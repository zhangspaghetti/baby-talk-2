import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/presentation/account_view_model.dart';
import 'package:mobile/features/mentor/presentation/mentor_view_model.dart';
import 'package:mobile/features/mentor/presentation/widgets/mentor_suggestion_tab.dart';
import 'package:mobile/features/onboarding/presentation/widgets/mentor_bubble.dart';
import 'package:provider/provider.dart';

Future<void> openMentorPanelSheet(
  BuildContext context, {
  required String launcher,
}) async {
  final viewModel = Provider.of<MentorViewModel?>(context, listen: false);
  if (viewModel == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Mentor 面板尚未装配完成。')));
    return;
  }

  final shouldOpen = await viewModel.beginPanelSession(launcher: launcher);
  if (!shouldOpen) {
    return;
  }
  if (!context.mounted) {
    viewModel.endPanelSession();
    return;
  }

  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider<MentorViewModel>.value(
        value: viewModel,
        child: const MentorPanelSheet(),
      ),
    );
  } finally {
    viewModel.endPanelSession();
  }
}

class MentorPanelSheet extends StatelessWidget {
  const MentorPanelSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MentorViewModel>();
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.76;

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          key: const Key('mentor-panel-sheet'),
          constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 430),
          decoration: const BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: AppTheme.warmShadowMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.outlineSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '小禾老师',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '先给建议，再决定是否需要聊天。离线时也不会让你白点。',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('mentor-panel-close'),
                      tooltip: '关闭 Mentor 面板',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SegmentedTabBar(selectedTab: viewModel.selectedTab),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: viewModel.selectedTab == MentorPanelTab.suggestions
                      ? const MentorSuggestionTab(
                          key: ValueKey('mentor-suggestion-body'),
                        )
                      : const _MentorChatTab(key: ValueKey('mentor-chat-body')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentedTabBar extends StatelessWidget {
  const _SegmentedTabBar({required this.selectedTab});

  final MentorPanelTab selectedTab;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<MentorViewModel>();
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.bgSunken,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentedButton(
              buttonKey: const Key('mentor-tab-suggestions-button'),
              label: '建议',
              selected: selectedTab == MentorPanelTab.suggestions,
              onPressed: () => viewModel.selectTab(MentorPanelTab.suggestions),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _SegmentedButton(
              buttonKey: const Key('mentor-tab-chat-button'),
              label: '聊天',
              selected: selectedTab == MentorPanelTab.chat,
              onPressed: () => viewModel.selectTab(MentorPanelTab.chat),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedButton extends StatelessWidget {
  const _SegmentedButton({
    required this.buttonKey,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.bgSurface : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: buttonKey,
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MentorChatTab extends StatelessWidget {
  const _MentorChatTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accountViewModel = context.watch<AccountViewModel>();
    final viewModel = context.watch<MentorViewModel>();
    final availability = viewModel.chatAvailability;

    return ListView(
      key: const Key('mentor-chat-tab'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      children: [
        MentorBubble(
          caption: availability.title,
          message: availability.detail,
          trailing: Text(
            '这一版不会发出任何聊天网络请求；你仍然可以直接使用建议 tab 里的文本援助。',
            key: const Key('mentor-chat-text-first-note'),
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 16),
        _ChatBanner(
          key: const Key('mentor-chat-banner'),
          title: availability.title,
          detail: availability.detail,
          code: availability.code.wireValue,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              key: const Key('mentor-chat-phase-chip'),
              label: Text('phase · ${availability.phase}'),
            ),
            Chip(
              key: const Key('mentor-chat-status-chip'),
              label: Text(viewModel.statusChipLabel),
            ),
            if (accountViewModel.snapshot.lastSyncPhase.trim().isNotEmpty)
              Chip(
                key: const Key('mentor-chat-account-phase-chip'),
                label: Text(
                  'account · ${accountViewModel.snapshot.lastSyncPhase}',
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            OutlinedButton(
              key: const Key('mentor-chat-retry-button'),
              onPressed: availability.retryable
                  ? viewModel.retryChatAvailability
                  : null,
              child: const Text('重新检查'),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              key: const Key('mentor-chat-back-to-suggestions'),
              onPressed: () => viewModel.selectTab(MentorPanelTab.suggestions),
              child: const Text('回到建议'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChatBanner extends StatelessWidget {
  const _ChatBanner({
    super.key,
    required this.title,
    required this.detail,
    required this.code,
  });

  final String title;
  final String detail;
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Chip(label: Text('code · $code')),
        ],
      ),
    );
  }
}
