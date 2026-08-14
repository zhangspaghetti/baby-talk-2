import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:mobile/features/care_entry/domain/care_entry_models.dart';
import 'package:mobile/features/care_entry/presentation/care_entry_selection_controller.dart';

abstract interface class CareEntryAudioPlayer {
  Future<void> playAsset(String assetPath);

  Future<void> dispose();
}

final class AudioplayersCareEntryAudioPlayer implements CareEntryAudioPlayer {
  AudioplayersCareEntryAudioPlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> playAsset(String assetPath) {
    return _player.play(AssetSource(assetPath));
  }

  @override
  Future<void> dispose() => _player.dispose();
}

class CareEntryEntrySurface extends StatefulWidget {
  const CareEntryEntrySurface({
    super.key,
    required this.controller,
    this.audioControllerFactory,
    this.onRetry,
  });

  final CareEntrySelectionController controller;
  final CareEntryAudioPlayer Function()? audioControllerFactory;
  final VoidCallback? onRetry;

  @override
  State<CareEntryEntrySurface> createState() => _CareEntryEntrySurfaceState();
}

class _CareEntryEntrySurfaceState extends State<CareEntryEntrySurface> {
  CareEntryAudioPlayer? _audioController;
  String? _audioMessage;
  bool _isPlaying = false;

  @override
  void dispose() {
    final audioController = _audioController;
    if (audioController != null) {
      unawaited(audioController.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        return Scaffold(
          backgroundColor: const Color(0xFFFFFBF3),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: switch (state.phase) {
                  CareEntrySelectionPhase.loading => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  CareEntrySelectionPhase.failure => _FailureView(
                    message: state.errorMessage ?? '暂时无法准备入口。',
                    onRetry: widget.onRetry,
                  ),
                  CareEntrySelectionPhase.selection => _SelectionView(
                    state: state,
                    onSelected: widget.controller.select,
                    onStarted: widget.controller.startSelected,
                  ),
                  CareEntrySelectionPhase.firstUtterance => _FirstUtteranceView(
                    entry: state.activeEntry!,
                    audioMessage: _audioMessage,
                    isPlaying: _isPlaying,
                    onPlayAudio: _playAudio,
                  ),
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _playAudio() async {
    final utterance = widget.controller.state.activeUtterance;
    if (utterance == null || _isPlaying) return;
    setState(() {
      _isPlaying = true;
      _audioMessage = null;
    });
    final controller = _audioController ??=
        widget.audioControllerFactory?.call() ??
        AudioplayersCareEntryAudioPlayer();
    try {
      final asset = utterance.audioAsset.startsWith('assets/')
          ? utterance.audioAsset.substring(7)
          : utterance.audioAsset;
      await controller.playAsset(asset);
    } on Object {
      if (mounted) {
        setState(() => _audioMessage = '今天先看着读也可以。');
      }
    } finally {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    }
  }
}

class _SelectionView extends StatelessWidget {
  const _SelectionView({
    required this.state,
    required this.onSelected,
    required this.onStarted,
  });

  final CareEntrySelectionState state;
  final ValueChanged<CareEntryId> onSelected;
  final VoidCallback onStarted;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      children: <Widget>[
        Text(
          '今天先从现在这一刻开始。',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: const Color(0xFF3F342C),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '不用学英语，只要对宝宝轻轻说一句。',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF6F6258)),
        ),
        const SizedBox(height: 24),
        GridView.builder(
          key: const Key('care-entry-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.entries.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 142,
          ),
          itemBuilder: (context, index) {
            final entry = state.entries[index];
            return CareEntryTile(
              entry: entry,
              selected: entry.id == state.selectedEntryId,
              onPressed: () => onSelected(entry.id),
            );
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: FilledButton(
            key: const Key('care-entry-primary-action'),
            onPressed: state.selectedEntryId == null ? null : onStarted,
            child: const Text('直接从现在开始'),
          ),
        ),
      ],
    );
  }
}

class CareEntryTile extends StatelessWidget {
  const CareEntryTile({
    super.key,
    required this.entry,
    required this.selected,
    required this.onPressed,
  });

  final ResolvedCareEntry entry;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? const Color(0xFFD67B45)
        : const Color(0xFFE1D7CA);
    return Semantics(
      button: true,
      selected: selected,
      label: entry.isRecommended ? '${entry.title}，现在推荐' : entry.title,
      child: OutlinedButton(
        key: Key('care-entry-tile-${entry.id.value}'),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(16),
          backgroundColor: selected ? const Color(0xFFFFF1E5) : Colors.white,
          side: BorderSide(color: borderColor, width: selected ? 2 : 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(_iconFor(entry.visualToken), color: const Color(0xFF6F6258)),
            const SizedBox(height: 10),
            Text(
              entry.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(entry.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _FirstUtteranceView extends StatelessWidget {
  const _FirstUtteranceView({
    required this.entry,
    required this.audioMessage,
    required this.isPlaying,
    required this.onPlayAudio,
  });

  final ResolvedCareEntry entry;
  final String? audioMessage;
  final bool isPlaying;
  final VoidCallback onPlayAudio;

  @override
  Widget build(BuildContext context) {
    final utterance = entry.seed.firstUtterance;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
      children: <Widget>[
        Text(
          entry.title,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: const Color(0xFFD06F3D)),
        ),
        const SizedBox(height: 18),
        Text(
          utterance.english,
          key: const Key('care-entry-first-utterance-english'),
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: const Color(0xFF3F342C),
            fontFamily: 'Fraunces',
          ),
        ),
        const SizedBox(height: 16),
        Text(utterance.chinese, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          utterance.pronunciation,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF6F6258)),
        ),
        const SizedBox(height: 28),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('care-entry-first-utterance-audio'),
            onPressed: isPlaying ? null : onPlayAudio,
            icon: const Icon(Icons.volume_up_outlined),
            label: Text(isPlaying ? '正在播放' : '听标准发音'),
          ),
        ),
        if (audioMessage != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(audioMessage!, key: const Key('care-entry-audio-message')),
        ],
      ],
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('再试一次')),
            ],
          ],
        ),
      ),
    );
  }
}

IconData _iconFor(String visualToken) => switch (visualToken) {
  'route.moon' => Icons.nightlight_round,
  'route.bottle' => Icons.local_drink_outlined,
  'route.soothing' => Icons.water_drop_outlined,
  'route.diaper' => Icons.checkroom_outlined,
  _ => Icons.favorite_outline,
};
