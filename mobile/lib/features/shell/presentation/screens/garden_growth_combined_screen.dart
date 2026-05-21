import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/widgets/app_banner.dart';
import 'package:mobile/app/widgets/app_empty_state.dart';
import 'package:mobile/app/widgets/app_haptics.dart';
import 'package:mobile/app/widgets/app_shimmer.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/household/presentation/household_notifier.dart';
import 'package:mobile/features/household/presentation/widgets/household_shared_context_card.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart'
    show PracticeActivitySnapshot;
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/practice_continuity_snapshot.dart'
    show PracticeContinuitySnapshot;
import 'package:mobile/features/practice/presentation/garden_growth_notifier.dart';
import 'package:mobile/features/practice/presentation/practice_continuity_notifier.dart';
import 'package:mobile/features/share/presentation/share_notifier.dart';
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

    // Provider: other Notifiers (still Provider-based)
    final continuityNotifier = context.watch<PracticeContinuityNotifier?>();
    final householdNotifier = context.watch<HouseholdNotifier?>();
    final shareNotifier = context.watch<ShareNotifier?>();
    final continuitySnapshot = continuityNotifier?.snapshot;
    final continuityActivity = continuityNotifier?.activitySnapshot;
    final practiceArgs = continuityNotifier?.recommendedArgs;

    // Shared context
    final sharedContext = householdNotifier?.snapshot.sharedContext;
    final sharedNextStepArgs = resolveHouseholdSharedNextStepArgs(
      sharedContext,
    );
    final localGardenAt =
        gardenSnapshot.latestImpact?.occurredAt ??
        gardenSnapshot.primarySpace?.lastPracticedAt ??
        continuitySnapshot?.cadence.lastEventTime;
    final isSharedOverlayNewer =
        continuityNotifier != null &&
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
                if (continuityNotifier != null)
                  continuityNotifier.refresh(
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
                const SizedBox(height: AppLayoutConstants.spacingLg),

                // ── Shared error banner ──
                if (gardenNotifier.hasError) ...[
                  AppBanner(
                    key: const Key('growth-combined-garden-warning-banner'),
                    message: gardenNotifier.message ?? l.gardenRefreshFailed,
                    backgroundColor: colors.warningSoft,
                    foregroundColor: colors.warning,
                  ),
                  const SizedBox(height: AppLayoutConstants.spacingMd),
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
                    continuityNotifier: continuityNotifier,
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
                const SizedBox(height: AppLayoutConstants.spacingMd),
                HouseholdSharedContextCard(
                  surfaceKeyPrefix: 'growth-combined',
                  notifier: householdNotifier,
                  title: l.gardenSharedAttributionTitle,
                  retryReason: 'growth_combined_household_manual_refresh',
                ),
                if (shareNotifier != null) ...[
                  const SizedBox(height: AppLayoutConstants.spacingMd),
                  ShareCalloutCard(
                    surfaceKeyPrefix: 'growth-combined',
                    notifier: shareNotifier,
                    sectionLabel: l.gardenShareFamily,
                    emptyMessage: l.growthShareWaitStable,
                    onShare: () => shareNotifier.shareCurrent(),
                  ),
                ],
                if (shouldShowSharedOverlay) ...[
                  const SizedBox(height: AppLayoutConstants.spacingMd),
                  HouseholdSharedPracticeOverlayCard(
                    surfaceKeyPrefix: 'growth-combined-shared-overlay',
                    sharedContext: sharedContext,
                  ),
                ],
                if (shouldShowSharedOverlayDisabled) ...[
                  const SizedBox(height: AppLayoutConstants.spacingMd),
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
    required PracticeContinuityNotifier? continuityNotifier,
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
          continuityNotifier: continuityNotifier,
          continuitySnapshot: continuitySnapshot,
          continuityActivity: continuityActivity,
        ),
        const SizedBox(height: AppLayoutConstants.spacingMd),

        // ── Continue card ──
        GardenContinueCard(
          practiceArgs: practiceArgs,
          continuityNotifier: continuityNotifier,
          continuitySnapshot: continuitySnapshot,
          continuityActivity: continuityActivity,
        ),
        const SizedBox(height: AppLayoutConstants.spacingMd),

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
            const SizedBox(height: AppLayoutConstants.spacingMd),
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
        Semantics(
          container: true,
          label: l.growthLatestImpactSemantics(title),
          child: Container(
            key: const Key('growth-combined-latest-impact'),
            padding: const EdgeInsets.all(AppLayoutConstants.spacingXl),
            decoration: BoxDecoration(
              color: colors.bgSurface,
              borderRadius: BorderRadius.circular(
                AppLayoutConstants.largeRadius,
              ),
              border: Border.all(color: colors.outlineSoft),
              boxShadow: colors.warmShadowSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.growthDiaryLabel, style: theme.textTheme.labelMedium),
                const SizedBox(height: AppLayoutConstants.spacingSm),
                Text(title, style: theme.textTheme.titleLarge),
                const SizedBox(height: AppLayoutConstants.spacingXs),
                Text(body, style: theme.textTheme.bodyMedium),
                if (snapshot.hasIssues &&
                    snapshot.projectionWarning != null) ...[
                  const SizedBox(height: AppLayoutConstants.spacingSm),
                  Text(
                    l.gardenProjectionWarningNote,
                    key: const Key('growth-combined-projection-warning'),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),

        if (!snapshot.isEmpty) ...[
          // ── Diary section ──
          const SizedBox(height: AppLayoutConstants.spacingXl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.growthAutoDiary, style: theme.textTheme.titleMedium),
              if (snapshot.diaryEntries.length > 3)
                _GrowthPreviewActionButton(
                  key: const Key('growth-combined-diary-view-all'),
                  onPressed: () {
                    AppHaptics.lightTap();
                    // Navigation is deferred until a dedicated diary route is approved.
                  },
                  label: l.viewAll,
                ),
            ],
          ),
          const SizedBox(height: AppLayoutConstants.spacingSm),
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
                    padding: const EdgeInsets.only(
                      bottom: AppLayoutConstants.spacingSm,
                    ),
                    child: _DiaryCard(entry: entry),
                  ),
                ),

          // ── Milestones section ──
          const SizedBox(height: AppLayoutConstants.spacingXl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.growthMilestone, style: theme.textTheme.titleMedium),
              if (snapshot.milestones.length > 6)
                _GrowthPreviewActionButton(
                  key: const Key('growth-combined-milestones-view-all'),
                  onPressed: () {
                    AppHaptics.lightTap();
                    // Navigation is deferred until a dedicated milestones route is approved.
                  },
                  label: l.viewAll,
                ),
            ],
          ),
          const SizedBox(height: AppLayoutConstants.spacingSm),
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
                    padding: const EdgeInsets.only(
                      bottom: AppLayoutConstants.spacingSm,
                    ),
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
        borderRadius: BorderRadius.circular(AppLayoutConstants.cardRadius),
      ),
      padding: const EdgeInsets.all(AppLayoutConstants.spacingXxs * 2),
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
    return Semantics(
      button: true,
      label: label,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(
            minHeight: AppLayoutConstants.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(
            vertical: AppLayoutConstants.spacingSm,
          ),
          decoration: BoxDecoration(
            color: isSelected ? colors.bgSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppLayoutConstants.spacingSm),
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
      padding: const EdgeInsets.all(AppLayoutConstants.spacingLg),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(AppLayoutConstants.largeRadius),
        border: Border.all(color: colors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppShimmer(width: 120, height: 14, borderRadius: 7),
          const SizedBox(height: AppLayoutConstants.spacingMd),
          AppShimmer(width: double.infinity, height: 20, borderRadius: 10),
          const SizedBox(height: AppLayoutConstants.spacingSm),
          AppShimmer(width: 200, height: 14, borderRadius: 7),
          const SizedBox(height: AppLayoutConstants.spacingLg),
          AppShimmer(width: double.infinity, height: 14, borderRadius: 7),
          const SizedBox(height: AppLayoutConstants.spacingXs),
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
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);
    final accentColor = entry.kind == GrowthDiaryEntryKind.practice
        ? colors.english
        : colors.accentDark;
    return Semantics(
      container: true,
      label: l.growthDiaryEntrySemantics(entry.title),
      child: Container(
        key: Key('growth-combined-diary-${entry.entryId}'),
        padding: const EdgeInsets.all(AppLayoutConstants.spacingLg),
        decoration: BoxDecoration(
          color: colors.bgSurface,
          borderRadius: BorderRadius.circular(AppLayoutConstants.mediumRadius),
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
                borderRadius: BorderRadius.circular(
                  AppLayoutConstants.pillRadius,
                ),
              ),
            ),
            const SizedBox(width: AppLayoutConstants.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppLayoutConstants.spacingXs),
                  Text(entry.body, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({required this.milestone});

  final GrowthMilestoneSnapshot milestone;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final achieved = milestone.isAchieved;
    return Semantics(
      container: true,
      label: l.growthMilestoneSemantics(milestone.title),
      child: Container(
        key: Key('growth-combined-milestone-${milestone.id}'),
        padding: const EdgeInsets.all(AppLayoutConstants.spacingLg),
        decoration: BoxDecoration(
          color: achieved ? colors.successSoft : colors.bgSunken,
          borderRadius: BorderRadius.circular(AppLayoutConstants.mediumRadius),
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
            const SizedBox(width: AppLayoutConstants.spacingSm),
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
      padding: const EdgeInsets.all(AppLayoutConstants.spacingLg),
      decoration: BoxDecoration(
        color: colors.bgSunken,
        borderRadius: BorderRadius.circular(AppLayoutConstants.mediumRadius),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _GrowthPreviewActionButton extends StatelessWidget {
  const _GrowthPreviewActionButton({
    required super.key,
    required this.onPressed,
    required this.label,
  });

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(
          AppLayoutConstants.minTouchTarget,
          AppLayoutConstants.minTouchTarget,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppLayoutConstants.spacingSm,
        ),
      ),
      child: Text(label),
    );
  }
}
