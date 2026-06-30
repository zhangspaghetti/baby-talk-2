import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/sync/data/repositories/sync_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): _resolveBundledIsarLibraryPath()},
    );
  });

  group('SyncRepository', () {
    late Directory tempDir;
    late PracticeLocalDataSource localDataSource;
    late InstallationIdService installationIdService;
    late SyncRepository syncRepository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sync_repository_test_');
      localDataSource = await PracticeLocalDataSource.open(
        directory: tempDir.path,
        name: 'sync_${DateTime.now().microsecondsSinceEpoch}',
      );
      installationIdService = InstallationIdService(
        directoryResolver: () async => tempDir,
        idGenerator: () => 'install_sync_test',
      );
      await installationIdService.getOrCreate();
      syncRepository = SyncRepository(
        localDataSource: localDataSource,
        installationIdReader: installationIdService.readExisting,
      );
    });

    tearDown(() async {
      await localDataSource.close(deleteFromDisk: true);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('inspectQueue 暴露 pending/synced/failed 与最近失败 phase/time', () async {
      await localDataSource.appendInteractionEvent(
        _payload(
          localEventId: 'evt_pending',
          phraseId: 'bath_time_warm_water',
          clientTimestamp: DateTime.utc(2026, 4, 8, 8, 0),
        ),
      );
      await localDataSource.appendInteractionEvent(
        _payload(
          localEventId: 'evt_synced',
          phraseId: 'bath_time_splash_splash',
          clientTimestamp: DateTime.utc(2026, 4, 8, 8, 1),
          syncState: InteractionSyncState.synced,
          lastSyncPhase: 'batch_ack_applied',
          lastSyncAt: DateTime.utc(2026, 4, 8, 8, 3),
        ),
      );
      await localDataSource.appendInteractionEvent(
        _payload(
          localEventId: 'evt_failed',
          phraseId: 'bath_time_all_clean',
          clientTimestamp: DateTime.utc(2026, 4, 8, 8, 2),
          syncState: InteractionSyncState.failed,
          lastSyncPhase: 'batch_upload_failed',
          lastSyncError: 'server 500',
          lastSyncAt: DateTime.utc(2026, 4, 8, 8, 4),
        ),
      );

      final inspection = await syncRepository.inspectQueue();

      expect(inspection.installationId, 'install_sync_test');
      expect(inspection.summary.pendingCount, 1);
      expect(inspection.summary.syncedCount, 1);
      expect(inspection.summary.failedCount, 1);
      expect(inspection.summary.lastSyncPhase, 'batch_upload_failed');
      expect(inspection.summary.lastSyncError, 'server 500');
      expect(inspection.summary.lastSyncAt, DateTime.utc(2026, 4, 8, 8, 4));
      expect(inspection.pendingUploads, hasLength(1));
      expect(
        inspection.pendingUploads.single.eventKey,
        'install_sync_test:evt_pending',
      );
      expect(
        inspection.pendingUploads.single.toJsonMap().keys,
        isNot(contains('syncState')),
      );
    });

    test('超时失败会保留 pending 状态，并记录最近失败 phase/error/time 供重试定位', () async {
      await localDataSource.appendInteractionEvent(
        _payload(
          localEventId: 'evt_timeout_1',
          phraseId: 'bath_time_warm_water',
          clientTimestamp: DateTime.utc(2026, 4, 8, 9, 0),
        ),
      );
      await localDataSource.appendInteractionEvent(
        _payload(
          localEventId: 'evt_timeout_2',
          phraseId: 'bath_time_splash_splash',
          clientTimestamp: DateTime.utc(2026, 4, 8, 9, 1),
        ),
      );

      await syncRepository.markBatchFailed(
        ['install_sync_test:evt_timeout_1', 'install_sync_test:evt_timeout_2'],
        phase: 'upload_timeout',
        errorMessage: 'request timeout token=secret +8613800138000',
        failedAt: DateTime.utc(2026, 4, 8, 9, 2),
        keepPending: true,
      );

      final inspection = await syncRepository.inspectQueue();

      expect(inspection.summary.pendingCount, 2);
      expect(inspection.summary.failedCount, 0);
      expect(inspection.summary.lastSyncPhase, 'upload_timeout');
      expect(
        inspection.summary.lastSyncError,
        'request timeout token=secret +8613800138000',
      );
      expect(inspection.summary.lastSyncAt, DateTime.utc(2026, 4, 8, 9, 2));
      expect(inspection.pendingUploads, hasLength(2));
    });

    test('拒绝未知 ack id、重复 ack id 与冲突 bootstrap event', () async {
      await localDataSource.appendInteractionEvent(
        _payload(
          localEventId: 'evt_known',
          phraseId: 'bath_time_warm_water',
          clientTimestamp: DateTime.utc(2026, 4, 8, 10, 0),
        ),
      );

      await expectLater(
        syncRepository.markBatchSynced(['install_sync_test:missing']),
        throwsFormatException,
      );

      await expectLater(
        syncRepository.markBatchSynced([
          'install_sync_test:evt_known',
          'install_sync_test:evt_known',
        ]),
        throwsFormatException,
      );

      await expectLater(
        syncRepository.importBootstrapEvents([
          _payload(
            localEventId: 'evt_known',
            phraseId: 'bath_time_all_clean',
            clientTimestamp: DateTime.utc(2026, 4, 8, 10, 1),
          ),
        ]),
        throwsFormatException,
      );
    });
  });
}

InteractionEventPayload _payload({
  required String localEventId,
  required String phraseId,
  required DateTime clientTimestamp,
  InteractionSyncState syncState = InteractionSyncState.pending,
  String? lastSyncPhase,
  String? lastSyncError,
  DateTime? lastSyncAt,
}) {
  return InteractionEventPayload(
    localEventId: localEventId,
    installationId: 'install_sync_test',
    spaceId: 'daily_care',
    activityId: 'bath_time',
    phraseId: phraseId,
    reactionType: BabyReactionType.cooperating,
    clientTimestamp: clientTimestamp,
    syncState: syncState,
    lastSyncPhase: lastSyncPhase,
    lastSyncError: lastSyncError,
    lastSyncAt: lastSyncAt,
  );
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
