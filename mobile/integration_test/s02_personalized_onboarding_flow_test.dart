import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/mentor/data/local/mentor_local_data_source.dart';
import 'package:mobile/features/mentor/data/repositories/mentor_repository.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
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
    final mentorLocalDataSource = await MentorLocalDataSource.open(
      directory: tempDir.path,
      name: 'mentor_s02_personalized_onboarding',
    );
    final mentorRepository = MentorRepository(
      localDataSource: mentorLocalDataSource,
      practiceRepository: firstRepository,
      onboardingSnapshotStore: OnboardingSnapshotStore(
        directoryResolver: () async => tempDir,
      ),
    );
    final firstAccountRepository = AccountRepository(
      localStore: AccountLocalStore(storageKey: 's02_account'),
      practiceRepository: firstRepository,
    );
    final firstHouseholdRepository = createLocalHouseholdRepository(
      accountRepository: firstAccountRepository,
      directory: tempDir,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPhraseServiceProvider.overrideWithValue(
            bootState.assetPhraseService!,
          ),
          appDirectoryProvider.overrideWith((ref) => tempDir),
          practiceRepositoryProvider.overrideWith(
            (ref) => firstRepository,
          ),
          mentorRepositoryProvider.overrideWith(
            (ref) async => mentorRepository,
          ),
          accountRepositoryProvider.overrideWith(
            (ref) => firstAccountRepository,
          ),
          householdRepositoryProvider.overrideWith(
            (ref) => firstHouseholdRepository,
          ),
        ],
        child: BabyTalkApp(
          bootState: bootState,
          practiceContinuityRefreshTimeout: Duration.zero,
        ),
      ),
    );
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('onboarding-local-only-banner')),
      timeout: const Duration(seconds: 30),
    );

    expect(find.byKey(const Key('boot-route-onboarding')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-local-only-banner')), findsOneWidget);

    await _completeOnboarding(tester, childDisplayName: '米米');
    await _waitForShellWithRetry(tester);
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('home-starter-seed')),
      timeout: const Duration(seconds: 30),
    );

    expect(find.byKey(const Key('boot-route-shell')), findsOneWidget);
    expect(find.byKey(const Key('boot-route-onboarding')), findsNothing);
    expect(find.text('米米 的练习'), findsOneWidget);
    expect(find.byKey(const Key('personalized-home-heading')), findsOneWidget);
    expect(find.textContaining('米米'), findsWidgets);
    expect(find.text('动作带词连接期'), findsWidgets);
    expect(find.textContaining('Warm water.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('shell-drawer-trigger')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shell-end-drawer')), findsOneWidget);
    expect(find.byKey(const Key('shell-drawer-child-name')), findsOneWidget);
    expect(find.byKey(const Key('shell-drawer-stage-title')), findsOneWidget);
    expect(find.byKey(const Key('shell-drawer-local-only-note')), findsOneWidget);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    final startButton = _homeStartPracticeButton();
    await _pumpUntilFound(
      tester,
      startButton,
      timeout: const Duration(seconds: 60),
    );
    await _scrollHomeTo(tester, startButton);

    await tester.tap(startButton);
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('phrase-card-bath_time_warm_water')),
      timeout: const Duration(seconds: 30),
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
      timeout: const Duration(seconds: 30),
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
      timeout: const Duration(seconds: 30),
    );

    final thirdReaction = find.byKey(
      const Key('reaction-bath_time_all_clean-calm'),
    );
    await _pumpUntilFound(tester, thirdReaction);
    await tester.ensureVisible(thirdReaction);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(thirdReaction);
    await tester.pump(const Duration(milliseconds: 700));
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPhraseServiceProvider.overrideWithValue(
            bootState.assetPhraseService!,
          ),
          appDirectoryProvider.overrideWith((ref) => tempDir),
          practiceRepositoryProvider.overrideWith(
            (ref) => firstRepository,
          ),
          mentorRepositoryProvider.overrideWith(
            (ref) async => mentorRepository,
          ),
          accountRepositoryProvider.overrideWith(
            (ref) => firstAccountRepository,
          ),
          householdRepositoryProvider.overrideWith(
            (ref) => firstHouseholdRepository,
          ),
        ],
        child: BabyTalkApp(
          bootState: bootState,
          practiceContinuityRefreshTimeout: Duration.zero,
        ),
      ),
    );
    await tester.pump();
    await _waitForShellWithRetry(tester);

    expect(find.byKey(const Key('boot-route-onboarding')), findsNothing);
    expect(find.byKey(const Key('boot-route-shell')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-local-only-banner')), findsNothing);
    expect(find.byKey(const Key('shell-ready')), findsOneWidget);
    expect(find.text('米米 的练习'), findsOneWidget);
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('home-starter-seed')),
      timeout: const Duration(seconds: 30),
    );
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
    await mentorRepository.close(deleteFromDisk: false);
    await _closeRepositoryWithTimeout(firstRepository);
  });
}

