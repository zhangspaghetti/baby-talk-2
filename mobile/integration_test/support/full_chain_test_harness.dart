import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/mentor/data/local/mentor_local_data_source.dart';
import 'package:mobile/features/mentor/domain/models/mentor_fact_event.dart';
import 'package:mobile/features/mentor/presentation/mentor_notifier.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/presentation/screens/home_screen.dart';
import 'package:mobile/features/practice/presentation/garden_growth_notifier.dart';
import 'package:mobile/features/sync/data/repositories/sync_repository.dart';
import 'package:provider/provider.dart';

import 'app_test_repositories.dart';
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

  String get _mentorStoreName => 'mentor_s06_${tempDir.path.hashCode}';

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
        accountRepositoryFactory: (practiceRepository, directory) async {
          return AccountRepository(
            localStore: AccountLocalStore(
              storageKey: 'test_full_chain_account_${tempDir.path.hashCode}',
            ),
            practiceRepository: practiceRepository,
            apiService: AccountApiService(baseUrl: backend.baseUri.toString()),
            connectivityChecker: () async => true,
          );
        },
        householdRepositoryFactory: (accountRepository, directory) async {
          return createLocalHouseholdRepository(
            accountRepository: accountRepository,
            directory: directory,
            apiBaseUrl: backend.baseUri.toString(),
          );
        },
        appDirectoryResolver: () async => tempDir,
        completedSnapshotLoader: completedSnapshotLoader,
        mentorStoreName: _mentorStoreName,
        practiceContinuityRefreshTimeout: Duration.zero,
      ),
    );
    await tester.pump();
  }

  Future<void> disposeMountedApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 300));
    await closeActiveRepository();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> closeActiveRepository() async {
    final repository = _activeRepository;
    _activeRepository = null;
    if (repository != null) {
      await repository.close();
    }
  }

  Future<void> dispose() async {
    await closeActiveRepository();
    await backend.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }

  Future<void> seedPracticeEventsForBenchmark({required int count}) async {
    if (count <= 0) {
      return;
    }
    await closeActiveRepository();
    final repository = await _openRepository(bootState.assetPhraseService!);
    const phraseIds = <String>[
      'bath_time_warm_water',
      'bath_time_splash_splash',
      'bath_time_all_clean',
    ];
    const reactionTypes = <BabyReactionType>[
      BabyReactionType.engaged,
      BabyReactionType.imitated,
      BabyReactionType.calm,
    ];
    final baseTimestamp = DateTime.utc(2026, 5, 20, 8);
    try {
      for (var index = 0; index < count; index += 1) {
        await repository.recordReaction(
          spaceId: 'daily_care',
          activityId: 'bath_time',
          phraseId: phraseIds[index % phraseIds.length],
          reactionType: reactionTypes[index % reactionTypes.length],
          clientTimestamp: baseTimestamp.add(Duration(seconds: index)),
          localEventId: 'r4_perf_${practiceDbName}_$index',
        );
      }
    } finally {
      await closeActiveRepository();
    }
  }

  Future<Map<String, int>> measurePracticeProjectionForBenchmark() async {
    await closeActiveRepository();
    final repository = await _openRepository(bootState.assetPhraseService!);
    try {
      final measurements = <String, int>{};
      final catalog = await _measureBenchmarkStep(
        measurements,
        'catalog_ms',
        repository.getActivityCatalog,
      );
      measurements['catalog_total_events'] = catalog.totalStoredEvents;
      await _measureBenchmarkStep(
        measurements,
        'continuity_ms',
        () => repository.getContinuitySnapshot(
          starterSpaceId: 'daily_care',
          starterActivityId: 'bath_time',
        ),
      );
      await _measureBenchmarkStep(
        measurements,
        'home_summary_ms',
        () => repository.getHomeSummary(
          spaceId: 'daily_care',
          activityId: 'bath_time',
        ),
      );
      return measurements;
    } finally {
      await closeActiveRepository();
    }
  }

  Future<void> completeOnboarding(WidgetTester tester) async {
    try {
      await pumpUntilFound(
        tester,
        find.byKey(const Key('onboarding-start-button')),
        timeout: const Duration(seconds: 30),
        step: const Duration(milliseconds: 100),
        reason: 'onboarding start button',
      );
    } on TestFailure {
      fail(
        'Timed out waiting for onboarding start button. '
        'visibleState=${_visibleBootStateSummary()}; '
        'visibleText=${_visibleTextSummary()}',
      );
    }
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
    await scrollHomeTo(
      tester,
      find.byKey(const Key('recent-result-summary')),
      reason: 'recent result summary',
    );
  }

  Future<void> signInAndSync(
    WidgetTester tester, {
    String phoneNumber = '13800138000',
    String verificationCode = '246810',
  }) async {
    await tester.tap(find.byKey(const Key('shell-drawer-trigger')));
    await tester.pumpAndSettle();
    await pumpUntilFound(
      tester,
      find.byKey(const Key('shell-account-open-entry')),
      timeout: const Duration(seconds: 20),
      reason: 'shell account entry',
    );
    await tester.ensureVisible(
      find.byKey(const Key('shell-account-open-entry')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('shell-account-open-entry')));
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
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('account-code-field')),
      verificationCode,
    );
    await tester.pump();
    // Dismiss soft keyboard before tapping submit
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.ensureVisible(find.byKey(const Key('account-submit-button')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(
      find.byKey(const Key('account-submit-button')),
      warnIfMissed: false,
    );
    await tester.pump();
    await pumpUntilFound(
      tester,
      find.byKey(const Key('account-status-signed-in-synced')),
      timeout: const Duration(seconds: 30),
      reason: 'signed-in synced status',
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
    final fabWidget = tester.widget<FloatingActionButton>(mentorFab);
    final onPressed = fabWidget.onPressed;
    if (onPressed == null) {
      fail('Shell mentor FAB is disabled.');
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
    await tester.ensureVisible(
      find.byKey(const Key('mentor-chat-submit-button')),
    );
    await tester.pumpAndSettle();
    final submitButton = tester.widget<FilledButton>(
      find.byKey(const Key('mentor-chat-submit-button')),
    );
    final submitChat = submitButton.onPressed;
    if (submitChat == null) {
      final notifier = Provider.of<MentorNotifier>(
        tester.element(find.byKey(const Key('mentor-panel-sheet'))),
        listen: false,
      );
      fail(
        'Mentor chat submit is disabled: '
        'phase=${notifier.chatAvailability.phase}; '
        'code=${notifier.chatAvailability.code}; '
        'detail=${notifier.chatAvailability.detail}',
      );
    }
    submitChat();
    await tester.pump();
    final notifier = await waitForMentorSubmissionToSettle(tester);
    await tester.pumpAndSettle();
    return notifier;
  }

  Future<void> switchToHomeTab(WidgetTester tester) async {
    await pumpUntil(
      tester,
      () => find.byKey(const Key('account-entry-surface')).evaluate().isEmpty,
      timeout: const Duration(seconds: 8),
      reason: 'account entry closed',
    );
    ScaffoldMessenger.of(
      tester.element(find.byType(NavigationBar)),
    ).removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await _tapShellTab(tester, 0);
    await tester.pumpAndSettle();
    await pumpUntilFound(
      tester,
      find.text('$childDisplayName 的练习'),
      timeout: const Duration(seconds: 12),
      reason: 'home tab active',
    );
  }

  Future<void> switchShellTab(
    WidgetTester tester, {
    required String label,
    required Key readyKey,
  }) async {
    await _tapShellTab(tester, _shellTabIndex(label));
    await tester.pumpAndSettle();
    await pumpUntilFound(
      tester,
      find.byKey(readyKey),
      timeout: const Duration(seconds: 12),
      reason: 'shell tab $label',
    );
  }

  int _shellTabIndex(String label) {
    return switch (label) {
      '首页' || '练习' => 0,
      '花园' || '成长' => 1,
      _ => throw ArgumentError.value(label, 'label', 'Unknown shell tab'),
    };
  }

  Future<void> _tapShellTab(WidgetTester tester, int index) async {
    final navigationBar = find.byType(NavigationBar);
    await pumpUntilFound(
      tester,
      navigationBar,
      timeout: const Duration(seconds: 8),
      reason: 'shell navigation bar',
    );
    final widget = tester.widget<NavigationBar>(navigationBar);
    final onDestinationSelected = widget.onDestinationSelected;
    if (onDestinationSelected == null) {
      fail('Shell navigation bar is missing onDestinationSelected.');
    }
    onDestinationSelected(index);
    await tester.pump();
  }

  static Future<void> waitForGardenProjectionReady(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 20),
    Duration step = const Duration(milliseconds: 100),
  }) async {
    GardenGrowthNotifier? resolved;
    await pumpUntil(
      tester,
      () {
        final shell = find.byKey(const Key('shell-ready'));
        if (shell.evaluate().isEmpty) {
          return false;
        }
        final container = riverpod.ProviderScope.containerOf(
          tester.element(shell),
          listen: false,
        );
        final notifier = container.read(gardenGrowthNotifierProvider);
        if (notifier.status == GardenGrowthLoadStatus.ready &&
            notifier.snapshot.spaces.isNotEmpty) {
          resolved = notifier;
          return true;
        }
        return false;
      },
      timeout: timeout,
      step: step,
      reason: 'garden projection ready',
    );

    if (resolved == null || resolved!.snapshot.spaces.isEmpty) {
      fail('Garden projection 未进入 ready non-empty 状态。');
    }
  }

  Future<SyncQueueInspection> inspectSyncQueue() async {
    final activeRepository = _activeRepository;
    if (activeRepository != null) {
      final installationId = await _readInstallationId();
      final events = await activeRepository.listEventHistory();
      final pendingUploads = await activeRepository.listPendingUploadRecords();
      return SyncQueueInspection(
        installationId: installationId,
        summary: summarizeSyncQueueEvents(events),
        pendingUploads: pendingUploads,
      );
    }

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
      name: _mentorStoreName,
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

  static Future<MentorNotifier> waitForMentorSubmissionToSettle(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 12),
    Duration step = const Duration(milliseconds: 50),
  }) async {
    MentorNotifier? resolved;
    await pumpUntil(
      tester,
      () {
        final sheet = find.byKey(const Key('mentor-panel-sheet'));
        if (sheet.evaluate().isEmpty) {
          return false;
        }
        final notifier = Provider.of<MentorNotifier>(
          tester.element(sheet),
          listen: false,
        );
        if (notifier.isSubmittingChat) {
          return false;
        }
        resolved = notifier;
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
    await pumpUntilFound(
      tester,
      _homeScrollables(),
      timeout: const Duration(seconds: 30),
      reason: 'home scrollable',
    );
    final scrollableState = tester.state<ScrollableState>(_homeScrollable());
    scrollableState.position.jumpTo(scrollableState.position.minScrollExtent);
    await tester.pump();

    for (var attempt = 0; attempt < 120; attempt++) {
      if (_finderExists(finder)) {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        if (_finderExists(finder)) {
          return;
        }
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

    fail('滚动后仍未找到 $reason。');
  }

  static Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  static Future<void> scrollHomeToTop(WidgetTester tester) async {
    await pumpUntilFound(
      tester,
      _homeScrollables(),
      timeout: const Duration(seconds: 8),
      reason: 'home scrollable',
    );
    final scrollableState = tester.state<ScrollableState>(_homeScrollable());
    scrollableState.position.jumpTo(scrollableState.position.minScrollExtent);
    await tester.pumpAndSettle();
  }

  static Finder _homeScrollables() {
    return find.descendant(
      of: find.byType(HomeScreen),
      matching: find.byType(Scrollable),
    );
  }

  static Finder _homeScrollable() => _homeScrollables().first;

  static bool _finderExists(Finder finder) {
    try {
      return finder.evaluate().isNotEmpty;
    } on StateError {
      return false;
    }
  }

  static Map<String, bool> _visibleBootStateSummary() {
    return <String, bool>{
      'bootLoading': find
          .byKey(const Key('boot-loading'))
          .evaluate()
          .isNotEmpty,
      'bootOnboarding': find
          .byKey(const Key('boot-route-onboarding'))
          .evaluate()
          .isNotEmpty,
      'bootShell': find
          .byKey(const Key('boot-route-shell'))
          .evaluate()
          .isNotEmpty,
      'shellReady': find.byKey(const Key('shell-ready')).evaluate().isNotEmpty,
      'bootFailed': find
          .byKey(const Key('boot-route-gate-failed'))
          .evaluate()
          .isNotEmpty,
      'onboardingBanner': find
          .byKey(const Key('onboarding-local-only-banner'))
          .evaluate()
          .isNotEmpty,
    };
  }

  static List<String> _visibleTextSummary() {
    return find
        .byType(Text)
        .evaluate()
        .map((element) => element.widget)
        .whereType<Text>()
        .map((widget) => widget.data?.trim())
        .whereType<String>()
        .where((text) => text.isNotEmpty)
        .take(12)
        .toList(growable: false);
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

Future<T> _measureBenchmarkStep<T>(
  Map<String, int> measurements,
  String key,
  Future<T> Function() action,
) async {
  final stopwatch = Stopwatch()..start();
  final result = await action();
  stopwatch.stop();
  measurements[key] = stopwatch.elapsedMilliseconds;
  return result;
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
