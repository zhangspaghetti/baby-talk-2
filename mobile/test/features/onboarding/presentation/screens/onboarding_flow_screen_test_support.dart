import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/router/app_route_contract.dart';
import 'package:mobile/app/router/account_entry_route_contract.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/local/auth_continuation_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository_contract.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/auth_continuation.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/account/presentation/account_notifier.dart';
import 'package:mobile/features/account/presentation/auth_continuation_coordinator.dart';
import 'package:mobile/features/care_path/data/repositories/care_path_repository.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/care_path/presentation/care_path_notifier.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_flow_store.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_flow_models.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_flow_notifier.dart';
import 'package:mobile/features/onboarding/presentation/screens/onboarding_flow_screen.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
import 'package:mobile/features/practice/presentation/practice_audio_controller.dart';
import 'package:mobile/l10n/app_localizations.dart';

class OnboardingFlowScreenHarness {
  OnboardingFlowScreenHarness._({
    required this.carePathNotifier,
    required _ControllableCarePathRepository carePathRepository,
    required _MemoryOnboardingFlowStore flowStore,
    required _MemoryAuthContinuationStore authContinuationStore,
    required this.accountNotifier,
    required this.notifier,
  }) : _carePathRepository = carePathRepository,
       _flowStore = flowStore,
       _authContinuationStore = authContinuationStore;

  final CarePathNotifier carePathNotifier;
  final _ControllableCarePathRepository _carePathRepository;
  final _MemoryOnboardingFlowStore _flowStore;
  final _MemoryAuthContinuationStore _authContinuationStore;
  final AccountNotifier accountNotifier;
  final OnboardingFlowNotifier notifier;
  final ControllablePracticeAudioController audioController =
      ControllablePracticeAudioController();

  Completer<AccountEntryResult>? _accountResult;
  AccountEntryOrigin? _accountEntryOrigin;
  var _providerScopeOwnsNotifiers = false;
  int _accountRoutePushCount = 0;
  int _shellNavigationCount = 0;

  int get accountRoutePushCount => _accountRoutePushCount;
  AccountEntryOrigin? get accountEntryOrigin => _accountEntryOrigin;
  int get shellNavigationCount => _shellNavigationCount;
  int get continuationWriteCount => _authContinuationStore.writeCount;
  List<String?> get receivedReactionLocalEventIds =>
      List<String?>.unmodifiable(_carePathRepository.receivedLocalEventIds);

  void failNextReactionWrite() {
    _carePathRepository.failNextReactionWrite = true;
  }

  void failNextMomentLoad() {
    _carePathRepository.failNextMomentLoad = true;
  }

  void failNextConfirmedTracePersistence() {
    _flowStore.failOnWrite = _flowStore.writeCount + 2;
  }

  void failNextStarterPhrasePersistence() {
    _flowStore.failOnWrite = _flowStore.writeCount + 2;
  }

  Completer<void> holdNextContinuationWrite() {
    final gate = Completer<void>();
    _authContinuationStore.writeGate = gate;
    return gate;
  }

  static Future<OnboardingFlowScreenHarness> create({
    bool signedIn = true,
  }) async {
    final practiceRepository = _MemoryPracticeRepository();
    final flowStore = _MemoryOnboardingFlowStore();
    final snapshotStore = _MemoryOnboardingSnapshotStore();
    final authContinuationStore = _MemoryAuthContinuationStore();
    final carePathRepository = _ControllableCarePathRepository(
      practiceRepository: practiceRepository,
    );
    final carePathNotifier = CarePathNotifier(repository: carePathRepository);
    final accountNotifier = AccountNotifier(
      repository: _SignedInAccountRepository(signedIn: signedIn),
    );
    await accountNotifier.initialize();
    final onboardingRepository = OnboardingRepository(
      snapshotStore: snapshotStore,
      flowStore: flowStore,
    );
    final notifier = OnboardingFlowNotifier(
      onboardingRepository: onboardingRepository,
      practiceRepository: practiceRepository,
      carePathNotifier: carePathNotifier,
      accountNotifier: accountNotifier,
      authContinuationCoordinator: AuthContinuationCoordinator(
        store: authContinuationStore,
      ),
      clock: () => DateTime.utc(2026, 7, 24, 12),
      localEventIdGenerator: () => 'evt_onboarding_screen',
    );
    return OnboardingFlowScreenHarness._(
      carePathNotifier: carePathNotifier,
      carePathRepository: carePathRepository,
      flowStore: flowStore,
      authContinuationStore: authContinuationStore,
      accountNotifier: accountNotifier,
      notifier: notifier,
    );
  }