Future<void> _completeOnboarding(
  WidgetTester tester, {
  required String childDisplayName,
}) async {
  await _scrollTo(tester, find.byKey(const Key('onboarding-start-button')));
  await tester.tap(find.byKey(const Key('onboarding-start-button')));
  await tester.pumpAndSettle();
  await _pumpUntilFound(
    tester,
    find.byKey(const Key('onboarding-name-input')),
    timeout: const Duration(seconds: 30),
  );

  await _scrollTo(tester, find.byKey(const Key('onboarding-name-input')));
  await tester.enterText(
    find.byKey(const Key('onboarding-name-input')),
    childDisplayName,
  );
  await _pumpUntilFound(
    tester,
    find.byKey(const Key('onboarding-name-continue')),
    timeout: const Duration(seconds: 30),
  );
  await _scrollTo(tester, find.byKey(const Key('onboarding-name-continue')));
  await tester.tap(find.byKey(const Key('onboarding-name-continue')));
  await tester.pumpAndSettle();
  await _pumpUntilFound(
    tester,
    find.byKey(const Key('onboarding-age-grid')),
    timeout: const Duration(seconds: 30),
  );

  await _scrollTo(tester, find.byKey(const Key('onboarding-age-card-12-18')));
  await tester.tap(find.byKey(const Key('onboarding-age-card-12-18')));
  await tester.pumpAndSettle();
  await _pumpUntilFound(
    tester,
    find.byKey(const Key('onboarding-age-continue')),
    timeout: const Duration(seconds: 30),
  );
  await _scrollTo(tester, find.byKey(const Key('onboarding-age-continue')));
  await tester.tap(find.byKey(const Key('onboarding-age-continue')));
  await tester.pumpAndSettle();
  await _pumpUntilFound(
    tester,
    find.byKey(const Key('onboarding-stage-match-card')),
    timeout: const Duration(seconds: 30),
  );

  expect(find.byKey(const Key('onboarding-stage-match-card')), findsOneWidget);
  await _scrollTo(
    tester,
    find.byKey(const Key('onboarding-preview-seed-text')),
  );
  expect(find.byKey(const Key('onboarding-preview-seed-text')), findsOneWidget);

  // Must tap 'I said it' to set hasRecordedFirstPhraseAction = true;
  // without this, canSubmit == false and the submit button tap is a no-op.
  await _pumpUntilFound(
    tester,
    find.byKey(const Key('onboarding-first-phrase-said')),
    timeout: const Duration(seconds: 30),
  );
  await _scrollTo(
    tester,
    find.byKey(const Key('onboarding-first-phrase-said')),
  );
  await tester.tap(find.byKey(const Key('onboarding-first-phrase-said')));
  await tester.pump(); // let _noopRecordFirstPhraseAction complete + setState

  await _pumpUntilFound(
    tester,
    find.byKey(const Key('onboarding-submit-button')),
    timeout: const Duration(seconds: 30),
  );
  await _scrollTo(tester, find.byKey(const Key('onboarding-submit-button')));
  await tester.tap(find.byKey(const Key('onboarding-submit-button')));
  // Do NOT use pumpAndSettle here: boot navigation triggers persistent streams
  // that never settle. The caller is responsible for waiting on shell-ready.
  await tester.pump(const Duration(milliseconds: 500));
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
      await _pumpBriefly(tester);
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
  await _pumpBriefly(tester);
}

Future<void> _waitForShellWithRetry(WidgetTester tester) async {
  final shellRoute = find.byKey(const Key('boot-route-shell'));
  final shellReady = find.byKey(const Key('shell-ready'));
  final gateFailed = find.byKey(const Key('boot-route-gate-failed'));
  final gateRetry = find.byKey(const Key('boot-route-gate-retry'));

  const step = Duration(milliseconds: 300);
  const timeout = Duration(seconds: 120);
  final totalSteps = timeout.inMilliseconds ~/ step.inMilliseconds;
  for (var index = 0; index < totalSteps; index++) {
    await tester.pump(step);
    if (shellRoute.evaluate().isNotEmpty || shellReady.evaluate().isNotEmpty) {
      return;
    }
    if (gateFailed.evaluate().isNotEmpty && gateRetry.evaluate().isNotEmpty) {
      await tester.tap(gateRetry, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  fail('Timed out waiting for shell route after boot gate retry.');
}

Future<void> _closeRepositoryWithTimeout(PracticeRepository repository) async {
  await Future.any([
    repository.close(),
    Future<void>.delayed(const Duration(seconds: 5)),
  ]);
}

Finder _homeStartPracticeButton() {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key == const Key('home-b-start-practice') ||
        key == const Key('home-start-practice');
  });
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

Future<void> _pumpBriefly(
  WidgetTester tester, {
  Duration duration = const Duration(milliseconds: 250),
}) async {
  await tester.pump(duration);
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
    isarOpener: (schemas, {required directory, name = 'practice_local'}) {
      return Isar.open(
        schemas,
        directory: directory,
        name: name,
        inspector: false,
      );
    },
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
