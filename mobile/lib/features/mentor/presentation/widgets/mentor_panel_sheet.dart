import 'package:flutter/material.dart';
import 'package:mobile/app/widgets/app_banner.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/account/presentation/account_notifier.dart';
import 'package:mobile/features/mentor/data/services/mentor_api_service.dart'
    show mentorPromptMaxLength;
import 'package:mobile/features/mentor/presentation/mentor_notifier.dart';
import 'package:mobile/features/mentor/presentation/widgets/mentor_suggestion_tab.dart';
import 'package:mobile/features/onboarding/presentation/widgets/mentor_bubble.dart';
import 'package:provider/provider.dart';
import 'package:mobile/l10n/app_localizations.dart';

Future<void> openMentorPanelSheet(
  BuildContext context, {
  required String launcher,
  String surface = 'home',
}) async {
  final notifier = Provider.of<MentorNotifier?>(context, listen: false);
  if (notifier == null) {
    final l = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l.mentorNotReady)));
    return;
  }

  final shouldOpen = await notifier.beginPanelSession(
    launcher: launcher,
    surface: surface,
  );
  if (!shouldOpen) {
    return;
  }
  if (!context.mounted) {
    notifier.endPanelSession();
    return;
  }

  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider<MentorNotifier>.value(
        value: notifier,
        child: const MentorPanelSheet(),
      ),
    );
  } finally {
    notifier.endPanelSession();
  }
}

class MentorPanelSheet extends StatelessWidget {
  const MentorPanelSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final notifier = context.watch<MentorNotifier>();
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.78;

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          key: const Key('mentor-panel-sheet'),
          constraints: BoxConstraints(
            maxHeight: maxHeight,
            maxWidth: AppLayoutConstants.maxContentWidth,
          ),
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
                child: _SegmentedTabBar(selectedTab: notifier.selectedTab),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: notifier.selectedTab == MentorPanelTab.suggestions
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
    final notifier = context.read<MentorNotifier>();
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
              label: l.mentorSuggestionTabSemantics,
              button: true,
              child: _SegmentedButton(
                buttonKey: const Key('mentor-tab-suggestions-button'),
                label: l.mentorSuggestionTab,
                selected: selectedTab == MentorPanelTab.suggestions,
                onPressed: () => notifier.selectTab(MentorPanelTab.suggestions),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              label: l.mentorChatTabSemantics,
              button: true,
              child: _SegmentedButton(
                buttonKey: const Key('mentor-tab-chat-button'),
                label: l.mentorChatTab,
                selected: selectedTab == MentorPanelTab.chat,
                onPressed: () => notifier.selectTab(MentorPanelTab.chat),
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
    final accountNotifier = context.watch<AccountNotifier>();
    final notifier = context.watch<MentorNotifier>();
    final availability = notifier.chatAvailability;

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
          AppBanner(
            key: const Key('mentor-chat-banner'),
            message: notifier.bannerMessage ?? availability.detail,
            backgroundColor: colors.warningSoft,
            foregroundColor: colors.warning,
          ),
          if (notifier.audioStatusMessage != null) ...[
            const SizedBox(height: 12),
            AppBanner(
              key: const Key('mentor-chat-audio-banner'),
              message: notifier.audioStatusMessage!,
              backgroundColor: colors.warningSoft,
              foregroundColor: colors.warning,
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
                  'phase · ${notifier.chatResponsePhase ?? availability.phase}',
                ),
              ),
              Chip(
                key: const Key('mentor-chat-status-chip'),
                label: Text(notifier.statusChipLabel),
              ),
              if (accountNotifier.snapshot.lastSyncPhase.trim().isNotEmpty)
                Chip(
                  key: const Key('mentor-chat-account-phase-chip'),
                  label: Text(
                    'account · ${accountNotifier.snapshot.lastSyncPhase}',
                  ),
                ),
              if (notifier.chatRateLimit != null)
                Chip(
                  key: const Key('mentor-chat-rate-chip'),
                  label: Text(
                    'limit · ${notifier.chatRateLimit!.remaining}/${notifier.chatRateLimit!.limit}',
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
                Text(
                  l.mentorChatPlaceholder,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('mentor-chat-input'),
                  minLines: 3,
                  maxLines: 5,
                  maxLength: mentorPromptMaxLength,
                  enabled: !notifier.isSubmittingChat,
                  onChanged: notifier.updateChatDraft,
                  decoration: const InputDecoration(
                    hintText: '例如：宝宝一直哭，我现在该怎么开口安抚？',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton(
                      key: const Key('mentor-chat-submit-button'),
                      onPressed: notifier.canSubmitChat
                          ? notifier.submitChat
                          : null,
                      child: Text(
                        notifier.isSubmittingChat
                            ? l.mentorSending
                            : l.mentorSendRequest,
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      key: const Key('mentor-chat-retry-button'),
                      onPressed: availability.retryable
                          ? notifier.retryChatAvailability
                          : null,
                      child: Text(l.mentorRecheck),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (notifier.isSubmittingChat) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(key: Key('mentor-chat-loading-bar')),
          ],
          if (notifier.chatResponseText != null) ...[
            const SizedBox(height: 16),
            _ChatResponseCard(notifier: notifier),
          ],
          const SizedBox(height: 16),
          FilledButton.tonal(
            key: const Key('mentor-chat-back-to-suggestions'),
            onPressed: () => notifier.selectTab(MentorPanelTab.suggestions),
            child: Text(l.mentorBackToSuggestion),
          ),
        ],
      ),
    );
  }
}

class _ChatResponseCard extends StatelessWidget {
  const _ChatResponseCard({required this.notifier});

  final MentorNotifier notifier;

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
            notifier.chatResponseText!,
            key: const Key('mentor-chat-response-text'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (notifier.chatResponseCode != null)
                Chip(label: Text('code · ${notifier.chatResponseCode}')),
              if (notifier.chatAuthenticated)
                const Chip(label: Text('auth · session'))
              else
                Chip(label: Text(l.mentorNotLoggedIn)),
              if (notifier.chatFallbackUsed)
                Chip(label: Text(l.mentorLocalResponse)),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('mentor-chat-read-aloud'),
            onPressed: notifier.isSpeaking ? null : notifier.replayChatResponse,
            icon: const Icon(Icons.volume_up_outlined),
            label: Text(
              notifier.isSpeaking ? l.mentorReading : l.mentorReadResponse,
            ),
          ),
        ],
      ),
    );
  }
}
