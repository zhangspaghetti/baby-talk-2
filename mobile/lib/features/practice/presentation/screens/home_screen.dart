import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/app/widgets/app_haptics.dart';
import 'package:mobile/app/widgets/app_shimmer.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/account/presentation/account_notifier.dart';
import 'package:mobile/features/mentor/presentation/widgets/mentor_panel_sheet.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_notifier.dart'
    show PracticeContinuityLoadStatusLabel;
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/practice/presentation/widgets/home_b_care_moment_title.dart';
import 'package:mobile/features/practice/presentation/widgets/home_b_mentor_bubble.dart';
import 'package:mobile/features/practice/presentation/widgets/home_b_scene_card.dart';
import 'package:mobile/features/practice/presentation/widgets/home_b_quick_rescue_row.dart';
import 'package:mobile/features/practice/presentation/widgets/home_b_practice_result.dart';
import 'package:mobile/features/practice/presentation/widgets/home_b_temporary_scene_sheet.dart';
import 'package:mobile/features/practice/presentation/widgets/home_garden_mini_entry.dart';
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

    // Home B: Default mentor bubble message
    final mentorMessage = starterPhrase != null
        ? '这句适合$activityTitle，${_resolveMentorHint(starterPhrase)}'
        : '小禾帮你挑一句最合适的';

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

                      // Home B: Care moment title
                      HomeBCareMomentTitle(
                        sceneTag: sceneTag,
                        sceneTitle: activityTitle,
                        childName: childName,
                      ),
                      const SizedBox(height: 16),

                      // Home B: Xiaohe mentor bubble
                      HomeBMentorBubble(
                        message: mentorMessage,
                        onTap: () {
                          openMentorPanelSheet(
                            context,
                            launcher: 'home_b_mentor_bubble',
                            surface: widget.embeddedInShell
                                ? 'app_shell'
                                : 'standalone_home',
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // Home B: Practice result or scene card
                      if (_showPracticeResult && _completedPhrase != null)
                        HomeBPracticeResult(
                          phrase: _completedPhrase!,
                          sceneTag: _completedSceneTag ?? sceneTag,
                          childName: childName,
                          onPracticeAgain: () {
                            setState(() {
                              _showPracticeResult = false;
                            });
                            if (canLaunchPractice) {
                              practiceArgs.push(context);
                            }
                          },
                          onNextPhrase: () {
                            setState(() {
                              _showPracticeResult = false;
                            });
                            AppHaptics.lightTap();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('下一句会在明天的照护时刻等你'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          },
                        )
                      else
                        HomeBSceneCard(
                          phrase: starterPhrase,
                          parentAction:
                              _resolveParentAction(activityTitle, activity?.coachTip),
                          sceneTag: sceneTag,
                          coachTip: activity?.coachTip,
                          onStartPractice: canLaunchPractice
                              ? () async {
                                  await practiceArgs.push(context);
                                  if (!mounted) {
                                    return;
                                  }
                                  // Show post-completion result
                                  setState(() {
                                    _showPracticeResult = true;
                                    _completedPhrase =
                                        starterPhrase?.english ?? "Let's put it back.";
                                    _completedSceneTag = sceneTag;
                                  });
                                  await _refreshContinuity(
                                    reason: 'practice_return',
                                  );
                                  await gardenGrowthNotifier.refresh();
                                }
                              : null,
                        ),
                      const SizedBox(height: 24),

                      // Home B: Quick rescue row
                      HomeBQuickRescueRow(
                        onSceneSelected: (scene) {
                          _openTemporarySceneSheet(scene);
                        },
                      ),
                      const SizedBox(height: 24),

                      // Garden summary
                      HomeGardenMiniEntry(notifier: gardenGrowthNotifier),

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

  void _openTemporarySceneSheet(String initialScene) {
    AppHaptics.lightTap();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HomeBTemporarySceneSheet(
        initialScene: initialScene,
      ),
    );
  }

  String _resolveParentAction(String activityTitle, String? coachTip) {
    // Use coach tip as parent action if available
    if (coachTip != null && coachTip.isNotEmpty) {
      return coachTip;
    }
    // Fallback contextual action
    return '一边$activityTitle，一边轻轻说给宝宝听。';
  }

  String _resolveMentorHint(PracticePhrase phrase) {
    // Generate a short contextual hint for the mentor bubble
    if (phrase.english.isNotEmpty) {
      return '现在就能用，不像命令，更像邀请宝宝一起完成。';
    }
    return '小禾帮你挑一句最合适的。';
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
