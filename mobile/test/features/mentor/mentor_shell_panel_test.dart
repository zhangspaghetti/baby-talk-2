import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/data/repositories/garden_growth_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/account/presentation/account_notifier.dart';
import 'package:mobile/features/household/presentation/household_notifier.dart';
import 'package:mobile/features/practice/presentation/garden_growth_notifier.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_notifier.dart';
import 'package:mobile/features/share/data/repositories/share_repository.dart';
import 'package:mobile/features/share/data/services/share_api_service.dart';
import 'package:mobile/features/share/data/services/share_sheet_launcher.dart';
import 'package:mobile/features/share/presentation/share_notifier.dart';
import 'package:mobile/features/share/domain/models/share_link_draft.dart';
import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/data/repositories/household_repository.dart';
import 'package:mobile/features/household/domain/models/household_role.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/mentor/data/repositories/mentor_repository.dart';
import 'package:mobile/features/mentor/data/services/mentor_api_service.dart';
import 'package:mobile/features/mentor/domain/models/local_mentor_suggestion.dart';
import 'package:mobile/features/mentor/domain/models/mentor_fact_event.dart';
import 'package:mobile/features/mentor/domain/services/local_mentor_suggestion_service.dart';
import 'package:mobile/features/mentor/presentation/mentor_audio_controller.dart';
import 'package:mobile/features/mentor/presentation/mentor_notifier.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/practice_session_notifier.dart';
import 'package:mobile/features/practice/presentation/screens/home_screen.dart';
import 'package:mobile/features/shell/presentation/app_shell_screen.dart';
import '../../support/isar_test_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): resolveBundledIsarLibraryPath()},
    );
  });

  testWidgets('shell 任一 tab 的全局 FAB 会打开默认建议 tab，并明确展示离线降级', (tester) async {
    await _setTallSurface(tester);
    final harness = (await tester.runAsync<_Harness>(
      () => _Harness.create(
        accountSeedSnapshot: AccountLocalSnapshot(
          consentState: AccountConsentState.acceptedPendingSync,
          session: AccountSession(
            accountId: 'account_shell',
            sessionId: 'session_shell',
            maskedPhoneNumber: '138****1234',
            createdAt: DateTime.utc(2026, 4, 9, 8),
          ),
          pendingSyncCount: 1,
          lastSyncPhase: 'home_visible_offline',
          lastVisibleError: '当前离线，已保留本机待同步记录，可稍后重试。',
        ),
        mentorSuggestionResult: LocalMentorSuggestionResult(
          suggestions: [
            LocalMentorSuggestion(
              suggestionId: 'starter_1',
              origin: LocalMentorSuggestionOrigin.starterPhrase,
              title: '先回到熟悉短句',
              body: '先把 Warm water. 贴在动作上，说一句就好。',
              phraseEnglish: 'Warm water.',
              reasonCode: 'starter_phrase',
            ),
          ],
          primaryOrigin: LocalMentorSuggestionOrigin.starterPhrase,
          contextFallbackUsed: false,
          redactedContextSummary:
              'starter_phrase:bath_time/bath_time_warm_water',
        ),
      ),
    ))!;
    addTearDown(() => _disposeHarness(tester, harness));

    await tester.runAsync(() async {
      await Future.wait([
        harness.accountNotifier.initialize(),
        harness.practiceSessionNotifier.initialize(),
      ]);
    });

    await tester.pumpWidget(harness.buildShell());
    await _pumpUntilFound(tester, find.byKey(const Key('shell-ready')));

    // §5 规则1：首页隐藏全局 FAB（用内联「问小禾」入口），故先切到「发现」Tab，
    // 验证非首页/非花园页的全局 FAB 能打开默认建议页。
    tester
        .widget<NavigationBar>(find.byType(NavigationBar))
        .onDestinationSelected!(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byKey(const Key('shell-mentor-fab')));
    await tester.pump();
    await _pumpUntilFound(tester, find.byKey(const Key('mentor-panel-sheet')));

    expect(find.byKey(const Key('mentor-panel-sheet')), findsOneWidget);
    expect(find.byKey(const Key('mentor-suggestion-tab')), findsOneWidget);
    expect(find.byKey(const Key('mentor-chat-tab')), findsNothing);
    expect(find.byKey(const Key('mentor-panel-banner')), findsOneWidget);
    expect(find.textContaining('离线'), findsWidgets);

    await tester.tap(find.byKey(const Key('mentor-tab-chat-button')));
    await _pumpUntilFound(tester, find.byKey(const Key('mentor-chat-tab')));
    await tester.scrollUntilVisible(
      find.byKey(const Key('mentor-chat-retry-button')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();

    expect(find.byKey(const Key('mentor-chat-tab')), findsOneWidget);
    expect(find.byKey(const Key('mentor-chat-retry-button')), findsOneWidget);
    expect(find.byKey(const Key('mentor-chat-phase-chip')), findsOneWidget);
    expect(
      find.byKey(const Key('mentor-chat-text-first-note')),
      findsOneWidget,
    );

    final panelOpenedFacts = harness.mentorRepository.appendedFacts
        .where((fact) => fact.eventType == MentorFactType.panelOpened)
        .toList();
    expect(panelOpenedFacts, hasLength(1));
  });

  testWidgets('Mentor 建议页会显示共享建议 adopted 的状态卡', (tester) async {
    await _setTallSurface(tester);
    final harness = (await tester.runAsync<_Harness>(
      () => _Harness.create(
        accountSeedSnapshot: AccountLocalSnapshot.signedOut,
        mentorSuggestionResult: LocalMentorSuggestionResult(
          suggestions: [
            LocalMentorSuggestion(
              suggestionId: 'shared_feeding_time',
              origin: LocalMentorSuggestionOrigin.sharedCaregiverContext,
              title: '接住家庭刚完成的练习',
              body: '次照护者刚完成一次共享练习。现在先接着喂饭时间。',
              reasonCode: 'shared_context_adopted_newer',
            ),
          ],
          primaryOrigin: LocalMentorSuggestionOrigin.sharedCaregiverContext,
          contextFallbackUsed: false,
          redactedContextSummary:
              'shared:shared_context_adopted_newer:caregiver:feeding_time',
          sharedContextStatus: const MentorSharedContextStatus(
            code: 'shared_context_adopted_newer',
            headline: '已采用家庭共享建议',
            detail: '次照护者刚完成一次共享练习，导师现在按“喂饭时间”继续。',
            adopted: true,
          ),
        ),
      ),
    ))!;
    addTearDown(() => _disposeHarness(tester, harness));

    await tester.runAsync(() async {
      await Future.wait([
        harness.accountNotifier.initialize(),
        harness.practiceSessionNotifier.initialize(),
      ]);
    });

    await tester.pumpWidget(harness.buildStandaloneHome());
    await _pumpUntilFound(tester, find.byKey(const Key('home-mentor-fab')));

    await tester.tap(find.byKey(const Key('home-mentor-fab')));
    await tester.pump();
    await _pumpUntilFound(tester, find.byKey(const Key('mentor-panel-sheet')));

    expect(
      find.byKey(const Key('mentor-shared-context-banner')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mentor-shared-context-chip')), findsOneWidget);
    expect(find.text('已采用家庭共享建议'), findsOneWidget);
    expect(find.textContaining('喂饭时间'), findsWidgets);
  });

  testWidgets('Mentor 建议页会显示共享建议 skipped 的安全原因', (tester) async {
    await _setTallSurface(tester);
    final harness = (await tester.runAsync<_Harness>(
      () => _Harness.create(
        accountSeedSnapshot: AccountLocalSnapshot.signedOut,
        mentorSuggestionResult: LocalMentorSuggestionResult(
          suggestions: [
            LocalMentorSuggestion(
              suggestionId: 'starter_1',
              origin: LocalMentorSuggestionOrigin.starterPhrase,
              title: '先回到熟悉短句',
              body: '先把 Warm water. 贴在动作上，说一句就好。',
              phraseEnglish: 'Warm water.',
              reasonCode: 'starter_phrase',
            ),
          ],
          primaryOrigin: LocalMentorSuggestionOrigin.starterPhrase,
          contextFallbackUsed: false,
          redactedContextSummary:
              'starter_phrase:bath_time/bath_time_warm_water;shared:shared_next_step_missing',
          sharedContextStatus: const MentorSharedContextStatus(
            code: 'shared_next_step_missing',
            headline: '共享建议已保留本地版本',
            detail: '共享下一步暂时打不开，导师继续使用本地建议。',
            adopted: false,
          ),
        ),
      ),
    ))!;
    addTearDown(() => _disposeHarness(tester, harness));

    await tester.runAsync(() async {
      await Future.wait([
        harness.accountNotifier.initialize(),
        harness.practiceSessionNotifier.initialize(),
      ]);
    });

    await tester.pumpWidget(harness.buildStandaloneHome());
    await _pumpUntilFound(tester, find.byKey(const Key('home-mentor-fab')));

    await tester.tap(find.byKey(const Key('home-mentor-fab')));
    await tester.pump();
    await _pumpUntilFound(tester, find.byKey(const Key('mentor-panel-sheet')));

    expect(
      find.byKey(const Key('mentor-shared-context-banner')),
      findsOneWidget,
    );
    expect(find.text('共享建议已保留本地版本'), findsOneWidget);
    expect(find.textContaining('共享下一步暂时打不开'), findsOneWidget);
    expect(find.textContaining('route args'), findsNothing);
  });

  testWidgets('standalone home 小 FAB 在缺失 onboarding 时仍打开同一 Mentor 面板并回退通用建议', (
    tester,
  ) async {
    await _setTallSurface(tester);
    final harness = (await tester.runAsync<_Harness>(
      () => _Harness.create(
        accountSeedSnapshot: AccountLocalSnapshot.signedOut,
        mentorSuggestionResult: const LocalMentorSuggestionService().derive(
          const LocalMentorSuggestionContext(
            contextFallbackUsed: true,
            fallbackReasonCode: 'onboarding_missing',
          ),
        ),
      ),
    ))!;
    addTearDown(() => _disposeHarness(tester, harness));

    await tester.runAsync(() async {
      await Future.wait([
        harness.accountNotifier.initialize(),
        harness.practiceSessionNotifier.initialize(),
      ]);
    });

    await tester.pumpWidget(harness.buildStandaloneHome());
    await _pumpUntilFound(tester, find.byKey(const Key('home-mentor-fab')));

    await tester.tap(find.byKey(const Key('home-mentor-fab')));
    await tester.pump();
    await _pumpUntilFound(tester, find.byKey(const Key('mentor-panel-sheet')));

    expect(find.byKey(const Key('mentor-panel-sheet')), findsOneWidget);
    expect(find.byKey(const Key('mentor-suggestion-tab')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('mentor-suggestion-card-safe_small_step')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();
    expect(
      find.byKey(const Key('mentor-suggestion-card-safe_small_step')),
      findsOneWidget,
    );
    expect(find.textContaining('还没读到本地档案'), findsOneWidget);
    expect(find.textContaining('onboarding 档案'), findsNothing);
  });

  testWidgets('chat tab 已登录且已同意时可提交一次求助并显示受控回应', (tester) async {
    await _setTallSurface(tester);
    final harness = (await tester.runAsync<_Harness>(
      () => _Harness.create(
        accountSeedSnapshot: AccountLocalSnapshot(
          consentState: AccountConsentState.acceptedPendingSync,
          session: _jwtSession(),
          lastSyncPhase: 'batch_ack_applied',
        ),
        mentorSuggestionResult: const LocalMentorSuggestionService().derive(
          const LocalMentorSuggestionContext(
            contextFallbackUsed: true,
            fallbackReasonCode: 'onboarding_missing',
          ),
        ),
        chatResponse: MentorChatResponse(
          correlationId: 'corr_widget_success',
          responseText: '先抱近一点，只说一句：I\'m here with you.',
          code: 'ok',
          phase: 'response_delivered',
          retryable: false,
          fallbackUsed: false,
          authenticated: true,
          rateLimit: const MentorRateLimitStatus(
            limited: false,
            limit: 3,
            remaining: 2,
            windowSeconds: 600,
          ),
          respondedAt: DateTime.utc(2026, 4, 10, 0),
        ),
      ),
    ))!;
    addTearDown(() => _disposeHarness(tester, harness));

    await tester.runAsync(() async {
      await Future.wait([
        harness.accountNotifier.initialize(),
        harness.practiceSessionNotifier.initialize(),
      ]);
    });

    await tester.pumpWidget(harness.buildStandaloneHome());
    await _pumpUntilFound(tester, find.byKey(const Key('home-mentor-fab')));

    await tester.tap(find.byKey(const Key('home-mentor-fab')));
    await tester.pump();
    await _pumpUntilFound(tester, find.byKey(const Key('mentor-panel-sheet')));
    await tester.tap(find.byKey(const Key('mentor-tab-chat-button')));
    await _pumpUntilFound(tester, find.byKey(const Key('mentor-chat-tab')));
    await tester.scrollUntilVisible(
      find.byKey(const Key('mentor-chat-input')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('mentor-chat-input')),
      '宝宝一直哭，我现在该怎么说？',
    );
    await _pumpBriefly(tester);
    await tester.tap(find.byKey(const Key('mentor-chat-submit-button')));
    await tester.scrollUntilVisible(
      find.byKey(const Key('mentor-chat-response-card')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();

    expect(find.byKey(const Key('mentor-chat-response-card')), findsOneWidget);
    expect(find.byKey(const Key('mentor-chat-response-text')), findsOneWidget);
    expect(find.textContaining('I\'m here with you.'), findsOneWidget);
    expect(
      harness.mentorRepository.appendedFacts.map((fact) => fact.eventType),
      containsAll([
        MentorFactType.chatRequested,
        MentorFactType.chatResponseDelivered,
      ]),
    );
  });
}

Future<void> _setTallSurface(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(800, 1400);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _disposeHarness(WidgetTester tester, _Harness harness) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump(const Duration(seconds: 5));
  // HomeScreen starts native Isar work from post-frame callbacks. Alternate
  // the real and fake async queues so those transactions release the database
  // before the fixture closes and deletes it.
  for (var index = 0; index < 12; index++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
  }
  await harness.dispose();
}

Future<void> _pumpBriefly(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 80));
  await tester.pump(const Duration(milliseconds: 160));
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 50),
  Duration timeout = const Duration(seconds: 5),
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

AccountSession _jwtSession() {
  return AccountSession(
    accountId: 'account_widget',
    sessionId: 'session_widget',
    maskedPhoneNumber: '138****1234',
    createdAt: DateTime.utc(2026, 4, 10, 8),
    accessToken: 'access-widget',
    refreshToken: 'refresh-widget',
    tokenType: 'Cookie',
    accessTokenExpiresAt: DateTime.utc(2026, 4, 10, 8, 15),
    refreshTokenExpiresAt: DateTime.utc(2026, 4, 17, 8),
  );
}

class _Harness {
  _Harness({
    required this.tempDir,
    required this.assetPhraseService,
    required this.practiceRepository,
    required this.accountNotifier,
    required this.mentorRepository,
    required this.mentorNotifier,
    required this.practiceSessionNotifier,
    required this.gardenGrowthNotifier,
    required this.practiceContinuityNotifier,
  });

  final Directory tempDir;
  final AssetPhraseService assetPhraseService;
  final PracticeRepository practiceRepository;
  final AccountNotifier accountNotifier;
  final _RecordingMentorRepository mentorRepository;
  final MentorNotifier mentorNotifier;
  final PracticeSessionNotifier practiceSessionNotifier;
  final GardenGrowthNotifier gardenGrowthNotifier;
  final PracticeContinuityNotifier practiceContinuityNotifier;

  static Future<_Harness> create({
    required AccountLocalSnapshot accountSeedSnapshot,
    required LocalMentorSuggestionResult mentorSuggestionResult,
    MentorChatResponse? chatResponse,
    MentorApiException? chatError,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('mentor_shell_test_');
    final practiceLocalDataSource = await PracticeLocalDataSource.open(
      directory: tempDir.path,
      name: 'practice_${DateTime.now().microsecondsSinceEpoch}',
    );
    final assetPhraseService = AssetPhraseService(bundle: rootBundle);
    final practiceRepository = PracticeRepository(
      assetPhraseService: assetPhraseService,
      localDataSource: practiceLocalDataSource,
      installationIdService: _MemoryInstallationIdService(),
    );
    final accountNotifier = AccountNotifier(
      repository: _StaticAccountRepository(seedSnapshot: accountSeedSnapshot),
    );
    final mentorRepository = _RecordingMentorRepository(
      deriveResult: mentorSuggestionResult,
    );
    final mentorNotifier = MentorNotifier(
      repository: mentorRepository,
      accountNotifier: accountNotifier,
      apiService: _FakeMentorApiService(
        response: chatResponse,
        error: chatError,
      ),
      audioController: _SilentMentorAudioController(),
    );
    final practiceSessionNotifier = PracticeSessionNotifier(
      repository: practiceRepository,
      spaceId: 'daily_care',
      activityId: 'bath_time',
      audioController: _SilentPracticeAudioController(),
    );
    final gardenGrowthRepo = GardenGrowthRepository(
      practiceRepository: practiceRepository,
      assetPhraseService: assetPhraseService,
    );
    final gardenGrowthNotifier = GardenGrowthNotifier(
      repository: gardenGrowthRepo,
    );
    final practiceContinuityNotifier = PracticeContinuityNotifier(
      repository: practiceRepository,
      initialStarterArgs: const PracticeRouteArgs(
        spaceId: 'daily_care',
        activityId: 'bath_time',
      ),
    );

    return _Harness(
      tempDir: tempDir,
      assetPhraseService: assetPhraseService,
      practiceRepository: practiceRepository,
      accountNotifier: accountNotifier,
      mentorRepository: mentorRepository,
      mentorNotifier: mentorNotifier,
      practiceSessionNotifier: practiceSessionNotifier,
      gardenGrowthNotifier: gardenGrowthNotifier,
      practiceContinuityNotifier: practiceContinuityNotifier,
    );
  }

  Widget buildShell() {
    final riverpodOverrides = <Override>[
      assetPhraseServiceProvider.overrideWithValue(assetPhraseService),
      practiceRepositoryProvider.overrideWith((ref) => practiceRepository),
      accountNotifierProvider.overrideWith((ref) => accountNotifier),
      mentorRepositoryProvider.overrideWith((ref) async => mentorRepository),
      mentorNotifierProvider.overrideWith((ref) => mentorNotifier),
      gardenGrowthNotifierProvider.overrideWith((ref) => gardenGrowthNotifier),
      practiceContinuityNotifierProvider.overrideWith(
        (ref) => practiceContinuityNotifier,
      ),
      householdNotifierProvider.overrideWith(
        (ref) => HouseholdNotifier(
          repository: _FakeHouseholdRepository(
            loadSnapshotResult: const HouseholdLocalSnapshot(lastPhase: 'idle'),
          ),
        ),
      ),
      shareNotifierProvider.overrideWith(
        (ref) => ShareNotifier(
          repository: ShareRepository(
            apiService: _FakeShareApiService(),
            shareSheetLauncher: _StaticShareSheetLauncher(),
            platformHintResolver: () => 'android',
          ),
          initialGrowthSnapshot: ref
              .watch(gardenGrowthNotifierProvider)
              .snapshot,
          initialContinuitySnapshot: null,
        ),
      ),
    ];
    return ProviderScope(
      overrides: riverpodOverrides,
      child: MaterialApp(
        theme: AppTheme.build(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppShellScreen(
          onboardingSnapshot: OnboardingSnapshot(
            childDisplayName: '米米',
            ageBucket: OnboardingAgeBucket.oneToTwo,
            approxMonths: 15,
            currentStage: 'gesture_plus_words',
            starterSpaceId: 'daily_care',
            starterActivityId: 'bath_time',
            starterPhraseId: 'bath_time_warm_water',
            consentState: OnboardingConsentState.localOnly,
            completedAt: DateTime.utc(2026, 4, 8, 8),
          ),
        ),
      ),
    );
  }

  Widget buildStandaloneHome() {
    final riverpodOverrides = <Override>[
      assetPhraseServiceProvider.overrideWithValue(assetPhraseService),
      practiceRepositoryProvider.overrideWith((ref) => practiceRepository),
      accountNotifierProvider.overrideWith((ref) => accountNotifier),
      mentorRepositoryProvider.overrideWith((ref) async => mentorRepository),
      mentorNotifierProvider.overrideWith((ref) => mentorNotifier),
      gardenGrowthNotifierProvider.overrideWith((ref) => gardenGrowthNotifier),
      practiceContinuityNotifierProvider.overrideWith(
        (ref) => practiceContinuityNotifier,
      ),
      householdNotifierProvider.overrideWith(
        (ref) => HouseholdNotifier(
          repository: _FakeHouseholdRepository(
            loadSnapshotResult: const HouseholdLocalSnapshot(lastPhase: 'idle'),
          ),
        ),
      ),
      shareNotifierProvider.overrideWith(
        (ref) => ShareNotifier(
          repository: ShareRepository(
            apiService: _FakeShareApiService(),
            shareSheetLauncher: _StaticShareSheetLauncher(),
            platformHintResolver: () => 'android',
          ),
          initialGrowthSnapshot: ref
              .watch(gardenGrowthNotifierProvider)
              .snapshot,
          initialContinuitySnapshot: null,
        ),
      ),
    ];
    return ProviderScope(
      overrides: riverpodOverrides,
      child: MaterialApp(
        theme: AppTheme.build(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const HomeScreen(embeddedInShell: false),
      ),
    );
  }

  Future<void> dispose() async {
    // Riverpod / Provider automatically disposes the notifiers when the widget tree is torn down.
    // Calling dispose again will trigger debugAssertNotDisposed.
    await practiceRepository.close(deleteFromDisk: true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (await tempDir.exists()) {
      await _deleteDirectoryWithRetry(tempDir);
    }
  }
}

class _MemoryInstallationIdService extends InstallationIdService {
  _MemoryInstallationIdService()
    : super(directoryResolver: () async => Directory.systemTemp);

  String? _installationId = 'install_mentor_shell_test';

  @override
  Future<String> getOrCreate() async {
    return _installationId ??= 'install_mentor_shell_test';
  }

  @override
  Future<String?> readExisting() async => _installationId;

  @override
  Future<void> deleteIfExists() async {
    _installationId = null;
  }
}

Future<void> _deleteDirectoryWithRetry(
  Directory directory, {
  int attempts = 50,
  Duration delay = const Duration(milliseconds: 100),
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    try {
      if (!await directory.exists()) {
        return;
      }
      await directory.delete(recursive: true);
      return;
    } on PathAccessException {
      if (attempt == attempts - 1) {
        rethrow;
      }
      await Future<void>.delayed(delay);
    }
  }
}

class _RecordingMentorRepository implements MentorRepository {
  _RecordingMentorRepository({required this.deriveResult});

  final LocalMentorSuggestionResult deriveResult;
  final List<MentorFactEvent> appendedFacts = <MentorFactEvent>[];

  @override
  Future<MentorFactEvent> appendFact({
    required MentorFactType eventType,
    required String phase,
    DateTime? createdAt,
    String? localEventId,
    String? correlationId,
    String? redactedSummary,
    String? visibleStatus,
    String? visibleDetail,
    bool retryable = false,
    bool contextFallbackUsed = false,
  }) async {
    final fact = MentorFactEvent(
      localEventId: localEventId ?? 'fact_${appendedFacts.length}',
      installationId: 'install_widget_test',
      eventType: eventType,
      phase: phase,
      createdAt:
          createdAt ?? DateTime.utc(2026, 4, 9, 8, 0, appendedFacts.length),
      correlationId: correlationId,
      redactedSummary: redactedSummary,
      visibleStatus: visibleStatus,
      visibleDetail: visibleDetail,
      retryable: retryable,
      contextFallbackUsed: contextFallbackUsed,
    );
    appendedFacts.add(fact);
    return fact;
  }

  @override
  Future<LocalMentorSuggestionResult> deriveLocalSuggestions() async {
    return deriveResult;
  }

  @override
  Future<void> close({bool deleteFromDisk = false}) async {}

  @override
  Future<String> ensureInstallationId() async => 'install_widget_test';

  @override
  Future<MentorFactInspection> inspectFactLog() async {
    return MentorFactInspection(
      installationId: 'install_widget_test',
      storedFactCount: appendedFacts.length,
      validFacts: List<MentorFactEvent>.unmodifiable(appendedFacts),
      skippedFactCount: 0,
    );
  }

  @override
  Future<List<MentorFactEvent>> listFactHistory({
    MentorFactType? eventType,
    int? limit,
  }) async {
    final filtered = eventType == null
        ? appendedFacts
        : appendedFacts.where((fact) => fact.eventType == eventType).toList();
    return List<MentorFactEvent>.unmodifiable(filtered);
  }

  @override
  Future<String?> readExistingInstallationId() async => 'install_widget_test';
}

class _StaticAccountRepository implements AccountRepository {
  _StaticAccountRepository({required this.seedSnapshot});

  final AccountLocalSnapshot seedSnapshot;

  @override
  final String consentVersion = 'pipl-v1';

  @override
  Future<AccountLocalSnapshot> loadSnapshot() async => seedSnapshot;

  @override
  Future<AccountLocalSnapshot> signIn({
    required String phoneNumber,
    required String verificationCode,
  }) async => seedSnapshot;

  @override
  Future<AccountLocalSnapshot> savePlaceholderSession({
    required String phoneNumber,
    required String verificationCode,
  }) async => seedSnapshot;

  @override
  Future<AccountLocalSnapshot> refreshRuntimeState({
    required AccountRuntimeTrigger trigger,
    AccountLocalSnapshot? seedSnapshot,
    bool forceBootstrap = false,
  }) async => seedSnapshot ?? this.seedSnapshot;

  @override
  Future<AccountLocalSnapshot> clearPlaceholderSession({
    bool revertToLocalOnly = false,
  }) async => seedSnapshot;

  @override
  Future<AccountLocalSnapshot> revokeConsent({
    String reason = 'user_requested',
  }) async => seedSnapshot;

  @override
  Future<AccountLocalSnapshot> deleteAccount({
    String reason = 'forget_me',
  }) async => seedSnapshot;

  @override
  Future<AccountSession> persistRefreshedSession(
    AccountSession refreshedSession,
  ) async => refreshedSession;

  @override
  Future<void> deleteLocalSnapshotForLifecycle() async {}

  @override
  Future<void> close() async {}
}

class _SilentPracticeAudioController implements PracticeAudioController {
  @override
  Stream<void> get completionStream => const Stream<void>.empty();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> playAsset(String assetPath) async {}

  @override
  Future<void> stop() async {}
}

class _FakeMentorApiService extends MentorApiService {
  _FakeMentorApiService({this.response, this.error})
    : super(baseUrl: 'http://localhost:8080');

  final MentorChatResponse? response;
  final MentorApiException? error;

  @override
  Future<MentorChatResponse> sendChat({
    required String installationId,
    required String prompt,
    required String surface,
    required String mode,
    required String correlationId,
    AccountSession? session,
    Future<AccountSession> Function(AccountSession refreshedSession)?
    persistRefreshedSession,
    String? contextSummary,
    String? conversationId,
  }) async {
    if (error != null) {
      throw error!;
    }
    return response ??
        MentorChatResponse(
          correlationId: correlationId,
          responseText: '先把语速放慢，说一句：I\'m here with you.',
          code: 'ok',
          phase: 'response_delivered',
          retryable: false,
          fallbackUsed: false,
          authenticated: session != null,
          rateLimit: const MentorRateLimitStatus(
            limited: false,
            limit: 3,
            remaining: 2,
            windowSeconds: 600,
          ),
          respondedAt: DateTime.utc(2026, 4, 10, 0),
        );
  }

  @override
  Future<void> close() async {}
}

class _SilentMentorAudioController implements MentorAudioController {
  @override
  Future<void> dispose() async {}

  @override
  Future<bool> ensureAvailable() async => true;

  @override
  Future<void> speakText(String text) async {}

  @override
  Future<void> stop() async {}
}

class _FakeHouseholdRepository implements HouseholdRepository {
  _FakeHouseholdRepository({required this.loadSnapshotResult});

  HouseholdLocalSnapshot loadSnapshotResult;

  @override
  Future<HouseholdCreateInviteResult> createInvite({
    HouseholdRole role = HouseholdRole.caregiver,
    String source = 'household_settings',
  }) async {
    return const HouseholdCreateInviteResult(
      snapshot: HouseholdLocalSnapshot(
        lastPhase: 'create_invite_unavailable',
        lastVisibleError: '邀请服务暂时不可用，请稍后重试。',
      ),
      message: '邀请服务暂时不可用，请稍后重试。',
    );
  }

  @override
  Future<HouseholdInviteAcceptResult> acceptInvite({
    required String token,
    required String source,
  }) async {
    return const HouseholdInviteAcceptResult(
      snapshot: HouseholdLocalSnapshot(
        lastPhase: 'accept_invite_unavailable',
        lastVisibleError: '邀请服务暂时不可用，请稍后重试。',
      ),
      message: '邀请服务暂时不可用，请稍后重试。',
    );
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> deleteLocalSnapshotForLifecycle() async {}

  @override
  Future<HouseholdLocalSnapshot> loadSnapshot() async => loadSnapshotResult;

  @override
  Future<HouseholdLocalSnapshot> refreshSharedContext({
    String reason = 'manual_refresh',
  }) async {
    return loadSnapshotResult;
  }

  @override
  Future<HouseholdRevokeInviteResult> revokeInvite({
    required String token,
    String source = 'household_settings',
  }) async {
    return const HouseholdRevokeInviteResult(
      snapshot: HouseholdLocalSnapshot(lastPhase: 'revoke_invite_revoked'),
      message: '邀请已撤销。',
      applied: true,
    );
  }
}

class _FakeShareApiService extends ShareApiService {
  _FakeShareApiService() : super(baseUrl: 'http://localhost:8080');

  @override
  Future<ShareCreateLinkResponse> createShareLink({
    required ShareLinkDraft draft,
    String? platformHint,
  }) async {
    return ShareCreateLinkResponse(
      token: 'share_token',
      shareUrl: 'https://share.example.com/share/share_token',
      expiresAt: DateTime.utc(2026, 4, 16, 12),
    );
  }

  @override
  Future<void> close() async {}
}

class _StaticShareSheetLauncher implements ShareSheetLauncher {
  @override
  Future<ShareSheetLaunchResult> shareText(
    String text, {
    String? subject,
  }) async {
    return const ShareSheetLaunchResult(status: ShareSheetLaunchStatus.success);
  }
}
