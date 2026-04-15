import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/account/presentation/account_view_model.dart';
import 'package:mobile/features/account/presentation/screens/account_entry_screen.dart';
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
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
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
  PracticeRouteArgs? _practiceArgs;
  PracticeContinuitySnapshot? _practiceContinuitySnapshot;
  PracticeActivitySnapshot? _practiceActivitySnapshot;
  String? _homeErrorMessage;
  bool _isHomeLoading = false;
  String? _lastResolvedScopeLabel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<AccountViewModel>().handleHomeVisible();
      final gardenGrowthViewModel = context.read<GardenGrowthViewModel?>();
      if (gardenGrowthViewModel != null &&
          gardenGrowthViewModel.status == GardenGrowthLoadStatus.idle) {
        unawaited(gardenGrowthViewModel.initialize());
      }
      unawaited(_refreshHomePracticeState());
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
        unawaited(_refreshHomePracticeState());
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
        unawaited(_refreshHomePracticeState());
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
    unawaited(_refreshHomePracticeState());
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
    if (!accountViewModel.isSignedIn) {
      return;
    }
    unawaited(_refreshHomePracticeState());
    final gardenGrowthViewModel = context.read<GardenGrowthViewModel?>();
    if (gardenGrowthViewModel != null) {
      unawaited(gardenGrowthViewModel.refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final gardenGrowthViewModel = context.watch<GardenGrowthViewModel?>();
    final continuitySnapshot = _practiceContinuitySnapshot;
    final activity = _practiceActivitySnapshot;
    final recommendedActivity = continuitySnapshot?.recommendedActivity;
    final practiceArgs = _practiceArgs;
    final canLaunchPractice =
        practiceArgs != null &&
        !_isHomeLoading &&
        _homeErrorMessage == null &&
        activity != null;
    final stageMatch = _resolveStageMatch(widget.onboardingSnapshot);
    final starterPhrase = _resolveStarterPhrase(
      activity,
      widget.onboardingSnapshot,
    );
    final body = SafeArea(
      top: !widget.embeddedInShell,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: _isHomeLoading && activity == null
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
                    ] else ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: const [
                          Chip(label: Text('离线种子已就绪')),
                          Chip(label: Text('Guest 模式')),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '今晚试试把洗澡时间变成一句句自然的英文。',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        activity?.phrases.first.english ?? 'Bath time, baby.',
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(color: AppTheme.english),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '首页和练习页共用同一条本地事件链路：点播放、记反应、回到首页都能看到结果。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 20),
                    AccountStatusCard(
                      scopeKeyPrefix: 'home',
                      onboardingSnapshot: widget.onboardingSnapshot,
                    ),
                    if (continuitySnapshot?.fallbackReason != null) ...[
                      const SizedBox(height: 20),
                      _HomeBanner(
                        key: const Key('home-continuity-fallback-banner'),
                        message: continuitySnapshot!.fallbackReason!,
                        backgroundColor: AppTheme.infoSoft,
                        foregroundColor: AppTheme.info,
                      ),
                    ],
                    if (continuitySnapshot?.warningMessage != null) ...[
                      const SizedBox(height: 20),
                      _HomeBanner(
                        key: const Key('home-continuity-warning-banner'),
                        message: continuitySnapshot!.warningMessage!,
                        backgroundColor: AppTheme.warningSoft,
                        foregroundColor: AppTheme.warning,
                        actionLabel: '重新整理',
                        onAction: _refreshHomePracticeState,
                      ),
                    ],
                    if (_homeErrorMessage != null) ...[
                      const SizedBox(height: 20),
                      _HomeBanner(
                        key: const Key('home-error-banner'),
                        message: _homeErrorMessage!,
                        backgroundColor: AppTheme.errorSoft,
                        foregroundColor: AppTheme.error,
                        actionLabel: '重试',
                        onAction: _refreshHomePracticeState,
                      ),
                    ],
                    const SizedBox(height: 20),
                    _TodaySceneCard(
                      activityId: recommendedActivity?.activityId ?? 'loading',
                      activityTitle: activity?.title ?? '洗澡时间',
                      activitySummary: activity?.summary ?? '正在加载今日活动摘要…',
                      sceneTag: activity?.sceneTag,
                      recommendation: continuitySnapshot?.recommendation,
                      nextIncompleteActivity:
                          continuitySnapshot?.nextIncompleteActivity,
                      buttonLabel: recommendedActivity?.isEmpty ?? true
                          ? '开始练习'
                          : '继续练习',
                      onPressed: canLaunchPractice
                          ? () async {
                              await practiceArgs.push(context);
                            }
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _WeekStatsCard(continuitySnapshot: continuitySnapshot),
                    const SizedBox(height: 16),
                    _GardenMiniEntry(viewModel: gardenGrowthViewModel),
                    const SizedBox(height: 16),
                    _GrowthSummaryCard(viewModel: gardenGrowthViewModel),
                    const SizedBox(height: 16),
                    _RecentResultCard(continuitySnapshot: continuitySnapshot),
                    const SizedBox(height: 12),
                    Text(
                      'boot: ready${continuitySnapshot?.catalog.installationId == null ? '' : ' · install: ${_shortInstallationId(continuitySnapshot!.catalog.installationId!)}'}',
                      key: const Key('boot-status-ready'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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
        tooltip: '小禾老师',
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

  Future<void> _refreshHomePracticeState() async {
    final starterArgs = _resolveStarterArgs();

    if (mounted) {
      setState(() {
        _homeErrorMessage = null;
        _isHomeLoading = true;
      });
    }

    try {
      final repository = context.read<PracticeRepository>();
      final continuitySnapshot = await repository.getContinuitySnapshot(
        starterSpaceId: starterArgs?.spaceId,
        starterActivityId: starterArgs?.activityId,
      );
      final activitySnapshot = await repository.getActivitySnapshot(
        spaceId: continuitySnapshot.recommendedActivity.spaceId,
        activityId: continuitySnapshot.recommendedActivity.activityId,
      );
      final recommendedArgs = PracticeRouteArgs(
        spaceId: continuitySnapshot.recommendedActivity.spaceId,
        activityId: continuitySnapshot.recommendedActivity.activityId,
      );
      if (mounted) {
        setState(() {
          _practiceArgs = recommendedArgs;
          _practiceContinuitySnapshot = continuitySnapshot;
          _practiceActivitySnapshot = activitySnapshot;
          _homeErrorMessage = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _practiceArgs = starterArgs;
          _practiceContinuitySnapshot = null;
          _practiceActivitySnapshot = null;
          _homeErrorMessage = '首页加载失败：$error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isHomeLoading = false;
        });
      }
    }
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
}

class _LocalOnlyBanner extends StatelessWidget {
  const _LocalOnlyBanner({required this.snapshot});

  final OnboardingSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('home-local-only-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgSunken,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.lock_outline,
              color: AppTheme.textSecondary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${snapshot.childDisplayName} 的昵称、月龄档和阶段在同意前仅保存在这台设备上。',
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.outlineSoft),
        boxShadow: AppTheme.warmShadowSm,
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
            '${snapshot.childDisplayName}，今天先从一句自然的英文开始。',
            key: const Key('personalized-home-heading'),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            stageMatch?.summary ?? '先把英语放进照护动作里，保持真实、短句、可重复。',
            key: const Key('personalized-home-stage-summary'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Container(
            key: const Key('home-starter-seed'),
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.englishSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('第一颗种子', style: theme.textTheme.labelMedium),
                const SizedBox(height: 10),
                Text(
                  starterPhrase?.english ?? 'Bath time, baby.',
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontSize: 28,
                    color: AppTheme.english,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  starterPhrase?.chinese ?? '先从洗澡时间这句开始。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textPrimary,
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
    required this.onPressed,
  });

  final String activityId;
  final String activityTitle;
  final String activitySummary;
  final String? sceneTag;
  final PracticeContinuityRecommendation? recommendation;
  final PracticeCatalogActivitySummary? nextIncompleteActivity;
  final String buttonLabel;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
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
              recommendation?.reasonLabel ?? '正在整理 continuity',
              key: ValueKey('home-continuity-reason-$activityId'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
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
                '下一步也可以切到 ${nextIncompleteActivity!.title}',
                key: ValueKey(
                  'home-next-incomplete-${nextIncompleteActivity!.activityId}',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              key: ValueKey('home-start-practice-$activityId'),
              onPressed: onPressed,
              child: Text(buttonLabel),
            ),
          ],
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
    final recommendedActivity = continuitySnapshot?.recommendedActivity;
    final cadence = continuitySnapshot?.cadence;
    return Container(
      key: ValueKey(
        'home-week-stats-${recommendedActivity?.activityId ?? 'loading'}',
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgSunken,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatCell(
              label: '推荐活动',
              value: recommendedActivity?.title ?? '整理中',
              hint:
                  continuitySnapshot?.recommendation.reasonLabel ??
                  '等待 continuity',
            ),
          ),
          Container(width: 1, height: 40, color: AppTheme.outlineSoft),
          Expanded(
            child: _StatCell(
              key: ValueKey(
                'home-cadence-summary-${recommendedActivity?.activityId ?? 'loading'}',
              ),
              label: '连续节奏',
              value: cadence?.headline ?? '整理中',
              hint: cadence?.detail ?? '正在从本地事件派生 cadence',
            ),
          ),
        ],
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
              color: AppTheme.textPrimary,
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
    final effectiveViewModel = viewModel;
    final snapshot =
        effectiveViewModel?.snapshot ?? GardenGrowthSnapshot.empty();
    final primarySpace = snapshot.primarySpace;
    final primaryActivity = snapshot.primaryActivity;
    final status = effectiveViewModel?.status ?? GardenGrowthLoadStatus.empty;

    String title;
    String body;
    Color backgroundColor = AppTheme.successSoft;
    Color foregroundColor = AppTheme.success;

    switch (status) {
      case GardenGrowthLoadStatus.loading:
      case GardenGrowthLoadStatus.idle:
        title = '花园正在整理今天的变化';
        body = '先把事件投影成花圃和花朵阶段，马上就能看到结果。';
        backgroundColor = AppTheme.bgSunken;
        foregroundColor = AppTheme.textSecondary;
        break;
      case GardenGrowthLoadStatus.error:
        title = '花园入口暂时没整理好';
        body = effectiveViewModel?.message ?? '先保留最近一次稳定结果，你也可以稍后刷新。';
        backgroundColor = AppTheme.warningSoft;
        foregroundColor = AppTheme.warning;
        break;
      case GardenGrowthLoadStatus.empty:
        title = '你的花园会从第一句开口开始';
        body = '还没有练习记录，先说出一句 Warm water.，花圃就会醒来。';
        backgroundColor = AppTheme.bgAccentSoft;
        foregroundColor = AppTheme.accentDark;
        break;
      case GardenGrowthLoadStatus.ready:
        title = primarySpace == null
            ? '花园入口已准备好'
            : '${primarySpace.title} · ${primarySpace.stage.label}';
        body = primaryActivity == null
            ? '花圃已经有变化，后续会继续接入完整花园页。'
            : '${primaryActivity.title} 现在是“${primaryActivity.stage.label}”，${primaryActivity.careNote}';
        break;
    }

    return Container(
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
            'GardenMiniEntry',
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
    );
  }
}

class _GrowthSummaryCard extends StatelessWidget {
  const _GrowthSummaryCard({required this.viewModel});

  final GardenGrowthViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final effectiveViewModel = viewModel;
    final snapshot =
        effectiveViewModel?.snapshot ?? GardenGrowthSnapshot.empty();
    final impact = snapshot.latestImpact;

    String title;
    String body;

    if (effectiveViewModel?.hasError ?? false) {
      title = '最近成长摘要暂时不可用';
      body = effectiveViewModel?.message ?? '投影失败时会保留安全空态，不会让首页白屏。';
    } else if (impact == null ||
        effectiveViewModel == null ||
        effectiveViewModel.isEmpty) {
      title = '最近成长会写在这里';
      body = '完成一次练习后，这里会告诉你这次开口让什么发生了变化。';
    } else {
      title = impact.headline;
      body = impact.detail;
    }

    return Container(
      key: const Key('home-growth-summary'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.outlineSoft),
        boxShadow: AppTheme.warmShadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('最近成长摘要', style: Theme.of(context).textTheme.labelMedium),
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
    final recommendedActivity = continuitySnapshot?.recommendedActivity;
    final recentResult = recommendedActivity?.recentResult;
    final activityId = recommendedActivity?.activityId ?? 'empty';

    return Container(
      key: ValueKey('recent-result-$activityId'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgSunken,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('最近一次本地结果', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (recentResult == null)
            Text(
              continuitySnapshot?.fallbackReason ?? '还没有本地练习记录，第一次打开也会看到安全空态。',
              key: const Key('recent-result-empty'),
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            Column(
              key: ValueKey('recent-result-summary-$activityId'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${recommendedActivity!.title} · ${recentResult.phraseEnglish} · ${_labelForReaction(recentResult.reactionType)}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${recommendedActivity.totalEvents} 条本地记录 · 最近一次 ${_formatTime(recentResult.eventTime)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _labelForReaction(BabyReactionType reactionType) {
    switch (reactionType) {
      case BabyReactionType.calm:
        return '宝宝放松';
      case BabyReactionType.engaged:
        return '宝宝在看';
      case BabyReactionType.imitated:
        return '宝宝模仿';
      case BabyReactionType.needsBreak:
        return '先休息';
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(key: Key('home-loading')),
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
