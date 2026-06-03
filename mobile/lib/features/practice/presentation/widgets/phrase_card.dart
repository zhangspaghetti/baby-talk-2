import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_audio_button.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
import 'package:mobile/features/practice/presentation/practice_session_notifier.dart';
import 'package:mobile/features/practice/presentation/widgets/scene_reaction_chip_row.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// Controls which mode the expanded [PhraseCard] renders.
enum PhraseCardPhase {
  /// Default state: phrase text + playback button.
  ready,

  /// After "说完了": "已保存本句" label + [SceneReactionChipRow].
  saved,
}

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
    this.phase = PhraseCardPhase.ready,
    this.sceneTag,
    this.selectedReactionType,
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
  final PhraseCardPhase phase;
  final String? sceneTag;
  final BabyReactionType? selectedReactionType;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'English phrase: ${phrase.english}',
      excludeSemantics: false,
      child: Container(
        key: Key('phrase-card-${phrase.phraseId}'),
        padding: isActive
            ? const EdgeInsets.all(AppLayoutConstants.spacingMd)
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Compact meta row: step + status ──────────────────────────────
        Row(
          children: [
            Text(
              l.practicePhraseStep(phrase.step),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textSecondary,
                  ),
            ),
            const Spacer(),
            _StatusPill(label: _playbackLabel(l, playbackStatus)),
            const SizedBox(width: 6),
            _StatusPill(label: _saveLabel(l, saveStatus)),
          ],
        ),
        const SizedBox(height: AppLayoutConstants.spacingMd),
        // ── Hero: English phrase ─────────────────────────────────────────
        Semantics(
          header: true,
          child: Text(
            phrase.english,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: colors.english,
                  fontSize: 36,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(height: AppLayoutConstants.spacingSm),
        // ── Supporting: pronunciation + Chinese (muted) ──────────────────
        Text(
          phrase.pronunciation,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontFamily: 'JetBrains Mono',
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          phrase.chinese,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppLayoutConstants.spacingMd),
        // ── Action: play button ──────────────────────────────────────────
        _buildPlayButton(context),
        if (playbackMessage != null) ...[
          const SizedBox(height: AppLayoutConstants.spacingSm),
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
        if (phase == PhraseCardPhase.saved || canSubmitReaction) ...[
          const SizedBox(height: AppLayoutConstants.spacingSm),
          if (phase == PhraseCardPhase.saved) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 14, color: colors.success),
                const SizedBox(width: 4),
                Text(
                  '已保存',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.success,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppLayoutConstants.spacingSm),
          ],
          Text(
            l.phraseReactionLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.textSecondary,
                ),
          ),
          const SizedBox(height: 6),
          SceneReactionChipRow(
            phraseId: phrase.phraseId,
            sceneTag: sceneTag,
            enabled: canSubmitReaction,
            selectedType: selectedReactionType,
            onSelected: onReactionSelected,
          ),
        ],
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
    final isPlaying = playbackStatus == PracticePlaybackStatus.playing;
    final icon = isTtsMode
        ? Icons.record_voice_over_rounded
        : (isPlaying ? Icons.graphic_eq_rounded : Icons.volume_up_outlined);
    return AppAudioButton(
      buttonKey: Key(
        isTtsMode ? 'tts-${phrase.phraseId}' : 'play-${phrase.phraseId}',
      ),
      semanticsLabel: isTtsMode ? '朗读发音' : '播放发音',
      icon: icon,
      isPlaying: isPlaying,
      onTap: isTtsMode ? onTtsSpeak : (canPlay ? onPlay : null),
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
