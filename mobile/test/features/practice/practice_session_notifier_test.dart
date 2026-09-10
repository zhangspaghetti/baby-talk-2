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
import '../../support/isar_test_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): resolveBundledIsarLibraryPath()},
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
        BabyReactionType.cooperating,
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
      expect(notifier.restoreStatusMessage, contains('跳过 1 条暂不可用记录'));
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
      await bathNotifier.recordReaction(BabyReactionType.cooperating);
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
      await notifier.retryHomeLoad();
      expect(notifier.homeErrorMessage, contains('missing_activity'));
      expect(await notifier.ensureSessionReady(), isFalse);
      expect(notifier.sessionErrorMessage, contains('missing_activity'));
    });

    test('recordReaction 保存失败时保留当前短语并暴露错误状态', () async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      final repository = _FailingRecordRepository(
        assetPhraseService: harness.assetPhraseService,
        localDataSource: harness.localDataSource,
        installationIdService: harness.installationIdService,
      );
      final notifier = PracticeSessionNotifier(
        repository: repository,
        spaceId: 'daily_care',
        activityId: 'bath_time',
        audioController: _SilentPracticeAudioController(),
      );
      addTearDown(notifier.dispose);

      await notifier.initialize();
      expect(await notifier.ensureSessionReady(), isTrue);
      expect(notifier.currentPhrase?.phraseId, 'bath_time_warm_water');

      final outcome = await notifier.recordReaction(
        BabyReactionType.cooperating,
      );

      expect(outcome, PracticeRecordOutcome.failed);
      expect(notifier.currentPhrase?.phraseId, 'bath_time_warm_water');
      expect(notifier.saveStatus, PracticeSaveStatus.error);
      expect(notifier.saveStatusLabel, 'error');
      expect(notifier.saveMessage, contains('保存失败'));
      expect(notifier.sessionCompleted, isFalse);
    });

    test('playCurrentPhrase 会进入 playing、完成后可记录并推进短语', () async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      final audioController = _ControllablePracticeAudioController();
      final notifier = PracticeSessionNotifier(
        repository: harness.repository,
        spaceId: 'daily_care',
        activityId: 'bath_time',
        audioController: audioController,
      );
      addTearDown(notifier.dispose);

      await notifier.initialize();
      expect(await notifier.ensureSessionReady(), isTrue);
      expect(notifier.playbackStatusLabel, 'idle');
      expect(notifier.saveStatusLabel, 'idle');
      expect(notifier.canPlayCurrentPhrase, isTrue);
      expect(notifier.canSubmitReaction, isTrue);

      await notifier.playCurrentPhrase();
      expect(notifier.playbackStatus, PracticePlaybackStatus.playing);
      expect(audioController.playedAssets.single, endsWith('warm_water.mp3'));

      audioController.completePlayback();
      await Future<void>.delayed(Duration.zero);
      expect(notifier.playbackStatus, PracticePlaybackStatus.completed);
      expect(notifier.playbackMessage, contains('播放完成'));

      final outcome = await notifier.recordReaction(
        BabyReactionType.cooperating,
      );

      expect(outcome, PracticeRecordOutcome.advanced);
      expect(notifier.currentPhrase?.phraseId, 'bath_time_splash_splash');
      expect(notifier.playbackStatus, PracticePlaybackStatus.idle);
      expect(notifier.saveStatus, PracticeSaveStatus.saved);
      expect(notifier.saveStatusLabel, 'saved');
      expect(notifier.isPhraseCompleted('bath_time_warm_water'), isTrue);
      expect(notifier.labelForReaction(BabyReactionType.cooperating), '配合');
      expect(notifier.labelForReaction(BabyReactionType.hesitant), '犹豫');
      expect(notifier.labelForReaction(BabyReactionType.resisting), '不想');
      expect(notifier.labelForReaction(BabyReactionType.noResponse), '没反应');
      expect(notifier.labelForReaction(BabyReactionType.other), '其他');
    });

    test('播放失败与播放超时都会留下可重试状态', () async {
      final failingHarness = await _createHarness();
      addTearDown(failingHarness.dispose);
      final failingAudio = _ControllablePracticeAudioController(
        failOnPlay: true,
      );
      final failingNotifier = PracticeSessionNotifier(
        repository: failingHarness.repository,
        spaceId: 'daily_care',
        activityId: 'bath_time',
        audioController: failingAudio,
      );
      addTearDown(failingNotifier.dispose);

      await failingNotifier.initialize();
      expect(await failingNotifier.ensureSessionReady(), isTrue);
      await failingNotifier.playCurrentPhrase();

      expect(failingNotifier.playbackStatus, PracticePlaybackStatus.error);
      expect(failingNotifier.playbackStatusLabel, 'error');
      expect(failingNotifier.playbackMessage, contains('播放失败'));

      final timeoutHarness = await _createHarness();
      addTearDown(timeoutHarness.dispose);
      final timeoutAudio = _ControllablePracticeAudioController();
      final timeoutNotifier = PracticeSessionNotifier(
        repository: timeoutHarness.repository,
        spaceId: 'daily_care',
        activityId: 'bath_time',
        audioController: timeoutAudio,
        playbackTimeout: const Duration(milliseconds: 1),
      );
      addTearDown(timeoutNotifier.dispose);

      await timeoutNotifier.initialize();
      expect(await timeoutNotifier.ensureSessionReady(), isTrue);
      await timeoutNotifier.playCurrentPhrase();
      expect(timeoutNotifier.playbackStatus, PracticePlaybackStatus.playing);

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(timeoutNotifier.playbackStatus, PracticePlaybackStatus.idle);
      expect(timeoutNotifier.playbackMessage, contains('播放超时'));
      expect(timeoutAudio.stopCount, greaterThanOrEqualTo(2));
    });

    test('动态模式使用生成内容且记录反应不写入本地事件', () async {
      final harness = await _createHarness();
      addTearDown(harness.dispose);
      final repository = _DynamicPracticeRepository(
        assetPhraseService: harness.assetPhraseService,
        localDataSource: harness.localDataSource,
        installationIdService: harness.installationIdService,
      );
      final audioController = _ControllablePracticeAudioController();
      final notifier = PracticeSessionNotifier(
        repository: repository,
        spaceId: 'daily_care',
        activityId: 'bath_time',
        isDynamic: true,
        babyAgeMonths: 18,
        sceneTag: 'bedtime',
        accessTokenLoader: () => 'access_dynamic',
        audioController: audioController,
      );
      addTearDown(notifier.dispose);

      await notifier.initialize();

      expect(repository.dynamicCallCount, 1);
      expect(repository.lastAccessToken, 'access_dynamic');
      expect(repository.lastBabyAgeMonths, 18);
      expect(repository.lastSceneTag, 'bedtime');
      expect(notifier.homeSummary?.activityId, 'dynamic_activity');
      expect(notifier.restoreStatusMessage, contains('动态练习已就绪'));
      expect(await notifier.ensureSessionReady(), isTrue);
      expect(notifier.currentPhrase?.phraseId, 'dynamic_phrase_1');

      await notifier.playCurrentPhrase();
      expect(notifier.playbackStatus, PracticePlaybackStatus.error);
      expect(notifier.playbackMessage, contains('音频资源缺失'));

      final outcome = await notifier.recordReaction(
        BabyReactionType.cooperating,
      );

      expect(outcome, PracticeRecordOutcome.advanced);
      expect(notifier.currentPhrase?.phraseId, 'dynamic_phrase_2');
      expect(notifier.homeSummary?.totalEvents, 0);
      expect((await repository.getSyncSummary()).pendingCount, 0);
    });
  });

  group('V21 phrase interaction phase', () {
    test('saveCurrentPhrase 把 phrasePhase 从 ready 改为 saved', () async {
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
      await notifier.ensureSessionReady();

      expect(notifier.phrasePhase, PhraseInteractionPhase.ready);
      notifier.saveCurrentPhrase();
      expect(notifier.phrasePhase, PhraseInteractionPhase.saved);
    });

    test('recordReaction 在 saved 阶段推进 index 并把 phase 设为 advancing', () async {
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
      await notifier.ensureSessionReady();
      notifier.saveCurrentPhrase();

      final outcome = await notifier.recordReaction(
        BabyReactionType.cooperating,
      );
      expect(outcome, PracticeRecordOutcome.advanced);
      expect(notifier.phrasePhase, PhraseInteractionPhase.advancing);
      // index already advanced — next phrase visible immediately
      expect(notifier.currentPhrase?.phraseId, 'bath_time_splash_splash');
    });

    test('skipToNextPhrase 在 saved 阶段跳过反应直接到下一句', () async {
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
      await notifier.ensureSessionReady();
      expect(notifier.currentPhrase?.phraseId, 'bath_time_warm_water');

      notifier.saveCurrentPhrase();
      notifier.skipToNextPhrase();

      expect(notifier.currentPhrase?.phraseId, 'bath_time_splash_splash');
      expect(notifier.phrasePhase, PhraseInteractionPhase.ready);
    });

    test('cancelAutoAdvance 在 advancing 阶段把 phase 退回 saved', () async {
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
      await notifier.ensureSessionReady();
      notifier.saveCurrentPhrase();
      await notifier.recordReaction(BabyReactionType.cooperating);
      expect(notifier.phrasePhase, PhraseInteractionPhase.advancing);

      notifier.cancelAutoAdvance();
      expect(notifier.phrasePhase, PhraseInteractionPhase.saved);
    });

    test('endSession 把 phase 设为 complete 并标记 sessionCompleted', () async {
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
      await notifier.ensureSessionReady();

      notifier.endSession();
      expect(notifier.phrasePhase, PhraseInteractionPhase.complete);
      expect(notifier.sessionCompleted, isTrue);
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

class _FailingRecordRepository extends PracticeRepository {
  _FailingRecordRepository({
    required super.assetPhraseService,
    required super.localDataSource,
    required super.installationIdService,
  });

  @override
  Future<InteractionEventPayload> recordReaction({
    required String spaceId,
    required String activityId,
    required String phraseId,
    required BabyReactionType reactionType,
    String? generatedContentId,
    String? utteranceId,
    DateTime? clientTimestamp,
    String? localEventId,
  }) async {
    throw StateError('disk full');
  }
}

class _DynamicPracticeRepository extends PracticeRepository {
  _DynamicPracticeRepository({
    required super.assetPhraseService,
    required super.localDataSource,
    required super.installationIdService,
  });

  int dynamicCallCount = 0;
  int? lastBabyAgeMonths;
  String? lastSceneTag;
  String? lastAccessToken;

  @override
  Future<PracticeActivitySnapshot> getActivitySnapshotDynamic({
    required int babyAgeMonths,
    String? sceneTag,
    String? fallbackSpaceId,
    String? fallbackActivityId,
    String? accessToken,
  }) async {
    dynamicCallCount += 1;
    lastBabyAgeMonths = babyAgeMonths;
    lastSceneTag = sceneTag;
    lastAccessToken = accessToken;
    return const PracticeActivitySnapshot(
      spaceId: 'dynamic',
      activityId: 'dynamic_activity',
      title: '睡前动态练习',
      summary: '根据宝宝状态生成两句练习。',
      sceneTag: 'bedtime',
      coachTip: '用轻一点的声音，给宝宝留出回应时间。',
      phrases: [
        PracticePhrase(
          spaceId: 'dynamic',
          activityId: 'dynamic_activity',
          phraseId: 'dynamic_phrase_1',
          step: 1,
          english: 'Soft light.',
          chinese: '灯光柔一点。',
          pronunciation: 'sɔːft laɪt',
          difficulty: 'starter',
          audioAsset: '',
        ),
        PracticePhrase(
          spaceId: 'dynamic',
          activityId: 'dynamic_activity',
          phraseId: 'dynamic_phrase_2',
          step: 2,
          english: 'Sleepy time.',
          chinese: '准备睡觉啦。',
          pronunciation: 'ˈsliːpi taɪm',
          difficulty: 'starter',
          audioAsset: '',
        ),
      ],
    );
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

class _ControllablePracticeAudioController implements PracticeAudioController {
  _ControllablePracticeAudioController({this.failOnPlay = false});

  final bool failOnPlay;
  final StreamController<void> _controller = StreamController<void>.broadcast();
  final List<String> playedAssets = [];
  int stopCount = 0;

  @override
  Stream<void> get completionStream => _controller.stream;

  @override
  Future<void> playAsset(String assetPath) async {
    if (failOnPlay) {
      throw StateError('speaker unavailable');
    }
    playedAssets.add(assetPath);
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
  }

  void completePlayback() {
    _controller.add(null);
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