  Future<void> pumpAtStep(
    WidgetTester tester,
    OnboardingFlowStep step, {
    TextScaler textScaler = TextScaler.noScaling,
    bool disableAnimations = false,
  }) async {
    await notifier.initialize();
    await _advanceTo(step);
    final router = GoRouter(
      initialLocation: AppRouteNames.onboarding,
      routes: <RouteBase>[
        GoRoute(
          path: AppRouteNames.onboarding,
          builder: (context, state) => OnboardingFlowScreen(
            audioControllerFactory: () => audioController,
          ),
        ),
        GoRoute(
          path: AppRouteNames.account,
          builder: (context, state) {
            _accountRoutePushCount += 1;
            _accountEntryOrigin = state.extra as AccountEntryOrigin?;
            final result = Completer<AccountEntryResult>();
            _accountResult = result;
            return _AccountResultRoute(result: result.future);
          },
        ),
        GoRoute(
          path: AppRouteNames.shell,
          builder: (context, state) {
            _shellNavigationCount += 1;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    _providerScopeOwnsNotifiers = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          onboardingFlowNotifierProvider.overrideWith((ref) => notifier),
          carePathNotifierProvider.overrideWith((ref) => carePathNotifier),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: textScaler,
              disableAnimations: disableAnimations,
            ),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> _advanceTo(OnboardingFlowStep target) async {
    if (target == OnboardingFlowStep.welcome) {
      return;
    }
    await notifier.continueFromWelcome();
    if (target == OnboardingFlowStep.age) {
      return;
    }
    await notifier.selectAgeBucket(OnboardingAgeBucket.oneToTwo);
    await notifier.continueFromAge();
    if (target == OnboardingFlowStep.scenePreferences) {
      return;
    }
    final moment = notifier.availableMoments.first;
    await notifier.toggleScenePreference(moment.activityId);
    await notifier.continueFromScenePreferences();
    if (target == OnboardingFlowStep.supportGoal) {
      return;
    }
    await notifier.selectSupportGoal(OnboardingSupportGoal.moreNatural);
    await notifier.continueFromSupportGoal();
    if (target == OnboardingFlowStep.currentMoment) {
      return;
    }
    await notifier.selectCurrentMoment(moment);
    if (target == OnboardingFlowStep.careTurn) {
      return;
    }
    notifier.markSaid();
    await notifier.selectReaction(BabyReactionType.hesitant);
    await notifier.continueFromCareTurn();
    if (target == OnboardingFlowStep.trace) {
      return;
    }
    await notifier.continueFromTrace();
  }

  void completeAccountRoute(AccountEntryResult result) {
    _accountResult!.complete(result);
  }

  Future<void> dispose() async {
    if (!_providerScopeOwnsNotifiers) {
      notifier.dispose();
      carePathNotifier.dispose();
    }
    accountNotifier.dispose();
  }
}

class ControllablePracticeAudioController implements PracticeAudioController {
  final StreamController<void> _completion = StreamController<void>.broadcast();
  bool failNextPlay = false;

  @override
  Stream<void> get completionStream => _completion.stream;

  @override
  Future<void> playAsset(String assetPath) async {
    if (failNextPlay) {
      failNextPlay = false;
      throw StateError('audio unavailable');
    }
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() => _completion.close();
}

class _AccountResultRoute extends StatefulWidget {
  const _AccountResultRoute({required this.result});

  final Future<AccountEntryResult> result;

  @override
  State<_AccountResultRoute> createState() => _AccountResultRouteState();
}

class _AccountResultRouteState extends State<_AccountResultRoute> {
  @override
  void initState() {
    super.initState();
    unawaited(_returnResult());
  }

  Future<void> _returnResult() async {
    final result = await widget.result;
    if (mounted) {
      context.pop(result);
    }
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('account route')));
}

class _SignedInAccountRepository implements AccountRepositoryContract {
  _SignedInAccountRepository({bool signedIn = true})
    : _snapshot = signedIn
          ? _signedInSnapshot()
          : AccountLocalSnapshot.localOnly;

  AccountLocalSnapshot _snapshot;

  @override
  Future<void> close() async {}

  @override
  Future<AccountLocalSnapshot> clearPlaceholderSession({
    bool revertToLocalOnly = false,
  }) async {
    _snapshot = revertToLocalOnly
        ? AccountLocalSnapshot.localOnly
        : AccountLocalSnapshot.signedOut;
    return _snapshot;
  }

  @override
  Future<AccountLocalSnapshot> deleteAccount({
    String reason = 'forget_me',
  }) async => AccountLocalSnapshot.localOnly;

  @override
  Future<AccountLocalSnapshot> loadSnapshot() async => _snapshot;

  @override
  Future<AccountLocalSnapshot> refreshRuntimeState({
    required AccountRuntimeTrigger trigger,
    AccountLocalSnapshot? seedSnapshot,
    bool forceBootstrap = false,
  }) async => seedSnapshot ?? _snapshot;

  @override
  Future<AccountLocalSnapshot> revokeConsent({
    String reason = 'user_requested',
  }) async => AccountLocalSnapshot.localOnly;

  @override
  Future<AccountLocalSnapshot> signIn({
    required String phoneNumber,
    required String verificationCode,
  }) async => _snapshot;
}

AccountLocalSnapshot _signedInSnapshot() => AccountLocalSnapshot(
  consentState: AccountConsentState.acceptedPendingSync,
  session: AccountSession(
    accountId: 'acct-onboarding-screen',
    sessionId: 'session-onboarding-screen',
    maskedPhoneNumber: '138****8000',
    createdAt: DateTime.utc(2026, 7, 24, 12),
  ),
  lastSyncPhase: 'synced',
);

class _MemoryOnboardingFlowStore extends OnboardingFlowStore {
  _MemoryOnboardingFlowStore() : super();

  OnboardingFlowSnapshot? _snapshot;
  int writeCount = 0;
  int? failOnWrite;

  @override
  Future<OnboardingFlowSnapshot?> read() async => _snapshot;

  @override
  Future<void> write(OnboardingFlowSnapshot snapshot) async {
    writeCount += 1;
    if (writeCount == failOnWrite) {
      throw StateError('disk unavailable');
    }
    _snapshot = snapshot;
  }

  @override
  Future<void> deleteIfExists() async {
    _snapshot = null;
  }
}

class _MemoryOnboardingSnapshotStore extends OnboardingSnapshotStore {
  _MemoryOnboardingSnapshotStore() : super();

  OnboardingSnapshot? _snapshot;

  @override
  Future<OnboardingSnapshot?> read() async => _snapshot;

  @override
  Future<void> write(OnboardingSnapshot snapshot) async {
    _snapshot = snapshot;
  }

  @override
  Future<void> deleteIfExists() async {
    _snapshot = null;
  }
}

class _MemoryAuthContinuationStore extends AuthContinuationStore {
  _MemoryAuthContinuationStore() : super();

  AuthContinuation? _continuation;
  int writeCount = 0;
  Completer<void>? writeGate;

  @override
  Future<AuthContinuation?> read({required DateTime now}) async {
    final continuation = _continuation;
    if (continuation == null) {
      return null;
    }
    if (!continuation.expiresAt.isAfter(now.toUtc())) {
      _continuation = null;
      return null;
    }
    return continuation;
  }

  @override
  Future<AuthContinuationReadResult> readResult({required DateTime now}) async {
    final continuation = await read(now: now);
    return AuthContinuationReadResult(
      status: continuation == null
          ? AuthContinuationReadStatus.notFound
          : AuthContinuationReadStatus.available,
      continuation: continuation,
    );
  }

  @override
  Future<void> write(AuthContinuation continuation) async {
    writeCount += 1;
    final gate = writeGate;
    if (gate != null) {
      await gate.future;
    }
    _continuation = continuation;
  }

  @override
  Future<void> deleteIfExists() async {
    _continuation = null;
  }
}

class _ControllableCarePathRepository extends CarePathRepository {
  _ControllableCarePathRepository({required super.practiceRepository});

  bool failNextReactionWrite = false;
  bool failNextMomentLoad = false;
  final List<String?> receivedLocalEventIds = <String?>[];

  @override
  Future<CareTurnSnapshot> startMoment({
    required String spaceId,
    required String activityId,
  }) async {
    if (failNextMomentLoad) {
      failNextMomentLoad = false;
      return CareTurnSnapshot(
        moment: CareMoment(
          spaceId: spaceId,
          activityId: activityId,
          spaceTitle: '日常照护',
          title: '暂时不可用',
          sceneTag: '',
          careActionLabel: '',
          coachTip: '',
          nodeState: CarePathNodeState.unavailable,
        ),
        currentUtterance: null,
        selectedReaction: null,
        nextSupportUtterance: null,
        phase: CareTurnPhase.error,
        traceEventKey: null,
        latestGardenImpact: null,
        message: '当前照护内容暂时无法加载。',
      );
    }
    return super.startMoment(spaceId: spaceId, activityId: activityId);
  }

  @override
  Future<CareTurnSnapshot> recordReaction({
    required CareTurnSnapshot turn,
    required BabyReactionType reactionType,
    DateTime? clientTimestamp,
    String? localEventId,
  }) {
    receivedLocalEventIds.add(localEventId);
    if (failNextReactionWrite) {
      failNextReactionWrite = false;
      return Future<CareTurnSnapshot>.error(StateError('reaction unavailable'));
    }
    return super.recordReaction(
      turn: turn,
      reactionType: reactionType,
      clientTimestamp: clientTimestamp,
      localEventId: localEventId,
    );
  }
}

class _MemoryPracticeRepository implements PracticeRepository {
  final List<InteractionEventPayload> _events = <InteractionEventPayload>[];

  static const _activity = PracticeActivitySnapshot(
    spaceId: 'daily_care',
    activityId: 'bath_time',
    title: '洗澡时间',
    summary: '温温的水。',
    sceneTag: 'Bath time',
    coachTip: '先说动作，再慢慢等待宝宝回应。',
    phrases: <PracticePhrase>[
      PracticePhrase(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'bath_time_warm_water',
        step: 1,
        english: 'Warm water.',
        chinese: '温温的水。',
        pronunciation: 'wɔːrm ˈwɔːtər',
        difficulty: 'easy',
        audioAsset: 'assets/audio/phrases/bath_time_warm_water.mp3',
      ),
      PracticePhrase(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'bath_time_splash_splash',
        step: 2,
        english: 'Splash splash.',
        chinese: '扑通扑通。',
        pronunciation: 'splæʃ splæʃ',
        difficulty: 'easy',
        audioAsset: 'assets/audio/phrases/bath_time_splash_splash.mp3',
      ),
    ],
  );

  @override
  Future<PracticeActivityCatalog> getActivityCatalog() async {
    final completedPhraseIds = _events.map((event) => event.phraseId).toList();
    final nextPhrase = _nextPhrase(completedPhraseIds);
    return PracticeActivityCatalog(
      installationId: 'memory_onboarding_screen_test',
      spaces: const <PracticeCatalogSpaceSummary>[],
      activities: <PracticeCatalogActivitySummary>[
        PracticeCatalogActivitySummary(
          spaceId: _activity.spaceId,
          spaceTitle: '日常照护',
          activityId: _activity.activityId,
          title: _activity.title,
          summary: _activity.summary,
          sceneTag: _activity.sceneTag,
          coachTip: _activity.coachTip,
          totalPhraseCount: _activity.phrases.length,
          completedPhraseCount: completedPhraseIds.length,
          completedPhraseIds: completedPhraseIds,
          nextPhraseId: nextPhrase?.phraseId,
          nextPhraseEnglish: nextPhrase?.english,
          totalEvents: _events.length,
          skippedUnknownPhraseCount: 0,
          skippedMalformedEventCount: 0,
        ),
      ],
      totalStoredEvents: _events.length,
      validEvents: _events.length,
      knownEvents: _events.length,
      skippedMalformedEvents: 0,
      skippedUnknownContentEvents: 0,
    );
  }

  @override
  Future<PracticeActivitySnapshot> getActivitySnapshot({
    required String spaceId,
    required String activityId,
  }) async => _activity;

  @override
  Future<InteractionEventPayload?> findEventByLocalEventId(
    String localEventId,
  ) async {
    for (final event in _events) {
      if (event.localEventId == localEventId) {
        return event;
      }
    }
    return null;
  }

  @override
  Future<PracticeResumeInfo> getResumeInfo({
    required String spaceId,
    required String activityId,
  }) async {
    final completedPhraseIds = _events.map((event) => event.phraseId).toList();
    final nextPhrase = _nextPhrase(completedPhraseIds);
    return PracticeResumeInfo(
      activityId: activityId,
      totalPhrases: _activity.phrases.length,
      completedPhraseIds: completedPhraseIds,
      nextPhraseId: nextPhrase?.phraseId,
      lastEventTime: _events.isEmpty ? null : _events.last.clientTimestamp,
    );
  }

  @override
  Future<InteractionEventPayload> recordReaction({
    required String spaceId,
    required String activityId,
    required String phraseId,
    required BabyReactionType reactionType,
    DateTime? clientTimestamp,
    String? localEventId,
  }) async {
    final event = InteractionEventPayload(
      localEventId: localEventId ?? 'memory_event_${_events.length + 1}',
      installationId: 'memory_onboarding_screen_test',
      spaceId: spaceId,
      activityId: activityId,
      phraseId: phraseId,
      reactionType: reactionType,
      clientTimestamp: clientTimestamp ?? DateTime.utc(2026, 7, 24),
    );
    _events.add(event);
    return event;
  }

  PracticePhrase? _nextPhrase(List<String> completedPhraseIds) {
    for (final phrase in _activity.phrases) {
      if (!completedPhraseIds.contains(phrase.phraseId)) {
        return phrase;
      }
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
