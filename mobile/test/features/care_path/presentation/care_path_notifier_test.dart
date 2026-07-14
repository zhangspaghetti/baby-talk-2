import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/care_path/data/repositories/care_path_repository.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/care_path/presentation/care_path_notifier.dart';
import 'package:mobile/features/care_path/presentation/care_path_view_model.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

import '../../practice/practice_repository_characterization_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ensurePracticeRepositoryHarnessIsarInitialized);

  group('CarePathViewModel', () {
    test('starts idle and derives one-turn state from snapshot', () {
      final idle = CarePathViewModel.idle();

      expect(idle.isIdle, isTrue);
      expect(idle.canSelectReaction, isFalse);
      expect(idle.currentUtterance, isNull);

      const moment = CareMoment(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        spaceTitle: '日常照护',
        title: '洗澡时间',
        sceneTag: 'Bath time',
        careActionLabel: 'Keep bath time warm.',
        coachTip: 'Say it before pouring water.',
        nodeState: CarePathNodeState.current,
      );
      const utterance = CareUtterance(
        phraseId: 'bath_time_warm_water',
        english: 'Warm water.',
        chinese: '水暖暖的。',
        pronunciation: 'wɔːrm ˈwɔːtər',
        audioAsset: 'assets/audio/warm_water.mp3',
        whenToSay: 'Say it before pouring water.',
        isFallback: false,
      );
      const snapshot = CareTurnSnapshot(
        moment: moment,
        currentUtterance: utterance,
        selectedReaction: null,
        nextSupportUtterance: null,
        phase: CareTurnPhase.utteranceReady,
        traceEventKey: null,
        latestGardenImpact: null,
        message: null,
      );

      final ready = CarePathViewModel.fromSnapshot(snapshot);

      expect(ready.moment, moment);
      expect(ready.currentUtterance, utterance);
      expect(ready.phase, CareTurnPhase.utteranceReady);
      expect(ready.canSelectReaction, isFalse);
      expect(ready.hasCurrentUtterance, isTrue);
    });
  });

  group('CarePathNotifier', () {
    late PracticeRepositoryCharacterizationHarness harness;
    late CarePathNotifier notifier;

    setUp(() async {
      harness = await PracticeRepositoryCharacterizationHarness.create();
      notifier = CarePathNotifier(
        repository: CarePathRepository(practiceRepository: harness.repository),
      );
    });

    tearDown(() async {
      notifier.dispose();
      await harness.dispose();
    });

    test('loads current utterance as one-turn state', () async {
      final phases = <CareTurnPhase>[];
      notifier.addListener(() => phases.add(notifier.phase));

      await notifier.loadCurrentUtterance(
        starterSpaceId: 'daily_care',
        starterActivityId: 'bath_time',
      );

      expect(phases.first, CareTurnPhase.loading);
      expect(phases.last, CareTurnPhase.reactionPrompt);
      expect(notifier.viewModel.moment?.activityId, 'bath_time');
      expect(
        notifier.viewModel.currentUtterance?.phraseId,
        'bath_time_warm_water',
      );
      expect(notifier.viewModel.canSelectReaction, isTrue);
      expect(notifier.message, isNull);
    });

    test(
      'markSaid moves utteranceReady into reactionPrompt without writes',
      () async {
        await notifier.startMoment(
          spaceId: 'daily_care',
          activityId: 'bath_time',
        );

        expect(notifier.phase, CareTurnPhase.utteranceReady);
        expect(
          notifier.viewModel.currentUtterance?.phraseId,
          'bath_time_warm_water',
        );

        notifier.markSaid();

        expect(notifier.phase, CareTurnPhase.reactionPrompt);
        expect(
          notifier.viewModel.currentUtterance?.phraseId,
          'bath_time_warm_water',
        );
        expect(notifier.viewModel.selectedReaction, isNull);
        expect(notifier.viewModel.nextSupportUtterance, isNull);
        expect(notifier.viewModel.traceEventKey, isNull);
        expect(notifier.viewModel.latestGardenImpact, isNull);

        final events = await harness.repository.listEventHistory(
          activityId: 'bath_time',
        );
        expect(events, isEmpty);
      },
    );

    test('selectReaction before markSaid does not write', () async {
      await notifier.startMoment(
        spaceId: 'daily_care',
        activityId: 'bath_time',
      );

      await notifier.selectReaction(
        BabyReactionType.other,
        localEventId: 'evt_care_path_notifier_before_mark_said',
      );

      expect(notifier.phase, CareTurnPhase.utteranceReady);
      expect(notifier.viewModel.selectedReaction, isNull);
      expect(notifier.message, contains('说完'));

      final events = await harness.repository.listEventHistory(
        activityId: 'bath_time',
      );
      expect(events, isEmpty);
    });

    test(
      'starts requested moment, marks said, and records selected reaction',
      () async {
        final phases = <CareTurnPhase>[];
        notifier.addListener(() => phases.add(notifier.phase));

        await notifier.startMoment(
          spaceId: 'daily_care',
          activityId: 'bath_time',
        );
        notifier.markSaid();
        await notifier.selectReaction(
          BabyReactionType.other,
          clientTimestamp: DateTime.utc(2026, 6, 30, 10),
          localEventId: 'evt_care_path_notifier_other',
        );

        expect(phases, contains(CareTurnPhase.savingTrace));
        expect(notifier.phase, CareTurnPhase.nextSupportReady);
        expect(notifier.viewModel.selectedReaction, BabyReactionType.other);
        expect(notifier.viewModel.canSelectReaction, isFalse);
        expect(
          notifier.viewModel.traceEventKey,
          '$practiceCharacterizationInstallationId:evt_care_path_notifier_other',
        );
        expect(
          notifier.viewModel.nextSupportUtterance?.phraseId,
          'bath_time_splash_splash',
        );

        final events = await harness.repository.listEventHistory(
          activityId: 'bath_time',
        );
        expect(events.single.reactionType, BabyReactionType.other);

        await notifier.selectReaction(
          BabyReactionType.cooperating,
          localEventId: 'evt_care_path_notifier_duplicate',
        );

        final eventsAfterDuplicateAttempt = await harness.repository
            .listEventHistory(activityId: 'bath_time');
        expect(eventsAfterDuplicateAttempt, hasLength(1));
        expect(notifier.message, contains('已经完成'));
      },
    );

    test('holds safe fallback when reaction is selected before load', () async {
      await notifier.selectReaction(BabyReactionType.other);

      expect(notifier.phase, CareTurnPhase.heldWithFallback);
      expect(notifier.viewModel.snapshot, isNull);
      expect(notifier.message, contains('还没有加载完成'));
    });

    test('reset returns state to idle', () async {
      await notifier.startMoment(
        spaceId: 'daily_care',
        activityId: 'bath_time',
      );

      notifier.resetToSafeEmpty();

      expect(notifier.phase, CareTurnPhase.idle);
      expect(notifier.viewModel.snapshot, isNull);
      expect(notifier.message, isNull);
    });
  });
}
