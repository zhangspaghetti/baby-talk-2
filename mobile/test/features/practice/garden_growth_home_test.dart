import 'dart:async';
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
import 'package:mobile/features/account/presentation/account_view_model.dart';
import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/data/repositories/household_repository.dart';
import 'package:mobile/features/household/domain/models/household_role.dart';
import 'package:mobile/features/household/domain/models/household_shared_context.dart';
import 'package:mobile/features/household/presentation/household_view_model.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/garden_growth_repository.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/presentation/garden_growth_view_model.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_view_model.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/practice_session_view_model.dart';
import 'package:mobile/features/practice/presentation/screens/home_screen.dart';
import 'package:mobile/features/share/data/repositories/share_repository.dart';
import 'package:mobile/features/share/data/services/share_api_service.dart';
import 'package:mobile/features/share/data/services/share_sheet_launcher.dart';
import 'package:mobile/features/share/domain/models/share_link_draft.dart';
import 'package:mobile/features/share/presentation/share_view_model.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): _resolveBundledIsarLibraryPath()},
    );
  });

  testWidgets('首页在零事件时显示花园入口空态与成长摘要空态', (tester) async {
    final harness = (await tester.runAsync<_Harness>(_Harness.create))!;
    addTearDown(harness.dispose);

    await tester.runAsync(() async {
      await Future.wait([
        harness.accountViewModel.initialize(),
        harness.practiceSessionViewModel.initialize(),
        harness.gardenGrowthViewModel.initialize(),
      ]);
    });

    await tester.pumpWidget(harness.buildApp());
    await _pumpUntilHomeLoaded(tester);
    await _scrollHomeUntilVisible(
      tester,
      find.byKey(const Key('home-continuity-fallback-banner')),
    );

    expect(
      find.byKey(const Key('home-continuity-fallback-banner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-hero-activity-bath_time')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-cadence-summary-bath_time')),
      findsOneWidget,
    );

    await _scrollHomeUntilVisible(
      tester,
      find.byKey(const Key('home-garden-mini-entry')),
    );
    await _scrollHomeUntilVisible(
      tester,
      find.byKey(const Key('home-growth-summary')),
    );

    expect(find.byKey(const Key('home-garden-mini-entry')), findsOneWidget);
    expect(find.byKey(const Key('home-growth-summary')), findsOneWidget);
    expect(find.textContaining('你的花园会从第一句开口开始'), findsOneWidget);
    expect(find.textContaining('最近成长会写在这里'), findsOneWidget);
  });

  testWidgets('首页消费同一份投影并显示最近成长摘要与降级提示', (tester) async {
    final harness = (await tester.runAsync<_Harness>(_Harness.create))!;
    addTearDown(harness.dispose);
    await tester.runAsync(() async {
      await harness.practiceRepository.recordReaction(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'bath_time_warm_water',
        reactionType: BabyReactionType.engaged,
        clientTimestamp: DateTime.utc(2026, 4, 9, 9, 0),
        localEventId: 'evt_home_1',
      );
      await harness.practiceRepository.importServerEvents([
        InteractionEventPayload.fromWire(
          eventKey: 'install_garden_home_test:evt_unknown_1',
          localEventId: 'evt_unknown_1',
          installationId: 'install_garden_home_test',
          spaceId: 'daily_care',
          activityId: 'bath_time',
          phraseId: 'bath_time_unknown',
          reactionType: 'calm',
          clientTimestamp: DateTime.utc(2026, 4, 9, 9, 1),
        ),
      ]);
    });

    await tester.runAsync(() async {
      await Future.wait([
        harness.accountViewModel.initialize(),
        harness.practiceSessionViewModel.initialize(),
        harness.gardenGrowthViewModel.refresh(),
      ]);
    });

    await tester.pumpWidget(harness.buildApp());
    await _pumpUntilHomeLoaded(tester);
    await _scrollHomeUntilVisible(
      tester,
      find.byKey(const Key('home-garden-mini-entry')),
    );
    await _scrollHomeUntilVisible(
      tester,
      find.byKey(const Key('home-growth-summary')),
    );

    expect(find.byKey(const Key('home-garden-mini-entry')), findsOneWidget);
    expect(find.textContaining('日常照护'), findsWidgets);
    expect(find.byKey(const Key('home-growth-summary')), findsOneWidget);
    expect(find.textContaining('Warm water.'), findsWidgets);
    expect(
      find.byKey(const Key('home-growth-summary-warning')),
      findsOneWidget,
    );
    expect(find.textContaining('未知内容事件'), findsWidgets);
  });

  testWidgets('首页优先显示最近 activity，而不是固定 starter provider', (tester) async {
    final harness = (await tester.runAsync<_Harness>(_Harness.create))!;
    addTearDown(harness.dispose);

    await tester.runAsync(() async {
      await harness.practiceRepository.recordReaction(
        spaceId: 'family_rhythm',
        activityId: 'feeding_time',
        phraseId: 'feeding_time_open_wide',
        reactionType: BabyReactionType.calm,
        clientTimestamp: DateTime.utc(2026, 4, 9, 9, 2),
        localEventId: 'evt_home_feed_1',
      );
      await harness.practiceRepository.recordReaction(
        spaceId: 'family_rhythm',
        activityId: 'feeding_time',
        phraseId: 'feeding_time_yummy_bite',
        reactionType: BabyReactionType.imitated,
        clientTimestamp: DateTime.utc(2026, 4, 9, 9, 3),
        localEventId: 'evt_home_feed_2',
      );
      await Future.wait([
        harness.accountViewModel.initialize(),
        harness.practiceSessionViewModel.initialize(),
        harness.gardenGrowthViewModel.refresh(),
      ]);
    });

    await tester.pumpWidget(
      harness.buildApp(
        practiceArgs: const PracticeRouteArgs(
          spaceId: 'daily_care',
          activityId: 'bath_time',
        ),
      ),
    );
    await _pumpUntilHomeLoaded(tester);
    await _scrollHomeUntilVisible(
      tester,
      find.byKey(const ValueKey('home-start-practice-feeding_time')),
    );

    expect(
      find.byKey(const ValueKey('home-start-practice-feeding_time')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-continuity-reason-feeding_time')),
      findsOneWidget,
    );

    await _scrollHomeUntilVisible(
      tester,
      find.byKey(const ValueKey('recent-result-summary-feeding_time')),
    );

    expect(
      find.byKey(const ValueKey('recent-result-summary-feeding_time')),
      findsOneWidget,
    );
    expect(find.textContaining('吃饭时间'), findsWidgets);
    expect(find.textContaining('Yummy bite.'), findsWidgets);
  });

  testWidgets('首页优先消费 household shared context 的 practice args，并显示共享照护摘要', (
    tester,
  ) async {
    final harness = (await tester.runAsync<_Harness>(_Harness.create))!;
    addTearDown(harness.dispose);
    final householdViewModel = HouseholdViewModel(
      repository: _FakeHouseholdRepository(
        loadSnapshotResult: HouseholdLocalSnapshot(
          householdId: 'household_1',
          role: HouseholdRole.caregiver,
          sharedContext: _sharedContext(
            const PracticeRouteArgs(
              spaceId: 'family_rhythm',
              activityId: 'feeding_time',
            ),
          ),
          lastPhase: 'shared_context_ready',
          lastAcceptedAt: DateTime.utc(2026, 4, 16, 12),
        ),
      ),
    );
    addTearDown(householdViewModel.dispose);

    await tester.runAsync(() async {
      await harness.practiceRepository.recordReaction(
        spaceId: 'family_rhythm',
        activityId: 'feeding_time',
        phraseId: 'feeding_time_open_wide',
        reactionType: BabyReactionType.calm,
        clientTimestamp: DateTime.utc(2026, 4, 9, 9, 2),
        localEventId: 'evt_home_household_1',
      );
      await harness.practiceRepository.recordReaction(
        spaceId: 'family_rhythm',
        activityId: 'feeding_time',
        phraseId: 'feeding_time_yummy_bite',
        reactionType: BabyReactionType.imitated,
        clientTimestamp: DateTime.utc(2026, 4, 9, 9, 3),
        localEventId: 'evt_home_household_2',
      );
      await Future.wait([
        householdViewModel.initialize(),
        harness.accountViewModel.initialize(),
        harness.practiceSessionViewModel.initialize(),
        harness.gardenGrowthViewModel.refresh(),
      ]);
    });

    await tester.pumpWidget(
      harness.buildApp(
        practiceArgs: const PracticeRouteArgs(
          spaceId: 'daily_care',
          activityId: 'bath_time',
        ),
        householdViewModel: householdViewModel,
      ),
    );
    await _pumpUntilHomeLoaded(tester);
    await _scrollHomeUntilVisible(
      tester,
      find.byKey(const Key('home-household-profile-summary')),
    );

    expect(
      find.byKey(const Key('home-household-profile-summary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('home-household-continuity-summary')),
      findsOneWidget,
    );
    expect(find.textContaining('共享宝宝档案'), findsWidgets);
    expect(find.byKey(const Key('home-shared-overlay-card')), findsOneWidget);
    expect(find.byKey(const Key('home-shared-overlay-button')), findsOneWidget);

    await _scrollHomeUntilVisible(
      tester,
      find.byKey(const ValueKey('home-start-practice-feeding_time')),
    );

    expect(
      find.byKey(const ValueKey('home-start-practice-feeding_time')),
      findsOneWidget,
    );
    expect(find.textContaining('吃饭时间'), findsWidgets);
  });

  testWidgets('首页在坏 starter context 下显示 warning 并回退到安全 activity', (
    tester,
  ) async {
    final harness = (await tester.runAsync<_Harness>(_Harness.create))!;
    addTearDown(harness.dispose);

    await tester.runAsync(() async {
      await Future.wait([
        harness.accountViewModel.initialize(),
        harness.practiceSessionViewModel.initialize(),
        harness.gardenGrowthViewModel.initialize(),
      ]);
    });

    await tester.pumpWidget(
      harness.buildApp(
        practiceArgs: const PracticeRouteArgs(
          spaceId: 'daily_care',
          activityId: 'missing_activity',
        ),
      ),
    );
    await _pumpUntilHomeLoaded(tester);
    await _scrollHomeUntilVisible(
      tester,
      find.byKey(const Key('home-continuity-warning-banner')),
    );

    expect(
      find.byKey(const Key('home-continuity-warning-banner')),
      findsOneWidget,
    );
    expect(find.textContaining('starter activity 不存在'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-hero-activity-bath_time')),
      findsOneWidget,
    );
  });

  testWidgets('首页在 continuity provider 缺失时显示安全空态，不回退默认 activity', (
    tester,
  ) async {
    final harness = (await tester.runAsync<_Harness>(_Harness.create))!;
    addTearDown(harness.dispose);

    await tester.runAsync(() async {
      await Future.wait([
        harness.accountViewModel.initialize(),
        harness.practiceSessionViewModel.initialize(),
        harness.gardenGrowthViewModel.initialize(),
      ]);
    });

    await tester.pumpWidget(harness.buildApp(includeContinuityProvider: false));
    await _pumpUntilHomeLoaded(tester);
    await _scrollHomeUntilVisible(
      tester,
      find.byKey(const Key('home-continuity-provider-missing-banner')),
    );

    expect(
      find.byKey(const Key('home-continuity-provider-missing-banner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-hero-activity-safe-empty')),
      findsOneWidget,
    );
    expect(find.textContaining('不会回退到默认 activity'), findsWidgets);
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const ValueKey('home-start-practice-safe-empty')),
          )
          .onPressed,
      isNull,
    );
    expect(find.byKey(const Key('home-share-card')), findsNothing);
  });

  testWidgets('首页分享 CTA 会显示 disabled 状态，并在失败时保留可见错误', (tester) async {
    final disabledHarness = (await tester.runAsync<_Harness>(_Harness.create))!;
    addTearDown(disabledHarness.dispose);

    await tester.runAsync(() async {
      await Future.wait([
        disabledHarness.accountViewModel.initialize(),
        disabledHarness.practiceSessionViewModel.initialize(),
        disabledHarness.gardenGrowthViewModel.initialize(),
      ]);
    });

    final disabledRepository = ShareRepository(
      apiService: _FakeShareApiService(),
      shareSheetLauncher: _StaticShareSheetLauncher(),
      platformHintResolver: () => 'android',
    );

    await tester.pumpWidget(
      disabledHarness.buildApp(
        includeContinuityProvider: false,
        includeShareProvider: true,
        shareRepository: disabledRepository,
      ),
    );
    await _pumpUntilHomeLoaded(tester);
    await _scrollHomeUntilVisible(
      tester,
      find.byKey(const Key('home-share-card')),
    );

    expect(find.byKey(const Key('home-share-card')), findsOneWidget);
    expect(find.byKey(const Key('home-share-state-disabled')), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const Key('home-share-button')))
          .onPressed,
      isNull,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final failingHarness = (await tester.runAsync<_Harness>(_Harness.create))!;
    addTearDown(failingHarness.dispose);

    await tester.runAsync(() async {
      await failingHarness.practiceRepository.recordReaction(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'bath_time_warm_water',
        reactionType: BabyReactionType.engaged,
        clientTimestamp: DateTime.utc(2026, 4, 9, 9, 5),
        localEventId: 'evt_home_share_1',
      );
      await failingHarness.practiceRepository.importServerEvents([
        InteractionEventPayload.fromWire(
          eventKey: 'install_garden_home_test:evt_unknown_share',
          localEventId: 'evt_unknown_share',
          installationId: 'install_garden_home_test',
          spaceId: 'daily_care',
          activityId: 'bath_time',
          phraseId: 'bath_time_unknown',
          reactionType: 'calm',
          clientTimestamp: DateTime.utc(2026, 4, 9, 9, 6),
        ),
      ]);
      await Future.wait([
        failingHarness.accountViewModel.initialize(),
        failingHarness.practiceSessionViewModel.initialize(),
        failingHarness.gardenGrowthViewModel.refresh(),
      ]);
    });

    final pendingLauncher = _PendingShareSheetLauncher();
    final failingRepository = ShareRepository(
      apiService: _FakeShareApiService(),
      shareSheetLauncher: pendingLauncher,
      platformHintResolver: () => 'android',
    );

    await tester.pumpWidget(
      failingHarness.buildApp(
        includeShareProvider: true,
        shareRepository: failingRepository,
      ),
    );
    await _pumpUntilHomeLoaded(tester);
    await _scrollHomeUntilVisible(
      tester,
      find.byKey(const Key('home-share-card')),
    );

    expect(find.byKey(const Key('home-share-cta-visible')), findsOneWidget);
    expect(find.byKey(const Key('home-share-state-ready')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('home-share-card')),
        matching: find.textContaining('未知内容事件'),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('home-share-button')));
    await tester.pump();
    expect(find.byKey(const Key('home-share-state-loading')), findsOneWidget);

    pendingLauncher.complete(
      const ShareSheetLaunchResult(status: ShareSheetLaunchStatus.unavailable),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.byKey(const Key('home-share-state-error')), findsOneWidget);
    expect(find.textContaining('无法打开分享面板'), findsOneWidget);
  });
}

