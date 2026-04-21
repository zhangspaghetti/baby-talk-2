import 'dart:async';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/presentation/account_view_model.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/practice_session_view_model.dart';
import 'package:mobile/features/practice/presentation/screens/practice_session_screen.dart';
import 'package:mobile/features/shell/presentation/app_shell_screen.dart';
import 'package:mobile/features/shell/presentation/screens/discover_screen.dart';
import 'package:provider/provider.dart';
import 'package:mobile/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): _resolveBundledIsarLibraryPath()},
    );
  });

  testWidgets('缺失 route args 时只显示安全 fallback，不会白屏或回退默认 activity', (
    WidgetTester tester,
  ) async {
    final harness = await tester.runAsync<_RepositoryHarness>(
      _createRepositoryHarness,
    );
    addTearDown(harness!.dispose);

    await tester.pumpWidget(
      Provider<PracticeRepository>.value(
        value: harness.repository,
        child: MaterialApp(
          theme: AppTheme.build(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PracticeSessionScreen(
            routeEntry: PracticeRouteEntry.fromObject(null),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('practice-safe-fallback')), findsOneWidget);
    expect(find.textContaining('缺少或损坏 practice route 参数'), findsOneWidget);
    expect(find.byKey(const Key('activation-frame')), findsNothing);
  });

  testWidgets(
    '从 Discover activity 视图进入 feeding_time 时，practice 标题和 route scope 都对应被点击 activity',
    (tester) async {
      final harness = await _ShellHarness.create();
      addTearDown(harness.dispose);

      await harness.practiceRepository.recordReaction(
        spaceId: 'family_rhythm',
        activityId: 'feeding_time',
        phraseId: 'feeding_time_open_wide',
        reactionType: BabyReactionType.engaged,
        clientTimestamp: DateTime.utc(2026, 4, 10, 8, 0),
        localEventId: 'evt_feeding_time_1',
      );

      await tester.runAsync(() async {
        await harness.accountViewModel.initialize();
      });

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('发现'));
      await _pumpUntilFound(
        tester,
        find.byKey(
          const Key('discover-route-target-family_rhythm-feeding_time'),
        ),
      );

      await tester.tap(
        find.byKey(
          const Key('discover-route-target-family_rhythm-feeding_time'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const Key('practice-route-scope-family_rhythm-feeding_time'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('吃饭时间')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('practice-restore-banner')), findsOneWidget);
      expect(find.textContaining('共 1 条记录'), findsOneWidget);
      expect(
        find.byKey(const Key('practice-route-scope-daily_care-bath_time')),
        findsNothing,
      );
    },
  );

  testWidgets(
    '从 Discover space 视图连续打开 bedtime 和 diaper_change 时不会回落到 bath_time',
    (tester) async {
      final harness = await _ShellHarness.create();
      addTearDown(harness.dispose);

      await harness.practiceRepository.recordReaction(
        spaceId: 'family_rhythm',
        activityId: 'bedtime',
        phraseId: 'bedtime_dim_the_lights',
        reactionType: BabyReactionType.calm,
        clientTimestamp: DateTime.utc(2026, 4, 10, 21, 0),
        localEventId: 'evt_bedtime_1',
      );
      await harness.practiceRepository.recordReaction(
        spaceId: 'daily_care',
        activityId: 'diaper_change',
        phraseId: 'diaper_change_clean_bottom',
        reactionType: BabyReactionType.imitated,
        clientTimestamp: DateTime.utc(2026, 4, 10, 22, 0),
        localEventId: 'evt_diaper_change_1',
      );

      await tester.runAsync(() async {
        await harness.accountViewModel.initialize();
      });

      await tester.pumpWidget(harness.buildShellApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('发现'));
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('discover-route-target-family_rhythm-bedtime')),
      );

      await tester.tap(find.byKey(const Key('discover-tab-space')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('discover-route-target-family_rhythm-bedtime')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('practice-route-scope-family_rhythm-bedtime')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('睡前时间')),
        findsOneWidget,
      );
      expect(find.textContaining('共 1 条记录'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('discover-view-space')), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('discover-route-target-daily_care-diaper_change')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('practice-route-scope-daily_care-diaper_change')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('换尿布')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('practice-route-scope-daily_care-bath_time')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Discover 遇到未知 activity 卡片时会进入 practice fallback，而不是静默回退默认 activity',
    (tester) async {
      final harness = await tester.runAsync<_RepositoryHarness>(
        _createRepositoryHarness,
      );
      addTearDown(harness!.dispose);

      await tester.pumpWidget(
        Provider<PracticeRepository>.value(
          value: harness.repository,
          child: MaterialApp(
            theme: AppTheme.build(),
            onGenerateRoute: AppRouter.onGenerateRoute(
              shellBuilder: (_) => DiscoverScreen(
                catalogLoader: () async => _unknownActivityCatalog(),
              ),
              practiceBuilder: (context, settings) {
                final routeEntry = PracticeRouteEntry.fromObject(
                  settings.arguments,
                );
                return PracticeSessionScreen(routeEntry: routeEntry);
              },
            ),
          ),
        ),
      );

      await _pumpUntilFound(
        tester,
        find.byKey(
          const Key('discover-route-target-daily_care-unknown_activity'),
        ),
      );

      await tester.tap(
        find.byKey(
          const Key('discover-route-target-daily_care-unknown_activity'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('practice-safe-fallback')), findsOneWidget);
      expect(find.textContaining('未知 activityId'), findsOneWidget);
      expect(
        find.byKey(const Key('practice-route-scope-daily_care-bath_time')),
        findsNothing,
      );
    },
  );
}

Future<_RepositoryHarness> _createRepositoryHarness() async {
  final tempDir = Directory(
    '${Directory.systemTemp.path}${Platform.pathSeparator}practice_session_screen_test_${DateTime.now().microsecondsSinceEpoch}',
  );
  await tempDir.create(recursive: true);
  final localDataSource = await PracticeLocalDataSource.open(
    directory: tempDir.path,
    name: 'practice_${DateTime.now().microsecondsSinceEpoch}',
  );
  final assetPhraseService = AssetPhraseService(bundle: rootBundle);
  final installationIdService = InstallationIdService(
    directoryResolver: () async => tempDir,
    idGenerator: () => 'install_widget_test',
  );

  final repository = PracticeRepository(
    assetPhraseService: assetPhraseService,
    localDataSource: localDataSource,
    installationIdService: installationIdService,
  );

  return _RepositoryHarness(
    tempDir: tempDir,
    localDataSource: localDataSource,
    repository: repository,
  );
}

class _RepositoryHarness {
  const _RepositoryHarness({
    required this.tempDir,
    required this.localDataSource,
    required this.repository,
  });

  final Directory tempDir;
  final PracticeLocalDataSource localDataSource;
  final PracticeRepository repository;

  Future<void> dispose() async {
    await localDataSource.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
}

class _ShellHarness {
  _ShellHarness({
    required this.tempDir,
    required this.localDataSource,
    required this.practiceRepository,
    required this.accountViewModel,
  });

  final Directory tempDir;
  final PracticeLocalDataSource localDataSource;
  final PracticeRepository practiceRepository;
  final AccountViewModel accountViewModel;

  static Future<_ShellHarness> create() async {
    final tempDir = await Directory.systemTemp.createTemp(
      'discover_shell_test_',
    );
    final localDataSource = await PracticeLocalDataSource.open(
      directory: tempDir.path,
      name: 'discover_shell_${DateTime.now().microsecondsSinceEpoch}',
    );
    final practiceRepository = PracticeRepository(
      assetPhraseService: AssetPhraseService(bundle: rootBundle),
      localDataSource: localDataSource,
      installationIdService: InstallationIdService(
        directoryResolver: () async => tempDir,
        idGenerator: () => 'install_discover_shell_test',
      ),
    );
    final accountViewModel = AccountViewModel(
      repository: _StaticAccountRepository(),
    );

    return _ShellHarness(
      tempDir: tempDir,
      localDataSource: localDataSource,
      practiceRepository: practiceRepository,
      accountViewModel: accountViewModel,
    );
  }

  Widget buildShellApp() {
    return MultiProvider(
      providers: [
        Provider<PracticeRepository>.value(value: practiceRepository),
        ChangeNotifierProvider<AccountViewModel>.value(value: accountViewModel),
        Provider<PracticeRouteArgs>.value(
          value: const PracticeRouteArgs(
            spaceId: 'daily_care',
            activityId: 'bath_time',
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.build(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [appRouteObserver],
        onGenerateRoute: AppRouter.onGenerateRoute(
          shellBuilder: (_) => AppShellScreen(
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
          practiceBuilder: (context, settings) {
            final routeEntry = PracticeRouteEntry.fromObject(
              settings.arguments,
            );
            return PracticeSessionScreen(
              routeEntry: routeEntry,
              audioControllerFactory: _SilentPracticeAudioController.new,
            );
          },
        ),
      ),
    );
  }

  Future<void> dispose() async {
    await practiceRepository.close(deleteFromDisk: true);
    accountViewModel.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
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
  final StreamController<void> _controller = StreamController<void>.broadcast();

  @override
  Stream<void> get completionStream => _controller.stream;

  @override
  Future<void> playAsset(String assetPath) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

PracticeActivityCatalog _unknownActivityCatalog() {
  const activity = PracticeCatalogActivitySummary(
    spaceId: 'daily_care',
    spaceTitle: '日常照护',
    activityId: 'unknown_activity',
    title: '未知活动',
    summary: '这张卡故意指向不存在的 activity，用来验证 fallback。',
    sceneTag: 'Broken card',
    coachTip: 'tip',
    totalPhraseCount: 1,
    completedPhraseCount: 0,
    completedPhraseIds: <String>[],
    nextPhraseId: 'unknown_phrase',
    nextPhraseEnglish: 'Unknown phrase.',
    totalEvents: 0,
    skippedUnknownPhraseCount: 0,
    skippedMalformedEventCount: 0,
  );

  return const PracticeActivityCatalog(
    installationId: 'install_test',
    spaces: [
      PracticeCatalogSpaceSummary(
        spaceId: 'daily_care',
        title: '日常照护',
        description: 'broken',
        activities: [activity],
        totalEvents: 0,
        startedActivityCount: 0,
        completedActivityCount: 0,
      ),
    ],
    activities: [activity],
    totalStoredEvents: 0,
    validEvents: 0,
    knownEvents: 0,
    skippedMalformedEvents: 0,
    skippedUnknownContentEvents: 0,
  );
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 50),
  Duration timeout = const Duration(seconds: 12),
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
