import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_surface_card.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/l10n/app_localizations.dart';

class DiscoverActivityCard extends StatelessWidget {
  const DiscoverActivityCard({
    super.key,
    required this.activity,
    required this.onOpen,
  });

  final PracticeCatalogActivitySummary activity;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final progress = activity.totalPhraseCount == 0
        ? 0.0
        : activity.completedPhraseCount / activity.totalPhraseCount;
    final hasRecentResult = activity.recentResult != null;
    final summary = activity.summary.trim().isEmpty
        ? l.discoverSummaryMissing
        : activity.summary;
    final footerText = hasRecentResult
        ? '${_reactionLabel(l, activity.recentResult!.reactionType)} · ${activity.recentResult!.phraseEnglish}'
        : (activity.nextPhraseEnglish?.trim().isNotEmpty ?? false)
        ? l.discoverNextPhrase(activity.nextPhraseEnglish!)
        : l.discoverNoNextPhrase;

    return Semantics(
      label: l.discoverActivityCardSemantics(activity.title),
      child: AppSurfaceCard(
        key: Key('discover-activity-card-${activity.activityId}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 64,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (activity.hasRecoverableIssue) ...[
                        Chip(label: Text(l.discoverNeedsAttention)),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        activity.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        summary,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              key: Key('discover-progress-${activity.activityId}'),
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              borderRadius: BorderRadius.circular(999),
              color: colors.accent,
              backgroundColor: colors.bgSunken,
            ),
            const SizedBox(height: 10),
            Text(
              l.discoverProgress(
                activity.completedPhraseCount,
                activity.totalPhraseCount,
                activity.totalEvents,
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Text(footerText, style: Theme.of(context).textTheme.bodyMedium),
            if (activity.warningMessage != null &&
                activity.warningMessage!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                activity.warningMessage!,
                key: Key('discover-activity-warning-${activity.activityId}'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              key: Key(
                'discover-route-target-${activity.spaceId}-${activity.activityId}',
              ),
              onPressed: onOpen,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                activity.isEmpty
                    ? l.discoverStartActivity
                    : l.discoverContinueActivity,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _reactionLabel(AppLocalizations l, BabyReactionType reactionType) {
  switch (reactionType) {
    case BabyReactionType.calm:
      return l.reactionCalm;
    case BabyReactionType.engaged:
      return l.reactionEngaged;
    case BabyReactionType.imitated:
      return l.reactionImitated;
    case BabyReactionType.needsBreak:
      return l.reactionNeedsBreak;
  }
}
