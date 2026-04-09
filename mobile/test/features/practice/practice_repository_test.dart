import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): _resolveBundledIsarLibraryPath()},
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
        activityId: 'bath_time',
      );

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
    });

    test('追加事件后保留原始历史，并派生最近结果与恢复信息', () async {
      await repository.recordReaction(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'bath_time_warm_water',
        reactionType: BabyReactionType.engaged,
        clientTimestamp: DateTime.utc(2026, 4, 7, 12, 0),
        localEventId: 'evt_1',
      );
      await repository.recordReaction(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'bath_time_splash_splash',
        reactionType: BabyReactionType.imitated,
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
      expect(homeSummary.recentResult!.reactionType, BabyReactionType.imitated);

      expect(resumeInfo.completedPhraseIds, [
        'bath_time_warm_water',
        'bath_time_splash_splash',
      ]);
      expect(resumeInfo.nextPhraseId, 'bath_time_all_clean');
      expect(resumeInfo.completedCount, 2);
      expect(resumeInfo.lastEventTime, DateTime.utc(2026, 4, 7, 12, 1));
    });

    test('重开 Isar 后仍能从 append-only 事件重建最近结果', () async {
      await repository.recordReaction(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'bath_time_all_clean',
        reactionType: BabyReactionType.calm,
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
      expect(homeSummary.recentResult!.reactionType, BabyReactionType.calm);
      expect(resumeInfo.completedPhraseIds, ['bath_time_all_clean']);
      expect(resumeInfo.lastEventTime, DateTime.utc(2026, 4, 7, 12, 2));
    });

    test('同步 ack/failure 只改 metadata，不回写事实字段，并支持 bootstrap 导入', () async {
      final first = await repository.recordReaction(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'bath_time_warm_water',
        reactionType: BabyReactionType.calm,
        clientTimestamp: DateTime.utc(2026, 4, 7, 12, 3),
        localEventId: 'evt_fact_1',
      );
      final second = await repository.recordReaction(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'bath_time_splash_splash',
        reactionType: BabyReactionType.engaged,
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
          eventKey: 'install_test:evt_remote',
          localEventId: 'evt_remote',
          installationId: 'install_test',
          spaceId: 'daily_care',
          activityId: 'bath_time',
          phraseId: 'bath_time_all_clean',
          reactionType: 'imitated',
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
      final syncSummary = await repository.getSyncSummary(activityId: 'bath_time');

      expect(events, hasLength(3));
      expect(events[0].syncState, InteractionSyncState.synced);
      expect(events[0].lastSyncPhase, 'batch_ack_applied');
      expect(events[0].lastSyncError, isNull);
      expect(events[1].syncState, InteractionSyncState.failed);
      expect(events[1].lastSyncPhase, 'batch_upload_failed');
      expect(events[1].lastSyncError, 'server 500 while syncing');
      expect(events[2].eventKey, 'install_test:evt_remote');
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
        containsAll(['syncState', 'lastSyncPhase', 'lastSyncError', 'lastSyncAt']),
      );
    });

    test('拒绝未知 reaction、空 phraseId、错误 eventKey、重复 eventKey 与未知 ack id', () async {
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
        () => InteractionEventPayload(
          localEventId: 'evt_empty_phrase',
          installationId: 'install_test',
          spaceId: 'daily_care',
          activityId: 'bath_time',
          phraseId: '',
          reactionType: BabyReactionType.calm,
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
          reactionType: 'calm',
          clientTimestamp: DateTime.utc(2026, 4, 7, 12, 4),
        ),
        throwsFormatException,
      );

      final duplicated = await repository.recordReaction(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'bath_time_warm_water',
        reactionType: BabyReactionType.calm,
        clientTimestamp: DateTime.utc(2026, 4, 7, 12, 5),
        localEventId: 'evt_duplicate',
      );

      await expectLater(
        repository.recordReaction(
          spaceId: 'daily_care',
          activityId: 'bath_time',
          phraseId: 'bath_time_splash_splash',
          reactionType: BabyReactionType.engaged,
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
        repository.markEventsSynced([duplicated.eventKey, duplicated.eventKey]),
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
    });

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

String _resolveBundledIsarLibraryPath() {
  final pubCacheRoot = Platform.environment['PUB_CACHE'];
  final localAppData = Platform.environment['LOCALAPPDATA'];
  final candidateRoots = <Directory>[
    if (pubCacheRoot != null) Directory(pubCacheRoot),
    if (localAppData != null) Directory('$localAppData\\Pub\\Cache'),
  ];

  for (final root in candidateRoots) {
    final hostedDirectory = Directory(
      '${root.path}${Platform.pathSeparator}hosted',
    );
    if (!hostedDirectory.existsSync()) {
      continue;
    }

    for (final host in hostedDirectory.listSync().whereType<Directory>()) {
      for (final packageDir in host.listSync().whereType<Directory>()) {
        final packageName = packageDir.path.split(RegExp(r'[\\/]')).last;
        if (!packageName.startsWith('isar_flutter_libs-')) {
          continue;
        }

        final dll = File(
          '${packageDir.path}${Platform.pathSeparator}windows${Platform.pathSeparator}isar.dll',
        );
        if (dll.existsSync()) {
          return dll.path;
        }
      }
    }
  }

  throw StateError('未在 pub cache 中找到 isar_flutter_libs/windows/isar.dll');
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
