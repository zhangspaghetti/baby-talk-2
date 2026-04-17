import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/app/invite_reentry_coordinator.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/app/share_reentry_coordinator.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/account/presentation/account_view_model.dart';
import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/data/repositories/household_repository.dart';
import 'package:mobile/features/household/data/services/household_api_service.dart';
import 'package:mobile/features/household/presentation/household_view_model.dart';
import 'package:mobile/features/mentor/data/local/mentor_local_data_source.dart';
import 'package:mobile/features/mentor/data/repositories/mentor_repository.dart';
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

  bool get isReady {
    return content != null &&
        assetPhraseService != null &&
        primarySpaceId != null &&
        primaryActivityId != null &&
        errorMessage == null;
  }

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
        errorMessage: 'Boot failed: $error',
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

enum AppLaunchDestination { onboarding, shell }

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

  String get initialRoute {
    switch (destination) {
      case AppLaunchDestination.onboarding:
        return AppRouteNames.onboarding;
      case AppLaunchDestination.shell:
        return AppRouteNames.shell;
    }
  }
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
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _shareUriSubscription;
  Future<void>? _inviteDrainFuture;
  bool _inviteDrainQueued = false;
  PracticeRepository? _repository;
  MentorRepository? _mentorRepository;
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
    _configureShareUriSubscription();
    _launchStateFuture = _loadLaunchState();
  }

  @override
  void didUpdateWidget(covariant BabyTalkApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shareUriStream != widget.shareUriStream) {
      _configureShareUriSubscription();
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
        theme: AppTheme.build(),
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
            theme: AppTheme.build(),
            home: const BootLoadingScreen(),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(),
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
          _drainPendingShareReentry();
          unawaited(_drainPendingInviteReentry());
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
            theme: AppTheme.build(),
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
    unawaited(_shareUriSubscription?.cancel() ?? Future<void>.value());
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
    super.dispose();
  }

  Future<void> _configureShareUriSubscription() async {
    await _shareUriSubscription?.cancel();
    final stream = widget.shareUriStream ?? AppLinks().uriLinkStream;
    _shareUriSubscription = stream.listen(
      _handleIncomingUri,
      onError: (Object error, StackTrace stackTrace) {
        _shareReentryCoordinator.markFallback(message: '分享回流监听异常，已停留在首页安全入口。');
        _inviteReentryCoordinator.markFallback(message: '邀请回流监听异常，已停留在首页安全入口。');
      },
    );
  }

  void _handleIncomingUri(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host == 'share') {
      final decision = _shareReentryCoordinator.acceptUri(uri);
      if (decision.dispatchTarget == ShareReentryDispatchTarget.none) {
        return;
      }
      _drainPendingShareReentry();
      return;
    }

    if (host == 'invite') {
      final decision = _inviteReentryCoordinator.acceptUri(uri);
      if (decision.dispatchTarget == InviteReentryDispatchTarget.none) {
        return;
      }
      unawaited(_drainPendingInviteReentry());
    }
  }

  void _drainPendingShareReentry() {
    final launchState = _resolvedLaunchState;
    final navigator = _navigatorKey.currentState;
    if (!mounted || launchState == null || navigator == null) {
      return;
    }

    if (launchState.destination != AppLaunchDestination.shell) {
      final hadPendingPractice =
          _shareReentryCoordinator.takePendingPracticeArgs() != null;
      final hadPendingFallback = _shareReentryCoordinator
          .takePendingShellFallback();
      if (hadPendingPractice || hadPendingFallback) {
        _shareReentryCoordinator.markFallback(
          message: '分享回流已收到，但当前 app 还不能安全进入练习；已停留在安全入口。',
        );
      }
      return;
    }

    if (_shareReentryCoordinator.takePendingShellFallback()) {
      AppRouter.navigateToShellFallback(navigator: navigator);
      _shareReentryCoordinator.markFallback(
        message:
            _shareReentryCoordinator.lastErrorSurface ?? '分享链接不可用，已停留在首页安全入口。',
      );
      return;
    }

    final practiceArgs = _shareReentryCoordinator.takePendingPracticeArgs();
    if (practiceArgs == null) {
      return;
    }
    if (!practiceArgs.isSupportedBy(widget.bootState.content!)) {
      AppRouter.navigateToShellFallback(navigator: navigator);
      _shareReentryCoordinator.markFallback(
        message: '分享链接里的 activity 不受支持，已停留在首页安全入口。',
      );
      return;
    }

    AppRouter.navigateToPracticeSeam(navigator: navigator, args: practiceArgs);
    _shareReentryCoordinator.markHandled(args: practiceArgs);
  }

  Future<void> _drainPendingInviteReentry() {
    final inFlight = _inviteDrainFuture;
    if (inFlight != null) {
      _inviteDrainQueued = true;
      return inFlight;
    }
    final future = _drainPendingInviteReentryInternal();
    _inviteDrainFuture = future;
    return future.whenComplete(() {
      if (identical(_inviteDrainFuture, future)) {
        _inviteDrainFuture = null;
      }
      final shouldDrainAgain = _inviteDrainQueued;
      _inviteDrainQueued = false;
      if (shouldDrainAgain && mounted) {
        unawaited(_drainPendingInviteReentry());
      }
    });
  }

  Future<void> _drainPendingInviteReentryInternal() async {
    final launchState = _resolvedLaunchState;
    final navigator = _navigatorKey.currentState;
    if (!mounted || launchState == null || navigator == null) {
      return;
    }

    if (launchState.destination != AppLaunchDestination.shell) {
      final hadPendingAccept =
          _inviteReentryCoordinator.takePendingAcceptCommand() != null;
      final hadPendingFallback = _inviteReentryCoordinator
          .takePendingShellFallback();
      if (hadPendingAccept || hadPendingFallback) {
        _inviteReentryCoordinator.markFallback(
          message: '邀请回流已收到，但当前 app 还不能安全进入共享练习；已停留在安全入口。',
        );
      }
      return;
    }

    if (_inviteReentryCoordinator.takePendingShellFallback()) {
      AppRouter.navigateToShellFallback(navigator: navigator);
      _inviteReentryCoordinator.markFallback(
        message:
            _inviteReentryCoordinator.lastErrorSurface ?? '邀请链接不可用，已停留在首页安全入口。',
      );
      return;
    }

    final command = _inviteReentryCoordinator.takePendingAcceptCommand();
    if (command == null) {
      return;
    }

    final householdViewModel = _lookupHouseholdViewModel();
    if (householdViewModel == null) {
      AppRouter.navigateToShellFallback(navigator: navigator);
      _inviteReentryCoordinator.markFallback(
        message: 'household provider 缺失，邀请回流已停留在首页安全入口。',
      );
      return;
    }

    final result = await householdViewModel.acceptInviteFromReentry(command);
    final practiceArgs = result.practiceArgs;
    if (!mounted) {
      return;
    }
    if (practiceArgs == null) {
      AppRouter.navigateToShellFallback(navigator: navigator);
      _inviteReentryCoordinator.markFallback(message: result.message);
      return;
    }
    if (!practiceArgs.isSupportedBy(widget.bootState.content!)) {
      AppRouter.navigateToShellFallback(navigator: navigator);
      _inviteReentryCoordinator.markFallback(
        message: '邀请返回的 activity 不受支持，已停留在首页安全入口。',
      );
      return;
    }

    final continuityViewModel = _lookupPracticeContinuityViewModel();
    if (continuityViewModel != null) {
      await continuityViewModel.configureStarterArgs(
        practiceArgs,
        reason: 'invite_accept',
      );
    }
    final gardenGrowthViewModel = _lookupGardenGrowthViewModel();
    if (gardenGrowthViewModel != null) {
      await gardenGrowthViewModel.refresh();
    }

    AppRouter.navigateToPracticeSeam(navigator: navigator, args: practiceArgs);
    _inviteReentryCoordinator.markHandled(args: practiceArgs);
  }

  HouseholdViewModel? _lookupHouseholdViewModel() {
    final context = _navigatorKey.currentContext;
    if (context == null) {
      return null;
    }
    try {
      return Provider.of<HouseholdViewModel>(context, listen: false);
    } on ProviderNotFoundException {
      return null;
    }
  }

  PracticeContinuityViewModel? _lookupPracticeContinuityViewModel() {
    final context = _navigatorKey.currentContext;
    if (context == null) {
      return null;
    }
    try {
      return Provider.of<PracticeContinuityViewModel>(context, listen: false);
    } on ProviderNotFoundException {
      return null;
    }
  }

  GardenGrowthViewModel? _lookupGardenGrowthViewModel() {
    final context = _navigatorKey.currentContext;
    if (context == null) {
      return null;
    }
    try {
      return Provider.of<GardenGrowthViewModel>(context, listen: false);
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
        destination: completedSnapshot == null
            ? AppLaunchDestination.onboarding
            : AppLaunchDestination.shell,
        starterArgs: continuitySeed.starterArgs,
        defaultPracticeArgs: continuitySeed.defaultPracticeArgs,
        continuitySeed: continuitySeed.viewModelSeed,
        completedSnapshot: completedSnapshot,
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
    final localDataSource = await PracticeLocalDataSource.open(
      directory: directory.path,
    );
    return PracticeRepository(
      assetPhraseService: assetPhraseService,
      localDataSource: localDataSource,
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
    return AccountRepository(
      localStore: AccountLocalStore(directoryResolver: () async => directory),
      practiceRepository: practiceRepository,
      apiService: AccountApiService(client: http.Client()),
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
    return HouseholdRepository(
      localStore: HouseholdLocalStore(directoryResolver: () async => directory),
      apiService: HouseholdApiService(client: http.Client()),
      accountSnapshotLoader: accountRepository.loadSnapshot,
    );
  }

  Future<Directory> _resolveAppDirectory() async {
    final resolver = widget.appDirectoryResolver;
    if (resolver != null) {
      return resolver();
    }

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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Container(
              key: statusKey,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.errorSoft,
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
    final inviteCoordinator = context.watch<InviteReentryCoordinator>();
    final shareCoordinator = context.watch<ShareReentryCoordinator>();
    final inviteMessage = inviteCoordinator?.displayMessage?.trim();
    final shareMessage = shareCoordinator?.displayMessage?.trim();
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
                    constraints: const BoxConstraints(maxWidth: 430),
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                    decoration: BoxDecoration(
                      color: AppTheme.warningSoft,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.warmShadowMd,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.info_outline,
                            color: AppTheme.warning,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            visibleMessage,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppTheme.warning,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: '关闭提示',
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: AppTheme.warning,
                          ),
                          onPressed: () {
                            if (hasInviteMessage) {
                              inviteCoordinator?.clearMessage();
                            } else {
                              shareCoordinator?.clearMessage();
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
