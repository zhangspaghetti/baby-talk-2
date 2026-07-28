import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/app/widgets/app_haptics.dart';
import 'package:mobile/app/widgets/app_english_phrase.dart';
import 'package:mobile/app/widgets/app_shimmer.dart';
import 'package:mobile/app/widgets/app_surface_card.dart';
import 'package:mobile/app/widgets/xiaohe_fab.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/account/presentation/account_notifier.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/care_path/presentation/care_path_view_model.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_feature_flag.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';
import 'package:mobile/features/custom_scene/presentation/custom_scene_entry.dart';
import 'package:mobile/features/custom_scene/presentation/custom_scene_route_args.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_notifier.dart'
    show PracticeContinuityLoadStatusLabel;
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/widgets/home_botanical_header.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    this.onboardingSnapshot,
    this.embeddedInShell = false,
    this.customSceneEntryOpener,
  });

  final OnboardingSnapshot? onboardingSnapshot;
  final bool embeddedInShell;
  final CustomSceneEntryOpener? customSceneEntryOpener;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with RouteAware {
  int _lastRuntimeToken = -1;
  bool _accountHasHadActiveSession = false;
  ModalRoute<dynamic>? _subscribedRoute;
  String? _lastResolvedScopeLabel;
  AccountNotifier? _cachedAccountNotifier;
  String? _todayNavigationError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final accountNotifier = ref.read(accountNotifierProvider);
      _cachedAccountNotifier = accountNotifier;
      unawaited(accountNotifier.initialize());
      accountNotifier.addListener(_handleAccountRuntimeChange);
      final gardenGrowthNotifier = ref.read(gardenGrowthNotifierProvider);
      unawaited(gardenGrowthNotifier.initialize());
      final continuityNotifier = ref.read(practiceContinuityNotifierProvider);
      unawaited(
        continuityNotifier.configureStarterArgs(
          _resolveStarterArgs(),
          reason: 'home_bootstrap',
        ),
      );
      unawaited(continuityNotifier.initialize(reason: 'home_bootstrap'));
      unawaited(_refreshCarePath());
    });
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onboardingSnapshot != widget.onboardingSnapshot) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(
          _syncContinuityStarterArgs(reason: 'onboarding_snapshot_changed'),
        );
        unawaited(_refreshCarePath());
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_subscribedRoute != route && route is PageRoute<dynamic>) {
      if (_subscribedRoute is PageRoute<dynamic>) {
        appRouteObserver.unsubscribe(this);
      }
      _subscribedRoute = route;
      appRouteObserver.subscribe(this, route);
    }

    final resolvedArgs = _resolveStarterArgs();
    final resolvedScopeLabel = resolvedArgs?.scopeLabel;
    if (_lastResolvedScopeLabel != resolvedScopeLabel) {
      _lastResolvedScopeLabel = resolvedScopeLabel;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(
          _syncContinuityStarterArgs(reason: 'starter_context_changed'),
        );
        unawaited(_refreshCarePath());
      });
    }
  }

  @override
  void didPopNext() {
    ref.read(accountNotifierProvider).handleHomeVisible();
    final gardenGrowthNotifier = ref.read(gardenGrowthNotifierProvider);
    unawaited(gardenGrowthNotifier.refresh());
    unawaited(_refreshContinuity(reason: 'practice_return'));
    unawaited(_refreshCarePath());
  }

  @override
  void dispose() {
    _cachedAccountNotifier?.removeListener(_handleAccountRuntimeChange);
    if (_subscribedRoute is PageRoute<dynamic>) {
      appRouteObserver.unsubscribe(this);
    }
    super.dispose();
  }

  void _handleAccountRuntimeChange() {
    if (!mounted) {
      return;
    }
    final accountNotifier = ref.read(accountNotifierProvider);
    if (_lastRuntimeToken == accountNotifier.runtimeChangeToken) {
      return;
    }
    _lastRuntimeToken = accountNotifier.runtimeChangeToken;
    // Track whether account has ever been active (registered/syncing)
    if (!accountNotifier.isSignedOut &&
        !accountNotifier.isRevoked &&
        !accountNotifier.isDeleted &&
        !accountNotifier.isLocalOnly) {
      _accountHasHadActiveSession = true;
    }
    if (accountNotifier.isSignedOut ||
        accountNotifier.isRevoked ||
        accountNotifier.isDeleted) {
      // Only reset downstream notifiers when account was previously active
      // (prevents accidental local data wipe on first launch before login)
      if (_accountHasHadActiveSession) {
        ref.read(practiceContinuityNotifierProvider).resetToSafeEmpty();
        ref.read(carePathNotifierProvider).resetToSafeEmpty();
        ref.read(gardenGrowthNotifierProvider).resetToSafeEmpty();
        ref.read(householdNotifierProvider).resetToSafeEmpty();
      }
      return;
    }
    if (accountNotifier.isLocalOnly) {
      // localOnly user's account state is stable; boot seed is up-to-date
      return;
    }
    unawaited(_refreshContinuity(reason: 'account_runtime_change'));
    unawaited(_refreshCarePath());
    final gardenGrowthNotifier = ref.read(gardenGrowthNotifierProvider);
    unawaited(gardenGrowthNotifier.refresh());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final continuityNotifier = ref.watch(practiceContinuityNotifierProvider);
    final carePathNotifier = ref.watch(carePathNotifierProvider);
    final carePathViewModel = carePathNotifier.viewModel;
    final customSceneEnabled = ref.watch(customSceneFeatureEnabledProvider);
    final isInitialCarePathLoading =
        carePathViewModel.isLoading && carePathViewModel.moment == null;

    final body = SafeArea(
      top: !widget.embeddedInShell,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayoutConstants.maxContentWidth,
          ),
          child: continuityNotifier.isInitialLoading || isInitialCarePathLoading
              ? const _HomeLoadingShimmer()
              : RefreshIndicator(
                  onRefresh: () async {
                    AppHaptics.lightTap();
                    await _refreshTodaySurface(reason: 'pull_to_refresh');
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      0,
                      widget.embeddedInShell ? 0 : 0,
                      0,
                      widget.embeddedInShell ? 120 : 32,
                    ),
                    children: [
                      // Botanical header with title and settings
                      const HomeBotanicalHeader(),

                      // Content area with padding
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppLayoutConstants.spacingLg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            _HomeTodayCareNodeCard(
                              viewModel: carePathViewModel,
                              navigationError: _todayNavigationError,
                              onStart: _openCurrentCareMoment,
                              showCustomSceneEntry:
                                  customSceneEnabled &&
                                  _shouldOfferCustomSceneToday(
                                    carePathViewModel,
                                  ),
                              onOpenCustomScene: () =>
                                  (widget.customSceneEntryOpener ??
                                  _openCustomScene)(
                                    context,
                                    CustomSceneEntrySource.today,
                                  ),
                            ),

                            const SizedBox(height: 24),

                            if (kDebugMode) ...[
                              const SizedBox(height: 12),
                              Text(
                                'continuity: ${continuityNotifier.status.label}${continuityNotifier.lastRefreshReason == null ? '' : ' · refresh: ${continuityNotifier.lastRefreshReason}'}',
                                key: const Key('home-debug-status'),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: colors.textMuted),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );

    if (widget.embeddedInShell) {
      return body;
    }

    return Scaffold(
      floatingActionButton: const XiaoheFab(
        key: Key('home-mentor-fab'),
        launcher: 'home_fab',
        surface: 'standalone_home',
        small: true,
      ),
      body: body,
    );
  }

  Future<void> _syncContinuityStarterArgs({required String reason}) async {
    final continuityNotifier = ref.read(practiceContinuityNotifierProvider);
    await continuityNotifier.configureStarterArgs(
      _resolveStarterArgs(),
      reason: reason,
    );
  }

  Future<void> _refreshTodaySurface({required String reason}) async {
    await _refreshContinuity(reason: reason);
    await _refreshCarePath();
    await ref.read(gardenGrowthNotifierProvider).refresh();
  }

  Future<void> _refreshContinuity({required String reason}) async {
    final continuityNotifier = ref.read(practiceContinuityNotifierProvider);
    final starterArgs = _resolveStarterArgs();
    if (continuityNotifier.starterArgs?.scopeLabel != starterArgs?.scopeLabel) {
      await continuityNotifier.configureStarterArgs(
        starterArgs,
        reason: reason,
      );
      return;
    }
    await continuityNotifier.refresh(reason: reason);
  }

  Future<void> _refreshCarePath() async {
    final carePathNotifier = ref.read(carePathNotifierProvider);
    final starterArgs = _resolveStarterArgs();
    await carePathNotifier.initialize();
    await carePathNotifier.loadCurrentUtterance(
      starterSpaceId: starterArgs?.spaceId,
      starterActivityId: starterArgs?.activityId,
    );
  }

  Future<void> _openCurrentCareMoment() async {
    final moment = ref.read(carePathNotifierProvider).viewModel.moment;
    final routeArgs = PracticeRouteArgs.maybeCreate(
      spaceId: moment?.spaceId,
      activityId: moment?.activityId,
    );
    if (routeArgs == null) {
      setState(() {
        _todayNavigationError = '这个场景暂时打不开，请稍后再试。';
      });
      return;
    }

    setState(() {
      _todayNavigationError = null;
    });

    try {
      await routeArgs.push<void>(context);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _todayNavigationError = '这个场景暂时打不开，请稍后再试。';
      });
    }
  }

  bool _shouldOfferCustomSceneToday(CarePathViewModel viewModel) {
    final moment = viewModel.moment;
    final hasOpenableMoment =
        moment != null &&
        moment.nodeState != CarePathNodeState.unavailable &&
        moment.spaceId.trim().isNotEmpty &&
        moment.activityId.trim().isNotEmpty;
    return shouldOfferCustomSceneFromToday(
      CustomSceneTodayEntryContext(
        currentRecommendationMatches:
            hasOpenableMoment && !viewModel.isHeldWithFallback,
        userSkippedRecommendation: false,
        hasOpenableMoment: hasOpenableMoment,
      ),
    );
  }

  Future<void> _openCustomScene(
    BuildContext context,
    CustomSceneEntrySource source,
  ) {
    return CustomSceneRouteArgs(entrySource: source).push<void>(context);
  }

  PracticeRouteArgs? _resolveStarterArgs() {
    final snapshotArgs = PracticeRouteArgs.maybeCreate(
      spaceId: widget.onboardingSnapshot?.starterSpaceId,
      activityId: widget.onboardingSnapshot?.starterActivityId,
    );
    if (snapshotArgs != null) {
      return snapshotArgs;
    }
    try {
      return ref.read(defaultPracticeRouteArgsProvider);
    } catch (_) {
      return null;
    }
  }
}

