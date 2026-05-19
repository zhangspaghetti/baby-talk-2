import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/presentation/screens/home_screen.dart';

import 'support/app_test_repositories.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fresh install 完成 onboarding 后进入个性化 shell，冷启动后跳过 onboarding 并恢复最近结果', (
    WidgetTester tester,
  ) async {
    final bootState = await AppBootState.load(rootBundle);
    expect(bootState.isReady, isTrue);

    final tempDir = await Directory.systemTemp.createTemp(
      's02_personalized_onboarding_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    const dbName = 's02_personalized_onboarding';
    final firstRepository = await _openRepository(
      assetPhraseService: bootState.assetPhraseService!,
      directory: tempDir,
      dbName: dbName,
    );

    await tester.pumpWidget(
      BabyTalkApp(
        bootState: bootState,
        repositoryFactory: (_) async => firstRepository,
        accountRepositoryFactory: (practiceRepository, directory) async {
          return AccountRepository(
            localStore: AccountLocalStore(storageKey: 's02_account'),
            practiceRepository: practiceRepository,
          );
        },
        householdRepositoryFactory: (accountRepository, directory) async {
          return createLocalHouseholdRepository(
            accountRepository: accountRepository,
            directory: directory,
          );
        },
        appDirectoryResolver: () async => tempDir,
        practiceContinuityRefreshTimeout: Duration.zero,
      ),
    );
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('onboarding-local-only-banner')),
    );

    expect(find.byKey(const Key('boot-route-onboarding')), findsOneWidget);
    expect(
      find.byKey(const Key('onboarding-local-only-banner')),
      findsOneWidget,
    );

    await _completeOnboarding(tester, childDisplayName: '米米');
    await _pumpUntilFound(tester, find.byKey(const Key('shell-ready')));
    // Wait for the personalized home content to finish loading (async Isar IO).
    await _pumpUntilFound(tester, find.byKey(const Key('home-starter-seed')));

    expect(find.byKey(const Key('boot-route-shell')), findsOneWidget);
    expect(find.byKey(const Key('shell-ready')), findsOneWidget);
    expect(find.text('米米 的练习'), findsOneWidget);
    expect(find.byKey(const Key('home-local-only-banner')), findsOneWidget);
    expect(find.byKey(const Key('personalized-home-heading')), findsOneWidget);
    expect(find.textContaining('米米'), findsWidgets);
    expect(find.text('动作带词连接期'), findsWidgets);
    expect(find.textContaining('Warm water.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('shell-drawer-trigger')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shell-end-drawer')), findsOneWidget);
    expect(find.byKey(const Key('shell-drawer-child-name')), findsOneWidget);
    expect(find.byKey(const Key('shell-drawer-stage-title')), findsOneWidget);
    expect(
      find.byKey(const Key('shell-drawer-local-only-note')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    await _scrollHomeTo(tester, find.byKey(const Key('home-start-practice')));
    await tester.tap(find.byKey(const Key('home-start-practice')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('phrase-card-bath_time_warm_water')),
    );

    final firstReaction = find.byKey(
      const Key('reaction-bath_time_warm_water-engaged'),
    );
    await _pumpUntilFound(tester, firstReaction);
    await tester.ensureVisible(firstReaction);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(firstReaction);
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('phrase-card-bath_time_splash_splash')),
    );

    final secondReaction = find.byKey(
      const Key('reaction-bath_time_splash_splash-imitated'),
    );
    await _pumpUntilFound(tester, secondReaction);
    await tester.ensureVisible(secondReaction);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(secondReaction);
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('phrase-card-bath_time_all_clean')),
    );

    final thirdReaction = find.byKey(
      const Key('reaction-bath_time_all_clean-calm'),
    );
    await _pumpUntilFound(tester, thirdReaction);
    await tester.ensureVisible(thirdReaction);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(thirdReaction);
    // Pump to let recordReaction complete, navigator.pop() fire, and route animation finish.
    await tester.pump(const Duration(milliseconds: 700));
    // Scroll home list back to top so _RecentResultCard is in the viewport
    // (the list was scrolled down to reveal home-start-practice).
    await _scrollHomeTo(tester, find.byKey(const Key('recent-result-summary')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('recent-result-summary')),
      timeout: const Duration(seconds: 30),
    );

    expect(find.byKey(const Key('recent-result-summary')), findsOneWidget);
    expect(find.textContaining('All clean. · 宝宝放松'), findsOneWidget);
    expect(find.textContaining('3 条本地记录'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
    await firstRepository.close();

    final secondRepository = await _openRepository(
      assetPhraseService: bootState.assetPhraseService!,
      directory: tempDir,
      dbName: dbName,
    );
    addTearDown(() async {
      await secondRepository.close();
    });

    await tester.pumpWidget(
      BabyTalkApp(
        bootState: bootState,
        repositoryFactory: (_) async => secondRepository,
        accountRepositoryFactory: (practiceRepository, directory) async {
          return AccountRepository(
            localStore: AccountLocalStore(storageKey: 's02_account'),
            practiceRepository: practiceRepository,
          );
        },
        householdRepositoryFactory: (accountRepository, directory) async {
          return createLocalHouseholdRepository(
            accountRepository: accountRepository,
            directory: directory,
          );
        },
        appDirectoryResolver: () async => tempDir,
        practiceContinuityRefreshTimeout: Duration.zero,
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('boot-route-shell')));

    expect(find.byKey(const Key('boot-route-onboarding')), findsNothing);
    expect(find.byKey(const Key('boot-route-shell')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-local-only-banner')), findsNothing);
    expect(find.byKey(const Key('shell-ready')), findsOneWidget);
    expect(find.text('米米 的练习'), findsOneWidget);
    // Wait for ListView to render (boot seed loaded or initialize() completed).
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('home-start-practice')),
      timeout: const Duration(seconds: 10),
    );
    // Scroll down to bring HomeRecentResultCard into viewport.
    // HomeTodaySceneCard + HomePersonalizedHero push it below the fold.
    await _scrollHomeTo(tester, find.byKey(const Key('recent-result-summary')));
    // Wait for recent-result-summary (Notifier loads data from Isar).
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('recent-result-summary')),
      timeout: const Duration(seconds: 30),
    );
    await _scrollHomeTo(tester, find.byKey(const Key('recent-result-summary')));
    expect(find.byKey(const Key('recent-result-summary')), findsOneWidget);
    expect(find.textContaining('All clean. · 宝宝放松'), findsOneWidget);
    expect(find.textContaining('3 条本地记录'), findsOneWidget);
  });
}

