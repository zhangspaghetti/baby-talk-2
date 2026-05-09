import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/app/app_reentry_orchestrator.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/app/invite_reentry_coordinator.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/app/share_reentry_coordinator.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/presentation/account_view_model.dart';
import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/data/repositories/household_repository.dart';
import 'package:mobile/features/household/data/services/household_api_service.dart';
import 'package:mobile/features/household/presentation/household_view_model.dart';
import 'package:mobile/features/mentor/data/local/mentor_local_data_source.dart';
import 'package:mobile/features/mentor/data/repositories/mentor_repository.dart';
import 'package:mobile/features/mentor/data/services/mentor_api_service.dart';
import 'package:mobile/features/mentor/presentation/mentor_view_model.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_view_model.dart';
import 'package:mobile/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/garden_growth_repository.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/data/services/dynamic_practice_api_service.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/practice/presentation/garden_growth_view_model.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_view_model.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/practice_session_view_model.dart';
import 'package:mobile/features/practice/presentation/screens/practice_session_screen.dart';
import 'package:mobile/features/share/data/repositories/share_repository.dart';
import 'package:mobile/features/share/data/services/share_api_service.dart';
import 'package:mobile/features/share/data/services/share_sheet_launcher.dart';
import 'package:mobile/features/share/presentation/share_view_model.dart';
import 'package:mobile/features/shell/presentation/app_shell_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
export 'package:mobile/features/practice/data/services/asset_phrase_service.dart'
    show SeedActivity, SeedContentBundle, SeedPhrase, SeedSpace;

class AppBootState {
  const AppBootState._({
    required this.content,
    required this.assetPhraseService,
    required this.primarySpaceId,
    required this.primaryActivityId,
    this.errorMessage,
  });

  final SeedContentBundle? content;
  final AssetPhraseService? assetPhraseService;
  final String? primarySpaceId;
  final String? primaryActivityId;
  final String? errorMessage;

  bool get isReady =>
      content != null &&
      assetPhraseService != null &&
      primarySpaceId != null &&
      primaryActivityId != null &&
      errorMessage == null;

  static Future<AppBootState> load(AssetBundle bundle) async {
    final assetPhraseService = AssetPhraseService(bundle: bundle);
    try {
      final content = await assetPhraseService.loadSeedContent();
      final primarySpace = content.spaces.first;
      final primaryActivity = primarySpace.activities.first;
      return AppBootState._(
        content: content,
        assetPhraseService: assetPhraseService,
        primarySpaceId: primarySpace.id,
        primaryActivityId: primaryActivity.id,
      );
    } catch (error) {
      return AppBootState._(
        content: null,
        assetPhraseService: null,
        primarySpaceId: null,
        primaryActivityId: null,
        errorMessage: '应用启动失败，请重启后重试。',
      );
    }
  }
}

typedef PracticeRepositoryFactory =
    Future<PracticeRepository> Function(AssetPhraseService assetPhraseService);
typedef AccountRepositoryFactory =
    Future<AccountRepository> Function(
      PracticeRepository practiceRepository,
      Directory directory,
    );
typedef HouseholdRepositoryFactory =
    Future<HouseholdRepository> Function(
      AccountRepository accountRepository,
      Directory directory,
    );
typedef AppDirectoryResolver = Future<Directory> Function();
typedef PracticeAudioControllerFactory = PracticeAudioController Function();
typedef OnboardingCompletedSnapshotLoader =
    Future<OnboardingSnapshot?> Function();
const _bootContinuitySeedTimeout = Duration(seconds: 4);

class _AppBootContinuitySeed {
  const _AppBootContinuitySeed({
    required this.starterArgs,
    required this.defaultPracticeArgs,
    this.viewModelSeed,
  });

  final PracticeRouteArgs starterArgs;
  final PracticeRouteArgs defaultPracticeArgs;
  final PracticeContinuitySeedState? viewModelSeed;
}

class _SharedConsumerAuthDependencies {
  _SharedConsumerAuthDependencies._({
    required this.accountApiService,
    required this.authenticatedApiClient,
    required this.dynamicPracticeApiService,
    required this.householdApiService,
    required this.mentorApiService,
  });

