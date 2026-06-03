import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/app/widgets/app_haptics.dart';
import 'package:mobile/app/widgets/app_shimmer.dart';
import 'package:mobile/app/widgets/xiaohe_fab.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/account/presentation/account_notifier.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_notifier.dart'
    show PracticeContinuityLoadStatusLabel;
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/widgets/home_botanical_header.dart';
import 'package:mobile/features/practice/presentation/widgets/home_progress_bar.dart';
import 'package:mobile/features/practice/presentation/widgets/home_garden_card.dart';
import 'package:mobile/features/practice/presentation/widgets/home_daily_activities.dart';
import 'package:mobile/l10n/app_localizations.dart';

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

  // Home B state: tracks whether the user has just completed a practice
  bool _showPracticeResult = false;
  String? _completedPhrase;
  String? _completedSceneTag;

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
    // Watch garden and continuity notifiers. Sub-widgets extracted below
    // each watch only the slice they need, limiting rebuild blast radius.
    final gardenGrowthNotifier = ref.watch(gardenGrowthNotifierProvider);
    final pendingFertilizerCount =
        ref.watch(gardenFertilizerNotifierProvider).view.pendingPacks.length;
    final continuityNotifier = ref.watch(practiceContinuityNotifierProvider);
    final hasResolvedContinuity = continuityNotifier.hasResolvedRecommendation;
    final activity = hasResolvedContinuity
        ? continuityNotifier.activitySnapshot
        : null;
    final practiceArgs = continuityNotifier.recommendedArgs;
    final canLaunchPractice =
        hasResolvedContinuity &&
        !continuityNotifier.isActionDisabled &&
        practiceArgs != null &&
        activity != null;
    final starterPhrase = _resolveStarterPhrase(
      activity,
      widget.onboardingSnapshot,
    );
    final childName = widget.onboardingSnapshot?.childDisplayName ?? l.guest;
    final sceneTag = activity?.sceneTag ?? '照护场景';
    final activityTitle = activity?.title ?? '收玩具';

    // Calculate garden stats for the new layout
    final gardenSnapshot = gardenGrowthNotifier.snapshot;
    final primarySpace = gardenSnapshot.primarySpace;
    final weekNumber = _calculateWeekNumber(gardenSnapshot);
    final stageName = primarySpace?.stage.label ?? 'Seedling';
    final wordsPlanted = gardenSnapshot.validEvents;

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

                            // Progress bar
                            HomeProgressBar(
                              progress: _calculateProgress(gardenSnapshot),
                              label: '本周学习进度',
                            ),

                            const SizedBox(height: 16),

                            // Garden card
                            HomeGardenCard(
                              weekNumber: weekNumber,
                              stageName: stageName,
                              wordsPlanted: wordsPlanted,
                            ),

                            const SizedBox(height: 24),

                            // Daily activities
                            HomeDailyActivities(
                              onActivityTap: (activity) {
                                // Navigate to practice flow based on activity
                                if (canLaunchPractice) {
                                  practiceArgs.push(context);
                                }
                              },
                              onSeeAll: () {
                                // Navigate to full activities list
                              },
                            ),

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

  int _calculateWeekNumber(GardenGrowthSnapshot snapshot) {
    if (snapshot.isEmpty) return 1;
    // Calculate week number based on first event or installation date
    final firstEvent = snapshot.diaryEntries.isNotEmpty
        ? snapshot.diaryEntries.first.occurredAt
        : DateTime.now();
    final weeksSinceStart = DateTime.now().difference(firstEvent).inDays ~/ 7;
    return (weeksSinceStart + 1).clamp(1, 52);
  }

  double _calculateProgress(GardenGrowthSnapshot snapshot) {
    if (snapshot.isEmpty) return 0.0;
    // Progress based on completed activities vs total
    final space = snapshot.primarySpace;
    if (space == null || space.totalActivityCount == 0) return 0.0;
    return (space.completedActivityCount / space.totalActivityCount).clamp(0.0, 1.0);
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
