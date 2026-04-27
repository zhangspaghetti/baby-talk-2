import 'dart:async';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/account/presentation/account_view_model.dart';
import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/data/repositories/household_repository.dart';
import 'package:mobile/features/household/domain/models/household_role.dart';
import 'package:mobile/features/household/domain/models/household_shared_context.dart';
import 'package:mobile/features/household/presentation/household_view_model.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/garden_growth_repository.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/practice/presentation/garden_growth_view_model.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_view_model.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/practice_session_view_model.dart';
import 'package:mobile/features/shell/presentation/app_shell_screen.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): _resolveBundledIsarLibraryPath()},
    );
  });

  testWidgets('shell 在空投影时显示真实花园与成长空态，标题和 drawer 仍可用', (tester) async {
    final harness = (await tester.runAsync<_Harness>(_Harness.create))!;
    _registerHarnessTeardown(tester, harness);

    await tester.runAsync(() async {
      await Future.wait([
        harness.accountViewModel.initialize(),
        harness.practiceSessionViewModel.initialize(),
        harness.gardenGrowthViewModel.initialize(),
      ]);
    });

    await tester.pumpWidget(harness.buildShell());
    await _pumpUntilFound(tester, find.byKey(const Key('shell-ready')));
    await _pumpShellAsync(tester);

    expect(find.byKey(const Key('shell-ready')), findsOneWidget);
    expect(find.text('米米 的首页'), findsOneWidget);

    await tester.tap(find.byTooltip('花园'));
    await _pumpUntilFound(tester, find.byKey(const Key('shell-tab-garden')));

    expect(find.text('花园'), findsWidgets);
    expect(find.byKey(const Key('shell-tab-garden')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('garden-empty-state')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();
    expect(find.byKey(const Key('garden-empty-state')), findsOneWidget);
    expect(find.textContaining('第一颗种子还没落下'), findsOneWidget);
    expect(find.textContaining('S04 会把空间花圃'), findsNothing);

    await tester.tap(find.byTooltip('成长'));
    await _pumpUntilFound(tester, find.byKey(const Key('shell-tab-growth')));

    expect(find.text('成长'), findsWidgets);
    expect(find.byKey(const Key('shell-tab-growth')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('growth-empty-state')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();
    expect(find.byKey(const Key('growth-empty-state')), findsOneWidget);
    expect(find.textContaining('最近成长会写在这里'), findsWidgets);

    await tester.tap(find.byKey(const Key('shell-drawer-trigger')));
    await _pumpUntilFound(tester, find.byKey(const Key('shell-end-drawer')));

    expect(find.byKey(const Key('shell-end-drawer')), findsOneWidget);
    expect(find.byKey(const Key('shell-drawer-child-name')), findsOneWidget);
    expect(find.text('米米'), findsWidgets);
  });

  testWidgets('shell 会把 household shared context 接进 drawer 与 garden', (
    tester,
  ) async {
    final harness = (await tester.runAsync<_Harness>(_Harness.create))!;
    _registerHarnessTeardown(tester, harness);
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
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(1080, 1400);
    tester.view.devicePixelRatio = 1.0;

    await tester.runAsync(() async {
      await harness.practiceRepository.recordReaction(
        spaceId: 'family_rhythm',
        activityId: 'feeding_time',
        phraseId: 'feeding_time_open_wide',
        reactionType: BabyReactionType.engaged,
        clientTimestamp: DateTime.utc(2026, 4, 9, 9, 0),
        localEventId: 'evt_shell_household_1',
      );
      await harness.practiceRepository.recordReaction(
        spaceId: 'family_rhythm',
        activityId: 'feeding_time',
        phraseId: 'feeding_time_yummy_bite',
        reactionType: BabyReactionType.imitated,
        clientTimestamp: DateTime.utc(2026, 4, 9, 9, 1),
        localEventId: 'evt_shell_household_2',
      );
      await Future.wait([
        householdViewModel.initialize(),
        harness.accountViewModel.initialize(),
        harness.practiceSessionViewModel.initialize(),
        harness.gardenGrowthViewModel.refresh(),
      ]);
    });

    await tester.pumpWidget(
      harness.buildShell(householdViewModel: householdViewModel),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('shell-ready')));
    await _pumpShellAsync(tester);

    await tester.tap(find.byKey(const Key('shell-drawer-trigger')));
    await _pumpUntilFound(tester, find.byKey(const Key('shell-end-drawer')));

    expect(find.byKey(const Key('shell-drawer-role-badge')), findsOneWidget);
    expect(find.textContaining('次照护者'), findsWidgets);

    await tester.tapAt(const Offset(16, 120));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('花园'));
    await _pumpUntilFound(tester, find.byKey(const Key('shell-tab-garden')));

    final gardenScrollable = find.byType(Scrollable).last;
    final initialGardenOffset = tester
        .state<ScrollableState>(gardenScrollable)
        .position
        .pixels;
    await tester.scrollUntilVisible(
      find.byKey(const Key('garden-continue-practice')),
      160,
      scrollable: gardenScrollable,
    );
    await tester.pump();
    final continueOffset = tester
        .state<ScrollableState>(gardenScrollable)
        .position
        .pixels;
    expect(continueOffset, greaterThanOrEqualTo(initialGardenOffset));
    expect(find.byKey(const Key('garden-continue-practice')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('garden-household-shared-context-card')),
      160,
      scrollable: gardenScrollable,
    );
    await tester.pump();
    final householdOffset = tester
        .state<ScrollableState>(gardenScrollable)
        .position
        .pixels;
    expect(householdOffset, greaterThan(continueOffset));

    expect(
      find.byKey(const Key('garden-household-shared-context-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('garden-household-continuity-summary')),
      findsOneWidget,
    );
    expect(find.textContaining('共享宝宝档案'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const Key('garden-shared-overlay-card')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();
    expect(find.byKey(const Key('garden-shared-overlay-card')), findsOneWidget);
    expect(
      find.byKey(const Key('garden-shared-overlay-button')),
      findsOneWidget,
    );
  });

  testWidgets('shell 花园与首页消费同一份 continuity recommendation', (tester) async {
    final harness = (await tester.runAsync<_Harness>(_Harness.create))!;
    _registerHarnessTeardown(tester, harness);
    await tester.runAsync(() async {
      await harness.practiceRepository.recordReaction(
        spaceId: 'family_rhythm',
        activityId: 'feeding_time',
        phraseId: 'feeding_time_open_wide',
        reactionType: BabyReactionType.engaged,
        clientTimestamp: DateTime.utc(2026, 4, 9, 9, 0),
        localEventId: 'evt_shell_feed_1',
      );
      await harness.practiceRepository.recordReaction(
        spaceId: 'family_rhythm',
        activityId: 'feeding_time',
        phraseId: 'feeding_time_yummy_bite',
        reactionType: BabyReactionType.imitated,
        clientTimestamp: DateTime.utc(2026, 4, 9, 9, 1),
        localEventId: 'evt_shell_feed_2',
      );
      await harness.practiceRepository.importServerEvents([
        InteractionEventPayload.fromWire(
          eventKey: 'install_garden_shell_test:evt_unknown_1',
          localEventId: 'evt_unknown_1',
          installationId: 'install_garden_shell_test',
          spaceId: 'daily_care',
          activityId: 'bath_time',
          phraseId: 'bath_time_unknown',
          reactionType: 'calm',
          clientTimestamp: DateTime.utc(2026, 4, 9, 9, 2),
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

    await tester.pumpWidget(harness.buildShell());
    await _pumpUntilFound(tester, find.byKey(const Key('shell-ready')));
    await _pumpShellAsync(tester);
    await _pumpUntilContinuityResolved(tester);

    final shellElement = tester.element(find.byKey(const Key('shell-ready')));
    final continuityViewModel = Provider.of<PracticeContinuityViewModel>(
      shellElement,
      listen: false,
    );
    expect(continuityViewModel.hasResolvedRecommendation, isTrue);
    expect(continuityViewModel.recommendedArgs?.activityId, 'feeding_time');
    expect(
      continuityViewModel.snapshot?.recommendation.reason,
      PracticeContinuityReason.recentActivity,
    );

    await tester.tap(find.byTooltip('花园'));
    await _pumpUntilFound(tester, find.byKey(const Key('shell-tab-garden')));

    expect(find.byKey(const Key('shell-tab-garden')), findsOneWidget);
    expect(find.byKey(const Key('garden-empty-state')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('garden-continue-practice')),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();
    expect(find.byKey(const Key('garden-continue-practice')), findsOneWidget);
    expect(
      find.byKey(const Key('garden-continue-target-feeding_time')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('garden-continue-reason-feeding_time')),
      findsOneWidget,
    );
    expect(find.textContaining('吃饭时间'), findsWidgets);

    await tester.tap(find.byTooltip('成长'));
    await _pumpUntilFound(tester, find.byKey(const Key('shell-tab-growth')));

    expect(find.byKey(const Key('shell-tab-growth')), findsOneWidget);
    expect(find.byKey(const Key('growth-latest-impact')), findsOneWidget);
    expect(find.byKey(const Key('growth-projection-warning')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(
        const Key('growth-diary-install_garden_shell_test:evt_shell_feed_2'),
      ),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();

    expect(
      find.byKey(
        const Key('growth-diary-install_garden_shell_test:evt_shell_feed_2'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Yummy bite.'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const Key('growth-space-family_rhythm')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();
    expect(find.byKey(const Key('growth-space-family_rhythm')), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('growth-milestone-first_opening')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const Key('growth-milestone-first_opening')),
      findsOneWidget,
    );
  });

  testWidgets('缺少 garden provider 时 shell 仍显示安全空态，不会退回 discover placeholder', (
    tester,
  ) async {
    final harness = (await tester.runAsync<_Harness>(_Harness.create))!;
    _registerHarnessTeardown(tester, harness);

    await tester.runAsync(() async {
      await Future.wait([
        harness.accountViewModel.initialize(),
        harness.practiceSessionViewModel.initialize(),
      ]);
    });

    await tester.pumpWidget(harness.buildShell(includeGardenProvider: false));
    await _pumpUntilFound(tester, find.byKey(const Key('shell-ready')));
    await _pumpShellAsync(tester);

    await tester.tap(find.byTooltip('花园'));
    await _pumpUntilFound(tester, find.byKey(const Key('shell-tab-garden')));
    await tester.scrollUntilVisible(
      find.byKey(const Key('garden-empty-state')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump();
    expect(find.byKey(const Key('garden-empty-state')), findsOneWidget);
    expect(find.textContaining('S04 会把空间花圃'), findsNothing);

    await tester.tap(find.byTooltip('成长'));
    await _pumpUntilFound(tester, find.byKey(const Key('shell-tab-growth')));
    expect(find.byKey(const Key('growth-empty-state')), findsOneWidget);
    expect(find.textContaining('S04 也会把日记'), findsNothing);
  });

  testWidgets(
    'continuity snapshot 缺少推荐 args 时，Garden continue 禁用且不显示空 warning',
    (tester) async {
      final harness = (await tester.runAsync<_Harness>(_Harness.create))!;
      _registerHarnessTeardown(tester, harness);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.runAsync(() async {
        await harness.practiceRepository.recordReaction(
          spaceId: 'daily_care',
          activityId: 'bath_time',
          phraseId: 'bath_time_warm_water',
          reactionType: BabyReactionType.engaged,
          clientTimestamp: DateTime.utc(2026, 4, 9, 9, 0),
          localEventId: 'evt_shell_bad_args',
        );
        await Future.wait([
          harness.accountViewModel.initialize(),
          harness.practiceSessionViewModel.initialize(),
          harness.gardenGrowthViewModel.initialize(),
        ]);
      });

      await tester.pumpWidget(
        harness.buildShell(
          continuityViewModelFactory: (initialArgs) =>
              PracticeContinuityViewModel(
                continuitySnapshotLoader:
                    ({starterSpaceId, starterActivityId}) async {
                      return _buildMalformedContinuitySnapshot();
                    },
                activitySnapshotLoader:
                    ({required spaceId, required activityId}) async {
                      throw StateError(
                        'malformed snapshot should not request activity',
                      );
                    },
                initialStarterArgs: initialArgs,
              ),
        ),
      );
      await _pumpUntilFound(tester, find.byKey(const Key('shell-ready')));
      await _pumpShellAsync(tester);

      await tester.tap(find.byTooltip('花园'));
      await _pumpUntilFound(tester, find.byKey(const Key('shell-tab-garden')));
      await tester.pump();

      expect(find.byKey(const Key('garden-continue-practice')), findsOneWidget);

      expect(find.byKey(const Key('garden-launcher-bad-args')), findsOneWidget);
      expect(
        find.byKey(const Key('garden-continuity-warning')),
        findsOneWidget,
      );
      expect(find.textContaining('继续入口已禁用'), findsWidgets);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const Key('garden-continue-practice')),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('缺少有效推荐 activity 参数'), findsWidgets);
    },
  );
}

void _registerHarnessTeardown(WidgetTester tester, _Harness harness) {
  addTearDown(() async {
    await _disposeWidgetTree(tester);
    await harness.dispose();
  });
}

Future<void> _disposeWidgetTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump(const Duration(seconds: 5));
  await tester.runAsync(() async {
    await Future<void>.delayed(Duration.zero);
  });
  await tester.pump();
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
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }

  fail('Timed out waiting for expected widget.');
}

Future<void> _pumpShellAsync(
  WidgetTester tester, {
  int cycles = 8,
  Duration step = const Duration(milliseconds: 50),
}) async {
  for (var index = 0; index < cycles; index++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump(step);
  }
  await _pumpUntilHomeSettled(tester);
}

Future<void> _pumpUntilContinuityResolved(
  WidgetTester tester, {
  Duration step = const Duration(milliseconds: 50),
  Duration timeout = const Duration(seconds: 5),
}) async {
  final totalSteps = timeout.inMilliseconds ~/ step.inMilliseconds;
  for (var index = 0; index < totalSteps; index++) {
    await tester.pump(step);
    final shellFinder = find.byKey(const Key('shell-ready'));
    if (shellFinder.evaluate().isNotEmpty) {
      final shellElement = tester.element(shellFinder);
      final continuityViewModel = Provider.of<PracticeContinuityViewModel>(
        shellElement,
        listen: false,
      );
      if (continuityViewModel.hasResolvedRecommendation) {
        return;
      }
    }
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pump();
  }

  fail('Timed out waiting for continuity recommendation to resolve.');
}

Future<void> _pumpUntilHomeSettled(
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

  fail('Timed out waiting for shell home continuity to settle.');
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
    final tempDir = await Directory.systemTemp.createTemp('garden_shell_test_');
    final localDataSource = await PracticeLocalDataSource.open(
      directory: tempDir.path,
      name: 'garden_shell_${DateTime.now().microsecondsSinceEpoch}',
    );
    final practiceRepository = PracticeRepository(
      assetPhraseService: AssetPhraseService(bundle: rootBundle),
      localDataSource: localDataSource,
      installationIdService: InstallationIdService(
        directoryResolver: () async => tempDir,
        idGenerator: () => 'install_garden_shell_test',
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

  Widget buildShell({
    bool includeGardenProvider = true,
    bool includeContinuityProvider = true,
    PracticeContinuityViewModel Function(PracticeRouteArgs initialArgs)?
    continuityViewModelFactory,
    HouseholdViewModel? householdViewModel,
  }) {
    const starterArgs = PracticeRouteArgs(
      spaceId: 'daily_care',
      activityId: 'bath_time',
    );
    final providers = [
      Provider<PracticeRepository>.value(value: practiceRepository),
      Provider<PracticeRouteArgs?>.value(value: starterArgs),
      ChangeNotifierProvider<AccountViewModel>.value(value: accountViewModel),
      if (householdViewModel != null)
        ChangeNotifierProvider<HouseholdViewModel>.value(
          value: householdViewModel,
        ),
      ChangeNotifierProvider<PracticeSessionViewModel>.value(
        value: practiceSessionViewModel,
      ),
      if (includeContinuityProvider)
        ChangeNotifierProvider<PracticeContinuityViewModel>(
          create: (_) =>
              (continuityViewModelFactory?.call(starterArgs) ??
                    PracticeContinuityViewModel(
                      repository: practiceRepository,
                      initialStarterArgs: starterArgs,
                    ))
                ..initialize(reason: 'test_boot'),
        ),
      if (includeGardenProvider)
        ChangeNotifierProvider<GardenGrowthViewModel>.value(
          value: gardenGrowthViewModel,
        ),
    ];

    return MultiProvider(
      providers: providers,
      child: MaterialApp(
        theme: AppTheme.build(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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

  Future<void> dispose() async {
    accountViewModel.dispose();
    practiceSessionViewModel.dispose();
    gardenGrowthViewModel.dispose();
    try {
      await practiceRepository
          .close(deleteFromDisk: true)
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      // Windows + Isar teardown can briefly outlive the widget tree.
    }
    await _deleteDirectoryWithRetry(tempDir);
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
  Future<AccountSession> persistRefreshedSession(
    AccountSession refreshedSession,
  ) async {
    return refreshedSession;
  }

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

PracticeContinuitySnapshot _buildMalformedContinuitySnapshot() {
  const malformedActivity = PracticeCatalogActivitySummary(
    spaceId: '',
    spaceTitle: '日常照护',
    activityId: '',
    title: '损坏 recommendation',
    summary: '缺少 route args',
    sceneTag: 'Broken',
    coachTip: 'tip',
    totalPhraseCount: 1,
    completedPhraseCount: 0,
    completedPhraseIds: <String>[],
    nextPhraseId: 'bath_time_warm_water',
    nextPhraseEnglish: 'Warm water.',
    totalEvents: 0,
    skippedUnknownPhraseCount: 0,
    skippedMalformedEventCount: 0,
  );
  const catalog = PracticeActivityCatalog(
    installationId: 'install_garden_shell_test',
    spaces: <PracticeCatalogSpaceSummary>[
      PracticeCatalogSpaceSummary(
        spaceId: 'daily_care',
        title: '日常照护',
        description: 'desc',
        activities: <PracticeCatalogActivitySummary>[malformedActivity],
        totalEvents: 0,
        startedActivityCount: 0,
        completedActivityCount: 0,
      ),
    ],
    activities: <PracticeCatalogActivitySummary>[malformedActivity],
    totalStoredEvents: 0,
    validEvents: 0,
    knownEvents: 0,
    skippedMalformedEvents: 0,
    skippedUnknownContentEvents: 0,
  );

  return const PracticeContinuitySnapshot(
    catalog: catalog,
    recommendedActivity: malformedActivity,
    recentActivity: null,
    nextIncompleteActivity: malformedActivity,
    starterActivity: malformedActivity,
    recommendation: PracticeContinuityRecommendation(
      spaceId: '',
      activityId: '',
      activityTitle: '损坏 recommendation',
      reason: PracticeContinuityReason.safeCatalogFallback,
      reasonLabel: '使用目录安全回退',
      fallbackReason: '坏 continuity 已退回安全空态。',
    ),
    cadence: PracticeContinuityCadenceSummary(
      totalKnownEvents: 0,
      startedActivityCount: 0,
      lastEventTime: null,
      headline: '还没形成 cadence',
      detail: '等待共享 continuity 修复。',
    ),
    warningMessage: ' ',
  );
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

Future<void> _deleteDirectoryWithRetry(
  Directory directory, {
  int attempts = 20,
  Duration delay = const Duration(milliseconds: 50),
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    try {
      if (!await directory.exists()) {
        return;
      }
      await directory.delete(recursive: true);
      return;
    } on PathAccessException {
      await Future<void>.delayed(delay);
    }
  }
}
