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
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/presentation/account_view_model.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/presentation/practice_session_view_model.dart';
import 'package:mobile/features/practice/presentation/screens/home_screen.dart';
import 'package:mobile/features/practice/presentation/screens/practice_session_screen.dart';
import 'package:mobile/features/shell/presentation/app_shell_screen.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): _resolveBundledIsarLibraryPath()},
    );
  });

  testWidgets('guest 从首页进入练习，记录反应后回到首页看到最近一次本地结果', (WidgetTester tester) async {
    final harness = await tester.runAsync<_RepositoryHarness>(
      _createRepositoryHarness,
    );
    addTearDown(harness!.dispose);
    final audioController = _FakePracticeAudioController();

    await _pumpPracticeFlow(
      tester,
      repository: harness.repository,
      audioController: audioController,
    );

    await _scrollHomeUntilVisible(
      tester,
      find.byKey(const Key('home-restore-banner')),
    );
    expect(find.byKey(const Key('home-restore-banner')), findsOneWidget);
    expect(find.textContaining('未找到本地记录'), findsOneWidget);

    await _openPracticeScreen(tester);

    expect(find.byKey(const Key('activation-frame')), findsOneWidget);
    expect(
      find.byKey(const Key('phrase-card-bath_time_warm_water')),
      findsOneWidget,
    );

    await _playCurrentPhrase(tester);
    expect(audioController.playCount, 1);
    expect(
      audioController.lastPlayedAsset,
      'audio/phrases/bath_time_warm_water.mp3',
    );

    audioController.completePlayback();
    await tester.pump();
    expect(find.text('音频 · completed'), findsOneWidget);

    await _recordReactionFromScreen(tester, BabyReactionType.engaged);
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('phrase-card-bath_time_splash_splash')),
    );
    expect(
      find.byKey(const Key('phrase-card-bath_time_splash_splash')),
      findsOneWidget,
    );

    await _recordReactionFromScreen(tester, BabyReactionType.imitated);
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('phrase-card-bath_time_all_clean')),
    );
    expect(
      find.byKey(const Key('phrase-card-bath_time_all_clean')),
      findsOneWidget,
    );

    final finalOutcome = await _recordReactionFromScreen(
      tester,
      BabyReactionType.calm,
    );
    expect(finalOutcome, PracticeRecordOutcome.completed);
    await _pumpUntilFound(tester, find.byKey(const Key('home-start-practice')));
    await tester.ensureVisible(find.byKey(const Key('recent-result-summary')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recent-result-summary')), findsOneWidget);
    expect(find.textContaining('All clean. · 宝宝放松'), findsOneWidget);

    final history = await tester.runAsync<List<InteractionEventPayload>>(
      () => harness.repository.listEventHistory(activityId: 'bath_time'),
    );
    expect(history, hasLength(3));
  });

  testWidgets('个性化首页会显示宝宝名字和阶段，同时保持原有开始练习入口', (WidgetTester tester) async {
    final harness = await tester.runAsync<_RepositoryHarness>(
      _createRepositoryHarness,
    );
    addTearDown(harness!.dispose);

    await _pumpPracticeFlow(
      tester,
      repository: harness.repository,
      audioController: _FakePracticeAudioController(),
      onboardingSnapshot: OnboardingSnapshot(
        childDisplayName: '米米',
        ageBucket: OnboardingAgeBucket.twelveToEighteen,
        approxMonths: 15,
        currentStage: 'gesture_plus_words',
        starterSpaceId: 'daily_care',
        starterActivityId: 'bath_time',
        starterPhraseId: 'bath_time_warm_water',
        consentState: OnboardingConsentState.localOnly,
        completedAt: DateTime.utc(2026, 4, 8, 8),
      ),
    );

    expect(find.byKey(const Key('home-local-only-banner')), findsOneWidget);
    expect(find.byKey(const Key('personalized-home-heading')), findsOneWidget);
    expect(find.textContaining('米米'), findsWidgets);
    expect(find.byKey(const Key('home-stage-pill')), findsOneWidget);
    expect(find.textContaining('动作带词连接期'), findsOneWidget);
    expect(find.byKey(const Key('home-starter-seed')), findsOneWidget);
    expect(find.textContaining('Warm water.'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('home-start-practice')),
      180,
      scrollable: _homeScrollable(),
    );
    await tester.pumpAndSettle();
    final startButton = tester.widget<ElevatedButton>(
      find.byKey(const Key('home-start-practice')),
    );
    expect(startButton.onPressed, isNotNull);
  });

  testWidgets('个性化 shell 保留 drawer 与首页标题，同时仍能进入练习流', (
    WidgetTester tester,
  ) async {
    final harness = await tester.runAsync<_RepositoryHarness>(
      _createRepositoryHarness,
    );
    addTearDown(harness!.dispose);

    await _pumpPracticeFlow(
      tester,
      repository: harness.repository,
      audioController: _FakePracticeAudioController(),
      onboardingSnapshot: OnboardingSnapshot(
        childDisplayName: '米米',
        ageBucket: OnboardingAgeBucket.twelveToEighteen,
        approxMonths: 15,
        currentStage: 'gesture_plus_words',
        starterSpaceId: 'daily_care',
        starterActivityId: 'bath_time',
        starterPhraseId: 'bath_time_warm_water',
        consentState: OnboardingConsentState.localOnly,
        completedAt: DateTime.utc(2026, 4, 8, 8),
      ),
      useShell: true,
    );

    expect(find.byKey(const Key('shell-ready')), findsOneWidget);
    expect(find.text('米米 的首页'), findsOneWidget);

    await tester.tap(find.byKey(const Key('shell-drawer-trigger')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shell-end-drawer')), findsOneWidget);
    expect(find.byKey(const Key('shell-drawer-child-name')), findsOneWidget);
    expect(find.text('米米'), findsWidgets);
    expect(
      find.byKey(const Key('shell-drawer-local-only-note')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    await _openPracticeScreen(tester);

    expect(find.byKey(const Key('activation-frame')), findsOneWidget);
    expect(
      find.byKey(const Key('phrase-card-bath_time_warm_water')),
      findsOneWidget,
    );
  });

  testWidgets('播放失败时当前短语保留在原位并显示明确错误状态，可稍后重试', (WidgetTester tester) async {
    final harness = await tester.runAsync<_RepositoryHarness>(
      _createRepositoryHarness,
    );
    addTearDown(harness!.dispose);
    final audioController = _FakePracticeAudioController(failOnPlay: true);

    await _pumpPracticeFlow(
      tester,
      repository: harness.repository,
      audioController: audioController,
    );

    await _openPracticeScreen(tester);

    await _playCurrentPhrase(tester);
    await _pumpUntilFound(tester, find.byKey(const Key('playback-banner')));

    expect(find.byKey(const Key('playback-banner')), findsOneWidget);
    expect(find.textContaining('播放失败'), findsOneWidget);
    expect(
      find.byKey(const Key('phrase-card-bath_time_warm_water')),
      findsOneWidget,
    );

    final history = await tester.runAsync<List<InteractionEventPayload>>(
      () => harness.repository.listEventHistory(activityId: 'bath_time'),
    );
    expect(history, isEmpty);
  });

  testWidgets('空 phrase 列表会在首页暴露安全错误态，而不是进入白屏练习页', (WidgetTester tester) async {
    final harness = await tester.runAsync<_RepositoryHarness>(
      _createRepositoryHarness,
    );
    addTearDown(harness!.dispose);
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

    await _scrollHomeUntilVisible(
      tester,
      find.byKey(const Key('home-error-banner')),
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
    final harness = await tester.runAsync<_RepositoryHarness>(
      _createRepositoryHarness,
    );
    addTearDown(harness!.dispose);
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

    await _openPracticeScreen(tester);

    final outcomes = await tester.runAsync<List<PracticeRecordOutcome>>(
      () async {
        final context = tester.element(find.byType(PracticeSessionScreen));
        final viewModel = Provider.of<PracticeSessionViewModel>(
          context,
          listen: false,
        );
        final first = viewModel.recordReaction(BabyReactionType.engaged);
        final second = viewModel.recordReaction(BabyReactionType.engaged);
        return Future.wait([first, second]);
      },
    );
    await tester.pump();

    expect(outcomes, [
      PracticeRecordOutcome.advanced,
      PracticeRecordOutcome.ignored,
    ]);
    expect(repository.recordCalls, 1);

    await _pumpUntilFound(
      tester,
      find.byKey(const Key('phrase-card-bath_time_splash_splash')),
    );

    final history = await tester.runAsync<List<InteractionEventPayload>>(
      () => repository.listEventHistory(activityId: 'bath_time'),
    );
    expect(repository.recordCalls, 1);
    expect(history, hasLength(1));
  });
}

Future<void> _pumpPracticeFlow(
  WidgetTester tester, {
  required PracticeRepository repository,
  required PracticeAudioController audioController,
  OnboardingSnapshot? onboardingSnapshot,
  bool useShell = false,
}) async {
  final accountViewModel = AccountViewModel(
    repository: _StaticAccountRepository(
      snapshot: onboardingSnapshot == null
          ? AccountLocalSnapshot.signedOut
          : AccountLocalSnapshot.localOnly,
    ),
  );
  addTearDown(accountViewModel.dispose);
  final viewModel = PracticeSessionViewModel(
    repository: repository,
    spaceId: 'daily_care',
    activityId: 'bath_time',
    audioController: audioController,
  );
  addTearDown(viewModel.dispose);
  await tester.runAsync(() async {
    await Future.wait([accountViewModel.initialize(), viewModel.initialize()]);
  });

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<PracticeRepository>.value(value: repository),
        ChangeNotifierProvider<AccountViewModel>.value(value: accountViewModel),
        ChangeNotifierProvider<PracticeSessionViewModel>.value(
          value: viewModel,
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.build(),
        onGenerateRoute: AppRouter.onGenerateRoute(
          shellBuilder: useShell
              ? (_) => AppShellScreen(onboardingSnapshot: onboardingSnapshot)
              : null,
          homeBuilder: useShell
              ? null
              : (_) => HomeScreen(onboardingSnapshot: onboardingSnapshot),
          practiceBuilder: (_) => const PracticeSessionScreen(),
        ),
      ),
    ),
  );

  await _pumpUntilFound(
    tester,
    useShell ? find.byKey(const Key('shell-ready')) : find.byType(HomeScreen),
  );
  if (!useShell) {
    await _pumpUntilFound(tester, find.byKey(const Key('home-account-card')));
  }
}

Future<void> _playCurrentPhrase(WidgetTester tester) async {
  expect(find.byKey(const Key('play-bath_time_warm_water')), findsOneWidget);

  final context = tester.element(find.byType(PracticeSessionScreen));
  final viewModel = Provider.of<PracticeSessionViewModel>(
    context,
    listen: false,
  );
  await tester.runAsync(() async {
    await viewModel.playCurrentPhrase();
  });
  await tester.pump();
}

Future<PracticeRecordOutcome> _recordReactionFromScreen(
  WidgetTester tester,
  BabyReactionType reactionType,
) async {
  final context = tester.element(find.byType(PracticeSessionScreen));
  final viewModel = Provider.of<PracticeSessionViewModel>(
    context,
    listen: false,
  );
  final outcome =
      await tester.runAsync<PracticeRecordOutcome>(() async {
        return viewModel.recordReaction(reactionType);
      }) ??
      PracticeRecordOutcome.failed;
  await tester.pump();
  if (outcome == PracticeRecordOutcome.completed &&
      Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
    await tester.pump();
  }
  return outcome;
}

Future<void> _scrollHomeUntilVisible(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 180, scrollable: _homeScrollable());
  await tester.pumpAndSettle();
}

Future<void> _openPracticeScreen(WidgetTester tester) async {
  final homeFinder = find.byType(HomeScreen);
  expect(homeFinder, findsOneWidget);

  await _scrollHomeUntilVisible(
    tester,
    find.byKey(const Key('home-start-practice')),
  );
  final startButton = tester.widget<ElevatedButton>(
    find.byKey(const Key('home-start-practice')),
  );
  expect(startButton.onPressed, isNotNull);

  final context = tester.element(homeFinder);
  final viewModel = Provider.of<PracticeSessionViewModel>(
    context,
    listen: false,
  );
  final ready = await tester.runAsync<bool>(() async {
    return viewModel.ensureSessionReady();
  });
  expect(ready ?? false, isTrue);

  Navigator.of(context).pushNamed(AppRouteNames.practice);
  await tester.pump();
  await _pumpUntilFound(tester, find.byKey(const Key('activation-frame')));
}

Finder _homeScrollable() {
  return find.descendant(
    of: find.byType(HomeScreen),
    matching: find.byType(Scrollable),
  );
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 50),
  Duration timeout = const Duration(seconds: 5),
}) async {
  final totalSteps = timeout.inMilliseconds ~/ step.inMilliseconds;
  for (var index = 0; index < totalSteps; index++) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }

  fail('Timed out waiting for expected widget.');
}

Future<_RepositoryHarness> _createRepositoryHarness() async {
  final tempDir = Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}practice_session_screen_test_${DateTime.now().microsecondsSinceEpoch}',
  );
  await tempDir.create(recursive: true);
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

class _StaticAccountRepository implements AccountRepository {
  _StaticAccountRepository({required this.snapshot});

  final AccountLocalSnapshot snapshot;

  @override
  Future<AccountLocalSnapshot> loadSnapshot() async => snapshot;

  @override
  Future<AccountLocalSnapshot> savePlaceholderSession({
    required String phoneNumber,
    required String verificationCode,
  }) async {
    return snapshot;
  }

  @override
  Future<AccountLocalSnapshot> clearPlaceholderSession({
    bool revertToLocalOnly = false,
  }) async {
    return snapshot;
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
