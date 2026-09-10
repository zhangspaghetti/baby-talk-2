// E2E test harness — connects Flutter app to a REAL backend.
//
// Unlike FullChainTestHarness (which starts InMemoryDemoBackend), this harness
// points the app at whatever URL is provided via --dart-define:
//   --dart-define=BABY_TALK_API_BASE_URL=http://localhost:8080
//
// Usage:
//   final harness = await E2eTestHarness.create();
//   addTearDown(harness.dispose);
//   await harness.pumpApp(tester);
//   await harness.completeOnboarding(tester);

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/mentor/presentation/mentor_notifier.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/presentation/screens/home_screen.dart';

import 'app_test_repositories.dart';

class E2eTestHarness {
  E2eTestHarness._({
    required this.backendUri,
    required this.tempDir,
    required this.bootState,
    required this.practiceDbName,
  });

  final Uri backendUri;
  final Directory tempDir;
  final AppBootState bootState;
  final String practiceDbName;

  PracticeRepository? _activeRepository;

  static Future<E2eTestHarness> create({
    String practiceDbName = 'e2e_smoke',
    String backendUrl = defaultAccountApiBaseUrl,
  }) async {
    final bootState = await AppBootState.load(rootBundle);
    if (!bootState.isReady) {
      fail('App boot state 未准备完成，无法启动 E2E 测试。');
    }

    final backendUri = Uri.parse(backendUrl);
    if (backendUri.scheme != 'http' && backendUri.scheme != 'https') {
      fail('E2E backend URL 不合法: $backendUrl');
    }

    final tempDir = await Directory.systemTemp.createTemp('e2e_smoke_');
    return E2eTestHarness._(
      backendUri: backendUri,
      tempDir: tempDir,
      bootState: bootState,
      practiceDbName: practiceDbName,
    );
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await _disposeMountedApp(tester);
    final practiceRepository = await _openRepository(
      bootState.assetPhraseService!,
    );
    final accountRepository = AccountRepository(
      localStore: AccountLocalStore(storageKey: 'e2e_smoke_account'),
      practiceRepository: practiceRepository,
      apiService: AccountApiService(baseUrl: backendUri.toString()),
      connectivityChecker: () async => true,
    );
    final householdRepository = createLocalHouseholdRepository(
      accountRepository: accountRepository,
      directory: tempDir,
      apiBaseUrl: backendUri.toString(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetPhraseServiceProvider.overrideWithValue(
            bootState.assetPhraseService!,
          ),
          appDirectoryProvider.overrideWith((ref) => tempDir),
          practiceRepositoryProvider.overrideWith((ref) => practiceRepository),
          accountRepositoryProvider.overrideWith((ref) => accountRepository),
          householdRepositoryProvider.overrideWith(
            (ref) => householdRepository,
          ),
        ],
        child: BabyTalkApp(
          bootState: bootState,
          practiceContinuityRefreshTimeout: Duration.zero,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> dispose() async {
    await _closeActiveRepository();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }

  // ---------------------------------------------------------------------------
  // UI Navigation Helpers
  // ---------------------------------------------------------------------------

  Future<void> completeOnboarding(WidgetTester tester) async {
    await pumpUntilFound(
      tester,
      find.byKey(const Key('care-entry-grid')),
      reason: 'V4 care-entry grid',
    );
    await tester.tap(find.byKey(const Key('care-entry-primary-action')));
    await pumpUntilFound(
      tester,
      find.byKey(const Key('care-entry-first-utterance-english')),
      reason: 'V4 first utterance',
    );
    await tester.tap(find.byKey(const Key('care-entry-said-action')));
    await pumpUntilFound(
      tester,
      find.byKey(const Key('care-entry-reaction-prompt')),
      reason: 'V4 reaction prompt',
    );
    await tester.tap(find.byKey(const Key('care-entry-reaction-hesitant')));
    await pumpUntilFound(
      tester,
      find.byKey(const Key('care-entry-next-support')),
      timeout: const Duration(seconds: 20),
      reason: 'V4 next support',
    );
    await scrollTo(
      tester,
      find.byKey(const Key('care-entry-finish-today-action')),
    );
    await tester.tap(find.byKey(const Key('care-entry-finish-today-action')));
    await pumpUntilFound(
      tester,
      find.byKey(const Key('care-entry-garden-trace')),
      timeout: const Duration(seconds: 20),
      reason: 'V4 garden trace',
    );
    await tester.tap(find.byKey(const Key('care-entry-open-today-action')));
    await pumpUntilFound(
      tester,
      find.byKey(const Key('shell-ready')),
      timeout: const Duration(seconds: 60),
      reason: 'shell ready after V4 onboarding',
    );
  }

  Future<void> completeStarterPractice(WidgetTester tester) async {
    await pumpUntilFound(
      tester,
      find.byKey(const Key('home-today-primary-cta')),
      timeout: const Duration(seconds: 45),
      step: const Duration(milliseconds: 300),
      reason: 'Today Care Path entry',
    );
    await _scrollHomeTo(
      tester,
      find.byKey(const Key('home-today-primary-cta')),
    );
    await tester.tap(find.byKey(const Key('home-today-primary-cta')));
    await pumpUntilFound(
      tester,
      find.byKey(const Key('care-turn-current-utterance')),
      reason: 'current Care Turn utterance',
    );
    await tester.tap(find.byKey(const Key('care-turn-said-button')));
    await pumpUntilFound(
      tester,
      find.byKey(const Key('care-reaction-cooperating')),
      reason: 'Care Turn reaction prompt',
    );
    await tester.tap(find.byKey(const Key('care-reaction-cooperating')));
    await pumpUntilFound(
      tester,
      find.byKey(const Key('care-turn-next-support')),
      timeout: const Duration(seconds: 60),
      reason: 'Care Turn next support',
    );
    await scrollTo(tester, find.byKey(const Key('care-turn-quiet-exit')));
    await tester.tap(find.byKey(const Key('care-turn-quiet-exit')));
    await pumpUntilFound(
      tester,
      find.byKey(const Key('home-today-care-node-card')),
      timeout: const Duration(seconds: 60),
      reason: 'Today Care Path after Care Turn',
    );
  }

  Future<MentorNotifier> submitMentorPrompt(
    WidgetTester tester, {
    required String prompt,
  }) async {
    final mentorFab = find.byKey(const Key('shell-mentor-fab'));
    await pumpUntilFound(
      tester,
      mentorFab,
      timeout: const Duration(seconds: 8),
      reason: 'shell mentor fab',
    );
    await tester.tap(mentorFab);
    await tester.pump();

    await pumpUntilFound(
      tester,
      find.byKey(const Key('mentor-panel-sheet')),
      reason: 'mentor panel sheet',
    );
    await tester.tap(find.byKey(const Key('mentor-tab-chat-button')));
    await tester.pumpAndSettle();
    await pumpUntilFound(
      tester,
      find.byKey(const Key('mentor-chat-input')),
      timeout: const Duration(seconds: 15),
      reason: 'mentor chat input',
    );

    await tester.enterText(find.byKey(const Key('mentor-chat-input')), prompt);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('mentor-chat-submit-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mentor-chat-submit-button')));
    await tester.pump();
    return _waitForMentorSubmissionToSettle(tester);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<PracticeRepository> _openRepository(
    AssetPhraseService assetPhraseService,
  ) async {
    final localDataSource = await PracticeLocalDataSource.open(
      directory: tempDir.path,
      name: practiceDbName,
    );
    final repository = PracticeRepository(
      assetPhraseService: assetPhraseService,
      localDataSource: localDataSource,
      installationIdService: InstallationIdService(
        directoryResolver: () async => tempDir,
        idGenerator: () =>
            'e2e_smoke_install_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    _activeRepository = repository;
    return repository;
  }

  Future<void> _disposeMountedApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
    await _closeActiveRepository();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> _closeActiveRepository() async {
    final repository = _activeRepository;
    _activeRepository = null;
    if (repository != null) {
      await repository.close();
    }
  }

  Future<void> _scrollHomeTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      180,
      scrollable: find.descendant(
        of: find.byType(HomeScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
  }

  static Future<MentorNotifier> _waitForMentorSubmissionToSettle(
    WidgetTester tester, {
    // Dev-mode backend is fast, but allow time for network round-trip.
    Duration timeout = const Duration(seconds: 30),
    Duration step = const Duration(milliseconds: 100),
  }) async {
    MentorNotifier? resolved;
    await pumpUntil(
      tester,
      () {
        final sheet = find.byKey(const Key('mentor-panel-sheet'));
        if (sheet.evaluate().isEmpty) return false;
        final notifier = ProviderScope.containerOf(
          tester.element(sheet),
        ).read(mentorNotifierProvider);
        if (notifier.isSubmittingChat) return false;
        resolved = notifier;
        return true;
      },
      timeout: timeout,
      step: step,
      reason: 'mentor submission settled',
    );
    return resolved!;
  }

  // ---------------------------------------------------------------------------
  // Static pump / scroll utilities (mirror of FullChainTestHarness)
  // ---------------------------------------------------------------------------

  static Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 8),
    Duration step = const Duration(milliseconds: 50),
    String reason = 'expected widget',
  }) {
    return pumpUntil(
      tester,
      () => finder.evaluate().isNotEmpty,
      timeout: timeout,
      step: step,
      reason: reason,
    );
  }

  static Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() predicate, {
    Duration timeout = const Duration(seconds: 8),
    Duration step = const Duration(milliseconds: 50),
    String reason = 'expected condition',
  }) async {
    final totalSteps = timeout.inMilliseconds ~/ step.inMilliseconds;
    for (var i = 0; i < totalSteps; i++) {
      await tester.pump(step);
      if (predicate()) return;
    }
    fail('Timed out waiting for $reason.');
  }

  static Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }
}
