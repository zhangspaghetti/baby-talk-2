import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
import 'package:mobile/features/practice/presentation/practice_session_view_model.dart';
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
    final colors = context.appColors;
    final borderColor = isActive
        ? colors.english
        : isCompleted
        ? colors.success
        : colors.outlineSoft;

    return Semantics(
      label: 'English phrase: ${phrase.english}',
      excludeSemantics: false,
      child: Container(
        key: Key('phrase-card-${phrase.phraseId}'),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isActive ? 2 : 1),
          boxShadow: colors.warmShadowSm,
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
              'STEP ${phrase.step}',
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
                  _StatusPill(label: '音频 · ${_playbackLabel(playbackStatus)}'),
                  _StatusPill(label: '保存 · ${_saveLabel(saveStatus)}'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          phrase.english,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: colors.english,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          phrase.pronunciation,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontFamily: 'JetBrains Mono',
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(phrase.chinese, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Semantics(
                label: isTtsMode ? '朗读发音' : '播放发音',
                button: true,
                child: ElevatedButton(
                  key: Key(
                    isTtsMode
                        ? 'tts-${phrase.phraseId}'
                        : 'play-${phrase.phraseId}',
                  ),
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: isTtsMode ? onTtsSpeak : (canPlay ? onPlay : null),
                  child: Icon(
                    isTtsMode
                        ? Icons.record_voice_over_rounded
                        : (playbackStatus == PracticePlaybackStatus.playing
                              ? Icons.graphic_eq_rounded
                              : Icons.play_arrow_rounded),
                    size: 30,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                l.phraseNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
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
        const SizedBox(height: 16),
        Text(
          l.phraseReactionLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
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

  String _playbackLabel(PracticePlaybackStatus status) {
    switch (status) {
      case PracticePlaybackStatus.idle:
        return 'idle';
      case PracticePlaybackStatus.playing:
        return 'playing';
      case PracticePlaybackStatus.completed:
        return 'completed';
      case PracticePlaybackStatus.error:
        return 'error';
    }
  }

  String _saveLabel(PracticeSaveStatus status) {
    switch (status) {
      case PracticeSaveStatus.idle:
        return 'idle';
      case PracticeSaveStatus.saving:
        return 'saving';
      case PracticeSaveStatus.saved:
        return 'saved';
      case PracticeSaveStatus.error:
        return 'error';
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
