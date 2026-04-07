import 'dart:async';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/presentation/practice_session_view_model.dart';
import 'package:mobile/features/practice/presentation/screens/home_screen.dart';
import 'package:mobile/features/practice/presentation/screens/practice_session_screen.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): _resolveBundledIsarLibraryPath()},
    );
  });

  testWidgets('guest 从首页进入练习，记录反应后回到首页看到最近一次本地结果', (WidgetTester tester) async {
    final harness = await _createRepositoryHarness();
    addTearDown(harness.dispose);
    final audioController = _FakePracticeAudioController();

    await _pumpPracticeFlow(
      tester,
      repository: harness.repository,
      audioController: audioController,
    );

    expect(find.byKey(const Key('recent-result-empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-start-practice')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activation-frame')), findsOneWidget);
    expect(find.text('Warm water.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('play-bath_time_warm_water')));
    await tester.pump();
    expect(find.text('音频 · playing'), findsOneWidget);

    audioController.completePlayback();
    await tester.pump();
    expect(find.text('音频 · completed'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('reaction-bath_time_warm_water-engaged')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Splash, splash!'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('reaction-bath_time_splash_splash-imitated')),
    );
    await tester.pumpAndSettle();
    expect(find.text('All clean.'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('reaction-bath_time_all_clean-calm')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recent-result-summary')), findsOneWidget);
    expect(find.textContaining('All clean. · 宝宝放松'), findsOneWidget);

    final history = await harness.repository.listEventHistory(
      activityId: 'bath_time',
    );
    expect(history, hasLength(3));
  });

  testWidgets('播放失败时当前短语保留在原位并显示明确错误状态，可稍后重试', (WidgetTester tester) async {
    final harness = await _createRepositoryHarness();
    addTearDown(harness.dispose);
    final audioController = _FakePracticeAudioController(failOnPlay: true);

    await _pumpPracticeFlow(
      tester,
      repository: harness.repository,
      audioController: audioController,
    );

    await tester.tap(find.byKey(const Key('home-start-practice')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('play-bath_time_warm_water')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('playback-banner')), findsOneWidget);
    expect(find.textContaining('播放失败'), findsOneWidget);
    expect(
      find.byKey(const Key('phrase-card-bath_time_warm_water')),
      findsOneWidget,
    );

    final history = await harness.repository.listEventHistory(
      activityId: 'bath_time',
    );
    expect(history, isEmpty);
  });

  testWidgets('空 phrase 列表会在首页暴露安全错误态，而不是进入白屏练习页', (WidgetTester tester) async {
    final harness = await _createRepositoryHarness();
    addTearDown(harness.dispose);
    final repository = _EmptyPhraseRepository(
      assetPhraseService: harness.assetPhraseService,
      localDataSource: harness.localDataSource,
      installationIdService: harness.installationIdService,
    );

    await _pumpPracticeFlow(
      tester,
      repository: repository,
      audioController: _FakePracticeAudioController(),
    );

    expect(find.byKey(const Key('home-error-banner')), findsOneWidget);
    expect(find.textContaining('首页加载失败'), findsOneWidget);

    final startButton = tester.widget<ElevatedButton>(
      find.byKey(const Key('home-start-practice')),
    );
    expect(startButton.onPressed, isNull);
  });

  testWidgets('连点同一个 reaction chip 不会产生双写，只记录一条本地事件', (
    WidgetTester tester,
  ) async {
    final harness = await _createRepositoryHarness();
    addTearDown(harness.dispose);
    final repository = _DelayedRecordRepository(
      assetPhraseService: harness.assetPhraseService,
      localDataSource: harness.localDataSource,
      installationIdService: harness.installationIdService,
      delay: const Duration(milliseconds: 120),
    );

    await _pumpPracticeFlow(
      tester,
      repository: repository,
      audioController: _FakePracticeAudioController(),
    );

    await tester.tap(find.byKey(const Key('home-start-practice')));
    await tester.pumpAndSettle();

    final reaction = find.byKey(
      const Key('reaction-bath_time_warm_water-engaged'),
    );
    await tester.tap(reaction);
    await tester.tap(reaction);
    await tester.pump();

    expect(repository.recordCalls, 1);
    expect(find.text('保存 · saving'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 140));
    await tester.pumpAndSettle();

    final history = await repository.listEventHistory(activityId: 'bath_time');
    expect(repository.recordCalls, 1);
    expect(history, hasLength(1));
  });
}

Future<void> _pumpPracticeFlow(
  WidgetTester tester, {
  required PracticeRepository repository,
  required PracticeAudioController audioController,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<PracticeRepository>.value(value: repository),
        ChangeNotifierProvider<PracticeSessionViewModel>(
          create: (_) => PracticeSessionViewModel(
            repository: repository,
            spaceId: 'daily_care',
            activityId: 'bath_time',
            audioController: audioController,
          )..initialize(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.build(),
        onGenerateRoute: AppRouter.onGenerateRoute(
          homeBuilder: (_) => const HomeScreen(),
          practiceBuilder: (_) => const PracticeSessionScreen(),
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.pumpAndSettle();
}

Future<_RepositoryHarness> _createRepositoryHarness() async {
  final tempDir = await Directory.systemTemp.createTemp(
    'practice_session_screen_test_',
  );
  final localDataSource = await PracticeLocalDataSource.open(
    directory: tempDir.path,
    name: 'practice_${DateTime.now().microsecondsSinceEpoch}',
  );
  final assetPhraseService = AssetPhraseService(bundle: rootBundle);
  final installationIdService = InstallationIdService(
    directoryResolver: () async => tempDir,
    idGenerator: () => 'install_widget_test',
  );

  final repository = PracticeRepository(
    assetPhraseService: assetPhraseService,
    localDataSource: localDataSource,
    installationIdService: installationIdService,
  );

  return _RepositoryHarness(
    tempDir: tempDir,
    localDataSource: localDataSource,
    assetPhraseService: assetPhraseService,
    installationIdService: installationIdService,
    repository: repository,
  );
}

class _RepositoryHarness {
  const _RepositoryHarness({
    required this.tempDir,
    required this.localDataSource,
    required this.assetPhraseService,
    required this.installationIdService,
    required this.repository,
  });

  final Directory tempDir;
  final PracticeLocalDataSource localDataSource;
  final AssetPhraseService assetPhraseService;
  final InstallationIdService installationIdService;
  final PracticeRepository repository;

  Future<void> dispose() async {
    await localDataSource.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
}

class _FakePracticeAudioController implements PracticeAudioController {
  _FakePracticeAudioController({this.failOnPlay = false});

  final bool failOnPlay;
  final StreamController<void> _completionController =
      StreamController<void>.broadcast();

  int playCount = 0;
  String? lastPlayedAsset;

  @override
  Stream<void> get completionStream => _completionController.stream;

  @override
  Future<void> playAsset(String assetPath) async {
    playCount += 1;
    lastPlayedAsset = assetPath;
    if (failOnPlay) {
      throw StateError('asset missing');
    }
  }

  void completePlayback() {
    if (!_completionController.isClosed) {
      _completionController.add(null);
    }
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _completionController.close();
  }
}

class _EmptyPhraseRepository extends PracticeRepository {
  _EmptyPhraseRepository({
    required super.assetPhraseService,
    required super.localDataSource,
    required super.installationIdService,
  });

  @override
  Future<PracticeActivitySnapshot> getActivitySnapshot({
    required String spaceId,
    required String activityId,
  }) async {
    return const PracticeActivitySnapshot(
      spaceId: 'daily_care',
      activityId: 'bath_time',
      title: '洗澡时间',
      summary: '空活动',
      sceneTag: 'Bath time',
      coachTip: 'tip',
      phrases: [],
    );
  }
}

class _DelayedRecordRepository extends PracticeRepository {
  _DelayedRecordRepository({
    required super.assetPhraseService,
    required super.localDataSource,
    required super.installationIdService,
    required this.delay,
  });

  final Duration delay;
  int recordCalls = 0;

  @override
  Future<InteractionEventPayload> recordReaction({
    required String spaceId,
    required String activityId,
    required String phraseId,
    required BabyReactionType reactionType,
    DateTime? clientTimestamp,
    String? localEventId,
  }) async {
    recordCalls += 1;
    await Future<void>.delayed(delay);
    return super.recordReaction(
      spaceId: spaceId,
      activityId: activityId,
      phraseId: phraseId,
      reactionType: reactionType,
      clientTimestamp: clientTimestamp,
      localEventId: localEventId,
    );
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
