import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/account/presentation/account_view_model.dart';
import 'package:mobile/features/mentor/data/repositories/mentor_repository.dart';
import 'package:mobile/features/mentor/data/services/mentor_api_service.dart';
import 'package:mobile/features/mentor/domain/models/local_mentor_suggestion.dart';
import 'package:mobile/features/mentor/domain/models/mentor_fact_event.dart';
import 'package:mobile/features/mentor/domain/services/local_mentor_suggestion_service.dart';
import 'package:mobile/features/mentor/presentation/mentor_audio_controller.dart';
import 'package:mobile/features/mentor/presentation/mentor_view_model.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/practice_session_view_model.dart';
import 'package:mobile/features/practice/presentation/screens/home_screen.dart';
import 'package:mobile/features/shell/presentation/app_shell_screen.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): _resolveBundledIsarLibraryPath()},
    );
  });

  testWidgets('shell 任一 tab 的全局 FAB 会打开默认建议 tab，并明确展示离线降级', (tester) async {
    final harness = await _Harness.create(
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
        lastVisibleError: '当前离线，已保留本地待同步事件，可稍后重试。',
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
        redactedContextSummary: 'starter_phrase:bath_time/bath_time_warm_water',
      ),
    );
    addTearDown(harness.dispose);

    await tester.runAsync(() async {
      await Future.wait([
        harness.accountViewModel.initialize(),
        harness.practiceSessionViewModel.initialize(),
      ]);
    });

    await tester.pumpWidget(harness.buildShell());
    await _pumpBriefly(tester);
    await tester.tap(find.byTooltip('发现'));
    await _pumpBriefly(tester);

    await tester.tap(find.byKey(const Key('shell-mentor-fab')));
    await tester.pump();
    await _pumpBriefly(tester);

    expect(find.byKey(const Key('mentor-panel-sheet')), findsOneWidget);
    expect(find.byKey(const Key('mentor-suggestion-tab')), findsOneWidget);
    expect(find.byKey(const Key('mentor-chat-tab')), findsNothing);
    expect(find.byKey(const Key('mentor-panel-banner')), findsOneWidget);
    expect(find.textContaining('离线'), findsWidgets);

    await tester.tap(find.byKey(const Key('mentor-tab-chat-button')));
    await _pumpBriefly(tester);

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

  testWidgets('standalone home 小 FAB 在缺失 onboarding 时仍打开同一 Mentor 面板并回退通用建议', (
    tester,
  ) async {
    final harness = await _Harness.create(
      accountSeedSnapshot: AccountLocalSnapshot.signedOut,
      mentorSuggestionResult: const LocalMentorSuggestionService().derive(
        const LocalMentorSuggestionContext(
          contextFallbackUsed: true,
          fallbackReasonCode: 'onboarding_missing',
        ),
      ),
    );
    addTearDown(harness.dispose);

    await tester.runAsync(() async {
      await Future.wait([
        harness.accountViewModel.initialize(),
        harness.practiceSessionViewModel.initialize(),
      ]);
    });

    await tester.pumpWidget(harness.buildStandaloneHome());
    await _pumpBriefly(tester);

    await tester.tap(find.byKey(const Key('home-mentor-fab')));
    await tester.pump();
    await _pumpBriefly(tester);

    expect(find.byKey(const Key('mentor-panel-sheet')), findsOneWidget);
    expect(find.byKey(const Key('mentor-suggestion-tab')), findsOneWidget);
    expect(
      find.byKey(const Key('mentor-suggestion-card-safe_small_step')),
      findsOneWidget,
    );
    expect(find.textContaining('还没读到 onboarding 档案'), findsOneWidget);
  });

  testWidgets('chat tab 可提交一次匿名求助并显示受控回应', (tester) async {
    final harness = await _Harness.create(
      accountSeedSnapshot: AccountLocalSnapshot.signedOut,
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
        authenticated: false,
        rateLimit: const MentorRateLimitStatus(
          limited: false,
          limit: 3,
          remaining: 2,
          windowSeconds: 600,
        ),
        respondedAt: DateTime.utc(2026, 4, 10, 0),
      ),
    );
    addTearDown(harness.dispose);

    await tester.runAsync(() async {
      await Future.wait([
        harness.accountViewModel.initialize(),
        harness.practiceSessionViewModel.initialize(),
      ]);
    });

    await tester.pumpWidget(harness.buildStandaloneHome());
    await _pumpBriefly(tester);

    await tester.tap(find.byKey(const Key('home-mentor-fab')));
    await tester.pump();
    await _pumpBriefly(tester);
    await tester.tap(find.byKey(const Key('mentor-tab-chat-button')));
    await _pumpBriefly(tester);

    await tester.enterText(
      find.byKey(const Key('mentor-chat-input')),
      '宝宝一直哭，我现在该怎么说？',
    );
    await _pumpBriefly(tester);
    await tester.tap(find.byKey(const Key('mentor-chat-submit-button')));
    await _pumpBriefly(tester);

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

Future<void> _pumpBriefly(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 80));
  await tester.pump(const Duration(milliseconds: 160));
}