  factory _SharedConsumerAuthDependencies.create() {
    final accountApiService = AccountApiService();
    final authenticatedApiClient = AuthenticatedApiClient(
      apiService: accountApiService,
    );
    return _SharedConsumerAuthDependencies._(
      accountApiService: accountApiService,
      authenticatedApiClient: authenticatedApiClient,
      dynamicPracticeApiService: DynamicPracticeApiService(),
      householdApiService: HouseholdApiService(
        authenticatedApiClient: authenticatedApiClient,
      ),
      mentorApiService: MentorApiService(
        authenticatedApiClient: authenticatedApiClient,
      ),
    );
  }

  final AccountApiService accountApiService;
  final AuthenticatedApiClient authenticatedApiClient;
  final DynamicPracticeApiService dynamicPracticeApiService;
  final HouseholdApiService householdApiService;
  final MentorApiService mentorApiService;

  void close() {
    accountApiService.close();
    dynamicPracticeApiService.close();
    householdApiService.close();
    mentorApiService.close();
  }
}

class _AppLaunchState {
  const _AppLaunchState({
    required this.practiceRepository,
    required this.onboardingRepository,
    required this.accountRepository,
    required this.householdRepository,
    required this.mentorRepository,
    required this.destination,
    required this.starterArgs,
    required this.defaultPracticeArgs,
    this.continuitySeed,
    this.completedSnapshot,
    this.mentorApiService,
  });

  final PracticeRepository practiceRepository;
  final OnboardingRepository onboardingRepository;
  final AccountRepository accountRepository;
  final HouseholdRepository householdRepository;
  final MentorRepository mentorRepository;
  final AppLaunchDestination destination;
  final PracticeRouteArgs starterArgs;
  final PracticeRouteArgs defaultPracticeArgs;
  final PracticeContinuitySeedState? continuitySeed;
  final OnboardingSnapshot? completedSnapshot;
  final MentorApiService? mentorApiService;

  String get initialRoute => switch (destination) {
    AppLaunchDestination.onboarding => AppRouteNames.onboarding,
    AppLaunchDestination.shell => AppRouteNames.shell,
  };
}

class BabyTalkApp extends StatefulWidget {
  const BabyTalkApp({
    super.key,
    required this.bootState,
    this.repositoryFactory,
    this.accountRepositoryFactory,
    this.householdRepositoryFactory,
    this.appDirectoryResolver,
    this.audioControllerFactory,
    this.completedSnapshotLoader,
    this.shareUriStream,
    this.shareReentryCoordinator,
    this.inviteReentryCoordinator,
    this.practiceContinuityRefreshTimeout = const Duration(seconds: 4),
    this.gardenGrowthRefreshTimeout = const Duration(seconds: 4),
  });

  final AppBootState bootState;
  final PracticeRepositoryFactory? repositoryFactory;
  final AccountRepositoryFactory? accountRepositoryFactory;
  final HouseholdRepositoryFactory? householdRepositoryFactory;
  final AppDirectoryResolver? appDirectoryResolver;
  final PracticeAudioControllerFactory? audioControllerFactory;
  final OnboardingCompletedSnapshotLoader? completedSnapshotLoader;
  final Stream<Uri>? shareUriStream;
  final ShareReentryCoordinator? shareReentryCoordinator;
  final InviteReentryCoordinator? inviteReentryCoordinator;
  final Duration practiceContinuityRefreshTimeout;
  final Duration gardenGrowthRefreshTimeout;

  @override
  State<BabyTalkApp> createState() => _BabyTalkAppState();
}

class _BabyTalkAppState extends State<BabyTalkApp> {
  late Future<_AppLaunchState> _launchStateFuture;
  late final ShareReentryCoordinator _shareReentryCoordinator;
  late final InviteReentryCoordinator _inviteReentryCoordinator;
  late final bool _ownsShareReentryCoordinator;
  late final bool _ownsInviteReentryCoordinator;
  late final AppReentryOrchestrator _reentryOrchestrator;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  PracticeRepository? _repository;
  MentorRepository? _mentorRepository;
  _SharedConsumerAuthDependencies? _sharedConsumerAuthDependencies;
  _AppLaunchState? _resolvedLaunchState;