Future<void> _pumpUntilHomeLoaded(
  WidgetTester tester, {
  Duration step = const Duration(milliseconds: 50),
  Duration timeout = const Duration(seconds: 5),
}) async {
  final totalSteps = timeout.inMilliseconds ~/ step.inMilliseconds;
  for (var index = 0; index < totalSteps; index++) {
    await tester.pump(step);
    if (find.byKey(const Key('home-loading')).evaluate().isEmpty) {
      return;
    }
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    if (find.byKey(const Key('home-loading')).evaluate().isEmpty) {
      return;
    }
  }

  debugDumpApp();
  fail('Timed out waiting for home loading to finish.');
}

Future<void> _scrollHomeUntilVisible(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 180, scrollable: _homeScrollable());
  await tester.pump();
}

Finder _homeScrollable() {
  return find.descendant(
    of: find.byType(HomeScreen),
    matching: find.byType(Scrollable),
  );
}

class _Harness {
  _Harness({
    required this.tempDir,
    required this.localDataSource,
    required this.practiceRepository,
    required this.accountViewModel,
    required this.practiceSessionViewModel,
    required this.gardenGrowthViewModel,
  });

  final Directory tempDir;
  final PracticeLocalDataSource localDataSource;
  final PracticeRepository practiceRepository;
  final AccountViewModel accountViewModel;
  final PracticeSessionViewModel practiceSessionViewModel;
  final GardenGrowthViewModel gardenGrowthViewModel;

