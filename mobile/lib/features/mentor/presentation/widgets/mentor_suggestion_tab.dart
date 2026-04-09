import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/mentor/presentation/mentor_view_model.dart';
import 'package:mobile/features/onboarding/presentation/widgets/mentor_bubble.dart';
import 'package:provider/provider.dart';

class MentorSuggestionTab extends StatelessWidget {
  const MentorSuggestionTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = context.watch<MentorViewModel>();

    return ListView(
      key: const Key('mentor-suggestion-tab'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      children: [
        const MentorBubble(
          message: '先给你几条现在就能说出口的建议。离线时也可以直接用，不需要等聊天连通。',
          caption: '小禾老师',
        ),
        const SizedBox(height: 16),
        if (viewModel.bannerMessage != null)
          _MentorAlertBanner(
            key: const Key('mentor-panel-banner'),
            message: viewModel.bannerMessage!,
            foregroundColor: _foregroundColorForStatus(viewModel.panelStatus),
            backgroundColor: _backgroundColorForStatus(viewModel.panelStatus),
          ),
        if (viewModel.bannerMessage != null) const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              key: const Key('mentor-selected-tab-chip'),
              label: Text(viewModel.selectedTabChipLabel),
            ),
            Chip(
              key: const Key('mentor-status-chip'),
              label: Text(viewModel.statusChipLabel),
            ),
            Chip(
              key: const Key('mentor-chat-chip'),
              label: Text(viewModel.chatAvailability.chipLabel),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (viewModel.isLoading)
          Container(
            key: const Key('mentor-suggestion-loading'),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.outlineSoft),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '正在整理本地建议…',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (viewModel.suggestions.isEmpty)
          Container(
            key: const Key('mentor-suggestion-empty-state'),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.outlineSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('还没整理出建议', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  '别担心，你重新打开或点一次刷新就好；面板本身不会失效。',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  key: const Key('mentor-suggestion-retry'),
                  onPressed: viewModel.reloadSuggestions,
                  child: const Text('刷新建议'),
                ),
              ],
            ),
          )
        else
          ...viewModel.suggestions.map(
            (suggestion) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SuggestionCard(
                suggestionId: suggestion.suggestionId,
                title: suggestion.title,
                body: suggestion.body,
                phraseEnglish: suggestion.phraseEnglish,
                reasonCode: suggestion.reasonCode,
              ),
            ),
          ),
        if (!viewModel.isLoading && viewModel.suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: const Key('mentor-suggestion-retry'),
              onPressed: viewModel.reloadSuggestions,
              child: const Text('刷新建议'),
            ),
          ),
        ],
      ],
    );
  }

  static Color _backgroundColorForStatus(MentorPanelStatus status) {
    switch (status) {
      case MentorPanelStatus.loading:
        return AppTheme.infoSoft;
      case MentorPanelStatus.ready:
        return AppTheme.infoSoft;
      case MentorPanelStatus.fallback:
        return AppTheme.warningSoft;
      case MentorPanelStatus.error:
        return AppTheme.errorSoft;
      case MentorPanelStatus.idle:
        return AppTheme.bgSunken;
    }
  }

  static Color _foregroundColorForStatus(MentorPanelStatus status) {
    switch (status) {
      case MentorPanelStatus.loading:
        return AppTheme.info;
      case MentorPanelStatus.ready:
        return AppTheme.info;
      case MentorPanelStatus.fallback:
        return AppTheme.warning;
      case MentorPanelStatus.error:
        return AppTheme.error;
      case MentorPanelStatus.idle:
        return AppTheme.textSecondary;
    }
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestionId,
    required this.title,
    required this.body,
    this.phraseEnglish,
    this.reasonCode,
  });

  final String suggestionId;
  final String title;
  final String body;
  final String? phraseEnglish;
  final String? reasonCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: Key('mentor-suggestion-card-$suggestionId'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.outlineSoft),
        boxShadow: AppTheme.warmShadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          if (phraseEnglish != null && phraseEnglish!.trim().isNotEmpty) ...[
            Text(
              phraseEnglish!,
              style: theme.textTheme.displayMedium?.copyWith(
                fontSize: 24,
                color: AppTheme.english,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(body, style: theme.textTheme.bodyMedium),
          if (reasonCode != null && reasonCode!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Chip(label: Text('reason · $reasonCode')),
          ],
        ],
      ),
    );
  }
}

class _MentorAlertBanner extends StatelessWidget {
  const _MentorAlertBanner({
    super.key,
    required this.message,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final String message;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
