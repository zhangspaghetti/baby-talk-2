import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/presentation/garden_growth_view_model.dart';
import 'package:provider/provider.dart';

class GrowthScreen extends StatelessWidget {
  const GrowthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<GardenGrowthViewModel?>();
    final snapshot = viewModel?.snapshot ?? GardenGrowthSnapshot.empty();

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: RefreshIndicator(
            onRefresh: () async {
              if (viewModel != null) {
                await viewModel.refresh();
              }
            },
            child: ListView(
              key: const Key('shell-tab-growth'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              children: [
                _GrowthHeroCard(snapshot: snapshot, viewModel: viewModel),
                if (viewModel?.hasError ?? false) ...[
                  const SizedBox(height: 16),
                  _GrowthBanner(
                    key: const Key('growth-warning-banner'),
                    message: viewModel!.message ?? '成长页刷新失败，先保留上次稳定结果。',
                    backgroundColor: AppTheme.warningSoft,
                    foregroundColor: AppTheme.warning,
                  ),
                ],
                const SizedBox(height: 16),
                if (snapshot.isEmpty) const _GrowthEmptyState(),
                if (!snapshot.isEmpty) ...[
                  _SectionTitle(title: '自动日记'),
                  const SizedBox(height: 12),
                  if (snapshot.diaryEntries.isEmpty)
                    const _SectionEmptyCard(
                      stateKey: Key('growth-diary-empty'),
                      message: '还没有自动日记，第一次练习完成后会在这里记下变化。',
                    )
                  else
                    ...snapshot.diaryEntries
                        .take(3)
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _DiaryCard(entry: entry),
                          ),
                        ),
                  const SizedBox(height: 12),
                  _SectionTitle(title: '场景进展'),
                  const SizedBox(height: 12),
                  if (snapshot.spaces.isEmpty)
                    const _SectionEmptyCard(
                      stateKey: Key('growth-space-empty'),
                      message: '花圃还没醒来，所以暂时没有场景进展。',
                    )
                  else
                    ...snapshot.spaces.map(
                      (space) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SpaceProgressCard(space: space),
                      ),
                    ),
                  const SizedBox(height: 12),
                  _SectionTitle(title: '里程碑'),
                  const SizedBox(height: 12),
                  if (snapshot.milestones.isEmpty)
                    const _SectionEmptyCard(
                      stateKey: Key('growth-milestones-empty'),
                      message: '里程碑会在真实练习后逐步点亮。',
                    )
                  else
                    ...snapshot.milestones
                        .take(6)
                        .map(
                          (milestone) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _MilestoneCard(milestone: milestone),
                          ),
                        ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GrowthHeroCard extends StatelessWidget {
  const _GrowthHeroCard({required this.snapshot, required this.viewModel});

  final GardenGrowthSnapshot snapshot;
  final GardenGrowthViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final impact = snapshot.latestImpact;
    String title = '成长不是分数，而是一串串被记住的变化。';
    String body = '这里会按时间整理自动日记、空间进展和里程碑，帮助你回看今天发生过什么。';

    if (viewModel != null &&
        (viewModel!.status == GardenGrowthLoadStatus.loading ||
            viewModel!.status == GardenGrowthLoadStatus.idle)) {
      title = '成长页正在整理练习记录';
      body = '等投影准备好后，这里会出现最新一次变化、自动日记和里程碑。';
    } else if (impact != null) {
      title = impact.headline;
      body = impact.detail;
    }

    return Container(
      key: const Key('growth-latest-impact'),
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
          Text('Growth diary', style: theme.textTheme.labelMedium),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(body, style: theme.textTheme.bodyMedium),
          if (snapshot.hasIssues && snapshot.projectionWarning != null) ...[
            const SizedBox(height: 12),
            Text(
              snapshot.projectionWarning!,
              key: const Key('growth-projection-warning'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _GrowthEmptyState extends StatelessWidget {
  const _GrowthEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('growth-empty-state'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.bgAccentSoft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('最近成长会写在这里', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Text(
            '完成一次真实练习后，这里会告诉你哪朵花发芽了、哪条日记被写下来了。',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.accentDark),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _DiaryCard extends StatelessWidget {
  const _DiaryCard({required this.entry});

  final GrowthDiaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = entry.kind == GrowthDiaryEntryKind.practice
        ? AppTheme.english
        : AppTheme.accentDark;
    return Container(
      key: Key('growth-diary-${entry.entryId}'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.outlineSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 64,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(entry.body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpaceProgressCard extends StatelessWidget {
  const _SpaceProgressCard({required this.space});

  final GardenPatchSnapshot space;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('growth-space-${space.spaceId}'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  space.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Container(
                key: Key('growth-space-stage-${space.spaceId}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.successSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  space.stage.label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: AppTheme.success),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(space.careNote, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 10),
          Text(
            '已开始 ${space.startedActivityCount}/${space.totalActivityCount} 个活动 · 已完成 ${space.completedActivityCount}/${space.totalActivityCount} 个活动',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({required this.milestone});

  final GrowthMilestoneSnapshot milestone;

  @override
  Widget build(BuildContext context) {
    final achieved = milestone.isAchieved;
    return Container(
      key: Key('growth-milestone-${milestone.id}'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: achieved ? AppTheme.successSoft : AppTheme.bgSunken,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            achieved
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked,
            color: achieved ? AppTheme.success : AppTheme.textMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  milestone.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  milestone.body,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionEmptyCard extends StatelessWidget {
  const _SectionEmptyCard({required this.stateKey, required this.message});

  final Key stateKey;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: stateKey,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgSunken,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _GrowthBanner extends StatelessWidget {
  const _GrowthBanner({
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
