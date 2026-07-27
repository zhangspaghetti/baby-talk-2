import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/app_reentry_orchestrator.dart';
import 'package:mobile/app/auth_state.dart';
import 'package:mobile/app/feature_gates.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/app/invite_reentry_coordinator.dart';
import 'package:mobile/app/router/account_entry_route_contract.dart';
import 'package:mobile/app/router/app_route_contract.dart';
import 'package:mobile/app/share_reentry_coordinator.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/presentation/screens/account_entry_screen.dart';
import 'package:mobile/features/household/data/repositories/household_repository.dart';
import 'package:mobile/features/household/presentation/household_notifier.dart';
import 'package:mobile/features/mentor/data/repositories/mentor_repository.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_flow_store.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/presentation/screens/onboarding_flow_screen.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/presentation/garden_growth_notifier.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_notifier.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/practice_session_notifier.dart';
import 'package:mobile/features/practice/presentation/screens/practice_session_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show
        ConsumerState,
        ConsumerStatefulWidget,
        ConsumerWidget,
        Override,
        ProviderScope,
        WidgetRef;
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/features/settings/presentation/screens/about_screen.dart';
import 'package:mobile/features/settings/presentation/screens/baby_profile_screen.dart';
import 'package:mobile/features/settings/presentation/screens/caregiver_preferences_screen.dart';
import 'package:mobile/features/settings/presentation/screens/help_feedback_screen.dart';
import 'package:mobile/features/settings/presentation/screens/playback_preferences_screen.dart';
import 'package:mobile/features/settings/presentation/screens/reminder_settings_screen.dart';
import 'package:mobile/features/settings/presentation/screens/settings_screen.dart';
import 'package:mobile/features/shell/presentation/app_shell_screen.dart';
import 'package:mobile/features/shell/presentation/screens/garden_growth_combined_screen.dart';
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

typedef PracticeAudioControllerFactory = PracticeAudioController Function();
typedef OnboardingCompletedSnapshotLoader =
    Future<OnboardingSnapshot?> Function();
const _bootContinuitySeedTimeout = Duration(seconds: 4);

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

  String get initialRoute => switch (destination) {
    AppLaunchDestination.onboarding => AppRouteNames.onboarding,
    AppLaunchDestination.shell => AppRouteNames.shell,
  };
}

class BabyTalkApp extends ConsumerStatefulWidget {
  const BabyTalkApp({
    super.key,
    required this.bootState,
    this.audioControllerFactory,
    this.completedSnapshotLoader,
    this.shareUriStream,
    this.shareReentryCoordinator,
    this.inviteReentryCoordinator,
    this.practiceContinuityRefreshTimeout = const Duration(seconds: 4),
    this.gardenGrowthRefreshTimeout = const Duration(seconds: 4),
  });

  final AppBootState bootState;
  final PracticeAudioControllerFactory? audioControllerFactory;
  final OnboardingCompletedSnapshotLoader? completedSnapshotLoader;
  final Stream<Uri>? shareUriStream;
  final ShareReentryCoordinator? shareReentryCoordinator;
  final InviteReentryCoordinator? inviteReentryCoordinator;
  final Duration practiceContinuityRefreshTimeout;
  final Duration gardenGrowthRefreshTimeout;

  @override
  ConsumerState<BabyTalkApp> createState() => _BabyTalkAppState();
}

