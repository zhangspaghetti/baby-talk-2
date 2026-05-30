import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';

class PlaybackPreferencesScreen extends ConsumerStatefulWidget {
  const PlaybackPreferencesScreen({super.key});

  @override
  ConsumerState<PlaybackPreferencesScreen> createState() =>
      _PlaybackPreferencesScreenState();
}

class _PlaybackPreferencesScreenState
    extends ConsumerState<PlaybackPreferencesScreen> {
  bool _autoPlayEnabled = true;
  double _audioSpeed = 1.0;
  bool _initialized = false;

  void _syncFromNotifier(dynamic snapshot) {
    if (_initialized) return;
    _initialized = true;
    _autoPlayEnabled = snapshot.autoPlayEnabled;
    _audioSpeed = snapshot.audioSpeed;
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(settingsNotifierProvider);
    final snapshot = notifier.snapshot;
    final colors = context.appColors;

    _syncFromNotifier(snapshot);

    return Scaffold(
      backgroundColor: colors.bgBase,
      appBar: AppBar(
        title: const Text('播放偏好'),
        backgroundColor: colors.bgSurface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayoutConstants.maxContentWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Auto-play
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: colors.warmShadowSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.play_circle_outline, color: colors.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '自动播放',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '进入活动时自动播放语音',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _autoPlayEnabled,
                          onChanged: (value) {
                            setState(() {
                              _autoPlayEnabled = value;
                            });
                            _save();
                          },
                          activeThumbColor: colors.accent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Audio speed
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: colors.warmShadowSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.speed, color: colors.accent),
                        const SizedBox(width: 12),
                        Text(
                          '语速',
                          style: TextStyle(
                            fontSize: 16,
                            color: colors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_audioSpeed.toStringAsFixed(1)}x',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: colors.accent,
                        inactiveTrackColor: colors.bgSunken,
                        thumbColor: colors.accent,
                        overlayColor: colors.bgAccentSoft,
                      ),
                      child: Slider(
                        value: _audioSpeed,
                        min: 0.5,
                        max: 2.0,
                        divisions: 6,
                        onChanged: (value) {
                          setState(() {
                            _audioSpeed = double.parse(
                              value.toStringAsFixed(1),
                            );
                          });
                        },
                        onChangeEnd: (_) => _save(),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '0.5x',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textMuted,
                          ),
                        ),
                        Text(
                          '1.0x',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textMuted,
                          ),
                        ),
                        Text(
                          '2.0x',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    ref
        .read(settingsNotifierProvider.notifier)
        .updatePlaybackPreferences(
          autoPlay: _autoPlayEnabled,
          speed: _audioSpeed,
        );
  }
}
