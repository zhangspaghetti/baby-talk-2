import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_haptics.dart';
import 'package:mobile/app/widgets/app_shimmer.dart';
import 'package:mobile/features/growth/domain/services/growth_stats_service.dart';
import 'package:mobile/features/growth/presentation/growth_insights_models.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';

/// Growth V2 insights panel: period selector (本周/本月/今年) + streak card
/// + period stats tiles + a trend bar chart (fl_chart). Consumes the pure
/// [GrowthStatsService] via [growthInsightsNotifierProvider].
class GrowthInsightsPanel extends ConsumerStatefulWidget {
  const GrowthInsightsPanel({
    super.key,
    this.milestones = const [],
    this.onStartSuggestedPractice,
  });

  /// All-time milestones from the garden growth snapshot. The panel filters
  /// them by [GrowthMilestoneSnapshot.achievedAt] within the selected period.
  final List<GrowthMilestoneSnapshot> milestones;

  /// Invoked when the user taps the next-step suggestion's "试这一句" action.
  /// Defaults to pushing the practice route via [PracticeRouteArgs.push].
  /// Injected in tests to capture the navigation intent.
  final void Function(PracticeRouteArgs args)? onStartSuggestedPractice;

  @override
  ConsumerState<GrowthInsightsPanel> createState() =>
      _GrowthInsightsPanelState();
}

class _GrowthInsightsPanelState extends ConsumerState<GrowthInsightsPanel> {
  GrowthPeriod _period = GrowthPeriod.week;
  int? _selectedBarIndex;

  void _selectPeriod(GrowthPeriod period) {
    if (period == _period) return;
    AppHaptics.lightTap();
    setState(() {
      _period = period;
      _selectedBarIndex = null;
    });
  }

