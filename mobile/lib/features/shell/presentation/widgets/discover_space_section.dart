import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/l10n/app_localizations.dart';

class DiscoverSpaceSection extends StatelessWidget {
  const DiscoverSpaceSection({
    super.key,
    required this.space,
    required this.onOpenActivity,
  });

  final PracticeCatalogSpaceSummary space;
  final ValueChanged<PracticeCatalogActivitySummary> onOpenActivity;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      key: Key('discover-space-section-${space.spaceId}'),
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
              color: colors.textSecondary,
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
                DiscoverSpaceGridItem(
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

class DiscoverSpaceGridItem extends StatelessWidget {
  const DiscoverSpaceGridItem({
    super.key,
    required this.activity,
    required this.onTap,
  });

  final PracticeCatalogActivitySummary activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final progress = activity.totalPhraseCount == 0
        ? 0.0
        : activity.completedPhraseCount / activity.totalPhraseCount;
    final highlight =
        activity.recentResult?.phraseEnglish ??
        activity.nextPhraseEnglish ??
        l.discoverOpenActivity;

    return Semantics(
      label: '空间活动: ${activity.title}',
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.bgAccentSoft, colors.bgSurface],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.outlineSoft),
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
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    highlight,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  LinearProgressIndicator(
                    key: Key('discover-space-progress-${activity.activityId}'),
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(999),
                    color: colors.english,
                    backgroundColor: colors.bgSurface,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${activity.completedPhraseCount}/${activity.totalPhraseCount} 句',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
