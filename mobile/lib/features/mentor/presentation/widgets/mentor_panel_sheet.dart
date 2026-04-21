import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/account/presentation/account_view_model.dart';
import 'package:mobile/features/mentor/data/services/mentor_api_service.dart'
    show mentorPromptMaxLength;
import 'package:mobile/features/mentor/presentation/mentor_view_model.dart';
import 'package:mobile/features/mentor/presentation/widgets/mentor_suggestion_tab.dart';
import 'package:mobile/features/onboarding/presentation/widgets/mentor_bubble.dart';
import 'package:provider/provider.dart';
import 'package:mobile/l10n/app_localizations.dart';

Future<void> openMentorPanelSheet(
  BuildContext context, {
  required String launcher,
  String surface = 'home',
}) async {
  final viewModel = Provider.of<MentorViewModel?>(context, listen: false);
  if (viewModel == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Mentor 面板尚未装配完成。')));
    return;
  }

  final shouldOpen = await viewModel.beginPanelSession(
    launcher: launcher,
    surface: surface,
  );
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
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final viewModel = context.watch<MentorViewModel>();
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.78;

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          key: const Key('mentor-panel-sheet'),
          constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 430),
          decoration: BoxDecoration(
            color: colors.bgSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: colors.warmShadowMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineSoft,
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
                            l.mentorName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l.mentorOfflineNote,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('mentor-panel-close'),
                      tooltip: l.mentorClosePanel,
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
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final viewModel = context.read<MentorViewModel>();
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.bgSunken,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: '建议标签页',
              button: true,
              child: _SegmentedButton(
              buttonKey: const Key('mentor-tab-suggestions-button'),
              label: l.mentorSuggestionTab,
              selected: selectedTab == MentorPanelTab.suggestions,
              onPressed: () => viewModel.selectTab(MentorPanelTab.suggestions),
            ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              label: '聊天标签页',
              button: true,
              child: _SegmentedButton(
              buttonKey: const Key('mentor-tab-chat-button'),
              label: l.mentorChatTab,
              selected: selectedTab == MentorPanelTab.chat,
              onPressed: () => viewModel.selectTab(MentorPanelTab.chat),
            ),
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
    final colors = context.appColors;
    return Material(
      color: selected ? colors.bgSurface : Colors.transparent,
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
                color: selected ? colors.textPrimary : colors.textSecondary,
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
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);
    final accountViewModel = context.watch<AccountViewModel>();
    final viewModel = context.watch<MentorViewModel>();
    final availability = viewModel.chatAvailability;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        key: const Key('mentor-chat-tab'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MentorBubble(
          caption: availability.title,
          message: availability.detail,
          trailing: Text(
            l.mentorChatNote,
            key: const Key('mentor-chat-text-first-note'),
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 16),
        _ChatBanner(
          key: const Key('mentor-chat-banner'),
          title: availability.title,
          detail: viewModel.bannerMessage ?? availability.detail,
          code: viewModel.bannerCode ?? availability.code.wireValue,
        ),
        if (viewModel.audioStatusMessage != null) ...[
          const SizedBox(height: 12),
          _ChatBanner(
            key: const Key('mentor-chat-audio-banner'),
            title: l.mentorReadStatus,
            detail: viewModel.audioStatusMessage!,
            code: viewModel.audioStatusCode ?? 'tts',
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              key: const Key('mentor-chat-phase-chip'),
              label: Text(
                'phase · ${viewModel.chatResponsePhase ?? availability.phase}',
              ),
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
            if (viewModel.chatRateLimit != null)
              Chip(
                key: const Key('mentor-chat-rate-chip'),
                label: Text(
                  'limit · ${viewModel.chatRateLimit!.remaining}/${viewModel.chatRateLimit!.limit}',
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.bgSunken,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.mentorChatPlaceholder, style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              TextField(
                key: const Key('mentor-chat-input'),
                minLines: 3,
                maxLines: 5,
                maxLength: mentorPromptMaxLength,
                enabled: !viewModel.isSubmittingChat,
                onChanged: viewModel.updateChatDraft,
                decoration: const InputDecoration(
                  hintText: '例如：宝宝一直哭，我现在该怎么开口安抚？',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton(
                    key: const Key('mentor-chat-submit-button'),
                    onPressed: viewModel.canSubmitChat
                        ? viewModel.submitChat
                        : null,
                    child: Text(
                      viewModel.isSubmittingChat
                          ? l.mentorSending
                          : l.mentorSendRequest,
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    key: const Key('mentor-chat-retry-button'),
                    onPressed: availability.retryable
                        ? viewModel.retryChatAvailability
                        : null,
                    child: Text(l.mentorRecheck),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (viewModel.isSubmittingChat) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(key: Key('mentor-chat-loading-bar')),
        ],
        if (viewModel.chatResponseText != null) ...[
          const SizedBox(height: 16),
          _ChatResponseCard(viewModel: viewModel),
        ],
        const SizedBox(height: 16),
        FilledButton.tonal(
          key: const Key('mentor-chat-back-to-suggestions'),
          onPressed: () => viewModel.selectTab(MentorPanelTab.suggestions),
          child: Text(l.mentorBackToSuggestion),
        ),
      ],
    ),
  );
  }
}

class _ChatResponseCard extends StatelessWidget {
  const _ChatResponseCard({required this.viewModel});

  final MentorViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Container(
      key: const Key('mentor-chat-response-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineSoft),
        boxShadow: colors.warmShadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.mentorControlledResponse, style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          Text(
            viewModel.chatResponseText!,
            key: const Key('mentor-chat-response-text'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (viewModel.chatResponseCode != null)
                Chip(label: Text('code · ${viewModel.chatResponseCode}')),
              if (viewModel.chatAuthenticated)
                const Chip(label: Text('auth · session'))
              else
                Chip(label: Text(l.mentorNotLoggedIn)),
              if (viewModel.chatFallbackUsed)
                Chip(label: Text(l.mentorLocalResponse)),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('mentor-chat-read-aloud'),
            onPressed: viewModel.isSpeaking ? null : viewModel.replayChatResponse,
            icon: const Icon(Icons.volume_up_outlined),
            label: Text(viewModel.isSpeaking ? l.mentorReading : l.mentorReadResponse),
          ),
        ],
      ),
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
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.warningSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.warning,
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
