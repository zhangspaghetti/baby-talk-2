import 'package:flutter/material.dart';
import 'package:mobile/app/widgets/app_banner.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/household/presentation/household_view_model.dart';
import 'package:mobile/features/household/presentation/widgets/household_shared_context_card.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/presentation/garden_growth_view_model.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_view_model.dart';
import 'package:mobile/features/share/presentation/share_view_model.dart';
import 'package:mobile/features/share/presentation/widgets/share_callout_card.dart';
import 'package:mobile/features/shell/presentation/widgets/garden_continue_card.dart';
import 'package:mobile/features/shell/presentation/widgets/garden_hero_card.dart';
import 'package:mobile/features/shell/presentation/widgets/garden_patch_card.dart';
import 'package:provider/provider.dart';
import 'package:mobile/l10n/app_localizations.dart';

class GardenGrowthCombinedScreen extends StatelessWidget {
  const GardenGrowthCombinedScreen({super.key});

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
          constraints: const BoxConstraints(
            maxWidth: AppLayoutConstants.maxContentWidth,
          ),
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                if (viewModel != null) viewModel.refresh(),
                if (continuityViewModel != null)
                  continuityViewModel.refresh(
                    reason: 'growth_combined_pull_to_refresh',
                  ),
              ]);
            },
            child: ListView(
              key: const Key('shell-tab-growth-combined'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppLayoutConstants.shellTabPadding,
              children: [
                // ── 花园区：今日练习状态 ──
                GardenHeroCard(
                  snapshot: snapshot,
                  viewModel: viewModel,
                  continuityViewModel: continuityViewModel,
                  continuitySnapshot: continuitySnapshot,
                  continuityActivity: continuityActivity,
                ),
                const SizedBox(height: 16),
                GardenContinueCard(
                  practiceArgs: practiceArgs,
                  continuityViewModel: continuityViewModel,
                  continuitySnapshot: continuitySnapshot,
                  continuityActivity: continuityActivity,
                ),
                if (viewModel?.hasError ?? false) ...[
                  const SizedBox(height: 16),
                  AppBanner(
                    key: const Key('growth-combined-garden-warning-banner'),
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
                    GardenPatchCard(patch: patch),
                    const SizedBox(height: 16),
                  ],
                ],

                // ── 成长区：成长日记 & 里程碑 ──
                const SizedBox(height: 8),
                _GrowthHeroCard(snapshot: snapshot, viewModel: viewModel),
                if (!snapshot.isEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionTitle(title: l.growthAutoDiary),
                  const SizedBox(height: 12),
                  if (snapshot.diaryEntries.isEmpty)
                    _SectionEmptyCard(
                      stateKey: const Key('growth-combined-diary-empty'),
                      message: l.growthDiaryEmpty,
                    )
                  else
                    ...snapshot.diaryEntries
                        .take(3)
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _DiaryCard(entry: entry),
                          ),
                        ),
                  const SizedBox(height: 12),
                  _SectionTitle(title: l.growthMilestone),
                  const SizedBox(height: 12),
                  if (snapshot.milestones.isEmpty)
                    _SectionEmptyCard(
                      stateKey: const Key('growth-combined-milestones-empty'),
                      message: l.growthMilestoneEmpty,
                    )
                  else
                    ...snapshot.milestones
                        .take(6)
                        .map(
                          (milestone) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _MilestoneCard(milestone: milestone),
                          ),
                        ),
                ],

                // ── 共享家庭 & 分享 ──
                const SizedBox(height: 16),
                HouseholdSharedContextCard(
                  surfaceKeyPrefix: 'growth-combined',
                  viewModel: householdViewModel,
                  title: l.gardenSharedAttributionTitle,
                  retryReason: 'growth_combined_household_manual_refresh',
                ),
                if (shareViewModel != null) ...[
                  const SizedBox(height: 16),
                  ShareCalloutCard(
                    surfaceKeyPrefix: 'growth-combined',
                    viewModel: shareViewModel,
                    sectionLabel: l.gardenShareFamily,
                    emptyMessage: l.growthShareWaitStable,
                    onShare: () => shareViewModel.shareCurrent(),
                  ),
                ],
                if (shouldShowSharedOverlay) ...[
                  const SizedBox(height: 16),
                  HouseholdSharedPracticeOverlayCard(
                    surfaceKeyPrefix: 'growth-combined-shared-overlay',
                    sharedContext: sharedContext,
                  ),
                ],
                if (shouldShowSharedOverlayDisabled) ...[
                  const SizedBox(height: 16),
                  AppBanner(
                    key: const Key(
                      'growth-combined-shared-overlay-disabled-banner',
                    ),
                    message: householdSharedUnavailableNextStepMessage(
                      sharedContext,
                    ),
                    backgroundColor: colors.warningSoft,
                    foregroundColor: colors.warning,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GrowthHeroCard extends StatelessWidget {
  const _GrowthHeroCard({required this.snapshot, required this.viewModel});

  final GardenGrowthSnapshot snapshot;
  final GardenGrowthViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);
    final impact = snapshot.latestImpact;
    String title = l.growthNotScore;
    String body = l.growthNote;

    if (viewModel != null &&
        (viewModel!.status == GardenGrowthLoadStatus.loading ||
            viewModel!.status == GardenGrowthLoadStatus.idle)) {
      title = l.growthOrganizing;
      body = l.growthOrganizingNote;
    } else if (impact != null) {
      title = impact.headline;
      body = impact.detail;
    }

    return Container(
      key: const Key('growth-combined-latest-impact'),
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
          Text('Growth diary', style: theme.textTheme.labelMedium),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(body, style: theme.textTheme.bodyMedium),
          if (snapshot.hasIssues && snapshot.projectionWarning != null) ...[
            const SizedBox(height: 12),
            Text(
              snapshot.projectionWarning!,
              key: const Key('growth-combined-projection-warning'),
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
      key: const Key('growth-combined-empty-state'),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) =>
      Text(title, style: Theme.of(context).textTheme.titleMedium);
}

class _DiaryCard extends StatelessWidget {
  const _DiaryCard({required this.entry});

  final GrowthDiaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final accentColor = entry.kind == GrowthDiaryEntryKind.practice
        ? colors.english
        : colors.accentDark;
    return Container(
      key: Key('growth-combined-diary-${entry.entryId}'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 64,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(entry.body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({required this.milestone});

  final GrowthMilestoneSnapshot milestone;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final achieved = milestone.isAchieved;
    return Container(
      key: Key('growth-combined-milestone-${milestone.id}'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: achieved ? colors.successSoft : colors.bgSunken,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            achieved
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked,
            color: achieved ? colors.success : colors.textMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  milestone.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  milestone.body,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionEmptyCard extends StatelessWidget {
  const _SectionEmptyCard({required this.stateKey, required this.message});

  final Key stateKey;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      key: stateKey,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.bgSunken,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
