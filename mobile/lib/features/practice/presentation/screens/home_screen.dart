import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/account/presentation/account_view_model.dart';
import 'package:mobile/features/account/presentation/screens/account_entry_screen.dart';
import 'package:mobile/features/household/presentation/household_view_model.dart';
import 'package:mobile/features/household/presentation/widgets/household_shared_context_card.dart';
import 'package:mobile/features/mentor/presentation/widgets/mentor_panel_sheet.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
import 'package:mobile/features/practice/presentation/garden_growth_view_model.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_view_model.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/share/presentation/share_view_model.dart';
import 'package:mobile/features/share/presentation/widgets/share_callout_card.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.onboardingSnapshot,
    this.embeddedInShell = false,
  });

  final OnboardingSnapshot? onboardingSnapshot;
  final bool embeddedInShell;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  AccountViewModel? _accountViewModel;
  int _lastRuntimeToken = -1;
  ModalRoute<dynamic>? _subscribedRoute;
  String? _lastResolvedScopeLabel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final accountViewModel = context.read<AccountViewModel>();
      unawaited(accountViewModel.initialize());
      final gardenGrowthViewModel = context.read<GardenGrowthViewModel?>();
      if (gardenGrowthViewModel != null) {
        unawaited(gardenGrowthViewModel.initialize());
      }
      final continuityViewModel = context.read<PracticeContinuityViewModel?>();
      if (continuityViewModel != null) {
        unawaited(
          continuityViewModel.configureStarterArgs(
            _resolveStarterArgs(),
            reason: 'home_bootstrap',
          ),
        );
        unawaited(continuityViewModel.initialize(reason: 'home_bootstrap'));
      }
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

    final accountViewModel = context.read<AccountViewModel>();
    if (!identical(_accountViewModel, accountViewModel)) {
      _accountViewModel?.removeListener(_handleAccountRuntimeChange);
      _accountViewModel = accountViewModel;
      _lastRuntimeToken = accountViewModel.runtimeChangeToken;
      accountViewModel.addListener(_handleAccountRuntimeChange);
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
    context.read<AccountViewModel>().handleHomeVisible();
    final gardenGrowthViewModel = context.read<GardenGrowthViewModel?>();
    if (gardenGrowthViewModel != null) {
      unawaited(gardenGrowthViewModel.refresh());
    }
    unawaited(_refreshContinuity(reason: 'practice_return'));
  }

  @override
  void dispose() {
    _accountViewModel?.removeListener(_handleAccountRuntimeChange);
    if (_subscribedRoute is PageRoute<dynamic>) {
      appRouteObserver.unsubscribe(this);
    }
    super.dispose();
  }

  void _handleAccountRuntimeChange() {
    final accountViewModel = _accountViewModel;
    if (!mounted || accountViewModel == null) {
      return;
    }
    if (_lastRuntimeToken == accountViewModel.runtimeChangeToken) {
      return;
    }
    _lastRuntimeToken = accountViewModel.runtimeChangeToken;
    if (accountViewModel.isSignedOut ||
        accountViewModel.isRevoked ||
        accountViewModel.isDeleted) {
      // 会话已结束（logout/delete/revoke），重置下游 VM 清除陈旧数据
      context.read<PracticeContinuityViewModel?>()?.resetToSafeEmpty();
      context.read<GardenGrowthViewModel?>()?.resetToSafeEmpty();
      context.read<HouseholdViewModel?>()?.resetToSafeEmpty();
      return;
    }
    if (accountViewModel.isLocalOnly) {
      // localOnly 用户的账号状态稳定，boot seed 已是最新，无需额外操作
      return;
    }
    unawaited(_refreshContinuity(reason: 'account_runtime_change'));
    final gardenGrowthViewModel = context.read<GardenGrowthViewModel?>();
    if (gardenGrowthViewModel != null) {
      unawaited(gardenGrowthViewModel.refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final gardenGrowthViewModel = context.watch<GardenGrowthViewModel?>();
    final continuityViewModel = context.watch<PracticeContinuityViewModel?>();
    final householdViewModel = context.watch<HouseholdViewModel?>();
    final shareViewModel = context.watch<ShareViewModel?>();
    final hasResolvedContinuity =
        continuityViewModel?.hasResolvedRecommendation ?? false;
    final continuitySnapshot = hasResolvedContinuity
        ? continuityViewModel?.snapshot
        : null;
    final activity = hasResolvedContinuity
        ? continuityViewModel?.activitySnapshot
        : null;
    final recommendedActivity = hasResolvedContinuity
        ? continuitySnapshot?.recommendedActivity
        : null;
    final practiceArgs = continuityViewModel?.recommendedArgs;
    final canLaunchPractice =
        hasResolvedContinuity &&
        !(continuityViewModel?.isActionDisabled ?? true) &&
        practiceArgs != null &&
        activity != null;
    final stageMatch = _resolveStageMatch(widget.onboardingSnapshot);
    final starterPhrase = _resolveStarterPhrase(
      activity,
      widget.onboardingSnapshot,
    );
    final homeWarningMessage = _resolveHomeWarningMessage(continuityViewModel);
    final homeDisabledReason = continuityViewModel?.disabledReason;
    final sharedContext = householdViewModel?.snapshot.sharedContext;
    final localContinuityAt = continuitySnapshot?.cadence.lastEventTime;
    final sharedNextStepArgs = resolveHouseholdSharedNextStepArgs(
      sharedContext,
    );
    final isSharedOverlayNewer =
        continuityViewModel != null &&
        sharedContext != null &&
        isHouseholdSharedProjectionNewer(sharedContext, localContinuityAt);
    final shouldShowSharedOverlay =
        isSharedOverlayNewer && sharedNextStepArgs != null;
    final shouldShowSharedOverlayDisabled =
        isSharedOverlayNewer && sharedNextStepArgs == null;
    final body = SafeArea(
      top: !widget.embeddedInShell,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: continuityViewModel?.isInitialLoading ?? false
              ? const _HomeLoadingState()
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    widget.embeddedInShell ? 12 : 20,
                    20,
                    widget.embeddedInShell ? 120 : 32,
                  ),
                  children: [
                    if (widget.onboardingSnapshot != null) ...[
                      _LocalOnlyBanner(snapshot: widget.onboardingSnapshot!),
                      const SizedBox(height: 20),
                      _PersonalizedHero(
                        snapshot: widget.onboardingSnapshot!,
                        stageMatch: stageMatch,
                        starterPhrase: starterPhrase,
                        activitySceneTag: activity?.sceneTag,
                      ),
                      const SizedBox(height: 16),
                      _RecentResultCard(continuitySnapshot: continuitySnapshot),
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
                        _HomeBanner(
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
                        continuityViewModel == null
                            ? l.homeContinuityNotConnected
                            : l.homeTonightTryActivity,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        activity?.phrases.first.english ??
                            'Continuity unavailable.',
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(color: colors.english),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        continuityViewModel == null
                            ? l.homeWelcomeBack
                            : l.homeContinuitySharedNote,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      _RecentResultCard(continuitySnapshot: continuitySnapshot),
                    ],
                    const SizedBox(height: 20),
                    _TodaySceneCard(
                      activityId:
                          recommendedActivity?.activityId ?? 'safe-empty',
                      activityTitle:
                          activity?.title ?? l.continueEntryUnavailable,
                      activitySummary:
                          activity?.summary ??
                          _resolveSafeHomeSummary(continuityViewModel),
                      sceneTag: activity?.sceneTag,
                      recommendation: continuitySnapshot?.recommendation,
                      nextIncompleteActivity:
                          continuitySnapshot?.nextIncompleteActivity,
                      buttonLabel: _resolveButtonLabel(continuitySnapshot),
                      disabledReason: continuityViewModel == null
                          ? l.practiceEntryUnavailable
                          : homeDisabledReason,
                      onPressed: canLaunchPractice
                          ? () async {
                              await practiceArgs.push(context);
                            }
                          : null,
                    ),
                    const SizedBox(height: 20),
                    AccountStatusCard(
                      scopeKeyPrefix: 'home',
                      onboardingSnapshot: widget.onboardingSnapshot,
                    ),
                    const SizedBox(height: 20),
                    HouseholdSharedContextCard(
                      surfaceKeyPrefix: 'home',
                      viewModel: householdViewModel,
                      title: l.sharedAttributionNextStep,
                      retryReason: 'home_household_manual_refresh',
                    ),
                    if (continuityViewModel == null) ...[
                      const SizedBox(height: 20),
                      _HomeBanner(
                        key: Key('home-continuity-provider-missing-banner'),
                        message: l.homePracticeUnavailable,
                        backgroundColor: colors.warningSoft,
                        foregroundColor: colors.warning,
                      ),
                    ],
                    if (continuitySnapshot?.fallbackReason != null) ...[
                      const SizedBox(height: 20),
                      _HomeBanner(
                        key: const Key('home-continuity-fallback-banner'),
                        message: continuitySnapshot!.fallbackReason!,
                        backgroundColor: colors.infoSoft,
                        foregroundColor: colors.info,
                      ),
                    ],
                    if (homeWarningMessage != null) ...[
                      const SizedBox(height: 20),
                      _HomeBanner(
                        key: const Key('home-continuity-warning-banner'),
                        message: homeWarningMessage,
                        backgroundColor: colors.warningSoft,
                        foregroundColor: colors.warning,
                        actionLabel: continuityViewModel == null
                            ? null
                            : l.homeReorganize,
                        onAction: continuityViewModel == null
                            ? null
                            : () => _refreshContinuity(
                                reason: 'home_manual_refresh',
                              ),
                      ),
                    ],
                    if (homeDisabledReason != null) ...[
                      const SizedBox(height: 20),
                      _HomeBanner(
                        key: const Key('home-continuity-disabled-banner'),
                        message: homeDisabledReason,
                        backgroundColor: colors.errorSoft,
                        foregroundColor: colors.error,
                        actionLabel: continuityViewModel == null
                            ? null
                            : l.retry,
                        onAction: continuityViewModel == null
                            ? null
                            : () => _refreshContinuity(reason: 'home_retry'),
                      ),
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
                      _HomeBanner(
                        key: const Key('home-shared-overlay-disabled-banner'),
                        message: householdSharedUnavailableNextStepMessage(
                          sharedContext,
                        ),
                        backgroundColor: colors.warningSoft,
                        foregroundColor: colors.warning,
                      ),
                    ],
                    const SizedBox(height: 16),
                    _WeekStatsCard(continuitySnapshot: continuitySnapshot),
                    const SizedBox(height: 16),
                    _GardenMiniEntry(viewModel: gardenGrowthViewModel),
                    const SizedBox(height: 16),
                    _GrowthSummaryCard(viewModel: gardenGrowthViewModel),
                    if (shareViewModel != null) ...[
                      const SizedBox(height: 16),
                      ShareCalloutCard(
                        surfaceKeyPrefix: 'home',
                        viewModel: shareViewModel,
                        sectionLabel: l.homeShareGrowthFamily,
                        emptyMessage: l.homeShareWaitStable,
                        onShare: () => shareViewModel.shareCurrent(),
                      ),
                    ],
                    if (kDebugMode) ...[
                      const SizedBox(height: 12),
                      Text(
                        'continuity: ${continuityViewModel?.status.label ?? 'missing_provider'}${continuityViewModel?.lastRefreshReason == null ? '' : ' · refresh: ${continuityViewModel!.lastRefreshReason}'}',
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
    );

    if (widget.embeddedInShell) {
      return body;
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        key: const Key('home-mentor-fab'),
        tooltip: l.mentorName,
        onPressed: () => openMentorPanelSheet(
          context,
          launcher: 'home_fab',
          surface: 'standalone_home',
        ),
        child: const Icon(Icons.auto_awesome),
      ),
      body: body,
    );
  }

  Future<void> _syncContinuityStarterArgs({required String reason}) async {
    final continuityViewModel = context.read<PracticeContinuityViewModel?>();
    if (continuityViewModel == null) {
      return;
    }
    await continuityViewModel.configureStarterArgs(
      _resolveStarterArgs(),
      reason: reason,
    );
  }

  Future<void> _refreshContinuity({required String reason}) async {
    final continuityViewModel = context.read<PracticeContinuityViewModel?>();
    if (continuityViewModel == null) {
      return;
    }
    final starterArgs = _resolveStarterArgs();
    if (continuityViewModel.starterArgs?.scopeLabel !=
        starterArgs?.scopeLabel) {
      await continuityViewModel.configureStarterArgs(
        starterArgs,
        reason: reason,
      );
      return;
    }
    await continuityViewModel.refresh(reason: reason);
  }

  String? _resolveHomeWarningMessage(
    PracticeContinuityViewModel? continuityViewModel,
  ) {
    final warningMessage = continuityViewModel?.warningMessage?.trim();
    if (warningMessage == null || warningMessage.isEmpty) {
      return null;
    }
    return warningMessage;
  }

  String _resolveSafeHomeSummary(
    PracticeContinuityViewModel? continuityViewModel,
  ) {
    final l = AppLocalizations.of(context)!;
    if (continuityViewModel == null) {
      return l.homePracticeAdviceUnavailable;
    }
    if (continuityViewModel.isInitialLoading) {
      return l.homeOrganizingContinuity;
    }
    if (continuityViewModel.disabledReason != null) {
      return continuityViewModel.disabledReason!;
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
    return Provider.of<PracticeRouteArgs?>(context, listen: false);
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
      return '未找到本地记录，可以直接开始 guest 练习。';
    }
    return '已从本地恢复最近一次练习结果，共 ${snapshot.cadence.totalKnownEvents} 条记录。';
  }
}

class _LocalOnlyBanner extends StatelessWidget {
  const _LocalOnlyBanner({required this.snapshot});

  final OnboardingSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    return Container(
      key: const Key('home-local-only-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.bgSunken,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.lock_outline,
              color: colors.textSecondary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l.homeLocalOnlyBanner(snapshot.childDisplayName),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalizedHero extends StatelessWidget {
  const _PersonalizedHero({
    required this.snapshot,
    required this.stageMatch,
    required this.starterPhrase,
    required this.activitySceneTag,
  });

  final OnboardingSnapshot snapshot;
  final StageMatch? stageMatch;
  final PracticePhrase? starterPhrase;
  final String? activitySceneTag;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineSoft),
        boxShadow: colors.warmShadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                key: const Key('home-stage-pill'),
                label: Text(stageMatch?.title ?? snapshot.ageBucket.label),
              ),
              if (activitySceneTag != null &&
                  activitySceneTag!.trim().isNotEmpty)
                Chip(label: Text(activitySceneTag!)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l.homePersonalizedHeading(snapshot.childDisplayName),
            key: const Key('personalized-home-heading'),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            stageMatch?.summary ?? l.homeDefaultStageSummary,
            key: const Key('personalized-home-stage-summary'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Container(
            key: starterPhrase != null
                ? const Key('home-starter-seed')
                : const Key('home-starter-seed-loading'),
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.englishSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.homeFirstSeed, style: theme.textTheme.labelMedium),
                const SizedBox(height: 10),
                Text(
                  starterPhrase?.english ?? 'Bath time, baby.',
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontSize: 28,
                    color: colors.english,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  starterPhrase?.chinese ?? l.homeStartBathTime,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodaySceneCard extends StatelessWidget {
  const _TodaySceneCard({
    required this.activityId,
    required this.activityTitle,
    required this.activitySummary,
    required this.sceneTag,
    required this.recommendation,
    required this.nextIncompleteActivity,
    required this.buttonLabel,
    required this.disabledReason,
    required this.onPressed,
  });

  final String activityId;
  final String activityTitle;
  final String activitySummary;
  final String? sceneTag;
  final PracticeContinuityRecommendation? recommendation;
  final PracticeCatalogActivitySummary? nextIncompleteActivity;
  final String buttonLabel;
  final String? disabledReason;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    return Semantics(
      label: '今日场景: $activityTitle',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sceneTag != null && sceneTag!.trim().isNotEmpty)
                Chip(label: Text(sceneTag!)),
              const SizedBox(height: 16),
              Text(
                activityTitle,
                key: ValueKey('home-hero-activity-$activityId'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                recommendation?.reasonLabel ?? l.homeContinuityUnavailable,
                key: ValueKey('home-continuity-reason-$activityId'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                activitySummary,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (nextIncompleteActivity != null &&
                  nextIncompleteActivity!.activityId != activityId) ...[
                const SizedBox(height: 12),
                Text(
                  l.homeNextAlternative(nextIncompleteActivity!.title),
                  key: ValueKey(
                    'home-next-incomplete-${nextIncompleteActivity!.activityId}',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (disabledReason != null) ...[
                const SizedBox(height: 12),
                Text(
                  disabledReason!,
                  key: ValueKey('home-start-disabled-$activityId'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                key: const Key('home-start-practice'),
                onPressed: onPressed,
                child: Text(buttonLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekStatsCard extends StatelessWidget {
  const _WeekStatsCard({required this.continuitySnapshot});

  final PracticeContinuitySnapshot? continuitySnapshot;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final recommendedActivity = continuitySnapshot?.recommendedActivity;
    final cadence = continuitySnapshot?.cadence;
    return Semantics(
      label: '本周练习统计',
      child: Container(
        key: ValueKey(
          'home-week-stats-${recommendedActivity?.activityId ?? 'loading'}',
        ),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.bgSunken,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: _StatCell(
                label: l.homeRecommendedActivity,
                value: recommendedActivity?.title ?? l.homeOrganizing,
                hint:
                    continuitySnapshot?.recommendation.reasonLabel ??
                    l.homeWaitingContinuity,
              ),
            ),
            Container(width: 1, height: 40, color: colors.outlineSoft),
            Expanded(
              child: _StatCell(
                key: ValueKey(
                  'home-cadence-summary-${recommendedActivity?.activityId ?? 'loading'}',
                ),
                label: l.homeCadence,
                value: cadence?.headline ?? l.homeOrganizing,
                hint: cadence?.detail ?? l.homeDerivingCadence,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    super.key,
    required this.label,
    required this.value,
    required this.hint,
  });

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(hint, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _GardenMiniEntry extends StatelessWidget {
  const _GardenMiniEntry({required this.viewModel});

  final GardenGrowthViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final effectiveViewModel = viewModel;
    final snapshot =
        effectiveViewModel?.snapshot ?? GardenGrowthSnapshot.empty();
    final primarySpace = snapshot.primarySpace;
    final primaryActivity = snapshot.primaryActivity;
    final status = effectiveViewModel?.status ?? GardenGrowthLoadStatus.empty;

    String title;
    String body;
    Color backgroundColor = colors.successSoft;
    Color foregroundColor = colors.success;

    switch (status) {
      case GardenGrowthLoadStatus.loading:
      case GardenGrowthLoadStatus.idle:
        title = l.homeGardenOrganizing;
        body = l.homeGardenProjecting;
        backgroundColor = colors.bgSunken;
        foregroundColor = colors.textSecondary;
        break;
      case GardenGrowthLoadStatus.error:
        title = l.homeGardenNotReady;
        body = effectiveViewModel?.message ?? l.homeGardenKeepStable;
        backgroundColor = colors.warningSoft;
        foregroundColor = colors.warning;
        break;
      case GardenGrowthLoadStatus.empty:
        title = l.homeGardenStartFirst;
        body = l.homeGardenNoPractice;
        backgroundColor = colors.bgAccentSoft;
        foregroundColor = colors.accentDark;
        break;
      case GardenGrowthLoadStatus.ready:
        title = primarySpace == null
            ? l.homeGardenReady
            : l.homeGardenSpaceStage(
                primarySpace.title,
                primarySpace.stage.label,
              );
        body = primaryActivity == null
            ? l.homeGardenChanges
            : l.homeGardenActivityDetail(
                primaryActivity.title,
                primaryActivity.stage.label,
                primaryActivity.careNote,
              );
        break;
    }

    return Semantics(
      label: '成长花园: $title',
      child: Container(
        key: const Key('home-garden-mini-entry'),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.homeGrowthGarden,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              key: const Key('home-garden-mini-entry-title'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: foregroundColor),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: foregroundColor),
            ),
            if (snapshot.hasIssues && snapshot.projectionWarning != null) ...[
              const SizedBox(height: 10),
              Text(
                snapshot.projectionWarning!,
                key: const Key('home-garden-mini-entry-warning'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: foregroundColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GrowthSummaryCard extends StatelessWidget {
  const _GrowthSummaryCard({required this.viewModel});

  final GardenGrowthViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final effectiveViewModel = viewModel;
    final snapshot =
        effectiveViewModel?.snapshot ?? GardenGrowthSnapshot.empty();
    final impact = snapshot.latestImpact;

    String title;
    String body;

    if (effectiveViewModel?.hasError ?? false) {
      title = l.homeGrowthUnavailable;
      body = effectiveViewModel?.message ?? l.homeGrowthFallback;
    } else if (impact == null ||
        effectiveViewModel == null ||
        effectiveViewModel.isEmpty) {
      title = l.homeGrowthPlaceholder;
      body = l.homeGrowthAfterPractice;
    } else {
      title = impact.headline;
      body = impact.detail;
    }

    return Container(
      key: const Key('home-growth-summary'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineSoft),
        boxShadow: colors.warmShadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.homeGrowthSummaryLabel,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            key: const Key('home-growth-summary-title'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
          if (snapshot.hasIssues && snapshot.projectionWarning != null) ...[
            const SizedBox(height: 10),
            Text(
              snapshot.projectionWarning!,
              key: const Key('home-growth-summary-warning'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentResultCard extends StatelessWidget {
  const _RecentResultCard({required this.continuitySnapshot});

  final PracticeContinuitySnapshot? continuitySnapshot;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final recommendedActivity = continuitySnapshot?.recommendedActivity;
    final recentResult = recommendedActivity?.recentResult;
    final activityId = recommendedActivity?.activityId ?? 'empty';

    return Container(
      key: ValueKey('recent-result-$activityId'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.bgSunken,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.homeRecentLocalResult,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (recentResult == null)
            Text(
              continuitySnapshot?.fallbackReason ?? l.homeNoLocalRecords,
              key: const Key('recent-result-empty'),
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            Column(
              key: const Key('recent-result-summary'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${recommendedActivity!.title} · ${recentResult.phraseEnglish} · ${_labelForReaction(l, recentResult.reactionType)}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l.homeRecentResultDetail(
                    recommendedActivity.totalEvents.toString(),
                    _formatTime(recentResult.eventTime),
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _labelForReaction(AppLocalizations l, BabyReactionType reactionType) {
    switch (reactionType) {
      case BabyReactionType.calm:
        return l.reactionCalm;
      case BabyReactionType.engaged:
        return l.reactionEngaged;
      case BabyReactionType.imitated:
        return l.reactionImitated;
      case BabyReactionType.needsBreak:
        return l.reactionNeedsBreak;
    }
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _HomeLoadingState extends StatelessWidget {
  const _HomeLoadingState();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          key: const Key('home-loading'),
          height: 4,
          width: 80,
          decoration: BoxDecoration(
            color: colors.outlineSoft,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _HomeBanner extends StatelessWidget {
  const _HomeBanner({
    super.key,
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final Color backgroundColor;
  final Color foregroundColor;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
