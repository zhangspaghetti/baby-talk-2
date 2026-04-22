import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/household/presentation/household_view_model.dart';
import 'package:mobile/features/household/presentation/widgets/household_shared_context_card.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart';
import 'package:mobile/features/practice/presentation/garden_growth_view_model.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_view_model.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/features/share/presentation/share_view_model.dart';
import 'package:mobile/features/share/presentation/widgets/share_callout_card.dart';
import 'package:provider/provider.dart';
import 'package:mobile/l10n/app_localizations.dart';

class GardenScreen extends StatelessWidget {
  const GardenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final viewModel = context.watch<GardenGrowthViewModel?>();
    final continuityViewModel = context.watch<PracticeContinuityViewModel?>();
    final householdViewModel = context.watch<HouseholdViewModel?>();
    final shareViewModel = context.watch<ShareViewModel?>();
    final snapshot = viewModel?.snapshot ?? GardenGrowthSnapshot.empty();
    final continuitySnapshot = continuityViewModel?.snapshot;
    final continuityActivity = continuityViewModel?.activitySnapshot;
    final practiceArgs = continuityViewModel?.recommendedArgs;
    final sharedContext = householdViewModel?.snapshot.sharedContext;
    final sharedNextStepArgs = resolveHouseholdSharedNextStepArgs(
      sharedContext,
    );
    final localGardenAt =
        snapshot.latestImpact?.occurredAt ??
        snapshot.primarySpace?.lastPracticedAt ??
        continuitySnapshot?.cadence.lastEventTime;
    final isSharedOverlayNewer =
        continuityViewModel != null &&
        sharedContext != null &&
        isHouseholdSharedProjectionNewer(sharedContext, localGardenAt);
    final shouldShowSharedOverlay =
        isSharedOverlayNewer && sharedNextStepArgs != null;
    final shouldShowSharedOverlayDisabled =
        isSharedOverlayNewer && sharedNextStepArgs == null;

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                if (viewModel != null) viewModel.refresh(),
                if (continuityViewModel != null)
                  continuityViewModel.refresh(reason: 'garden_pull_to_refresh'),
              ]);
            },
            child: ListView(
              key: const Key('shell-tab-garden'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              children: [
                _GardenHeroCard(
                  snapshot: snapshot,
                  viewModel: viewModel,
                  continuityViewModel: continuityViewModel,
                  continuitySnapshot: continuitySnapshot,
                  continuityActivity: continuityActivity,
                ),
                const SizedBox(height: 16),
                HouseholdSharedContextCard(
                  surfaceKeyPrefix: 'garden',
                  viewModel: householdViewModel,
                  title: l.gardenSharedAttributionTitle,
                  retryReason: 'garden_household_manual_refresh',
                ),
                if (shareViewModel != null) ...[
                  const SizedBox(height: 16),
                  ShareCalloutCard(
                    surfaceKeyPrefix: 'garden',
                    viewModel: shareViewModel,
                    sectionLabel: l.gardenShareFamily,
                    emptyMessage: '等最近成长和继续建议整理稳定后，再生成一条脱敏分享链接。',
                    onShare: () => shareViewModel.shareCurrent(),
                  ),
                ],
                if (viewModel?.hasError ?? false) ...[
                  const SizedBox(height: 16),
                  _GardenBanner(
                    key: const Key('garden-warning-banner'),
                    message: viewModel!.message ?? l.gardenRefreshFailed,
                    backgroundColor: colors.warningSoft,
                    foregroundColor: colors.warning,
                  ),
                ],
                const SizedBox(height: 16),
                if (snapshot.isEmpty)
                  const _GardenEmptyState()
                else ...[
                  for (final patch in snapshot.spaces) ...[
                    _GardenPatchCard(patch: patch),
                    const SizedBox(height: 16),
                  ],
                ],
                const SizedBox(height: 16),
                if (shouldShowSharedOverlay) ...[
                  HouseholdSharedPracticeOverlayCard(
                    surfaceKeyPrefix: 'garden-shared-overlay',
                    sharedContext: sharedContext,
                  ),
                  const SizedBox(height: 16),
                ],
                if (shouldShowSharedOverlayDisabled) ...[
                  _GardenBanner(
                    key: const Key('garden-shared-overlay-disabled-banner'),
                    message: householdSharedUnavailableNextStepMessage(
                      sharedContext,
                    ),
                    backgroundColor: colors.warningSoft,
                    foregroundColor: colors.warning,
                  ),
                  const SizedBox(height: 16),
                ],
                _GardenContinueCard(
                  practiceArgs: practiceArgs,
                  continuityViewModel: continuityViewModel,
                  continuitySnapshot: continuitySnapshot,
                  continuityActivity: continuityActivity,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GardenHeroCard extends StatelessWidget {
  const _GardenHeroCard({
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

class _GardenEmptyState extends StatelessWidget {
  const _GardenEmptyState();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Container(
      key: const Key('garden-empty-state'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.bgAccentSoft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.gardenFirstSeedNotPlanted, style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          Text(
            l.gardenFirstSeedNote,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.accentDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _GardenPatchCard extends StatelessWidget {
  const _GardenPatchCard({required this.patch});

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
              _GardenMetaChip(
                label:
                    '已开始 ${patch.startedActivityCount}/${patch.totalActivityCount}',
              ),
              _GardenMetaChip(
                label:
                    '已完成 ${patch.completedActivityCount}/${patch.totalActivityCount}',
              ),
              _GardenMetaChip(label: '${patch.totalKnownEvents} 次练习事件'),
            ],
          ),
          const SizedBox(height: 16),
          for (final activity in patch.activities) ...[
            _GardenFlowerCard(activity: activity),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _GardenFlowerCard extends StatelessWidget {
  const _GardenFlowerCard({required this.activity});

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

class _GardenContinueCard extends StatelessWidget {
  const _GardenContinueCard({
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

class _GardenMetaChip extends StatelessWidget {
  const _GardenMetaChip({required this.label});

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

class _GardenBanner extends StatelessWidget {
  const _GardenBanner({
    super.key,
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String message;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
