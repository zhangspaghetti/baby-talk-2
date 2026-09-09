import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/router/app_route_contract.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/account/presentation/screens/account_settings_screen.dart';
import 'package:mobile/features/household/domain/models/household_role.dart';
import 'package:mobile/features/household/presentation/widgets/household_invite_card.dart';
import 'package:mobile/features/household/presentation/widgets/household_shared_context_card.dart';
import 'package:mobile/app/widgets/xiaohe_fab.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_feature_flag.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/presentation/garden_growth_notifier.dart'
    show GardenGrowthLoadStatus;
import 'package:mobile/features/practice/presentation/screens/home_screen.dart';
import 'package:mobile/features/shell/presentation/screens/discover_screen.dart';
import 'package:mobile/features/shell/presentation/screens/garden_growth_combined_screen.dart';
import 'package:mobile/features/shell/presentation/screens/me_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

class AppShellScreen extends ConsumerStatefulWidget {
  const AppShellScreen({
    super.key,
    this.onboardingSnapshot,
    this.customSceneEnabled = customSceneFeatureEnabledByDefault,
    this.initialDestination = AppShellDestination.today,
  });

  final OnboardingSnapshot? onboardingSnapshot;
  final bool customSceneEnabled;
  final AppShellDestination initialDestination;

  @override
  ConsumerState<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends ConsumerState<AppShellScreen> {
  late int _selectedIndex;
  GrowthTab _gardenInitialTab = GrowthTab.garden;

  @override
  void initState() {
    super.initState();
    _selectedIndex = switch (widget.initialDestination) {
      AppShellDestination.today => 0,
      AppShellDestination.discover => 1,
      AppShellDestination.garden => 2,
    };
  }

  void _openGardenTab(GrowthTab tab) {
    final gardenGrowthNotifier = ref.read(gardenGrowthNotifierProvider);
    if (gardenGrowthNotifier.status == GardenGrowthLoadStatus.idle) {
      unawaited(gardenGrowthNotifier.initialize());
    }
    setState(() {
      _gardenInitialTab = tab;
      _selectedIndex = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final stageMatch = _resolveStageMatch(widget.onboardingSnapshot);
    final hasPendingFertilizer = ref
        .watch(gardenFertilizerNotifierProvider)
        .view
        .hasPendingPacks;

    return Scaffold(
      key: const Key('shell-ready'),
      appBar: AppBar(
        toolbarHeight: 72,
        leadingWidth: 72,
        leading: Builder(
          builder: (context) {
            return IconButton(
              key: const Key('shell-drawer-trigger'),
              tooltip: l.shellDrawerTooltip,
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              icon: _DrawerAvatar(snapshot: widget.onboardingSnapshot),
            );
          },
        ),
        title: Text(
          _titleForIndex(l, _selectedIndex, widget.onboardingSnapshot),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        actions: [
          // §4 设置入口：仅在「我」Tab 顶栏右上角显示 46x46 齿轮图标，进入设置页。
          if (_selectedIndex == 3)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 46,
                height: 46,
                child: IconButton(
                  key: const Key('shell-settings-gear'),
                  tooltip: l.settingsTitle,
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => context.push(AppRouteNames.meSettings),
                ),
              ),
            ),
        ],
      ),
      endDrawer: _HouseholdDrawer(
        onboardingSnapshot: widget.onboardingSnapshot,
        stageMatch: stageMatch,
      ),
      // §5 规则1/规则2：花园页有自己的施肥交互，隐藏全局小禾 FAB；
      // 其余页面（今天/场景/我）固定显示。
      floatingActionButton: _selectedIndex == 2
          ? null
          : Semantics(
              container: true,
              sortKey: const OrdinalSortKey(3.0),
              child: XiaoheFab(
                key: const Key('shell-mentor-fab'),
                launcher: 'shell_fab',
                surface: _surfaceForIndex(_selectedIndex),
              ),
            ),
      body: Semantics(
        container: true,
        sortKey: const OrdinalSortKey(1.0),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: IndexedStack(
            key: ValueKey(_selectedIndex),
            index: _selectedIndex,
            children: [
              HomeScreen(
                onboardingSnapshot: widget.onboardingSnapshot,
                embeddedInShell: true,
              ),
              DiscoverScreen(customSceneEnabled: widget.customSceneEnabled),
              GardenGrowthCombinedScreen(
                initialTab: _gardenInitialTab,
                onGoHome: () => setState(() => _selectedIndex = 0),
              ),
              MeScreen(
                onboardingSnapshot: widget.onboardingSnapshot,
                onOpenGarden: () => _openGardenTab(GrowthTab.garden),
                onOpenGrowth: () => _openGardenTab(GrowthTab.growth),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Semantics(
        container: true,
        sortKey: const OrdinalSortKey(2.0),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            if (index == 2) {
              final gardenGrowthNotifier = ref.read(
                gardenGrowthNotifierProvider,
              );
              if (gardenGrowthNotifier.status == GardenGrowthLoadStatus.idle) {
                unawaited(gardenGrowthNotifier.initialize());
              }
            }
            setState(() {
              _selectedIndex = index;
            });
          },
          destinations: [
            NavigationDestination(
              key: const Key('shell-nav-home'),
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: l.shellHome,
            ),
            NavigationDestination(
              key: const Key('shell-nav-discover'),
              icon: const Icon(Icons.explore_outlined),
              selectedIcon: const Icon(Icons.explore_rounded),
              label: l.shellDiscover,
            ),
            NavigationDestination(
              key: const Key('shell-nav-garden'),
              icon: Badge(
                key: const Key('shell-nav-garden-badge'),
                isLabelVisible: hasPendingFertilizer,
                child: const Icon(Icons.local_florist_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: hasPendingFertilizer,
                child: const Icon(Icons.local_florist_rounded),
              ),
              label: l.shellGarden,
            ),
            NavigationDestination(
              key: const Key('shell-nav-me'),
              icon: const Icon(Icons.person_outlined),
              selectedIcon: const Icon(Icons.person_rounded),
              label: l.shellMe,
            ),
          ],
        ),
      ),
    );
  }

  String _titleForIndex(
    AppLocalizations l,
    int index,
    OnboardingSnapshot? snapshot,
  ) {
    switch (index) {
      case 0:
        final name = snapshot?.childDisplayName.trim();
        if (name != null && name.isNotEmpty) {
          return l.shellHomeName(name);
        }
        return l.shellHome;
      case 1:
        return l.shellDiscover;
      case 2:
        return l.shellGarden;
      case 3:
        return l.shellMe;
    }
    return 'Baby Talk 2';
  }

  String _surfaceForIndex(int index) {
    switch (index) {
      case 0:
        return 'home';
      case 1:
        return 'discover';
      case 2:
        return 'garden';
      case 3:
        return 'me';
    }
    return 'home';
  }

  StageMatch? _resolveStageMatch(OnboardingSnapshot? snapshot) {
    final stageId = snapshot?.currentStage.trim();
    if (stageId == null || stageId.isEmpty) {
      return null;
    }
    return StageMatchCatalog.maybeForStageId(stageId);
  }
}

class _DrawerAvatar extends StatelessWidget {
  const _DrawerAvatar({required this.snapshot});

  final OnboardingSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);
    final name = snapshot?.childDisplayName.trim();
    final avatarLabel = name == null || name.isEmpty
        ? l.shellAvatarHome
        : name.substring(0, 1);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colors.bgAccentSoft,
        shape: BoxShape.circle,
        border: Border.all(color: colors.outlineSoft),
      ),
      alignment: Alignment.center,
      child: Text(
        avatarLabel,
        style: theme.textTheme.titleMedium?.copyWith(color: colors.accentDark),
      ),
    );
  }
}

class _HouseholdDrawer extends ConsumerWidget {
  const _HouseholdDrawer({
    required this.onboardingSnapshot,
    required this.stageMatch,
  });

