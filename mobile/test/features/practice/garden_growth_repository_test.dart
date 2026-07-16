import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/practice/data/local/interaction_event_entity.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/garden_growth_repository.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import '../../support/isar_test_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): resolveBundledIsarLibraryPath()},
    );
  });

  group('GardenGrowthRepository', () {
    late Directory tempDir;
    late PracticeLocalDataSource localDataSource;
    late PracticeRepository practiceRepository;
    late GardenGrowthRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'garden_growth_repository_test_',
      );
      localDataSource = await PracticeLocalDataSource.open(
        directory: tempDir.path,
        name: 'garden_growth_${DateTime.now().microsecondsSinceEpoch}',
      );
      practiceRepository = PracticeRepository(
        assetPhraseService: AssetPhraseService(bundle: rootBundle),
        localDataSource: localDataSource,
        installationIdService: InstallationIdService(
          directoryResolver: () async => tempDir,
          idGenerator: () => 'install_garden_growth_test',
        ),
      );
      repository = GardenGrowthRepository(
        practiceRepository: practiceRepository,
        assetPhraseService: AssetPhraseService(bundle: rootBundle),
      );
    });

    tearDown(() async {
      await practiceRepository.close(deleteFromDisk: true);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('零事件时返回可重建空态而不是错误', () async {
      final snapshot = await repository.buildSnapshot();

      expect(snapshot.isEmpty, isTrue);
      expect(snapshot.knownEvents, 0);
      expect(snapshot.skippedMalformedEvents, 0);
      expect(snapshot.skippedUnknownContentEvents, 0);
      expect(snapshot.primarySpace?.stage, GardenPatchStage.quiet);
      expect(snapshot.primaryActivity?.stage, GardenFlowerStage.seed);
      expect(snapshot.latestImpact, isNull);
      expect(snapshot.milestones.where((item) => item.isAchieved), isEmpty);
    });

    test('本地事件 + bootstrap + unknown phrase + 损坏事件会被稳定投影并降级暴露', () async {
      await practiceRepository.recordReaction(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'bath_time_warm_water',
        reactionType: BabyReactionType.cooperating,
        clientTimestamp: DateTime.utc(2026, 4, 9, 8, 0),
        localEventId: 'evt_local_1',
      );
      await practiceRepository.recordReaction(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'bath_time_splash_splash',
        reactionType: BabyReactionType.cooperating,
        clientTimestamp: DateTime.utc(2026, 4, 9, 8, 1),
        localEventId: 'evt_local_2',
      );
      await practiceRepository.importServerEvents([
        InteractionEventPayload.fromWire(
          eventKey: 'install_garden_growth_test:evt_bootstrap_1',
          localEventId: 'evt_bootstrap_1',
          installationId: 'install_garden_growth_test',
          spaceId: 'daily_care',
          activityId: 'bath_time',
          phraseId: 'bath_time_all_clean',
          reactionType: 'cooperating',
          clientTimestamp: DateTime.utc(2026, 4, 9, 8, 2),
          syncState: 'synced',
          lastSyncPhase: 'bootstrap_import',
          lastSyncAt: DateTime.utc(2026, 4, 9, 8, 3),
        ),
        InteractionEventPayload.fromWire(
          eventKey: 'install_garden_growth_test:evt_unknown_1',
          localEventId: 'evt_unknown_1',
          installationId: 'install_garden_growth_test',
          spaceId: 'daily_care',
          activityId: 'bath_time',
          phraseId: 'bath_time_unknown',
          reactionType: 'cooperating',
          clientTimestamp: DateTime.utc(2026, 4, 9, 8, 4),
          syncState: 'synced',
          lastSyncPhase: 'bootstrap_import',
          lastSyncAt: DateTime.utc(2026, 4, 9, 8, 5),
        ),
      ]);
      await localDataSource.isar.writeTxn(() async {
        final entity = InteractionEventEntity()
          ..eventKey = 'install_garden_growth_test:evt_bad_payload'
          ..localEventId = 'evt_bad_payload'
          ..installationId = 'install_garden_growth_test'
          ..spaceId = 'daily_care'
          ..activityId = 'bath_time'
          ..phraseId = 'bath_time_warm_water'
          ..reactionType = 'mystery'
          ..clientTimestamp = DateTime.utc(2026, 4, 9, 8, 6)
          ..syncState = 'pending';
        await localDataSource.isar.collection<InteractionEventEntity>().put(
          entity,
        );
      });

      final snapshot = await repository.buildSnapshot();

      expect(snapshot.isEmpty, isFalse);
      expect(snapshot.knownEvents, 3);
      expect(snapshot.skippedUnknownContentEvents, 1);
      expect(snapshot.skippedMalformedEvents, 1);
      expect(snapshot.projectionWarning, contains('损坏事件'));
      expect(snapshot.projectionWarning, contains('未知内容事件'));
      expect(snapshot.primarySpace?.stage, GardenPatchStage.rooted);
      expect(snapshot.primaryActivity?.stage, GardenFlowerStage.fullBloom);
      expect(snapshot.latestImpact?.phraseTitle, 'All clean.');
      expect(snapshot.latestImpact?.headline, contains('All clean.'));
      expect(
        snapshot.milestones
            .where((item) => item.isAchieved)
            .map((item) => item.id),
        containsAll(<String>[
          'first_opening',
          'first_cooperating',
          'activity_bath_time_completed',
        ]),
      );
    });

    test('累计句数与坚持天数阈值里程碑会记录达成时间并给未达成项还差提示', () async {
      // 连续 12 天、每天 1 句：触发 cumulative_10 与 streak_7，
      // 而 cumulative_25 / streak_14 仍处于未达成态并带“还差 N”提示。
      for (var day = 1; day <= 12; day += 1) {
        await practiceRepository.recordReaction(
          spaceId: 'daily_care',
          activityId: 'bath_time',
          phraseId: 'bath_time_warm_water',
          reactionType: BabyReactionType.cooperating,
          clientTimestamp: DateTime.utc(2026, 4, day, 8, 0),
          localEventId: 'evt_streak_$day',
        );
      }

      final snapshot = await repository.buildSnapshot();

      expect(snapshot.knownEvents, 12);

      GrowthMilestoneSnapshot byId(String id) =>
          snapshot.milestones.firstWhere((item) => item.id == id);

      final cumulative10 = byId('cumulative_10');
      expect(cumulative10.isAchieved, isTrue);
      expect(cumulative10.achievedAt, isNotNull);

      final cumulative25 = byId('cumulative_25');
      expect(cumulative25.isAchieved, isFalse);
      expect(cumulative25.remainingHint, '还差13句');

      final streak7 = byId('streak_7');
      expect(streak7.isAchieved, isTrue);
      expect(streak7.achievedAt, isNotNull);

      final streak14 = byId('streak_14');
      expect(streak14.isAchieved, isFalse);
      expect(streak14.remainingHint, '还差2天');
    });
  });
}