  @override
  void initState() {
    super.initState();
    _ownsShareReentryCoordinator = widget.shareReentryCoordinator == null;
    _ownsInviteReentryCoordinator = widget.inviteReentryCoordinator == null;
    _shareReentryCoordinator =
        widget.shareReentryCoordinator ?? ShareReentryCoordinator();
    _inviteReentryCoordinator =
        widget.inviteReentryCoordinator ?? InviteReentryCoordinator();
    _reentryOrchestrator = AppReentryOrchestrator(
      shareReentryCoordinator: _shareReentryCoordinator,
      inviteReentryCoordinator: _inviteReentryCoordinator,
      navigatorStateProvider: () => _navigatorKey.currentState,
      mountedCheck: () => mounted,
      launchDestinationProvider: () => _resolvedLaunchState?.destination,
      seedContentProvider: () => widget.bootState.content,
      householdViewModelLookup: _lookupViewModel<HouseholdViewModel>,
      continuityViewModelLookup: _lookupViewModel<PracticeContinuityViewModel>,
      gardenGrowthViewModelLookup: _lookupViewModel<GardenGrowthViewModel>,
    );
    _reentryOrchestrator.configureShareUriSubscription(widget.shareUriStream);
    _launchStateFuture = _loadLaunchState();
  }

  _SharedConsumerAuthDependencies _resolveSharedConsumerAuthDependencies() {
    return _sharedConsumerAuthDependencies ??=
        _SharedConsumerAuthDependencies.create();
  }

