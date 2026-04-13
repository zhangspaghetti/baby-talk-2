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
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_view_model.dart';
import 'package:mobile/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): _resolveBundledIsarLibraryPath()},
    );
  });

  group('OnboardingScreen', () {
    testWidgets('显示本地优先说明，并用真实 starter seed 驱动阶段匹配与迷你体验卡', (
      WidgetTester tester,
    ) async {
      final harness = (await tester.runAsync<_OnboardingRepositoryHarness>(() {
        return _createOnboardingRepositoryHarness();
      }))!;
      addTearDown(harness.close);

      final viewModel = OnboardingViewModel(
        repository: harness.onboardingRepository,
        completeOnboardingAction: (childDisplayName, ageBucket) async =>
            _completedSnapshot(
              childDisplayName: childDisplayName,
              ageBucket: ageBucket,
            ),
      );

      await _pumpOnboardingScreen(tester, viewModel);
      expect(
        find.byKey(const Key('onboarding-local-only-banner')),
        findsOneWidget,
      );

      await _advanceToPreview(
        tester,
        childDisplayName: '米米',
        bucket: OnboardingAgeBucket.sixToTwelve,
      );

      expect(
        find.byKey(const Key('onboarding-preview-seed-text')),
        findsOneWidget,
      );
      final previewSeedTexts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('onboarding-preview-seed-text')),
              matching: find.byType(Text),
            ),
          )
          .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
          .join(' ');
      expect(previewSeedTexts, contains(viewModel.starterSeed!.phraseEnglish));
      expect(previewSeedTexts, contains(viewModel.starterSeed!.phraseChinese));

      await tester.drag(find.byType(ListView), const Offset(0, 260));
      await tester.pumpAndSettle();
      await _scrollTo(
        tester,
        find.byKey(const Key('onboarding-mini-seed-card')),
      );

      expect(
        find.byKey(const Key('onboarding-stage-match-card')),
        findsOneWidget,
      );
      expect(find.text('声音轮流回应期'), findsOneWidget);
    });

    testWidgets('空昵称、空白昵称与超长昵称都会被拦下', (WidgetTester tester) async {
      final viewModel = _readyViewModel();
      await _pumpOnboardingScreen(tester, viewModel);

      await _scrollTo(tester, find.byKey(const Key('onboarding-start-button')));
      await tester.tap(find.byKey(const Key('onboarding-start-button')));
      await tester.pumpAndSettle();

      await _scrollTo(
        tester,
        find.byKey(const Key('onboarding-name-continue')),
      );
      await tester.tap(find.byKey(const Key('onboarding-name-continue')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('onboarding-name-error')), findsOneWidget);
      expect(find.text('先给宝宝填一个昵称吧。'), findsOneWidget);

      await _scrollTo(tester, find.byKey(const Key('onboarding-name-input')));
      await tester.enterText(
        find.byKey(const Key('onboarding-name-input')),
        '   ',
      );
      await _scrollTo(
        tester,
        find.byKey(const Key('onboarding-name-continue')),
      );
      await tester.tap(find.byKey(const Key('onboarding-name-continue')));
      await tester.pumpAndSettle();
      expect(find.text('先给宝宝填一个昵称吧。'), findsOneWidget);

      await _scrollTo(tester, find.byKey(const Key('onboarding-name-input')));
      await tester.enterText(
        find.byKey(const Key('onboarding-name-input')),
        '1234567890123',
      );
      await _scrollTo(
        tester,
        find.byKey(const Key('onboarding-name-continue')),
      );
      await tester.tap(find.byKey(const Key('onboarding-name-continue')));
      await tester.pumpAndSettle();
      expect(find.text('昵称先控制在 12 个字内，之后还可以改。'), findsOneWidget);
      expect(find.byKey(const Key('onboarding-age-grid')), findsNothing);
    });

    testWidgets('边界月龄切换会映射到正确阶段，返回上一步也不会丢失输入', (WidgetTester tester) async {
      final viewModel = _readyViewModel();
      await _pumpOnboardingScreen(tester, viewModel);

      await _scrollTo(tester, find.byKey(const Key('onboarding-start-button')));
      await tester.tap(find.byKey(const Key('onboarding-start-button')));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.byKey(const Key('onboarding-name-input')));
      await tester.enterText(
        find.byKey(const Key('onboarding-name-input')),
        '果果',
      );
      await _scrollTo(
        tester,
        find.byKey(const Key('onboarding-name-continue')),
      );
      await tester.tap(find.byKey(const Key('onboarding-name-continue')));
      await tester.pumpAndSettle();

      final expectedTitles = <OnboardingAgeBucket, String>{
        OnboardingAgeBucket.zeroToSix: '日常陪伴起步期',
        OnboardingAgeBucket.sixToTwelve: '声音轮流回应期',
        OnboardingAgeBucket.twelveToEighteen: '动作带词连接期',
        OnboardingAgeBucket.eighteenToTwentyFour: '场景模仿萌芽期',
        OnboardingAgeBucket.twentyFourToThirtySix: '日常短句扩展期',
      };

      for (final entry in expectedTitles.entries) {
        await _scrollTo(
          tester,
          find.byKey(Key('onboarding-age-card-${entry.key.wireValue}')),
        );
        await tester.tap(
          find.byKey(Key('onboarding-age-card-${entry.key.wireValue}')),
        );
        await tester.pumpAndSettle();
        await _scrollTo(
          tester,
          find.byKey(const Key('onboarding-age-continue')),
        );
        await tester.tap(find.byKey(const Key('onboarding-age-continue')));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, 260));
        await tester.pumpAndSettle();

        expect(find.text(entry.value), findsOneWidget);
        expect(
          find.byKey(const Key('onboarding-stage-match-card')),
          findsOneWidget,
        );

        await tester.drag(find.byType(ListView), const Offset(0, -260));
        await tester.pumpAndSettle();
        await _scrollTo(
          tester,
          find.byKey(const Key('onboarding-back-button')),
        );
        await tester.tap(find.byKey(const Key('onboarding-back-button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('onboarding-age-grid')), findsOneWidget);
      }

      await _scrollTo(tester, find.byKey(const Key('onboarding-back-button')));
      await tester.tap(find.byKey(const Key('onboarding-back-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('onboarding-name-input')), findsOneWidget);

      final nameField = tester.widget<TextField>(
        find.byKey(const Key('onboarding-name-input')),
      );
      expect(nameField.controller?.text, '果果');
    });

    testWidgets('starter seed 加载失败时会展示明确错误并阻断进入预览', (
      WidgetTester tester,
    ) async {
      final viewModel = OnboardingViewModel(
        starterSeedLoader: () async {
          throw const FormatException('starter phrase 缺失。');
        },
        completeOnboardingAction: (childDisplayName, ageBucket) async =>
            _completedSnapshot(
              childDisplayName: childDisplayName,
              ageBucket: ageBucket,
            ),
      );

      await _pumpOnboardingScreen(tester, viewModel);
      await _scrollTo(tester, find.byKey(const Key('onboarding-start-button')));
      await tester.tap(find.byKey(const Key('onboarding-start-button')));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.byKey(const Key('onboarding-name-input')));
      await tester.enterText(
        find.byKey(const Key('onboarding-name-input')),
        '米米',
      );
      await _scrollTo(
        tester,
        find.byKey(const Key('onboarding-name-continue')),
      );
      await tester.tap(find.byKey(const Key('onboarding-name-continue')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('onboarding-content-error-banner')),
        findsOneWidget,
      );

      await _scrollTo(
        tester,
        find.byKey(const Key('onboarding-age-card-12-18')),
      );
      await tester.tap(find.byKey(const Key('onboarding-age-card-12-18')));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.byKey(const Key('onboarding-age-continue')));
      await tester.tap(find.byKey(const Key('onboarding-age-continue')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('onboarding-age-error')), findsOneWidget);
      expect(
        find.byKey(const Key('onboarding-stage-match-card')),
        findsNothing,
      );
    });

    testWidgets('保存失败时展示可重试 banner，保留输入并允许再次提交', (WidgetTester tester) async {
      var submitCount = 0;
      final viewModel = OnboardingViewModel(
        starterSeedLoader: () async => _starterSeed(),
        completeOnboardingAction: (childDisplayName, ageBucket) async {
          submitCount += 1;
          if (submitCount == 1) {
            throw StateError('disk denied');
          }
          return _completedSnapshot(
            childDisplayName: childDisplayName,
            ageBucket: ageBucket,
          );
        },
      );

      await _pumpOnboardingScreen(tester, viewModel);
      await _advanceToPreview(
        tester,
        childDisplayName: '米米',
        bucket: OnboardingAgeBucket.eighteenToTwentyFour,
      );

      await _scrollTo(
        tester,
        find.byKey(const Key('onboarding-submit-button')),
      );
      await tester.tap(find.byKey(const Key('onboarding-submit-button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('onboarding-save-error-banner')),
        findsOneWidget,
      );
      expect(find.textContaining('本地保存失败，请重试。'), findsOneWidget);

      await _scrollTo(tester, find.byKey(const Key('onboarding-back-button')));
      await tester.tap(find.byKey(const Key('onboarding-back-button')));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.byKey(const Key('onboarding-back-button')));
      await tester.tap(find.byKey(const Key('onboarding-back-button')));
      await tester.pumpAndSettle();

      final nameField = tester.widget<TextField>(
        find.byKey(const Key('onboarding-name-input')),
      );
      expect(nameField.controller?.text, '米米');

      await _scrollTo(
        tester,
        find.byKey(const Key('onboarding-name-continue')),
      );
      await tester.tap(find.byKey(const Key('onboarding-name-continue')));
      await tester.pumpAndSettle();
      await _scrollTo(
        tester,
        find.byKey(const Key('onboarding-age-card-18-24')),
      );
      await tester.tap(find.byKey(const Key('onboarding-age-card-18-24')));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.byKey(const Key('onboarding-age-continue')));
      await tester.tap(find.byKey(const Key('onboarding-age-continue')));
      await tester.pumpAndSettle();
      await _scrollTo(
        tester,
        find.byKey(const Key('onboarding-submit-button')),
      );
      await tester.tap(find.byKey(const Key('onboarding-submit-button')));

      await tester.pumpAndSettle();

      expect(submitCount, 2);
      expect(find.byKey(const Key('shell-ready')), findsOneWidget);
    });

    testWidgets('重复提交时只有一次本地写入，并暴露 saving 状态', (WidgetTester tester) async {
      final completer = Completer<OnboardingSnapshot>();
      var submitCount = 0;
      final viewModel = OnboardingViewModel(
        starterSeedLoader: () async => _starterSeed(),
        completeOnboardingAction: (childDisplayName, ageBucket) {
          submitCount += 1;
          return completer.future;
        },
      );

      await _pumpOnboardingScreen(tester, viewModel);
      await _advanceToPreview(
        tester,
        childDisplayName: '果果',
        bucket: OnboardingAgeBucket.zeroToSix,
      );

      await _scrollTo(
        tester,
        find.byKey(const Key('onboarding-submit-button')),
      );
      await tester.tap(find.byKey(const Key('onboarding-submit-button')));
      await tester.pump();
      expect(find.byKey(const Key('onboarding-submit-saving')), findsOneWidget);
      expect(submitCount, 1);

      unawaited(viewModel.submit());
      await tester.pump();
      expect(submitCount, 1);

      completer.complete(
        _completedSnapshot(
          childDisplayName: '果果',
          ageBucket: OnboardingAgeBucket.zeroToSix,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('shell-ready')), findsOneWidget);
    });
  });
}

