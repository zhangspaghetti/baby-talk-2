import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/practice/presentation/garden_growth_view_model.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_view_model.dart';
import 'package:mobile/l10n/app_localizations.dart';

class GardenHeroCard extends StatelessWidget {
  const GardenHeroCard({
    super.key,
    required this.snapshot,
    required this.viewModel,
    required this.continuityViewModel,
    required this.continuitySnapshot,
    required this.continuityActivity,
  });

  final GardenGrowthSnapshot snapshot;
  final GardenGrowthViewModel? viewModel;
  final PracticeContinuityViewModel? continuityViewModel;
  final PracticeContinuitySnapshot? continuitySnapshot;
  final PracticeActivitySnapshot? continuityActivity;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final impact = snapshot.latestImpact;
    final theme = Theme.of(context);
    final continuityReasonLabel =
        continuitySnapshot?.recommendation.reasonLabel;
    final continuityActivityTitle = continuityActivity?.title;

    String eyebrow = l.gardenTodayChanges;
    String title = l.gardenEveryVoice;
    String body = l.gardenNoScores;

    if (viewModel != null &&
        (viewModel!.status == GardenGrowthLoadStatus.loading ||
            viewModel!.status == GardenGrowthLoadStatus.idle)) {
      title = l.gardenOrganizing;
      body = l.gardenProjectingNote;
    } else if (continuityViewModel == null) {
      eyebrow = l.gardenContinuityNotConnected;
      title = '继续入口暂不可用';
      body = l.gardenUnavailable;
    } else if (continuityViewModel!.disabledReason != null) {
      eyebrow = l.gardenComeBack;
      title = continuityActivityTitle == null
          ? '继续入口暂不可用'
          : '继续 $continuityActivityTitle';
      body = continuityViewModel!.disabledReason!;
    } else if (impact != null) {
      eyebrow = impact.spaceTitle;
      title = continuityActivityTitle == null
          ? impact.headline
          : impact.headline;
      body = continuityActivityTitle == null
          ? impact.detail
          : impact.activityId ==
                continuitySnapshot?.recommendedActivity.activityId
          ? '${impact.detail} 现在继续会回到 $continuityActivityTitle。'
          : '最新影响来自 ${impact.activityTitle}；回来继续会去 $continuityActivityTitle（${continuityReasonLabel ?? l.gardenSharedContinuity}）。';
    } else if (continuityActivityTitle != null) {
      eyebrow = l.gardenComeBack;
      title = '继续 $continuityActivityTitle';
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
                style: theme.textTheme.displayMedium?.copyWith(
                  fontSize: 28,
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
              '$continuityActivityTitle · ${continuityReasonLabel ?? l.gardenSharedContinuity}',
              key: Key(
                'garden-continuity-target-${continuitySnapshot?.recommendedActivity.activityId ?? 'safe-empty'}',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (kDebugMode) ...[
            const SizedBox(height: 12),
            Text(
              'continuity: ${continuityViewModel?.status.label ?? 'missing_provider'}${continuityViewModel?.lastRefreshReason == null ? '' : ' · refresh: ${continuityViewModel!.lastRefreshReason}'}',
              key: const Key('garden-continuity-status'),
              style: theme.textTheme.bodySmall,
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