  static Future<_Harness> create() async {
    final tempDir = await Directory.systemTemp.createTemp('garden_home_test_');
    final localDataSource = await PracticeLocalDataSource.open(
      directory: tempDir.path,
      name: 'garden_home_${DateTime.now().microsecondsSinceEpoch}',
    );
    final practiceRepository = PracticeRepository(
      assetPhraseService: AssetPhraseService(bundle: rootBundle),
      localDataSource: localDataSource,
      installationIdService: InstallationIdService(
        directoryResolver: () async => tempDir,
        idGenerator: () => 'install_garden_home_test',
      ),
    );
    final accountViewModel = AccountViewModel(
      repository: _StaticAccountRepository(),
    );
    final practiceSessionViewModel = PracticeSessionViewModel(
      repository: practiceRepository,
      spaceId: 'daily_care',
      activityId: 'bath_time',
      audioController: _SilentPracticeAudioController(),
    );
    final gardenGrowthViewModel = GardenGrowthViewModel(
      repository: GardenGrowthRepository(
        practiceRepository: practiceRepository,
        assetPhraseService: AssetPhraseService(bundle: rootBundle),
      ),
    );

    return _Harness(
      tempDir: tempDir,
      localDataSource: localDataSource,
      practiceRepository: practiceRepository,
      accountViewModel: accountViewModel,
      practiceSessionViewModel: practiceSessionViewModel,
      gardenGrowthViewModel: gardenGrowthViewModel,
    );
  }

