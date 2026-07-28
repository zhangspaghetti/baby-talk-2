import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/features/account/data/local/auth_continuation_store.dart';
import 'package:mobile/features/account/presentation/auth_continuation_coordinator.dart';
import 'package:mobile/features/care_path/data/repositories/care_path_repository.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/care_path/presentation/care_path_notifier.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_draft_continuation_coordinator.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_handoff_confirmation_coordinator.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_draft_store.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/practice_content_source.dart';
import 'package:mobile/features/practice/presentation/practice_audio_controller.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/screens/practice_session_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

void main() {
  test('ready generated starter passes destination confirmation gate', () {
    expect(
      GeneratedCareTurnHandoffReadiness.isReady(
        routeContentId: 'generated_1',
        completedMomentKey: 'generated:generated_1',
        routeScopeKey: 'generated:generated_1',
        phase: CareTurnPhase.utteranceReady,
        snapshot: _snapshot(),
      ),
      isTrue,
    );
  });

  test('failure, stale, mismatch, and non-interactive starter fail gate', () {
    final matching = _snapshot();

    // A stale route completion cannot satisfy the destination gate.
    expect(
      GeneratedCareTurnHandoffReadiness.isReady(
        routeContentId: 'generated_1',
        completedMomentKey: 'generated:generated_1',
        routeScopeKey: 'generated:generated_2',
        phase: CareTurnPhase.utteranceReady,
        snapshot: matching,
      ),
      isFalse,
    );
    // A completed route must still resolve exactly its own generated content.
    expect(
      GeneratedCareTurnHandoffReadiness.isReady(
        routeContentId: 'generated_1',
        completedMomentKey: 'generated:generated_1',
        routeScopeKey: 'generated:generated_1',
        phase: CareTurnPhase.utteranceReady,
        snapshot: _snapshot(generatedContentId: 'generated_2'),
      ),
      isFalse,
    );
    expect(
      GeneratedCareTurnHandoffReadiness.isReady(
        routeContentId: 'generated_1',
        completedMomentKey: 'generated:generated_1',
        routeScopeKey: 'generated:generated_1',
        phase: CareTurnPhase.error,
        snapshot: matching,
      ),
      isFalse,
    );
    expect(
      GeneratedCareTurnHandoffReadiness.isReady(
        routeContentId: 'generated_1',
        completedMomentKey: 'generated:generated_1',
        routeScopeKey: 'generated:generated_1',
        phase: CareTurnPhase.utteranceReady,
        snapshot: _snapshot(contentSource: PracticeContentSource.seed),
      ),
      isFalse,
    );
    expect(
      GeneratedCareTurnHandoffReadiness.isReady(
        routeContentId: 'generated_1',
        completedMomentKey: 'generated:generated_1',
        routeScopeKey: 'generated:generated_1',
        phase: CareTurnPhase.utteranceReady,
        snapshot: _snapshot(isFallback: true),
      ),
      isFalse,
    );
  });

  testWidgets('destination confirms only ready generated starter once', (
    tester,
  ) async {
    final confirmationCoordinator = _TrackingHandoffConfirmationCoordinator(
      confirmationResult: true,
    );
    final notifier = _GeneratedHandoffNotifier();

    await _pumpGeneratedScreen(
      tester,
      notifier: notifier,
      confirmationCoordinator: confirmationCoordinator,
    );
    await tester.pump();

    expect(notifier.startCalls, 1);
    expect(confirmationCoordinator.confirmationCalls, 0);
    expect(confirmationCoordinator.hasDurableIntent, isTrue);

    notifier.completeWithReadyStarter();
    await _pumpFrames(tester);

    expect(find.bySemanticsLabel('Warm water.'), findsOneWidget);
    expect(confirmationCoordinator.confirmationCalls, 1);
    expect(confirmationCoordinator.hasDurableIntent, isFalse);

    await _pumpFrames(tester);
    expect(confirmationCoordinator.confirmationCalls, 1);
  });

  testWidgets('failed confirmation preserves intent and does not repeat', (
    tester,
  ) async {
    final confirmationCoordinator = _TrackingHandoffConfirmationCoordinator(
      confirmationResult: false,
    );
    final notifier = _GeneratedHandoffNotifier();

    await _pumpGeneratedScreen(
      tester,
      notifier: notifier,
      confirmationCoordinator: confirmationCoordinator,
    );
    await tester.pump();
    notifier.completeWithReadyStarter();
    await _pumpFrames(tester);

    expect(confirmationCoordinator.confirmationCalls, 1);
    expect(confirmationCoordinator.hasDurableIntent, isTrue);

    await _pumpFrames(tester);
    expect(confirmationCoordinator.confirmationCalls, 1);
    expect(confirmationCoordinator.hasDurableIntent, isTrue);
  });

  testWidgets('failed generated route never confirms or clears intent', (
    tester,
  ) async {
    final confirmationCoordinator = _TrackingHandoffConfirmationCoordinator(
      confirmationResult: true,
    );
    final notifier = _GeneratedHandoffNotifier();

    await _pumpGeneratedScreen(
      tester,
      notifier: notifier,
      confirmationCoordinator: confirmationCoordinator,
    );
    await tester.pump();
    notifier.completeWithFailure();
    await _pumpFrames(tester);

    expect(confirmationCoordinator.confirmationCalls, 0);
    expect(confirmationCoordinator.hasDurableIntent, isTrue);
  });
}

