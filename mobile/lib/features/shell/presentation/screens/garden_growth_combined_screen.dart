import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/widgets/app_banner.dart';
import 'package:mobile/app/widgets/app_empty_state.dart';
import 'package:mobile/app/widgets/app_haptics.dart';
import 'package:mobile/app/widgets/app_shimmer.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/household/presentation/household_view_model.dart';
import 'package:mobile/features/household/presentation/widgets/household_shared_context_card.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart'
    show PracticeActivitySnapshot;
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart'
    show PracticeContinuitySnapshot;
import 'package:mobile/features/practice/presentation/garden_growth_notifier.dart';
import 'package:mobile/features/practice/presentation/garden_growth_view_model.dart'
    show GardenGrowthLoadStatus;
import 'package:mobile/features/practice/presentation/practice_continuity_view_model.dart';
import 'package:mobile/features/share/presentation/share_view_model.dart';
import 'package:mobile/features/share/presentation/widgets/share_callout_card.dart';
import 'package:mobile/features/shell/presentation/widgets/garden_continue_card.dart';
import 'package:mobile/features/shell/presentation/widgets/garden_hero_card.dart';
import 'package:mobile/features/shell/presentation/widgets/garden_patch_card.dart';
import 'package:provider/provider.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// Internal tab index for the segmented control.
enum _GrowthTab { garden, growth }

class GardenGrowthCombinedScreen extends ConsumerStatefulWidget {
  const GardenGrowthCombinedScreen({super.key});

  @override
  ConsumerState<GardenGrowthCombinedScreen> createState() =>
      _GardenGrowthCombinedScreenState();
}

