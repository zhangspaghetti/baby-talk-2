import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/scene_generation/domain/generated_care_moment.dart';
import 'package:mobile/features/practice/data/generated/generated_practice_content_registry.dart';
import 'package:mobile/features/practice/data/generated/generated_care_moment_local_store.dart';
import 'package:mobile/features/practice/data/generated/generated_care_turn_resume_marker_store.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/generated_care_turn_resume.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/practice/domain/models/practice_content_source.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
import '../../support/isar_test_library.dart';
import '../../support/generated_care_moment_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): resolveBundledIsarLibraryPath()},
    );
  });

  group('PracticeRepository', () {
    late Directory tempDir;
    late String dbName;
    late PracticeLocalDataSource localDataSource;
    late PracticeRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'practice_repository_test_',
      );
      dbName = 'practice_${DateTime.now().microsecondsSinceEpoch}';
      localDataSource = await PracticeLocalDataSource.open(
        directory: tempDir.path,
        name: dbName,
      );
      repository = PracticeRepository(
        assetPhraseService: AssetPhraseService(bundle: rootBundle),
        localDataSource: localDataSource,
        installationIdService: InstallationIdService(
          directoryResolver: () async => tempDir,
          idGenerator: () => 'install_test',
        ),
      );
    });

    tearDown(() async {
      await localDataSource.close(deleteFromDisk: true);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('从打包内容加载活动，并在零事件时返回显式空态', () async {
      final snapshot = await repository.getActivitySnapshot(
        spaceId: 'daily_care',
        activityId: 'bath_time',
      );
      final homeSummary = await repository.getHomeSummary(
        spaceId: 'daily_care',
        activityId: 'bath_time',
      );
      final resumeInfo = await repository.getResumeInfo(
        spaceId: 'daily_care',
        activityId: 'bath_time',
      );
      final syncSummary = await repository.getSyncSummary(
        spaceId: 'daily_care',
        activityId: 'bath_time',
      );
      final catalog = await repository.getActivityCatalog();

      expect(snapshot.title, '洗澡时间');
      expect(snapshot.phrases, hasLength(3));
      expect(snapshot.phrases.first.english, 'Warm water.');

      expect(homeSummary.isEmpty, isTrue);
      expect(homeSummary.totalEvents, 0);
      expect(homeSummary.lastEventTime, isNull);
      expect(homeSummary.recentResult, isNull);

      expect(resumeInfo.completedCount, 0);
      expect(resumeInfo.nextPhraseId, 'bath_time_warm_water');
      expect(resumeInfo.lastEventTime, isNull);

      expect(syncSummary.pendingCount, 0);
      expect(syncSummary.syncedCount, 0);
      expect(syncSummary.failedCount, 0);
      expect(syncSummary.lastSyncPhase, isNull);

      expect(catalog.spaces.map((space) => space.spaceId), [
        'daily_care',
        'family_rhythm',
      ]);
      expect(catalog.activities.map((activity) => activity.activityId), [
        'bath_time',
        'diaper_change',
        'post_cry_soothing',
        'feeding_time',
        'bedtime',
      ]);
      expect(catalog.totalStoredEvents, 0);
      expect(catalog.validEvents, 0);
      expect(catalog.knownEvents, 0);
      expect(catalog.catalogWarning, isNull);

      for (final activity in catalog.activities) {
        expect(activity.isEmpty, isTrue);
        expect(activity.recentResult, isNull);
        expect(activity.warningMessage, isNull);
        expect(activity.nextPhraseId, isNotNull);
        expect(activity.nextPhraseEnglish, isNotNull);
      }
    });

    test(
      'recordBundledReaction validates shipped seed content without generated registry',
      () async {
        final generatedResolver = _GeneratedSameScopeResolver();
        final bundledOnlyRepository = PracticeRepository(
          assetPhraseService: AssetPhraseService(bundle: rootBundle),
          localDataSource: localDataSource,
          installationIdService: InstallationIdService(
            directoryResolver: () async => tempDir,
            idGenerator: () => 'install_test',
          ),
          contentResolver: generatedResolver,
        );

        final event = await bundledOnlyRepository.recordBundledReaction(
          spaceId: 'daily_care',
          activityId: 'bath_time',
          phraseId: 'bath_time_warm_water',
          reactionType: BabyReactionType.cooperating,
          localEventId: 'bundled_reaction_1',
        );

        expect(event.generatedContentId, isNull);
        expect(event.utteranceId, isNull);
        expect(generatedResolver.resolveActivityCalls, 0);
        expect(
          (await bundledOnlyRepository.listEventHistory()).single.phraseId,
          'bath_time_warm_water',
        );
      },
    );

    test('未登录时 generated projection 不可用仍返回完整 seed catalog', () async {
      final signedOutRepository = PracticeRepository(
        assetPhraseService: AssetPhraseService(bundle: rootBundle),
        localDataSource: localDataSource,
        installationIdService: InstallationIdService(
          directoryResolver: () async => tempDir,
          idGenerator: () => 'install_test',
        ),
        contentResolver: const _ThrowingPracticeContentResolver(
          GeneratedPracticeProjectionUnavailableException(
            GeneratedPracticeProjectionUnavailableReason.accountUnavailable,
          ),
        ),
      );

      final catalog = await signedOutRepository.getActivityCatalog();

      expect(catalog.activities.map((activity) => activity.activityId), [
        'bath_time',
        'diaper_change',
        'post_cry_soothing',
        'feeding_time',
        'bedtime',
      ]);
      expect(
        catalog.activities.where(
          (activity) => activity.generatedContentId != null,
        ),
        isEmpty,
      );
      expect(catalog.knownEvents, 0);
    });

    test(
      'attributes a matching preset event to its stable catalog activity',
      () async {
        final generatedStore = GeneratedCareMomentLocalStore(
          directoryResolver: () async => tempDir,
        );
        final resumeStore = GeneratedCareTurnResumeMarkerStore(
          directoryResolver: () async => tempDir,
        );
        final registry = GeneratedPracticeContentRegistry(
          store: generatedStore,
          resumeStore: resumeStore,
          accountContextLoader: () async => 'account_preset',
        );
        final preset = generatedCareMomentFixture(
          generatedContentId: 'preset_generated_bath',
          spaceId: 'daily_care',
          activityId: 'bath_time',
          inputSource: SceneGenerationSourceType.preset,
          presetSceneId: 'bath_time',
          presetSceneVersion: 1,
        );
        await registry.register(
          accountContext: 'account_preset',
          moment: preset,
        );
        final presetRepository = PracticeRepository(
          assetPhraseService: AssetPhraseService(bundle: rootBundle),
          localDataSource: localDataSource,
          installationIdService: InstallationIdService(
            directoryResolver: () async => tempDir,
            idGenerator: () => 'install_test',
          ),
          contentResolver: registry,
        );

        await localDataSource.appendInteractionEvent(
          InteractionEventPayload.validated(
            localEventId: 'preset_event_1',
            installationId: 'install_test',
            spaceId: 'daily_care',
            activityId: 'bath_time',
            phraseId: preset.starter.phraseId,
            reactionType: BabyReactionType.cooperating,
            clientTimestamp: DateTime.utc(2026, 9, 8, 10),
            generatedContentId: preset.generatedContentId,
            utteranceId: preset.starter.utteranceId,
          ),
        );

        final catalog = await presetRepository.getActivityCatalog();
        final bath = catalog.findActivity(
          spaceId: 'daily_care',
          activityId: 'bath_time',
        );

        expect(bath, isNotNull);
        expect(bath!.totalEvents, 1);
        expect(bath.generatedContentId, isNull);
        expect(
          catalog.activities.where(
            (activity) => activity.generatedContentId != null,
          ),
          isEmpty,
        );
        expect(catalog.knownEvents, 1);
        expect(catalog.skippedUnknownContentEvents, 0);
      },
    );

    test(
      'restores a preset resume marker through direct generated-content resolve',
      () async {
        final generatedStore = GeneratedCareMomentLocalStore(
          directoryResolver: () async => tempDir,
        );
        final resumeStore = GeneratedCareTurnResumeMarkerStore(
          directoryResolver: () async => tempDir,
        );
        final registry = GeneratedPracticeContentRegistry(
          store: generatedStore,
          resumeStore: resumeStore,
          accountContextLoader: () async => 'account_preset_resume',
        );
        final preset = generatedCareMomentFixture(
          generatedContentId: 'preset_resume_bath',
          spaceId: 'daily_care',
          activityId: 'bath_time',
          inputSource: SceneGenerationSourceType.preset,
          presetSceneId: 'bath_time',
          presetSceneVersion: 1,
        );
        await registry.register(
          accountContext: 'account_preset_resume',
          moment: preset,
        );
        await resumeStore.write(
          accountContext: 'account_preset_resume',
          generatedContentId: preset.generatedContentId,
          confirmedAt: DateTime.utc(2026, 9, 8, 10),
        );
        final presetRepository = PracticeRepository(
          assetPhraseService: AssetPhraseService(bundle: rootBundle),
          localDataSource: localDataSource,
          installationIdService: InstallationIdService(
            directoryResolver: () async => tempDir,
            idGenerator: () => 'install_test',
          ),
          contentResolver: registry,
        );

        expect(await presetRepository.getGeneratedActivitySnapshots(), isEmpty);
        final continuity = await presetRepository.getContinuitySnapshot();

        expect(
          continuity.recommendedActivity.generatedContentId,
          preset.generatedContentId,
        );
        expect(continuity.recommendedActivity.spaceId, preset.spaceId);
        expect(continuity.recommendedActivity.activityId, preset.activityId);
        expect(
          continuity.recommendation.generatedContentId,
          preset.generatedContentId,
        );
      },
    );

    test(
      'ignores preset events with wrong phrase or utterance identity',
      () async {
        final generatedStore = GeneratedCareMomentLocalStore(
          directoryResolver: () async => tempDir,
        );
        final resumeStore = GeneratedCareTurnResumeMarkerStore(
          directoryResolver: () async => tempDir,
        );
        final registry = GeneratedPracticeContentRegistry(
          store: generatedStore,
          resumeStore: resumeStore,
          accountContextLoader: () async => 'account_preset_identity',
        );
        final preset = generatedCareMomentFixture(
          generatedContentId: 'preset_identity_bath',
          spaceId: 'daily_care',
          activityId: 'bath_time',
          inputSource: SceneGenerationSourceType.preset,
          presetSceneId: 'bath_time',
          presetSceneVersion: 1,
        );
        await registry.register(
          accountContext: 'account_preset_identity',
          moment: preset,
        );
        for (final event in <InteractionEventPayload>[
          InteractionEventPayload.validated(
            localEventId: 'preset_wrong_phrase',
            installationId: 'install_test',
            spaceId: 'daily_care',
            activityId: 'bath_time',
            phraseId: 'not_in_generated_bundle',
            reactionType: BabyReactionType.cooperating,
            clientTimestamp: DateTime.utc(2026, 9, 8, 10),
            generatedContentId: preset.generatedContentId,
            utteranceId: 'wrong_phrase_utterance',
          ),
          InteractionEventPayload.validated(
            localEventId: 'preset_wrong_utterance',
            installationId: 'install_test',
            spaceId: 'daily_care',
            activityId: 'bath_time',
            phraseId: preset.starter.phraseId,
            reactionType: BabyReactionType.hesitant,
            clientTimestamp: DateTime.utc(2026, 9, 8, 10, 1),
            generatedContentId: preset.generatedContentId,
            utteranceId: 'not_in_generated_bundle',
          ),
        ]) {
          await localDataSource.appendInteractionEvent(event);
        }
        final presetRepository = PracticeRepository(
          assetPhraseService: AssetPhraseService(bundle: rootBundle),
          localDataSource: localDataSource,
          installationIdService: InstallationIdService(
            directoryResolver: () async => tempDir,
            idGenerator: () => 'install_test',
          ),
          contentResolver: registry,
        );

        final catalog = await presetRepository.getActivityCatalog();
        final bath = catalog.findActivity(
          spaceId: 'daily_care',
          activityId: 'bath_time',
        );

        expect(bath!.totalEvents, 0);
        expect(catalog.knownEvents, 0);
        expect(catalog.skippedUnknownContentEvents, 2);
      },
    );

    test('generated projection 读取故障与未知错误继续显式失败', () async {
      final errors = <Object>[
        const GeneratedPracticeProjectionUnavailableException(
          GeneratedPracticeProjectionUnavailableReason.accountLoadFailed,
        ),
        const GeneratedPracticeProjectionUnavailableException(
          GeneratedPracticeProjectionUnavailableReason.contentLoadFailed,
        ),
        StateError('unexpected projection failure'),
      ];

      for (final error in errors) {
        final failingRepository = PracticeRepository(
          assetPhraseService: AssetPhraseService(bundle: rootBundle),
          localDataSource: localDataSource,
          installationIdService: InstallationIdService(
            directoryResolver: () async => tempDir,
            idGenerator: () => 'install_test',
          ),
          contentResolver: _ThrowingPracticeContentResolver(error),
        );

        await expectLater(
          failingRepository.getActivityCatalog(),
          throwsA(same(error)),
        );
      }
    });

    test(
      'continuity snapshot 在零事件时显式回退到 starter activity，并给出 cadence',
      () async {
        final continuity = await repository.getContinuitySnapshot(
          starterSpaceId: 'daily_care',
          starterActivityId: 'bath_time',
        );

        expect(
          continuity.recommendation.reason,
          PracticeContinuityReason.starterFallback,
        );
        expect(continuity.recommendedActivity.activityId, 'bath_time');
        expect(continuity.fallbackReason, contains('starter activity'));
        expect(continuity.warningMessage, isNull);
        expect(continuity.cadence.totalKnownEvents, 0);
        expect(continuity.cadence.headline, '还没形成 cadence');
        expect(continuity.cadence.detail, contains('洗澡时间'));
      },
    );

    test('追加事件后保留原始历史，并派生最近结果与恢复信息', () async {
      await repository.recordReaction(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'bath_time_warm_water',
        reactionType: BabyReactionType.cooperating,
        clientTimestamp: DateTime.utc(2026, 4, 7, 12, 0),
        localEventId: 'evt_1',
      );
      await repository.recordReaction(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'bath_time_splash_splash',
        reactionType: BabyReactionType.cooperating,
        clientTimestamp: DateTime.utc(2026, 4, 7, 12, 1),
        localEventId: 'evt_2',
      );

      final events = await repository.listEventHistory(activityId: 'bath_time');
      final pendingUploads = await repository.listPendingUploadRecords(
        activityId: 'bath_time',
      );
      final homeSummary = await repository.getHomeSummary(
        spaceId: 'daily_care',
        activityId: 'bath_time',
      );
      final resumeInfo = await repository.getResumeInfo(
        spaceId: 'daily_care',
        activityId: 'bath_time',
      );

      expect(events, hasLength(2));
      expect(events.map((event) => event.localEventId), ['evt_1', 'evt_2']);
      expect(events.map((event) => event.installationId).toSet(), {
        'install_test',
      });
      expect(events.first.eventKey, 'install_test:evt_1');
      expect(pendingUploads, hasLength(2));
      expect(
        pendingUploads.first.toJsonMap().keys,
        containsAll([
          'eventKey',
          'localEventId',
          'installationId',
          'spaceId',
          'activityId',
          'phraseId',
          'reactionType',
          'clientTimestamp',
        ]),
      );
      expect(
        pendingUploads.first.toJsonMap().keys,
        isNot(contains('syncState')),
      );

      expect(homeSummary.isEmpty, isFalse);
      expect(homeSummary.totalEvents, 2);
      expect(homeSummary.lastEventTime, DateTime.utc(2026, 4, 7, 12, 1));
      expect(homeSummary.recentResult, isNotNull);
      expect(homeSummary.recentResult!.phraseId, 'bath_time_splash_splash');
      expect(homeSummary.recentResult!.phraseEnglish, 'Splash, splash!');
      expect(
        homeSummary.recentResult!.reactionType,
        BabyReactionType.cooperating,
      );

      expect(resumeInfo.completedPhraseIds, [
        'bath_time_warm_water',
        'bath_time_splash_splash',
      ]);
      expect(resumeInfo.nextPhraseId, 'bath_time_all_clean');
      expect(resumeInfo.completedCount, 2);
      expect(resumeInfo.lastEventTime, DateTime.utc(2026, 4, 7, 12, 1));
    });

    test('continuity snapshot 优先推荐最近 activity，而不是固定 starter', () async {
      await repository.recordReaction(
        spaceId: 'family_rhythm',
        activityId: 'feeding_time',
        phraseId: 'feeding_time_open_wide',
        reactionType: BabyReactionType.cooperating,
        clientTimestamp: DateTime.utc(2026, 4, 7, 12, 10),
        localEventId: 'evt_recent_feed_1',
      );
      await repository.recordReaction(
        spaceId: 'family_rhythm',
        activityId: 'feeding_time',
        phraseId: 'feeding_time_yummy_bite',
        reactionType: BabyReactionType.cooperating,
        clientTimestamp: DateTime.utc(2026, 4, 7, 12, 11),
        localEventId: 'evt_recent_feed_2',
      );

      final continuity = await repository.getContinuitySnapshot(
        starterSpaceId: 'daily_care',
        starterActivityId: 'bath_time',
      );

      expect(
        continuity.recommendation.reason,
        PracticeContinuityReason.recentActivity,
      );
      expect(continuity.recommendedActivity.spaceId, 'family_rhythm');
      expect(continuity.recommendedActivity.activityId, 'feeding_time');
      expect(
        continuity.recommendedActivity.recentResult?.phraseId,
        'feeding_time_yummy_bite',
      );
      expect(continuity.fallbackReason, isNull);
      expect(continuity.cadence.totalKnownEvents, 2);
      expect(continuity.cadence.detail, contains('吃饭时间'));
    });

    test(
      'continuity snapshot 在坏 starter context 下暴露 warning 并退回未完成 activity',
      () async {
        final continuity = await repository.getContinuitySnapshot(
          starterSpaceId: 'daily_care',
          starterActivityId: 'missing_activity',
        );

        expect(
          continuity.recommendation.reason,
          PracticeContinuityReason.nextIncomplete,
        );
        expect(continuity.recommendedActivity.activityId, 'bath_time');
        expect(continuity.warningMessage, contains('starter activity 不存在'));
        expect(continuity.fallbackReason, contains('退回尚未完成'));
      },
    );

    test('catalog 只统计各自 space/activity 的事件，并把未知内容留在局部 warning', () async {
      await repository.recordReaction(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'bath_time_warm_water',
        reactionType: BabyReactionType.cooperating,
        clientTimestamp: DateTime.utc(2026, 4, 7, 13, 0),
        localEventId: 'evt_catalog_bath',
      );
      await repository.recordReaction(
        spaceId: 'family_rhythm',
        activityId: 'feeding_time',
        phraseId: 'feeding_time_open_wide',
        reactionType: BabyReactionType.cooperating,
        clientTimestamp: DateTime.utc(2026, 4, 7, 13, 1),
        localEventId: 'evt_catalog_feed',
      );
      await localDataSource.appendInteractionEvent(
        InteractionEventPayload(
          localEventId: 'evt_catalog_unknown_phrase',
          installationId: 'install_test',
          spaceId: 'daily_care',
          activityId: 'bath_time',
          phraseId: 'bath_time_unknown',
          reactionType: BabyReactionType.resisting,
          clientTimestamp: DateTime.utc(2026, 4, 7, 13, 2),
        ),
      );
      await localDataSource.appendInteractionEvent(
        InteractionEventPayload(
          localEventId: 'evt_catalog_unknown_activity',
          installationId: 'install_test',
          spaceId: 'family_rhythm',
          activityId: 'mystery_time',
          phraseId: 'mystery_phrase',
          reactionType: BabyReactionType.cooperating,
          clientTimestamp: DateTime.utc(2026, 4, 7, 13, 3),
        ),
      );

      final bathRestore = await repository.restorePracticeState(
        spaceId: 'daily_care',
        activityId: 'bath_time',
      );
      final feedingRestore = await repository.restorePracticeState(
        spaceId: 'family_rhythm',
        activityId: 'feeding_time',
      );
      final catalog = await repository.getActivityCatalog();
      final bath = catalog.activities.firstWhere(
        (activity) =>
            activity.spaceId == 'daily_care' &&
            activity.activityId == 'bath_time',
      );
      final diaper = catalog.activities.firstWhere(
        (activity) =>
            activity.spaceId == 'daily_care' &&
            activity.activityId == 'diaper_change',
      );
      final feeding = catalog.activities.firstWhere(
        (activity) =>
            activity.spaceId == 'family_rhythm' &&
            activity.activityId == 'feeding_time',
      );
      final bedtime = catalog.activities.firstWhere(
        (activity) =>
            activity.spaceId == 'family_rhythm' &&
            activity.activityId == 'bedtime',
      );

      expect(bathRestore.homeSummary.totalEvents, 1);
      expect(
        bathRestore.homeSummary.recentResult?.phraseId,
        'bath_time_warm_water',
      );
      expect(bathRestore.hasRecoverableIssue, isTrue);
      expect(bathRestore.restoreMessage, contains('未知短语记录'));

      expect(feedingRestore.homeSummary.totalEvents, 1);
      expect(
        feedingRestore.homeSummary.recentResult?.phraseId,
        'feeding_time_open_wide',
      );
      expect(feedingRestore.hasRecoverableIssue, isFalse);

      expect(catalog.totalStoredEvents, 4);
      expect(catalog.validEvents, 4);
      expect(catalog.knownEvents, 2);
      expect(catalog.skippedMalformedEvents, 0);
      expect(catalog.skippedUnknownContentEvents, 2);
      expect(catalog.catalogWarning, contains('未知内容记录'));

      expect(bath.totalEvents, 1);
      expect(bath.recentResult?.phraseId, 'bath_time_warm_water');
      expect(bath.skippedUnknownPhraseCount, 1);
      expect(bath.warningMessage, contains('未知短语'));

      expect(diaper.isEmpty, isTrue);
      expect(diaper.totalEvents, 0);
      expect(diaper.warningMessage, isNull);

      expect(feeding.totalEvents, 1);
      expect(feeding.recentResult?.phraseId, 'feeding_time_open_wide');
      expect(feeding.skippedUnknownPhraseCount, 0);
      expect(feeding.warningMessage, isNull);

      expect(bedtime.isEmpty, isTrue);
      expect(catalog.spaces.first.totalEvents, 1);
      expect(catalog.spaces.last.totalEvents, 1);
    });

    test(
      'same localEventId and same immutable facts reconcile to one event',
      () async {
        final first = await repository.recordReaction(
          spaceId: 'daily_care',
          activityId: 'bath_time',
          phraseId: 'bath_time_warm_water',
          reactionType: BabyReactionType.hesitant,
          localEventId: 'evt_reconcile_same',
          clientTimestamp: DateTime.utc(2026, 7, 23, 12),
        );
        final second = await repository.recordReaction(
          spaceId: 'daily_care',
          activityId: 'bath_time',
          phraseId: 'bath_time_warm_water',
          reactionType: BabyReactionType.hesitant,
          localEventId: 'evt_reconcile_same',
          clientTimestamp: DateTime.utc(2026, 7, 23, 12, 1),
        );

        expect(second.eventKey, first.eventKey);
        expect(await repository.listEventHistory(), hasLength(1));
      },
    );

    test('same localEventId with different facts fails closed', () async {
      await repository.recordReaction(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'bath_time_warm_water',
        reactionType: BabyReactionType.hesitant,
        localEventId: 'evt_reconcile_conflict',
      );
      await expectLater(
        repository.recordReaction(
          spaceId: 'daily_care',
          activityId: 'bath_time',
          phraseId: 'bath_time_warm_water',
          reactionType: BabyReactionType.resisting,
          localEventId: 'evt_reconcile_conflict',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('localEventId 已绑定不同事件事实'),
          ),
        ),
      );
    });

    test(
      'write success with lost response reconciles the stored event',
      () async {
        final writeThenThrowDataSource = _WriteThenThrowLocalDataSource(
          isar: localDataSource.isar,
        );
        final unknownOutcomeRepository = PracticeRepository(
          assetPhraseService: AssetPhraseService(bundle: rootBundle),
          localDataSource: writeThenThrowDataSource,
          installationIdService: InstallationIdService(
            directoryResolver: () async => tempDir,
            idGenerator: () => 'install_test',
          ),
        );

        final reconciled = await unknownOutcomeRepository.recordReaction(
          spaceId: 'daily_care',
          activityId: 'bath_time',
          phraseId: 'bath_time_warm_water',
          reactionType: BabyReactionType.hesitant,
          localEventId: 'evt_unknown_outcome',
        );

        expect(reconciled.localEventId, 'evt_unknown_outcome');
        expect(
          await unknownOutcomeRepository.findEventByLocalEventId(
            'evt_unknown_outcome',
          ),
          reconciled,
        );
        expect(await unknownOutcomeRepository.listEventHistory(), hasLength(1));
      },
    );

    test('重开 Isar 后仍能从 append-only 事件重建最近结果', () async {
      await repository.recordReaction(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'bath_time_all_clean',
        reactionType: BabyReactionType.cooperating,
        clientTimestamp: DateTime.utc(2026, 4, 7, 12, 2),
        localEventId: 'evt_reopen',
      );

      await localDataSource.close();
      localDataSource = await PracticeLocalDataSource.open(
        directory: tempDir.path,
        name: dbName,
      );
      final reopenedRepository = PracticeRepository(
        assetPhraseService: AssetPhraseService(bundle: rootBundle),
        localDataSource: localDataSource,
        installationIdService: InstallationIdService(
          directoryResolver: () async => tempDir,
          idGenerator: () => 'install_test',
        ),
      );

      final homeSummary = await reopenedRepository.getHomeSummary(
        spaceId: 'daily_care',
        activityId: 'bath_time',
      );
      final resumeInfo = await reopenedRepository.getResumeInfo(
        spaceId: 'daily_care',
        activityId: 'bath_time',
      );
      final events = await reopenedRepository.listEventHistory(
        activityId: 'bath_time',
      );

      expect(events, hasLength(1));
      expect(homeSummary.totalEvents, 1);
      expect(homeSummary.recentResult, isNotNull);
      expect(homeSummary.recentResult!.phraseId, 'bath_time_all_clean');
      expect(
        homeSummary.recentResult!.reactionType,
        BabyReactionType.cooperating,
      );
      expect(resumeInfo.completedPhraseIds, ['bath_time_all_clean']);
      expect(resumeInfo.lastEventTime, DateTime.utc(2026, 4, 7, 12, 2));
    });

    test('同步 ack/failure 只改 metadata，不回写事实字段，并支持 bootstrap 导入', () async {
      final first = await repository.recordReaction(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'bath_time_warm_water',
        reactionType: BabyReactionType.cooperating,
        clientTimestamp: DateTime.utc(2026, 4, 7, 12, 3),
        localEventId: 'evt_fact_1',
      );
      final second = await repository.recordReaction(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'bath_time_splash_splash',
        reactionType: BabyReactionType.cooperating,
        clientTimestamp: DateTime.utc(2026, 4, 7, 12, 4),
        localEventId: 'evt_fact_2',
      );

      final beforeFacts = (await localDataSource.listRawEntities(
        activityId: 'bath_time',
      )).map((entity) => entity.toPersistedFactMap()).toList(growable: false);

      await repository.markEventsSynced(
        [first.eventKey],
        phase: 'batch_ack_applied',
        syncedAt: DateTime.utc(2026, 4, 7, 12, 5),
      );
      await repository.markEventsFailed(
        [second.eventKey],
        phase: 'batch_upload_failed',
        errorMessage: 'server 500 while syncing',
        failedAt: DateTime.utc(2026, 4, 7, 12, 6),
      );

      await repository.importServerEvents([
        second.copyWithSyncMetadata(
          syncState: InteractionSyncState.failed,
          lastSyncPhase: 'batch_upload_failed',
          lastSyncError: 'server 500 while syncing',
          lastSyncAt: DateTime.utc(2026, 4, 7, 12, 6),
        ),
        InteractionEventPayload.fromWire(
          eventKey:
              'v1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA:evt_remote',
          localEventId: 'evt_remote',
          installationId:
              'v1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
          spaceId: 'daily_care',
          activityId: 'bath_time',
          phraseId: 'bath_time_all_clean',
          reactionType: 'cooperating',
          clientTimestamp: DateTime.utc(2026, 4, 7, 12, 7),
          syncState: 'synced',
          lastSyncPhase: 'bootstrap_import',
          lastSyncAt: DateTime.utc(2026, 4, 7, 12, 8),
        ),
      ]);

      final events = await repository.listEventHistory(activityId: 'bath_time');
      final afterEntities = await localDataSource.listRawEntities(
        activityId: 'bath_time',
      );
      final afterFacts = afterEntities
          .take(2)
          .map((entity) => entity.toPersistedFactMap())
          .toList(growable: false);
      final syncSummary = await repository.getSyncSummary(
        activityId: 'bath_time',
      );

      expect(events, hasLength(3));
      expect(events[0].syncState, InteractionSyncState.synced);
      expect(events[0].lastSyncPhase, 'batch_ack_applied');
      expect(events[0].lastSyncError, isNull);
      expect(events[1].syncState, InteractionSyncState.failed);
      expect(events[1].lastSyncPhase, 'batch_upload_failed');
      expect(events[1].lastSyncError, 'server 500 while syncing');
      expect(
        events[2].eventKey,
        'v1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA:evt_remote',
      );
      expect(events[2].syncState, InteractionSyncState.synced);
      expect(events[2].lastSyncPhase, 'bootstrap_import');

      expect(afterFacts, beforeFacts);
      expect(syncSummary.pendingCount, 0);
      expect(syncSummary.syncedCount, 2);
      expect(syncSummary.failedCount, 1);
      expect(syncSummary.lastSyncPhase, 'bootstrap_import');
      expect(syncSummary.lastSyncAt, DateTime.utc(2026, 4, 7, 12, 8));
      expect(syncSummary.lastSyncError, isNull);
      expect(
        afterEntities.first.toPersistedSyncMetadataMap().keys,
        containsAll([
          'syncState',
          'lastSyncPhase',
          'lastSyncError',
          'lastSyncAt',
        ]),
      );
    });

    test(
      'bootstrap 同 localEventId 同事实保留本地 raw identity 并标记 synced',
      () async {
        final local = await repository.recordReaction(
          spaceId: 'daily_care',
          activityId: 'bath_time',
          phraseId: 'bath_time_warm_water',
          reactionType: BabyReactionType.cooperating,
          clientTimestamp: DateTime.utc(2026, 4, 7, 13),
          localEventId: 'evt_bootstrap_reconcile',
        );
        final opaqueInstallation = 'v1:${'A' * 43}';

        await repository.importServerEvents([
          InteractionEventPayload.fromWire(
            eventKey: '$opaqueInstallation:evt_bootstrap_reconcile',
            localEventId: 'evt_bootstrap_reconcile',
            installationId: opaqueInstallation,
            spaceId: 'daily_care',
            activityId: 'bath_time',
            phraseId: 'bath_time_warm_water',
            reactionType: 'cooperating',
            clientTimestamp: DateTime.utc(2026, 4, 7, 13),
            syncState: 'synced',
            lastSyncPhase: 'bootstrap_import',
            lastSyncAt: DateTime.utc(2026, 4, 7, 13, 1),
          ),
        ]);

        final events = await repository.listEventHistory(activityId: 'bath_time');
        expect(events, hasLength(1));
        expect(events.single.eventKey, local.eventKey);
        expect(events.single.installationId, local.installationId);
        expect(events.single.syncState, InteractionSyncState.synced);
        expect(events.single.lastSyncPhase, 'bootstrap_import');
      },
    );

    test('bootstrap 远端新设备导入 opaque identity', () async {
      final opaqueInstallation = 'v1:${'C' * 43}';
      await repository.importServerEvents([
        InteractionEventPayload.fromWire(
          eventKey: '$opaqueInstallation:evt_remote_device',
          localEventId: 'evt_remote_device',
          installationId: opaqueInstallation,
          spaceId: 'daily_care',
          activityId: 'bath_time',
          phraseId: 'bath_time_warm_water',
          reactionType: 'cooperating',
          clientTimestamp: DateTime.utc(2026, 4, 7, 13),
          syncState: 'synced',
          lastSyncPhase: 'bootstrap_import',
          lastSyncAt: DateTime.utc(2026, 4, 7, 13, 1),
        ),
      ]);

      final events = await repository.listEventHistory(activityId: 'bath_time');
      expect(events, hasLength(1));
      expect(events.single.eventKey, '$opaqueInstallation:evt_remote_device');
      expect(events.single.installationId, opaqueInstallation);
      expect(events.single.syncState, InteractionSyncState.synced);
    });

    test(
      '拒绝未知 reaction、空 phraseId、错误 eventKey、重复 eventKey 与未知 ack id',
      () async {
        expect(
          () => InteractionEventPayload.fromWire(
            localEventId: 'evt_bad_reaction',
            installationId: 'install_test',
            spaceId: 'daily_care',
            activityId: 'bath_time',
            phraseId: 'bath_time_warm_water',
            reactionType: 'mystery',
            clientTimestamp: DateTime.utc(2026, 4, 7, 12, 4),
          ),
          throwsFormatException,
        );

        expect(
          () => InteractionEventPayload.validated(
            localEventId: 'evt_empty_phrase',
            installationId: 'install_test',
            spaceId: 'daily_care',
            activityId: 'bath_time',
            phraseId: '',
            reactionType: BabyReactionType.cooperating,
            clientTimestamp: DateTime.utc(2026, 4, 7, 12, 4),
          ),
          throwsFormatException,
        );

        expect(
          () => InteractionEventPayload.fromWire(
            eventKey: 'mismatch',
            localEventId: 'evt_bad_key',
            installationId: 'install_test',
            spaceId: 'daily_care',
            activityId: 'bath_time',
            phraseId: 'bath_time_warm_water',
            reactionType: 'cooperating',
            clientTimestamp: DateTime.utc(2026, 4, 7, 12, 4),
          ),
          throwsFormatException,
        );

        final duplicated = await repository.recordReaction(
          spaceId: 'daily_care',
          activityId: 'bath_time',
          phraseId: 'bath_time_warm_water',
          reactionType: BabyReactionType.cooperating,
          clientTimestamp: DateTime.utc(2026, 4, 7, 12, 5),
          localEventId: 'evt_duplicate',
        );

        await expectLater(
          repository.recordReaction(
            spaceId: 'daily_care',
            activityId: 'bath_time',
            phraseId: 'bath_time_splash_splash',
            reactionType: BabyReactionType.cooperating,
            clientTimestamp: DateTime.utc(2026, 4, 7, 12, 6),
            localEventId: 'evt_duplicate',
          ),
          throwsFormatException,
        );

        await expectLater(
          repository.markEventsSynced(['install_test:missing_event']),
          throwsFormatException,
        );

        await expectLater(
          repository.markEventsSynced([
            duplicated.eventKey,
            duplicated.eventKey,
          ]),
          throwsFormatException,
        );

        await expectLater(
          repository.importServerEvents([
            InteractionEventPayload.fromWire(
              eventKey: duplicated.eventKey,
              localEventId: duplicated.localEventId,
              installationId: duplicated.installationId,
              spaceId: duplicated.spaceId,
              activityId: duplicated.activityId,
              phraseId: 'bath_time_all_clean',
              reactionType: duplicated.reactionType.wireValue,
              clientTimestamp: duplicated.clientTimestamp,
            ),
          ]),
          throwsFormatException,
        );
      },
    );

    test('本地数据源打开失败时暴露明确错误', () async {
      await expectLater(
        PracticeLocalDataSource.open(
          directory: tempDir.path,
          isarOpener: (_, {required directory, name = 'practice_local'}) async {
            throw StateError('boom');
          },
        ),
        throwsA(
          isA<PracticePersistenceException>().having(
            (error) => error.message,
            'message',
            contains('打开本地事件库失败'),
          ),
        ),
      );
    });
  });

  test('AssetPhraseService 拒绝缺字段的种子 JSON', () async {
    final service = AssetPhraseService(
      bundle: _FakeAssetBundle(
        strings: const {
          'assets/content/seed_content.json':
              '{"spaces":[{"id":"daily_care","activities":[{"id":"bath_time","phrases":[{"step":1,"audioAsset":"assets/audio/phrases/x.mp3"}]}]}]}',
        },
        binaryAssets: const {'assets/audio/phrases/x.mp3'},
      ),
    );

    await expectLater(service.loadSeedContent(), throwsFormatException);
  });
}

