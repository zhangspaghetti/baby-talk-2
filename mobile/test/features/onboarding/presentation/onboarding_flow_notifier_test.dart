import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/local/auth_continuation_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository_contract.dart';
import 'package:mobile/features/account/presentation/account_notifier.dart';
import 'package:mobile/features/account/presentation/auth_continuation_coordinator.dart';
import 'package:mobile/features/care_path/data/repositories/care_path_repository.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/care_path/presentation/care_path_notifier.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_flow_store.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_flow_models.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_flow_notifier.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';

import '../../practice/practice_repository_characterization_harness.dart';

const _bedtimeMoment = CareMoment(
  spaceId: 'family_rhythm',
  activityId: 'bedtime',
  spaceTitle: '家庭节奏',
  title: '睡前时间',
  sceneTag: 'Bedtime',
  careActionLabel: 'Get ready for sleep.',
  coachTip: 'Say it while dimming the lights.',
  nodeState: CarePathNodeState.current,
);

const _starterUtterance = CareUtterance(
  phraseId: 'bedtime_dim_the_lights',
  english: 'Let’s dim the lights.',
  chinese: '我们把灯调暗一点。',
  pronunciation: 'lets dim the lights',
  audioAsset: 'assets/audio/bedtime_dim_the_lights.mp3',
  whenToSay: '调暗灯光时说。',
  isFallback: false,
);

const _supportUtterance = CareUtterance(
  phraseId: 'bedtime_take_it_slowly',
  english: 'We can take it slowly.',
  chinese: '我们可以慢慢来。',
  pronunciation: 'we can take it slowly',
  audioAsset: 'assets/audio/bedtime_take_it_slowly.mp3',
  whenToSay: '宝宝犹豫或抗拒时说。',
  isFallback: false,
);

CareTurnSnapshot _starterSnapshot() => const CareTurnSnapshot(
  moment: _bedtimeMoment,
  currentUtterance: _starterUtterance,
  selectedReaction: null,
  nextSupportUtterance: null,
  phase: CareTurnPhase.utteranceReady,
  traceEventKey: null,
  latestGardenImpact: null,
  message: null,
);

CareTurnSnapshot _nextSupportSnapshot({LatestPracticeImpact? gardenImpact}) =>
    CareTurnSnapshot(
      moment: _bedtimeMoment,
      currentUtterance: _starterUtterance,
      selectedReaction: BabyReactionType.hesitant,
      nextSupportUtterance: _supportUtterance,
      phase: CareTurnPhase.nextSupportReady,
      traceEventKey: 'trace_onboarding_1',
      latestGardenImpact: gardenImpact,
      message: null,
    );

