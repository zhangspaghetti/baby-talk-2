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
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
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
          ..eventKey = 'install_view_model_test:evt_bad_payload'
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

    test('不同 activity 的恢复状态彼此隔离，切回原 activity 时不会串屏', () async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      final repository = _MultiActivityRepository(
        assetPhraseService: harness.assetPhraseService,
        localDataSource: harness.localDataSource,
        installationIdService: harness.installationIdService,
      );

      final bathViewModel = PracticeSessionViewModel(
        repository: repository,
        spaceId: 'daily_care',
        activityId: 'bath_time',
        audioController: _SilentPracticeAudioController(),
      );
      addTearDown(bathViewModel.dispose);
      await bathViewModel.initialize();
      expect(await bathViewModel.ensureSessionReady(), isTrue);
      expect(bathViewModel.currentPhrase?.phraseId, 'bath_time_warm_water');
      await bathViewModel.recordReaction(BabyReactionType.engaged);
      expect(bathViewModel.currentPhrase?.phraseId, 'bath_time_splash_splash');

      final diaperViewModel = PracticeSessionViewModel(
        repository: repository,
        spaceId: 'daily_care',
        activityId: 'diaper_change',
        audioController: _SilentPracticeAudioController(),
      );
      addTearDown(diaperViewModel.dispose);
      await diaperViewModel.initialize();
      expect(await diaperViewModel.ensureSessionReady(), isTrue);
      expect(
        diaperViewModel.currentPhrase?.phraseId,
        'diaper_change_lift_your_legs',
      );
      expect(diaperViewModel.homeSummary?.totalEvents, 0);

      final reopenedBathViewModel = PracticeSessionViewModel(
        repository: repository,
        spaceId: 'daily_care',
        activityId: 'bath_time',
        audioController: _SilentPracticeAudioController(),
      );
      addTearDown(reopenedBathViewModel.dispose);
      await reopenedBathViewModel.initialize();
      expect(await reopenedBathViewModel.ensureSessionReady(), isTrue);
      expect(
        reopenedBathViewModel.currentPhrase?.phraseId,
        'bath_time_splash_splash',
      );
      expect(reopenedBathViewModel.homeSummary?.totalEvents, 1);
    });

    test('未知 activity 会在 initialize 与 ensureSessionReady 中暴露明确错误', () async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      final viewModel = PracticeSessionViewModel(
        repository: harness.repository,
        spaceId: 'daily_care',
        activityId: 'missing_activity',
        audioController: _SilentPracticeAudioController(),
      );
      addTearDown(viewModel.dispose);

      await viewModel.initialize();
      expect(viewModel.activitySnapshot, isNull);
      expect(viewModel.homeErrorMessage, contains('missing_activity'));
      expect(await viewModel.ensureSessionReady(), isFalse);
      expect(viewModel.sessionErrorMessage, contains('missing_activity'));
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
  final assetPhraseService = AssetPhraseService(bundle: rootBundle);
  final installationIdService = InstallationIdService(
    directoryResolver: () async => directory,
    idGenerator: () => 'install_view_model_test',
  );
  final repository = PracticeRepository(
    assetPhraseService: assetPhraseService,
    localDataSource: localDataSource,
    installationIdService: installationIdService,
  );

  return _Harness(
    tempDir: directory,
    ownsDirectory: tempDir == null,
    localDataSource: localDataSource,
    assetPhraseService: assetPhraseService,
    installationIdService: installationIdService,
    repository: repository,
  );
}

class _Harness {
  const _Harness({
    required this.tempDir,
    required this.ownsDirectory,
    required this.localDataSource,
    required this.assetPhraseService,
    required this.installationIdService,
    required this.repository,
  });

  final Directory tempDir;
  final bool ownsDirectory;
  final PracticeLocalDataSource localDataSource;
  final AssetPhraseService assetPhraseService;
  final InstallationIdService installationIdService;
  final PracticeRepository repository;

  Future<void> dispose() async {
    await repository.close(deleteFromDisk: ownsDirectory);
    if (ownsDirectory && await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
}

class _MultiActivityRepository extends PracticeRepository {
  _MultiActivityRepository({
    required super.assetPhraseService,
    required super.localDataSource,
    required super.installationIdService,
  });

  static const _secondarySnapshot = PracticeActivitySnapshot(
    spaceId: 'daily_care',
    activityId: 'diaper_change',
    title: '换尿布',
    summary: '从抬腿到收尾，保持同一条照护节奏。',
    sceneTag: 'Diaper change',
    coachTip: '先说动作，再说感受，让语气保持稳定和安心。',
    phrases: [
      PracticePhrase(
        spaceId: 'daily_care',
        activityId: 'diaper_change',
        phraseId: 'diaper_change_lift_your_legs',
        step: 1,
        english: 'Lift your legs.',
        chinese: '抬一下小腿。',
        pronunciation: 'lɪft jʊr lɛgz',
        difficulty: 'starter',
        audioAsset: 'assets/audio/phrases/bath_time_warm_water.mp3',
      ),
      PracticePhrase(
        spaceId: 'daily_care',
        activityId: 'diaper_change',
        phraseId: 'diaper_change_all_dry',
        step: 2,
        english: 'All dry.',
        chinese: '已经擦干啦。',
        pronunciation: 'ɔːl draɪ',
        difficulty: 'starter',
        audioAsset: 'assets/audio/phrases/bath_time_all_clean.mp3',
      ),
    ],
  );

  @override
  Future<PracticeActivitySnapshot> getActivitySnapshot({
    required String spaceId,
    required String activityId,
  }) async {
    if (spaceId == _secondarySnapshot.spaceId &&
        activityId == _secondarySnapshot.activityId) {
      return _secondarySnapshot;
    }
    return super.getActivitySnapshot(spaceId: spaceId, activityId: activityId);
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
