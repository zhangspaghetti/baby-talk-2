import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/features/account/data/local/auth_continuation_store.dart';
import 'package:mobile/features/account/presentation/auth_continuation_coordinator.dart';
import 'package:mobile/features/care_entry/contract/onboarding_care_turn_continuation.dart';
import 'package:mobile/features/care_path/data/repositories/care_path_repository.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/care_path/presentation/care_path_notifier.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_draft_continuation_coordinator.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_handoff_confirmation_coordinator.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_draft_store.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/generated/generated_care_turn_resume_marker_store.dart';
import 'package:mobile/features/practice/domain/models/practice_content_source.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
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

  testWidgets('onboarding handoff renders the exact support in Care Turn', (
    tester,
  ) async {
    final practiceRepository = _OnboardingPracticeRepository();
    final continuationPort = _MemoryContinuationPort();
    final notifier = CarePathNotifier(
      repository: CarePathRepository(
        practiceRepository: practiceRepository,
        onboardingContinuationPort: continuationPort,
      ),
    );
    const args = OnboardingCareTurnRouteArgs(
      completionId: 'completion-1',
      spaceId: 'family_rhythm',
      activityId: 'bedtime',
      entryTitle: '哄睡中',
      utteranceId: 'support.bedtime.hesitant',
      english: 'Try when ready.',
      chinese: '准备好再试。',
      source: OnboardingCareTurnSource.localFallback,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          practiceRepositoryProvider.overrideWith(
            (ref) async => practiceRepository,
          ),
          carePathNotifierProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PracticeSessionScreen(
            routeEntry: PracticeRouteEntry.fromObject(args),
            audioControllerFactory: _SilentPracticeAudioController.new,
          ),
        ),
      ),
    );
    await _pumpFrames(tester);

    expect(find.text('Try when ready.'), findsOneWidget);
    expect(find.text('准备好再试。'), findsOneWidget);
    expect(
      notifier.snapshot?.currentUtterance?.phraseId,
      'support.bedtime.hesitant',
    );
    expect(
      notifier.snapshot?.currentUtterance?.sourceIdentity,
      'local_fallback',
    );
    notifier.markSaid();
    await notifier.selectReaction(BabyReactionType.hesitant);
    await _pumpFrames(tester);
    expect(continuationPort.records, hasLength(1));
    expect(
      continuationPort.records.single.utteranceId,
      'support.bedtime.hesitant',
    );
    expect(notifier.snapshot?.traceEventKey, isNotNull);
  });

  testWidgets('invalid onboarding handoff renders a scoped failure', (
    tester,
  ) async {
    final practiceRepository = _OnboardingPracticeRepository();
    final notifier = CarePathNotifier(
      repository: CarePathRepository(
        practiceRepository: practiceRepository,
        onboardingContinuationPort: _FailingContinuationPort(),
      ),
    );
    const args = OnboardingCareTurnRouteArgs(
      completionId: 'completion-invalid',
      spaceId: 'family_rhythm',
      activityId: 'bedtime',
      entryTitle: '哄睡中',
      utteranceId: 'support.invalid',
      english: 'Invalid support.',
      chinese: '无效支持。',
      source: OnboardingCareTurnSource.remoteGenerated,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          practiceRepositoryProvider.overrideWith(
            (ref) async => practiceRepository,
          ),
          carePathNotifierProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PracticeSessionScreen(
            routeEntry: PracticeRouteEntry.fromObject(args),
            audioControllerFactory: _SilentPracticeAudioController.new,
          ),
        ),
      ),
    );
    await _pumpFrames(tester);

    expect(find.text('刚才的下一句暂时无法核验，请返回今天重试。'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
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
        generatedCareTurnResumeStore: GeneratedCareTurnResumeMarkerStore(
          directoryResolver: () async => Directory.systemTemp,
        ),
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

final class _MemoryContinuationPort
    implements OnboardingCareTurnContinuationPort {
  final List<OnboardingContinuationReactionRecord> records = [];

  @override
  Future<OnboardingCareTurnHandoff> verify(
    OnboardingCareTurnHandoff handoff,
  ) async => handoff;

  @override
  Future<OnboardingContinuationReactionRecord> recordReaction({
    required OnboardingCareTurnHandoff handoff,
    required String reaction,
    required DateTime occurredAt,
  }) async {
    final record = OnboardingContinuationReactionRecord(
      eventId: 'event-${handoff.completionId}',
      completionId: handoff.completionId,
      utteranceId: handoff.utteranceId,
      reaction: reaction,
      occurredAt: occurredAt,
    );
    records.add(record);
    return record;
  }
}

final class _FailingContinuationPort
    implements OnboardingCareTurnContinuationPort {
  @override
  Future<OnboardingCareTurnHandoff> verify(
    OnboardingCareTurnHandoff handoff,
  ) async => throw const FormatException('invalid handoff');

  @override
  Future<OnboardingContinuationReactionRecord> recordReaction({
    required OnboardingCareTurnHandoff handoff,
    required String reaction,
    required DateTime occurredAt,
  }) async => throw StateError('not reached');
}

final class _OnboardingPracticeRepository implements PracticeRepository {
  static const activitySummary = PracticeCatalogActivitySummary(
    spaceId: 'family_rhythm',
    spaceTitle: '家庭节奏',
    activityId: 'bedtime',
    title: '睡前时光',
    summary: '慢慢安静下来。',
    sceneTag: 'bedtime',
    coachTip: '轻轻说。',
    totalPhraseCount: 1,
    completedPhraseCount: 0,
    completedPhraseIds: <String>[],
    nextPhraseId: 'bedtime_seed_1',
    nextPhraseEnglish: 'Sleepy time.',
    totalEvents: 0,
    skippedUnknownPhraseCount: 0,
    skippedMalformedEventCount: 0,
  );

  static const activity = PracticeActivitySnapshot(
    spaceId: 'family_rhythm',
    activityId: 'bedtime',
    title: '睡前时光',
    summary: '慢慢安静下来。',
    sceneTag: 'bedtime',
    coachTip: '轻轻说。',
    phrases: <PracticePhrase>[
      PracticePhrase(
        spaceId: 'family_rhythm',
        activityId: 'bedtime',
        phraseId: 'bedtime_seed_1',
        step: 1,
        english: 'Sleepy time.',
        chinese: '睡觉时间到啦。',
        pronunciation: 'sleepy time',
        difficulty: 'easy',
        audioAsset: '',
      ),
    ],
  );

  @override
  Future<PracticeActivityCatalog> getActivityCatalog() async {
    return const PracticeActivityCatalog(
      installationId: 'installation-1',
      spaces: <PracticeCatalogSpaceSummary>[
        PracticeCatalogSpaceSummary(
          spaceId: 'family_rhythm',
          title: '家庭节奏',
          description: '家庭节奏',
          activities: <PracticeCatalogActivitySummary>[activitySummary],
          totalEvents: 0,
          startedActivityCount: 0,
          completedActivityCount: 0,
        ),
      ],
      activities: <PracticeCatalogActivitySummary>[activitySummary],
      totalStoredEvents: 0,
      validEvents: 0,
      knownEvents: 0,
      skippedMalformedEvents: 0,
      skippedUnknownContentEvents: 0,
    );
  }

  @override
  Future<PracticeActivitySnapshot> getActivitySnapshot({
    required String spaceId,
    required String activityId,
  }) async => activity;

  @override
  Future<PracticeActivitySnapshot> getBundledActivitySnapshot({
    required String spaceId,
    required String activityId,
  }) async => activity;

  @override
  Future<PracticeResumeInfo> getResumeInfo({
    required String spaceId,
    required String activityId,
  }) async => const PracticeResumeInfo(
    activityId: 'bedtime',
    totalPhrases: 1,
    completedPhraseIds: <String>[],
    nextPhraseId: 'bedtime_seed_1',
    lastEventTime: null,
  );

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