Future<void> _completeOnboarding(
  WidgetTester tester, {
  required String childDisplayName,
}) async {
  await _scrollTo(tester, find.byKey(const Key('onboarding-start-button')));
  await tester.tap(find.byKey(const Key('onboarding-start-button')));
  await tester.pumpAndSettle();
  await _pumpUntilFound(tester, find.byKey(const Key('onboarding-name-input')));

  await _scrollTo(tester, find.byKey(const Key('onboarding-name-input')));
  await tester.enterText(
    find.byKey(const Key('onboarding-name-input')),
    childDisplayName,
  );
  await _pumpUntilFound(
    tester,
    find.byKey(const Key('onboarding-name-continue')),
  );
  await _scrollTo(tester, find.byKey(const Key('onboarding-name-continue')));
  await tester.tap(find.byKey(const Key('onboarding-name-continue')));
  await tester.pumpAndSettle();
  await _pumpUntilFound(tester, find.byKey(const Key('onboarding-age-grid')));

  await _scrollTo(tester, find.byKey(const Key('onboarding-age-card-12-18')));
  await tester.tap(find.byKey(const Key('onboarding-age-card-12-18')));
  await tester.pumpAndSettle();
  await _pumpUntilFound(
    tester,
    find.byKey(const Key('onboarding-age-continue')),
  );
  await _scrollTo(tester, find.byKey(const Key('onboarding-age-continue')));
  await tester.tap(find.byKey(const Key('onboarding-age-continue')));
  await tester.pumpAndSettle();
  await _pumpUntilFound(
    tester,
    find.byKey(const Key('onboarding-stage-match-card')),
  );

  expect(find.byKey(const Key('onboarding-stage-match-card')), findsOneWidget);
  await _scrollTo(
    tester,
    find.byKey(const Key('onboarding-preview-seed-text')),
  );
  expect(find.byKey(const Key('onboarding-preview-seed-text')), findsOneWidget);

  await _pumpUntilFound(
    tester,
    find.byKey(const Key('onboarding-submit-button')),
  );
  await _scrollTo(tester, find.byKey(const Key('onboarding-submit-button')));
  await tester.tap(find.byKey(const Key('onboarding-submit-button')));
  await tester.pumpAndSettle();
}

Finder _homeScrollables() {
  return find.descendant(
    of: find.byType(HomeScreen),
    matching: find.byType(Scrollable),
  );
}

Finder _homeScrollable() {
  return _homeScrollables().first;
}

Future<void> _scrollHomeTo(WidgetTester tester, Finder finder) async {
  await _pumpUntilFound(
    tester,
    _homeScrollables(),
    timeout: const Duration(seconds: 30),
  );
  final scrollableState = tester.state<ScrollableState>(_homeScrollable());
  scrollableState.position.jumpTo(scrollableState.position.minScrollExtent);
  await tester.pump();

  for (var attempt = 0; attempt < 120; attempt++) {
    if (_finderExists(finder)) {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      expect(finder, findsOneWidget);
      return;
    }
    if (_finderExists(_homeScrollables())) {
      if (attempt > 0 && attempt % 30 == 0) {
        final state = tester.state<ScrollableState>(_homeScrollable());
        state.position.jumpTo(state.position.minScrollExtent);
      } else {
        await tester.drag(_homeScrollable(), const Offset(0, -300));
      }
    }
    await tester.pump(const Duration(milliseconds: 100));
  }

  fail('Timed out waiting for home content.');
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 50),
  Duration timeout = const Duration(seconds: 8),
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

bool _finderExists(Finder finder) {
  try {
    return finder.evaluate().isNotEmpty;
  } on StateError {
    return false;
  }
}

Future<PracticeRepository> _openRepository({
  required AssetPhraseService assetPhraseService,
  required Directory directory,
  required String dbName,
}) async {
  final localDataSource = await PracticeLocalDataSource.open(
    directory: directory.path,
    name: dbName,
  );
  return PracticeRepository(
    assetPhraseService: assetPhraseService,
    localDataSource: localDataSource,
    installationIdService: InstallationIdService(
      directoryResolver: () async => directory,
      idGenerator: () => 'install_integration_test',
    ),
  );
}