  Widget buildApp({
    PracticeRouteArgs? practiceArgs,
    bool includeContinuityProvider = true,
    bool includeShareProvider = false,
    ShareRepository? shareRepository,
    HouseholdViewModel? householdViewModel,
  }) {
    final resolvedPracticeArgs =
        practiceArgs ??
        const PracticeRouteArgs(spaceId: 'daily_care', activityId: 'bath_time');

    return MultiProvider(
      providers: [
        Provider<PracticeRepository>.value(value: practiceRepository),
        Provider<PracticeRouteArgs?>.value(value: resolvedPracticeArgs),
        if (includeContinuityProvider)
          ChangeNotifierProvider<PracticeContinuityViewModel>(
            create: (_) => PracticeContinuityViewModel(
              repository: practiceRepository,
              initialStarterArgs: resolvedPracticeArgs,
            )..initialize(reason: 'test_boot'),
          ),
        ChangeNotifierProvider<AccountViewModel>.value(value: accountViewModel),
        if (householdViewModel != null)
          ChangeNotifierProvider<HouseholdViewModel>.value(
            value: householdViewModel,
          ),
        ChangeNotifierProvider<PracticeSessionViewModel>.value(
          value: practiceSessionViewModel,
        ),
        ChangeNotifierProvider<GardenGrowthViewModel>.value(
          value: gardenGrowthViewModel,
        ),
        if (includeShareProvider && shareRepository != null)
          Provider<ShareRepository>.value(value: shareRepository),
        if (includeShareProvider && shareRepository != null)
          ChangeNotifierProxyProvider2<
            GardenGrowthViewModel,
            PracticeContinuityViewModel?,
            ShareViewModel
          >(
            create: (context) =>
                ShareViewModel(repository: context.read<ShareRepository>()),
            update:
                (
                  context,
                  growthViewModel,
                  continuityViewModel,
                  shareViewModel,
                ) {
                  final nextViewModel =
                      shareViewModel ??
                      ShareViewModel(
                        repository: context.read<ShareRepository>(),
                      );
                  nextViewModel.updateSnapshots(
                    growthSnapshot: growthViewModel.snapshot,
                    continuitySnapshot:
                        continuityViewModel?.hasResolvedRecommendation == true
                        ? continuityViewModel?.snapshot
                        : null,
                    notify: false,
                  );
                  return nextViewModel;
                },
          ),
      ],
      child: MaterialApp(theme: AppTheme.build(), home: const HomeScreen()),
    );
  }

