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
import 'package:mobile/features/practice/presentation/practice_session_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): _resolveBundledIsarLibraryPath()},
    );
  });

  group('PracticeSessionNotifier', () {
    test('initialize 会创建 installationId，并在零事件时暴露显式安全空态', () async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      final notifier = PracticeSessionNotifier(
        repository: harness.repository,
        spaceId: 'daily_care',
        activityId: 'bath_time',
        audioController: _SilentPracticeAudioController(),
      );
      addTearDown(notifier.dispose);

      await notifier.initialize();

      expect(notifier.installationId, 'install_notifier_test');
      expect(notifier.homeSummary, isNotNull);
      expect(notifier.homeSummary!.isEmpty, isTrue);
      expect(notifier.restoreStatusMessage, contains('未找到本地记录'));
      expect(notifier.hasRecoverableRestoreIssue, isFalse);
      expect(notifier.canStartPractice, isTrue);
    });

    test('重开 repository 后仍能恢复最近结果，并把下一句指向未完成短语', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'practice_session_notifier_restore_',
      );
      const dbName = 'practice_notifier_restore';

      final firstHarness = await _createHarness(
        tempDir: tempDir,
        dbName: dbName,
      );
      final firstNotifier = PracticeSessionNotifier(
        repository: firstHarness.repository,
        spaceId: 'daily_care',
        activityId: 'bath_time',
        audioController: _SilentPracticeAudioController(),
      );

      await firstNotifier.initialize();
      final firstReady = await firstNotifier.ensureSessionReady();
      expect(firstReady, isTrue);
      expect(firstNotifier.currentPhrase?.phraseId, 'bath_time_warm_water');

      final outcome = await firstNotifier.recordReaction(
        BabyReactionType.engaged,
      );
      expect(outcome, PracticeRecordOutcome.advanced);
      expect(firstNotifier.homeSummary?.totalEvents, 1);

      firstNotifier.dispose();
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
      final secondNotifier = PracticeSessionNotifier(
        repository: secondHarness.repository,
        spaceId: 'daily_care',
        activityId: 'bath_time',
        audioController: _SilentPracticeAudioController(),
      );
      addTearDown(secondNotifier.dispose);

      await secondNotifier.initialize();

      expect(secondNotifier.installationId, 'install_notifier_test');
      expect(secondNotifier.restoreStatusMessage, contains('已从本地恢复'));
      expect(
        secondNotifier.homeSummary?.recentResult?.phraseEnglish,
        'Warm water.',
      );
      expect(secondNotifier.homeSummary?.totalEvents, 1);

      final secondReady = await secondNotifier.ensureSessionReady();
      expect(secondReady, isTrue);
      expect(secondNotifier.currentPhrase?.phraseId, 'bath_time_splash_splash');
      expect(secondNotifier.resumeInfo?.completedPhraseIds, [
        'bath_time_warm_water',
      ]);
    });

    test('损坏事件会在恢复时被跳过并暴露最近失败信息，而不是让首页崩溃', () async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      await harness.localDataSource.isar.writeTxn(() async {
        final entity = InteractionEventEntity()
          ..eventKey = 'install_notifier_test:evt_bad_payload'
          ..localEventId = 'evt_bad_payload'
          ..installationId = 'install_notifier_test'
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

      final notifier = PracticeSessionNotifier(
        repository: harness.repository,
        spaceId: 'daily_care',
        activityId: 'bath_time',
        audioController: _SilentPracticeAudioController(),
      );
      addTearDown(notifier.dispose);

      await notifier.initialize();

      expect(notifier.homeSummary?.isEmpty, isTrue);
      expect(notifier.hasRecoverableRestoreIssue, isTrue);
      expect(notifier.restoreStatusMessage, contains('跳过 1 条损坏记录'));
      expect(notifier.restoreStatusMessage, contains('evt_bad_payload'));
      expect(notifier.canStartPractice, isTrue);
    });

    test('不同 activity 的恢复状态彼此隔离，切回原 activity 时不会串屏', () async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      final repository = _MultiActivityRepository(
        assetPhraseService: harness.assetPhraseService,
        localDataSource: harness.localDataSource,
        installationIdService: harness.installationIdService,
      );

      final bathNotifier = PracticeSessionNotifier(
        repository: repository,
        spaceId: 'daily_care',
        activityId: 'bath_time',
        audioController: _SilentPracticeAudioController(),
      );
      addTearDown(bathNotifier.dispose);
      await bathNotifier.initialize();
      expect(await bathNotifier.ensureSessionReady(), isTrue);
      expect(bathNotifier.currentPhrase?.phraseId, 'bath_time_warm_water');
      await bathNotifier.recordReaction(BabyReactionType.engaged);
      expect(bathNotifier.currentPhrase?.phraseId, 'bath_time_splash_splash');

      final diaperNotifier = PracticeSessionNotifier(
        repository: repository,
        spaceId: 'daily_care',
        activityId: 'diaper_change',
        audioController: _SilentPracticeAudioController(),
      );
      addTearDown(diaperNotifier.dispose);
      await diaperNotifier.initialize();
      expect(await diaperNotifier.ensureSessionReady(), isTrue);
      expect(
        diaperNotifier.currentPhrase?.phraseId,
        'diaper_change_lift_your_legs',
      );
      expect(diaperNotifier.homeSummary?.totalEvents, 0);

      final reopenedBathNotifier = PracticeSessionNotifier(
        repository: repository,
        spaceId: 'daily_care',
        activityId: 'bath_time',
        audioController: _SilentPracticeAudioController(),
      );
      addTearDown(reopenedBathNotifier.dispose);
      await reopenedBathNotifier.initialize();
      expect(await reopenedBathNotifier.ensureSessionReady(), isTrue);
      expect(
        reopenedBathNotifier.currentPhrase?.phraseId,
        'bath_time_splash_splash',
      );
      expect(reopenedBathNotifier.homeSummary?.totalEvents, 1);
    });

    test('未知 activity 会在 initialize 与 ensureSessionReady 中暴露明确错误', () async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      final notifier = PracticeSessionNotifier(
        repository: harness.repository,
        spaceId: 'daily_care',
        activityId: 'missing_activity',
        audioController: _SilentPracticeAudioController(),
      );
      addTearDown(notifier.dispose);

      await notifier.initialize();
      expect(notifier.activitySnapshot, isNull);
      expect(notifier.homeErrorMessage, contains('missing_activity'));
      expect(await notifier.ensureSessionReady(), isFalse);
      expect(notifier.sessionErrorMessage, contains('missing_activity'));
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
    idGenerator: () => 'install_notifier_test',
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
