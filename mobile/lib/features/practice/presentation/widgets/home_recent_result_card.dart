import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/l10n/app_localizations.dart';

class HomeRecentResultCard extends StatelessWidget {
  const HomeRecentResultCard({super.key, required this.continuitySnapshot});

  final PracticeContinuitySnapshot? continuitySnapshot;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final recommendedActivity = continuitySnapshot?.recommendedActivity;
    final recentResult = recommendedActivity?.recentResult;
    final activityId = recommendedActivity?.activityId ?? 'empty';

    return Container(
      key: ValueKey('recent-result-$activityId'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.bgSunken,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.homeRecentLocalResult,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (recentResult == null)
            Text(
              continuitySnapshot?.fallbackReason == null
                  ? l.homeNoLocalRecords
                  : l.homeRecentFallbackNote,
              key: const Key('recent-result-empty'),
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            Column(
              key: const Key('recent-result-summary'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${recentResult.phraseEnglish} · ${_labelForReaction(l, recentResult.reactionType)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  l.homeRecentResultDetail(
                    recommendedActivity?.totalEvents.toString() ?? '0',
                    _formatTime(recentResult.eventTime),
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _labelForReaction(AppLocalizations l, BabyReactionType reactionType) {
    switch (reactionType) {
      case BabyReactionType.cooperating:
        return l.reactionCooperating;
      case BabyReactionType.hesitant:
        return l.reactionHesitant;
      case BabyReactionType.resisting:
        return l.reactionResisting;
      case BabyReactionType.noResponse:
        return l.reactionNoResponse;
      case BabyReactionType.other:
        return l.reactionOther;
    }
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