Future<void> _pumpGeneratedScreen(
  WidgetTester tester, {
  required _GeneratedHandoffNotifier notifier,
  required _TrackingHandoffConfirmationCoordinator confirmationCoordinator,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        practiceRepositoryProvider.overrideWith(
          (ref) async => _UnusedPracticeRepository(),
        ),
        carePathNotifierProvider.overrideWith((ref) => notifier),
        customSceneHandoffConfirmationCoordinatorProvider.overrideWith(
          (ref) => confirmationCoordinator,
        ),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PracticeSessionScreen(
          routeEntry: PracticeRouteEntry.fromObject(
            GeneratedCareTurnRouteArgs(generatedContentId: 'generated_1'),
          ),
          audioControllerFactory: _SilentPracticeAudioController.new,
        ),
      ),
    ),
  );
}

Future<void> _pumpFrames(WidgetTester tester, {int count = 6}) async {
  for (var index = 0; index < count; index += 1) {
    await tester.pump();
  }
}

class _TrackingHandoffConfirmationCoordinator
    extends CustomSceneHandoffConfirmationCoordinator {
  _TrackingHandoffConfirmationCoordinator({required bool confirmationResult})
    : _confirmationResult = confirmationResult,
      super(
        draftContinuationCoordinator: CustomSceneDraftContinuationCoordinator(
          draftStore: CustomSceneDraftStore(
            directoryResolver: () async => Directory.systemTemp,
          ),
          authContinuationCoordinator: AuthContinuationCoordinator(
            store: AuthContinuationStore(
              directoryResolver: () async => Directory.systemTemp,
            ),
          ),
        ),
        accountContextLoader: () async => 'account_a',
      );

  final bool _confirmationResult;
  int confirmationCalls = 0;
  bool hasDurableIntent = true;

  @override
  Future<bool> confirm({required String generatedContentId}) async {
    confirmationCalls += 1;
    if (_confirmationResult) {
      hasDurableIntent = false;
    }
    return _confirmationResult;
  }
}

class _GeneratedHandoffNotifier extends CarePathNotifier {
  _GeneratedHandoffNotifier()
    : super(
        repository: CarePathRepository(
          practiceRepository: _UnusedPracticeRepository(),
        ),
      );

  CareTurnSnapshot? _currentSnapshot;
  CareTurnPhase _currentPhase = CareTurnPhase.idle;
  int startCalls = 0;

  @override
  CareTurnSnapshot? get snapshot => _currentSnapshot;

  @override
  CareTurnPhase get phase => _currentPhase;

  @override
  Future<void> startGeneratedMoment({required String generatedContentId}) {
    startCalls += 1;
    _currentSnapshot = null;
    _currentPhase = CareTurnPhase.error;
    notifyListeners();
    return Future<void>.value();
  }

  void completeWithReadyStarter() {
    _currentSnapshot = _snapshot();
    _currentPhase = CareTurnPhase.utteranceReady;
    notifyListeners();
  }

  void completeWithFailure() {
    _currentSnapshot = null;
    _currentPhase = CareTurnPhase.error;
    notifyListeners();
  }
}

class _SilentPracticeAudioController implements PracticeAudioController {
  @override
  Stream<void> get completionStream => const Stream<void>.empty();

  @override
  Future<void> dispose() => Future<void>.value();

  @override
  Future<void> playAsset(String assetPath) => Future<void>.value();

  @override
  Future<void> stop() => Future<void>.value();
}

class _UnusedPracticeRepository implements PracticeRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CareTurnSnapshot _snapshot({
  PracticeContentSource contentSource = PracticeContentSource.generated,
  bool isFallback = false,
  String generatedContentId = 'generated_1',
}) {
  return CareTurnSnapshot(
    moment: CareMoment(
      spaceId: 'daily_care',
      activityId: 'bath_time',
      spaceTitle: '日常照护',
      title: '洗澡',
      sceneTag: 'bath',
      careActionLabel: '回应此刻',
      coachTip: '慢慢说',
      nodeState: CarePathNodeState.current,
      contentSource: contentSource,
      generatedContentId: generatedContentId,
    ),
    currentUtterance: CareUtterance(
      phraseId: 'starter_1',
      english: 'Warm water.',
      chinese: '温温的水。',
      pronunciation: 'wɔːm',
      audioAsset: null,
      whenToSay: '慢慢说',
      isFallback: isFallback,
    ),
    selectedReaction: null,
    nextSupportUtterance: null,
    phase: CareTurnPhase.utteranceReady,
    traceEventKey: null,
    latestGardenImpact: null,
    message: null,
  );
}
