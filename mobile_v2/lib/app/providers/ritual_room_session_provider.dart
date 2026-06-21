import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ritual_room/domain/models/advance_result.dart';
import '../../features/ritual_room/domain/models/input_event.dart';
import '../../features/ritual_room/domain/models/product_snapshot.dart';
import '../../features/ritual_room/domain/models/ritual_room_content.dart';
import '../../features/ritual_room/presentation/state/ritual_room_ui_state.dart';
import '../../features/ritual_room/domain/repositories/interaction_outcome_unknown_exception.dart';
import 'interaction_engine_providers.dart';
import 'ritual_room_data_providers.dart';

final ritualRoomSessionProvider =
    NotifierProvider<RitualRoomSessionNotifier, RitualRoomUiState>(
      RitualRoomSessionNotifier.new,
    );

final class RitualRoomSessionNotifier extends Notifier<RitualRoomUiState> {
  var _operationEpoch = 0;
  var _disposed = false;
  String? _activeRoomId;
  _PendingInteractionCommand? _pendingCommand;

  @override
  RitualRoomUiState build() {
    ref.onDispose(() {
      _disposed = true;
      _operationEpoch += 1;
      _pendingCommand = null;
    });
    return const RitualRoomIdle();
  }

  Future<void> openRoom(String ritualRoomId) async {
    if (_activeRoomId == ritualRoomId &&
        state is! RitualRoomLoadFailure &&
        state is! RitualRoomIdle) {
      return;
    }

    _pendingCommand = null;
    final epoch = ++_operationEpoch;
    _activeRoomId = ritualRoomId;
    state = const RitualRoomLoading();

    try {
      final room = await ref
          .read(ritualRoomRepositoryProvider)
          .loadRoom(ritualRoomId);
      if (!_isCurrent(epoch)) {
        return;
      }

      final snapshot = await ref
          .read(interactionSessionInitializerProvider)
          .initialize(ritualRoomId);
      if (!_isCurrent(epoch)) {
        return;
      }

      state = RitualRoomReady(room: room, snapshot: snapshot);
    } on Object catch (cause) {
      if (!_isCurrent(epoch)) {
        return;
      }
      _activeRoomId = null;
      state = RitualRoomLoadFailure(cause);
    }
  }

  Future<void> reloadRoom(String ritualRoomId) async {
    _pendingCommand = null;
    _activeRoomId = null;
    await openRoom(ritualRoomId);
  }

  Future<void> submitReaction(String selected) async {
    final current = _usableSession(state);
    if (current == null || _pendingCommand != null) {
      return;
    }

    final input = ref.read(interactionInputFactoryProvider).reaction(selected);
    await _submitCommand(
      current: current,
      command: _PendingInteractionCommand(
        input: input,
        interactionId: current.snapshot.interactionId,
        expectedRevision: current.snapshot.revision,
        selectedReaction: selected,
      ),
    );
  }

  Future<void> submit(InputEvent input) async {
    final current = _usableSession(state);
    if (current == null || _pendingCommand != null) {
      return;
    }

    await _submitCommand(
      current: current,
      command: _PendingInteractionCommand(
        input: input,
        interactionId: current.snapshot.interactionId,
        expectedRevision: current.snapshot.revision,
        selectedReaction: null,
      ),
    );
  }

  Future<void> retryPendingEvent() async {
    final currentState = state;
    final command = _pendingCommand;
    if (currentState is! RitualRoomUnknownOutcome ||
        currentState.isRetrying ||
        command == null) {
      return;
    }

    final epoch = ++_operationEpoch;
    state = RitualRoomUnknownOutcome(
      room: currentState.room,
      snapshot: currentState.snapshot,
      selectedReaction: currentState.selectedReaction,
      isRetrying: true,
    );
    await _executeCommand(
      epoch: epoch,
      room: currentState.room,
      priorSnapshot: currentState.snapshot,
      command: command,
    );
  }

  Future<void> _submitCommand({
    required _UsableSession current,
    required _PendingInteractionCommand command,
  }) async {
    _pendingCommand = command;
    final epoch = ++_operationEpoch;
    state = RitualRoomSubmitting(
      room: current.room,
      snapshot: current.snapshot,
      selectedReaction: command.selectedReaction,
    );
    await _executeCommand(
      epoch: epoch,
      room: current.room,
      priorSnapshot: current.snapshot,
      command: command,
    );
  }

  Future<void> _executeCommand({
    required int epoch,
    required RitualRoomContent room,
    required ProductSnapshot priorSnapshot,
    required _PendingInteractionCommand command,
  }) async {
    try {
      final result = await ref
          .read(interactionRepositoryProvider)
          .advance(
            interactionId: command.interactionId,
            expectedRevision: command.expectedRevision,
            input: command.input,
          );
      if (!_isCurrent(epoch)) {
        return;
      }

      _pendingCommand = null;
      state = switch (result) {
        AdvanceApplied(:final snapshot) ||
        AdvanceDuplicateIgnored(
          :final snapshot,
        ) => RitualRoomReady(room: room, snapshot: snapshot),
        AdvanceRejected(:final code, :final latestSnapshot) =>
          RitualRoomRecoverableFailure(
            room: room,
            snapshot: latestSnapshot ?? priorSnapshot,
            problem: RitualRoomProblem(code),
          ),
      };
    } on InteractionOutcomeUnknownException {
      if (!_isCurrent(epoch) || !identical(_pendingCommand, command)) {
        return;
      }
      state = RitualRoomUnknownOutcome(
        room: room,
        snapshot: priorSnapshot,
        selectedReaction: command.selectedReaction,
        isRetrying: false,
      );
    } on Object catch (cause) {
      if (!_isCurrent(epoch)) {
        return;
      }
      _pendingCommand = null;
      state = RitualRoomRecoverableFailure(
        room: room,
        snapshot: priorSnapshot,
        problem: RitualRoomProblem(null, cause: cause),
      );
    }
  }

  bool _isCurrent(int epoch) => !_disposed && epoch == _operationEpoch;

  _UsableSession? _usableSession(RitualRoomUiState current) =>
      switch (current) {
        RitualRoomReady(:final room, :final snapshot) ||
        RitualRoomRecoverableFailure(
          :final room,
          :final snapshot,
        ) => _UsableSession(room: room, snapshot: snapshot),
        _ => null,
      };
}

final class _UsableSession {
  const _UsableSession({required this.room, required this.snapshot});

  final RitualRoomContent room;
  final ProductSnapshot snapshot;
}

final class _PendingInteractionCommand {
  const _PendingInteractionCommand({
    required this.input,
    required this.interactionId,
    required this.expectedRevision,
    required this.selectedReaction,
  });

  final InputEvent input;
  final String interactionId;
  final int expectedRevision;
  final String? selectedReaction;
}
