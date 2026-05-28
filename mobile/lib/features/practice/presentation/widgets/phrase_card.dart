import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
import 'package:mobile/features/practice/presentation/practice_session_notifier.dart';
import 'package:mobile/features/practice/presentation/widgets/reaction_chip_row.dart';
import 'package:mobile/l10n/app_localizations.dart';

class PhraseCard extends StatelessWidget {
  const PhraseCard({
    super.key,
    required this.phrase,
    required this.isActive,
    required this.isCompleted,
    required this.playbackStatus,
    required this.saveStatus,
    required this.playbackMessage,
    required this.saveMessage,
    required this.canPlay,
    required this.canSubmitReaction,
    required this.onPlay,
    required this.onReactionSelected,
    this.onTtsSpeak,
    this.isTtsMode = false,
  });

  final PracticePhrase phrase;
  final bool isActive;
  final bool isCompleted;
  final PracticePlaybackStatus playbackStatus;
  final PracticeSaveStatus saveStatus;
  final String? playbackMessage;
  final String? saveMessage;
  final bool canPlay;
  final bool canSubmitReaction;
  final VoidCallback? onPlay;
  final ValueChanged<BabyReactionType>? onReactionSelected;
  final VoidCallback? onTtsSpeak;
  final bool isTtsMode;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'English phrase: ${phrase.english}',
      excludeSemantics: false,
      child: Container(
        key: Key('phrase-card-${phrase.phraseId}'),
        padding: isActive
            ? const EdgeInsets.all(AppLayoutConstants.spacingLg)
            : const EdgeInsets.symmetric(
                horizontal: AppLayoutConstants.spacingMd,
                vertical: AppLayoutConstants.spacingSm,
              ),
        child: isActive ? _buildExpanded(context) : _buildCollapsed(context),
      ),
    );
  }

  Widget _buildCollapsed(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isCompleted ? colors.successSoft : colors.bgSunken,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${phrase.step}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                phrase.english,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                phrase.chinese,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isCompleted ? colors.successSoft : colors.bgAccentSoft,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Text(
            isCompleted ? l.phraseRecorded : l.phrasePending,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isCompleted ? colors.success : colors.accentDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpanded(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.practicePhraseStep(phrase.step),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.end,
                runAlignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusPill(label: _playbackLabel(l, playbackStatus)),
                  _StatusPill(label: _saveLabel(l, saveStatus)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppLayoutConstants.spacingMd),
        Text(
          phrase.english,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: colors.english),
        ),
        const SizedBox(height: AppLayoutConstants.spacingXs),
        Text(
          phrase.pronunciation,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontFamily: 'JetBrains Mono',
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: AppLayoutConstants.spacingXs),
        Text(phrase.chinese, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: AppLayoutConstants.spacingMd),
        LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final stackAction = constraints.maxWidth < 320 || textScale >= 1.25;
            final playButton = _buildPlayButton(context);
            final note = Text(
              l.phraseNote,
              style: Theme.of(context).textTheme.bodySmall,
            );

            if (stackAction) {
              return Column(
                key: Key('phrase-action-stacked-${phrase.phraseId}'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  playButton,
                  const SizedBox(height: AppLayoutConstants.spacingSm),
                  note,
                ],
              );
            }

            return Row(
              key: Key('phrase-action-row-${phrase.phraseId}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                playButton,
                const SizedBox(width: AppLayoutConstants.spacingMd),
                Expanded(child: note),
              ],
            );
          },
        ),
        if (playbackMessage != null) ...[
          const SizedBox(height: 14),
          _MessageBanner(
            key: const Key('playback-banner'),
            message: playbackMessage!,
            backgroundColor: playbackStatus == PracticePlaybackStatus.error
                ? colors.errorSoft
                : colors.infoSoft,
            foregroundColor: playbackStatus == PracticePlaybackStatus.error
                ? colors.error
                : colors.info,
          ),
        ],
        const SizedBox(height: AppLayoutConstants.spacingMd),
        Text(
          l.phraseReactionLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppLayoutConstants.spacingXs),
        ReactionChipRow(
          phraseId: phrase.phraseId,
          enabled: canSubmitReaction,
          onSelected: onReactionSelected,
        ),
        if (saveMessage != null) ...[
          const SizedBox(height: 14),
          _MessageBanner(
            key: const Key('save-banner'),
            message: saveMessage!,
            backgroundColor: saveStatus == PracticeSaveStatus.error
                ? colors.errorSoft
                : colors.successSoft,
            foregroundColor: saveStatus == PracticeSaveStatus.error
                ? colors.error
                : colors.success,
          ),
        ],
      ],
    );
  }

  Widget _buildPlayButton(BuildContext context) {
    final colors = context.appColors;
    final isPlaying = playbackStatus == PracticePlaybackStatus.playing;
    return Semantics(
      label: isTtsMode ? '朗读发音' : '播放发音',
      button: true,
      child: InkWell(
        key: Key(
          isTtsMode ? 'tts-${phrase.phraseId}' : 'play-${phrase.phraseId}',
        ),
        borderRadius: BorderRadius.circular(9999),
        onTap: isTtsMode ? onTtsSpeak : (canPlay ? onPlay : null),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isTtsMode
                    ? Icons.record_voice_over_rounded
                    : (isPlaying
                          ? Icons.graphic_eq_rounded
                          : Icons.volume_up_outlined),
                size: 18,
                color: colors.textSecondary,
              ),
              if (isPlaying) ...[
                const SizedBox(width: 4),
                Text(
                  '播放中',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _playbackLabel(AppLocalizations l, PracticePlaybackStatus status) {
    switch (status) {
      case PracticePlaybackStatus.idle:
        return l.phrasePlaybackReady;
      case PracticePlaybackStatus.playing:
        return l.phrasePlaybackPlaying;
      case PracticePlaybackStatus.completed:
        return l.phrasePlaybackCompleted;
      case PracticePlaybackStatus.error:
        return l.phrasePlaybackRetry;
    }
  }

  String _saveLabel(AppLocalizations l, PracticeSaveStatus status) {
    switch (status) {
      case PracticeSaveStatus.idle:
        return l.phraseSaveAwaitingReaction;
      case PracticeSaveStatus.saving:
        return l.phraseSaveSaving;
      case PracticeSaveStatus.saved:
        return l.phraseSaveSaved;
      case PracticeSaveStatus.error:
        return l.phraseSaveRetry;
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.bgSunken,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({
    super.key,
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String message;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
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
