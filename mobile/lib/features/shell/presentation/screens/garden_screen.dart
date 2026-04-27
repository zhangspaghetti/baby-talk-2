import 'package:flutter/material.dart';
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
                    GardenPatchCard(patch: patch),
                    const SizedBox(height: 16),
                  ],
                ],
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
              ],
            ),
          ),
        ),
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
