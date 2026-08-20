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

String mentorPanelStatusLabel(AppLocalizations l, MentorPanelStatus status) {
  switch (status) {
    case MentorPanelStatus.idle:
      return l.mentorStatusPreparing;
    case MentorPanelStatus.loading:
      return l.mentorStatusOrganizing;
    case MentorPanelStatus.ready:
      return l.mentorStatusReady;
    case MentorPanelStatus.fallback:
      return l.mentorStatusLocalFallback;
    case MentorPanelStatus.error:
      return l.mentorStatusSafeFallback;
  }
}

String mentorPanelTabLabel(AppLocalizations l, MentorPanelTab tab) {
  switch (tab) {
    case MentorPanelTab.suggestions:
      return l.mentorSuggestionTab;
    case MentorPanelTab.chat:
      return l.mentorChatTab;
  }
}

String mentorChatAvailabilityTitle(
  AppLocalizations l,
  MentorChatAvailability availability,
) {
  switch (availability.code) {
    case MentorChatAvailabilityCode.accountLoading:
      return l.mentorChatAvailabilityLoadingTitle;
    case MentorChatAvailabilityCode.ready:
      return l.mentorChatAvailabilityReadyTitle;
    case MentorChatAvailabilityCode.offline:
      return l.mentorChatAvailabilityOfflineTitle;
    case MentorChatAvailabilityCode.loginRequired:
      return availability.phase == 'mentor_session_required'
          ? l.mentorChatAvailabilityReloginTitle
          : l.mentorChatAvailabilityLoginTitle;
    case MentorChatAvailabilityCode.consentRequired:
      return l.mentorChatAvailabilityConsentTitle;
  }
}

String mentorChatAvailabilityDetail(
  AppLocalizations l,
  MentorChatAvailability availability,
) {
  switch (availability.code) {
    case MentorChatAvailabilityCode.accountLoading:
      return l.mentorChatAvailabilityLoadingDetail;
    case MentorChatAvailabilityCode.ready:
      return l.mentorChatAvailabilityReadyDetail;
    case MentorChatAvailabilityCode.offline:
      return l.mentorChatAvailabilityOfflineDetail;
    case MentorChatAvailabilityCode.loginRequired:
      return availability.phase == 'mentor_session_required'
          ? l.mentorChatAvailabilityReloginDetail
          : l.mentorChatAvailabilityLoginDetail;
    case MentorChatAvailabilityCode.consentRequired:
      return l.mentorChatAvailabilityConsentDetail;
  }
}

String mentorBannerLabel(AppLocalizations l, MentorBannerState banner) {
  switch (banner.code) {
    case 'account-loading':
      return l.mentorBannerAccountLoading;
    case 'ready':
      return l.mentorBannerReady;
    case 'offline':
      return l.mentorBannerOffline;
    case 'login-required':
      return l.mentorBannerLoginRequired;
    case 'consent-required':
      return l.mentorBannerConsentRequired;
    case 'onboarding_missing':
      return l.mentorBannerOnboardingMissing;
    case 'onboarding_malformed':
    case 'onboarding_unavailable':
      return l.mentorBannerOnboardingUnavailable;
    case 'starter_seed_missing':
    case 'practice_restore_failed':
    case 'practice_restore_timeout':
    case 'practice_restore_malformed':
      return l.mentorBannerContextRestore;
    case 'suggestion_render_fallback':
      return l.mentorBannerSuggestionRenderFallback;
    case 'context_fallback_used':
      return l.mentorBannerGenericFallback;
    case 'missing_prompt':
      return l.mentorBannerMissingPrompt;
    case 'prompt_too_long':
      return l.mentorBannerPromptTooLong(banner.maxLength ?? 0);
    case 'chat_requesting':
      return l.mentorBannerChatRequesting;
    case 'chat_fallback':
      return l.mentorBannerChatFallback;
    case 'timeout':
      return l.mentorBannerChatTimeout;
    case '401':
      return l.mentorBannerChatUnauthorized;
    case '403':
      return l.mentorBannerChatConsentRevoked;
    case '426':
      return l.mentorBannerChatVersionBlocked;
    case 'rate-limited':
      return l.mentorBannerChatRateLimited;
    case 'malformed':
      return l.mentorBannerChatMalformed;
    case 'blocked-fallback':
      return l.mentorBannerChatBlockedFallback;
    case 'server-error':
      return l.mentorBannerChatServerError;
    default:
      return l.mentorBannerGenericError;
  }
}

String mentorAudioStatusLabel(AppLocalizations l, String code) {
  switch (code) {
    case 'tts_unavailable':
      return l.mentorAudioUnavailable;
    case 'tts_failed':
      return l.mentorAudioFailed;
    default:
      return l.mentorAudioFailed;
  }
}

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
        if (notifier.banner != null)
          _MentorAlertBanner(
            key: const Key('mentor-panel-banner'),
            message: mentorBannerLabel(l, notifier.banner!),
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
          if (notifier.banner != null) const SizedBox(height: 12),
          _MentorSharedContextBanner(
            key: const Key('mentor-shared-context-banner'),
            status: notifier.sharedContextStatus!,
          ),
        ],
        if (notifier.audioStatusCode != null) ...[
          if (notifier.banner != null || notifier.sharedContextStatus != null)
            const SizedBox(height: 12),
          _MentorAlertBanner(
            key: const Key('mentor-audio-banner'),
            message: mentorAudioStatusLabel(l, notifier.audioStatusCode!),
            foregroundColor: colors.warning,
            backgroundColor: colors.warningSoft,
          ),
        ],
        if (notifier.banner != null ||
            notifier.audioStatusCode != null ||
            notifier.sharedContextStatus != null)
          const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              key: const Key('mentor-selected-tab-chip'),
              label: Text(
                l.mentorCurrentTabLabel(
                  mentorPanelTabLabel(l, notifier.selectedTab),
                ),
              ),
            ),
            Chip(
              key: const Key('mentor-status-chip'),
              label: Text(
                l.mentorStatusLabel(
                  mentorPanelStatusLabel(l, notifier.panelStatus),
                ),
              ),
            ),
            Chip(
              key: const Key('mentor-chat-chip'),
              label: Text(
                l.mentorChatStatusLabel(
                  mentorChatAvailabilityTitle(l, notifier.chatAvailability),
                ),
              ),
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