  final OnboardingSnapshot? onboardingSnapshot;
  final StageMatch? stageMatch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);
    final householdNotifier = ref.watch(householdNotifierProvider);
    final householdSnapshot = householdNotifier.snapshot;
    final childName = onboardingSnapshot?.childDisplayName.trim();
    final displayName = childName == null || childName.isEmpty
        ? l.shellBabyName
        : childName;
    final role = householdSnapshot.role;

    return Drawer(
      key: const Key('shell-end-drawer'),
      width: 310,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: ListView(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  tooltip: l.close,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close),
                ),
              ),
              Text(
                displayName,
                key: const Key('shell-drawer-child-name'),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                stageMatch?.title ?? l.shellFirstTimeDrawerStage,
                key: const Key('shell-drawer-stage-title'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DrawerRoleChip(
                    key: const Key('shell-drawer-role-badge'),
                    label: role?.label ?? l.shellSharedNotConnected,
                    backgroundColor: _drawerRoleBackground(role, colors),
                    foregroundColor: _drawerRoleForeground(role, colors),
                  ),
                  _DrawerRoleChip(
                    key: const Key('shell-drawer-shared-status-badge'),
                    label: _drawerHouseholdStatusLabel(l, householdSnapshot),
                    backgroundColor: colors.bgSunken,
                    foregroundColor: colors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                stageMatch?.summary ?? l.shellNoStageDescription,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Container(
                key: const Key('shell-drawer-local-only-note'),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.bgSunken,
                  borderRadius: BorderRadius.circular(
                    AppLayoutConstants.cardRadius,
                  ),
                ),
                child: Text(
                  l.shellLocalOnlyNote,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 20),
              AccountStatusCard(
                scopeKeyPrefix: 'shell',
                onboardingSnapshot: onboardingSnapshot,
                compact: true,
              ),
              const SizedBox(height: 20),
              HouseholdSharedContextCard(
                surfaceKeyPrefix: 'shell',
                notifier: householdNotifier,
                title: l.shellSharedProfile,
                compact: true,
                retryReason: 'shell_drawer_manual_refresh',
              ),
              const SizedBox(height: 20),
              HouseholdInviteCard(
                surfaceKeyPrefix: 'shell',
                notifier: householdNotifier,
                inviteSource: 'shell_drawer',
                compact: true,
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.englishSoft,
                  borderRadius: BorderRadius.circular(
                    AppLayoutConstants.largeRadius,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.shellFamilyProfile,
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 10),
                    _DrawerMetaRow(
                      label: l.shellAgeBucket,
                      value:
                          onboardingSnapshot?.ageBucket.label ??
                          l.shellNotFilled,
                    ),
                    const SizedBox(height: 8),
                    _DrawerMetaRow(
                      label: l.shellCurrentStage,
                      value: stageMatch?.title ?? l.shellPendingMatch,
                    ),
                    const SizedBox(height: 8),
                    _DrawerMetaRow(
                      label: l.shellSharedRole,
                      value: role?.label ?? l.shellPendingSync,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (kDebugMode)
                Text(l.shellDrawerNoteText, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerRoleChip extends StatelessWidget {
  const _DrawerRoleChip({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppLayoutConstants.pillRadius),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: foregroundColor),
      ),
    );
  }
}

Color _drawerRoleBackground(HouseholdRole? role, BabyTalkColors colors) {
  switch (role) {
    case HouseholdRole.primaryCaregiver:
      return colors.bgAccentSoft;
    case HouseholdRole.caregiver:
      return colors.englishSoft;
    case null:
      return colors.bgSunken;
  }
}

Color _drawerRoleForeground(HouseholdRole? role, BabyTalkColors colors) {
  switch (role) {
    case HouseholdRole.primaryCaregiver:
      return colors.accentDark;
    case HouseholdRole.caregiver:
      return colors.english;
    case null:
      return colors.textSecondary;
  }
}

String _drawerHouseholdStatusLabel(
  AppLocalizations l,
  dynamic householdSnapshot,
) {
  return drawerHouseholdStatusLabel(l, householdSnapshot.lastPhase.toString());
}

@visibleForTesting
String drawerHouseholdStatusLabel(AppLocalizations l, String? lastPhase) {
  final phase = lastPhase?.trim().toLowerCase() ?? '';
  if (phase.isEmpty || phase == 'idle' || phase == 'unknown') {
    return l.shellSharedStatusPending;
  }
  if (phase.contains('unavailable') ||
      phase.contains('error') ||
      phase.contains('timeout')) {
    return l.shellSharedStatusUnavailable;
  }
  if (phase.contains('disabled') ||
      phase.contains('read_only') ||
      phase.contains('read-only')) {
    return l.shellSharedStatusReadOnly;
  }
  if (phase.contains('invite') &&
      (phase.contains('created') ||
          phase.contains('waiting') ||
          phase.contains('pending'))) {
    return l.shellSharedStatusWaiting;
  }
  if (phase.contains('ready') ||
      phase.contains('accepted') ||
      phase.contains('synced')) {
    return l.shellSharedStatusReady;
  }
  return l.shellSharedStatusPending;
}

class _DrawerMetaRow extends StatelessWidget {
  const _DrawerMetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
