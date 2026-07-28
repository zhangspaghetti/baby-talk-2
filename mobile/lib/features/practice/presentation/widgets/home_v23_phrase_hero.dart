import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/practice/domain/models/practice_phrase.dart';
import 'package:mobile/features/practice/presentation/practice_session_notifier.dart';
import 'package:mobile/l10n/app_localizations.dart';

class HomeV23PhraseHero extends StatefulWidget {
  final OnboardingSnapshot? snapshot;
  final PracticePhrase? starterPhrase;
  final String? activityTitle;
  final String? activitySceneTag;
  final VoidCallback? onStartPractice;
  final VoidCallback onOpenMentor;

  const HomeV23PhraseHero({
    super.key,
    this.snapshot,
    this.starterPhrase,
    this.activityTitle,
    this.activitySceneTag,
    this.onStartPractice,
    required this.onOpenMentor,
  });

  @override
  State<HomeV23PhraseHero> createState() => _HomeV23PhraseHeroState();
}

enum _PlaybackState { idle, playing, played }

class _HomeV23PhraseHeroState extends State<HomeV23PhraseHero> {
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

  String _getGreeting(String childName) {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return '早上好，$childName';
    } else if (hour < 18) {
      return '下午好，$childName';
    } else {
      return '晚上好，$childName';
    }
  }

  Future<void> _playRealAudio() async {
    if (_playbackState == _PlaybackState.playing) return;

    final assetPath = widget.starterPhrase?.audioPlayerAsset;
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

  String get _playbackStatusText {
    if (_playbackFailed) {
      return '这句没读出来，点我重试。';
    }
    switch (_playbackState) {
      case _PlaybackState.idle:
        return '听一遍，也可以直接开始。';
      case _PlaybackState.playing:
        return '听完就可以说。';
      case _PlaybackState.played:
        return '可以开始练。';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);
    final childName = widget.snapshot?.childDisplayName ?? l.guest;
    final englishText = widget.starterPhrase?.english ?? 'One more bite.';
    final chineseText = widget.starterPhrase?.chinese ?? '再吃一口';

    return Column(
      key: const Key('home-v23-phrase-hero'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Greeting
        Text(
          _getGreeting(childName),
          style: theme.textTheme.titleMedium?.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        // Scene Row
        Row(
          children: [
            Text(
              '${widget.activitySceneTag ?? '照护场景'} / ${widget.activityTitle ?? '喂饭开始'}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '先说一句，再顺手做一个小活动。',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            InkWell(
              onTap: widget.onOpenMentor,
              child: Semantics(
                button: true,
                label: '换个眼前场景',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '不是现在？换个眼前场景',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.accentDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: colors.accentDark,
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              key: const Key('home-mentor-entry'),
              onTap: widget.onOpenMentor,
              child: Semantics(
                button: true,
                label: '问小禾',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '问小禾',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.accentDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: colors.accentDark,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Phrase Hero Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.englishSoft,
            borderRadius: BorderRadius.circular(AppLayoutConstants.largeRadius),
            border: Border.all(color: colors.outlineSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  Chip(
                    label: Text(widget.activityTitle ?? '喂饭'),
                    backgroundColor: colors.bgSurface,
                    side: BorderSide(color: colors.outlineSoft),
                  ),
                  Chip(
                    label: const Text('适合现在'),
                    backgroundColor: colors.bgSurface,
                    side: BorderSide(color: colors.outlineSoft),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Semantics(
                label: '英文句子: $englishText',
                child: Text(
                  englishText,
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: colors.english,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                label: '中文翻译: $chineseText · 适合递勺前后轻轻说一次',
                child: Text(
                  '$chineseText · 适合递勺前后轻轻说一次',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Playback Status Text
              Semantics(
                label: '播放状态: $_playbackStatusText',
                child: Text(
                  _playbackStatusText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _playRealAudio,
                      icon: Icon(
                        _playbackState == _PlaybackState.playing
                            ? Icons.graphic_eq
                            : Icons.play_circle_fill,
                      ),
                      label: Text(
                        _playbackState == _PlaybackState.playing
                            ? '播放中'
                            : _playbackState == _PlaybackState.played
                            ? '再听一次'
                            : '读一下',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppLayoutConstants.cardRadius,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      key: const Key('home-start-practice'),
                      onPressed: widget.onStartPractice,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppLayoutConstants.cardRadius,
                          ),
                        ),
                      ),
                      child: const Text('今天先说一句'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
