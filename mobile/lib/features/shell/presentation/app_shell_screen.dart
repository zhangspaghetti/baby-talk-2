import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/account/presentation/screens/account_entry_screen.dart';
import 'package:mobile/features/household/domain/models/household_role.dart';
import 'package:mobile/features/household/presentation/household_view_model.dart';
import 'package:mobile/features/household/presentation/widgets/household_invite_card.dart';
import 'package:mobile/features/household/presentation/widgets/household_shared_context_card.dart';
import 'package:mobile/features/mentor/presentation/widgets/mentor_panel_sheet.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/presentation/garden_growth_view_model.dart';
import 'package:mobile/features/practice/presentation/screens/home_screen.dart';
import 'package:mobile/features/shell/presentation/screens/discover_screen.dart';
import 'package:mobile/features/shell/presentation/screens/garden_screen.dart';
import 'package:mobile/features/shell/presentation/screens/growth_screen.dart';
import 'package:provider/provider.dart';
import 'package:mobile/l10n/app_localizations.dart';

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key, this.onboardingSnapshot});

  final OnboardingSnapshot? onboardingSnapshot;

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final stageMatch = _resolveStageMatch(widget.onboardingSnapshot);

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
          _titleForIndex(_selectedIndex, widget.onboardingSnapshot),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      endDrawer: _HouseholdDrawer(
        snapshot: widget.onboardingSnapshot,
        stageMatch: stageMatch,
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('shell-mentor-fab'),
        tooltip: l.mentorName,
        onPressed: () => openMentorPanelSheet(
          context,
          launcher: 'shell_fab',
          surface: _surfaceForIndex(_selectedIndex),
        ),
        child: const Icon(Icons.auto_awesome),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(
            onboardingSnapshot: widget.onboardingSnapshot,
            embeddedInShell: true,
          ),
          const DiscoverScreen(),
          const GardenScreen(),
          const GrowthScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          if (index == 2 || index == 3) {
            final gardenGrowthViewModel = context
                .read<GardenGrowthViewModel?>();
            if (gardenGrowthViewModel != null &&
                gardenGrowthViewModel.status == GardenGrowthLoadStatus.idle) {
              unawaited(gardenGrowthViewModel.initialize());
            }
          }
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search_rounded),
            label: '发现',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_florist_outlined),
            selectedIcon: Icon(Icons.local_florist_rounded),
            label: '花园',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: '成长',
          ),
        ],
      ),
    );
  }

  String _titleForIndex(int index, OnboardingSnapshot? snapshot) {
    switch (index) {
      case 0:
        final name = snapshot?.childDisplayName.trim();
        if (name != null && name.isNotEmpty) {
          return '$name 的首页';
        }
        return '首页';
      case 1:
        return '发现';
      case 2:
        return '花园';
      case 3:
        return '成长';
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
        return 'growth';
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
    final colors = context.appColors;
    final theme = Theme.of(context);
    final name = snapshot?.childDisplayName.trim();
    final avatarLabel = name == null || name.isEmpty
        ? '家'
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
        style: theme.textTheme.titleMedium?.copyWith(
          color: colors.accentDark,
        ),
      ),
    );
  }
}

class _HouseholdDrawer extends StatelessWidget {
  const _HouseholdDrawer({required this.snapshot, required this.stageMatch});

  final OnboardingSnapshot? snapshot;
  final StageMatch? stageMatch;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final householdViewModel = context.watch<HouseholdViewModel?>();
    final householdSnapshot = householdViewModel?.snapshot;
    final childName = snapshot?.childDisplayName.trim();
    final displayName = childName == null || childName.isEmpty
        ? '这位宝宝'
        : childName;
    final role = householdSnapshot?.role;

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
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close),
                ),
              ),
              Text(
                displayName,
                key: const Key('shell-drawer-child-name'),
                style: theme.textTheme.displayMedium?.copyWith(
                  fontSize: 28,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                stageMatch?.title ?? '第一次进入家庭档案',
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
                    label: role?.label ?? '共享未接通',
                    backgroundColor: _drawerRoleBackground(role, colors),
                    foregroundColor: _drawerRoleForeground(role, colors),
                  ),
                  _DrawerRoleChip(
                    label: householdSnapshot?.lastPhase ?? 'idle',
                    backgroundColor: colors.bgSunken,
                    foregroundColor: colors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                stageMatch?.summary ?? '当前还没有完整阶段说明，后续完成 onboarding 后会显示这里。',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Container(
                key: const Key('shell-drawer-local-only-note'),
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.bgSunken,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '同意前，这里的昵称、月龄档和阶段仅保存在这台设备上；共享照护只会显示脱敏后的角色、phase 和上下文摘要。',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 20),
              AccountStatusCard(
                scopeKeyPrefix: 'shell',
                onboardingSnapshot: snapshot,
                compact: true,
              ),
              const SizedBox(height: 20),
              HouseholdSharedContextCard(
                surfaceKeyPrefix: 'shell',
                viewModel: householdViewModel,
                title: '共享家庭档案',
                compact: true,
                retryReason: 'shell_drawer_manual_refresh',
              ),
              const SizedBox(height: 20),
              HouseholdInviteCard(
                surfaceKeyPrefix: 'shell',
                viewModel: householdViewModel,
                inviteSource: 'shell_drawer',
                compact: true,
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.englishSoft,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('家庭档案', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 10),
                    _DrawerMetaRow(
                      label: '月龄档',
                      value: snapshot?.ageBucket.label ?? '未填写',
                    ),
                    const SizedBox(height: 8),
                    _DrawerMetaRow(
                      label: '当前阶段',
                      value: stageMatch?.title ?? '待匹配',
                    ),
                    const SizedBox(height: 8),
                    _DrawerMetaRow(label: '共享角色', value: role?.label ?? '待同步'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Drawer 现在会直接显示 invite CTA、角色 badge、最近是谁完成了什么，以及共享下一步是否安全可进。',
                style: theme.textTheme.bodySmall,
              ),
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
        borderRadius: BorderRadius.circular(999),
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
