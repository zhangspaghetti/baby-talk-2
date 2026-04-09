import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/account/presentation/account_view_model.dart';
import 'package:mobile/features/account/presentation/screens/account_entry_screen.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
import 'package:mobile/features/practice/presentation/practice_session_view_model.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<AccountViewModel>().handleHomeVisible();
    });
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
  }

  @override
  void didPopNext() {
    context.read<AccountViewModel>().handleHomeVisible();
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
    unawaited(context.read<PracticeSessionViewModel>().retryHomeLoad());
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PracticeSessionViewModel>();
    final activity = viewModel.activitySnapshot;
    final homeSummary = viewModel.homeSummary;
    final stageMatch = _resolveStageMatch(widget.onboardingSnapshot);
    final starterPhrase = _resolveStarterPhrase(activity, widget.onboardingSnapshot);
    final body = SafeArea(
      top: !widget.embeddedInShell,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: viewModel.isHomeLoading && activity == null
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
                    if (viewModel.restoreStatusMessage != null) ...[
                      const SizedBox(height: 20),
                      _HomeBanner(
                        key: const Key('home-restore-banner'),
                        message: viewModel.restoreStatusMessage!,
                        backgroundColor: viewModel.hasRecoverableRestoreIssue
                            ? AppTheme.warningSoft
                            : AppTheme.infoSoft,
                        foregroundColor: viewModel.hasRecoverableRestoreIssue
                            ? AppTheme.warning
                            : AppTheme.info,
                        actionLabel: viewModel.hasRecoverableRestoreIssue
                            ? '重新恢复'
                            : null,
                        onAction: viewModel.hasRecoverableRestoreIssue
                            ? viewModel.retryHomeLoad
                            : null,
                      ),
                    ],
                    if (viewModel.homeErrorMessage != null) ...[
                      const SizedBox(height: 20),
                      _HomeBanner(
                        key: const Key('home-error-banner'),
                        message: viewModel.homeErrorMessage!,
                        backgroundColor: AppTheme.errorSoft,
                        foregroundColor: AppTheme.error,
                        actionLabel: '重试',
                        onAction: viewModel.retryHomeLoad,
                      ),
                    ],
                    const SizedBox(height: 20),
                    _TodaySceneCard(
                      activityTitle: activity?.title ?? '洗澡时间',
                      activitySummary: activity?.summary ?? '正在加载今日活动摘要…',
                      sceneTag: activity?.sceneTag,
                      buttonLabel: homeSummary?.isEmpty ?? true
                          ? '开始练习'
                          : '继续练习',
                      onPressed: viewModel.canStartPractice
                          ? () async {
                              final ready = await context
                                  .read<PracticeSessionViewModel>()
                                  .ensureSessionReady();
                              if (!context.mounted || !ready) {
                                return;
                              }
                              Navigator.of(
                                context,
                              ).pushNamed(AppRouteNames.practice);
                            }
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _WeekStatsCard(
                      homeSummary: homeSummary,
                      stageMatch: stageMatch,
                    ),
                    const SizedBox(height: 16),
                    _RecentResultCard(
                      homeSummary: homeSummary,
                      viewModel: viewModel,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'boot: ready${viewModel.installationId == null ? '' : ' · install: ${_shortInstallationId(viewModel.installationId!)}'}',
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
        tooltip: '小禾老师',
        onPressed: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('小禾老师入口已预留，后续任务接入。')));
        },
        child: const Icon(Icons.auto_awesome),
      ),
      body: body,
    );
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
    required this.activityTitle,
    required this.activitySummary,
    required this.sceneTag,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String activityTitle;
  final String activitySummary;
  final String? sceneTag;
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
              key: const Key('home-hero-activity'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              activitySummary,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              key: const Key('home-start-practice'),
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
  const _WeekStatsCard({required this.homeSummary, required this.stageMatch});

  final PracticeHomeSummary? homeSummary;
  final StageMatch? stageMatch;

  @override
  Widget build(BuildContext context) {
    final totalEvents = homeSummary?.totalEvents ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgSunken,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatCell(
              label: '本地记录',
              value: '$totalEvents',
              hint: '只统计当前活动',
            ),
          ),
          Container(width: 1, height: 40, color: AppTheme.outlineSoft),
          Expanded(
            child: _StatCell(
              label: '当前阶段',
              value: stageMatch == null ? '未匹配' : stageMatch!.ageBucket.label,
              hint: stageMatch?.title ?? '等待 onboarding',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
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

class _RecentResultCard extends StatelessWidget {
  const _RecentResultCard({required this.homeSummary, required this.viewModel});

  final PracticeHomeSummary? homeSummary;
  final PracticeSessionViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          if (homeSummary?.isEmpty ?? true)
            Text(
              '还没有本地练习记录，第一次打开也会看到安全空态。',
              key: const Key('recent-result-empty'),
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            Column(
              key: const Key('recent-result-summary'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${homeSummary!.recentResult!.phraseEnglish} · ${viewModel.labelForReaction(homeSummary!.recentResult!.reactionType)}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${homeSummary!.totalEvents} 条本地记录 · 最近一次 ${_formatTime(homeSummary!.recentResult!.eventTime)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
        ],
      ),
    );
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
