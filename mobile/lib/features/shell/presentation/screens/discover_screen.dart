import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:provider/provider.dart';

enum DiscoverBrowseView { activity, space }

typedef DiscoverCatalogLoader = Future<PracticeActivityCatalog> Function();
typedef DiscoverPracticeOpener =
    Future<void> Function(BuildContext context, PracticeRouteArgs args);

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key, this.catalogLoader, this.practiceOpener});

  final DiscoverCatalogLoader? catalogLoader;
  final DiscoverPracticeOpener? practiceOpener;

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with AutomaticKeepAliveClientMixin<DiscoverScreen> {
  late Future<PracticeActivityCatalog> _catalogFuture;
  DiscoverBrowseView _selectedView = DiscoverBrowseView.activity;
  String? _navigationError;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _catalogFuture = _loadCatalog();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: FutureBuilder<PracticeActivityCatalog>(
            future: _catalogFuture,
            builder: (context, snapshot) {
              final isLoading =
                  snapshot.connectionState != ConnectionState.done;
              final catalog = snapshot.data;

              return ListView(
                key: const Key('shell-tab-discover'),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                children: [
                  _DiscoverHero(theme: theme),
                  const SizedBox(height: 16),
                  _DiscoverViewToggle(
                    selectedView: _selectedView,
                    onChanged: (view) {
                      setState(() {
                        _selectedView = view;
                      });
                    },
                  ),
                  if (_navigationError != null) ...[
                    const SizedBox(height: 16),
                    _DiscoverBanner(
                      key: const Key('discover-navigation-error'),
                      message: _navigationError!,
                      backgroundColor: AppTheme.errorSoft,
                      foregroundColor: AppTheme.error,
                    ),
                  ],
                  if (catalog?.catalogWarning != null &&
                      catalog!.catalogWarning!.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _DiscoverBanner(
                      key: const Key('discover-catalog-warning'),
                      message: catalog.catalogWarning!,
                      backgroundColor: AppTheme.warningSoft,
                      foregroundColor: AppTheme.warning,
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (isLoading)
                    const _DiscoverLoadingState()
                  else if (snapshot.hasError)
                    _DiscoverErrorState(
                      message: '目录读取失败：${snapshot.error}',
                      onRetry: _retryCatalog,
                    )
                  else if (catalog == null || catalog.isEmpty)
                    _DiscoverEmptyState(onRetry: _retryCatalog)
                  else if (_selectedView == DiscoverBrowseView.activity)
                    _DiscoverActivityList(
                      activities: catalog.activities,
                      onOpenActivity: _openActivity,
                    )
                  else
                    _DiscoverSpaceList(
                      spaces: catalog.spaces,
                      onOpenActivity: _openActivity,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<PracticeActivityCatalog> _loadCatalog() {
    final loader = widget.catalogLoader;
    if (loader != null) {
      return loader();
    }
    return context.read<PracticeRepository>().getActivityCatalog();
  }

  Future<void> _retryCatalog() async {
    setState(() {
      _navigationError = null;
      _catalogFuture = _loadCatalog();
    });
  }

  Future<void> _openActivity(PracticeCatalogActivitySummary activity) async {
    final routeArgs = PracticeRouteArgs.maybeCreate(
      spaceId: activity.spaceId,
      activityId: activity.activityId,
    );
    if (routeArgs == null) {
      setState(() {
        _navigationError = '这张活动卡缺少有效的 spaceId/activityId，已禁止导航。';
      });
      return;
    }

    setState(() {
      _navigationError = null;
    });

    try {
      final opener = widget.practiceOpener;
      if (opener != null) {
        await opener(context, routeArgs);
      } else {
        await routeArgs.push<void>(context);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _navigationError = '打开 ${activity.title} 失败：$error';
      });
    }
  }
}

class _DiscoverHero extends StatelessWidget {
  const _DiscoverHero({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('discover-hero-card'),
      width: double.infinity,
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
          Text('发现', style: theme.textTheme.labelMedium),
          const SizedBox(height: 10),
          Text('按活动和空间继续找下一句。', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(
            '这里展示真实离线目录：你可以按 activity 挑一句，也可以按 space 找到现在最顺手的照护时刻。',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _DiscoverViewToggle extends StatelessWidget {
  const _DiscoverViewToggle({
    required this.selectedView,
    required this.onChanged,
  });

  final DiscoverBrowseView selectedView;
  final ValueChanged<DiscoverBrowseView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('discover-view-toggle'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.bgSunken,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: _DiscoverTogglePill(
              key: const Key('discover-tab-activity'),
              label: '按活动',
              icon: Icons.explore_outlined,
              selected: selectedView == DiscoverBrowseView.activity,
              onTap: () => onChanged(DiscoverBrowseView.activity),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _DiscoverTogglePill(
              key: const Key('discover-tab-space'),
              label: '按空间',
              icon: Icons.grid_view_rounded,
              selected: selectedView == DiscoverBrowseView.space,
              onTap: () => onChanged(DiscoverBrowseView.space),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverTogglePill extends StatelessWidget {
  const _DiscoverTogglePill({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.bgSurface : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? AppTheme.accentDark : AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: selected
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverLoadingState extends StatelessWidget {
  const _DiscoverLoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('discover-loading-state'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.outlineSoft),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(
            key: Key('discover-loading-indicator'),
          ),
          const SizedBox(height: 16),
          Text(
            '正在整理离线 activity 目录…',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '加载只影响 Discover，不会阻塞首页、花园和成长 tab。',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DiscoverErrorState extends StatelessWidget {
  const _DiscoverErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('discover-error-state'),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.errorSoft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '目录暂时没有整理好',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppTheme.error),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.error),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            key: const Key('discover-retry-button'),
            onPressed: onRetry,
            child: const Text('重试加载'),
          ),
        ],
      ),
    );
  }
}

class _DiscoverEmptyState extends StatelessWidget {
  const _DiscoverEmptyState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('discover-empty-state'),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('目录还是空的', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '目前没有可展示的 activity。稍后重试时不会把你带回旧 placeholder。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            key: const Key('discover-empty-retry-button'),
            onPressed: onRetry,
            child: const Text('重新读取目录'),
          ),
        ],
      ),
    );
  }
}

class _DiscoverActivityList extends StatelessWidget {
  const _DiscoverActivityList({
    required this.activities,
    required this.onOpenActivity,
  });

  final List<PracticeCatalogActivitySummary> activities;
  final ValueChanged<PracticeCatalogActivitySummary> onOpenActivity;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('discover-view-activity'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('按活动浏览', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          '每张 ActivityCard 都带着自己的 spaceId/activityId 进入练习页。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        for (final activity in activities) ...[
          _DiscoverActivityCard(
            activity: activity,
            onOpen: () => onOpenActivity(activity),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _DiscoverActivityCard extends StatelessWidget {
  const _DiscoverActivityCard({required this.activity, required this.onOpen});

  final PracticeCatalogActivitySummary activity;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final progress = activity.totalPhraseCount == 0
        ? 0.0
        : activity.completedPhraseCount / activity.totalPhraseCount;
    final hasRecentResult = activity.recentResult != null;
    final summary = activity.summary.trim().isEmpty
        ? '摘要暂时缺失，但这张卡仍然可以安全进入练习。'
        : activity.summary;
    final footerText = hasRecentResult
        ? '${_reactionLabel(activity.recentResult!.reactionType)} · ${activity.recentResult!.phraseEnglish}'
        : (activity.nextPhraseEnglish?.trim().isNotEmpty ?? false)
        ? '下一句：${activity.nextPhraseEnglish}'
        : '目录暂时没有下一句预览。';
    final footerHint = hasRecentResult
        ? '最近一次 ${_formatTime(activity.recentResult!.eventTime)} · ${activity.recentResult!.totalEvents} 条记录'
        : '${activity.completedPhraseCount}/${activity.totalPhraseCount} 句已练 · ${activity.totalEvents} 条记录';

    return Container(
      key: Key('discover-activity-card-${activity.activityId}'),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text(activity.sceneTag)),
                        Chip(label: Text(activity.spaceTitle)),
                        if (activity.hasRecoverableIssue)
                          Chip(label: Text('需留意')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      activity.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      summary,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            key: Key('discover-progress-${activity.activityId}'),
            value: progress.clamp(0.0, 1.0),
            minHeight: 6,
            borderRadius: BorderRadius.circular(999),
            color: AppTheme.accent,
            backgroundColor: AppTheme.bgSunken,
          ),
          const SizedBox(height: 10),
          Text(
            '${activity.completedPhraseCount}/${activity.totalPhraseCount} 句已练 · ${activity.totalEvents} 条记录',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hasRecentResult ? AppTheme.englishSoft : AppTheme.bgSunken,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '最近进度 / 结果',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  footerText,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(footerHint, style: Theme.of(context).textTheme.bodySmall),
                if (activity.warningMessage != null &&
                    activity.warningMessage!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    activity.warningMessage!,
                    key: Key(
                      'discover-activity-warning-${activity.activityId}',
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            key: Key(
              'discover-route-target-${activity.spaceId}-${activity.activityId}',
            ),
            onPressed: onOpen,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(activity.isEmpty ? '开始这个活动' : '继续这个活动'),
          ),
        ],
      ),
    );
  }
}

class _DiscoverSpaceList extends StatelessWidget {
  const _DiscoverSpaceList({
    required this.spaces,
    required this.onOpenActivity,
  });

  final List<PracticeCatalogSpaceSummary> spaces;
  final ValueChanged<PracticeCatalogActivitySummary> onOpenActivity;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('discover-view-space'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('按空间浏览', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          '每个 SpaceGridItem 会保留被点击 activity 的 route 作用域。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        for (final space in spaces) ...[
          _DiscoverSpaceSection(space: space, onOpenActivity: onOpenActivity),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _DiscoverSpaceSection extends StatelessWidget {
  const _DiscoverSpaceSection({
    required this.space,
    required this.onOpenActivity,
  });

  final PracticeCatalogSpaceSummary space;
  final ValueChanged<PracticeCatalogActivitySummary> onOpenActivity;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('discover-space-section-${space.spaceId}'),
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
          Text(space.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            space.description,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            '${space.startedActivityCount}/${space.totalActivityCount} 个 activity 已开始 · ${space.totalEvents} 条记录',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            key: Key('discover-space-grid-${space.spaceId}'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.95,
            children: [
              for (final activity in space.activities)
                _DiscoverSpaceGridItem(
                  activity: activity,
                  onTap: () => onOpenActivity(activity),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiscoverSpaceGridItem extends StatelessWidget {
  const _DiscoverSpaceGridItem({required this.activity, required this.onTap});

  final PracticeCatalogActivitySummary activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = activity.totalPhraseCount == 0
        ? 0.0
        : activity.completedPhraseCount / activity.totalPhraseCount;
    final highlight =
        activity.recentResult?.phraseEnglish ??
        activity.nextPhraseEnglish ??
        '打开后查看这张活动卡里的短语';

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.bgAccentSoft, AppTheme.bgSurface],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.outlineSoft),
        ),
        child: InkWell(
          key: Key(
            'discover-route-target-${activity.spaceId}-${activity.activityId}',
          ),
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              key: Key(
                'discover-space-item-${activity.spaceId}-${activity.activityId}',
              ),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.sceneTag,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  activity.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  highlight,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                LinearProgressIndicator(
                  key: Key('discover-space-progress-${activity.activityId}'),
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(999),
                  color: AppTheme.english,
                  backgroundColor: AppTheme.bgSurface,
                ),
                const SizedBox(height: 8),
                Text(
                  '${activity.completedPhraseCount}/${activity.totalPhraseCount} 句',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoverBanner extends StatelessWidget {
  const _DiscoverBanner({
    super.key,
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String message;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _reactionLabel(BabyReactionType reactionType) {
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