class _Harness {
  _Harness({
    required this.tempDir,
    required this.practiceRepository,
    required this.accountViewModel,
    required this.mentorRepository,
    required this.mentorViewModel,
    required this.practiceSessionViewModel,
  });

  final Directory tempDir;
  final PracticeRepository practiceRepository;
  final AccountViewModel accountViewModel;
  final _RecordingMentorRepository mentorRepository;
  final MentorViewModel mentorViewModel;
  final PracticeSessionViewModel practiceSessionViewModel;

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
    final practiceRepository = PracticeRepository(
      assetPhraseService: AssetPhraseService(bundle: rootBundle),
      localDataSource: practiceLocalDataSource,
      installationIdService: InstallationIdService(
        directoryResolver: () async => tempDir,
        idGenerator: () => 'install_mentor_shell_test',
      ),
    );
    final accountViewModel = AccountViewModel(
      repository: _StaticAccountRepository(seedSnapshot: accountSeedSnapshot),
    );
    final mentorRepository = _RecordingMentorRepository(
      deriveResult: mentorSuggestionResult,
    );
    final mentorViewModel = MentorViewModel(
      repository: mentorRepository,
      accountViewModel: accountViewModel,
      apiService: _FakeMentorApiService(
        response: chatResponse,
        error: chatError,
      ),
      audioController: _SilentMentorAudioController(),
    );
    final practiceSessionViewModel = PracticeSessionViewModel(
      repository: practiceRepository,
      spaceId: 'daily_care',
      activityId: 'bath_time',
      audioController: _SilentPracticeAudioController(),
    );

    return _Harness(
      tempDir: tempDir,
      practiceRepository: practiceRepository,
      accountViewModel: accountViewModel,
      mentorRepository: mentorRepository,
      mentorViewModel: mentorViewModel,
      practiceSessionViewModel: practiceSessionViewModel,
    );
  }

  Widget buildShell() {
    return MultiProvider(
      providers: [
        Provider<PracticeRepository>.value(value: practiceRepository),
        Provider<MentorRepository>.value(value: mentorRepository),
        Provider<PracticeRouteArgs>.value(
          value: const PracticeRouteArgs(
            spaceId: 'daily_care',
            activityId: 'bath_time',
          ),
        ),
        ChangeNotifierProvider<AccountViewModel>.value(value: accountViewModel),
        ChangeNotifierProvider<MentorViewModel>.value(value: mentorViewModel),
        ChangeNotifierProvider<PracticeSessionViewModel>.value(
          value: practiceSessionViewModel,
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.build(),
        home: AppShellScreen(
          onboardingSnapshot: OnboardingSnapshot(
            childDisplayName: '米米',
            ageBucket: OnboardingAgeBucket.twelveToEighteen,
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
    return MultiProvider(
      providers: [
        Provider<PracticeRepository>.value(value: practiceRepository),
        Provider<MentorRepository>.value(value: mentorRepository),
        Provider<PracticeRouteArgs>.value(
          value: const PracticeRouteArgs(
            spaceId: 'daily_care',
            activityId: 'bath_time',
          ),
        ),
        ChangeNotifierProvider<AccountViewModel>.value(value: accountViewModel),
        ChangeNotifierProvider<MentorViewModel>.value(value: mentorViewModel),
        ChangeNotifierProvider<PracticeSessionViewModel>.value(
          value: practiceSessionViewModel,
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.build(),
        home: const HomeScreen(embeddedInShell: false),
      ),
    );
  }

  Future<void> dispose() async {
    mentorViewModel.dispose();
    accountViewModel.dispose();
    practiceSessionViewModel.dispose();
    await practiceRepository.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
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
    : super(baseUri: Uri.parse('http://localhost:8080'));

  final MentorChatResponse? response;
  final MentorApiException? error;

  @override
  Future<MentorChatResponse> sendChat({
    required String installationId,
    required String prompt,
    required String surface,
    required String mode,
    required String correlationId,
    String? sessionId,
    String? contextSummary,
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
          authenticated: sessionId != null,
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

String _resolveBundledIsarLibraryPath() {
  final pubCacheRoot = Platform.environment['PUB_CACHE'];
  final localAppData = Platform.environment['LOCALAPPDATA'];
  final candidateRoots = <Directory>[
    if (pubCacheRoot != null) Directory(pubCacheRoot),
    if (localAppData != null) Directory('$localAppData\\Pub\\Cache'),
  ];

  for (final root in candidateRoots) {
    final hostedDirectory = Directory(
      '${root.path}${Platform.pathSeparator}hosted',
    );
    if (!hostedDirectory.existsSync()) {
      continue;
    }

    for (final host in hostedDirectory.listSync().whereType<Directory>()) {
      for (final packageDir in host.listSync().whereType<Directory>()) {
        final packageName = packageDir.path.split(RegExp(r'[\\/]')).last;
        if (!packageName.startsWith('isar_flutter_libs-')) {
          continue;
        }

        final dll = File(
          '${packageDir.path}${Platform.pathSeparator}windows${Platform.pathSeparator}isar.dll',
        );
        if (dll.existsSync()) {
          return dll.path;
        }
      }
    }
  }

  throw StateError('未在 pub cache 中找到 isar_flutter_libs/windows/isar.dll');
}
