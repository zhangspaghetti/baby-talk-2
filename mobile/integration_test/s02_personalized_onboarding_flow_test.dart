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
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/presentation/screens/home_screen.dart';

import 'support/app_test_repositories.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fresh install 完成 onboarding 后进入个性化 shell，并保留练习入口', (
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
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('home-b-practice-result')),
      timeout: const Duration(seconds: 30),
    );

    expect(find.byKey(const Key('home-b-practice-result')), findsOneWidget);
    expect(find.textContaining('Warm water.'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
    await firstRepository.close();
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

Future<void> _pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 50),
  Duration timeout = const Duration(seconds: 8),
}) async {
  final totalSteps = timeout.inMilliseconds ~/ step.inMilliseconds;
  for (var index = 0; index < totalSteps; index++) {
    await tester.pump(step);
    if (finder.evaluate().isEmpty) {
      return;
    }
  }

  fail('Timed out waiting for widget to disappear.');
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
