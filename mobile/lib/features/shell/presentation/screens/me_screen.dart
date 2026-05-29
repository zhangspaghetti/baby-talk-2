import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/account/presentation/screens/account_entry_screen.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// The "Me" tab screen — user profile, garden/growth summary, and function grid.
class MeScreen extends ConsumerWidget {
  const MeScreen({
    super.key,
    this.onboardingSnapshot,
    this.onOpenGarden,
    this.onOpenGrowth,
  });

  final OnboardingSnapshot? onboardingSnapshot;

  /// 回调：点击花园状态入口块 → 切到底部「花园」Tab（由 Shell 注入）。
  final VoidCallback? onOpenGarden;

  /// 回调：点击成长数据入口块 → 切到「花园」Tab 的成长分段（由 Shell 注入）。
  final VoidCallback? onOpenGrowth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final gardenNotifier = ref.watch(gardenGrowthNotifierProvider);
    final gardenSnapshot = gardenNotifier.snapshot;
    final account = ref.watch(accountNotifierProvider);

    final childName = onboardingSnapshot?.childDisplayName.trim();
    final displayName =
        (childName != null && childName.isNotEmpty) ? childName : l.shellBabyName;
    final avatarLabel =
        (childName != null && childName.isNotEmpty)
            ? childName.substring(0, 1)
            : '?';

    // §6 账号入口状态：未登录 → 轻提示；已登录 → 昵称(脱敏手机号)；同步中 → 指示器。
    final bool accountSyncing = account.isSignedIn && account.hasPendingSync;
    final String accountStateLabel = account.isSignedIn
        ? account.maskedPhoneNumber
        : l.meAccountSignedOutHint;

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // ── User info section ──
            _UserInfoSection(
              avatarLabel: avatarLabel,
              displayName: displayName,
              ageBucketLabel: onboardingSnapshot?.ageBucket.label,
              accountStateLabel: accountStateLabel,
              isSyncing: accountSyncing,
              onTap: () => openAccountEntryScreen(context),
            ),
            const SizedBox(height: 20),

            // ── Garden status block ──
            _GardenStatusBlock(
              spacesCount: gardenSnapshot.spaces.length,
              latestImpact: gardenSnapshot.latestImpact,
              onTap: onOpenGarden,
            ),
            const SizedBox(height: 12),

            // ── Growth data block ──
            _GrowthDataBlock(
              knownEvents: gardenSnapshot.knownEvents,
              sceneCount: gardenSnapshot.spaces.length,
              streakDays: gardenSnapshot.currentStreakDays,
              onTap: onOpenGrowth,
            ),
            const SizedBox(height: 20),

            // ── Function grid ──
            _FunctionGrid(onboardingSnapshot: onboardingSnapshot),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// User info section
// ---------------------------------------------------------------------------

class _UserInfoSection extends StatelessWidget {
  const _UserInfoSection({
    required this.avatarLabel,
    required this.displayName,
    this.ageBucketLabel,
    required this.accountStateLabel,
    this.isSyncing = false,
    this.onTap,
  });

  final String avatarLabel;
  final String displayName;
  final String? ageBucketLabel;
  final String accountStateLabel;
  final bool isSyncing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Material(
      color: colors.bgSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: const Key('me-user-info'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: colors.warmShadowSm,
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colors.bgAccentSoft,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.outlineSoft),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      avatarLabel,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colors.accentDark,
                      ),
                    ),
                  ),
                  if (isSyncing)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        key: const Key('me-account-syncing'),
                        width: 18,
                        height: 18,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: colors.bgSurface,
                          shape: BoxShape.circle,
                        ),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.accent,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    if (ageBucketLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        ageBucketLabel!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      accountStateLabel,
                      key: const Key('me-account-state'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Garden status block
// ---------------------------------------------------------------------------

class _GardenStatusBlock extends StatelessWidget {
  const _GardenStatusBlock({
    required this.spacesCount,
    required this.latestImpact,
    this.onTap,
  });

  final int spacesCount;
  final dynamic latestImpact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);

    final String statusText;
    if (spacesCount == 0) {
      statusText = l.meGardenEmpty;
    } else {
      statusText = l.meGardenSummary(spacesCount);
    }

    return Material(
      color: colors.successSoft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: const Key('me-garden-status'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.local_florist_rounded,
                color: colors.success,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  statusText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Growth data block
// ---------------------------------------------------------------------------

class _GrowthDataBlock extends StatelessWidget {
  const _GrowthDataBlock({
    required this.knownEvents,
    required this.sceneCount,
    required this.streakDays,
    this.onTap,
  });

  final int knownEvents;
  final int sceneCount;
  final int streakDays;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Material(
      color: colors.bgSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: const Key('me-growth-data'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.outlineSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.meGrowthTitle,
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                  if (onTap != null)
                    Icon(Icons.chevron_right, color: colors.textMuted),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatItem(
                    label: l.meStatPracticeTotal,
                    value: l.meGrowthPracticeTotalValue(knownEvents, sceneCount),
                  ),
                  const SizedBox(width: 16),
                  _StatItem(
                    label: l.meStatStreak,
                    value: l.meGrowthStreakValue(streakDays),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.accentDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Function grid — 2-column layout
// ---------------------------------------------------------------------------

class _FunctionGrid extends StatelessWidget {
  const _FunctionGrid({required this.onboardingSnapshot});

  final OnboardingSnapshot? onboardingSnapshot;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final entries = [
      _GridEntry(
        icon: Icons.notifications_outlined,
        label: l.meReminders,
        route: '/me/settings',
      ),
      _GridEntry(
        icon: Icons.child_care_outlined,
        label: l.meBabyProfile,
        route: '/me/settings',
      ),
      _GridEntry(
        icon: Icons.play_circle_outline,
        label: l.mePlaybackPrefs,
        route: '/me/settings',
      ),
      _GridEntry(
        icon: Icons.help_outline,
        label: l.meHelp,
        route: '/me/settings',
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.2,
      children: entries
          .map((entry) => _FunctionGridTile(entry: entry))
          .toList(),
    );
  }
}

class _GridEntry {
  const _GridEntry({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;
}

class _FunctionGridTile extends StatelessWidget {
  const _FunctionGridTile({required this.entry});

  final _GridEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Material(
      color: colors.bgSurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(entry.route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(entry.icon, size: 22, color: colors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
