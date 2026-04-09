import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/account/presentation/screens/account_entry_screen.dart';
import 'package:mobile/features/mentor/presentation/widgets/mentor_panel_sheet.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/presentation/garden_growth_view_model.dart';
import 'package:mobile/features/practice/presentation/screens/home_screen.dart';
import 'package:mobile/features/shell/presentation/screens/garden_screen.dart';
import 'package:mobile/features/shell/presentation/screens/growth_screen.dart';
import 'package:provider/provider.dart';

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
              tooltip: '打开家庭抽屉',
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
        tooltip: '小禾老师',
        onPressed: () => openMentorPanelSheet(context, launcher: 'shell_fab'),
        child: const Icon(Icons.auto_awesome),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(
            onboardingSnapshot: widget.onboardingSnapshot,
            embeddedInShell: true,
          ),
          const _ShellPlaceholderTab(
            pageKey: Key('shell-tab-discover'),
            eyebrow: '发现',
            title: '按活动和空间继续找下一句。',
            body: '这一页会在后续切片接入阶段筛选、活动卡片和搜索。当前先保留稳定入口。',
            icon: Icons.explore_outlined,
          ),
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
        destinations: const [
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
    final theme = Theme.of(context);
    final name = snapshot?.childDisplayName.trim();
    final avatarLabel = name == null || name.isEmpty
        ? '家'
        : name.substring(0, 1);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.bgAccentSoft,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.outlineSoft),
      ),
      alignment: Alignment.center,
      child: Text(
        avatarLabel,
        style: theme.textTheme.titleMedium?.copyWith(
          color: AppTheme.accentDark,
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
    final theme = Theme.of(context);
    final childName = snapshot?.childDisplayName.trim();
    final displayName = childName == null || childName.isEmpty
        ? '这位宝宝'
        : childName;

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
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                stageMatch?.title ?? '第一次进入家庭档案',
                key: const Key('shell-drawer-stage-title'),
                style: theme.textTheme.titleMedium,
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
                  color: AppTheme.bgSunken,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '同意前，这里的昵称、月龄档和阶段仅保存在这台设备上，不进入练习事件诊断。',
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.englishSoft,
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
                    _DrawerMetaRow(label: '起步方式', value: '先从洗澡时间这句开始'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Drawer 和 4-tab 壳已稳定下来，后续切片会继续往这里接花园、成长和 Mentor。',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerMetaRow extends StatelessWidget {
  const _DrawerMetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
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
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ShellPlaceholderTab extends StatelessWidget {
  const _ShellPlaceholderTab({
    required this.pageKey,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.icon,
  });

  final Key pageKey;
  final String eyebrow;
  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: ListView(
            key: pageKey,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.outlineSoft),
                  boxShadow: AppTheme.warmShadowSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: AppTheme.english),
                    const SizedBox(height: 16),
                    Text(eyebrow, style: theme.textTheme.labelMedium),
                    const SizedBox(height: 10),
                    Text(title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Text(body, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
