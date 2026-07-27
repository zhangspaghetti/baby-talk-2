import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/local/auth_continuation_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
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
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/garden_growth_repository.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

import '../support/isar_test_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): resolveBundledIsarLibraryPath()},
    );
  });

  group('M1 first care-turn integration', () {
    test(
      'a fresh local flow reaches Today through one real bedtime trace',
      () async {
        final harness = await _M1FirstCareTurnHarness.create(
          suffix: 'first_trace',
          localEventId: 'evt_m1_first_care_turn',
        );
        addTearDown(harness.dispose);

        expect(await harness.practiceRepository.listEventHistory(), isEmpty);

        await harness.flow.initialize();
        await harness.flow.continueFromWelcome();
        await harness.flow.selectAgeBucket(OnboardingAgeBucket.oneToTwo);
        await harness.flow.continueFromAge();
        await harness.flow.toggleScenePreference('bedtime');
        await harness.flow.continueFromScenePreferences();
        await harness.flow.selectSupportGoal(OnboardingSupportGoal.moreNatural);
        await harness.flow.continueFromSupportGoal();

        final bedtimeChoice = harness.flow.availableMoments.singleWhere(
          (moment) =>
              moment.spaceId == 'family_rhythm' &&
              moment.activityId == 'bedtime',
        );
        await harness.flow.selectCurrentMoment(bedtimeChoice);
        expect(harness.flow.step, OnboardingFlowStep.careTurn);
        expect(
          harness.flow.careTurn?.currentUtterance?.phraseId,
          'bedtime_dim_the_lights',
        );

        harness.flow.markSaid();
        expect(harness.flow.careTurn?.phase, CareTurnPhase.reactionPrompt);
        await harness.flow.selectReaction(BabyReactionType.hesitant);
        expect(harness.flow.step, OnboardingFlowStep.careTurn);
        expect(harness.flow.flowSnapshot.traceEventKey, isNotEmpty);

        await harness.flow.continueFromCareTurn();
        expect(harness.flow.step, OnboardingFlowStep.trace);
        await harness.flow.continueFromTrace();
        final completed = (await harness.flow.chooseLocalOnly())!;

        final events = await harness.practiceRepository.listEventHistory();
        expect(events, hasLength(1));
        expect(events.single.reactionType, BabyReactionType.hesitant);
        expect(completed.firstTraceEventKey, events.single.eventKey);
        expect(completed.starterSpaceId, 'family_rhythm');
        expect(completed.starterActivityId, 'bedtime');
        expect(completed.starterPhraseId, 'bedtime_dim_the_lights');

        final continuity = await harness.carePathRepository.loadCurrentTurn(
          starterSpaceId: completed.starterSpaceId,
          starterActivityId: completed.starterActivityId,
        );
        expect(continuity.moment.activityId, 'bedtime');
      },
    );

    test('a repeated local event ID stores one real reaction event', () async {
      final harness = await _M1FirstCareTurnHarness.create(
        suffix: 'same_event_id',
        localEventId: 'evt_m1_same_event',
      );
      addTearDown(harness.dispose);

      final turn = await harness.carePathRepository.startMoment(
        spaceId: 'family_rhythm',
        activityId: 'bedtime',
      );
      final prompted = turn.copyWith(phase: CareTurnPhase.reactionPrompt);

      final first = await harness.carePathRepository.recordReaction(
        turn: prompted,
        reactionType: BabyReactionType.hesitant,
        localEventId: 'evt_m1_same_event',
      );
      final retry = await harness.carePathRepository.recordReaction(
        turn: prompted,
        reactionType: BabyReactionType.hesitant,
        localEventId: 'evt_m1_same_event',
      );

      final events = await harness.practiceRepository.listEventHistory();
      expect(events, hasLength(1));
      expect(events.single.localEventId, 'evt_m1_same_event');
      expect(events.single.reactionType, BabyReactionType.hesitant);
      expect(retry.traceEventKey, first.traceEventKey);
    });

    test(
      'a written reaction whose response is lost reconciles after notifier recreation',
      () async {
        var responseLossCalls = 0;
        final harness = await _M1FirstCareTurnHarness.create(
          suffix: 'response_lost_recovery',
          localEventId: 'evt_m1_response_lost',
          onReactionRecorded: (_) async {
            responseLossCalls += 1;
            if (responseLossCalls == 1) {
              throw const CarePathResponseLostException();
            }
          },
        );
        addTearDown(harness.dispose);

        await harness.flow.initialize();
        await harness.flow.continueFromWelcome();
        await harness.flow.selectAgeBucket(OnboardingAgeBucket.oneToTwo);
        await harness.flow.continueFromAge();
        await harness.flow.toggleScenePreference('bedtime');
        await harness.flow.continueFromScenePreferences();
        await harness.flow.selectSupportGoal(OnboardingSupportGoal.moreNatural);
        await harness.flow.continueFromSupportGoal();
        final bedtimeChoice = harness.flow.availableMoments.singleWhere(
          (moment) => moment.activityId == 'bedtime',
        );
        await harness.flow.selectCurrentMoment(bedtimeChoice);
        harness.flow.markSaid();
        await harness.flow.selectReaction(BabyReactionType.hesitant);

        expect(harness.carePathNotifier.phase, CareTurnPhase.error);
        expect(harness.flow.careTurn?.message, '刚才的回应可能已经保存，正在确认。请再试一次。');
        expect(
          harness.flow.flowSnapshot.pendingLocalEventId,
          'evt_m1_response_lost',
        );
        expect(
          harness.flow.flowSnapshot.selectedReaction,
          BabyReactionType.hesitant,
        );
        final beforeRestart = await harness.practiceRepository
            .listEventHistory();
        expect(beforeRestart, hasLength(1));
        expect(beforeRestart.single.localEventId, 'evt_m1_response_lost');

        harness.disposeOriginalNotifiers();
        final recoveredCarePathNotifier = CarePathNotifier(
          repository: CarePathRepository(
            practiceRepository: harness.practiceRepository,
            gardenGrowthRepository: GardenGrowthRepository(
              practiceRepository: harness.practiceRepository,
              assetPhraseService: harness.assetPhraseService,
            ),
          ),
        );
        final recoveredFlow = OnboardingFlowNotifier(
          onboardingRepository: harness.onboardingRepository,
          practiceRepository: harness.practiceRepository,
          carePathNotifier: recoveredCarePathNotifier,
          accountNotifier: harness.accountNotifier,
          authContinuationCoordinator: AuthContinuationCoordinator(
            store: AuthContinuationStore(
              directoryResolver: () async => harness.tempDirectory,
            ),
          ),
          clock: () => DateTime.utc(2026, 7, 24, 12),
          localEventIdGenerator: () => 'evt_m1_response_lost',
        );
        addTearDown(() {
          recoveredFlow.dispose();
          recoveredCarePathNotifier.dispose();
        });

        await recoveredFlow.initialize();

        final afterRestart = await harness.practiceRepository
            .listEventHistory();
        expect(afterRestart, hasLength(1));
        expect(afterRestart.single.localEventId, 'evt_m1_response_lost');
        expect(recoveredFlow.flowSnapshot.pendingLocalEventId, isNull);
        expect(
          recoveredFlow.flowSnapshot.traceEventKey,
          afterRestart.single.eventKey,
        );
        expect(recoveredFlow.careTurn?.phase, CareTurnPhase.nextSupportReady);
        expect(recoveredFlow.careTurn?.nextSupportUtterance, isNotNull);
        expect(recoveredFlow.careTurn?.latestGardenImpact, isNotNull);
      },
    );
  });
}

