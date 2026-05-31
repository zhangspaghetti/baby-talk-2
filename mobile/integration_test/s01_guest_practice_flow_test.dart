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

  testWidgets('local-only 完成快照冷启动后直接进入 shell，并保持练习入口可见', (WidgetTester tester) async {
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
    await tester.pump();
    await _waitForHomeReady(tester);

    expect(find.byKey(const Key('boot-route-shell')), findsOneWidget);
    final startButton = _homeStartPracticeButton();
    await _scrollHomeTo(tester, startButton);
    expect(startButton, findsOneWidget);
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

Finder _homeStartPracticeButton() {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key == const Key('home-b-start-practice') ||
        key == const Key('home-start-practice');
  });
}

Future<void> _waitForHomeReady(WidgetTester tester) async {
  final shellReady = find.byKey(const Key('shell-ready'));
  final shellRoute = find.byKey(const Key('boot-route-shell'));
  const step = Duration(milliseconds: 300);
  const timeout = Duration(seconds: 45);
  final totalSteps = timeout.inMilliseconds ~/ step.inMilliseconds;
  for (var index = 0; index < totalSteps; index++) {
    await tester.pump(step);
    if (shellReady.evaluate().isNotEmpty || shellRoute.evaluate().isNotEmpty) {
      return;
    }
  }

  fail('Timed out waiting for shell home route.');
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
