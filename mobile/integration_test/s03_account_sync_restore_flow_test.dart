import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/presentation/screens/home_screen.dart';

import 'support/in_memory_demo_backend.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('离线练习后登录同步，退出再登录仍能恢复 recent result', (WidgetTester tester) async {
    final backend = await InMemoryDemoBackend.start();
    addTearDown(() async {
      await backend.dispose();
    });

    final bootState = await AppBootState.load(rootBundle);
    expect(bootState.isReady, isTrue);

    final tempDir = await Directory.systemTemp.createTemp(
      's03_account_sync_restore_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    const dbName = 's03_account_sync_restore';
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

    await tester.pumpWidget(
      BabyTalkApp(
        bootState: bootState,
        repositoryFactory: (_) async => firstRepository,
        accountRepositoryFactory: (practiceRepository, directory) async {
          return AccountRepository(
            localStore: AccountLocalStore(
              directoryResolver: () async => directory,
            ),
            practiceRepository: practiceRepository,
            apiService: AccountApiService(baseUri: backend.baseUri),
            connectivityChecker: () async => true,
          );
        },
        appDirectoryResolver: () async => tempDir,
        completedSnapshotLoader: () async => completedSnapshot,
        practiceContinuityRefreshTimeout: Duration.zero,
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('shell-ready')));
    await _pumpUntilFound(tester, find.byKey(const Key('home-starter-seed')));

    await _scrollHomeTo(tester, find.byKey(const Key('home-start-practice')));
    await tester.tap(find.byKey(const Key('home-start-practice')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('phrase-card-bath_time_warm_water')),
      timeout: const Duration(seconds: 15),
    );

    final firstReaction = find.byKey(
      const Key('reaction-bath_time_warm_water-engaged'),
    );
    await _scrollTo(tester, firstReaction);
    await tester.tap(firstReaction);
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('phrase-card-bath_time_splash_splash')),
      timeout: const Duration(seconds: 15),
    );

    final secondReaction = find.byKey(
      const Key('reaction-bath_time_splash_splash-imitated'),
    );
    await _pumpUntilFound(
      tester,
      secondReaction,
      timeout: const Duration(seconds: 15),
    );
    await tester.ensureVisible(secondReaction);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(secondReaction);
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('phrase-card-bath_time_all_clean')),
      timeout: const Duration(seconds: 15),
    );

    final thirdReaction = find.byKey(
      const Key('reaction-bath_time_all_clean-calm'),
    );
    await _pumpUntilFound(
      tester,
      thirdReaction,
      timeout: const Duration(seconds: 15),
    );
    await tester.ensureVisible(thirdReaction);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(thirdReaction);
    // Pump 3 seconds: enough for DB write + navigator pop animation on slow device.
    await tester.pump(const Duration(milliseconds: 3000));
    // Drag the home list all the way to the top (it was scrolled down to reveal
    // home-start-practice). A large positive Y drag scrolls content upward.
    await tester.drag(_homeScrollable(), const Offset(0, 5000));
    await tester.pump();
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('recent-result-summary')),
      timeout: const Duration(seconds: 30),
    );

    expect(find.byKey(const Key('recent-result-summary')), findsOneWidget);
    expect(find.textContaining('All clean. · 宝宝放松'), findsOneWidget);
    expect(find.textContaining('3 条本地记录'), findsOneWidget);

    await _scrollHomeTo(
      tester,
      find.byKey(const Key('home-account-open-entry')),
    );
    await tester.tap(find.byKey(const Key('home-account-open-entry')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('account-entry-surface')),
    );

    await tester.enterText(
      find.byKey(const Key('account-phone-field')),
      '13800138000',
    );
    await tester.enterText(
      find.byKey(const Key('account-code-field')),
      '246810',
    );
    await tester.ensureVisible(find.byKey(const Key('account-submit-button')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('account-submit-button')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('account-status-signed-in-synced')),
      timeout: const Duration(seconds: 20),
    );

    expect(
      find.byKey(const Key('account-status-signed-in-synced')),
      findsOneWidget,
    );
    expect(find.textContaining('登录已完成'), findsWidgets);
    expect(backend.bootstrapCount, 1);
    expect(backend.storedEventCount(_openRepositoryInstallationId), 3);

    await tester.tap(find.byKey(const Key('account-clear-button')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('account-status-signed-out')),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
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
            localStore: AccountLocalStore(
              directoryResolver: () async => directory,
            ),
            practiceRepository: practiceRepository,
            apiService: AccountApiService(baseUri: backend.baseUri),
            connectivityChecker: () async => true,
          );
        },
        appDirectoryResolver: () async => tempDir,
        completedSnapshotLoader: () async => completedSnapshot,
        practiceContinuityRefreshTimeout: Duration.zero,
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('shell-ready')));
    await _pumpUntilFound(tester, find.byKey(const Key('home-starter-seed')));

    await _scrollHomeTo(tester, find.byKey(const Key('recent-result-summary')));
    expect(find.byKey(const Key('recent-result-summary')), findsOneWidget);
    expect(find.textContaining('All clean. · 宝宝放松'), findsOneWidget);
    expect(find.textContaining('3 条本地记录'), findsOneWidget);

    await _scrollHomeTo(
      tester,
      find.byKey(const Key('home-account-open-entry')),
    );
    await tester.tap(find.byKey(const Key('home-account-open-entry')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('account-entry-surface')),
    );
    await tester.enterText(
      find.byKey(const Key('account-phone-field')),
      '13800138000',
    );
    await tester.enterText(
      find.byKey(const Key('account-code-field')),
      '246810',
    );
    await tester.ensureVisible(find.byKey(const Key('account-submit-button')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('account-submit-button')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('account-status-signed-in-synced')),
      timeout: const Duration(seconds: 20),
    );

    expect(backend.bootstrapCount, 2);
    expect(backend.storedEventCount(_openRepositoryInstallationId), 3);
    await tester.tap(find.byKey(const Key('account-close-button')));
    await tester.pumpAndSettle();
    await _scrollHomeTo(tester, find.byKey(const Key('recent-result-summary')));
    expect(find.byKey(const Key('recent-result-summary')), findsOneWidget);
    expect(find.textContaining('已同步 3'), findsOneWidget);
  });
}

const _openRepositoryInstallationId = 'install_s03_integration_test';

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
      idGenerator: () => _openRepositoryInstallationId,
    ),
  );
}

Finder _homeScrollable() {
  return find.descendant(
    of: find.byType(HomeScreen),
    matching: find.byType(Scrollable),
  );
}

Future<void> _scrollHomeTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 180, scrollable: _homeScrollable());
  await tester.pumpAndSettle();
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