class _GardenGrowthCombinedScreenState
    extends ConsumerState<GardenGrowthCombinedScreen> {
  _GrowthTab _selectedTab = _GrowthTab.garden;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;

    // Riverpod: garden growth notifier
    final gardenNotifier = ref.watch(gardenGrowthNotifierProvider);
    final gardenSnapshot = gardenNotifier.snapshot;
    final gardenStatus = gardenNotifier.status;

    // Provider: other ViewModels (still Provider-based)
    final continuityViewModel = context.watch<PracticeContinuityViewModel?>();
    final householdViewModel = context.watch<HouseholdViewModel?>();
    final shareViewModel = context.watch<ShareViewModel?>();
    final continuitySnapshot = continuityViewModel?.snapshot;
    final continuityActivity = continuityViewModel?.activitySnapshot;
    final practiceArgs = continuityViewModel?.recommendedArgs;

    // Shared context
    final sharedContext = householdViewModel?.snapshot.sharedContext;
    final sharedNextStepArgs = resolveHouseholdSharedNextStepArgs(
      sharedContext,
    );
    final localGardenAt =
        gardenSnapshot.latestImpact?.occurredAt ??
        gardenSnapshot.primarySpace?.lastPracticedAt ??
        continuitySnapshot?.cadence.lastEventTime;
    final isSharedOverlayNewer =
        continuityViewModel != null &&
        sharedContext != null &&
        isHouseholdSharedProjectionNewer(sharedContext, localGardenAt);
    final shouldShowSharedOverlay =
        isSharedOverlayNewer && sharedNextStepArgs != null;
    final shouldShowSharedOverlayDisabled =
        isSharedOverlayNewer && sharedNextStepArgs == null;

    // Loading state for shimmer
    final isLoading =
        gardenStatus == GardenGrowthLoadStatus.loading ||
        gardenStatus == GardenGrowthLoadStatus.idle;

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
              AppHaptics.lightTap();
              await Future.wait([
                gardenNotifier.refresh(),
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
                // ── Segmented control: 花园 / 成长 ──
                _GardenSegmentedControl(
                  selectedTab: _selectedTab,
                  onTabChanged: (tab) {
                    AppHaptics.selectionClick();
                    setState(() => _selectedTab = tab);
                  },
                ),
                const SizedBox(height: 20),

                // ── Shared error banner ──
                if (gardenNotifier.hasError) ...[
                  AppBanner(
                    key: const Key('growth-combined-garden-warning-banner'),
                    message: gardenNotifier.message ?? l.gardenRefreshFailed,
                    backgroundColor: colors.warningSoft,
                    foregroundColor: colors.warning,
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Tab content ──
                if (_selectedTab == _GrowthTab.garden)
                  _buildGardenTab(
                    context: context,
                    l: l,
                    colors: colors,
                    snapshot: gardenSnapshot,
                    isLoading: isLoading,
                    gardenNotifier: gardenNotifier,
                    continuityViewModel: continuityViewModel,
                    continuitySnapshot: continuitySnapshot,
                    continuityActivity: continuityActivity,
                    practiceArgs: practiceArgs,
                  )
                else
                  _buildGrowthTab(
                    context: context,
                    l: l,
                    colors: colors,
                    snapshot: gardenSnapshot,
                    gardenNotifier: gardenNotifier,
                  ),

                // ── Shared household & share section (always visible) ──
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

  // ---------------------------------------------------------------------------
  // Garden tab
  // ---------------------------------------------------------------------------

  Widget _buildGardenTab({
    required BuildContext context,
    required AppLocalizations l,
    required BabyTalkColors colors,
    required GardenGrowthSnapshot snapshot,
    required bool isLoading,
    required GardenGrowthNotifier gardenNotifier,
    required PracticeContinuityViewModel? continuityViewModel,
    required PracticeContinuitySnapshot? continuitySnapshot,
    required PracticeActivitySnapshot? continuityActivity,
    required dynamic practiceArgs,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Hero card ──
        GardenHeroCard(
          snapshot: snapshot,
          status: gardenNotifier.status,
          continuityViewModel: continuityViewModel,
          continuitySnapshot: continuitySnapshot,
          continuityActivity: continuityActivity,
        ),
        const SizedBox(height: 16),

        // ── Continue card ──
        GardenContinueCard(
          practiceArgs: practiceArgs,
          continuityViewModel: continuityViewModel,
          continuitySnapshot: continuitySnapshot,
          continuityActivity: continuityActivity,
        ),
        const SizedBox(height: 16),

        // ── Loading shimmer or content ──
        if (isLoading)
          const _GardenLoadingShimmer()
        else if (snapshot.isEmpty)
          AppEmptyState(
            key: const Key('growth-combined-empty-state'),
            icon: Icons.local_florist_rounded,
            title: l.gardenFirstSeedNotPlanted,
            description: l.gardenFirstSeedNote,
          )
        else
          for (final patch in snapshot.spaces) ...[
            GardenPatchCard(patch: patch),
            const SizedBox(height: 16),
          ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Growth tab
  // ---------------------------------------------------------------------------

  Widget _buildGrowthTab({
    required BuildContext context,
    required AppLocalizations l,
    required BabyTalkColors colors,
    required GardenGrowthSnapshot snapshot,
    required GardenGrowthNotifier gardenNotifier,
  }) {
    final theme = Theme.of(context);
    final impact = snapshot.latestImpact;
    String title = l.growthNotScore;
    String body = l.growthNote;

    if (gardenNotifier.status == GardenGrowthLoadStatus.loading ||
        gardenNotifier.status == GardenGrowthLoadStatus.idle) {
      title = l.growthOrganizing;
      body = l.growthOrganizingNote;
    } else if (impact != null) {
      title = impact.headline;
      body = impact.detail;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Growth hero card ──
        Container(
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
        ),

        if (!snapshot.isEmpty) ...[
          // ── Diary section ──
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.growthAutoDiary, style: theme.textTheme.titleMedium),
              if (snapshot.diaryEntries.length > 3)
                TextButton(
                  key: const Key('growth-combined-diary-view-all'),
                  onPressed: () {
                    AppHaptics.lightTap();
                    // TODO: navigate to full diary list
                  },
                  child: const Text('查看全部'),
                ),
            ],
          ),
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

          // ── Milestones section ──
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.growthMilestone, style: theme.textTheme.titleMedium),
              if (snapshot.milestones.length > 6)
                TextButton(
                  key: const Key('growth-combined-milestones-view-all'),
                  onPressed: () {
                    AppHaptics.lightTap();
                    // TODO: navigate to full milestones list
                  },
                  child: const Text('查看全部'),
                ),
            ],
          ),
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
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Segmented control
// ---------------------------------------------------------------------------

class _GardenSegmentedControl extends StatelessWidget {
  const _GardenSegmentedControl({
    required this.selectedTab,
    required this.onTabChanged,
  });

  final _GrowthTab selectedTab;
  final ValueChanged<_GrowthTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l = AppLocalizations.of(context)!;
    return Container(
      key: const Key('growth-combined-segmented-control'),
      decoration: BoxDecoration(
        color: colors.bgSunken,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _SegmentTab(
              label: l.shellGarden,
              isSelected: selectedTab == _GrowthTab.garden,
              onTap: () => onTabChanged(_GrowthTab.garden),
            ),
          ),
          Expanded(
            child: _SegmentTab(
              label: l.shellGrowth,
              isSelected: selectedTab == _GrowthTab.growth,
              onTap: () => onTabChanged(_GrowthTab.growth),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? colors.bgSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected ? colors.warmShadowSm : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            color: isSelected ? colors.textPrimary : colors.textMuted,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading shimmer
// ---------------------------------------------------------------------------

class _GardenLoadingShimmer extends StatelessWidget {
  const _GardenLoadingShimmer();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      key: const Key('growth-combined-loading-shimmer'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppShimmer(width: 120, height: 14, borderRadius: 7),
          const SizedBox(height: 16),
          AppShimmer(width: double.infinity, height: 20, borderRadius: 10),
          const SizedBox(height: 12),
          AppShimmer(width: 200, height: 14, borderRadius: 7),
          const SizedBox(height: 20),
          AppShimmer(width: double.infinity, height: 14, borderRadius: 7),
          const SizedBox(height: 8),
          AppShimmer(width: 160, height: 14, borderRadius: 7),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private sub-widgets (preserved from original)
// ---------------------------------------------------------------------------

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