class _WriteThenThrowLocalDataSource extends PracticeLocalDataSource {
  _WriteThenThrowLocalDataSource({required super.isar});

  @override
  Future<void> appendInteractionEvent(InteractionEventPayload payload) async {
    await super.appendInteractionEvent(payload);
    throw StateError('simulated lost response after local commit');
  }
}

class _GeneratedSameScopeResolver implements PracticeContentResolver {
  int resolveActivityCalls = 0;

  @override
  Future<PracticeActivitySnapshot?> resolveActivity({
    required String spaceId,
    required String activityId,
  }) async {
    resolveActivityCalls += 1;
    return const PracticeActivitySnapshot(
      spaceId: 'daily_care',
      activityId: 'bath_time',
      title: 'generated same scope',
      summary: 'generated same scope',
      sceneTag: 'generated',
      coachTip: 'generated',
      contentSource: PracticeContentSource.generated,
      generatedContentId: 'generated_same_scope',
      phrases: <PracticePhrase>[],
    );
  }

  @override
  Future<PracticeActivitySnapshot?> resolveGeneratedContent({
    required String generatedContentId,
  }) async => null;

  @override
  Future<List<PracticeActivitySnapshot>> listGeneratedActivities() async =>
      const <PracticeActivitySnapshot>[];

  @override
  Future<GeneratedCareTurnResumeMarker?>
  loadGeneratedCareTurnResumeMarker() async => null;

