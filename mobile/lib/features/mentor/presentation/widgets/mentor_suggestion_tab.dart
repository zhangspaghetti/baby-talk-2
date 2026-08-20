import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/mentor/domain/models/local_mentor_suggestion.dart';
import 'package:mobile/features/mentor/domain/services/local_mentor_suggestion_service.dart';
import 'package:mobile/features/mentor/presentation/mentor_notifier.dart';
import 'package:mobile/app/widgets/app_mentor_bubble.dart';
import 'package:mobile/l10n/app_localizations.dart';

class MentorSuggestionTab extends ConsumerWidget {
  const MentorSuggestionTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);
    final notifier = ref.watch(mentorNotifierProvider);

    return ListView(
      key: const Key('mentor-suggestion-tab'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      children: [
        AppMentorBubble(
          message: l.mentorSuggestionIntro,
          caption: l.mentorName,
        ),
        const SizedBox(height: 16),
        if (notifier.bannerMessage != null)
          _MentorAlertBanner(
            key: const Key('mentor-panel-banner'),
            message: notifier.bannerMessage!,
            foregroundColor: _foregroundColorForStatus(
              notifier.panelStatus,
              colors,
            ),
            backgroundColor: _backgroundColorForStatus(
              notifier.panelStatus,
              colors,
            ),
          ),
        if (notifier.sharedContextStatus != null) ...[
          if (notifier.bannerMessage != null) const SizedBox(height: 12),
          _MentorSharedContextBanner(
            key: const Key('mentor-shared-context-banner'),
            status: notifier.sharedContextStatus!,
          ),
        ],
        if (notifier.audioStatusMessage != null) ...[
          if (notifier.bannerMessage != null ||
              notifier.sharedContextStatus != null)
            const SizedBox(height: 12),
          _MentorAlertBanner(
            key: const Key('mentor-audio-banner'),
            message: notifier.audioStatusMessage!,
            foregroundColor: colors.warning,
            backgroundColor: colors.warningSoft,
          ),
        ],
        if (notifier.bannerMessage != null ||
            notifier.audioStatusMessage != null ||
            notifier.sharedContextStatus != null)
          const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              key: const Key('mentor-selected-tab-chip'),
              label: Text(notifier.selectedTabChipLabel),
            ),
            Chip(
              key: const Key('mentor-status-chip'),
              label: Text(notifier.statusChipLabel),
            ),
            Chip(
              key: const Key('mentor-chat-chip'),
              label: Text(notifier.chatAvailability.chipLabel),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (notifier.isLoading)
          Container(
            key: const Key('mentor-suggestion-loading'),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.bgSurface,
              borderRadius: BorderRadius.circular(
                AppLayoutConstants.largeRadius,
              ),
              border: Border.all(color: colors.outlineSoft),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.mentorSuggestionLoading,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (notifier.suggestions.isEmpty)
          Container(
            key: const Key('mentor-suggestion-empty-state'),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.bgSurface,
              borderRadius: BorderRadius.circular(
                AppLayoutConstants.largeRadius,
              ),
              border: Border.all(color: colors.outlineSoft),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.mentorSuggestionEmpty,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  l.mentorSuggestionEmptyNote,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  key: const Key('mentor-suggestion-retry'),
                  onPressed: notifier.reloadSuggestions,
                  child: Text(l.mentorSuggestionRefresh),
                ),
              ],
            ),
          )
        else
          ...notifier.suggestions.map(
            (suggestion) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SuggestionCard(
                suggestion: suggestion,
                onReadAloud: () => notifier.replaySuggestion(suggestion),
                isSpeaking: notifier.isSpeaking,
              ),
            ),
          ),
        if (!notifier.isLoading && notifier.suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: const Key('mentor-suggestion-retry'),
              onPressed: notifier.reloadSuggestions,
              child: Text(l.mentorSuggestionRefresh),
            ),
          ),
        ],
      ],
    );
  }

  static Color _backgroundColorForStatus(
    MentorPanelStatus status,
    BabyTalkColors colors,
  ) {
    switch (status) {
      case MentorPanelStatus.loading:
        return colors.infoSoft;
      case MentorPanelStatus.ready:
        return colors.infoSoft;
      case MentorPanelStatus.fallback:
        return colors.warningSoft;
      case MentorPanelStatus.error:
        return colors.errorSoft;
      case MentorPanelStatus.idle:
        return colors.bgSunken;
    }
  }

  static Color _foregroundColorForStatus(
    MentorPanelStatus status,
    BabyTalkColors colors,
  ) {
    switch (status) {
      case MentorPanelStatus.loading:
        return colors.info;
      case MentorPanelStatus.ready:
        return colors.info;
      case MentorPanelStatus.fallback:
        return colors.warning;
      case MentorPanelStatus.error:
        return colors.error;
      case MentorPanelStatus.idle:
        return colors.textSecondary;
    }
  }
}

class _MentorSharedContextBanner extends StatelessWidget {
  const _MentorSharedContextBanner({super.key, required this.status});

  final MentorSharedContextStatus status;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final foregroundColor = status.adopted ? colors.info : colors.warning;
    final backgroundColor = status.adopted
        ? colors.infoSoft
        : colors.warningSoft;
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
            label: Text(l.mentorStatusLabel(status.headline)),
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
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Container(
      key: Key('mentor-suggestion-card-${suggestion.suggestionId}'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(AppLayoutConstants.largeRadius),
        border: Border.all(color: colors.outlineSoft),
        boxShadow: colors.warmShadowSm,
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
                color: colors.english,
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
                label: Text(
                  isSpeaking ? l.mentorReading : l.mentorSuggestionRead,
                ),
              ),
              if (suggestion.reasonCode != null &&
                  suggestion.reasonCode!.trim().isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          l.mentorSuggestionSource(
                            _suggestionReasonLabel(l, suggestion.reasonCode!),
                          ),
                        ),
                      ),
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

String _suggestionReasonLabel(AppLocalizations l, String reasonCode) {
  switch (reasonCode) {
    case 'recent_result':
      return l.mentorSuggestionReasonRecentResult;
    case 'stage_reinforcement':
      return l.mentorSuggestionReasonStageReinforcement;
    case 'stage_guide':
      return l.mentorSuggestionReasonStageGuide;
    case 'stage_only':
      return l.mentorSuggestionReasonStageOnly;
    case 'starter_phrase':
      return l.mentorSuggestionReasonStarterPhrase;
    case 'shared_context_adopted_newer':
    case 'shared_context_adopted_local_gap':
      return l.mentorSuggestionReasonSharedContext;
    case 'fallback':
    case 'safe_small_step':
    case 'context_fallback_used':
      return l.mentorSuggestionReasonSafe;
    default:
      return l.mentorSuggestionReasonDefault;
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
