import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/l10n/app_localizations.dart';

class HomeWeekStatsCard extends StatelessWidget {
  const HomeWeekStatsCard({super.key, required this.continuitySnapshot});

  final PracticeContinuitySnapshot? continuitySnapshot;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final recommendedActivity = continuitySnapshot?.recommendedActivity;
    final cadence = continuitySnapshot?.cadence;
    return Semantics(
      label: '本周练习统计',
      child: Container(
        key: ValueKey(
          'home-week-stats-${recommendedActivity?.activityId ?? 'loading'}',
        ),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.bgSunken,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: HomeStatCell(
                label: l.homeRecommendedActivity,
                value: recommendedActivity?.title ?? l.homeOrganizing,
                hint:
                    _homeContinuationReasonLabel(
                      l,
                      continuitySnapshot?.recommendation.reason,
                    ) ??
                    l.homeWaitingContinuity,
              ),
            ),
            Container(width: 1, height: 40, color: colors.outlineSoft),
            Expanded(
              child: HomeStatCell(
                key: ValueKey(
                  'home-cadence-summary-${recommendedActivity?.activityId ?? 'loading'}',
                ),
                label: l.homeCadence,
                value: cadence?.headline ?? l.homeOrganizing,
                hint: cadence?.detail ?? l.homeDerivingCadence,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _homeContinuationReasonLabel(
    AppLocalizations l,
    PracticeContinuityReason? reason,
  ) {
    switch (reason) {
      case PracticeContinuityReason.recentActivity:
        return l.homeContinuationRecent;
      case PracticeContinuityReason.nextIncomplete:
        return l.homeContinuationNextIncomplete;
      case PracticeContinuityReason.starterFallback:
        return l.homeContinuationStarter;
      case PracticeContinuityReason.safeCatalogFallback:
        return l.homeContinuationSafeFallback;
      case null:
        return null;
    }
  }
}

class HomeStatCell extends StatelessWidget {
  const HomeStatCell({
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
    final colors = context.appColors;
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
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(hint, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