  @override
  void didUpdateWidget(covariant BabyTalkApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shareUriStream != widget.shareUriStream) {
      _reentryOrchestrator.configureShareUriSubscription(widget.shareUriStream);
    }
    if (oldWidget.bootState != widget.bootState ||
        oldWidget.repositoryFactory != widget.repositoryFactory ||
        oldWidget.accountRepositoryFactory != widget.accountRepositoryFactory ||
        oldWidget.householdRepositoryFactory !=
            widget.householdRepositoryFactory ||
        oldWidget.appDirectoryResolver != widget.appDirectoryResolver ||
        oldWidget.audioControllerFactory != widget.audioControllerFactory ||
        oldWidget.completedSnapshotLoader != widget.completedSnapshotLoader ||
        oldWidget.practiceContinuityRefreshTimeout !=
            widget.practiceContinuityRefreshTimeout ||
        oldWidget.gardenGrowthRefreshTimeout !=
            widget.gardenGrowthRefreshTimeout) {
      _launchStateFuture = _loadLaunchState();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.bootState.isReady) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.build(),
        darkTheme: AppTheme.buildDark(),
        themeMode: ThemeMode.system,
        home: BootFailureScreen(
          message: widget.bootState.errorMessage ?? '未知启动错误',
          statusKey: const Key('boot-status-failed'),
        ),
      );
    }

    return FutureBuilder<_AppLaunchState>(
      future: _launchStateFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.build(),
            darkTheme: AppTheme.buildDark(),
            themeMode: ThemeMode.system,
            home: const BootLoadingScreen(),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.build(),
            darkTheme: AppTheme.buildDark(),
            themeMode: ThemeMode.system,
            home: BootFailureScreen(
              message: 'onboarding 本地档案读取失败：${snapshot.error}',
              statusKey: const Key('boot-route-gate-failed'),
              actionLabel: '重试',
              onAction: _retryLaunchState,
            ),
          );
        }

        final launchState = snapshot.requireData;
        _resolvedLaunchState = launchState;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _reentryOrchestrator.drainPendingShareReentry();
          unawaited(_reentryOrchestrator.drainPendingInviteReentry());
        });
        final practiceRepository = launchState.practiceRepository;
        final onboardingRepository = launchState.onboardingRepository;
        final accountRepository = launchState.accountRepository;
        final householdRepository = launchState.householdRepository;
        final mentorRepository = launchState.mentorRepository;
        return MultiProvider(
          providers: [
            ChangeNotifierProvider<ShareReentryCoordinator>.value(
              value: _shareReentryCoordinator,
            ),
            ChangeNotifierProvider<InviteReentryCoordinator>.value(
              value: _inviteReentryCoordinator,
            ),
            Provider<PracticeRepository>.value(value: practiceRepository),
            Provider<OnboardingRepository>.value(value: onboardingRepository),
            Provider<AccountRepository>.value(value: accountRepository),
            Provider<HouseholdRepository>.value(value: householdRepository),
            Provider<MentorRepository>.value(value: mentorRepository),
            Provider<PracticeRouteArgs>.value(
              value: launchState.defaultPracticeArgs,
            ),
            Provider<GardenGrowthRepository>(
              create: (_) => GardenGrowthRepository(
                practiceRepository: practiceRepository,
                assetPhraseService: widget.bootState.assetPhraseService!,
              ),
            ),
            ChangeNotifierProvider<PracticeContinuityViewModel>(
              create: (_) => PracticeContinuityViewModel(
                repository: practiceRepository,
                initialStarterArgs: launchState.starterArgs,
                seedState: launchState.continuitySeed,
                refreshTimeout: widget.practiceContinuityRefreshTimeout,
              ),
            ),
            ChangeNotifierProvider<AccountViewModel>(
              create: (_) => AccountViewModel(repository: accountRepository),
            ),
            ChangeNotifierProvider<HouseholdViewModel>(
              create: (_) =>
                  HouseholdViewModel(repository: householdRepository)
                    ..initialize(),
            ),
            ChangeNotifierProvider<MentorViewModel>(
              create: (context) => MentorViewModel(
                repository: context.read<MentorRepository>(),
                accountViewModel: context.read<AccountViewModel>(),
                apiService: launchState.mentorApiService,
                persistRefreshedSession:
                    accountRepository.persistRefreshedSession,
              ),
            ),
            ChangeNotifierProvider<GardenGrowthViewModel>(
              create: (context) => GardenGrowthViewModel(
                repository: context.read<GardenGrowthRepository>(),
                refreshTimeout: widget.gardenGrowthRefreshTimeout,
              ),
            ),
            Provider<ShareApiService>(
              create: (_) => ShareApiService(),
              dispose: (_, service) => service.close(),
            ),
            Provider<ShareRepository>(
              create: (context) => ShareRepository(
                apiService: context.read<ShareApiService>(),
                shareSheetLauncher: const SharePlusSheetLauncher(),
              ),
            ),
            ChangeNotifierProxyProvider2<
              GardenGrowthViewModel,
              PracticeContinuityViewModel,
              ShareViewModel
            >(
              create: (context) =>
                  ShareViewModel(repository: context.read<ShareRepository>()),
              update:
                  (
                    context,
                    gardenGrowthViewModel,
                    continuityViewModel,
                    shareViewModel,
                  ) {
                    final nextViewModel =
                        shareViewModel ??
                        ShareViewModel(
                          repository: context.read<ShareRepository>(),
                        );
                    nextViewModel.updateSnapshots(
                      growthSnapshot: gardenGrowthViewModel.snapshot,
                      continuitySnapshot:
                          continuityViewModel.hasResolvedRecommendation
                          ? continuityViewModel.snapshot
                          : null,
                      notify: false,
                    );
                    return nextViewModel;
                  },
            ),
          ],
          child: MaterialApp(
            navigatorKey: _navigatorKey,
            builder: (context, child) => _ReentryOverlay(child: child),
            debugShowCheckedModeBanner: false,
            title: 'Baby Talk 2',
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.build(),
            darkTheme: AppTheme.buildDark(),
            themeMode: ThemeMode.system,
            navigatorObservers: [appRouteObserver],
            initialRoute: launchState.initialRoute,
            onGenerateRoute: AppRouter.onGenerateRoute(
              onboardingBuilder: (_) =>
                  ChangeNotifierProvider<OnboardingViewModel>(
                    create: (_) =>
                        OnboardingViewModel(repository: onboardingRepository)
                          ..initialize(),
                    child: const _BootRouteMarker(
                      routeKey: Key('boot-route-onboarding'),
                      child: OnboardingScreen(),
                    ),
                  ),
              shellBuilder: (context) {
                final routeArgs = ModalRoute.of(context)?.settings.arguments;
                final routedSnapshot = routeArgs is OnboardingSnapshot
                    ? routeArgs
                    : launchState.completedSnapshot;
                return _BootRouteMarker(
                  routeKey: const Key('boot-route-shell'),
                  child: AppShellScreen(onboardingSnapshot: routedSnapshot),
                );
              },
              practiceBuilder: (context, settings) {
                final routeEntry = PracticeRouteEntry.fromObject(
                  settings.arguments,
                );
                return PracticeSessionScreen(
                  routeEntry: routeEntry,
                  audioControllerFactory: widget.audioControllerFactory,
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    final repository = _repository;
    final mentorRepository = _mentorRepository;
    final sharedConsumerAuthDependencies = _sharedConsumerAuthDependencies;
    _reentryOrchestrator.dispose();
    if (_ownsShareReentryCoordinator) {
      _shareReentryCoordinator.dispose();
    }
    if (_ownsInviteReentryCoordinator) {
      _inviteReentryCoordinator.dispose();
    }
    if (repository != null) {
      unawaited(repository.close());
    }
    if (mentorRepository != null) {
      unawaited(mentorRepository.close());
    }
    sharedConsumerAuthDependencies?.close();
    super.dispose();
  }

  T? _lookupViewModel<T>() {
    final context = _navigatorKey.currentContext;
    if (context == null) {
      return null;
    }
    try {
      return Provider.of<T>(context, listen: false);
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _retryLaunchState() async {
    setState(() {
      _launchStateFuture = _loadLaunchState();
    });
  }

  Future<_AppLaunchState> _loadLaunchState() async {
    PracticeRepository? repository;
    HouseholdRepository? householdRepository;
    MentorRepository? mentorRepository;
    if (widget.accountRepositoryFactory != null) {
      _sharedConsumerAuthDependencies?.close();
      _sharedConsumerAuthDependencies = null;
    }
    try {
      final factory = widget.repositoryFactory ?? _defaultRepositoryFactory;
      final directory = await _resolveAppDirectory();
      repository = await factory(widget.bootState.assetPhraseService!);
      final onboardingStore = OnboardingSnapshotStore(
        directoryResolver: () async => directory,
      );
      final onboardingRepository = OnboardingRepository(
        snapshotStore: onboardingStore,
        practiceRepository: repository,
        starterSpaceId: widget.bootState.primarySpaceId!,
        starterActivityId: widget.bootState.primaryActivityId!,
      );
      final accountRepositoryFactory =
          widget.accountRepositoryFactory ?? _defaultAccountRepositoryFactory;
      final accountRepository = await accountRepositoryFactory(
        repository,
        directory,
      );
      final householdRepositoryFactory =
          widget.householdRepositoryFactory ??
          _defaultHouseholdRepositoryFactory;
      householdRepository = await householdRepositoryFactory(
        accountRepository,
        directory,
      );
      mentorRepository = MentorRepository(
        localDataSource: await MentorLocalDataSource.open(
          directory: directory.path,
        ),
        practiceRepository: repository,
        onboardingSnapshotStore: onboardingStore,
        householdSnapshotLoader: householdRepository.loadSnapshot,
      );
      final completedSnapshotLoader = widget.completedSnapshotLoader;
      final completedSnapshot = completedSnapshotLoader == null
          ? await onboardingRepository.readCompletedSnapshot()
          : await completedSnapshotLoader();
      final continuitySeed = await _resolveBootContinuitySeed(
        repository: repository,
        completedSnapshot: completedSnapshot,
      );
      _repository = repository;
      _mentorRepository = mentorRepository;
      return _AppLaunchState(
        practiceRepository: repository,
        onboardingRepository: onboardingRepository,
        accountRepository: accountRepository,
        householdRepository: householdRepository,
        mentorRepository: mentorRepository,
        destination: completedSnapshot != null
            ? AppLaunchDestination.shell
            : widget.appDirectoryResolver != null
            ? AppLaunchDestination.onboarding
            : AppLaunchDestination.shell,
        starterArgs: continuitySeed.starterArgs,
        defaultPracticeArgs: continuitySeed.defaultPracticeArgs,
        continuitySeed: continuitySeed.viewModelSeed,
        completedSnapshot: completedSnapshot,
        mentorApiService: widget.accountRepositoryFactory == null
            ? _sharedConsumerAuthDependencies?.mentorApiService
            : null,
      );
    } catch (error) {
      if (householdRepository != null) {
        await householdRepository.close();
      }
      if (mentorRepository != null &&
          !identical(mentorRepository, _mentorRepository)) {
        await mentorRepository.close();
      }
      if (repository != null && !identical(repository, _repository)) {
        await repository.close();
      }
      rethrow;
    }
  }

  Future<_AppBootContinuitySeed> _resolveBootContinuitySeed({
    required PracticeRepository repository,
    required OnboardingSnapshot? completedSnapshot,
  }) async {
    final primaryArgs = PracticeRouteArgs(
      spaceId: widget.bootState.primarySpaceId!,
      activityId: widget.bootState.primaryActivityId!,
    );
    final starterArgs =
        PracticeRouteArgs.maybeCreate(
          spaceId: completedSnapshot?.starterSpaceId,
          activityId: completedSnapshot?.starterActivityId,
        ) ??
        primaryArgs;

    if (completedSnapshot == null) {
      return _AppBootContinuitySeed(
        starterArgs: starterArgs,
        defaultPracticeArgs: starterArgs,
      );
    }

    try {
      final continuitySnapshot = await repository
          .getContinuitySnapshot(
            starterSpaceId: starterArgs.spaceId,
            starterActivityId: starterArgs.activityId,
          )
          .timeout(_bootContinuitySeedTimeout);
      final recommendedArgs = PracticeRouteArgs.maybeCreate(
        spaceId: continuitySnapshot.recommendedActivity.spaceId,
        activityId: continuitySnapshot.recommendedActivity.activityId,
      );
      if (recommendedArgs == null) {
        return _AppBootContinuitySeed(
          starterArgs: starterArgs,
          defaultPracticeArgs: starterArgs,
        );
      }

      final activitySnapshot = await repository
          .getActivitySnapshot(
            spaceId: recommendedArgs.spaceId,
            activityId: recommendedArgs.activityId,
          )
          .timeout(_bootContinuitySeedTimeout);
      return _AppBootContinuitySeed(
        starterArgs: starterArgs,
        defaultPracticeArgs: recommendedArgs,
        viewModelSeed: PracticeContinuitySeedState(
          starterArgs: starterArgs,
          snapshot: continuitySnapshot,
          activitySnapshot: activitySnapshot,
          recommendedArgs: recommendedArgs,
          status: PracticeContinuityLoadStatus.ready,
          warningMessage: continuitySnapshot.warningMessage,
          lastRefreshReason:
              'boot_seed_${continuitySnapshot.recommendation.reason.wireValue}',
        ),
      );
    } on TimeoutException {
      return _AppBootContinuitySeed(
        starterArgs: starterArgs,
        defaultPracticeArgs: starterArgs,
      );
    } on FormatException {
      return _AppBootContinuitySeed(
        starterArgs: starterArgs,
        defaultPracticeArgs: starterArgs,
      );
    } catch (_) {
      return _AppBootContinuitySeed(
        starterArgs: starterArgs,
        defaultPracticeArgs: starterArgs,
      );
    }
  }

  Future<PracticeRepository> _defaultRepositoryFactory(
    AssetPhraseService assetPhraseService,
  ) async {
    final directory = await _resolveAppDirectory();
    final authDependencies = _resolveSharedConsumerAuthDependencies();
    final localDataSource = await PracticeLocalDataSource.open(
      directory: directory.path,
    );
    return PracticeRepository(
      assetPhraseService: assetPhraseService,
      localDataSource: localDataSource,
      dynamicPracticeApiService: authDependencies.dynamicPracticeApiService,
      installationIdService: InstallationIdService(
        directoryResolver: () async => directory,
      ),
    );
  }

  Future<AccountRepository> _defaultAccountRepositoryFactory(
    PracticeRepository practiceRepository,
    Directory directory,
  ) async {
    final connectivity = Connectivity();
    final authDependencies = _resolveSharedConsumerAuthDependencies();
    return AccountRepository(
      localStore: AccountLocalStore(),
      practiceRepository: practiceRepository,
      apiService: authDependencies.accountApiService,
      authenticatedApiClient: authDependencies.authenticatedApiClient,
      connectivityChecker: () async {
        try {
          final dynamic status = await connectivity.checkConnectivity();
          if (status is List<ConnectivityResult>) {
            return status.any((entry) => entry != ConnectivityResult.none);
          }
          if (status is ConnectivityResult) {
            return status != ConnectivityResult.none;
          }
          return true;
        } on MissingPluginException {
          return true;
        } catch (_) {
          return true;
        }
      },
    );
  }

  Future<HouseholdRepository> _defaultHouseholdRepositoryFactory(
    AccountRepository accountRepository,
    Directory directory,
  ) async {
    final authDependencies = _resolveSharedConsumerAuthDependencies();
    return HouseholdRepository(
      localStore: HouseholdLocalStore(directoryResolver: () async => directory),
      apiService: authDependencies.householdApiService,
      accountSnapshotLoader: accountRepository.loadSnapshot,
      persistRefreshedSession: accountRepository.persistRefreshedSession,
    );
  }

  Future<Directory> _resolveAppDirectory() async {
    final resolver = widget.appDirectoryResolver;
    if (resolver != null) return resolver();
    try {
      return await getApplicationSupportDirectory();
    } on MissingPluginException {
      final directory = Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}baby_talk_2_support',
      );
      await directory.create(recursive: true);
      return directory;
    }
  }
}

class BootLoadingScreen extends StatelessWidget {
  const BootLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: CircularProgressIndicator(key: Key('boot-loading')),
        ),
      ),
    );
  }
}

