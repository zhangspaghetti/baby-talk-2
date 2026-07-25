import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/router/account_entry_route_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
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
    late _ControllableOnboardingFlowStore flowStore;
    late _ControllableOnboardingSnapshotStore snapshotStore;
    late _ControllableAuthContinuationStore continuationStore;
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
      flowStore = _ControllableOnboardingFlowStore();
      snapshotStore = _ControllableOnboardingSnapshotStore();
      continuationStore = _ControllableAuthContinuationStore();
      onboardingRepository = OnboardingRepository(
        snapshotStore: snapshotStore,
        flowStore: flowStore,
      );
      notifier = OnboardingFlowNotifier(
        onboardingRepository: onboardingRepository,
        practiceRepository: practiceHarness.repository,
        carePathNotifier: carePathNotifier,
        accountNotifier: AccountNotifier(repository: _FakeAccountRepository()),
        authContinuationCoordinator: AuthContinuationCoordinator(
          store: continuationStore,
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
      'flow persistence failure keeps the current step and shows recovery',
      () async {
        final failingRepository = OnboardingRepository(
          snapshotStore: OnboardingSnapshotStore(
            directoryResolver: () async => tempDir,
          ),
          flowStore: _FailingOnboardingFlowStore(),
        );
        final failingNotifier = OnboardingFlowNotifier(
          onboardingRepository: failingRepository,
          practiceRepository: practiceHarness.repository,
          carePathNotifier: carePathNotifier,
          accountNotifier: AccountNotifier(
            repository: _FakeAccountRepository(),
          ),
          authContinuationCoordinator: AuthContinuationCoordinator(
            store: AuthContinuationStore(
              directoryResolver: () async => tempDir,
            ),
          ),
          clock: () => DateTime.utc(2026, 7, 24, 12),
        );
        addTearDown(failingNotifier.dispose);

        await failingNotifier.initialize();
        await failingNotifier.continueFromWelcome();

        expect(failingNotifier.step, OnboardingFlowStep.welcome);
        expect(failingNotifier.message, '暂时无法保存引导进度，请再试一次。');
      },
    );

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
      'moment transition persistence failure does not start the Care Path',
      () async {
        await _advanceToCurrentMoment(notifier);
        flowStore.failOnWrite = flowStore.writeCount + 1;

        await notifier.selectCurrentMoment(_bedtimeChoice);

        expect(scriptedCarePathRepository.startMomentCalls, 0);
        expect(notifier.step, OnboardingFlowStep.currentMoment);
        expect(notifier.message, '暂时无法保存引导进度，请再试一次。');
      },
    );

    test(
      'starter phrase persistence failure recovers in place before recording reaction',
      () async {
        await _advanceToCurrentMoment(notifier);
        flowStore.failOnWrite = flowStore.writeCount + 2;

        await notifier.selectCurrentMoment(_bedtimeChoice);

        expect(notifier.step, OnboardingFlowStep.careTurn);
        expect(notifier.flowSnapshot.starterPhraseId, isNull);
        expect(notifier.careTurn?.currentUtterance, _starterUtterance);
        expect(notifier.hasPendingStarterPhrasePersistence, isTrue);

        notifier.markSaid();
        await notifier.selectReaction(BabyReactionType.hesitant);

        expect(scriptedCarePathRepository.receivedLocalEventIds, isEmpty);

        flowStore.failOnWrite = null;
        await notifier.retryPersistStarterPhrase();

        expect(
          notifier.flowSnapshot.starterPhraseId,
          _starterUtterance.phraseId,
        );
        expect(notifier.hasPendingStarterPhrasePersistence, isFalse);

        await notifier.selectReaction(BabyReactionType.hesitant);

        expect(scriptedCarePathRepository.receivedLocalEventIds, <String?>[
          'evt_onboarding_fixed',
        ]);
      },
    );

    test(
      'rapid scene selections are serialized without dropping either choice',
      () async {
        await notifier.initialize();
        await notifier.continueFromWelcome();
        await notifier.selectAgeBucket(OnboardingAgeBucket.oneToTwo);
        await notifier.continueFromAge();
        final activityIds = notifier.availableMoments
            .map((moment) => moment.activityId)
            .toSet()
            .take(2)
            .toList(growable: false);

        expect(activityIds, hasLength(2));
        await Future.wait(<Future<void>>[
          notifier.toggleScenePreference(activityIds[0]),
          notifier.toggleScenePreference(activityIds[1]),
        ]);

        expect(
          notifier.flowSnapshot.selectedSceneIds,
          containsAll(activityIds),
        );
      },
    );

    test('rapid moment choices leave one coherent saved Care Turn', () async {
      await _advanceToCurrentMoment(notifier);
      final alternateMoment = notifier.availableMoments.firstWhere(
        (moment) => moment.activityId != _bedtimeChoice.activityId,
      );

      await Future.wait(<Future<void>>[
        notifier.selectCurrentMoment(_bedtimeChoice),
        notifier.selectCurrentMoment(alternateMoment),
      ]);

      expect(scriptedCarePathRepository.startedMomentRequests, <String>[
        '${_bedtimeChoice.spaceId}/${_bedtimeChoice.activityId}',
      ]);
      expect(notifier.flowSnapshot.selectedSpaceId, _bedtimeChoice.spaceId);
      expect(
        notifier.flowSnapshot.selectedActivityId,
        _bedtimeChoice.activityId,
      );
      expect(notifier.careTurn?.moment.activityId, _bedtimeChoice.activityId);
      expect(notifier.flowSnapshot.starterPhraseId, _starterUtterance.phraseId);
    });

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

    test(
      'pending event identity persistence failure does not record a reaction',
      () async {
        await _advanceToCareTurn(notifier);
        notifier.markSaid();
        flowStore.failOnWrite = flowStore.writeCount + 1;

        await notifier.selectReaction(BabyReactionType.hesitant);

        expect(scriptedCarePathRepository.receivedLocalEventIds, isEmpty);
        expect(notifier.flowSnapshot.pendingLocalEventId, isNull);
        expect(notifier.message, '暂时无法保存引导进度，请再试一次。');
      },
    );

    test(
      'confirmed trace persistence failure stays retryable until it is saved',
      () async {
        await _advanceToCareTurn(notifier);
        notifier.markSaid();
        flowStore.failOnWrite = flowStore.writeCount + 2;

        await notifier.selectReaction(BabyReactionType.hesitant);

        expect(notifier.careTurn?.traceEventKey, isNotEmpty);
        expect(notifier.flowSnapshot.hasConfirmedTrace, isFalse);
        expect(notifier.hasPendingTracePersistence, isTrue);

        await notifier.continueFromCareTurn();
        expect(notifier.step, OnboardingFlowStep.careTurn);

        flowStore.failOnWrite = null;
        await notifier.retryPersistConfirmedCareTurn();

        expect(notifier.flowSnapshot.hasConfirmedTrace, isTrue);
        expect(notifier.flowSnapshot.pendingLocalEventId, isNull);
        expect(notifier.hasPendingTracePersistence, isFalse);
      },
    );

    test(
      'confirmed event plus unavailable Garden waits for next-support acknowledgement',
      () async {
        await _advanceToCareTurn(notifier);
        notifier.markSaid();
        scriptedCarePathRepository.nextSnapshot = _nextSupportSnapshot();

        await notifier.selectReaction(BabyReactionType.noResponse);

        expect(notifier.step, OnboardingFlowStep.careTurn);
        expect(notifier.flowSnapshot.traceEventKey, isNotEmpty);
        expect(notifier.gardenTraceDegraded, isTrue);
        await notifier.continueFromCareTurn();

        expect(notifier.step, OnboardingFlowStep.trace);
      },
    );

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

    test(
      'confirmed next-support state promotes its Garden trace after restart',
      () async {
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
          accountNotifier: AccountNotifier(
            repository: _FakeAccountRepository(),
          ),
          authContinuationCoordinator: AuthContinuationCoordinator(
            store: AuthContinuationStore(
              directoryResolver: () async => tempDir,
            ),
          ),
          clock: () => DateTime.utc(2026, 7, 24, 12),
          localEventIdGenerator: () => 'evt_onboarding_fixed',
        );
        addTearDown(resumedNotifier.dispose);
        addTearDown(resumedCarePathNotifier.dispose);

        await resumedNotifier.initialize();

        expect(resumedNotifier.step, OnboardingFlowStep.trace);
        expect(resumedNotifier.gardenTraceDegraded, isFalse);
      },
    );

    test(
      'restart reconciles a persisted pending event before loading the next phrase',
      () async {
        await _advanceToCareTurn(notifier);
        notifier.markSaid();
        final pendingSnapshot = notifier.flowSnapshot.copyWith(
          pendingLocalEventId: 'evt_onboarding_recovery',
          selectedReaction: BabyReactionType.hesitant,
        );
        await onboardingRepository.saveFlowSnapshot(pendingSnapshot);
        final persistedEvent = await practiceHarness.repository.recordReaction(
          spaceId: pendingSnapshot.selectedSpaceId!,
          activityId: pendingSnapshot.selectedActivityId!,
          phraseId: pendingSnapshot.starterPhraseId!,
          reactionType: pendingSnapshot.selectedReaction!,
          clientTimestamp: DateTime.utc(2026, 7, 24, 12),
          localEventId: pendingSnapshot.pendingLocalEventId,
        );

        final resumedCarePathNotifier = CarePathNotifier(
          repository: CarePathRepository(
            practiceRepository: practiceHarness.repository,
          ),
        );
        final resumedNotifier = OnboardingFlowNotifier(
          onboardingRepository: onboardingRepository,
          practiceRepository: practiceHarness.repository,
          carePathNotifier: resumedCarePathNotifier,
          accountNotifier: AccountNotifier(
            repository: _FakeAccountRepository(),
          ),
          authContinuationCoordinator: AuthContinuationCoordinator(
            store: AuthContinuationStore(
              directoryResolver: () async => tempDir,
            ),
          ),
          clock: () => DateTime.utc(2026, 7, 24, 12),
          localEventIdGenerator: () => 'evt_onboarding_recovery',
        );
        addTearDown(resumedNotifier.dispose);
        addTearDown(resumedCarePathNotifier.dispose);

        await resumedNotifier.initialize();

        expect(resumedNotifier.flowSnapshot.pendingLocalEventId, isNull);
        expect(resumedNotifier.flowSnapshot.traceEventKey, isNotEmpty);
        expect(
          resumedNotifier.careTurn?.traceEventKey,
          persistedEvent.eventKey,
        );
        expect(
          resumedNotifier.careTurn?.currentUtterance?.phraseId,
          pendingSnapshot.starterPhraseId,
        );
      },
    );

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
        await original.continueFromCareTurn();

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
        await notifier.continueFromCareTurn();
        await notifier.continueFromTrace();

        final completed = (await notifier.chooseLocalOnly())!;

        expect(completed.starterSpaceId, 'family_rhythm');
        expect(completed.starterActivityId, 'bedtime');
        expect(completed.starterPhraseId, 'bedtime_dim_the_lights');
        expect(completed.firstTraceEventKey, isNotEmpty);
        expect(await onboardingRepository.readFlowSnapshot(), isNull);
      },
    );

    test('local-only completion write failure stays retryable', () async {
      await _advanceToAccountInvitation(notifier);
      snapshotStore.failOnWrite = snapshotStore.writeCount + 1;

      final failed = await notifier.chooseLocalOnly();

      expect(failed, isNull);
      expect(notifier.message, '暂时无法完成引导，请再试一次。');
      expect(await onboardingRepository.readCompletedSnapshot(), isNull);

      snapshotStore.failOnWrite = null;
      final completed = await notifier.chooseLocalOnly();

      expect(completed, isNotNull);
      expect(await onboardingRepository.readCompletedSnapshot(), isNotNull);
    });

    test(
      'continuation write failure does not allow entering account',
      () async {
        await _advanceToAccountInvitation(notifier);
        continuationStore.failOnWrite = true;

        final completed = await notifier.beginAccountSave();

        expect(completed, isNull);
        expect(notifier.canOpenAccountEntry, isFalse);
        expect(notifier.message, '暂时无法保存账号继续状态，请再试一次。');
        expect(
          await AuthContinuationCoordinator(
            store: continuationStore,
          ).readPending(),
          isNull,
        );
      },
    );

    test(
      'duplicate account saves share one continuation write and navigation',
      () async {
        await _advanceToAccountInvitation(notifier);
        final writeGate = Completer<void>();
        continuationStore.writeGate = writeGate;

        final first = notifier.beginAccountSave();
        final second = notifier.beginAccountSave();

        expect(continuationStore.writeCount, 1);
        expect(notifier.isBusy, isTrue);

        writeGate.complete();
        await Future.wait(<Future<OnboardingSnapshot?>>[first, second]);

        expect(continuationStore.writeCount, 1);
        expect(notifier.takeAccountEntryNavigation(), isTrue);
        expect(notifier.takeAccountEntryNavigation(), isFalse);
      },
    );

    test(
      'first account exit action excludes a concurrent local completion',
      () async {
        await _advanceToAccountInvitation(notifier);
        final writeGate = Completer<void>();
        continuationStore.writeGate = writeGate;

        final accountSave = notifier.beginAccountSave();
        final localOnly = notifier.chooseLocalOnly();

        expect(continuationStore.writeCount, 1);
        expect(snapshotStore.writeCount, 0);

        writeGate.complete();
        final results = await Future.wait(<Future<OnboardingSnapshot?>>[
          accountSave,
          localOnly,
        ]);

        expect(results, everyElement(isNull));
        expect(snapshotStore.writeCount, 0);
        expect(notifier.takeAccountEntryNavigation(), isTrue);
      },
    );

    test(
      'continuation read I/O failures stay visible on return and recovery',
      () async {
        await _advanceToAccountInvitation(notifier);
        continuationStore.readStatus = AuthContinuationReadStatus.ioFailure;
        final signedInAccountNotifier = AccountNotifier(
          repository: _SignedInAccountRepository(),
        );
        await signedInAccountNotifier.initialize();
        final returnCarePathNotifier = CarePathNotifier(
          repository: scriptedCarePathRepository,
        );
        final returnNotifier = OnboardingFlowNotifier(
          onboardingRepository: onboardingRepository,
          practiceRepository: practiceHarness.repository,
          carePathNotifier: returnCarePathNotifier,
          accountNotifier: signedInAccountNotifier,
          authContinuationCoordinator: AuthContinuationCoordinator(
            store: continuationStore,
          ),
          clock: () => DateTime.utc(2026, 7, 24, 12),
        );
        addTearDown(returnNotifier.dispose);
        addTearDown(returnCarePathNotifier.dispose);
        addTearDown(signedInAccountNotifier.dispose);

        await returnNotifier.handleAccountReturn(AccountEntryResult.signedIn);

        expect(returnNotifier.message, '暂时无法读取账号继续状态，请再试一次。');

        final recoveryCarePathNotifier = CarePathNotifier(
          repository: scriptedCarePathRepository,
        );
        final recoveryNotifier = OnboardingFlowNotifier(
          onboardingRepository: onboardingRepository,
          practiceRepository: practiceHarness.repository,
          carePathNotifier: recoveryCarePathNotifier,
          accountNotifier: signedInAccountNotifier,
          authContinuationCoordinator: AuthContinuationCoordinator(
            store: continuationStore,
          ),
          clock: () => DateTime.utc(2026, 7, 24, 12),
        );
        addTearDown(recoveryNotifier.dispose);
        addTearDown(recoveryCarePathNotifier.dispose);

        await recoveryNotifier.initialize();

        expect(recoveryNotifier.message, '暂时无法恢复账号继续状态，请稍后再试。');
      },
    );

    test(
      'signed-in account return completes when its continuation has expired',
      () async {
        await _advanceToAccountInvitation(notifier);
        continuationStore.readStatus = AuthContinuationReadStatus.expired;
        final signedInAccountNotifier = AccountNotifier(
          repository: _SignedInAccountRepository(),
        );
        await signedInAccountNotifier.initialize();
        final resumedCarePathNotifier = CarePathNotifier(
          repository: scriptedCarePathRepository,
        );
        final resumedNotifier = OnboardingFlowNotifier(
          onboardingRepository: onboardingRepository,
          practiceRepository: practiceHarness.repository,
          carePathNotifier: resumedCarePathNotifier,
          accountNotifier: signedInAccountNotifier,
          authContinuationCoordinator: AuthContinuationCoordinator(
            store: continuationStore,
          ),
          clock: () => DateTime.utc(2026, 7, 24, 12),
        );
        addTearDown(resumedNotifier.dispose);
        addTearDown(resumedCarePathNotifier.dispose);
        addTearDown(signedInAccountNotifier.dispose);

        await resumedNotifier.initialize();
        final completed = await resumedNotifier.handleAccountReturn(
          AccountEntryResult.signedIn,
        );

        expect(completed, isNotNull);
        expect(resumedNotifier.takeShellNavigation(), isTrue);
      },
    );

    test(
      'completed snapshot survives flow cleanup failure for boot recovery',
      () async {
        await _advanceToAccountInvitation(notifier);
        flowStore.failDelete = true;

        final completed = await notifier.chooseLocalOnly();

        expect(completed, isNotNull);
        expect(await onboardingRepository.readCompletedSnapshot(), completed);
        expect(await onboardingRepository.readFlowSnapshot(), isNotNull);
      },
    );

    test(
      'duplicate local completion requests write one completed snapshot',
      () async {
        await _advanceToAccountInvitation(notifier);

        final results = await Future.wait(<Future<OnboardingSnapshot?>>[
          notifier.chooseLocalOnly(),
          notifier.chooseLocalOnly(),
        ]);

        expect(results[0], isNotNull);
        expect(results[1], same(results[0]));
        expect(snapshotStore.writeCount, 1);
      },
    );

    test(
      'cold restart completes a signed-in continuation once and exposes navigation',
      () async {
        await _advanceToCareTurn(notifier);
        notifier.markSaid();
        await notifier.selectReaction(BabyReactionType.hesitant);
        await notifier.continueFromCareTurn();
        await notifier.continueFromTrace();

        final continuationCoordinator = AuthContinuationCoordinator(
          store: AuthContinuationStore(directoryResolver: () async => tempDir),
        );
        await continuationCoordinator.beginSaveOnboardingMemory();
        final signedInAccountNotifier = AccountNotifier(
          repository: _SignedInAccountRepository(),
        );
        await signedInAccountNotifier.initialize();
        final resumedCarePathNotifier = CarePathNotifier(
          repository: scriptedCarePathRepository,
        );
        final resumedNotifier = OnboardingFlowNotifier(
          onboardingRepository: onboardingRepository,
          practiceRepository: practiceHarness.repository,
          carePathNotifier: resumedCarePathNotifier,
          accountNotifier: signedInAccountNotifier,
          authContinuationCoordinator: continuationCoordinator,
          clock: () => DateTime.utc(2026, 7, 24, 12),
          localEventIdGenerator: () => 'evt_onboarding_fixed',
        );
        addTearDown(resumedNotifier.dispose);
        addTearDown(resumedCarePathNotifier.dispose);
        addTearDown(signedInAccountNotifier.dispose);

        await resumedNotifier.initialize();

        expect(resumedNotifier.takeRecoveredCompletion(), isNotNull);
        expect(resumedNotifier.takeRecoveredCompletion(), isNull);
        expect(await onboardingRepository.readFlowSnapshot(), isNull);
        expect(await continuationCoordinator.readPending(), isNull);
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

Future<void> _advanceToAccountInvitation(
  OnboardingFlowNotifier notifier,
) async {
  await _advanceToCareTurn(notifier);
  notifier.markSaid();
  await notifier.selectReaction(BabyReactionType.hesitant);
  await notifier.continueFromCareTurn();
  await notifier.continueFromTrace();
}

class _ScriptedCarePathRepository extends CarePathRepository {
  _ScriptedCarePathRepository({required super.practiceRepository});

  bool completeReactionWithError = false;
  CareTurnSnapshot nextSnapshot = _nextSupportSnapshot();
  final List<String?> receivedLocalEventIds = <String?>[];
  final List<String> startedMomentRequests = <String>[];
  int startMomentCalls = 0;

  @override
  Future<CareTurnSnapshot> startMoment({
    required String spaceId,
    required String activityId,
  }) async {
    startMomentCalls += 1;
    startedMomentRequests.add('$spaceId/$activityId');
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

class _SignedInAccountRepository implements AccountRepositoryContract {
  final AccountLocalSnapshot _snapshot = AccountLocalSnapshot(
    consentState: AccountConsentState.acceptedPendingSync,
    session: AccountSession(
      accountId: 'acct-onboarding-notifier',
      sessionId: 'session-onboarding-notifier',
      maskedPhoneNumber: '138****8000',
      createdAt: DateTime.utc(2026, 7, 24, 12),
    ),
    lastSyncPhase: 'synced',
  );

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
  Future<AccountLocalSnapshot> loadSnapshot() async => _snapshot;

  @override
  Future<AccountLocalSnapshot> refreshRuntimeState({
    required AccountRuntimeTrigger trigger,
    AccountLocalSnapshot? seedSnapshot,
    bool forceBootstrap = false,
  }) async => _snapshot;

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

class _FailingOnboardingFlowStore extends OnboardingFlowStore {
  _FailingOnboardingFlowStore() : super();

  @override
  Future<OnboardingFlowSnapshot?> read() async => null;

  @override
  Future<void> write(OnboardingFlowSnapshot snapshot) =>
      Future<void>.error(StateError('disk unavailable'));

  @override
  Future<void> deleteIfExists() async {}
}

class _ControllableOnboardingFlowStore extends OnboardingFlowStore {
  _ControllableOnboardingFlowStore() : super();

  OnboardingFlowSnapshot? _snapshot;
  int writeCount = 0;
  int? failOnWrite;
  bool failDelete = false;

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
    if (failDelete) {
      throw StateError('disk unavailable');
    }
    _snapshot = null;
  }
}

class _ControllableOnboardingSnapshotStore extends OnboardingSnapshotStore {
  _ControllableOnboardingSnapshotStore() : super();

  OnboardingSnapshot? _snapshot;
  int writeCount = 0;
  int? failOnWrite;

  @override
  Future<OnboardingSnapshot?> read() async => _snapshot;

  @override
  Future<void> write(OnboardingSnapshot snapshot) async {
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

class _ControllableAuthContinuationStore extends AuthContinuationStore {
  _ControllableAuthContinuationStore() : super();

  AuthContinuation? _continuation;
  bool failOnWrite = false;
  int writeCount = 0;
  Completer<void>? writeGate;
  AuthContinuationReadStatus readStatus = AuthContinuationReadStatus.available;

  @override
  Future<AuthContinuation?> read({required DateTime now}) async {
    return _continuation;
  }

  @override
  Future<AuthContinuationReadResult> readResult({required DateTime now}) async {
    return AuthContinuationReadResult(
      status: readStatus,
      continuation: readStatus == AuthContinuationReadStatus.available
          ? _continuation
          : null,
    );
  }

  @override
  Future<void> write(AuthContinuation continuation) async {
    writeCount += 1;
    final gate = writeGate;
    if (gate != null) {
      await gate.future;
    }
    if (failOnWrite) {
      throw StateError('disk unavailable');
    }
    _continuation = continuation;
  }

  @override
  Future<void> deleteIfExists() async {
    _continuation = null;
  }
}
