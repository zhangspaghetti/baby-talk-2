import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/presentation/screens/home_screen.dart';

import 'support/app_test_repositories.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('local-only 离线练习在冷启动后仍能恢复最近一次本地结果', (WidgetTester tester) async {
    final bootState = await AppBootState.load(rootBundle);
    expect(bootState.isReady, isTrue);

    final tempDir = await Directory.systemTemp.createTemp(
      's01_guest_practice_integration_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    const dbName = 's01_guest_practice';
    final completedSnapshot = OnboardingSnapshot(
      childDisplayName: '米米',
      ageBucket: OnboardingAgeBucket.twelveToEighteen,
      approxMonths: 15,
      currentStage: 'gesture_plus_words',
      starterSpaceId: 'daily_care',
      starterActivityId: 'bath_time',
      starterPhraseId: 'bath_time_warm_water',
      consentState: OnboardingConsentState.localOnly,
      completedAt: DateTime.utc(2026, 4, 9, 8),
    );
    final firstRepository = await _openRepository(
      assetPhraseService: bootState.assetPhraseService!,
      directory: tempDir,
      dbName: dbName,
    );
    addTearDown(() async {
      await firstRepository.close();
    });

    await tester.pumpWidget(
      BabyTalkApp(
        bootState: bootState,
        repositoryFactory: (_) async => firstRepository,
        accountRepositoryFactory: (practiceRepository, directory) async {
          return AccountRepository(
            localStore: AccountLocalStore(storageKey: 's01_account'),
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
        completedSnapshotLoader: () async => completedSnapshot,
        practiceContinuityRefreshTimeout: Duration.zero,
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('shell-ready')));
    await _pumpUntilFound(tester, find.byKey(const Key('home-starter-seed')));

    expect(find.byKey(const Key('boot-route-shell')), findsOneWidget);
    expect(find.byKey(const Key('home-local-only-banner')), findsOneWidget);
    await _scrollHomeTo(tester, find.byKey(const Key('recent-result-empty')));
    expect(find.byKey(const Key('recent-result-empty')), findsOneWidget);

    await _tapHomeStartPractice(tester);
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('phrase-card-bath_time_warm_water')),
    );

    expect(
      find.byKey(const Key('phrase-card-bath_time_warm_water')),
      findsOneWidget,
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

    expect(
      find.byKey(const Key('phrase-card-bath_time_splash_splash')),
      findsOneWidget,
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

    expect(
      find.byKey(const Key('phrase-card-bath_time_all_clean')),
      findsOneWidget,
    );
    final thirdReaction = find.byKey(
      const Key('reaction-bath_time_all_clean-calm'),
    );
    await _pumpUntilFound(tester, thirdReaction);
    await tester.ensureVisible(thirdReaction);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(thirdReaction);
    // Pump 3 seconds: enough for DB write + navigator pop animation on slow device.
    await tester.pump(const Duration(milliseconds: 3000));
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
            localStore: AccountLocalStore(storageKey: 's01_account'),
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
        completedSnapshotLoader: () async => completedSnapshot,
        practiceContinuityRefreshTimeout: Duration.zero,
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('boot-route-shell')));
    await _pumpUntilFound(tester, find.byKey(const Key('home-starter-seed')));

    expect(find.byKey(const Key('home-local-only-banner')), findsOneWidget);
    await _scrollHomeTo(tester, find.byKey(const Key('recent-result-summary')));
    expect(find.byKey(const Key('recent-result-summary')), findsOneWidget);
    expect(find.textContaining('All clean. · 宝宝放松'), findsOneWidget);
    expect(find.textContaining('3 条本地记录'), findsOneWidget);
  });
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

Future<void> _scrollHomeToTop(WidgetTester tester) async {
  await _pumpUntilFound(
    tester,
    _homeScrollables(),
    timeout: const Duration(seconds: 30),
  );
  final scrollableState = tester.state<ScrollableState>(_homeScrollable());
  scrollableState.position.jumpTo(scrollableState.position.minScrollExtent);
  await tester.pumpAndSettle();
}

Future<void> _tapHomeStartPractice(WidgetTester tester) async {
  await _scrollHomeToTop(tester);
  final startButton = find.byKey(const Key('home-start-practice'));
  await _pumpUntilFound(
    tester,
    startButton,
    timeout: const Duration(seconds: 15),
  );
  await tester.ensureVisible(startButton);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(startButton);
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
