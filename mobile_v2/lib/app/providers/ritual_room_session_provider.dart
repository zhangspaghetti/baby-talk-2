import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ritual_room/domain/models/advance_result.dart';
import '../../features/ritual_room/domain/models/input_event.dart';
import '../../features/ritual_room/domain/models/product_snapshot.dart';
import '../../features/ritual_room/domain/models/ritual_room_content.dart';
import '../../features/ritual_room/presentation/state/ritual_room_ui_state.dart';
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

  @override
  RitualRoomUiState build() {
    ref.onDispose(() {
      _disposed = true;
      _operationEpoch += 1;
    });
    return const RitualRoomIdle();
  }

  Future<void> openRoom(String ritualRoomId) async {
    if (_activeRoomId == ritualRoomId &&
        state is! RitualRoomLoadFailure &&
        state is! RitualRoomIdle) {
      return;
    }

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

  Future<void> submit(InputEvent input) async {
    final current = _usableSession(state);
    if (current == null) {
      return;
    }

    final epoch = ++_operationEpoch;
    state = RitualRoomSubmitting(
      room: current.room,
      snapshot: current.snapshot,
    );

    try {
      final result = await ref
          .read(interactionRepositoryProvider)
          .advance(
            interactionId: current.snapshot.interactionId,
            expectedRevision: current.snapshot.revision,
            input: input,
          );
      if (!_isCurrent(epoch)) {
        return;
      }

      state = switch (result) {
        AdvanceApplied(:final snapshot) ||
        AdvanceDuplicateIgnored(
          :final snapshot,
        ) => RitualRoomReady(room: current.room, snapshot: snapshot),
        AdvanceRejected(:final code, :final latestSnapshot) =>
          RitualRoomRecoverableFailure(
            room: current.room,
            snapshot: latestSnapshot ?? current.snapshot,
            problem: RitualRoomProblem(code),
          ),
      };
    } on Object catch (cause) {
      if (!_isCurrent(epoch)) {
        return;
      }
      state = RitualRoomRecoverableFailure(
        room: current.room,
        snapshot: current.snapshot,
        problem: RitualRoomProblem(null, cause: cause),
      );
    }
  }

  bool _isCurrent(int epoch) => !_disposed && epoch == _operationEpoch;

  _UsableSession? _usableSession(RitualRoomUiState current) =>
      switch (current) {
        RitualRoomReady(:final room, :final snapshot) ||
        RitualRoomSubmitting(:final room, :final snapshot) ||
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
