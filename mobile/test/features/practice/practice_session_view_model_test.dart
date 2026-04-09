import 'dart:async';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/practice/data/local/interaction_event_entity.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/presentation/practice_session_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): _resolveBundledIsarLibraryPath()},
    );
  });

  group('PracticeSessionViewModel', () {
    test('initialize 会创建 installationId，并在零事件时暴露显式安全空态', () async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      final viewModel = PracticeSessionViewModel(
        repository: harness.repository,
        spaceId: 'daily_care',
        activityId: 'bath_time',
        audioController: _SilentPracticeAudioController(),
      );
      addTearDown(viewModel.dispose);

      await viewModel.initialize();

      expect(viewModel.installationId, 'install_view_model_test');
      expect(viewModel.homeSummary, isNotNull);
      expect(viewModel.homeSummary!.isEmpty, isTrue);
      expect(viewModel.restoreStatusMessage, contains('未找到本地记录'));
      expect(viewModel.hasRecoverableRestoreIssue, isFalse);
      expect(viewModel.canStartPractice, isTrue);
    });

    test('重开 repository 后仍能恢复最近结果，并把下一句指向未完成短语', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'practice_session_view_model_restore_',
      );
      const dbName = 'practice_view_model_restore';

      final firstHarness = await _createHarness(
        tempDir: tempDir,
        dbName: dbName,
      );
      final firstViewModel = PracticeSessionViewModel(
        repository: firstHarness.repository,
        spaceId: 'daily_care',
        activityId: 'bath_time',
        audioController: _SilentPracticeAudioController(),
      );

      await firstViewModel.initialize();
      final firstReady = await firstViewModel.ensureSessionReady();
      expect(firstReady, isTrue);
      expect(firstViewModel.currentPhrase?.phraseId, 'bath_time_warm_water');

      final outcome = await firstViewModel.recordReaction(
        BabyReactionType.engaged,
      );
      expect(outcome, PracticeRecordOutcome.advanced);
      expect(firstViewModel.homeSummary?.totalEvents, 1);

      firstViewModel.dispose();
      await firstHarness.repository.close();

      final secondHarness = await _createHarness(
        tempDir: tempDir,
        dbName: dbName,
      );
      addTearDown(() async {
        await secondHarness.dispose();
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final secondViewModel = PracticeSessionViewModel(
        repository: secondHarness.repository,
        spaceId: 'daily_care',
        activityId: 'bath_time',
        audioController: _SilentPracticeAudioController(),
      );
      addTearDown(secondViewModel.dispose);

      await secondViewModel.initialize();

      expect(secondViewModel.installationId, 'install_view_model_test');
      expect(secondViewModel.restoreStatusMessage, contains('已从本地恢复'));
      expect(
        secondViewModel.homeSummary?.recentResult?.phraseEnglish,
        'Warm water.',
      );
      expect(secondViewModel.homeSummary?.totalEvents, 1);

      final secondReady = await secondViewModel.ensureSessionReady();
      expect(secondReady, isTrue);
      expect(
        secondViewModel.currentPhrase?.phraseId,
        'bath_time_splash_splash',
      );
      expect(secondViewModel.resumeInfo?.completedPhraseIds, [
        'bath_time_warm_water',
      ]);
    });

    test('损坏事件会在恢复时被跳过并暴露最近失败信息，而不是让首页崩溃', () async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      await harness.localDataSource.isar.writeTxn(() async {
        final entity = InteractionEventEntity()
          ..localEventId = 'evt_bad_payload'
          ..installationId = 'install_view_model_test'
          ..spaceId = 'daily_care'
          ..activityId = 'bath_time'
          ..phraseId = 'bath_time_warm_water'
          ..reactionType = 'mystery'
          ..clientTimestamp = DateTime.utc(2026, 4, 8, 1, 0)
          ..syncState = 'pending';
        await harness.localDataSource.isar
            .collection<InteractionEventEntity>()
            .put(entity);
      });

      final viewModel = PracticeSessionViewModel(
        repository: harness.repository,
        spaceId: 'daily_care',
        activityId: 'bath_time',
        audioController: _SilentPracticeAudioController(),
      );
      addTearDown(viewModel.dispose);

      await viewModel.initialize();

      expect(viewModel.homeSummary?.isEmpty, isTrue);
      expect(viewModel.hasRecoverableRestoreIssue, isTrue);
      expect(viewModel.restoreStatusMessage, contains('跳过 1 条损坏记录'));
      expect(viewModel.restoreStatusMessage, contains('evt_bad_payload'));
      expect(viewModel.canStartPractice, isTrue);
    });
  });
}

Future<_Harness> _createHarness({Directory? tempDir, String? dbName}) async {
  final directory =
      tempDir ?? await Directory.systemTemp.createTemp('practice_session_vm_');
  final localDataSource = await PracticeLocalDataSource.open(
    directory: directory.path,
    name: dbName ?? 'practice_${DateTime.now().microsecondsSinceEpoch}',
  );
  final repository = PracticeRepository(
    assetPhraseService: AssetPhraseService(bundle: rootBundle),
    localDataSource: localDataSource,
    installationIdService: InstallationIdService(
      directoryResolver: () async => directory,
      idGenerator: () => 'install_view_model_test',
    ),
  );

  return _Harness(
    tempDir: directory,
    ownsDirectory: tempDir == null,
    localDataSource: localDataSource,
    repository: repository,
  );
}

class _Harness {
  const _Harness({
    required this.tempDir,
    required this.ownsDirectory,
    required this.localDataSource,
    required this.repository,
  });

  final Directory tempDir;
  final bool ownsDirectory;
  final PracticeLocalDataSource localDataSource;
  final PracticeRepository repository;

  Future<void> dispose() async {
    await repository.close(deleteFromDisk: ownsDirectory);
    if (ownsDirectory && await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
}

class _SilentPracticeAudioController implements PracticeAudioController {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  @override
  Stream<void> get completionStream => _controller.stream;

  @override
  Future<void> playAsset(String assetPath) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
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