  void _selectBar(int? index) {
    if (index == _selectedBarIndex) return;
    AppHaptics.lightTap();
    setState(() => _selectedBarIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final notifier = ref.watch(growthInsightsNotifierProvider);
    final view = notifier.viewFor(_period);

    return Container(
      key: const Key('growth-insights-panel'),
      padding: const EdgeInsets.all(AppLayoutConstants.spacingXl),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(AppLayoutConstants.largeRadius),
        border: Border.all(color: colors.outlineSoft),
        boxShadow: colors.warmShadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '练习趋势',
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _PeriodSelector(selected: _period, onSelected: _selectPeriod),
            ],
          ),
          const SizedBox(height: AppLayoutConstants.spacingLg),
          if (view.isLoading)
            _buildLoading(colors)
          else if (view.isEmpty)
            _buildEmpty(theme, colors)
          else
            _buildContent(context, theme, colors, view),
        ],
      ),
    );
  }

  Widget _buildLoading(BabyTalkColors colors) {
    return Column(
      key: const Key('growth-insights-loading'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        AppShimmer(width: 160, height: 56),
        SizedBox(height: AppLayoutConstants.spacingMd),
        AppShimmer(width: double.infinity, height: 140),
      ],
    );
  }

  Widget _buildEmpty(ThemeData theme, BabyTalkColors colors) {
    return Padding(
      key: const Key('growth-insights-empty'),
      padding: const EdgeInsets.symmetric(
        vertical: AppLayoutConstants.spacingLg,
      ),
      child: Row(
        children: [
          Icon(Icons.insights_rounded, color: colors.textMuted, size: 28),
          const SizedBox(width: AppLayoutConstants.spacingSm),
          Expanded(
            child: Text(
              _emptyHint(_period),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _emptyHint(GrowthPeriod period) {
    switch (period) {
      case GrowthPeriod.week:
        return '本周还没有练习记录，去和宝宝说几句吧。';
      case GrowthPeriod.month:
        return '本月还没有练习记录，挑个场景陪宝宝开口试试。';
      case GrowthPeriod.year:
        return '今年还没有练习记录，从今天的第一句开始吧。';
    }
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    BabyTalkColors colors,
    GrowthInsightsViewState view,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Streak card ──
        Container(
          key: const Key('growth-insights-streak'),
          padding: const EdgeInsets.all(AppLayoutConstants.spacingMd),
          decoration: BoxDecoration(
            color: colors.bgAccentSoft,
            borderRadius: BorderRadius.circular(AppLayoutConstants.cardRadius),
          ),
          child: Row(
            children: [
              _StatCell(
                label: '连续打卡',
                value: '${view.streak.currentStreak}',
                unit: '天',
                colors: colors,
                theme: theme,
                emphasize: true,
              ),
              _CellDivider(colors: colors),
              _StatCell(
                label: '最长连续',
                value: '${view.streak.longestStreak}',
                unit: '天',
                colors: colors,
                theme: theme,
              ),
              _CellDivider(colors: colors),
              _StatCell(
                label: '累计天数',
                value: '${view.streak.totalDaysPracticed}',
                unit: '天',
                colors: colors,
                theme: theme,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppLayoutConstants.spacingMd),

        // ── Period stat tiles ──
        Wrap(
          spacing: AppLayoutConstants.spacingSm,
          runSpacing: AppLayoutConstants.spacingSm,
          children: [
            _StatChip(
              label: '${view.period.label}练习',
              value: '${view.stats.totalEvents}',
              colors: colors,
              theme: theme,
            ),
            _StatChip(
              label: '说过的话',
              value: '${view.stats.uniquePhrases}',
              colors: colors,
              theme: theme,
            ),
            _StatChip(
              label: '涉及活动',
              value: '${view.stats.uniqueActivities}',
              colors: colors,
              theme: theme,
            ),
            _StatChip(
              label: '配合',
              value: '${view.stats.cooperatingCount}',
              colors: colors,
              theme: theme,
            ),
          ],
        ),
        const SizedBox(height: AppLayoutConstants.spacingLg),

        // ── Trend bar chart ──
        SizedBox(
          key: const Key('growth-insights-chart'),
          height: 160,
          child: _TrendBarChart(
            view: view,
            colors: colors,
            theme: theme,
            selectedIndex: _selectedBarIndex,
            onBarSelected: _selectBar,
          ),
        ),
        if (_selectedBarCaption(view) != null) ...[
          const SizedBox(height: AppLayoutConstants.spacingSm),
          Text(
            key: const Key('growth-insights-chart-caption'),
            _selectedBarCaption(view)!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],

        // ── Scene distribution (top spaces by event count) ──
        if (view.scenes.isNotEmpty) ...[
          const SizedBox(height: AppLayoutConstants.spacingLg),
          _SceneDistribution(scenes: view.scenes, colors: colors, theme: theme),
        ],

        // ── Period milestones (achieved within the selected window) ──
        if (_periodMilestones(view).isNotEmpty) ...[
          const SizedBox(height: AppLayoutConstants.spacingLg),
          _PeriodMilestones(
            milestones: _periodMilestones(view),
            colors: colors,
            theme: theme,
          ),
        ],

        // ── Gentle next-step suggestion (week/month only) ──
        if (view.suggestion != null) ...[
          const SizedBox(height: AppLayoutConstants.spacingLg),
          _NextStepSuggestion(
            suggestion: view.suggestion!,
            colors: colors,
            theme: theme,
            onTry: () => _startSuggestedPractice(context, view.suggestion!),
          ),
        ],

        // ── Recent activity (this week vs last week, spec §8) ──
        if (view.recentActivity != null) ...[
          const SizedBox(height: AppLayoutConstants.spacingLg),
          _RecentActivity(
            activity: view.recentActivity!,
            colors: colors,
            theme: theme,
          ),
        ],
      ],
    );
  }

  void _startSuggestedPractice(
    BuildContext context,
    GrowthNextStepSuggestion suggestion,
  ) {
    AppHaptics.lightTap();
    final args = PracticeRouteArgs(
      spaceId: suggestion.spaceId,
      activityId: suggestion.activityId,
    );
    final handler = widget.onStartSuggestedPractice;
    if (handler != null) {
      handler(args);
    } else {
      args.push(context);
    }
  }

  /// Milestones from [widget.milestones] whose achievedAt falls inside the
  /// view's aggregation window, most recent first.
  List<GrowthMilestoneSnapshot> _periodMilestones(
    GrowthInsightsViewState view,
  ) {
    final start = view.windowStart;
    final end = view.windowEnd;
    if (start == null || end == null) return const [];
    final inWindow = widget.milestones.where((m) {
      final at = m.achievedAt;
      return at != null && !at.isBefore(start) && !at.isAfter(end);
    }).toList();
    inWindow.sort((a, b) => b.achievedAt!.compareTo(a.achievedAt!));
    return inWindow;
  }

  /// Caption describing the currently selected bar, or null when nothing is
  /// selected or the index is out of range.
  String? _selectedBarCaption(GrowthInsightsViewState view) {
    final index = _selectedBarIndex;
    if (index == null || index < 0 || index >= view.bars.length) return null;
    final bar = view.bars[index];
    return '${bar.label} · ${bar.count} 次练习';
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onSelected});

  final GrowthPeriod selected;
  final ValueChanged<GrowthPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.bgSunken,
        borderRadius: BorderRadius.circular(AppLayoutConstants.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: GrowthPeriod.values.map((period) {
          final isSelected = period == selected;
          return GestureDetector(
            key: Key('growth-insights-period-${period.name}'),
            onTap: () => onSelected(period),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(
                horizontal: AppLayoutConstants.spacingSm,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isSelected ? colors.bgSurface : Colors.transparent,
                borderRadius: BorderRadius.circular(
                  AppLayoutConstants.pillRadius,
                ),
                boxShadow: isSelected ? colors.warmShadowSm : null,
              ),
              child: Text(
                period.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isSelected ? colors.textPrimary : colors.textMuted,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    required this.unit,
    required this.colors,
    required this.theme,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final String unit;
  final BabyTalkColors colors;
  final ThemeData theme;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: emphasize ? colors.accentDark : colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CellDivider extends StatelessWidget {
  const _CellDivider({required this.colors});

  final BabyTalkColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: colors.outlineSoft);
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.colors,
    required this.theme,
  });

  final String label;
  final String value;
  final BabyTalkColors colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppLayoutConstants.spacingSm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: colors.bgSunken,
        borderRadius: BorderRadius.circular(AppLayoutConstants.smallRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendBarChart extends StatelessWidget {
  const _TrendBarChart({
    required this.view,
    required this.colors,
    required this.theme,
    required this.selectedIndex,
    required this.onBarSelected,
  });

  final GrowthInsightsViewState view;
  final BabyTalkColors colors;
  final ThemeData theme;
  final int? selectedIndex;
  final ValueChanged<int?> onBarSelected;

  @override
  Widget build(BuildContext context) {
    final bars = view.bars;
    final maxCount = view.maxBarCount;
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxCount.toDouble(),
        minY: 0,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: true,
          touchCallback: (event, response) {
            if (!event.isInterestedForInteractions) return;
            final spot = response?.spot;
            if (spot == null) {
              onBarSelected(null);
              return;
            }
            onBarSelected(spot.touchedBarGroupIndex);
          },
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => colors.textPrimary,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toInt()}',
                theme.textTheme.labelSmall!.copyWith(color: colors.bgSurface),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= bars.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    bars[index].label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < bars.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: bars[i].count.toDouble(),
                  width: bars.length > 8 ? 8 : 16,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppLayoutConstants.smallRadius),
                  ),
                  color: bars[i].count > 0
                      ? (i == selectedIndex ? colors.accentDark : colors.accent)
                      : colors.outlineSoft,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Top scenes (spaces) ranked by event count, shown as proportional bars.
class _SceneDistribution extends StatelessWidget {
  const _SceneDistribution({
    required this.scenes,
    required this.colors,
    required this.theme,
  });

  final List<SceneDistribution> scenes;
  final BabyTalkColors colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final top = scenes.take(4).toList();
    final maxCount = top.fold<int>(
      1,
      (value, scene) => scene.eventCount > value ? scene.eventCount : value,
    );
    return Column(
      key: const Key('growth-insights-scenes'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '场景分布',
          style: theme.textTheme.labelLarge?.copyWith(
            color: colors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppLayoutConstants.spacingSm),
        for (final scene in top) ...[
          _SceneRow(
            scene: scene,
            maxCount: maxCount,
            colors: colors,
            theme: theme,
          ),
          const SizedBox(height: AppLayoutConstants.spacingSm),
        ],
      ],
    );
  }
}

class _SceneRow extends StatelessWidget {
  const _SceneRow({
    required this.scene,
    required this.maxCount,
    required this.colors,
    required this.theme,
  });

  final SceneDistribution scene;
  final int maxCount;
  final BabyTalkColors colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final fraction = (scene.eventCount / maxCount).clamp(0.0, 1.0);
    final percentLabel = '${(scene.percentage * 100).round()}%';
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            scene.sceneTag,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: AppLayoutConstants.spacingSm),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppLayoutConstants.pillRadius),
            child: LinearProgressIndicator(
              value: fraction == 0 ? 0.04 : fraction,
              minHeight: 8,
              backgroundColor: colors.bgSunken,
              valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
            ),
          ),
        ),
        const SizedBox(width: AppLayoutConstants.spacingSm),
        Text(
          percentLabel,
          style: theme.textTheme.labelSmall?.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({
    required this.activity,
    required this.colors,
    required this.theme,
  });

  final GrowthRecentActivity activity;
  final BabyTalkColors colors;
  final ThemeData theme;

  String get _trendText {
    switch (activity.trend) {
      case GrowthRecentTrend.more:
        return '本周比上周多说了 ${activity.gain} 句。';
      case GrowthRecentTrend.less:
        return '本周稍有减少，没关系。';
      case GrowthRecentTrend.flat:
        return '和上周差不多，保持就好。';
      case GrowthRecentTrend.none:
        return '开始练习后，这里会显示你的活跃节奏。';
    }
  }

  @override
  Widget build(BuildContext context) {
    final numberStyle = theme.textTheme.titleMedium?.copyWith(
      color: colors.textPrimary,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: colors.textMuted,
    );
    return Container(
      key: const Key('growth-insights-recent'),
      padding: const EdgeInsets.all(AppLayoutConstants.spacingMd),
      decoration: BoxDecoration(
        color: colors.bgSunken,
        borderRadius: BorderRadius.circular(AppLayoutConstants.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '最近活跃',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppLayoutConstants.spacingSm),
          Row(
            children: [
              _RecentStat(
                label: '本周',
                value: '${activity.thisWeekCount}',
                numberStyle: numberStyle,
                labelStyle: labelStyle,
              ),
              const SizedBox(width: AppLayoutConstants.spacingXl),
              _RecentStat(
                label: '上周',
                value: '${activity.lastWeekCount}',
                numberStyle: numberStyle,
                labelStyle: labelStyle,
              ),
            ],
          ),
          const SizedBox(height: AppLayoutConstants.spacingXxs),
          Text(
            key: const Key('growth-insights-recent-trend'),
            _trendText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentStat extends StatelessWidget {
  const _RecentStat({
    required this.label,
    required this.value,
    required this.numberStyle,
    required this.labelStyle,
  });

  final String label;
  final String value;
  final TextStyle? numberStyle;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(width: AppLayoutConstants.spacingXxs),
        Text(value, style: numberStyle),
        const SizedBox(width: 2),
        Text('句', style: labelStyle),
      ],
    );
  }
}

class _PeriodMilestones extends StatelessWidget {
  const _PeriodMilestones({
    required this.milestones,
    required this.colors,
    required this.theme,
  });

  final List<GrowthMilestoneSnapshot> milestones;
  final BabyTalkColors colors;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final top = milestones.take(3).toList();
    return Column(
      key: const Key('growth-insights-milestones'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '本周期里程碑',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: AppLayoutConstants.spacingSm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colors.bgAccentSoft,
                borderRadius: BorderRadius.circular(
                  AppLayoutConstants.pillRadius,
                ),
              ),
              child: Text(
                '${milestones.length}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.accentDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppLayoutConstants.spacingSm),
        for (final milestone in top) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.local_florist_rounded, size: 18, color: colors.accent),
              const SizedBox(width: AppLayoutConstants.spacingSm),
              Expanded(
                child: Text(
                  milestone.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppLayoutConstants.spacingSm),
        ],
      ],
    );
  }
}

/// Gentle next-step suggestion: an uncovered scene plus one concrete phrase to
/// try, with a button that jumps straight into practice. Shown only on the
/// week/month views (the notifier returns null for the year view).
class _NextStepSuggestion extends StatelessWidget {
  const _NextStepSuggestion({
    required this.suggestion,
    required this.colors,
    required this.theme,
    required this.onTry,
  });

  final GrowthNextStepSuggestion suggestion;
  final BabyTalkColors colors;
  final ThemeData theme;
  final VoidCallback onTry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('growth-insights-next-step'),
      padding: const EdgeInsets.all(AppLayoutConstants.spacingMd),
      decoration: BoxDecoration(
        color: colors.bgAccentSoft,
        borderRadius: BorderRadius.circular(AppLayoutConstants.cardRadius),
        border: Border.all(color: colors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tips_and_updates_rounded,
                size: 18,
                color: colors.accentDark,
              ),
              const SizedBox(width: AppLayoutConstants.spacingSm),
              Text(
                '下一步',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppLayoutConstants.spacingSm),
          Text(
            '你还没试过${suggestion.sceneLabel}场景。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '试试 "${suggestion.phraseEnglish}"',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: AppLayoutConstants.spacingSm),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              key: const Key('growth-insights-next-step-try'),
              onPressed: onTry,
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: colors.bgSurface,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppLayoutConstants.spacingLg,
                  vertical: AppLayoutConstants.spacingSm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppLayoutConstants.pillRadius,
                  ),
                ),
              ),
              child: const Text('试这一句'),
            ),
          ),
        ],
      ),
    );
  }
}
