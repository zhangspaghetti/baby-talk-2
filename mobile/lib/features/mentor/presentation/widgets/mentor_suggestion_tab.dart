import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/mentor/domain/models/local_mentor_suggestion.dart';
import 'package:mobile/features/mentor/domain/services/local_mentor_suggestion_service.dart';
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
        if (viewModel.sharedContextStatus != null) ...[
          if (viewModel.bannerMessage != null) const SizedBox(height: 12),
          _MentorSharedContextBanner(
            key: const Key('mentor-shared-context-banner'),
            status: viewModel.sharedContextStatus!,
          ),
        ],
        if (viewModel.audioStatusMessage != null) ...[
          if (viewModel.bannerMessage != null ||
              viewModel.sharedContextStatus != null)
            const SizedBox(height: 12),
          _MentorAlertBanner(
            key: const Key('mentor-audio-banner'),
            message: viewModel.audioStatusMessage!,
            foregroundColor: AppTheme.warning,
            backgroundColor: AppTheme.warningSoft,
          ),
        ],
        if (viewModel.bannerMessage != null ||
            viewModel.audioStatusMessage != null ||
            viewModel.sharedContextStatus != null)
          const SizedBox(height: 16),
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
                suggestion: suggestion,
                onReadAloud: () => viewModel.replaySuggestion(suggestion),
                isSpeaking: viewModel.isSpeaking,
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

class _MentorSharedContextBanner extends StatelessWidget {
  const _MentorSharedContextBanner({super.key, required this.status});

  final MentorSharedContextStatus status;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = status.adopted ? AppTheme.info : AppTheme.warning;
    final backgroundColor = status.adopted
        ? AppTheme.infoSoft
        : AppTheme.warningSoft;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            status.headline,
            key: const Key('mentor-shared-context-headline'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            status.detail,
            key: const Key('mentor-shared-context-detail'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Chip(
            key: const Key('mentor-shared-context-chip'),
            label: Text('shared · ${status.code}'),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.onReadAloud,
    required this.isSpeaking,
  });

  final LocalMentorSuggestion suggestion;
  final VoidCallback onReadAloud;
  final bool isSpeaking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: Key('mentor-suggestion-card-${suggestion.suggestionId}'),
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
          Text(suggestion.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          if (suggestion.phraseEnglish != null &&
              suggestion.phraseEnglish!.trim().isNotEmpty) ...[
            Text(
              suggestion.phraseEnglish!,
              style: theme.textTheme.displayMedium?.copyWith(
                fontSize: 24,
                color: AppTheme.english,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(suggestion.body, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                key: Key('mentor-suggestion-audio-${suggestion.suggestionId}'),
                onPressed: isSpeaking ? null : onReadAloud,
                icon: const Icon(Icons.volume_up_outlined),
                label: Text(isSpeaking ? '朗读中…' : '朗读'),
              ),
              if (suggestion.reasonCode != null &&
                  suggestion.reasonCode!.trim().isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('reason · ${suggestion.reasonCode}')),
                    ],
                  ),
                ),
              ],
            ],
          ),
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
