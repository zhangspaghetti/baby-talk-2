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
import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/presentation/screens/home_screen.dart';

import 'support/app_test_repositories.dart';
import 'support/in_memory_demo_backend.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('local-only 账号登录同步后，退出再登录仍能恢复 synced 账号状态', (WidgetTester tester) async {
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

    final firstAccountRepository = AccountRepository(
      localStore: AccountLocalStore(storageKey: 's03_first_account'),
      practiceRepository: firstRepository,
      apiService: AccountApiService(baseUrl: backend.baseUri.toString()),
      connectivityChecker: () async => true,
    );
    final firstHouseholdRepository = createLocalHouseholdRepository(
      accountRepository: firstAccountRepository,
      directory: tempDir,
      apiBaseUrl: backend.baseUri.toString(),
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

    await _openAccountEntryFromShell(tester);

    await tester.enterText(
      find.byKey(const Key('account-phone-field')),
      '13800138000',
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('account-code-field')),
      '246810',
    );
    await tester.pump();
    // Dismiss soft keyboard before tapping submit
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.ensureVisible(find.byKey(const Key('account-submit-button')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(
      find.byKey(const Key('account-submit-button')),
      warnIfMissed: false,
    );
    await tester.pump();
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('account-status-signed-in-synced')),
      timeout: const Duration(seconds: 30),
    );

    expect(
      find.byKey(const Key('account-status-signed-in-synced')),
      findsOneWidget,
    );
    expect(find.textContaining('登录已完成'), findsWidgets);
    expect(backend.bootstrapCount, 1);

    await _scrollTo(tester, find.byKey(const Key('account-clear-button')));
    await tester.tap(
      find.byKey(const Key('account-clear-button')),
      warnIfMissed: false,
    );
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('account-clear-confirm-dialog')),
      timeout: const Duration(seconds: 15),
    );
    await tester.tap(
      find.byKey(const Key('account-clear-confirm-button')),
      warnIfMissed: false,
    );
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('account-status-signed-out')),
      timeout: const Duration(seconds: 30),
    );

    await tester.enterText(
      find.byKey(const Key('account-phone-field')),
      '13800138000',
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('account-code-field')),
      '246810',
    );
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.ensureVisible(find.byKey(const Key('account-submit-button')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(
      find.byKey(const Key('account-submit-button')),
      warnIfMissed: false,
    );
    await tester.pump();
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('account-status-signed-in-synced')),
      timeout: const Duration(seconds: 30),
    );

    expect(backend.bootstrapCount, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
    await firstRepository.close();
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
  await _pumpBriefly(tester);
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

Future<void> _openAccountEntryFromShell(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('shell-nav-me')));
  await _pumpBriefly(tester);
  await _pumpUntilFound(tester, find.byKey(const Key('me-user-info')));
  await tester.tap(find.byKey(const Key('me-user-info')));
  await _pumpUntilFound(
    tester,
    find.byKey(const Key('account-entry-surface')),
    timeout: const Duration(seconds: 30),
  );
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await _pumpBriefly(tester);
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
