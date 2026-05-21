import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/l10n/app_localizations.dart';

class GardenPatchCard extends StatelessWidget {
  const GardenPatchCard({super.key, required this.patch});

  final GardenPatchSnapshot patch;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: l.gardenPatchSemantics(patch.title, patch.stage.label),
      child: Container(
        key: Key('garden-patch-${patch.spaceId}'),
        padding: const EdgeInsets.all(AppLayoutConstants.spacingLg),
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
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patch.title, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text(
                        patch.description,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppLayoutConstants.spacingSm),
                Container(
                  key: Key('garden-patch-stage-${patch.spaceId}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppLayoutConstants.spacingSm,
                    vertical: AppLayoutConstants.spacingXs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.successSoft,
                    borderRadius: BorderRadius.circular(
                      AppLayoutConstants.pillRadius,
                    ),
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
            const SizedBox(height: AppLayoutConstants.spacingSm),
            Text(patch.careNote, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppLayoutConstants.spacingMd),
            Wrap(
              spacing: AppLayoutConstants.spacingXs,
              runSpacing: AppLayoutConstants.spacingXs,
              children: [
                GardenMetaChip(
                  label: l.gardenStartedProgress(
                    patch.startedActivityCount,
                    patch.totalActivityCount,
                  ),
                ),
                GardenMetaChip(
                  label: l.gardenCompletedProgress(
                    patch.completedActivityCount,
                    patch.totalActivityCount,
                  ),
                ),
                GardenMetaChip(
                  label: l.gardenTotalEvents(patch.totalKnownEvents),
                ),
              ],
            ),
            const SizedBox(height: AppLayoutConstants.spacingMd),
            for (final activity in patch.activities) ...[
              GardenFlowerCard(activity: activity),
              const SizedBox(height: AppLayoutConstants.spacingSm),
            ],
          ],
        ),
      ),
    );
  }
}

class GardenFlowerCard extends StatelessWidget {
  const GardenFlowerCard({super.key, required this.activity});

  final GardenFlowerSnapshot activity;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: l.gardenFlowerSemantics(activity.title, activity.stage.label),
      child: Container(
        key: Key('garden-flower-${activity.activityId}'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppLayoutConstants.spacingMd),
        decoration: BoxDecoration(
          color: colors.bgSunken,
          borderRadius: BorderRadius.circular(AppLayoutConstants.mediumRadius),
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
                    horizontal: AppLayoutConstants.spacingSm,
                    vertical: AppLayoutConstants.spacingXs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.englishSoft,
                    borderRadius: BorderRadius.circular(
                      AppLayoutConstants.pillRadius,
                    ),
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
            const SizedBox(height: AppLayoutConstants.spacingXs),
            Text(activity.careNote, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppLayoutConstants.spacingXs),
            Text(
              l.gardenActivityProgress(
                activity.completedPhraseCount,
                activity.totalPhraseCount,
                activity.totalEvents,
              ),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppLayoutConstants.spacingXs,
        vertical: AppLayoutConstants.spacingXs,
      ),
      decoration: BoxDecoration(
        color: colors.bgAccentSoft,
        borderRadius: BorderRadius.circular(AppLayoutConstants.pillRadius),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