final _gardenImpact = LatestPracticeImpact(
  eventKey: 'trace_onboarding_1',
  occurredAt: DateTime.utc(2026, 7, 24, 12),
  spaceId: 'family_rhythm',
  spaceTitle: '家庭节奏',
  activityId: 'bedtime',
  activityTitle: '睡前时间',
  phraseId: 'bedtime_dim_the_lights',
  phraseTitle: 'Let’s dim the lights.',
  reactionType: BabyReactionType.hesitant,
  previousPatchStage: GardenPatchStage.quiet,
  currentPatchStage: GardenPatchStage.tended,
  previousFlowerStage: GardenFlowerStage.seed,
  currentFlowerStage: GardenFlowerStage.sprout,
  headline: '照护记录已保存。',
  detail: '花园有了新的变化。',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ensurePracticeRepositoryHarnessIsarInitialized);

  group('OnboardingFlowNotifier', () {
    late Directory tempDir;
    late PracticeRepositoryCharacterizationHarness practiceHarness;
    late _ScriptedCarePathRepository scriptedCarePathRepository;
    late CarePathNotifier carePathNotifier;
    late OnboardingRepository onboardingRepository;
    late OnboardingFlowNotifier notifier;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('onboarding_flow_');
      practiceHarness =
          await PracticeRepositoryCharacterizationHarness.create();
      scriptedCarePathRepository = _ScriptedCarePathRepository(
        practiceRepository: practiceHarness.repository,
      );
      carePathNotifier = CarePathNotifier(
        repository: scriptedCarePathRepository,
      );
      onboardingRepository = OnboardingRepository(
        snapshotStore: OnboardingSnapshotStore(
          directoryResolver: () async => tempDir,
        ),
        flowStore: OnboardingFlowStore(directoryResolver: () async => tempDir),
        practiceRepository: practiceHarness.repository,
        starterSpaceId: _bedtimeMoment.spaceId,
        starterActivityId: _bedtimeMoment.activityId,
      );
      notifier = OnboardingFlowNotifier(
        onboardingRepository: onboardingRepository,
        practiceRepository: practiceHarness.repository,
        carePathNotifier: carePathNotifier,
        accountNotifier: AccountNotifier(repository: _FakeAccountRepository()),
        authContinuationCoordinator: AuthContinuationCoordinator(
          store: AuthContinuationStore(directoryResolver: () async => tempDir),
        ),
        clock: () => DateTime.utc(2026, 7, 24, 12),
        localEventIdGenerator: () => 'evt_onboarding_fixed',
      );
    });

    tearDown(() async {
      notifier.dispose();
      carePathNotifier.dispose();
      await practiceHarness.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'cannot advance without required age, scenes, goal, and moment',
      () async {
        await notifier.initialize();
        expect(notifier.step, OnboardingFlowStep.welcome);

        await notifier.continueFromWelcome();
        expect(notifier.step, OnboardingFlowStep.age);

        await notifier.continueFromAge();
        expect(notifier.step, OnboardingFlowStep.age);
        expect(notifier.message, '先选一个适合宝宝的年龄范围。');
      },
    );

    test('scene CTA uses the approved required-selection copy', () async {
      await notifier.initialize();
      await notifier.continueFromWelcome();
      await notifier.selectAgeBucket(OnboardingAgeBucket.oneToTwo);
      await notifier.continueFromAge();

      await notifier.continueFromScenePreferences();

      expect(notifier.step, OnboardingFlowStep.scenePreferences);
      expect(notifier.message, '至少选一个常见照护时刻。');
    });

    test(
      'selected moment starts the formal Care Path and stores phrase id',
      () async {
        await _advanceToCurrentMoment(notifier);

        await notifier.selectCurrentMoment(_bedtimeChoice);

        expect(notifier.step, OnboardingFlowStep.careTurn);
        expect(notifier.careTurn?.moment.activityId, 'bedtime');
        expect(notifier.flowSnapshot.starterPhraseId, 'bedtime_dim_the_lights');
      },
    );

    test(
      'reaction persists local ID before write and retry reuses it',
      () async {
        await _advanceToCareTurn(notifier);
        notifier.markSaid();
        scriptedCarePathRepository.completeReactionWithError = true;

        await notifier.selectReaction(BabyReactionType.resisting);
        final firstId = notifier.flowSnapshot.pendingLocalEventId;

        scriptedCarePathRepository.completeReactionWithError = false;
        await notifier.selectReaction(BabyReactionType.resisting);

        expect(firstId, 'evt_onboarding_fixed');
        expect(scriptedCarePathRepository.receivedLocalEventIds, <String?>[
          firstId,
          firstId,
        ]);
      },
    );

    test('confirmed event plus unavailable Garden advances to trace', () async {
      await _advanceToCareTurn(notifier);
      notifier.markSaid();
      scriptedCarePathRepository.nextSnapshot = _nextSupportSnapshot();

      await notifier.selectReaction(BabyReactionType.noResponse);

      expect(notifier.step, OnboardingFlowStep.trace);
      expect(notifier.flowSnapshot.traceEventKey, isNotEmpty);
      expect(notifier.gardenTraceDegraded, isTrue);
    });

    test(
      'concurrent reaction requests share one persisted event write',
      () async {
        await _advanceToCareTurn(notifier);
        notifier.markSaid();

        await Future.wait(<Future<void>>[
          notifier.selectReaction(BabyReactionType.hesitant),
          notifier.selectReaction(BabyReactionType.hesitant),
        ]);

        expect(scriptedCarePathRepository.receivedLocalEventIds, <String?>[
          'evt_onboarding_fixed',
        ]);
      },
    );

    test('normal Garden trace state survives a restart', () async {
      await _advanceToCareTurn(notifier);
      notifier.markSaid();
      scriptedCarePathRepository.nextSnapshot = _nextSupportSnapshot(
        gardenImpact: _gardenImpact,
      );
      await notifier.selectReaction(BabyReactionType.hesitant);

      expect(notifier.gardenTraceDegraded, isFalse);

      final resumedCarePathNotifier = CarePathNotifier(
        repository: scriptedCarePathRepository,
      );
      final resumedNotifier = OnboardingFlowNotifier(
        onboardingRepository: onboardingRepository,
        practiceRepository: practiceHarness.repository,
        carePathNotifier: resumedCarePathNotifier,
        accountNotifier: AccountNotifier(repository: _FakeAccountRepository()),
        authContinuationCoordinator: AuthContinuationCoordinator(
          store: AuthContinuationStore(directoryResolver: () async => tempDir),
        ),
        clock: () => DateTime.utc(2026, 7, 24, 12),
        localEventIdGenerator: () => 'evt_onboarding_fixed',
      );
      addTearDown(resumedNotifier.dispose);
      addTearDown(resumedCarePathNotifier.dispose);

      await resumedNotifier.initialize();

      expect(resumedNotifier.step, OnboardingFlowStep.trace);
      expect(resumedNotifier.gardenTraceDegraded, isFalse);
    });

    test(
      'provider keeps the same flow while Care Path emits trace updates',
      () async {
        final providerCarePathNotifier = CarePathNotifier(
          repository: scriptedCarePathRepository,
        );
        final accountNotifier = AccountNotifier(
          repository: _FakeAccountRepository(),
        );
        final coordinator = AuthContinuationCoordinator(
          store: AuthContinuationStore(directoryResolver: () async => tempDir),
        );
        final container = ProviderContainer(
          overrides: <Override>[
            onboardingRepositoryProvider.overrideWith(
              (ref) async => onboardingRepository,
            ),
            practiceRepositoryProvider.overrideWith(
              (ref) async => practiceHarness.repository,
            ),
            carePathNotifierProvider.overrideWith(
              (ref) => providerCarePathNotifier,
            ),
            accountNotifierProvider.overrideWith((ref) => accountNotifier),
            authContinuationCoordinatorProvider.overrideWithValue(coordinator),
          ],
        );
        addTearDown(container.dispose);

        await container.read(onboardingRepositoryProvider.future);
        await container.read(practiceRepositoryProvider.future);
        final flow = container.read(onboardingFlowNotifierProvider);
        await flow.initialize();
        await _advanceToCareTurn(flow);
        final original = container.read(onboardingFlowNotifierProvider);
        original.markSaid();

        await original.selectReaction(BabyReactionType.hesitant);

        expect(container.read(onboardingFlowNotifierProvider), same(original));
        expect(original.step, OnboardingFlowStep.trace);
        expect(scriptedCarePathRepository.receivedLocalEventIds, hasLength(1));
      },
    );

    test(
      'local completion writes actual starter and clears flow state',
      () async {
        await _advanceToCareTurn(notifier);
        notifier.markSaid();
        await notifier.selectReaction(BabyReactionType.hesitant);
        await notifier.continueFromTrace();

        final completed = await notifier.chooseLocalOnly();

        expect(completed.starterSpaceId, 'family_rhythm');
        expect(completed.starterActivityId, 'bedtime');
        expect(completed.starterPhraseId, 'bedtime_dim_the_lights');
        expect(completed.firstTraceEventKey, isNotEmpty);
        expect(await onboardingRepository.readFlowSnapshot(), isNull);
      },
    );
  });
}

