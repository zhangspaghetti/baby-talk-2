import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
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
    final theme = Theme.of(context);
    final viewModel = context.watch<MentorViewModel>();
    final availability = viewModel.chatAvailability;
    final messages = viewModel.messages;

    return Column(
      key: const Key('mentor-chat-tab'),
      children: [
        // 聊天气泡列表
        Expanded(
          child: messages.isEmpty
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
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
                    if (viewModel.bannerMessage != null) ...[
                      const SizedBox(height: 12),
                      _ChatBanner(
                        key: const Key('mentor-chat-banner'),
                        title: availability.title,
                        detail: viewModel.bannerMessage!,
                        code: viewModel.bannerCode ?? availability.code.wireValue,
                      ),
                    ],
                  ],
                )
              : _ChatBubbleList(
                  key: const Key('mentor-chat-bubble-list'),
                  messages: messages,
                  isLoading: viewModel.isSubmittingChat,
                ),
        ),
        // 底部输入区域
        _ChatInputBar(
          key: const Key('mentor-chat-input-bar'),
          viewModel: viewModel,
        ),
      ],
    );
  }
}

/// 聊天气泡列表，自动滚动到底部。
class _ChatBubbleList extends StatefulWidget {
  const _ChatBubbleList({
    super.key,
    required this.messages,
    this.isLoading = false,
  });

  final List<ChatBubbleData> messages;
  final bool isLoading;

  @override
  State<_ChatBubbleList> createState() => _ChatBubbleListState();
}

class _ChatBubbleListState extends State<_ChatBubbleList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(_ChatBubbleList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length > oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: widget.messages.length + (widget.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == widget.messages.length) {
          // 加载指示器
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final bubble = widget.messages[index];
        return _ChatBubble(
          key: ValueKey('chat-bubble-$index'),
          data: bubble,
        );
      },
    );
  }
}

/// 单个聊天气泡。用户消息右对齐暖橙底，AI 回复左对齐白底带知识来源高亮。
class _ChatBubble extends StatelessWidget {
  const _ChatBubble({super.key, required this.data});

  final ChatBubbleData data;

  static final RegExp _sourcePattern = RegExp(r'《([^》]+)》');

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final isUser = data.role == ChatBubbleRole.user;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) const SizedBox(width: 4),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? colors.bgAccentSoft : colors.bgSurface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 6),
                  bottomRight: Radius.circular(isUser ? 6 : 20),
                ),
                border: isUser
                    ? null
                    : Border.all(color: colors.outlineSoft, width: 0.5),
                boxShadow: colors.warmShadowSm,
              ),
              child: isUser
                  ? Text(
                      data.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.textPrimary,
                      ),
                    )
                  : _buildSourceHighlightedText(context, data.text),
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }

  /// 对 AI 回复中的 《书名》 格式做知识来源高亮。
  Widget _buildSourceHighlightedText(BuildContext context, String text) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colors.textPrimary,
    );
    final sourceStyle = baseStyle?.copyWith(
      color: colors.english,
      fontWeight: FontWeight.w700,
    );

    final matches = _sourcePattern.allMatches(text);
    if (matches.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final spans = <TextSpan>[];
    var lastEnd = 0;
    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: sourceStyle,
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(style: baseStyle, children: spans),
    );
  }
}

/// 底部聊天输入栏，包含文本框和发送按钮。
class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({super.key, required this.viewModel});

  final MentorViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        border: Border(top: BorderSide(color: colors.outlineSoft, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const Key('mentor-chat-input'),
              minLines: 1,
              maxLines: 4,
              maxLength: mentorPromptMaxLength,
              enabled: !viewModel.isSubmittingChat,
              onChanged: viewModel.updateChatDraft,
              decoration: InputDecoration(
                hintText: '例如：宝宝一直哭，我现在该怎么开口安抚？',
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: colors.outlineSoft),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: colors.outlineSoft),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: colors.accent),
                ),
                filled: true,
                fillColor: colors.bgSunken,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton.filled(
              key: const Key('mentor-chat-submit-button'),
              onPressed:
                  viewModel.canSubmitChat ? viewModel.submitChat : null,
              icon: viewModel.isSubmittingChat
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: colors.accent,
                disabledBackgroundColor: colors.bgSunken,
              ),
            ),
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