class BootFailureScreen extends StatelessWidget {
  const BootFailureScreen({
    super.key,
    required this.message,
    required this.statusKey,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final Key statusKey;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Container(
              key: statusKey,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.errorSoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, style: Theme.of(context).textTheme.bodyLarge),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('boot-route-gate-retry'),
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BootRouteMarker extends StatelessWidget {
  const _BootRouteMarker({required this.routeKey, required this.child});

  final Key routeKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('boot-route-gate-ready'),
      child: KeyedSubtree(key: routeKey, child: child),
    );
  }
}

class _ReentryOverlay extends StatelessWidget {
  const _ReentryOverlay({this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final inviteCoordinator = context.watch<InviteReentryCoordinator>();
    final shareCoordinator = context.watch<ShareReentryCoordinator>();
    final inviteMessage = inviteCoordinator.displayMessage?.trim();
    final shareMessage = shareCoordinator.displayMessage?.trim();
    final hasInviteMessage = inviteMessage != null && inviteMessage.isNotEmpty;
    final hasShareMessage = shareMessage != null && shareMessage.isNotEmpty;
    final visibleMessage = hasInviteMessage
        ? inviteMessage
        : (hasShareMessage ? shareMessage : null);
    final overlayKey = hasInviteMessage
        ? const Key('invite-reentry-overlay')
        : const Key('share-reentry-overlay');

    return Stack(
      fit: StackFit.expand,
      children: [
        // ignore: use_null_aware_elements
        if (child != null) child!,
        if (visibleMessage != null)
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Material(
                  key: overlayKey,
                  color: Colors.transparent,
                  child: Container(
                    constraints: const BoxConstraints(
                      maxWidth: AppLayoutConstants.maxContentWidth,
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                    decoration: BoxDecoration(
                      color: colors.warningSoft,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: colors.warmShadowMd,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.info_outline,
                            color: colors.warning,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            visibleMessage,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: colors.warning,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: '关闭提示',
                          icon: Icon(
                            Icons.close,
                            size: 18,
                            color: colors.warning,
                          ),
                          onPressed: () {
                            if (hasInviteMessage) {
                              inviteCoordinator.clearMessage();
                            } else {
                              shareCoordinator.clearMessage();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
