import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart'
    show defaultAccountApiBaseUrl, defaultAccountApiVersion;
import 'package:mobile/features/mentor/data/local/mentor_local_data_source.dart';
import 'package:mobile/features/mentor/domain/models/mentor_fact_event.dart';
import 'package:mobile/features/mentor/presentation/mentor_view_model.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/presentation/screens/home_screen.dart';
import 'package:mobile/features/sync/data/repositories/sync_repository.dart';
import 'package:provider/provider.dart';

import 'in_memory_demo_backend.dart';

class FullChainTestHarness {
  FullChainTestHarness._({
    required this.bootState,
    required this.backend,
    required this.tempDir,
    required this.practiceDbName,
    required this.installationId,
    required this.childDisplayName,
    required this.ageBucket,
  });

  final AppBootState bootState;
  final InMemoryDemoBackend backend;
  final Directory tempDir;
  final String practiceDbName;
  final String installationId;
  final String childDisplayName;
  final OnboardingAgeBucket ageBucket;

  PracticeRepository? _activeRepository;

  static Future<FullChainTestHarness> create({
    String practiceDbName = 's06_full_chain_release',
    String installationId = 'install_s06_full_chain_test',
    String childDisplayName = '米米',
    OnboardingAgeBucket ageBucket = OnboardingAgeBucket.twelveToEighteen,
    String minSupportedVersion = defaultAccountApiVersion,
    Duration simulatedSlowResponse = const Duration(milliseconds: 250),
    int mentorRateLimit = 2,
  }) async {
    final bootState = await AppBootState.load(rootBundle);
    if (!bootState.isReady) {
      fail('App boot state 未准备完成，无法启动 S06 full-chain proof。');
    }

    final backendUri = _resolveConfiguredBackendUri();
    final backend = await InMemoryDemoBackend.start(
      bindAddress: _resolveBindAddress(backendUri),
      port: backendUri.port,
      minSupportedVersion: minSupportedVersion,
      simulatedSlowResponse: simulatedSlowResponse,
      mentorRateLimit: mentorRateLimit,
    );
    final tempDir = await Directory.systemTemp.createTemp('s06_full_chain_');

    return FullChainTestHarness._(
      bootState: bootState,
      backend: backend,
      tempDir: tempDir,
      practiceDbName: practiceDbName,
      installationId: installationId,
      childDisplayName: childDisplayName,
      ageBucket: ageBucket,
    );
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    OnboardingCompletedSnapshotLoader? completedSnapshotLoader,
  }) async {
    await disposeMountedApp(tester);
    await tester.pumpWidget(
      BabyTalkApp(
        bootState: bootState,
        repositoryFactory: _openRepository,
        appDirectoryResolver: () async => tempDir,
        completedSnapshotLoader: completedSnapshotLoader,
        practiceContinuityRefreshTimeout: Duration.zero,
      ),
    );
    await tester.pump();
  }

  Future<void> disposeMountedApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
    final repository = _activeRepository;
    _activeRepository = null;
    if (repository != null) {
      await repository.close();
    }
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> dispose() async {
    final repository = _activeRepository;
    _activeRepository = null;
    if (repository != null) {
      await repository.close();
    }
    await backend.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }

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
      timeout: const Duration(seconds: 12),
      reason: 'onboarding stage match card',
    );

    await scrollTo(tester, find.byKey(const Key('onboarding-submit-button')));
    await tester.tap(find.byKey(const Key('onboarding-submit-button')));
    await tester.pumpAndSettle();
    await pumpUntilFound(
      tester,
      find.byKey(const Key('shell-ready')),
      timeout: const Duration(seconds: 12),
      reason: 'shell ready after onboarding',
    );
  }

  Future<void> completeStarterPractice(WidgetTester tester) async {
    await switchToHomeTab(tester);
    await pumpUntilFound(
      tester,
      find.byKey(const Key('home-starter-seed')),
      timeout: const Duration(seconds: 45),
      step: const Duration(milliseconds: 300),
      reason: 'home starter seed (continuity loaded)',
    );
    await scrollHomeTo(tester, find.byKey(const Key('home-start-practice')));
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
    await pumpUntilFound(
      tester,
      secondReaction,
      reason: 'second reaction button',
    );
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
    await pumpUntilFound(
      tester,
      thirdReaction,
      reason: 'third reaction button',
    );
    await tester.ensureVisible(thirdReaction);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(thirdReaction);
    // Pump 3 seconds: enough for DB write + navigator pop animation on slow device.
    await tester.pump(const Duration(milliseconds: 3000));
    // Drag the home list all the way to the top (it was scrolled down to reveal
    // home-start-practice). A large positive Y drag scrolls content upward.
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

  Future<void> signInAndSync(
    WidgetTester tester, {
    String phoneNumber = '13800138000',
    String verificationCode = '246810',
  }) async {
    await switchToHomeTab(tester);
    await scrollHomeTo(
      tester,
      find.byKey(const Key('home-account-open-entry')),
    );
    await tester.tap(find.byKey(const Key('home-account-open-entry')));
    await tester.pumpAndSettle();
    await pumpUntilFound(
      tester,
      find.byKey(const Key('account-entry-surface')),
      reason: 'account entry surface',
    );

    await tester.enterText(
      find.byKey(const Key('account-phone-field')),
      phoneNumber,
    );
    await tester.enterText(
      find.byKey(const Key('account-code-field')),
      verificationCode,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('account-submit-button')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('account-submit-button')));
    await tester.pump();
    await pumpUntilFound(
      tester,
      find.byKey(const Key('account-status-signed-in-synced')),
      timeout: const Duration(seconds: 16),
      reason: 'signed-in synced status',
    );
  }

  Future<MentorViewModel> submitMentorPrompt(
    WidgetTester tester, {
    required String prompt,
  }) async {
    await tester.tap(find.byKey(const Key('shell-mentor-fab')));
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
    return waitForMentorSubmissionToSettle(tester);
  }

  Future<void> switchToHomeTab(WidgetTester tester) async {
    final homeLabel = find.text('首页');
    if (homeLabel.evaluate().isNotEmpty) {
      await tester.tap(homeLabel.last);
      await tester.pumpAndSettle();
    }
  }

  Future<void> switchShellTab(
    WidgetTester tester, {
    required String label,
    required Key readyKey,
  }) async {
    final labelFinder = find.text(label);
    await tester.tap(labelFinder.last);
    await tester.pumpAndSettle();
    await pumpUntilFound(
      tester,
      find.byKey(readyKey),
      timeout: const Duration(seconds: 12),
      reason: 'shell tab $label',
    );
  }

  Future<SyncQueueInspection> inspectSyncQueue() async {
    final localDataSource = await PracticeLocalDataSource.open(
      directory: tempDir.path,
      name: practiceDbName,
    );
    try {
      final repository = SyncRepository(
        localDataSource: localDataSource,
        installationIdReader: _readInstallationId,
      );
      return repository.inspectQueue();
    } finally {
      await localDataSource.close();
    }
  }

  Future<List<MentorFactEvent>> readMentorFacts({
    MentorFactType? eventType,
    int? limit,
  }) async {
    final dataSource = await MentorLocalDataSource.open(
      directory: tempDir.path,
    );
    try {
      return dataSource.listMentorFactEvents(
        eventType: eventType,
        limit: limit,
      );
    } finally {
      await dataSource.close();
    }
  }

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
        idGenerator: () => installationId,
      ),
    );
    _activeRepository = repository;
    return repository;
  }

  Future<String?> _readInstallationId() async {
    final file = File(
      '${tempDir.path}${Platform.pathSeparator}installation_id.txt',
    );
    if (!await file.exists()) {
      return null;
    }
    final value = (await file.readAsString()).trim();
    return value.isEmpty ? null : value;
  }

  static Future<MentorViewModel> waitForMentorSubmissionToSettle(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 12),
    Duration step = const Duration(milliseconds: 50),
  }) async {
    MentorViewModel? resolved;
    await pumpUntil(
      tester,
      () {
        final sheet = find.byKey(const Key('mentor-panel-sheet'));
        if (sheet.evaluate().isEmpty) {
          return false;
        }
        final viewModel = Provider.of<MentorViewModel>(
          tester.element(sheet),
          listen: false,
        );
        if (viewModel.isSubmittingChat) {
          return false;
        }
        resolved = viewModel;
        return true;
      },
      timeout: timeout,
      step: step,
      reason: 'mentor submission settled',
    );
    return resolved!;
  }

  static Future<void> scrollHomeTo(
    WidgetTester tester,
    Finder finder, {
    String reason = 'home content',
  }) async {
    await tester.scrollUntilVisible(
      finder,
      180,
      scrollable: find.descendant(
        of: find.byType(HomeScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    if (finder.evaluate().isEmpty) {
      fail('滚动后仍未找到 $reason。');
    }
  }

  static Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

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
    for (var index = 0; index < totalSteps; index++) {
      await tester.pump(step);
      if (predicate()) {
        return;
      }
    }
    fail('Timed out waiting for $reason.');
  }
}

Uri _resolveConfiguredBackendUri() {
  final uri = Uri.parse(defaultAccountApiBaseUrl);
  if (uri.scheme != 'http') {
    fail(
      'S06 integration proof 只支持本地 http demo backend，当前收到 `$defaultAccountApiBaseUrl`。',
    );
  }
  if (uri.host.isEmpty) {
    fail('BABY_TALK_API_BASE_URL 缺少 host：`$defaultAccountApiBaseUrl`。');
  }
  if (uri.path.isNotEmpty && uri.path != '/') {
    fail(
      'S06 integration proof 期望无 path 前缀的本地 base url，当前收到 `$defaultAccountApiBaseUrl`。',
    );
  }
  return uri;
}

InternetAddress _resolveBindAddress(Uri uri) {
  switch (uri.host) {
    case 'localhost':
    case '127.0.0.1':
      return InternetAddress.loopbackIPv4;
  }

  final parsed = InternetAddress.tryParse(uri.host);
  if (parsed == null) {
    fail('无法为 `$uri` 解析可绑定的本地地址。');
  }
  return parsed;
}