  Future<void> dispose() async {
    await practiceRepository.close(deleteFromDisk: true);
    accountViewModel.dispose();
    practiceSessionViewModel.dispose();
    gardenGrowthViewModel.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
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
  Future<HouseholdLocalSnapshot> loadSnapshot() async => loadSnapshotResult;

  @override
  Future<HouseholdLocalSnapshot> refreshSharedContext({
    String reason = 'manual_refresh',
  }) async {
    return loadSnapshotResult;
  }
}

HouseholdSharedContext _sharedContext(PracticeRouteArgs practiceArgs) {
  return HouseholdSharedContext(
    babyProfileSummary: '共享宝宝档案：家庭已同步 2 条互动。',
    continuitySummary: '最近 continuity：先继续这条共享 activity。',
    gardenSummary: '花园上下文：共享花圃正在缓慢生长。',
    practiceArgs: practiceArgs,
    actor: const HouseholdSharedActor(
      role: 'caregiver',
      source: 'sync_event',
      result: 'needs_break',
    ),
    nextStep: HouseholdSharedNextStep(
      spaceId: practiceArgs.spaceId,
      activityId: practiceArgs.activityId,
      reason: 'top_activity',
    ),
    latestInteractionAt: DateTime.utc(2026, 4, 16, 11, 50),
    updatedAt: DateTime.utc(2026, 4, 16, 12),
  );
}

class _StaticAccountRepository implements AccountRepository {
  @override
  final String consentVersion = 'pipl-v1';

