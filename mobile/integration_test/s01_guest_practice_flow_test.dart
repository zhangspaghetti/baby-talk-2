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
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/presentation/screens/home_screen.dart';

import 'support/app_test_repositories.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('local-only 完成快照冷启动后可完成练习，且重挂载后连续性结果仍可恢复', (
    WidgetTester tester,
  ) async {
    final bootState = await AppBootState.load(rootBundle);
    expect(bootState.isReady, isTrue);

    final tempDir = await Directory.systemTemp.createTemp(
      's01_guest_practice_integration_',
    );
    addTearDown(() async {
      await _deleteDirectoryBestEffort(tempDir);
    });

    const dbName = 's01_guest_practice';
    final completedSnapshot = OnboardingSnapshot(
      childDisplayName: '米米',
      ageBucket: OnboardingAgeBucket.oneToTwo,
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
    final mentorLocalDataSource = await MentorLocalDataSource.open(
      directory: tempDir.path,
      name: 'mentor_s01_guest_practice',
    );
    final mentorRepository = MentorRepository(
      localDataSource: mentorLocalDataSource,
      practiceRepository: firstRepository,
      onboardingSnapshotStore: OnboardingSnapshotStore(
        directoryResolver: () async => tempDir,
      ),
    );

    final firstAccountRepository = AccountRepository(
      localStore: AccountLocalStore(storageKey: 's01_account'),
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
          practiceRepositoryProvider.overrideWith((ref) => firstRepository),
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
          completedSnapshotLoader: () async => completedSnapshot,
          practiceContinuityRefreshTimeout: Duration.zero,
        ),
      ),
    );
    await tester.pump();
    await _waitForShellWithRetry(tester);

    expect(find.byKey(const Key('boot-route-shell')), findsOneWidget);
    expect(find.byKey(const Key('boot-route-onboarding')), findsNothing);
    final startButton = _homeStartPracticeButton();
    await _pumpUntilFound(
      tester,
      startButton,
      timeout: const Duration(seconds: 60),
    );
    expect(startButton, findsOneWidget);

    await _completeStarterPractice(tester);
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('home-b-practice-result')),
      timeout: const Duration(seconds: 30),
    );
    expect(find.byKey(const Key('home-b-practice-result')), findsOneWidget);
    await _expectGardenContinuation(tester, activityId: 'bath_time');
    final persistedHomeSummary = await firstRepository.getHomeSummary(
      spaceId: 'daily_care',
      activityId: 'bath_time',
    );
    expect(persistedHomeSummary.recentResult, isNotNull);
    expect(persistedHomeSummary.recentResult!.phraseId, 'bath_time_all_clean');
    expect(
      persistedHomeSummary.recentResult!.totalEvents,
      greaterThanOrEqualTo(3),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPhraseServiceProvider.overrideWithValue(
            bootState.assetPhraseService!,
          ),
          appDirectoryProvider.overrideWith((ref) => tempDir),
          practiceRepositoryProvider.overrideWith((ref) => firstRepository),
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
          completedSnapshotLoader: () async => completedSnapshot,
          practiceContinuityRefreshTimeout: Duration.zero,
        ),
      ),
    );
    await tester.pump();
    await _waitForShellWithRetry(tester);

    expect(find.byKey(const Key('boot-route-shell')), findsOneWidget);
    expect(find.byKey(const Key('boot-route-onboarding')), findsNothing);
    await _expectGardenContinuation(tester, activityId: 'bath_time');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
    await mentorRepository.close(deleteFromDisk: false);
    await _closeRepositoryWithTimeout(firstRepository);
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

Future<void> _scrollHomeToTop(WidgetTester tester) async {
  await _pumpUntilFound(
    tester,
    _homeScrollables(),
    timeout: const Duration(seconds: 30),
  );
  final scrollableState = tester.state<ScrollableState>(_homeScrollable());
  scrollableState.position.jumpTo(scrollableState.position.minScrollExtent);
  await _pumpBriefly(tester);
}

Future<void> _tapHomeStartPractice(WidgetTester tester) async {
  await _scrollHomeToTop(tester);
  final startButton = _homeStartPracticeButton();
  await _pumpUntilFound(
    tester,
    startButton,
    timeout: const Duration(seconds: 15),
  );
  await tester.ensureVisible(startButton);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(startButton);
}

Future<void> _completeStarterPractice(WidgetTester tester) async {
  await _tapHomeStartPractice(tester);
  await _pumpUntilFound(
    tester,
    find.byKey(const Key('phrase-card-bath_time_warm_water')),
  );

  final firstReaction = find.byKey(
    const Key('reaction-bath_time_warm_water-cooperating'),
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
    const Key('reaction-bath_time_splash_splash-no_response'),
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
    const Key('reaction-bath_time_all_clean-cooperating'),
  );
  await _pumpUntilFound(tester, thirdReaction);
  await tester.ensureVisible(thirdReaction);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(thirdReaction);
  // Let reaction persist + pop animation + home continuity refresh settle.
  await tester.pump(const Duration(milliseconds: 700));
}

Finder _homeStartPracticeButton() {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key == const Key('home-b-start-practice') ||
        key == const Key('home-start-practice');
  });
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

Future<void> _expectGardenContinuation(
  WidgetTester tester, {
  required String activityId,
}) async {
  final targetFinder = find.byKey(Key('garden-continue-target-$activityId'));
  final continueButton = find.byKey(const Key('garden-continue-practice'));
  await tester.tap(find.byKey(const Key('shell-nav-garden')));
  await _pumpUntilFound(
    tester,
    find.byKey(const Key('shell-tab-growth-combined')),
    timeout: const Duration(seconds: 30),
  );

  for (var attempt = 0; attempt < 50; attempt++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (targetFinder.evaluate().isNotEmpty &&
        continueButton.evaluate().isNotEmpty) {
      break;
    }
    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isNotEmpty) {
      await tester.drag(scrollables.last, const Offset(0, -180));
    }
  }

  await _pumpUntilFound(
    tester,
    continueButton,
    timeout: const Duration(seconds: 30),
  );
  await _pumpUntilFound(
    tester,
    targetFinder,
    timeout: const Duration(seconds: 30),
  );
  await _pumpBriefly(tester);
  expect(targetFinder, findsOneWidget);
  expect(find.textContaining('接着刚才练过的场景'), findsWidgets);
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

Future<void> _closeRepositoryWithTimeout(PracticeRepository repository) async {
  await Future.any([
    repository.close(),
    Future<void>.delayed(const Duration(seconds: 5)),
  ]);
}

Future<void> _deleteDirectoryBestEffort(Directory directory) async {
  final exists = await directory.exists();
  if (!exists) {
    return;
  }

  try {
    await Future.any([
      directory.delete(recursive: true),
      Future<void>.delayed(const Duration(seconds: 3)),
    ]);
  } catch (_) {
    // Ignore cleanup failure in integration tests.
  }
}
