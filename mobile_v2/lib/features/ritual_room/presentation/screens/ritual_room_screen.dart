import 'package:flutter/material.dart';

import '../../../../app/localization/generated/app_localizations.dart';
import '../../domain/models/ritual_room_content.dart';
import '../capability/interaction_capability_mask.dart';
import '../models/ritual_listen_state.dart';
import '../state/ritual_room_ui_state.dart';
import '../widgets/ritual_atmosphere_layer.dart';
import '../widgets/ritual_context_dock.dart';
import '../widgets/ritual_sentence_plane.dart';

final class RitualRoomScreen extends StatefulWidget {
  const RitualRoomScreen({
    super.key,
    required this.state,
    required this.capabilityMask,
    required this.onReactionSelected,
    required this.onRetry,
    required this.onRetryPendingEvent,
    this.onQuietExit = _noopCallback,
    required this.onListen,
    this.listenAdapterInjected = false,
  });

  final RitualRoomUiState state;
  final InteractionCapabilityMask capabilityMask;
  final ValueChanged<String> onReactionSelected;
  final VoidCallback onRetry;
  final VoidCallback onRetryPendingEvent;
  final VoidCallback onQuietExit;
  final VoidCallback onListen;
  final bool listenAdapterInjected;

  @override
  State<RitualRoomScreen> createState() => _RitualRoomScreenState();
}

void _noopCallback() {}

final class _RitualRoomScreenState extends State<RitualRoomScreen> {
  bool _dockExpanded = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final room = switch (state) {
      RitualRoomReady(:final room) ||
      RitualRoomSubmitting(:final room) ||
      RitualRoomUnknownOutcome(:final room) ||
      RitualRoomRecoverableFailure(:final room) => room,
      _ => null,
    };

    return PopScope(
      canPop: !_dockExpanded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _dockExpanded) {
          setState(() => _dockExpanded = false);
        }
      },
      child: Scaffold(
        key: const Key('ritual-room-root'),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    Positioned.fill(
                      child: room == null
                          ? const _FallbackAtmosphereLayer()
                          : RitualAtmosphereLayer(
                              illustration: room.illustration,
                              tone: room.atmosphereTone,
                              roomName: room.roomName,
                            ),
                    ),
                    Positioned.fill(
                      child: switch (state) {
                        RitualRoomIdle() || RitualRoomLoading() =>
                          _LoadingContent(dockExpanded: _dockExpanded),
                        RitualRoomLoadFailure() => _LoadFailure(
                          onRetry: widget.onRetry,
                        ),
                        RitualRoomReady() ||
                        RitualRoomSubmitting() ||
                        RitualRoomUnknownOutcome() ||
                        RitualRoomRecoverableFailure() => _RitualSemanticContent(
                          state: state,
                          capabilityMask: widget.capabilityMask,
                          dockExpanded: _dockExpanded,
                          onDockExpandedChanged: (expanded) {
                            setState(() => _dockExpanded = expanded);
                          },
                          onReactionSelected: widget.onReactionSelected,
                          onRetryPendingEvent: widget.onRetryPendingEvent,
                          onQuietExit: widget.onQuietExit,
                          onListen: widget.onListen,
                          listenAdapterInjected: widget.listenAdapterInjected,
                        ),
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _FallbackAtmosphereLayer extends StatelessWidget {
  const _FallbackAtmosphereLayer();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: DecoratedBox(
          key: const Key('ritual-atmosphere-field'),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
          ),
        ),
      ),
    );
  }
}

final class _LoadingContent extends StatelessWidget {
  const _LoadingContent({required this.dockExpanded});

  final bool dockExpanded;

  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            container: true,
            child: Text(
              copy.loadingSentence,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const Spacer(),
          IgnorePointer(
            child: RitualContextDock(
              expanded: dockExpanded,
              requestStatus: RitualDockRequestStatus.idle,
              prompt: copy.contextPrompt,
              reassurance: copy.contextPromptHint,
              quietExitLabel: copy.collapseContext,
              choices: const [],
              selectedReactionId: null,
              notice: null,
              onToggleExpanded: (_) {},
              onReactionSelected: (_) {},
              onReconcileUnknown: null,
              onQuietExit: () {},
            ),
          ),
        ],
      ),
    );
  }
}

