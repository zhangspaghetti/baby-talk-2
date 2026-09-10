import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/router/app_go_router.dart';
import 'package:mobile/app/router/app_route_contract.dart';
import 'package:mobile/features/care_entry/contract/onboarding_care_turn_continuation.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/preset_scene_generation_gate_screen.dart';
import 'package:mobile/features/practice/presentation/screens/practice_session_screen.dart';
import 'package:mobile/features/practice/domain/models/preset_scene_definition.dart';
import 'package:mobile/features/scene_generation/application/scene_generation_controller.dart';
import 'package:mobile/features/scene_generation/domain/generated_care_moment.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_repository.dart';
import 'package:mobile/l10n/app_localizations.dart';
import '../../support/generated_care_moment_fixture.dart';

void main() {
  testWidgets(
    'central practice route sends preset entries to generation gate',
    (tester) async {
      final pendingRepository = Completer<SceneGenerationRepository>();
      final router = createAppRouter(
        initialLocation: AppRouteNames.practice,
        presetDefinitionLoader: _presetDefinitionLoader,
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sceneGenerationRepositoryProvider.overrideWith(
              (ref) => pendingRepository.future,
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      router.go(
        AppRouteNames.practice,
        extra: const PracticeRouteArgs(
          spaceId: 'daily_care',
          activityId: 'bath_time',
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('preset-generation-progress')),
        findsOneWidget,
      );
      expect(find.byType(PracticeSessionScreen), findsNothing);
      pendingRepository.complete(_PendingRepository());
    },
  );

  testWidgets(
    'generated, onboarding, and invalid entries bypass generation gate',
    (tester) async {
      final repository = Completer<PracticeRepository>();
      final router = createAppRouter(
        initialLocation: AppRouteNames.practice,
        presetDefinitionLoader: _presetDefinitionLoader,
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            practiceRepositoryProvider.overrideWith((ref) => repository.future),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      final entries = <Object?>[
        GeneratedCareTurnRouteArgs(generatedContentId: 'generated_1'),
        const OnboardingCareTurnRouteArgs(
          completionId: 'completion_1',
          spaceId: 'daily_care',
          activityId: 'bath_time',
          entryTitle: '洗澡',
          utteranceId: 'utterance_1',
          english: 'Warm water.',
          chinese: '温水。',
          source: OnboardingCareTurnSource.localFallback,
        ),
        null,
      ];
      for (final entry in entries) {
        router.go(AppRouteNames.practice, extra: entry);
        await tester.pump();
        expect(find.byType(PracticeSessionScreen), findsOneWidget);
        expect(
          find.byKey(const Key('preset-generation-progress')),
          findsNothing,
        );
      }
      repository.completeError(StateError('test end'));
    },
  );

  testWidgets(
    'successful preset generation replaces gate with generated route',
    (tester) async {
      final controller = SceneGenerationController(
        repository: _ImmediateRepository(
          generatedCareMomentFixture(
            generatedContentId: 'generated_route',
            sceneId: 'daily_care',
            spaceId: 'daily_care',
            momentId: 'bath_time',
            activityId: 'bath_time',
            inputSource: SceneGenerationSourceType.preset,
            presetSceneId: 'bath_time',
            presetSceneVersion: 1,
          ),
        ),
        approvedBundleRegistrar: (_) async {},
      );
      final practiceRepository = Completer<PracticeRepository>();
      final router = createAppRouter(
        initialLocation: AppRouteNames.practice,
        presetDefinitionLoader: _presetDefinitionLoader,
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sceneGenerationControllerProvider(
              'daily_care/bath_time@v1',
            ).overrideWith((ref) => controller),
            practiceRepositoryProvider.overrideWith(
              (ref) => practiceRepository.future,
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      router.go(
        AppRouteNames.practice,
        extra: const PracticeRouteArgs(
          spaceId: 'daily_care',
          activityId: 'bath_time',
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('preset-generation-progress')),
        findsOneWidget,
      );

      for (var index = 0; index < 4; index += 1) {
        await tester.pump();
      }
      expect(find.byType(PresetSceneGenerationGateScreen), findsNothing);
      expect(find.byType(PracticeSessionScreen), findsOneWidget);
      practiceRepository.completeError(StateError('test end'));
    },
  );

  test('router exposes runtime baby-profile route contract', () {
    final router = createAppRouter();
    addTearDown(router.dispose);

    expect(
      router.configuration
          .findMatch(Uri.parse(AppRouteNames.meBabyProfile))
          .error,
      isNull,
    );
  });
}

class _PendingRepository implements SceneGenerationRepository {
  @override
  Future<GeneratedCareMoment> generate({
    required source,
    required String clientRequestId,
  }) {
    return Completer<GeneratedCareMoment>().future;
  }
}

class _ImmediateRepository implements SceneGenerationRepository {
  _ImmediateRepository(this.moment);

  final GeneratedCareMoment moment;

  @override
  Future<GeneratedCareMoment> generate({
    required source,
    required String clientRequestId,
  }) async => moment;
}

Future<PresetSceneDefinition?> _presetDefinitionLoader(
  PracticeRouteArgs args,
) async {
  return PresetSceneDefinition(
    presetSceneId: args.normalizedActivityId,
    publishedVersion: 1,
    spaceId: args.normalizedSpaceId,
    title: args.normalizedActivityId,
    summary: args.normalizedActivityId,
    sceneTag: args.normalizedActivityId,
    coachTip: args.normalizedActivityId,
    sortOrder: 1,
  );
}
