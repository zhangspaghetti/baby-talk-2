import 'package:baby_talk_mobile/models/app_models.dart';
import 'package:baby_talk_mobile/screens/scene_coaching_screen.dart';
import 'package:baby_talk_mobile/state/app_state.dart';
import 'package:baby_talk_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BabyTalkAppState>(
      builder: (context, appState, _) {
        final header = _headerCopyFor(appState.selectedTabIndex, appState);

        return Scaffold(
          endDrawer: const _AccountDrawer(),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: const _MentorFab(),
          body: SafeArea(
            child: Column(
              children: [
                if (appState.isOffline) const _OfflineBanner(),
                _ShellHeader(header: header),
                Expanded(
                  child: IndexedStack(
                    index: appState.selectedTabIndex,
                    children: const [
                      _HomeTab(),
                      _DiscoverTab(),
                      _GardenTab(),
                      _GrowthTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: appState.selectedTabIndex,
            onDestinationSelected: appState.selectTab,
            destinations: const [
              NavigationDestination(
                key: Key('home-tab'),
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: '首页',
              ),
              NavigationDestination(
                key: Key('discover-tab'),
                icon: Icon(Icons.travel_explore_outlined),
                selectedIcon: Icon(Icons.travel_explore),
                label: '发现',
              ),
              NavigationDestination(
                key: Key('garden-tab'),
                icon: Icon(Icons.local_florist_outlined),
                selectedIcon: Icon(Icons.local_florist),
                label: '花园',
              ),
              NavigationDestination(
                key: Key('growth-tab'),
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights),
                label: '成长',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<BabyTalkAppState>();
    final themeTone = Theme.of(context).extension<AppThemeTone>()!;
    final featuredActivity = appState.featuredActivity;
    final featuredSpace = appState.featuredSpace;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        _PaperCard(
          color: themeTone.paperSunken,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppPalette.warningSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.wb_sunny_outlined,
                  color: AppPalette.accentDark,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '宝宝状态条',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appState.coachHeadline,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SectionTitle(
          title: '花园速览',
          actionLabel: '+${appState.growthPoints} 生长点可用',
        ),
        const SizedBox(height: 12),
        _PaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final space in appState.gardenPreviewSpaces)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: space.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(space.icon, size: 18, color: space.color),
                          const SizedBox(width: 8),
                          Text(
                            '${space.name} ${(space.progress * 100).round()}%',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '最近浇灌最勤的是 ${appState.gardenPreviewSpaces.first.name}，继续保持，用户会感受到“练习真的会留下痕迹”。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SectionTitle(title: '现在试试'),
        const SizedBox(height: 12),
        _PaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                featuredActivity.leadPhrase.english,
                key: const Key('featured-phrase'),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: themeTone.englishTone,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                featuredActivity.leadPhrase.chinese,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TagPill(
                    icon: featuredActivity.icon,
                    label: featuredActivity.name,
                  ),
                  _TagPill(icon: featuredSpace.icon, label: featuredSpace.name),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('home-start-practice'),
                onPressed: () =>
                    _openSceneCoaching(context, featuredActivity.id),
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('开始练习'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SectionTitle(title: '今日活动'),
        const SizedBox(height: 12),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: appState.recommendedActivities.length.clamp(0, 4),
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final activity = appState.recommendedActivities[index];
              return SizedBox(
                width: 220,
                child: InkWell(
                  onTap: () => _openSceneCoaching(context, activity.id),
                  borderRadius: BorderRadius.circular(24),
                  child: _PaperCard(
                    color: themeTone.paperSunken,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.12),
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          child: Icon(activity.icon),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          activity.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          activity.shortLabel,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const Spacer(),
                        _ProgressLine(progress: activity.progress),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        _SectionTitle(title: '本周速览'),
        const SizedBox(height: 12),
        _PaperCard(
          child: Row(
            children: [
              Expanded(
                child: _WeeklyStat(
                  icon: Icons.record_voice_over_outlined,
                  label: '说了 ${appState.weeklyPhraseCount} 句',
                  detail: '比上周多 6 句',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WeeklyStat(
                  icon: Icons.local_fire_department_outlined,
                  label: '连续 ${appState.streakDays} 天',
                  detail: '今天别断',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DiscoverTab extends StatelessWidget {
  const _DiscoverTab();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<BabyTalkAppState>();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).extension<AppThemeTone>()!.paperSunken,
                borderRadius: BorderRadius.circular(18),
              ),
              child: TabBar(
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                tabs: const [
                  Tab(text: '分类浏览'),
                  Tab(text: '为你推荐'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  children: [
                    _SectionTitle(title: '空间'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final space in appState.spaces)
                          SizedBox(
                            width: (MediaQuery.of(context).size.width - 44) / 2,
                            child: _PaperCard(
                              color: space.color.withValues(alpha: 0.1),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(space.icon, color: space.color),
                                  const SizedBox(height: 10),
                                  Text(
                                    space.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${space.completedActivities}/${space.activities.length} 活动已点亮',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SectionTitle(title: '按空间展开'),
                    const SizedBox(height: 12),
                    for (final space in appState.spaces) ...[
                      _PaperCard(
                        padding: EdgeInsets.zero,
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: space.color.withValues(
                                alpha: 0.12,
                              ),
                              foregroundColor: space.color,
                              child: Icon(space.icon),
                            ),
                            title: Text(space.name),
                            subtitle: Text(space.subtitle),
                            children: [
                              for (final activity in space.activities)
                                ListTile(
                                  onTap: () =>
                                      _openSceneCoaching(context, activity.id),
                                  leading: Icon(activity.icon),
                                  title: Text(activity.name),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: _ProgressLine(
                                      progress: activity.progress,
                                    ),
                                  ),
                                  trailing: Text(activity.growthStage.emoji),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
                ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  itemCount: appState.recommendedActivities.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final activity = appState.recommendedActivities[index];
                    return _PaperCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.secondary.withValues(alpha: 0.14),
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.secondary,
                                child: Icon(activity.icon),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activity.name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    Text(
                                      activity.leadPhrase.english,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Text('${(activity.progress * 10).round()}/10'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _ProgressLine(progress: activity.progress),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GardenTab extends StatelessWidget {
  const _GardenTab();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<BabyTalkAppState>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        _PaperCard(
          color: Theme.of(context).extension<AppThemeTone>()!.paperSunken,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '花园系统',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '练习赚生长点，浇水换成长。这才是能让用户看见反馈的回路。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${appState.growthPoints}',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  Text('可用生长点', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionTitle(title: '花圃地图'),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: 420,
            color: Theme.of(context).extension<AppThemeTone>()!.paperSunken,
            child: InteractiveViewer(
              constrained: false,
              minScale: 0.8,
              maxScale: 1.8,
              child: SizedBox(
                width: 560,
                height: 520,
                child: Stack(
                  children: [
                    for (final space in appState.spaces)
                      Positioned(
                        left: space.mapOffset.dx,
                        top: space.mapOffset.dy,
                        child: Container(
                          width: 150,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: space.color.withValues(alpha: 0.35),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(space.icon, color: space.color),
                              const SizedBox(height: 8),
                              Text(
                                space.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                space.activities
                                    .map((item) => item.growthStage.emoji)
                                    .join(' '),
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SectionTitle(title: '花圃详情', actionLabel: appState.spaces.first.name),
        const SizedBox(height: 12),
        _PaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final activity in appState.spaces.first.activities) ...[
                Row(
                  children: [
                    Icon(
                      activity.icon,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${activity.growthStage.emoji} ${activity.growthStage.label}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text('${(activity.progress * 100).round()}%'),
                  ],
                ),
                const SizedBox(height: 8),
                _ProgressLine(progress: activity.progress),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                onPressed: () async {
                  final success = await appState.waterSelectedPatch(
                    appState.spaces.first.id,
                  );
                  if (!context.mounted) {
                    return;
                  }
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        success ? '🌱 已浇水，先把循环跑顺，动画下一层接。' : '生长点不够了，先去练几句。',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.water_drop_outlined),
                label: const Text('浇水 -5 生长点'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GrowthTab extends StatelessWidget {
  const _GrowthTab();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<BabyTalkAppState>();

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _PaperCard(
              color: Theme.of(context).extension<AppThemeTone>()!.paperSunken,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('阶段进度', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  _ProgressLine(progress: appState.roadmapProgress),
                  const SizedBox(height: 10),
                  Text(
                    '${appState.phaseLabel} · ${appState.difficulty.label}。${appState.coachHeadline}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).extension<AppThemeTone>()!.paperSunken,
                borderRadius: BorderRadius.circular(18),
              ),
              child: TabBar(
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                tabs: const [
                  Tab(text: '日记'),
                  Tab(text: '场景进展'),
                  Tab(text: '里程碑'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              children: [
                ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  itemCount: appState.diaryEntries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final entry = appState.diaryEntries[index];
                    final stripeColor = entry.type == DiaryEntryType.autoNote
                        ? Theme.of(context).colorScheme.secondary
                        : Theme.of(context).colorScheme.primary;
                    return _PaperCard(
                      padding: EdgeInsets.zero,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border(
                            left: BorderSide(color: stripeColor, width: 5),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.title,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              entry.subtitle,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.timeLabel,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  itemCount: appState.spaces.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final space = appState.spaces[index];
                    return _PaperCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(space.icon, color: space.color),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  space.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              Text('${(space.progress * 100).round()}%'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _ProgressLine(progress: space.progress),
                          const SizedBox(height: 10),
                          Text(
                            '${space.completedActivities}/${space.activities.length} 活动已到盛开态',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  itemCount: appState.milestones.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final milestone = appState.milestones[index];
                    return _PaperCard(
                      color: AppPalette.successSoft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppPalette.success,
                            foregroundColor: Colors.white,
                            child: Icon(Icons.check_rounded),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  milestone.title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  milestone.detail,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  milestone.timeLabel,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MentorFab extends StatelessWidget {
  const _MentorFab();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<BabyTalkAppState>();

    return FloatingActionButton.extended(
      key: const Key('mentor-fab'),
      onPressed: () {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) {
            return DefaultTabController(
              length: 2,
              child: SizedBox(
                height: 540,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.14),
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            child: const Icon(Icons.spa_outlined),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '小禾老师',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text(
                                  '先给你一句马上能用的话，再陪你把今天这个场景说顺。',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).extension<AppThemeTone>()!.paperSunken,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: TabBar(
                          dividerColor: Colors.transparent,
                          indicator: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          tabs: const [
                            Tab(text: '建议'),
                            Tab(text: '聊天'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TabBarView(
                        children: [
                          ListView(
                            key: const Key('mentor-suggestions'),
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: const [
                                  Chip(label: Text('洗澡怎么开口')),
                                  Chip(label: Text('宝宝哭闹怎么办')),
                                  Chip(label: Text('今天只学一句')),
                                ],
                              ),
                              const SizedBox(height: 16),
                              for (final suggestion
                                  in appState.coachSuggestions) ...[
                                _PaperCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        suggestion.title,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        suggestion.detail,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                            child: const _MentorChatTab(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      icon: const Icon(Icons.spa_outlined),
      label: const Text('小禾'),
    );
  }
}

class _ShellHeader extends StatelessWidget {
  const _ShellHeader({required this.header});

  final _HeaderCopy header;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          Builder(
            builder: (context) {
              return IconButton(
                onPressed: () => Scaffold.of(context).openEndDrawer(),
                icon: const Icon(Icons.menu_rounded),
                tooltip: '打开菜单',
              );
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  header.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  header.subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: '通知',
          ),
        ],
      ),
    );
  }
}

class _MentorChatTab extends StatefulWidget {
  const _MentorChatTab();

  @override
  State<_MentorChatTab> createState() => _MentorChatTabState();
}

class _MentorChatTabState extends State<_MentorChatTab> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendPrompt(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      return;
    }

    _controller.clear();
    await context.read<BabyTalkAppState>().askCoach(trimmed);
    if (!mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<BabyTalkAppState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (appState.isOffline) ...[
          _PaperCard(
            color: Theme.of(context).extension<AppThemeTone>()!.paperSunken,
            child: Text(
              '当前是本地建议模式，恢复联网后会切回远端教练。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final suggestion in appState.coachSuggestions.take(3))
              ActionChip(
                label: Text(suggestion.title),
                onPressed: appState.isCoachReplying
                    ? null
                    : () => _sendPrompt(suggestion.title),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            key: const Key('mentor-chat-thread'),
            controller: _scrollController,
            itemCount:
                appState.coachChatMessages.length +
                (appState.isCoachReplying ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index >= appState.coachChatMessages.length) {
                return _PaperCard(
                  color: Theme.of(
                    context,
                  ).extension<AppThemeTone>()!.paperSunken,
                  child: Text(
                    '小禾老师正在整理一句马上能用的话…',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }

              final message = appState.coachChatMessages[index];
              return _MentorChatBubble(message: message);
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('mentor-chat-input'),
                controller: _controller,
                onSubmitted: _sendPrompt,
                enabled: !appState.isCoachReplying,
                decoration: const InputDecoration(
                  hintText: '把你现在卡住的时刻告诉小禾老师',
                  prefixIcon: Icon(Icons.chat_bubble_outline),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              key: const Key('mentor-chat-send'),
              onPressed: appState.isCoachReplying
                  ? null
                  : () => _sendPrompt(_controller.text),
              child: const Icon(Icons.send_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.mic_none_outlined),
          label: const Text('语音输入待接入阿里云 ASR'),
        ),
      ],
    );
  }
}

class _MentorChatBubble extends StatelessWidget {
  const _MentorChatBubble({required this.message});

  final CoachChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == CoachChatRole.caregiver;
    final tone = Theme.of(context).extension<AppThemeTone>()!;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: _PaperCard(
          color: isUser
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.14)
              : tone.paperSunken,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.body, style: Theme.of(context).textTheme.bodyLarge),
              if (message.suggestedPhraseEnglish != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.suggestedPhraseEnglish!,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (message.suggestedPhraseChinese != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          message.suggestedPhraseChinese!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (message.followUpPrompt != null) ...[
                const SizedBox(height: 10),
                Text(
                  message.followUpPrompt!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountDrawer extends StatelessWidget {
  const _AccountDrawer();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<BabyTalkAppState>();

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _PaperCard(
              color: Theme.of(context).extension<AppThemeTone>()!.paperSunken,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    child: Text(appState.caregiverName.substring(0, 1)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appState.caregiverName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${appState.childName} · ${appState.ageLabel}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const ListTile(
              leading: Icon(Icons.settings_outlined),
              title: Text('设置'),
            ),
            const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('账号管理'),
            ),
            const ListTile(
              leading: Icon(Icons.support_agent_outlined),
              title: Text('客服反馈'),
            ),
            const ListTile(
              leading: Icon(Icons.privacy_tip_outlined),
              title: Text('隐私政策'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppPalette.warningSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '没有网络，部分功能暂时休息。恢复联网后自动同步。',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _PaperCard extends StatelessWidget {
  const _PaperCard({
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.actionLabel});

  final String title;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (actionLabel != null)
          Text(actionLabel!, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).extension<AppThemeTone>()!.paperSunken,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _WeeklyStat extends StatelessWidget {
  const _WeeklyStat({
    required this.icon,
    required this.label,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(detail, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(value: progress, minHeight: 8),
    );
  }
}

class _HeaderCopy {
  const _HeaderCopy({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

_HeaderCopy _headerCopyFor(int index, BabyTalkAppState appState) {
  switch (index) {
    case 0:
      return _HeaderCopy(
        title: '${appState.caregiverName}，早上好',
        subtitle: '${appState.phaseLabel} · ${appState.ageLabel}',
      );
    case 1:
      return const _HeaderCopy(title: '发现', subtitle: '按空间和推荐找灵感');
    case 2:
      return const _HeaderCopy(title: '我的花园', subtitle: '把练习变成看得见的生长');
    case 3:
      return const _HeaderCopy(title: '成长', subtitle: '日记、进展和里程碑');
    default:
      return const _HeaderCopy(title: 'Baby Talk', subtitle: '育儿英语伴侣');
  }
}

void _openSceneCoaching(BuildContext context, String activityId) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SceneCoachingScreen(activityId: activityId),
    ),
  );
}