class _HomeTodayCareNodeCard extends StatelessWidget {
  const _HomeTodayCareNodeCard({
    required this.viewModel,
    required this.navigationError,
    required this.onStart,
    required this.showCustomSceneEntry,
    required this.onOpenCustomScene,
  });

  final CarePathViewModel viewModel;
  final String? navigationError;
  final VoidCallback onStart;
  final bool showCustomSceneEntry;
  final VoidCallback onOpenCustomScene;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final moment = viewModel.moment;
    final utterance = viewModel.currentUtterance;
    final hasOpenableMoment =
        moment != null &&
        moment.nodeState != CarePathNodeState.unavailable &&
        moment.spaceId.trim().isNotEmpty &&
        moment.activityId.trim().isNotEmpty;
    final title = _clean(moment?.title) ?? '今天的照护时刻';
    final actionLabel = _carePathCopy(_clean(moment?.careActionLabel));
    final sceneLabel =
        _clean(moment?.sceneTag) ?? _clean(moment?.spaceTitle) ?? '照护场景';
    final coachTip =
        _carePathCopy(_clean(utterance?.whenToSay)) ??
        _carePathCopy(_clean(moment?.coachTip));
    final ctaLabel = utterance == null ? '继续这个场景' : '现在说一句';

    return AppSurfaceCard(
      key: const Key('home-today-care-node-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '今天',
            key: const Key('home-today-label'),
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.accentDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppLayoutConstants.spacingXs),
          Text(
            title,
            key: const Key('home-today-care-moment-title'),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppLayoutConstants.spacingSm),
          Wrap(
            spacing: AppLayoutConstants.spacingXs,
            runSpacing: AppLayoutConstants.spacingXs,
            children: [
              _CareNodeChip(label: sceneLabel),
              if (moment?.nodeState == CarePathNodeState.doneToday)
                const _CareNodeChip(label: '今日已照护'),
            ],
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: AppLayoutConstants.spacingMd),
            Text(
              actionLabel,
              key: const Key('home-today-care-action'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: AppLayoutConstants.spacingLg),
          if (utterance != null) ...[
            Text(
              '现在说一句',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppLayoutConstants.spacingXs),
            AppEnglishPhrase(
              utterance.english,
              key: const Key('home-today-utterance-english'),
            ),
            if (_clean(utterance.chinese) != null) ...[
              const SizedBox(height: AppLayoutConstants.spacingXs),
              Text(
                utterance.chinese,
                key: const Key('home-today-utterance-chinese'),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ],
            if (_clean(utterance.pronunciation) != null) ...[
              const SizedBox(height: AppLayoutConstants.spacingXs),
              Text(
                utterance.pronunciation,
                key: const Key('home-today-utterance-pronunciation'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textMuted,
                ),
              ),
            ],
          ] else ...[
            Text(
              viewModel.message ?? '当前照护节点暂时不可用。',
              key: const Key('home-today-held-message'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
          if (coachTip != null) ...[
            const SizedBox(height: AppLayoutConstants.spacingMd),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 18,
                  color: colors.textMuted,
                ),
                const SizedBox(width: AppLayoutConstants.spacingXs),
                Expanded(
                  child: Text(
                    coachTip,
                    key: const Key('home-today-care-tip'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textMuted,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (navigationError != null) ...[
            const SizedBox(height: AppLayoutConstants.spacingMd),
            Text(
              navigationError!,
              key: const Key('home-today-navigation-error'),
              style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ],
          const SizedBox(height: AppLayoutConstants.spacingLg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('home-today-primary-cta'),
              onPressed: hasOpenableMoment ? onStart : null,
              child: Text(ctaLabel),
            ),
          ),
          if (showCustomSceneEntry) ...[
            const SizedBox(height: AppLayoutConstants.spacingXs),
            CustomSceneEntryLink(
              source: CustomSceneEntrySource.today,
              onOpen: (_, _) async => onOpenCustomScene(),
            ),
          ],
        ],
      ),
    );
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String? _carePathCopy(String? value) {
    if (value == null) {
      return null;
    }
    return value
        .replaceAll('练习', '照护')
        .replaceAll('课程', '场景')
        .replaceAll('学习进度', '照护节奏')
        .replaceAll('完成任务', '照护收尾')
        .replaceAll('短语', '表达')
        .replaceAll('1 of N', '当前节点');
  }
}

class _CareNodeChip extends StatelessWidget {
  const _CareNodeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppLayoutConstants.spacingSm,
        vertical: AppLayoutConstants.spacingXxs,
      ),
      decoration: BoxDecoration(
        color: colors.bgAccentSoft,
        borderRadius: BorderRadius.circular(AppLayoutConstants.pillRadius),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colors.accentDark,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Skeleton loading state using AppShimmer instead of the old 4px gray bar.
class _HomeLoadingShimmer extends StatelessWidget {
  const _HomeLoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        key: const Key('home-loading'),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppShimmer(width: 200, height: 24),
            const SizedBox(height: 16),
            AppShimmer(width: 160, height: 16),
            const SizedBox(height: 12),
            AppShimmer(width: 280, height: 12),
            const SizedBox(height: 8),
            AppShimmer(width: 220, height: 12),
          ],
        ),
      ),
    );
  }
}
