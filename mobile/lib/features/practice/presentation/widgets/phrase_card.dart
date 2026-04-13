import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
import 'package:mobile/features/practice/presentation/practice_session_view_model.dart';
import 'package:mobile/features/practice/presentation/widgets/reaction_chip_row.dart';

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

  @override
  Widget build(BuildContext context) {
    final borderColor = isActive
        ? AppTheme.english
        : isCompleted
        ? AppTheme.success
        : const Color(0xFFE7DDD6);

    return Container(
      key: Key('phrase-card-${phrase.phraseId}'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isActive ? 2 : 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F2D2926),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: isActive ? _buildExpanded(context) : _buildCollapsed(context),
    );
  }

  Widget _buildCollapsed(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isCompleted ? AppTheme.successSoft : AppTheme.bgSunken,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Text(
            '${phrase.step}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textPrimary,
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
                ).textTheme.titleMedium?.copyWith(color: AppTheme.textPrimary),
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
            color: isCompleted ? AppTheme.successSoft : AppTheme.bgAccentSoft,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Text(
            isCompleted ? '已记录' : '待练习',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isCompleted ? AppTheme.success : AppTheme.accentDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpanded(BuildContext context) {
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
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            fontSize: 28,
            color: AppTheme.english,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          phrase.pronunciation,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontFamily: 'JetBrains Mono',
            color: AppTheme.textPrimary,
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
              child: ElevatedButton(
                key: Key('play-${phrase.phraseId}'),
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                ),
                onPressed: canPlay ? onPlay : null,
                child: Icon(
                  playbackStatus == PracticePlaybackStatus.playing
                      ? Icons.graphic_eq_rounded
                      : Icons.play_arrow_rounded,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                '点按播放真实本地音频，再选择宝宝反应。状态会直接暴露为 idle / playing / completed / error。',
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
                ? AppTheme.errorSoft
                : AppTheme.infoSoft,
            foregroundColor: playbackStatus == PracticePlaybackStatus.error
                ? AppTheme.error
                : AppTheme.info,
          ),
        ],
        const SizedBox(height: 16),
        Text('宝宝现在的反应', style: Theme.of(context).textTheme.titleMedium),
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
                ? AppTheme.errorSoft
                : AppTheme.successSoft,
            foregroundColor: saveStatus == PracticeSaveStatus.error
                ? AppTheme.error
                : AppTheme.success,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.bgSunken,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.textPrimary,
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
