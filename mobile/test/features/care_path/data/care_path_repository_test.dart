import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/care_path/data/repositories/care_path_repository.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/practice/data/repositories/garden_growth_repository.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';

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

        expect(snapshot.phase, CareTurnPhase.utteranceReady);
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
          turn: turn.copyWith(phase: CareTurnPhase.reactionPrompt),
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

    test('recordReaction retry with the same event id returns next support '
        'without duplicate trace', () async {
      final turn = await repository.startMoment(
        spaceId: 'daily_care',
        activityId: 'bath_time',
      );
      final first = await repository.recordReaction(
        turn: turn,
        reactionType: BabyReactionType.hesitant,
        localEventId: 'evt_care_path_reconcile',
      );
      final retry = await repository.recordReaction(
        turn: turn,
        reactionType: BabyReactionType.hesitant,
        localEventId: 'evt_care_path_reconcile',
      );

      expect(retry.traceEventKey, first.traceEventKey);
      expect(retry.phase, CareTurnPhase.nextSupportReady);
      expect(retry.nextSupportUtterance, isNotNull);
      expect(await harness.repository.listEventHistory(), hasLength(1));
    });

    test(
      'records BabyReactionType.other canonically after mark-said state handoff',
      () async {
        final turn = await repository.startMoment(
          spaceId: 'daily_care',
          activityId: 'bath_time',
        );

        final saved = await repository.recordReaction(
          turn: turn.copyWith(phase: CareTurnPhase.reactionPrompt),
          reactionType: BabyReactionType.other,
          clientTimestamp: DateTime.utc(2026, 6, 30, 8, 30),
          localEventId: 'evt_care_path_other',
        );

        expect(saved.selectedReaction, BabyReactionType.other);
        expect(
          saved.traceEventKey,
          '$practiceCharacterizationInstallationId:evt_care_path_other',
        );

        final events = await harness.repository.listEventHistory(
          activityId: 'bath_time',
        );
        expect(events, hasLength(1));
        expect(events.single.reactionType, BabyReactionType.other);
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
          turn: turn.copyWith(phase: CareTurnPhase.reactionPrompt),
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
      'keeps confirmed trace and next support when Garden snapshot fails',
      () async {
        final repository = CarePathRepository(
          practiceRepository: harness.repository,
          gardenGrowthRepository: _FailingGardenGrowthRepository(),
        );
        final turn = await repository.startMoment(
          spaceId: 'daily_care',
          activityId: 'bath_time',
        );

        final saved = await repository.recordReaction(
          turn: turn,
          reactionType: BabyReactionType.cooperating,
          localEventId: 'evt_care_path_garden_failure',
        );

        expect(saved.phase, CareTurnPhase.nextSupportReady);
        expect(
          saved.traceEventKey,
          '$practiceCharacterizationInstallationId:'
          'evt_care_path_garden_failure',
        );
        expect(saved.nextSupportUtterance, isNotNull);
        expect(saved.latestGardenImpact, isNull);
        expect(await harness.repository.listEventHistory(), hasLength(1));
      },
    );

    test(
      'holds fallback after successful write when no next support exists',
      () async {
        final latestImpact = LatestPracticeImpact(
          eventKey: 'install_test:evt_care_path_last_phrase',
          occurredAt: DateTime.utc(2026, 6, 30, 10),
          spaceId: 'daily_care',
          spaceTitle: '日常照护',
          activityId: 'bath_time',
          activityTitle: '洗澡时间',
          phraseId: 'bath_time_all_clean',
          phraseTitle: 'All clean.',
          reactionType: BabyReactionType.noResponse,
          previousPatchStage: GardenPatchStage.quiet,
          currentPatchStage: GardenPatchStage.tended,
          previousFlowerStage: GardenFlowerStage.growing,
          currentFlowerStage: GardenFlowerStage.blooming,
          headline: 'headline',
          detail: 'detail',
        );
        final practiceRepository = _NoNextSupportPracticeRepository();
        final repository = CarePathRepository(
          practiceRepository: practiceRepository,
          gardenGrowthRepository: _StubGardenGrowthRepository(latestImpact),
        );
        final turn = await repository.startMoment(
          spaceId: 'daily_care',
          activityId: 'bath_time',
        );

        expect(turn.currentUtterance?.phraseId, 'bath_time_all_clean');

        final saved = await repository.recordReaction(
          turn: turn.copyWith(phase: CareTurnPhase.reactionPrompt),
          reactionType: BabyReactionType.noResponse,
          clientTimestamp: DateTime.utc(2026, 6, 30, 10),
          localEventId: 'evt_care_path_last_phrase',
        );

        expect(saved.phase, CareTurnPhase.heldWithFallback);
        expect(saved.currentUtterance?.phraseId, 'bath_time_all_clean');
        expect(saved.selectedReaction, BabyReactionType.noResponse);
        expect(saved.nextSupportUtterance, isNull);
        expect(saved.traceEventKey, 'install_test:evt_care_path_last_phrase');
        expect(saved.latestGardenImpact, latestImpact);
        expect(practiceRepository.recordedWrite, isNotNull);
        expect(practiceRepository.recordedWrite?.spaceId, 'daily_care');
        expect(practiceRepository.recordedWrite?.activityId, 'bath_time');
        expect(
          practiceRepository.recordedWrite?.phraseId,
          'bath_time_all_clean',
        );
        expect(
          practiceRepository.recordedWrite?.reactionType,
          BabyReactionType.noResponse,
        );
        expect(
          practiceRepository.recordedWrite?.clientTimestamp,
          DateTime.utc(2026, 6, 30, 10),
        );
        expect(
          practiceRepository.recordedWrite?.localEventId,
          'evt_care_path_last_phrase',
        );
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
        expect(snapshot.message, '当前照护内容暂时不可用。');
        expect(snapshot.message, isNot(contains('care path')));
      },
    );
  });
}

