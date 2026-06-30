import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/care_path/data/repositories/care_path_repository.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/practice/data/repositories/garden_growth_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

import '../../practice/practice_repository_characterization_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(ensurePracticeRepositoryHarnessIsarInitialized);

  group('CarePathRepository', () {
    late PracticeRepositoryCharacterizationHarness harness;
    late CarePathRepository repository;

    setUp(() async {
      harness = await PracticeRepositoryCharacterizationHarness.create();
      repository = CarePathRepository(practiceRepository: harness.repository);
    });

    tearDown(() async {
      await harness.dispose();
    });

    test(
      'loads starter activity as current turn when no local event exists',
      () async {
        final snapshot = await repository.loadCurrentTurn(
          starterSpaceId: 'daily_care',
          starterActivityId: 'bath_time',
        );

        expect(snapshot.phase, CareTurnPhase.reactionPrompt);
        expect(snapshot.message, isNull);
        expect(snapshot.moment.spaceId, 'daily_care');
        expect(snapshot.moment.spaceTitle, '日常照护');
        expect(snapshot.moment.activityId, 'bath_time');
        expect(snapshot.moment.title, '洗澡时间');
        expect(snapshot.moment.sceneTag, 'Bath time');
        expect(snapshot.moment.nodeState, CarePathNodeState.current);
        expect(snapshot.currentUtterance?.phraseId, 'bath_time_warm_water');
        expect(snapshot.currentUtterance?.english, 'Warm water.');
        expect(snapshot.currentUtterance?.chinese, '水暖暖的。');
        expect(snapshot.currentUtterance?.isFallback, isFalse);
        expect(snapshot.selectedReaction, isNull);
        expect(snapshot.traceEventKey, isNull);
        expect(snapshot.latestGardenImpact, isNull);
      },
    );

    test(
      'starts a requested moment directly from the practice catalog',
      () async {
        final snapshot = await repository.startMoment(
          spaceId: 'daily_care',
          activityId: 'bath_time',
        );

        expect(snapshot.phase, CareTurnPhase.reactionPrompt);
        expect(snapshot.moment.spaceId, 'daily_care');
        expect(snapshot.moment.activityId, 'bath_time');
        expect(snapshot.currentUtterance?.phraseId, 'bath_time_warm_water');
      },
    );

    test('continues with next phrase after a saved local event', () async {
      await harness.recordBathTimeReaction(
        localEventId: 'evt_care_path_existing_warm_water',
        phraseId: 'bath_time_warm_water',
        reactionType: BabyReactionType.cooperating,
        clientTimestamp: DateTime.utc(2026, 6, 30, 7),
      );

      final snapshot = await repository.loadCurrentTurn(
        starterSpaceId: 'daily_care',
        starterActivityId: 'bath_time',
      );

      expect(snapshot.phase, CareTurnPhase.reactionPrompt);
      expect(snapshot.moment.activityId, 'bath_time');
      expect(snapshot.currentUtterance?.phraseId, 'bath_time_splash_splash');
      expect(snapshot.currentUtterance?.english, 'Splash, splash!');
    });

    test(
      'records reaction through practice local event with BabyReactionType',
      () async {
        final turn = await repository.startMoment(
          spaceId: 'daily_care',
          activityId: 'bath_time',
        );

        final saved = await repository.recordReaction(
          turn: turn,
          reactionType: BabyReactionType.hesitant,
          clientTimestamp: DateTime.utc(2026, 6, 30, 8),
          localEventId: 'evt_care_path_hesitant',
        );

        expect(saved.phase, CareTurnPhase.nextSupportReady);
        expect(saved.selectedReaction, BabyReactionType.hesitant);
        expect(
          saved.traceEventKey,
          '$practiceCharacterizationInstallationId:evt_care_path_hesitant',
        );
        expect(saved.nextSupportUtterance?.phraseId, 'bath_time_splash_splash');

        final events = await harness.repository.listEventHistory(
          activityId: 'bath_time',
        );
        expect(events, hasLength(1));
        expect(events.single.localEventId, 'evt_care_path_hesitant');
        expect(events.single.phraseId, 'bath_time_warm_water');
        expect(events.single.reactionType, BabyReactionType.hesitant);
      },
    );

    test(
      'surfaces optional garden impact after recording a reaction',
      () async {
        final gardenRepository = GardenGrowthRepository(
          practiceRepository: harness.repository,
          assetPhraseService: AssetPhraseService(bundle: rootBundle),
        );
        final repository = CarePathRepository(
          practiceRepository: harness.repository,
          gardenGrowthRepository: gardenRepository,
        );
        final turn = await repository.startMoment(
          spaceId: 'daily_care',
          activityId: 'bath_time',
        );

        final saved = await repository.recordReaction(
          turn: turn,
          reactionType: BabyReactionType.cooperating,
          clientTimestamp: DateTime.utc(2026, 6, 30, 9),
          localEventId: 'evt_care_path_garden',
        );

        expect(saved.latestGardenImpact, isNotNull);
        expect(
          saved.latestGardenImpact?.eventKey,
          '$practiceCharacterizationInstallationId:evt_care_path_garden',
        );
        expect(
          saved.latestGardenImpact?.reactionType,
          BabyReactionType.cooperating,
        );
        expect(saved.latestGardenImpact?.phraseTitle, 'Warm water.');
      },
    );

    test(
      'returns fallback snapshot when practice activity cannot be loaded',
      () async {
        final snapshot = await repository.startMoment(
          spaceId: 'missing_space',
          activityId: 'missing_activity',
        );

        expect(snapshot.phase, CareTurnPhase.error);
        expect(snapshot.moment.nodeState, CarePathNodeState.unavailable);
        expect(snapshot.currentUtterance, isNull);
        expect(snapshot.message, isNotNull);
      },
    );
  });
}