  @override
  Future<AccountLocalSnapshot> loadSnapshot() async {
    return AccountLocalSnapshot.signedOut;
  }

  @override
  Future<AccountLocalSnapshot> signIn({
    required String phoneNumber,
    required String verificationCode,
  }) async {
    return AccountLocalSnapshot.signedOut;
  }

  @override
  Future<AccountLocalSnapshot> savePlaceholderSession({
    required String phoneNumber,
    required String verificationCode,
  }) async {
    return AccountLocalSnapshot.signedOut;
  }

  @override
  Future<AccountLocalSnapshot> refreshRuntimeState({
    required AccountRuntimeTrigger trigger,
    AccountLocalSnapshot? seedSnapshot,
    bool forceBootstrap = false,
  }) async {
    return seedSnapshot ?? AccountLocalSnapshot.signedOut;
  }

  @override
  Future<AccountLocalSnapshot> clearPlaceholderSession({
    bool revertToLocalOnly = false,
  }) async {
    return AccountLocalSnapshot.signedOut;
  }

  @override
  Future<AccountLocalSnapshot> revokeConsent({
    String reason = 'user_requested',
  }) async {
    return AccountLocalSnapshot.signedOut;
  }

  @override
  Future<AccountLocalSnapshot> deleteAccount({
    String reason = 'forget_me',
  }) async {
    return AccountLocalSnapshot.signedOut;
  }

  @override
  Future<AccountLocalSnapshot> close() async {
    return AccountLocalSnapshot.signedOut;
  }
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

class _FakeShareApiService extends ShareApiService {
  _FakeShareApiService({this.error})
    : super(baseUri: Uri.parse('http://localhost:8080'));

  final ShareApiException? error;

  @override
  Future<ShareCreateLinkResponse> createShareLink({
    required ShareLinkDraft draft,
    String? platformHint,
  }) async {
    if (error != null) {
      throw error!;
    }
    return ShareCreateLinkResponse(
      token: 'share_token',
      shareUrl: 'https://share.example.com/share/share_token',
      expiresAt: DateTime.utc(2026, 4, 16, 12),
    );
  }

  @override
  Future<void> close() async {}
}

class _PendingShareSheetLauncher implements ShareSheetLauncher {
  final Completer<ShareSheetLaunchResult> _completer =
      Completer<ShareSheetLaunchResult>();

  @override
  Future<ShareSheetLaunchResult> shareText(String text, {String? subject}) {
    return _completer.future;
  }

  void complete(ShareSheetLaunchResult result) {
    if (!_completer.isCompleted) {
      _completer.complete(result);
    }
  }
}

class _StaticShareSheetLauncher implements ShareSheetLauncher {
  _StaticShareSheetLauncher({
    this.result = const ShareSheetLaunchResult(
      status: ShareSheetLaunchStatus.success,
    ),
  });

  final ShareSheetLaunchResult result;

  @override
  Future<ShareSheetLaunchResult> shareText(
    String text, {
    String? subject,
  }) async {
    return result;
  }
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
