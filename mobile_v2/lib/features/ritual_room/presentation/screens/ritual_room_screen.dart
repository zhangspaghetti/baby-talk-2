import 'package:flutter/material.dart';

import '../../domain/models/ritual_room_content.dart';
import '../capability/interaction_capability_mask.dart';
import '../state/ritual_room_ui_state.dart';
import '../widgets/ritual_context_input_tray.dart';
import '../widgets/ritual_current_utterance.dart';
import '../widgets/ritual_identity_header.dart';
import '../widgets/ritual_reassurance.dart';

final class RitualRoomScreen extends StatelessWidget {
  const RitualRoomScreen({
    super.key,
    required this.state,
    required this.capabilityMask,
    required this.onReactionSelected,
    required this.onRetry,
    required this.onListen,
    required this.onQuietExit,
  });

  final RitualRoomUiState state;
  final InteractionCapabilityMask capabilityMask;
  final ValueChanged<String> onReactionSelected;
  final VoidCallback onRetry;
  final VoidCallback onListen;
  final VoidCallback onQuietExit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: switch (state) {
              RitualRoomIdle() || RitualRoomLoading() => const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: '正在准备 Ritual Room',
                ),
              ),
              RitualRoomLoadFailure() => _LoadFailure(onRetry: onRetry),
              RitualRoomReady(:final room) => _RoomProjection(
                room: room,
                snapshotState: state,
                capabilityMask: capabilityMask,
                onReactionSelected: onReactionSelected,
                onListen: onListen,
                onQuietExit: onQuietExit,
              ),
              RitualRoomSubmitting(:final room) => _RoomProjection(
                room: room,
                snapshotState: state,
                capabilityMask: capabilityMask,
                onReactionSelected: onReactionSelected,
                onListen: onListen,
                onQuietExit: onQuietExit,
              ),
              RitualRoomRecoverableFailure(:final room) => _RoomProjection(
                room: room,
                snapshotState: state,
                capabilityMask: capabilityMask,
                onReactionSelected: onReactionSelected,
                onListen: onListen,
                onQuietExit: onQuietExit,
              ),
            },
          ),
        ),
      ),
    );
  }
}

final class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '这个小声音暂时没准备好。稍后再打开一次。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            key: const Key('ritual-load-retry'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: onRetry,
            child: const Text('再试一次'),
          ),
        ],
      ),
    );
  }
}

final class _RoomProjection extends StatelessWidget {
  const _RoomProjection({
    required this.room,
    required this.snapshotState,
    required this.capabilityMask,
    required this.onReactionSelected,
    required this.onListen,
    required this.onQuietExit,
  });

  final RitualRoomContent room;
  final RitualRoomUiState snapshotState;
  final InteractionCapabilityMask capabilityMask;
  final ValueChanged<String> onReactionSelected;
  final VoidCallback onListen;
  final VoidCallback onQuietExit;

  @override
  Widget build(BuildContext context) {
    final snapshot = snapshotState.snapshot!;
    final isSubmitting = snapshotState is RitualRoomSubmitting;
    final isRecoverableFailure = snapshotState is RitualRoomRecoverableFailure;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        RitualIdentityHeader(
          illustration: room.illustration,
          roomName: room.roomName,
          routineAnchor: room.routineAnchor,
          anchorPhrase: room.anchorPhrase,
          chineseHelper: room.chineseHelper,
        ),
        RitualCurrentUtterance(
          snapshot: snapshot,
          actionCue: room.actionCue,
          audio: room.audio,
          submitting: isSubmitting,
          pendingCopy: room.pendingCopy,
          onListen: onListen,
        ),
        if (isRecoverableFailure)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '暂时没换好说法，可以再试一次。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        if (capabilityMask.exposes(InteractionCapability.reactionSelection))
          RitualContextInputTray(
            prompt: room.reactionPrompt,
            choices: room.reactionChoices,
            moreChoicesLabel: '更多情况',
            onReactionSelected: onReactionSelected,
          ),
        RitualReassurance(
          message: room.reassurance,
          quietExitLabel: room.quietExit,
          onQuietExit: onQuietExit,
        ),
      ],
    );
  }
}