  @override
  Future<void> completeGeneratedCareTurnResume({
    required String generatedContentId,
  }) async {}

  @override
  Future<void> clearForLifecycle() async {}
}

class _ThrowingPracticeContentResolver implements PracticeContentResolver {
  const _ThrowingPracticeContentResolver(this.error);

  final Object error;

  @override
  Future<List<PracticeActivitySnapshot>> listGeneratedActivities() async {
    throw error;
  }

  @override
  Future<PracticeActivitySnapshot?> resolveActivity({
    required String spaceId,
    required String activityId,
  }) async => null;

  @override
  Future<PracticeActivitySnapshot?> resolveGeneratedContent({
    required String generatedContentId,
  }) async => null;

  @override
  Future<GeneratedCareTurnResumeMarker?>
  loadGeneratedCareTurnResumeMarker() async => null;

  @override
  Future<void> completeGeneratedCareTurnResume({
    required String generatedContentId,
  }) async {}

  @override
  Future<void> clearForLifecycle() async {}
}

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle({required this.strings, required this.binaryAssets});

  final Map<String, String> strings;
  final Set<String> binaryAssets;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final value = strings[key];
    if (value == null) {
      throw StateError('Missing string asset: $key');
    }
    return value;
  }

  @override
  Future<ByteData> load(String key) async {
    if (!binaryAssets.contains(key)) {
      throw StateError('Missing binary asset: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(const [1, 2, 3]));
  }
}
