import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/features/care_path/data/repositories/care_path_repository.dart';
import 'package:mobile/features/care_entry/contract/onboarding_care_turn_continuation.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/practice_content_source.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/preset_scene_generation_gate_screen.dart';
import 'package:mobile/features/practice/presentation/screens/practice_session_screen.dart';
import 'package:mobile/features/scene_generation/application/scene_generation_controller.dart';
import 'package:mobile/features/scene_generation/domain/generated_care_moment.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_failure.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_repository.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_source.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/l10n/app_localizations.dart';

void main() {
  test(
    'route entry policy distinguishes preset, generated, onboarding, invalid',
    () {
      final preset = PracticeRouteEntry.fromObject(
        const PracticeRouteArgs(spaceId: 'daily_care', activityId: 'bath_time'),
      );
      final generated = PracticeRouteEntry.fromObject(
        GeneratedCareTurnRouteArgs(generatedContentId: 'generated_1'),
      );
      final onboarding = PracticeRouteEntry.fromObject(
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
      );

      expect(preset.kind, PracticeEntryKind.preset);
      expect(generated.kind, PracticeEntryKind.generated);
      expect(onboarding.kind, PracticeEntryKind.onboarding);
      expect(
        PracticeRouteEntry.fromObject(null).kind,
        PracticeEntryKind.invalid,
      );
    },
  );

  test('registers approved preset bundle before exposing success', () async {
    final generation = Completer<GeneratedCareMoment>();
    final repository = _FakeSceneGenerationRepository(
      onGenerate: ({required source, required clientRequestId}) =>
          generation.future,
    );
    final registration = <GeneratedCareMoment>[];
    final controller = SceneGenerationController(
      repository: repository,
      approvedBundleRegistrar: (moment) async {
        registration.add(moment);
      },
    );

    final operation = controller.generate(
      source: const PresetSceneGenerationSource('bath_time'),
      clientRequestId: 'preset_request_1',
    );

    expect(controller.state.status, SceneGenerationControllerStatus.submitting);
    generation.complete(_presetMoment());
    await operation;

    expect(registration, hasLength(1));
    expect(controller.state.status, SceneGenerationControllerStatus.success);
    expect(controller.state.moment?.generatedContentId, 'generated_preset_1');
  });

  test(
    'retry after unknown outcome reuses source and request identity',
    () async {
      var attempt = 0;
      final repository = _FakeSceneGenerationRepository(
        onGenerate: ({required source, required clientRequestId}) async {
          attempt += 1;
          if (attempt == 1) {
            throw const SceneGenerationFailure(
              kind: SceneGenerationFailureKind.timeout,
              retryable: true,
            );
          }
          return _presetMoment();
        },
      );
      final requests = <String>[];
      repository.onRequest = ({required source, required clientRequestId}) {
        requests.add(clientRequestId);
      };
      final controller = SceneGenerationController(
        repository: repository,
        approvedBundleRegistrar: (_) async {},
      );

      await controller.generate(
        source: const PresetSceneGenerationSource('bath_time'),
        clientRequestId: 'preset_request_2',
      );
      expect(
        controller.state.status,
        SceneGenerationControllerStatus.unknownOutcome,
      );

      await controller.retry();

      expect(requests, ['preset_request_2', 'preset_request_2']);
      expect(controller.state.status, SceneGenerationControllerStatus.success);
    },
  );

  test(
    'registration recovery retries registration without generating twice',
    () async {
      var registrationAttempts = 0;
      final repository = _FakeSceneGenerationRepository(
        onGenerate: ({required source, required clientRequestId}) async =>
            _presetMoment(),
      );
      final controller = SceneGenerationController(
        repository: repository,
        approvedBundleRegistrar: (_) async {
          registrationAttempts += 1;
          if (registrationAttempts == 1) {
            throw StateError('registry unavailable');
          }
        },
      );

      await controller.generate(
        source: const PresetSceneGenerationSource('bath_time'),
        clientRequestId: 'preset_request_registration',
      );
      expect(
        controller.state.status,
        SceneGenerationControllerStatus.unknownOutcome,
      );

      await controller.retry();

      expect(repository.generateCount, 1);
      expect(registrationAttempts, 2);
      expect(controller.state.status, SceneGenerationControllerStatus.success);
    },
  );

  test('terminal recovery allocates a new logical request identity', () async {
    var attempts = 0;
    final requests = <String>[];
    final controller = SceneGenerationController(
      repository: _FakeSceneGenerationRepository(
        onGenerate: ({required source, required clientRequestId}) async {
          requests.add(clientRequestId);
          attempts += 1;
          if (attempts == 1) {
            throw const SceneGenerationFailure(
              kind: SceneGenerationFailureKind.requestTerminal,
              requiresNewClientRequestId: true,
            );
          }
          return _presetMoment();
        },
      ),
      approvedBundleRegistrar: (_) async {},
    );

    await controller.generate(
      source: const PresetSceneGenerationSource('bath_time'),
      clientRequestId: 'terminal_request_1',
    );
    await controller.retry();

    expect(requests, hasLength(2));
    expect(requests[0], 'terminal_request_1');
    expect(requests[1], isNot('terminal_request_1'));
    expect(controller.state.status, SceneGenerationControllerStatus.success);
  });

  test('recoverable failure keeps request identity when retrying', () async {
    var attempts = 0;
    final requests = <String>[];
    final controller = SceneGenerationController(
      repository: _FakeSceneGenerationRepository(
        onGenerate: ({required source, required clientRequestId}) async {
          requests.add(clientRequestId);
          attempts += 1;
          if (attempts == 1) {
            throw const SceneGenerationFailure(
              kind: SceneGenerationFailureKind.invalidInput,
            );
          }
          return _presetMoment();
        },
      ),
      approvedBundleRegistrar: (_) async {},
    );

    await controller.generate(
      source: const PresetSceneGenerationSource('bath_time'),
      clientRequestId: 'recoverable_request_1',
    );
    expect(
      controller.state.status,
      SceneGenerationControllerStatus.recoverableError,
    );
    await controller.retry();

    expect(requests, ['recoverable_request_1', 'recoverable_request_1']);
    expect(controller.state.status, SceneGenerationControllerStatus.success);
  });

  test('reentrant generate calls share one logical request', () async {
    final generation = Completer<GeneratedCareMoment>();
    final repository = _FakeSceneGenerationRepository(
      onGenerate: ({required source, required clientRequestId}) =>
          generation.future,
    );
    final controller = SceneGenerationController(
      repository: repository,
      approvedBundleRegistrar: (_) async {},
    );

    final first = controller.generate(
      source: const PresetSceneGenerationSource('bath_time'),
      clientRequestId: 'preset_request_3',
    );
    final second = controller.generate(
      source: const PresetSceneGenerationSource('bath_time'),
      clientRequestId: 'preset_request_3',
    );

    expect(identical(first, second), isTrue);
    expect(repository.generateCount, 1);
    generation.complete(_presetMoment());
    await first;
  });

  testWidgets(
    'gate shows progress before generation and routes success as generated',
    (tester) async {
      final generation = Completer<GeneratedCareMoment>();
      final controller = SceneGenerationController(
        repository: _FakeSceneGenerationRepository(
          onGenerate: ({required source, required clientRequestId}) =>
              generation.future,
        ),
        approvedBundleRegistrar: (_) async {},
      );
      GeneratedCareTurnRouteArgs? generatedArgs;

      await tester.pumpWidget(
        MaterialApp(
          home: PresetSceneGenerationGateScreen(
            routeEntry: PracticeRouteEntry.fromObject(
              const PracticeRouteArgs(
                spaceId: 'daily_care',
                activityId: 'bath_time',
              ),
            ),
            controller: controller,
            clientRequestId: 'preset_widget_request',
            onGenerated: (args) async {
              generatedArgs = args;
            },
            bundledFallbackLoader: (_) async => false,
          ),
        ),
      );

      await tester.pump();
      expect(
        find.byKey(const Key('preset-generation-progress')),
        findsOneWidget,
      );
      expect(find.text('正在为宝宝准备个性化练习…'), findsOneWidget);

      generation.complete(_presetMoment());
      await tester.pumpAndSettle();

      expect(generatedArgs?.generatedContentId, 'generated_preset_1');
      expect(find.byKey(const Key('preset-generation-progress')), findsNothing);
    },
  );

  testWidgets(
    'gate offers local generic fallback only when bundled content exists',
    (tester) async {
      final controller = SceneGenerationController(
        repository: _FakeSceneGenerationRepository(
          onGenerate: ({required source, required clientRequestId}) async {
            throw const SceneGenerationFailure(
              kind: SceneGenerationFailureKind.network,
              retryable: true,
            );
          },
        ),
        approvedBundleRegistrar: (_) async {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PresetSceneGenerationGateScreen(
            routeEntry: PracticeRouteEntry.fromObject(
              const PracticeRouteArgs(
                spaceId: 'daily_care',
                activityId: 'bath_time',
              ),
            ),
            controller: controller,
            clientRequestId: 'preset_fallback_request',
            bundledFallbackLoader: (_) async => true,
            fallbackBuilder: (_, _) => const Text('通用内容'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('preset-generation-retry')), findsOneWidget);
      expect(find.text('使用通用内容'), findsOneWidget);

      await tester.tap(find.text('使用通用内容'));
      await tester.pumpAndSettle();
      expect(find.text('通用内容'), findsOneWidget);
      expect(find.byKey(const Key('preset-generation-retry')), findsNothing);
    },
  );

  testWidgets('default generic fallback carries explicit bundled-only args', (
    tester,
  ) async {
    final controller = SceneGenerationController(
      repository: _FakeSceneGenerationRepository(
        onGenerate: ({required source, required clientRequestId}) async {
          throw const SceneGenerationFailure(
            kind: SceneGenerationFailureKind.network,
            retryable: true,
          );
        },
      ),
      approvedBundleRegistrar: (_) async {},
    );

    final practiceRepository = Completer<PracticeRepository>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          practiceRepositoryProvider.overrideWith(
            (ref) => practiceRepository.future,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PresetSceneGenerationGateScreen(
            routeEntry: PracticeRouteEntry.fromObject(
              const PracticeRouteArgs(
                spaceId: 'daily_care',
                activityId: 'bath_time',
              ),
            ),
            controller: controller,
            clientRequestId: 'preset_default_fallback_request',
            bundledFallbackLoader: (_) async => true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('使用通用内容'));
    await tester.pump();

    final session = tester.widget<PracticeSessionScreen>(
      find.byType(PracticeSessionScreen),
    );
    expect(
      session.genericFallbackArgs?.scopeLabel,
      'generic-fallback:daily_care/bath_time',
    );
  });

  testWidgets('remote-only preset does not offer generic fallback', (
    tester,
  ) async {
    final controller = SceneGenerationController(
      repository: _FakeSceneGenerationRepository(
        onGenerate: ({required source, required clientRequestId}) async {
          throw const SceneGenerationFailure(
            kind: SceneGenerationFailureKind.presetSceneUnavailable,
            retryable: true,
          );
        },
      ),
      approvedBundleRegistrar: (_) async {},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PresetSceneGenerationGateScreen(
          routeEntry: PracticeRouteEntry.fromObject(
            const PracticeRouteArgs(
              spaceId: 'remote_space',
              activityId: 'remote_only',
            ),
          ),
          controller: controller,
          clientRequestId: 'preset_remote_request',
          bundledFallbackLoader: (_) async => false,
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('使用通用内容'), findsNothing);
  });

  testWidgets(
    'gate keeps default controller provider alive until it resolves',
    (tester) async {
      final controllerCompleter = Completer<SceneGenerationController>();
      var disposed = false;
      final controller = SceneGenerationController(
        repository: _FakeSceneGenerationRepository(
          onGenerate: ({required source, required clientRequestId}) async =>
              _presetMoment(),
        ),
        approvedBundleRegistrar: (_) async {},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sceneGenerationControllerProvider.overrideWith((ref) {
              ref.onDispose(() => disposed = true);
              return controllerCompleter.future;
            }),
          ],
          child: MaterialApp(
            home: PresetSceneGenerationGateScreen(
              routeEntry: PracticeRouteEntry.fromObject(
                const PracticeRouteArgs(
                  spaceId: 'daily_care',
                  activityId: 'bath_time',
                ),
              ),
              clientRequestId: 'provider_lifecycle_request',
              bundledFallbackLoader: (_) async => false,
              onGenerated: (_) async {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(disposed, isFalse);

      controllerCompleter.complete(controller);
      await tester.pump();
      await tester.pump();
    },
  );

  testWidgets(
    'switching route identity starts a fresh controller for preset B',
    (tester) async {
      final controllerA = SceneGenerationController(
        repository: _FakeSceneGenerationRepository(
          onGenerate: ({required source, required clientRequestId}) =>
              Completer<GeneratedCareMoment>().future,
        ),
        approvedBundleRegistrar: (_) async {},
      );
      final controllerB = SceneGenerationController(
        repository: _FakeSceneGenerationRepository(
          onGenerate: ({required source, required clientRequestId}) async =>
              _presetMoment(),
        ),
        approvedBundleRegistrar: (_) async {},
      );

      PracticeRouteEntry entry(String activityId) =>
          PracticeRouteEntry.fromObject(
            PracticeRouteArgs(spaceId: 'daily_care', activityId: activityId),
          );

      await tester.pumpWidget(
        MaterialApp(
          home: PresetSceneGenerationGateScreen(
            routeEntry: entry('bath_time'),
            controller: controllerA,
            clientRequestId: 'route_a_request',
            bundledFallbackLoader: (_) async => false,
            onGenerated: (_) async {},
          ),
        ),
      );
      await tester.pump();
      expect(controllerA.status, SceneGenerationControllerStatus.submitting);

      await tester.pumpWidget(
        MaterialApp(
          home: PresetSceneGenerationGateScreen(
            routeEntry: entry('feeding_time'),
            controller: controllerB,
            clientRequestId: 'route_b_request',
            bundledFallbackLoader: (_) async => false,
            onGenerated: (_) async {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(controllerB.status, SceneGenerationControllerStatus.success);
      expect(controllerB.clientRequestId, 'route_b_request');
    },
  );

  test(
    'bundled fallback seam never resolves generated or remote content',
    () async {
      final repository = _BundledOnlyPracticeRepository();
      final turn = await CarePathRepository(practiceRepository: repository)
          .startMoment(
            spaceId: 'daily_care',
            activityId: 'bath_time',
            bundledOnly: true,
          );

      expect(repository.bundledCalls, 1);
      expect(repository.remoteCalls, 0);
      expect(turn.moment.contentSource, PracticeContentSource.seed);
    },
  );
}

class _FakeSceneGenerationRepository implements SceneGenerationRepository {
  _FakeSceneGenerationRepository({required this.onGenerate});

  Future<GeneratedCareMoment> Function({
    required SceneGenerationSource source,
    required String clientRequestId,
  })
  onGenerate;
  void Function({
    required SceneGenerationSource source,
    required String clientRequestId,
  })?
  onRequest;
  int generateCount = 0;

  @override
  Future<GeneratedCareMoment> generate({
    required SceneGenerationSource source,
    required String clientRequestId,
  }) {
    generateCount += 1;
    onRequest?.call(source: source, clientRequestId: clientRequestId);
    return onGenerate(source: source, clientRequestId: clientRequestId);
  }
}

class _BundledOnlyPracticeRepository implements PracticeRepository {
  int bundledCalls = 0;
  int remoteCalls = 0;

  @override
  Future<PracticeActivitySnapshot> getBundledActivitySnapshot({
    required String spaceId,
    required String activityId,
  }) async {
    bundledCalls += 1;
    return const PracticeActivitySnapshot(
      spaceId: 'daily_care',
      activityId: 'bath_time',
      title: '洗澡时间',
      summary: '通用内容',
      sceneTag: 'bath',
      coachTip: '慢慢说',
      phrases: <PracticePhrase>[
        PracticePhrase(
          spaceId: 'daily_care',
          activityId: 'bath_time',
          phraseId: 'bath_time_warm_water',
          step: 1,
          english: 'Warm water.',
          chinese: '水暖暖的。',
          pronunciation: 'wɔːm',
          difficulty: 'starter',
          audioAsset: 'assets/audio/phrases/bath_time_warm_water.mp3',
        ),
      ],
    );
  }

  @override
  Future<PracticeActivitySnapshot> getActivitySnapshot({
    required String spaceId,
    required String activityId,
  }) async {
    remoteCalls += 1;
    throw StateError('remote activity must not be read for generic fallback');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

GeneratedCareMoment _presetMoment() {
  GeneratedCareUtterance utterance(
    String suffix, {
    required GeneratedCareUtteranceRole role,
    required BabyReactionType? reaction,
    required int displayOrder,
  }) {
    return GeneratedCareUtterance(
      utteranceId: 'utterance_$suffix',
      phraseId: 'phrase_$suffix',
      english: 'Warm water',
      chinese: '温水来了',
      pronunciation: 'wɔːm',
      tprActionZh: '靠近宝宝',
      deliveryGuidanceZh: '慢慢说',
      difficulty: 'starter',
      source: 'generated',
      role: role,
      reaction: reaction,
      displayOrder: displayOrder,
      providerProvenance: GeneratedCareProviderProvenance(
        origin: GeneratedCareProviderOrigin.providerGenerated,
        providerName: 'provider',
        modelName: 'model',
        attemptNumber: 1,
      ),
    );
  }

  return GeneratedCareMoment(
    schemaVersion: generatedCareMomentSchemaVersion,
    generatedContentId: 'generated_preset_1',
    sceneId: 'daily_care',
    spaceId: 'daily_care',
    momentId: 'bath_time',
    activityId: 'bath_time',
    title: '洗澡时间',
    sceneTag: 'bath',
    coachTip: '慢慢说',
    source: 'generated',
    inputSource: SceneGenerationSourceType.preset,
    presetSceneId: 'bath_time',
    presetSceneVersion: 1,
    starter: utterance(
      'starter',
      role: GeneratedCareUtteranceRole.starter,
      reaction: null,
      displayOrder: 1,
    ),
    reactionSupports:
        GeneratedReactionSupportMap(<BabyReactionType, GeneratedCareUtterance>{
          for (final reaction in BabyReactionType.values)
            reaction: utterance(
              reaction.name,
              role: GeneratedCareUtteranceRole.reactionSupport,
              reaction: reaction,
              displayOrder: BabyReactionType.values.indexOf(reaction) + 2,
            ),
        }),
  );
}