class _M1FirstCareTurnHarness {
  _M1FirstCareTurnHarness({
    required this.tempDirectory,
    required this.practiceRepository,
    required this.assetPhraseService,
    required this.onboardingRepository,
    required this.carePathRepository,
    required this.carePathNotifier,
    required this.accountNotifier,
    required this.flow,
  });

  final Directory tempDirectory;
  final PracticeRepository practiceRepository;
  final AssetPhraseService assetPhraseService;
  final OnboardingRepository onboardingRepository;
  final CarePathRepository carePathRepository;
  final CarePathNotifier carePathNotifier;
  final AccountNotifier accountNotifier;
  final OnboardingFlowNotifier flow;
  var _originalNotifiersDisposed = false;

  void disposeOriginalNotifiers() {
    if (_originalNotifiersDisposed) {
      return;
    }
    _originalNotifiersDisposed = true;
    flow.dispose();
    carePathNotifier.dispose();
  }

  static Future<_M1FirstCareTurnHarness> create({
    required String suffix,
    required String localEventId,
    CarePathReactionRecordedHook? onReactionRecorded,
  }) async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'm1_first_care_turn_$suffix',
    );
    final assetPhraseService = AssetPhraseService(bundle: rootBundle);
    final practiceRepository = PracticeRepository(
      assetPhraseService: assetPhraseService,
      localDataSource: await PracticeLocalDataSource.open(
        directory: tempDirectory.path,
        name: 'm1_first_care_turn_$suffix',
      ),
      installationIdService: InstallationIdService(
        directoryResolver: () async => tempDirectory,
        idGenerator: () => 'install_m1_first_care_turn_$suffix',
      ),
    );
    final gardenGrowthRepository = GardenGrowthRepository(
      practiceRepository: practiceRepository,
      assetPhraseService: assetPhraseService,
    );
    final carePathRepository = CarePathRepository(
      practiceRepository: practiceRepository,
      gardenGrowthRepository: gardenGrowthRepository,
      onReactionRecorded: onReactionRecorded,
    );
    final carePathNotifier = CarePathNotifier(repository: carePathRepository);
    final onboardingRepository = OnboardingRepository(
      snapshotStore: OnboardingSnapshotStore(
        directoryResolver: () async => tempDirectory,
      ),
      flowStore: OnboardingFlowStore(
        directoryResolver: () async => tempDirectory,
      ),
    );
    final accountNotifier = AccountNotifier(
      repository: AccountRepository(
        localStore: AccountLocalStore(storageKey: 'm1_first_care_turn_$suffix'),
        practiceRepository: practiceRepository,
      ),
    );
    final flow = OnboardingFlowNotifier(
      onboardingRepository: onboardingRepository,
      practiceRepository: practiceRepository,
      carePathNotifier: carePathNotifier,
      accountNotifier: accountNotifier,
      authContinuationCoordinator: AuthContinuationCoordinator(
        store: AuthContinuationStore(
          directoryResolver: () async => tempDirectory,
        ),
      ),
      clock: () => DateTime.utc(2026, 7, 24, 12),
      localEventIdGenerator: () => localEventId,
    );
    return _M1FirstCareTurnHarness(
      tempDirectory: tempDirectory,
      practiceRepository: practiceRepository,
      assetPhraseService: assetPhraseService,
      onboardingRepository: onboardingRepository,
      carePathRepository: carePathRepository,
      carePathNotifier: carePathNotifier,
      accountNotifier: accountNotifier,
      flow: flow,
    );
  }

  Future<void> dispose() async {
    disposeOriginalNotifiers();
    accountNotifier.dispose();
    await practiceRepository.close(deleteFromDisk: true);
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  }
}
