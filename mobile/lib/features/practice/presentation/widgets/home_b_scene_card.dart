import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
import 'package:mobile/features/practice/presentation/practice_session_notifier.dart';

/// Scene card widget for Home B (Scene-mentor direction).
///
/// Displays the care scene with parent action first, then the English phrase
/// embedded in the scene context. The phrase is the hero, but framed as
/// something to say right now, not a lesson item.
class HomeBSceneCard extends StatefulWidget {
  const HomeBSceneCard({
    super.key,
    required this.phrase,
    required this.parentAction,
    this.sceneTag,
    this.coachTip,
    this.onStartPractice,
  });

  final PracticePhrase? phrase;
  final String parentAction;
  final String? sceneTag;
  final String? coachTip;
  final VoidCallback? onStartPractice;

  @override
  State<HomeBSceneCard> createState() => _HomeBSceneCardState();
}

enum _PlaybackState { idle, playing, played }

class _HomeBSceneCardState extends State<HomeBSceneCard> {
  _PlaybackState _playbackState = _PlaybackState.idle;
  late final PracticeAudioController _audioController;
  StreamSubscription? _audioSubscription;
  bool _playbackFailed = false;

  @override
  void initState() {
    super.initState();
    _audioController = AudioplayersPracticeAudioController();
    _audioSubscription = _audioController.completionStream.listen((_) {
      if (mounted) {
        setState(() {
          _playbackState = _PlaybackState.played;
          _playbackFailed = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    _audioController.dispose();
    super.dispose();
  }

  Future<void> _playAudio() async {
    if (_playbackState == _PlaybackState.playing) return;
    final assetPath = widget.phrase?.audioPlayerAsset;
    if (assetPath == null || assetPath.isEmpty) {
      if (mounted) {
        setState(() {
          _playbackFailed = true;
          _playbackState = _PlaybackState.idle;
        });
      }
      return;
    }
    setState(() {
      _playbackState = _PlaybackState.playing;
      _playbackFailed = false;
    });
    try {
      await _audioController.playAsset(assetPath);
    } catch (e) {
      if (mounted) {
        setState(() {
          _playbackState = _PlaybackState.idle;
          _playbackFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final englishText = widget.phrase?.english ?? "Let's put it back.";
    final chineseText = widget.phrase?.chinese ?? '我们把它放回去吧。';

    return Container(
      key: const Key('home-b-scene-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Parent action - what to do
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.bgAccentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.touch_app_rounded,
                  size: 16,
                  color: colors.accentDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '你的动作',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.parentAction,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Divider
          Container(height: 1, color: colors.outlineSoft),
          const SizedBox(height: 20),
          // English phrase - the hero
          Semantics(
            label: '英文句子: $englishText',
            child: Text(
              englishText,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: colors.english,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            label: '中文翻译: $chineseText',
            child: Text(
              chineseText,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Audio play + action row
          Row(
            children: [
              // Audio button
              Semantics(
                button: true,
                label: _playbackFailed
                    ? '播放失败，点击重试'
                    : _playbackState == _PlaybackState.playing
                        ? '正在播放'
                        : '听一遍',
                child: GestureDetector(
                  onTap: _playAudio,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.bgSunken,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _playbackState == _PlaybackState.playing
                              ? Icons.graphic_eq
                              : _playbackFailed
                                  ? Icons.error_outline
                                  : Icons.play_circle_fill,
                          size: 18,
                          color: _playbackFailed
                              ? colors.warning
                              : colors.accentDark,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _playbackFailed
                              ? '重试'
                              : _playbackState == _PlaybackState.playing
                                  ? '播放中'
                                  : _playbackState == _PlaybackState.played
                                      ? '再听'
                                      : '听一遍',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: _playbackFailed
                                ? colors.warning
                                : colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // Main CTA
              FilledButton(
                key: const Key('home-b-start-practice'),
                onPressed: widget.onStartPractice,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('试着说这一句'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