class _NoNextSupportPracticeRepository implements PracticeRepository {
  _NoNextSupportPracticeRepository();

  static const PracticePhrase _phrase = PracticePhrase(
    spaceId: 'daily_care',
    activityId: 'bath_time',
    phraseId: 'bath_time_all_clean',
    step: 3,
    english: 'All clean.',
    chinese: '洗好了。',
    pronunciation: 'ɔːl kliːn',
    difficulty: 'starter',
    audioAsset: 'assets/audio/phrases/bath_time_all_clean.mp3',
  );

  static const PracticeActivitySnapshot _activity = PracticeActivitySnapshot(
    spaceId: 'daily_care',
    activityId: 'bath_time',
    title: '洗澡时间',
    summary: 'Keep bath time warm.',
    sceneTag: 'Bath time',
    coachTip: 'Say it before wrapping up.',
    phrases: <PracticePhrase>[_phrase],
  );

  var _resumeCalls = 0;
  var _recorded = false;
  _RecordedReactionWrite? recordedWrite;

  @override
  Future<PracticeActivityCatalog> getActivityCatalog() async {
    final summary = PracticeCatalogActivitySummary(
      spaceId: 'daily_care',
      spaceTitle: '日常照护',
      activityId: 'bath_time',
      title: '洗澡时间',
      summary: 'Keep bath time warm.',
      sceneTag: 'Bath time',
      coachTip: 'Say it before wrapping up.',
      totalPhraseCount: 1,
      completedPhraseCount: _recorded ? 1 : 0,
      completedPhraseIds: _recorded
          ? const <String>['bath_time_all_clean']
          : const <String>[],
      nextPhraseId: _recorded ? null : 'bath_time_all_clean',
      nextPhraseEnglish: _recorded ? null : 'All clean.',
      totalEvents: _recorded ? 1 : 0,
      skippedUnknownPhraseCount: 0,
      skippedMalformedEventCount: 0,
      lastEventTime: _recorded ? recordedWrite?.clientTimestamp : null,
    );
    return PracticeActivityCatalog(
      installationId: 'install_test',
      spaces: <PracticeCatalogSpaceSummary>[],
      activities: <PracticeCatalogActivitySummary>[summary],
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
  }) async {
    return _activity;
  }

  @override
  Future<PracticeResumeInfo> getResumeInfo({
    required String spaceId,
    required String activityId,
  }) async {
    _resumeCalls += 1;
    if (_resumeCalls == 1) {
      return const PracticeResumeInfo(
        activityId: 'bath_time',
        totalPhrases: 1,
        completedPhraseIds: <String>[],
        nextPhraseId: 'bath_time_all_clean',
        lastEventTime: null,
      );
    }
    return PracticeResumeInfo(
      activityId: 'bath_time',
      totalPhrases: 1,
      completedPhraseIds: const <String>['bath_time_all_clean'],
      nextPhraseId: null,
      lastEventTime: recordedWrite?.clientTimestamp,
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
    _recorded = true;
    final effectiveLocalEventId = localEventId ?? 'evt_generated';
    final effectiveClientTimestamp =
        clientTimestamp ?? DateTime.utc(2026, 6, 30, 10);
    recordedWrite = _RecordedReactionWrite(
      spaceId: spaceId,
      activityId: activityId,
      phraseId: phraseId,
      reactionType: reactionType,
      clientTimestamp: effectiveClientTimestamp,
      localEventId: effectiveLocalEventId,
    );
    return InteractionEventPayload.validated(
      localEventId: effectiveLocalEventId,
      installationId: 'install_test',
      spaceId: spaceId,
      activityId: activityId,
      phraseId: phraseId,
      reactionType: reactionType,
      clientTimestamp: effectiveClientTimestamp,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordedReactionWrite {
  const _RecordedReactionWrite({
    required this.spaceId,
    required this.activityId,
    required this.phraseId,
    required this.reactionType,
    required this.clientTimestamp,
    required this.localEventId,
  });

  final String spaceId;
  final String activityId;
  final String phraseId;
  final BabyReactionType reactionType;
  final DateTime clientTimestamp;
  final String localEventId;
}

class _StubGardenGrowthRepository implements GardenGrowthRepository {
  const _StubGardenGrowthRepository(this.latestImpact);

  final LatestPracticeImpact latestImpact;

  @override
  Future<GardenGrowthSnapshot> buildSnapshot() async {
    return GardenGrowthSnapshot(
      installationId: 'install_test',
      spaces: const <GardenPatchSnapshot>[],
      diaryEntries: const <GrowthDiaryEntry>[],
      milestones: const <GrowthMilestoneSnapshot>[],
      latestImpact: latestImpact,
      totalStoredEvents: 1,
      validEvents: 1,
      knownEvents: 1,
      skippedMalformedEvents: 0,
      skippedUnknownContentEvents: 0,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingGardenGrowthRepository implements GardenGrowthRepository {
  @override
  Future<GardenGrowthSnapshot> buildSnapshot() {
    throw StateError('simulated Garden snapshot failure');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