const _bedtimeChoice = OnboardingMomentChoice(
  spaceId: 'family_rhythm',
  activityId: 'bedtime',
  spaceTitle: '家庭节奏',
  title: '睡前时间',
  summary: '准备睡觉',
);

Future<void> _advanceToCurrentMoment(OnboardingFlowNotifier notifier) async {
  await notifier.initialize();
  await notifier.continueFromWelcome();
  await notifier.selectAgeBucket(OnboardingAgeBucket.oneToTwo);
  await notifier.continueFromAge();
  await notifier.toggleScenePreference('bedtime');
  await notifier.continueFromScenePreferences();
  await notifier.selectSupportGoal(OnboardingSupportGoal.moreNatural);
  await notifier.continueFromSupportGoal();
}

Future<void> _advanceToCareTurn(OnboardingFlowNotifier notifier) async {
  await _advanceToCurrentMoment(notifier);
  await notifier.selectCurrentMoment(_bedtimeChoice);
}

class _ScriptedCarePathRepository extends CarePathRepository {
  _ScriptedCarePathRepository({required super.practiceRepository});

  bool completeReactionWithError = false;
  CareTurnSnapshot nextSnapshot = _nextSupportSnapshot();
  final List<String?> receivedLocalEventIds = <String?>[];

  @override
  Future<CareTurnSnapshot> startMoment({
    required String spaceId,
    required String activityId,
  }) async {
    if (spaceId != _bedtimeMoment.spaceId ||
        activityId != _bedtimeMoment.activityId) {
      throw StateError('unexpected moment: $spaceId/$activityId');
    }
    return _starterSnapshot();
  }

  @override
  Future<CareTurnSnapshot> recordReaction({
    required CareTurnSnapshot turn,
    required BabyReactionType reactionType,
    DateTime? clientTimestamp,
    String? localEventId,
  }) async {
    receivedLocalEventIds.add(localEventId);
    if (completeReactionWithError) {
      throw StateError('simulated unknown write result');
    }
    return nextSnapshot.copyWith(selectedReaction: reactionType);
  }
}

class _FakeAccountRepository implements AccountRepositoryContract {
  @override
  Future<void> close() async {}

  @override
  Future<AccountLocalSnapshot> clearPlaceholderSession({
    bool revertToLocalOnly = false,
  }) async => AccountLocalSnapshot.localOnly;

  @override
  Future<AccountLocalSnapshot> deleteAccount({
    String reason = 'forget_me',
  }) async => AccountLocalSnapshot.localOnly;

  @override
  Future<AccountLocalSnapshot> loadSnapshot() async =>
      AccountLocalSnapshot.localOnly;

  @override
  Future<AccountLocalSnapshot> refreshRuntimeState({
    required AccountRuntimeTrigger trigger,
    AccountLocalSnapshot? seedSnapshot,
    bool forceBootstrap = false,
  }) async => AccountLocalSnapshot.localOnly;

  @override
  Future<AccountLocalSnapshot> revokeConsent({
    String reason = 'user_requested',
  }) async => AccountLocalSnapshot.localOnly;

  @override
  Future<AccountLocalSnapshot> signIn({
    required String phoneNumber,
    required String verificationCode,
  }) async => AccountLocalSnapshot.localOnly;
}