final class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final copy = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            copy.loadFailure,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            key: const Key('ritual-load-retry'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: onRetry,
            child: Text(copy.retry),
          ),
        ],
      ),
    );
  }
}

final class _RitualSemanticContent extends StatelessWidget {
  const _RitualSemanticContent({
    required this.state,
    required this.capabilityMask,
    required this.dockExpanded,
    required this.onDockExpandedChanged,
    required this.onReactionSelected,
    required this.onRetryPendingEvent,
    required this.onQuietExit,
    required this.onListen,
    required this.listenAdapterInjected,
  });

  final RitualRoomUiState state;
  final InteractionCapabilityMask capabilityMask;
  final bool dockExpanded;
  final ValueChanged<bool> onDockExpandedChanged;
  final ValueChanged<String> onReactionSelected;
  final VoidCallback onRetryPendingEvent;
  final VoidCallback onQuietExit;
  final VoidCallback onListen;
  final bool listenAdapterInjected;

  @override
  Widget build(BuildContext context) {
    final room = switch (state) {
      RitualRoomReady(:final room) ||
      RitualRoomSubmitting(:final room) ||
      RitualRoomUnknownOutcome(:final room) ||
      RitualRoomRecoverableFailure(:final room) => room,
      _ => throw StateError('Semantic content requires room state'),
    };
    final snapshot = state.snapshot!;
    final copy = AppLocalizations.of(context);
    final requestStatus = switch (state) {
      RitualRoomSubmitting() => RitualDockRequestStatus.submitting,
      RitualRoomUnknownOutcome(:final isRetrying) => isRetrying
          ? RitualDockRequestStatus.reconciling
          : RitualDockRequestStatus.unknownOutcome,
      RitualRoomRecoverableFailure() => RitualDockRequestStatus.recoverableFailure,
      _ => RitualDockRequestStatus.idle,
    };
    final unknownOutcome = state is RitualRoomUnknownOutcome
        ? state as RitualRoomUnknownOutcome
        : null;
    final selectedReaction = switch (state) {
      RitualRoomSubmitting(:final selectedReaction) => selectedReaction,
      RitualRoomUnknownOutcome(:final selectedReaction) => selectedReaction,
      _ => null,
    };
    final notice = switch (requestStatus) {
      RitualDockRequestStatus.submitting => room.pendingCopy,
      RitualDockRequestStatus.recoverableFailure => copy.recoverableFailure,
      RitualDockRequestStatus.unknownOutcome || RitualDockRequestStatus.reconciling =>
        copy.unknownOutcome,
      RitualDockRequestStatus.idle => null,
    };
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final motionDuration = reduceMotion
        ? const Duration(milliseconds: 80)
        : const Duration(milliseconds: 220);
    final listenState = room.audio.available
        ? const RitualListenReady()
        : const RitualListenUnavailable();
    final effectiveListenState =
      room.audio.available && !listenAdapterInjected
        ? const RitualListenUnavailable()
        : listenState;
    final listenAction = effectiveListenState is RitualListenUnavailable
      ? null
      : onListen;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: RitualSentencePlane(
                utterance: snapshot.activeUtterance,
                listenState: effectiveListenState,
                onListen: listenAction,
                motionDuration: motionDuration,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (capabilityMask.exposes(InteractionCapability.reactionSelection))
            RitualContextDock(
              expanded: dockExpanded,
              requestStatus: requestStatus,
              prompt: room.reactionPrompt,
              reassurance: room.reassurance,
              quietExitLabel: room.quietExit,
              choices: room.reactionChoices,
              selectedReactionId: selectedReaction,
              notice: notice,
              onToggleExpanded: onDockExpandedChanged,
              onReactionSelected: onReactionSelected,
              onReconcileUnknown: unknownOutcome != null && !unknownOutcome.isRetrying
                  ? onRetryPendingEvent
                  : null,
              onQuietExit: () {
                onQuietExit();
                onDockExpandedChanged(false);
              },
            ),
        ],
      ),
    );
  }
}
