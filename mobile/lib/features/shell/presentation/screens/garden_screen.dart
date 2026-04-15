import 'package:flutter/material.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/presentation/garden_growth_view_model.dart';
import 'package:mobile/features/practice/presentation/practice_session_view_model.dart';
import 'package:provider/provider.dart';

class GardenScreen extends StatelessWidget {
  const GardenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<GardenGrowthViewModel?>();
    final snapshot = viewModel?.snapshot ?? GardenGrowthSnapshot.empty();
    final practiceViewModel = context.read<PracticeSessionViewModel?>();

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
              key: const Key('shell-tab-garden'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              children: [
                _GardenHeroCard(snapshot: snapshot, viewModel: viewModel),
                if (viewModel?.hasError ?? false) ...[
                  const SizedBox(height: 16),
                  _GardenBanner(
                    key: const Key('garden-warning-banner'),
                    message: viewModel!.message ?? '花园刷新失败，先保留上一次稳定结果。',
                    backgroundColor: AppTheme.warningSoft,
                    foregroundColor: AppTheme.warning,
                  ),
                ],
                const SizedBox(height: 16),
                if (snapshot.isEmpty)
                  const _GardenEmptyState()
                else ...[
                  for (final patch in snapshot.spaces) ...[
                    _GardenPatchCard(patch: patch),
                    const SizedBox(height: 16),
                  ],
                  _GardenContinueCard(practiceViewModel: practiceViewModel),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GardenHeroCard extends StatelessWidget {
  const _GardenHeroCard({required this.snapshot, required this.viewModel});

  final GardenGrowthSnapshot snapshot;
  final GardenGrowthViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final impact = snapshot.latestImpact;
    final theme = Theme.of(context);

    String eyebrow = '花园今日变化';
    String title = '每一次开口，花园都会记得。';
    String body = '这里不会给分数，只会把真实发生过的照护练习慢慢长成花圃与花朵。';

    if (viewModel != null &&
        (viewModel!.status == GardenGrowthLoadStatus.loading ||
            viewModel!.status == GardenGrowthLoadStatus.idle)) {
      title = '花园正在整理今天的变化';
      body = '事件会先被投影成花圃、花朵和阶段，再温柔地出现在这里。';
    } else if (impact != null) {
      eyebrow = impact.spaceTitle;
      title = impact.headline;
      body = impact.detail;
    }

    return Container(
      key: const Key('garden-hero-card'),
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
          Text(eyebrow, style: theme.textTheme.labelMedium),
          const SizedBox(height: 12),
          if (impact != null) ...[
            Container(
              key: const Key('garden-impact-phrase'),
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.englishSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                impact.phraseTitle,
                style: theme.textTheme.displayMedium?.copyWith(
                  fontSize: 28,
                  color: AppTheme.english,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(body, style: theme.textTheme.bodyMedium),
          if (snapshot.hasIssues && snapshot.projectionWarning != null) ...[
            const SizedBox(height: 12),
            Text(
              snapshot.projectionWarning!,
              key: const Key('garden-projection-warning'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _GardenEmptyState extends StatelessWidget {
  const _GardenEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('garden-empty-state'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.bgAccentSoft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('第一颗种子还没落下', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          Text(
            '先从一句 Warm water. 开始。花圃会先醒来，接着才慢慢长出花朵和节奏。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.accentDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _GardenPatchCard extends StatelessWidget {
  const _GardenPatchCard({required this.patch});

  final GardenPatchSnapshot patch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: Key('garden-patch-${patch.spaceId}'),
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
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patch.title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(patch.description, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                key: Key('garden-patch-stage-${patch.spaceId}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.successSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  patch.stage.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppTheme.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(patch.careNote, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _GardenMetaChip(
                label:
                    '已开始 ${patch.startedActivityCount}/${patch.totalActivityCount}',
              ),
              _GardenMetaChip(
                label:
                    '已完成 ${patch.completedActivityCount}/${patch.totalActivityCount}',
              ),
              _GardenMetaChip(label: '${patch.totalKnownEvents} 次练习事件'),
            ],
          ),
          const SizedBox(height: 16),
          for (final activity in patch.activities) ...[
            _GardenFlowerCard(activity: activity),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _GardenFlowerCard extends StatelessWidget {
  const _GardenFlowerCard({required this.activity});

  final GardenFlowerSnapshot activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: Key('garden-flower-${activity.activityId}'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgSunken,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(activity.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(activity.sceneTag, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Container(
                key: Key('garden-flower-stage-${activity.activityId}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.englishSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  activity.stage.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppTheme.english,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(activity.careNote, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
          Text(
            '已连起 ${activity.completedPhraseCount}/${activity.totalPhraseCount} 句 · ${activity.totalEvents} 次记录',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _GardenContinueCard extends StatelessWidget {
  const _GardenContinueCard({required this.practiceViewModel});

  final PracticeSessionViewModel? practiceViewModel;

  @override
  Widget build(BuildContext context) {
    final canContinue = practiceViewModel?.canStartPractice ?? false;
    return Container(
      key: const Key('garden-continue-card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.englishSoft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('继续浇灌', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '如果你现在继续练习，花朵阶段和成长日记会沿着同一份投影一起更新。',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            key: const Key('garden-continue-practice'),
            onPressed: !canContinue
                ? null
                : () async {
                    final ready = await practiceViewModel!.ensureSessionReady();
                    if (!context.mounted || !ready) {
                      return;
                    }
                    Navigator.of(context).pushNamed(AppRouteNames.practice);
                  },
            child: const Text('继续今天的练习'),
          ),
        ],
      ),
    );
  }
}

class _GardenMetaChip extends StatelessWidget {
  const _GardenMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.bgAccentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _GardenBanner extends StatelessWidget {
  const _GardenBanner({
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
