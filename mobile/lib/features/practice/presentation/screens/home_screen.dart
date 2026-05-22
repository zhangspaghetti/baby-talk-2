import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/app/widgets/app_banner.dart';
import 'package:mobile/app/widgets/app_haptics.dart';
import 'package:mobile/app/widgets/app_shimmer.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/account/presentation/account_notifier.dart';
import 'package:mobile/features/account/presentation/screens/account_entry_screen.dart';
import 'package:mobile/features/household/presentation/widgets/household_shared_context_card.dart';
import 'package:mobile/features/mentor/presentation/widgets/mentor_panel_sheet.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_notifier.dart'
    show PracticeContinuityLoadStatusLabel;
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/widgets/home_garden_mini_entry.dart';
import 'package:mobile/features/practice/presentation/widgets/home_growth_summary_card.dart';
import 'package:mobile/features/practice/presentation/widgets/home_personalized_hero.dart';
import 'package:mobile/features/practice/presentation/widgets/home_recent_result_card.dart';
import 'package:mobile/features/practice/presentation/widgets/home_today_scene_card.dart';
import 'package:mobile/features/practice/presentation/widgets/home_week_stats_card.dart';
import 'package:mobile/features/share/presentation/widgets/share_callout_card.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:provider/provider.dart' as old_provider;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    this.onboardingSnapshot,
    this.embeddedInShell = false,
  });

  final OnboardingSnapshot? onboardingSnapshot;
  final bool embeddedInShell;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with RouteAware {
  int _lastRuntimeToken = -1;
  bool _accountHasHadActiveSession = false;
  ModalRoute<dynamic>? _subscribedRoute;
  String? _lastResolvedScopeLabel;
  AccountNotifier? _cachedAccountNotifier;

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
      });
    }
  }

  @override
  void didPopNext() {
    ref.read(accountNotifierProvider).handleHomeVisible();
    final gardenGrowthNotifier = ref.read(gardenGrowthNotifierProvider);
    unawaited(gardenGrowthNotifier.refresh());
    unawaited(_refreshContinuity(reason: 'practice_return'));
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
    final gardenGrowthNotifier = ref.read(gardenGrowthNotifierProvider);
    unawaited(gardenGrowthNotifier.refresh());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final gardenGrowthNotifier = ref.watch(gardenGrowthNotifierProvider);
    final continuityNotifier = ref.watch(practiceContinuityNotifierProvider);
    final householdNotifier = ref.watch(householdNotifierProvider);
    final shareNotifier = ref.watch(shareNotifierProvider);
    final hasResolvedContinuity = continuityNotifier.hasResolvedRecommendation;
    final continuitySnapshot = hasResolvedContinuity
        ? continuityNotifier.snapshot
        : null;
    final activity = hasResolvedContinuity
        ? continuityNotifier.activitySnapshot
        : null;
    final recommendedActivity = hasResolvedContinuity
        ? continuitySnapshot?.recommendedActivity
        : null;
    final practiceArgs = continuityNotifier.recommendedArgs;
    final canLaunchPractice =
        hasResolvedContinuity &&
        !continuityNotifier.isActionDisabled &&
        practiceArgs != null &&
        activity != null;
    final stageMatch = _resolveStageMatch(widget.onboardingSnapshot);
    final starterPhrase = _resolveStarterPhrase(
      activity,
      widget.onboardingSnapshot,
    );
    final homeWarningMessage = _resolveHomeWarningMessage(continuityNotifier);
    final homeDisabledReason = continuityNotifier.disabledReason == null
        ? null
        : l.homeContinuityDisabledNote;
    final sharedContext = householdNotifier.snapshot.sharedContext;
    final localContinuityAt = continuitySnapshot?.cadence.lastEventTime;
    final sharedNextStepArgs = resolveHouseholdSharedNextStepArgs(
      sharedContext,
    );
    final isSharedOverlayNewer =
        sharedContext != null &&
        isHouseholdSharedProjectionNewer(sharedContext, localContinuityAt);
    final shouldShowSharedOverlay =
        isSharedOverlayNewer && sharedNextStepArgs != null;
    final shouldShowSharedOverlayDisabled =
        isSharedOverlayNewer && sharedNextStepArgs == null;

    // Banner priority: error > warning > info (at most 1 visible)
    final banner = _resolveTopBanner(
      continuityNotifier: continuityNotifier,
      homeWarningMessage: homeWarningMessage,
      homeDisabledReason: homeDisabledReason,
      colors: colors,
      l: l,
    );

    final body = SafeArea(
      top: !widget.embeddedInShell,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayoutConstants.maxContentWidth,
          ),
          child: continuityNotifier.isInitialLoading
              ? const _HomeLoadingShimmer()
              : RefreshIndicator(
                  onRefresh: () async {
                    AppHaptics.lightTap();
                    await _refreshContinuity(reason: 'pull_to_refresh');
                    await gardenGrowthNotifier.refresh();
                  },
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      widget.embeddedInShell ? 12 : 20,
                      20,
                      widget.embeddedInShell ? 120 : 32,
                    ),
                    children: [
                      const SizedBox(height: 20),
                      HomeTodaySceneCard(
                        activityId:
                            recommendedActivity?.activityId ?? 'safe-empty',
                        activityTitle:
                            activity?.title ?? l.continueEntryUnavailable,
                        activitySummary:
                            activity?.summary ??
                            _resolveSafeHomeSummary(continuityNotifier),
                        sceneTag: activity?.sceneTag,
                        recommendation: continuitySnapshot?.recommendation,
                        nextIncompleteActivity:
                            continuitySnapshot?.nextIncompleteActivity,
                        buttonLabel: _resolveButtonLabel(continuitySnapshot),
                        disabledReason: homeDisabledReason,
                        onPressed: canLaunchPractice
                            ? () async {
                                await practiceArgs.push(context);
                                if (!mounted) {
                                  return;
                                }
                                await _refreshContinuity(
                                  reason: 'practice_return',
                                );
                                await gardenGrowthNotifier.refresh();
                              }
                            : null,
                      ),
                      if (widget.onboardingSnapshot != null) ...[
                        AppBanner(
                          key: const Key('home-local-only-banner'),
                          message: l.homeLocalOnlyBanner(
                            widget.onboardingSnapshot!.childDisplayName,
                          ),
                          backgroundColor: colors.bgSunken,
                          foregroundColor: colors.textSecondary,
                          icon: Icons.lock_outline,
                        ),
                        const SizedBox(height: 20),
                        HomePersonalizedHero(
                          snapshot: widget.onboardingSnapshot!,
                          stageMatch: stageMatch,
                          starterPhrase: starterPhrase,
                          activitySceneTag: activity?.sceneTag,
                        ),
                        const SizedBox(height: 16),
                        HomeRecentResultCard(
                          continuitySnapshot: continuitySnapshot,
                        ),
                      ] else ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(label: Text(l.localMode)),
                            Chip(label: Text(l.guest)),
                          ],
                        ),
                        if (hasResolvedContinuity) ...[
                          const SizedBox(height: 12),
                          AppBanner(
                            key: const Key('home-restore-banner'),
                            message: _buildGuestRestoreMessage(
                              continuitySnapshot,
                            ),
                            backgroundColor: colors.infoSoft,
                            foregroundColor: colors.info,
                          ),
                        ],
                        const SizedBox(height: 24),
                        Text(
                          continuityNotifier.hasResolvedRecommendation
                              ? l.homeTonightTryActivity
                              : l.homeContinuityNotConnected,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          activity?.phrases.first.english ?? '先从熟悉短句开始。',
                          style: Theme.of(context).textTheme.displayMedium
                              ?.copyWith(color: colors.english),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          continuityNotifier.hasResolvedRecommendation
                              ? l.homeContinuitySharedNote
                              : l.homeWelcomeBack,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        HomeRecentResultCard(
                          continuitySnapshot: continuitySnapshot,
                        ),
                      ],
                      const SizedBox(height: 20),
                      AccountStatusCard(
                        scopeKeyPrefix: 'home',
                        onboardingSnapshot: widget.onboardingSnapshot,
                      ),
                      const SizedBox(height: 20),
                      HouseholdSharedContextCard(
                        surfaceKeyPrefix: 'home',
                        notifier: householdNotifier,
                        title: l.sharedAttributionNextStep,
                        retryReason: 'home_household_manual_refresh',
                      ),
                      // Dismissible banner (at most 1, priority: error > warning > info)
                      if (banner != null) ...[
                        const SizedBox(height: 20),
                        banner,
                      ],
                      if (shouldShowSharedOverlay) ...[
                        const SizedBox(height: 20),
                        HouseholdSharedPracticeOverlayCard(
                          surfaceKeyPrefix: 'home-shared-overlay',
                          sharedContext: sharedContext,
                          buttonLabel: l.enterSharedNextStep,
                        ),
                      ],
                      if (shouldShowSharedOverlayDisabled) ...[
                        const SizedBox(height: 20),
                        AppBanner(
                          key: const Key('home-shared-overlay-disabled-banner'),
                          message: householdSharedUnavailableNextStepMessage(
                            sharedContext,
                          ),
                          backgroundColor: colors.warningSoft,
                          foregroundColor: colors.warning,
                        ),
                      ],
                      const SizedBox(height: 16),
                      HomeWeekStatsCard(continuitySnapshot: continuitySnapshot),
                      const SizedBox(height: 16),
                      HomeGardenMiniEntry(notifier: gardenGrowthNotifier),
                      const SizedBox(height: 16),
                      HomeGrowthSummaryCard(notifier: gardenGrowthNotifier),
                      if (shareNotifier.hasShareDraft) ...[
                        const SizedBox(height: 16),
                        ShareCalloutCard(
                          surfaceKeyPrefix: 'home',
                          notifier: shareNotifier,
                          sectionLabel: l.homeShareGrowthFamily,
                          emptyMessage: l.homeShareWaitStable,
                          onShare: () => shareNotifier.shareCurrent(),
                        ),
                      ],
                      if (kDebugMode) ...[
                        const SizedBox(height: 12),
                        Text(
                          'continuity: ${continuityNotifier.status.label}${continuityNotifier.lastRefreshReason == null ? '' : ' · refresh: ${continuityNotifier.lastRefreshReason}'}',
                          key: const Key('home-continuity-status'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'boot: ready${continuitySnapshot?.catalog.installationId == null ? '' : ' · install: ${_shortInstallationId(continuitySnapshot!.catalog.installationId!)}'}',
                          key: const Key('boot-status-ready'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
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
      floatingActionButton: FloatingActionButton.small(
        key: const Key('home-mentor-fab'),
        tooltip: l.mentorName,
        onPressed: () {
          AppHaptics.lightTap();
          openMentorPanelSheet(
            context,
            launcher: 'home_fab',
            surface: 'standalone_home',
          );
        },
        child: const Icon(Icons.auto_awesome),
      ),
      body: body,
    );
  }

  /// Resolves the topmost banner based on priority: error > warning > info.
  ///
  /// Returns at most one banner widget; earlier banners in the list take priority.
  Widget? _resolveTopBanner({
    required dynamic continuityNotifier,
    required String? homeWarningMessage,
    required String? homeDisabledReason,
    required BabyTalkColors colors,
    required AppLocalizations l,
  }) {
    // 1. Disabled reason (error-level)
    if (homeDisabledReason != null) {
      return AppBanner(
        key: const Key('home-continuity-disabled-banner'),
        message: homeDisabledReason,
        backgroundColor: colors.errorSoft,
        foregroundColor: colors.error,
        actionLabel: l.retry,
        onAction: () => _refreshContinuity(reason: 'home_retry'),
        onDismiss: () {
          // Dismiss by clearing the disabled reason is not directly possible,
          // but the banner can be visually dismissed via haptic feedback.
          AppHaptics.lightTap();
        },
      );
    }

    // 2. Warning message
    if (homeWarningMessage != null) {
      return AppBanner(
        key: const Key('home-continuity-warning-banner'),
        message: homeWarningMessage,
        backgroundColor: colors.warningSoft,
        foregroundColor: colors.warning,
        actionLabel: l.homeReorganize,
        onAction: () => _refreshContinuity(reason: 'home_manual_refresh'),
        onDismiss: () {
          AppHaptics.lightTap();
        },
      );
    }

    // 3. Continuity provider missing (warning-level)
    if (continuityNotifier == null) {
      return AppBanner(
        key: const Key('home-continuity-provider-missing-banner'),
        message: l.homePracticeUnavailable,
        backgroundColor: colors.warningSoft,
        foregroundColor: colors.warning,
      );
    }

    // 4. Fallback reason (info-level)
    final fallbackReason = continuityNotifier.snapshot?.fallbackReason;
    if (fallbackReason != null) {
      return AppBanner(
        key: const Key('home-continuity-fallback-banner'),
        message: l.homeContinuityFallbackNote,
        backgroundColor: colors.infoSoft,
        foregroundColor: colors.info,
      );
    }

    return null;
  }

  Future<void> _syncContinuityStarterArgs({required String reason}) async {
    final continuityNotifier = ref.read(practiceContinuityNotifierProvider);
    await continuityNotifier.configureStarterArgs(
      _resolveStarterArgs(),
      reason: reason,
    );
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

  String? _resolveHomeWarningMessage(dynamic continuityNotifier) {
    final warningMessage = continuityNotifier.warningMessage?.trim();
    if (warningMessage == null || warningMessage.isEmpty) {
      return null;
    }
    final l = AppLocalizations.of(context)!;
    return l.homeContinuityWarningNote;
  }

  String _resolveSafeHomeSummary(dynamic continuityNotifier) {
    final l = AppLocalizations.of(context)!;
    if (continuityNotifier.isInitialLoading) {
      return l.homeOrganizingContinuity;
    }
    if (continuityNotifier.disabledReason != null) {
      return l.homeContinuityDisabledNote;
    }
    return l.homeContinuityNoActivity;
  }

  String _resolveButtonLabel(PracticeContinuitySnapshot? continuitySnapshot) {
    final l = AppLocalizations.of(context)!;
    final recommendedActivity = continuitySnapshot?.recommendedActivity;
    if (recommendedActivity == null ||
        recommendedActivity.recentResult == null) {
      return l.homeStartPractice;
    }
    return l.homeContinuePractice;
  }

  PracticeRouteArgs? _resolveStarterArgs() {
    final snapshotArgs = PracticeRouteArgs.maybeCreate(
      spaceId: widget.onboardingSnapshot?.starterSpaceId,
      activityId: widget.onboardingSnapshot?.starterActivityId,
    );
    if (snapshotArgs != null) {
      return snapshotArgs;
    }
    return old_provider.Provider.of<PracticeRouteArgs?>(context, listen: false);
  }

  StageMatch? _resolveStageMatch(OnboardingSnapshot? snapshot) {
    final stageId = snapshot?.currentStage.trim();
    if (stageId == null || stageId.isEmpty) {
      return null;
    }
    return StageMatchCatalog.maybeForStageId(stageId);
  }

  PracticePhrase? _resolveStarterPhrase(
    PracticeActivitySnapshot? activity,
    OnboardingSnapshot? snapshot,
  ) {
    if (activity == null || snapshot == null) {
      return null;
    }

    for (final phrase in activity.phrases) {
      if (phrase.phraseId == snapshot.starterPhraseId) {
        return phrase;
      }
    }
    if (activity.phrases.isNotEmpty) {
      return activity.phrases.first;
    }
    return null;
  }

  String _shortInstallationId(String installationId) {
    if (installationId.length <= 12) {
      return installationId;
    }
    return '${installationId.substring(0, 12)}…';
  }

  String _buildGuestRestoreMessage(PracticeContinuitySnapshot? snapshot) {
    if (snapshot == null || snapshot.cadence.totalKnownEvents == 0) {
      return '未找到本地记录，可以直接开始练习。';
    }
    return '已从本地恢复最近一次练习结果，共 ${snapshot.cadence.totalKnownEvents} 条记录。';
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
