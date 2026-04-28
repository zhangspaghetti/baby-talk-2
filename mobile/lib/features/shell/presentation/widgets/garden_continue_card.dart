import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_view_model.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/l10n/app_localizations.dart';

class GardenContinueCard extends StatelessWidget {
  const GardenContinueCard({
    super.key,
    required this.practiceArgs,
    required this.continuityViewModel,
    required this.continuitySnapshot,
    required this.continuityActivity,
  });

  final PracticeRouteArgs? practiceArgs;
  final PracticeContinuityViewModel? continuityViewModel;
  final PracticeContinuitySnapshot? continuitySnapshot;
  final PracticeActivitySnapshot? continuityActivity;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final canContinue =
        practiceArgs != null &&
        !(continuityViewModel?.isActionDisabled ?? true);
    final activityId =
        continuitySnapshot?.recommendedActivity.activityId ?? 'safe-empty';
    final activityTitle = continuityActivity?.title ?? '继续入口暂不可用';
    final reasonLabel =
        continuitySnapshot?.recommendation.reasonLabel ??
        l.gardenSharedContinuityUnavailable;
    final warningMessage = continuityViewModel?.warningMessage;
    final disabledReason = continuityViewModel == null
        ? '练习入口暂时不可用。'
        : continuityViewModel?.disabledReason;

    return Container(
      key: const Key('garden-continue-card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.englishSoft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.gardenContinueWatering,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            activityTitle,
            key: Key('garden-continue-target-$activityId'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            reasonLabel,
            key: Key('garden-continue-reason-$activityId'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.gardenContinueNote,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
          ),
          if (continuitySnapshot?.fallbackReason != null) ...[
            const SizedBox(height: 12),
            Text(
              continuitySnapshot!.fallbackReason!,
              key: const Key('garden-continuity-fallback'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.info,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (warningMessage != null && warningMessage.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              warningMessage,
              key: const Key('garden-continuity-warning'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (!canContinue && disabledReason != null) ...[
            const SizedBox(height: 12),
            Text(
              disabledReason,
              key: const Key('garden-launcher-bad-args'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            key: const Key('garden-continue-practice'),
            onPressed: !canContinue
                ? null
                : () async {
                    await practiceArgs!.push(context);
                  },
            child: Text(l.gardenContinueToday),
          ),
        ],
      ),
    );
  }
}
