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
import 'package:mobile/app/app.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/mentor/presentation/mentor_view_model.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/presentation/screens/home_screen.dart';
import 'package:provider/provider.dart';

class E2eTestHarness {
  E2eTestHarness._({
    required this.backendUri,
    required this.tempDir,
    required this.bootState,
    required this.childDisplayName,
    required this.ageBucket,
    required this.practiceDbName,
  });

  final Uri backendUri;
  final Directory tempDir;
  final AppBootState bootState;
  final String childDisplayName;
  final OnboardingAgeBucket ageBucket;
  final String practiceDbName;

  PracticeRepository? _activeRepository;

  static Future<E2eTestHarness> create({
    String childDisplayName = '小明',
    OnboardingAgeBucket ageBucket = OnboardingAgeBucket.twelveToEighteen,
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
      childDisplayName: childDisplayName,
      ageBucket: ageBucket,
      practiceDbName: practiceDbName,
    );
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await _disposeMountedApp(tester);
    await tester.pumpWidget(
      BabyTalkApp(
        bootState: bootState,
        repositoryFactory: _openRepository,
        accountRepositoryFactory: (practiceRepository, directory) async {
          return AccountRepository(
            localStore: AccountLocalStore(
              directoryResolver: () async => directory,
            ),
            practiceRepository: practiceRepository,
            apiService: AccountApiService(baseUri: backendUri),
            connectivityChecker: () async => true,
          );
        },
        appDirectoryResolver: () async => tempDir,
        practiceContinuityRefreshTimeout: Duration.zero,
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
      find.byKey(const Key('onboarding-start-button')),
      reason: 'onboarding start button',
    );
    await scrollTo(tester, find.byKey(const Key('onboarding-start-button')));
    await tester.tap(find.byKey(const Key('onboarding-start-button')));
    await tester.pumpAndSettle();

    await pumpUntilFound(
      tester,
      find.byKey(const Key('onboarding-name-input')),
      reason: 'onboarding name input',
    );
    await scrollTo(tester, find.byKey(const Key('onboarding-name-input')));
    await tester.enterText(
      find.byKey(const Key('onboarding-name-input')),
      childDisplayName,
    );
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const Key('onboarding-name-continue')));
    await tester.tap(find.byKey(const Key('onboarding-name-continue')));
    await tester.pumpAndSettle();

    await pumpUntilFound(
      tester,
      find.byKey(const Key('onboarding-age-grid')),
      reason: 'onboarding age grid',
    );
    final ageCard = find.byKey(
      Key('onboarding-age-card-${ageBucket.wireValue}'),
    );
    await scrollTo(tester, ageCard);
    await tester.tap(ageCard);
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const Key('onboarding-age-continue')));
    await tester.tap(find.byKey(const Key('onboarding-age-continue')));
    await tester.pumpAndSettle();

    await pumpUntilFound(
      tester,
      find.byKey(const Key('onboarding-stage-match-card')),
      // Real backend stage-match API call — allow more time.
      timeout: const Duration(seconds: 20),
      reason: 'onboarding stage match card',
    );
    await scrollTo(tester, find.byKey(const Key('onboarding-submit-button')));
    await tester.tap(find.byKey(const Key('onboarding-submit-button')));
    await tester.pumpAndSettle();

    await pumpUntilFound(
      tester,
      find.byKey(const Key('shell-ready')),
      timeout: const Duration(seconds: 20),
      reason: 'shell ready after onboarding',
    );
  }

  Future<void> completeStarterPractice(WidgetTester tester) async {
    await pumpUntilFound(
      tester,
      find.byKey(const Key('home-starter-seed')),
      timeout: const Duration(seconds: 45),
      step: const Duration(milliseconds: 300),
      reason: 'home starter seed',
    );
    await _scrollHomeTo(tester, find.byKey(const Key('home-start-practice')));
    await tester.tap(find.byKey(const Key('home-start-practice')));
    await tester.pumpAndSettle();

    await pumpUntilFound(
      tester,
      find.byKey(const Key('phrase-card-bath_time_warm_water')),
      reason: 'first starter phrase',
    );
    final firstReaction = find.byKey(
      const Key('reaction-bath_time_warm_water-engaged'),
    );
    await scrollTo(tester, firstReaction);
    await tester.tap(firstReaction);

    await pumpUntilFound(
      tester,
      find.byKey(const Key('phrase-card-bath_time_splash_splash')),
      reason: 'second starter phrase',
    );
    final secondReaction = find.byKey(
      const Key('reaction-bath_time_splash_splash-imitated'),
    );
    await pumpUntilFound(tester, secondReaction, reason: 'second reaction');
    await tester.ensureVisible(secondReaction);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(secondReaction);

    await pumpUntilFound(
      tester,
      find.byKey(const Key('phrase-card-bath_time_all_clean')),
      reason: 'third starter phrase',
    );
    final thirdReaction = find.byKey(
      const Key('reaction-bath_time_all_clean-calm'),
    );
    await pumpUntilFound(tester, thirdReaction, reason: 'third reaction');
    await tester.ensureVisible(thirdReaction);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(thirdReaction);
    await tester.pump(const Duration(milliseconds: 3000));

    await tester.drag(
      find.descendant(
        of: find.byType(HomeScreen),
        matching: find.byType(Scrollable),
      ),
      const Offset(0, 5000),
    );
    await tester.pump();
    await pumpUntilFound(
      tester,
      find.byKey(const Key('recent-result-summary')),
      timeout: const Duration(seconds: 30),
      reason: 'recent result summary',
    );
  }

  Future<MentorViewModel> submitMentorPrompt(
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
    final fabWidget = tester.widget<FloatingActionButton>(mentorFab);
    final onPressed = fabWidget.onPressed;
    if (onPressed == null) {
      fail('Shell mentor FAB is disabled — make sure to completeStarterPractice first.');
    }
    onPressed();
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
    await tester.ensureVisible(find.byKey(const Key('mentor-chat-submit-button')));
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
        idGenerator: () => 'e2e_smoke_install_${DateTime.now().millisecondsSinceEpoch}',
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

  static Future<MentorViewModel> _waitForMentorSubmissionToSettle(
    WidgetTester tester, {
    // Dev-mode backend is fast, but allow time for network round-trip.
    Duration timeout = const Duration(seconds: 30),
    Duration step = const Duration(milliseconds: 100),
  }) async {
    MentorViewModel? resolved;
    await pumpUntil(
      tester,
      () {
        final sheet = find.byKey(const Key('mentor-panel-sheet'));
        if (sheet.evaluate().isEmpty) return false;
        final viewModel = Provider.of<MentorViewModel>(
          tester.element(sheet),
          listen: false,
        );
        if (viewModel.isSubmittingChat) return false;
        resolved = viewModel;
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
