import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';

class GardenPatchCard extends StatelessWidget {
  const GardenPatchCard({super.key, required this.patch});

  final GardenPatchSnapshot patch;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Container(
      key: Key('garden-patch-${patch.spaceId}'),
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
                  color: colors.successSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  patch.stage.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.success,
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
              GardenMetaChip(
                label:
                    '已开始 ${patch.startedActivityCount}/${patch.totalActivityCount}',
              ),
              GardenMetaChip(
                label:
                    '已完成 ${patch.completedActivityCount}/${patch.totalActivityCount}',
              ),
              GardenMetaChip(label: '${patch.totalKnownEvents} 次练习事件'),
            ],
          ),
          const SizedBox(height: 16),
          for (final activity in patch.activities) ...[
            GardenFlowerCard(activity: activity),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class GardenFlowerCard extends StatelessWidget {
  const GardenFlowerCard({super.key, required this.activity});

  final GardenFlowerSnapshot activity;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Container(
      key: Key('garden-flower-${activity.activityId}'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.bgSunken,
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
                  color: colors.englishSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  activity.stage.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.english,
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

class GardenMetaChip extends StatelessWidget {
  const GardenMetaChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.bgAccentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
