import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/l10n/app_localizations.dart';

class HomeTodaySceneCard extends StatelessWidget {
  const HomeTodaySceneCard({
    super.key,
    required this.activityId,
    required this.activityTitle,
    required this.activitySummary,
    required this.sceneTag,
    required this.recommendation,
    required this.nextIncompleteActivity,
    required this.buttonLabel,
    required this.disabledReason,
    required this.onPressed,
  });

  final String activityId;
  final String activityTitle;
  final String activitySummary;
  final String? sceneTag;
  final PracticeContinuityRecommendation? recommendation;
  final PracticeCatalogActivitySummary? nextIncompleteActivity;
  final String buttonLabel;
  final String? disabledReason;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    return Semantics(
      label: '今日场景: $activityTitle',
      child: Container(
        decoration: BoxDecoration(
          color: colors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outlineSoft),
          boxShadow: colors.warmShadowMd,
        ),
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
                recommendation?.reasonLabel ?? l.homeContinuityUnavailable,
                key: ValueKey('home-continuity-reason-$activityId'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
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
                  l.homeNextAlternative(nextIncompleteActivity!.title),
                  key: ValueKey(
                    'home-next-incomplete-${nextIncompleteActivity!.activityId}',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (disabledReason != null) ...[
                const SizedBox(height: 12),
                Text(
                  disabledReason!,
                  key: ValueKey('home-start-disabled-$activityId'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                key: const Key('home-start-practice'),
                onPressed: onPressed,
                child: Text(buttonLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
