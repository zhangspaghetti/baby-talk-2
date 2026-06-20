import 'dart:async';

import 'interaction_runtime_state.dart';

typedef RuntimeCommit = void Function(InteractionRuntimeState next);
typedef ExclusiveRuntimeOperation<T> =
    Future<T> Function(InteractionRuntimeState? current, RuntimeCommit commit);

abstract interface class InteractionRuntimeStore {
  Future<void> create(InteractionRuntimeState state);

  Future<T> runExclusive<T>(
    String interactionId,
    ExclusiveRuntimeOperation<T> operation,
  );
}

final class InMemoryInteractionRuntimeStore implements InteractionRuntimeStore {
  final Map<String, InteractionRuntimeState> _states = {};
  final Map<String, Future<void>> _tails = {};

  @override
  Future<void> create(InteractionRuntimeState state) async {
    add(state);
  }

  void add(InteractionRuntimeState state) {
    final interactionId = state.snapshot.interactionId;
    if (_states.containsKey(interactionId)) {
      throw StateError('Interaction already exists: $interactionId');
    }
    _states[interactionId] = state;
  }

  InteractionRuntimeState? read(String interactionId) => _states[interactionId];

  InteractionRuntimeState? debugState(String interactionId) =>
      _states[interactionId];

  @override
  Future<T> runExclusive<T>(
    String interactionId,
    ExclusiveRuntimeOperation<T> operation,
  ) async {
    final previous = _tails[interactionId] ?? Future<void>.value();
    final release = Completer<void>();
    final tail = release.future;
    _tails[interactionId] = tail;

    await previous.catchError((Object _) {});

    InteractionRuntimeState? pending;
    var committed = false;
    void commit(InteractionRuntimeState next) {
      if (committed) {
        throw StateError('Runtime aggregate may be committed only once');
      }
      if (next.snapshot.interactionId != interactionId) {
        throw ArgumentError('Committed runtime interaction ID does not match');
      }
      committed = true;
      pending = next;
    }

    try {
      final result = await operation(_states[interactionId], commit);
      if (committed) {
        _states[interactionId] = pending!;
      }
      return result;
    } finally {
      release.complete();
      if (identical(_tails[interactionId], tail)) {
        _tails.remove(interactionId);
      }
    }
  }
}