Future<void> _pumpOnboardingScreen(
  WidgetTester tester,
  OnboardingViewModel viewModel,
) async {
  await tester.runAsync(() async {
    await viewModel.initialize();
  });

  await tester.pumpWidget(
    ChangeNotifierProvider<OnboardingViewModel>.value(
      value: viewModel,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        initialRoute: AppRouteNames.onboarding,
        onGenerateRoute: AppRouter.onGenerateRoute(
          onboardingBuilder: (_) => const OnboardingScreen(),
          shellBuilder: (_) => const Scaffold(
            body: Center(child: Text('shell ready', key: Key('shell-ready'))),
          ),
          practiceBuilder: (_) => const SizedBox.shrink(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _advanceToPreview(
  WidgetTester tester, {
  required String childDisplayName,
  required OnboardingAgeBucket bucket,
}) async {
  await _scrollTo(tester, find.byKey(const Key('onboarding-start-button')));
  await tester.tap(find.byKey(const Key('onboarding-start-button')));
  await tester.pumpAndSettle();
  await _scrollTo(tester, find.byKey(const Key('onboarding-name-input')));
  await tester.enterText(
    find.byKey(const Key('onboarding-name-input')),
    childDisplayName,
  );
  await _scrollTo(tester, find.byKey(const Key('onboarding-name-continue')));
  await tester.tap(find.byKey(const Key('onboarding-name-continue')));
  await tester.pumpAndSettle();
  await _scrollTo(
    tester,
    find.byKey(Key('onboarding-age-card-${bucket.wireValue}')),
  );
  await tester.tap(find.byKey(Key('onboarding-age-card-${bucket.wireValue}')));
  await tester.pumpAndSettle();
  await _scrollTo(tester, find.byKey(const Key('onboarding-age-continue')));
  await tester.tap(find.byKey(const Key('onboarding-age-continue')));
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    return;
  }
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

OnboardingViewModel _readyViewModel() {
  return OnboardingViewModel(
    starterSeedLoader: () async => _starterSeed(),
    completeOnboardingAction: (childDisplayName, ageBucket) async =>
        _completedSnapshot(
          childDisplayName: childDisplayName,
          ageBucket: ageBucket,
        ),
  );
}

OnboardingStarterSeed _starterSeed() {
  return const OnboardingStarterSeed(
    spaceId: 'daily_care',
    activityId: 'bath_time',
    phraseId: 'bath_time_warm_water',
    phraseEnglish: 'Warm water.',
    phraseChinese: '温温的水。',
  );
}

OnboardingSnapshot _completedSnapshot({
  required String childDisplayName,
  required OnboardingAgeBucket ageBucket,
}) {
  final stageMatch = StageMatchCatalog.forAgeBucket(ageBucket);
  return OnboardingSnapshot(
    childDisplayName: childDisplayName.trim(),
    ageBucket: ageBucket,
    approxMonths: stageMatch.approxMonths,
    currentStage: stageMatch.stageId,
    starterSpaceId: 'daily_care',
    starterActivityId: 'bath_time',
    starterPhraseId: 'bath_time_warm_water',
    consentState: OnboardingConsentState.localOnly,
    completedAt: DateTime.utc(2026, 4, 8, 8),
  );
}

class _OnboardingRepositoryHarness {
  const _OnboardingRepositoryHarness({
    required this.tempDir,
    required this.localDataSource,
    required this.practiceRepository,
    required this.onboardingRepository,
  });

  final Directory tempDir;
  final PracticeLocalDataSource localDataSource;
  final PracticeRepository practiceRepository;
  final OnboardingRepository onboardingRepository;

  Future<void> close() async {
    await practiceRepository.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
}

Future<_OnboardingRepositoryHarness>
_createOnboardingRepositoryHarness() async {
  final tempDir = await Directory.systemTemp.createTemp(
    'onboarding_screen_test_',
  );
  final localDataSource = await PracticeLocalDataSource.open(
    directory: tempDir.path,
    name: 'onboarding_screen_test',
  );
  final practiceRepository = PracticeRepository(
    assetPhraseService: AssetPhraseService(bundle: rootBundle),
    localDataSource: localDataSource,
    installationIdService: InstallationIdService(
      directoryResolver: () async => tempDir,
      idGenerator: () => 'install_onboarding_screen_test',
    ),
  );
  final onboardingRepository = OnboardingRepository(
    snapshotStore: OnboardingSnapshotStore(
      directoryResolver: () async => tempDir,
    ),
    practiceRepository: practiceRepository,
    starterSpaceId: 'daily_care',
    starterActivityId: 'bath_time',
  );
  return _OnboardingRepositoryHarness(
    tempDir: tempDir,
    localDataSource: localDataSource,
    practiceRepository: practiceRepository,
    onboardingRepository: onboardingRepository,
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