class _BabyTalkAppState extends ConsumerState<BabyTalkApp> {
  late Future<_AppLaunchState> _launchStateFuture;
  late final ShareReentryCoordinator _shareReentryCoordinator;
  late final InviteReentryCoordinator _inviteReentryCoordinator;
  late final bool _ownsShareReentryCoordinator;
  late final bool _ownsInviteReentryCoordinator;
  late final AppReentryOrchestrator _reentryOrchestrator;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  GoRouter? _currentRouter;
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
      goRouterProvider: () => _currentRouter,
      mountedCheck: () => mounted,
      launchDestinationProvider: () => _resolvedLaunchState?.destination,
      seedContentProvider: () => widget.bootState.content,
      householdNotifierLookup: _lookupNotifier<HouseholdNotifier>,
      continuityNotifierLookup: _lookupNotifier<PracticeContinuityNotifier>,
      gardenGrowthNotifierLookup: _lookupNotifier<GardenGrowthNotifier>,
    );
    _reentryOrchestrator.configureShareUriSubscription(widget.shareUriStream);
    _launchStateFuture = _buildLaunchStateFuture();
  }

  @override
  void didUpdateWidget(covariant BabyTalkApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shareUriStream != widget.shareUriStream) {
      _reentryOrchestrator.configureShareUriSubscription(widget.shareUriStream);
    }
    if (oldWidget.bootState != widget.bootState ||
        oldWidget.audioControllerFactory != widget.audioControllerFactory ||
        oldWidget.completedSnapshotLoader != widget.completedSnapshotLoader ||
        oldWidget.practiceContinuityRefreshTimeout !=
            widget.practiceContinuityRefreshTimeout ||
        oldWidget.gardenGrowthRefreshTimeout !=
            widget.gardenGrowthRefreshTimeout) {
      _launchStateFuture = _buildLaunchStateFuture();
    }
  }

  Future<_AppLaunchState> _buildLaunchStateFuture() {
    if (!widget.bootState.isReady) {
      return Completer<_AppLaunchState>().future;
    }
    return _loadLaunchState();
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
              message: '本地档案读取失败，请重试。',
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
        final onboardingRepository = launchState.onboardingRepository;
        return ProviderScope(
          overrides: _buildRiverpodOverrides(
            onboardingRepository: onboardingRepository,
            defaultPracticeArgs: launchState.defaultPracticeArgs,
            practiceRepository: launchState.practiceRepository,
            continuitySeed: launchState.continuitySeed,
          ),
          child: MaterialApp.router(
            routerConfig: _resolveRouter(
              launchState: launchState,
              onboardingRepository: onboardingRepository,
            ),
            builder: (context, child) => _ReentryOverlay(child: child),
            debugShowCheckedModeBanner: false,
            title: 'Baby Talk 2',
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.build(),
            darkTheme: AppTheme.buildDark(),
            themeMode: ThemeMode.system,
          ),
        );
      },
    );
  }

  List<Override> _buildRiverpodOverrides({
    required OnboardingRepository onboardingRepository,
    required PracticeRouteArgs defaultPracticeArgs,
    required PracticeRepository practiceRepository,
    required PracticeContinuitySeedState? continuitySeed,
  }) {
    return [
      onboardingRepositoryProvider.overrideWith((ref) => onboardingRepository),
      defaultPracticeRouteArgsProvider.overrideWithValue(defaultPracticeArgs),
      practiceContinuityNotifierProvider.overrideWith((ref) {
        return PracticeContinuityNotifier(
          repository: practiceRepository,
          seedState: continuitySeed,
          refreshTimeout: widget.practiceContinuityRefreshTimeout,
        )..initialize();
      }),
      gardenGrowthNotifierProvider.overrideWith((ref) {
        final repository = ref.watch(gardenGrowthRepositoryProvider);
        return GardenGrowthNotifier(
          repository: repository,
          refreshTimeout: widget.gardenGrowthRefreshTimeout,
        )..initialize();
      }),
    ];
  }

  @override
  void dispose() {
    _reentryOrchestrator.dispose();
    if (_ownsShareReentryCoordinator) {
      _shareReentryCoordinator.dispose();
    }
    if (_ownsInviteReentryCoordinator) {
      _inviteReentryCoordinator.dispose();
    }
    super.dispose();
  }

  T? _lookupNotifier<T>() {
    final context = _navigatorKey.currentContext;
    if (context == null) {
      return null;
    }
    try {
      final container = ProviderScope.containerOf(context);
      // Match by runtime type since Riverpod providers are typed.
      if (T == HouseholdNotifier) {
        return container.read(householdNotifierProvider) as T;
      }
      if (T == PracticeContinuityNotifier) {
        return container.read(practiceContinuityNotifierProvider) as T;
      }
      if (T == GardenGrowthNotifier) {
        return container.read(gardenGrowthNotifierProvider) as T;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  GoRouter _resolveRouter({
    required _AppLaunchState launchState,
    required OnboardingRepository onboardingRepository,
  }) {
    _currentRouter = GoRouter(
      navigatorKey: _navigatorKey,
      initialLocation: launchState.initialRoute,
      routes: [
        GoRoute(
          path: AppRouteNames.shell,
          builder: (context, state) {
            final routedSnapshot = state.extra is OnboardingSnapshot
                ? state.extra as OnboardingSnapshot
                : launchState.completedSnapshot;
            return _BootRouteMarker(
              routeKey: const Key('boot-route-shell'),
              child: AppShellScreen(onboardingSnapshot: routedSnapshot),
            );
          },
        ),
        GoRoute(
          path: AppRouteNames.onboarding,
          builder: (context, state) => _BootRouteMarker(
            routeKey: Key('boot-route-onboarding'),
            child: OnboardingFlowScreen(
              audioControllerFactory: widget.audioControllerFactory,
            ),
          ),
        ),
        for (final path in AppRouteNames.legacyOnboardingPaths)
          GoRoute(
            path: path,
            redirect: (context, state) => AppRouteNames.onboarding,
          ),
        GoRoute(
          path: AppRouteNames.practice,
          builder: (context, state) {
            final routeEntry = PracticeRouteEntry.fromObject(state.extra);
            return PracticeSessionScreen(
              routeEntry: routeEntry,
              audioControllerFactory: widget.audioControllerFactory,
            );
          },
        ),
        GoRoute(
          path: AppRouteNames.account,
          builder: (context, state) => AccountEntryScreen(
            origin: accountEntryOriginFromRouteExtra(state.extra),
          ),
        ),
        GoRoute(
          path: '/me/settings',
          builder: (context, state) => const SettingsScreen(),
          routes: [
            GoRoute(
              path: 'reminder',
              builder: (context, state) => const ReminderSettingsScreen(),
            ),
            GoRoute(
              path: 'baby-profile',
              builder: (context, state) => const BabyProfileScreen(),
            ),
            GoRoute(
              path: 'caregiver',
              builder: (context, state) => const CaregiverPreferencesScreen(),
            ),
            GoRoute(
              path: 'playback',
              builder: (context, state) => const PlaybackPreferencesScreen(),
            ),
            GoRoute(
              path: 'help',
              builder: (context, state) => const HelpFeedbackScreen(),
            ),
            GoRoute(
              path: 'about',
              builder: (context, state) => const AboutScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/me/growth',
          builder: (context, state) =>
              const GardenGrowthCombinedScreen(initialTab: GrowthTab.growth),
        ),
      ],
    );
    return _currentRouter!;
  }

  Future<void> _retryLaunchState() async {
    setState(() {
      _launchStateFuture = _loadLaunchState();
    });
  }

  Future<_AppLaunchState> _loadLaunchState() async {
    // 1. 从 Riverpod provider graph 读取仓库
    //    assetPhraseServiceProvider 已在 main.dart 的 ProviderScope 中覆盖
    final practiceRepository = await ref.read(
      practiceRepositoryProvider.future,
    );
    final accountRepository = await ref.read(accountRepositoryProvider.future);
    final householdRepository = await ref.read(
      householdRepositoryProvider.future,
    );
    final mentorRepository = await ref.read(mentorRepositoryProvider.future);

    // 2. OnboardingRepository 需要 AppBootState 的 ID，手动构造
    final directory = await ref.read(appDirectoryProvider.future);
    final onboardingStore = OnboardingSnapshotStore(
      directoryResolver: () async => directory,
    );
    final onboardingFlowStore = OnboardingFlowStore(
      directoryResolver: () async => directory,
    );
    final onboardingRepository = OnboardingRepository(
      snapshotStore: onboardingStore,
      flowStore: onboardingFlowStore,
    );

    // 3. AuthState: 读取认证状态
    final authState = await AuthState.load(
      onboardingRepository: onboardingRepository,
      completedSnapshotLoader: widget.completedSnapshotLoader,
    );

    // 4. FeatureGates: 解析启动目标和 feature gates
    final featureGates = await FeatureGates.resolve(
      practiceRepository: practiceRepository,
      completedSnapshot: authState.completedSnapshot,
      primarySpaceId: widget.bootState.primarySpaceId!,
      primaryActivityId: widget.bootState.primaryActivityId!,
      continuitySeedTimeout: _bootContinuitySeedTimeout,
    );

    return _AppLaunchState(
      practiceRepository: practiceRepository,
      onboardingRepository: onboardingRepository,
      accountRepository: accountRepository,
      householdRepository: householdRepository,
      mentorRepository: mentorRepository,
      destination: featureGates.destination,
      starterArgs: featureGates.starterArgs,
      defaultPracticeArgs: featureGates.defaultPracticeArgs,
      continuitySeed: featureGates.continuitySeed,
      completedSnapshot: authState.completedSnapshot,
    );
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

class _ReentryOverlay extends ConsumerWidget {
  const _ReentryOverlay({this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final inviteCoordinator = ref.watch(inviteReentryCoordinatorProvider);
    final shareCoordinator = ref.watch(shareReentryCoordinatorProvider);
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
