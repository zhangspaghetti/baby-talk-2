import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/practice/presentation/garden_growth_notifier.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_notifier.dart';
import 'package:mobile/l10n/app_localizations.dart';

class GardenHeroCard extends StatelessWidget {
  const GardenHeroCard({
    super.key,
    required this.snapshot,
    required this.status,
    required this.continuityNotifier,
    required this.continuitySnapshot,
    required this.continuityActivity,
  });

  final GardenGrowthSnapshot snapshot;
  final GardenGrowthLoadStatus status;
  final PracticeContinuityNotifier? continuityNotifier;
  final PracticeContinuitySnapshot? continuitySnapshot;
  final PracticeActivitySnapshot? continuityActivity;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final impact = snapshot.latestImpact;
    final theme = Theme.of(context);
    final continuityReasonLabel = _gardenContinuationReasonLabel(
      l,
      continuitySnapshot?.recommendation.reason,
    );
    final continuityActivityTitle = continuityActivity?.title;

    String eyebrow = l.gardenTodayChanges;
    String title = l.gardenEveryVoice;
    String body = l.gardenNoScores;

    if (status == GardenGrowthLoadStatus.loading ||
        status == GardenGrowthLoadStatus.idle) {
      title = l.gardenOrganizing;
      body = l.gardenProjectingNote;
    } else if (continuityNotifier == null) {
      eyebrow = l.gardenContinuityNotConnected;
      title = l.gardenContinueUnavailable;
      body = l.gardenUnavailable;
    } else if (continuityNotifier!.disabledReason != null) {
      eyebrow = l.gardenComeBack;
      title = continuityActivityTitle == null
          ? l.gardenContinueUnavailable
          : l.gardenContinueActivityTitle(continuityActivityTitle);
      body = l.gardenContinueUnavailableNote;
    } else if (impact != null) {
      eyebrow = impact.spaceTitle;
      title = continuityActivityTitle == null
          ? impact.headline
          : impact.headline;
      body = continuityActivityTitle == null
          ? impact.detail
          : impact.activityId ==
                continuitySnapshot?.recommendedActivity.activityId
          ? l.gardenImpactContinue(impact.detail, continuityActivityTitle)
          : l.gardenImpactWithReasonDetail(
              impact.activityTitle,
              continuityActivityTitle,
              continuityReasonLabel,
            );
    } else if (continuityActivityTitle != null) {
      eyebrow = l.gardenComeBack;
      title = l.gardenContinueActivityTitle(continuityActivityTitle);
      body = l.gardenContinuitySharedNote;
    }

    return Container(
      key: const Key('garden-hero-card'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineSoft),
        boxShadow: colors.warmShadowSm,
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
                color: colors.englishSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                impact.phraseTitle,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: colors.english,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(body, style: theme.textTheme.bodyMedium),
          if (continuityActivityTitle != null) ...[
            const SizedBox(height: 12),
            Text(
              '$continuityActivityTitle · $continuityReasonLabel',
              key: Key(
                'garden-continuity-target-${continuitySnapshot?.recommendedActivity.activityId ?? 'safe-empty'}',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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

String _gardenContinuationReasonLabel(
  AppLocalizations l,
  PracticeContinuityReason? reason,
) {
  switch (reason) {
    case PracticeContinuityReason.recentActivity:
      return l.gardenContinuationRecent;
    case PracticeContinuityReason.nextIncomplete:
      return l.gardenContinuationNextIncomplete;
    case PracticeContinuityReason.starterFallback:
      return l.gardenContinuationStarter;
    case PracticeContinuityReason.safeCatalogFallback:
      return l.gardenContinuationSafeFallback;
    case null:
      return l.gardenSharedContinuityUnavailable;
  }
}
