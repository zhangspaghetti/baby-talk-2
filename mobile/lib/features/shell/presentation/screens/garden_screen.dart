import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/widgets/app_banner.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/household/presentation/widgets/household_shared_context_card.dart';
import 'package:mobile/features/share/presentation/widgets/share_callout_card.dart';
import 'package:mobile/features/shell/presentation/widgets/garden_continue_card.dart';
import 'package:mobile/features/shell/presentation/widgets/garden_hero_card.dart';
import 'package:mobile/features/shell/presentation/widgets/garden_patch_card.dart';
import 'package:mobile/l10n/app_localizations.dart';

@Deprecated('Use GardenGrowthCombinedScreen instead')
class GardenScreen extends ConsumerWidget {
  const GardenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final notifier = ref.watch(gardenGrowthNotifierProvider);
    final continuityNotifier = ref.watch(practiceContinuityNotifierProvider);
    final householdNotifier = ref.watch(householdNotifierProvider);
    final shareNotifier = ref.watch(shareNotifierProvider);
    final snapshot = notifier.snapshot;
    final continuitySnapshot = continuityNotifier.snapshot;
    final continuityActivity = continuityNotifier.activitySnapshot;
    final practiceArgs = continuityNotifier.recommendedArgs;
    final sharedContext = householdNotifier.snapshot.sharedContext;
    final sharedNextStepArgs = resolveHouseholdSharedNextStepArgs(
      sharedContext,
    );
    final localGardenAt =
        snapshot.latestImpact?.occurredAt ??
        snapshot.primarySpace?.lastPracticedAt ??
        continuitySnapshot?.cadence.lastEventTime;
    final isSharedOverlayNewer =
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
                notifier.refresh(),
                continuityNotifier.refresh(reason: 'garden_pull_to_refresh'),
              ]);
            },
            child: ListView(
              key: const Key('shell-tab-garden'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppLayoutConstants.shellTabPadding,
              children: [
                GardenHeroCard(
                  snapshot: snapshot,
                  status: notifier.status,
                  continuityNotifier: continuityNotifier,
                  continuitySnapshot: continuitySnapshot,
                  continuityActivity: continuityActivity,
                ),
                const SizedBox(height: 16),
                GardenContinueCard(
                  practiceArgs: practiceArgs,
                  continuityNotifier: continuityNotifier,
                  continuitySnapshot: continuitySnapshot,
                  continuityActivity: continuityActivity,
                ),
                if (notifier.hasError) ...[
                  const SizedBox(height: 16),
                  AppBanner(
                    key: const Key('garden-warning-banner'),
                    message: notifier.message ?? l.gardenRefreshFailed,
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
                  notifier: householdNotifier,
                  title: l.gardenSharedAttributionTitle,
                  retryReason: 'garden_household_manual_refresh',
                ),
                const SizedBox(height: 16),
                ShareCalloutCard(
                  surfaceKeyPrefix: 'garden',
                  notifier: shareNotifier,
                  sectionLabel: l.gardenShareFamily,
                  emptyMessage: '等最近成长和继续建议整理稳定后，再生成一条脱敏分享链接。',
                  onShare: (draft) => shareNotifier.shareDraft(draft),
                ),
                const SizedBox(height: 16),
                if (shouldShowSharedOverlay) ...[
                  HouseholdSharedPracticeOverlayCard(
                    surfaceKeyPrefix: 'garden-shared-overlay',
                    sharedContext: sharedContext,
                  ),
                  const SizedBox(height: 16),
                ],
                if (shouldShowSharedOverlayDisabled) ...[
                  AppBanner(
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
