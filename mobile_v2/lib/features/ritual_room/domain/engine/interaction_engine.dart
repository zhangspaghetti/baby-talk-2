import '../models/advance_result.dart';
import '../models/input_event.dart';
import '../models/product_snapshot.dart';
import '../runtime/consistency_state.dart';
import '../runtime/input_fingerprint.dart';
import '../runtime/interaction_clock.dart';
import '../runtime/interaction_id_generator.dart';
import '../runtime/interaction_runtime_state.dart';
import '../runtime/interaction_runtime_store.dart';
import '../runtime/interaction_seed_source.dart';
import '../runtime/interaction_session_initializer.dart';
import '../runtime/replay_journal.dart';
import 'interaction_engine_port.dart';
import 'normalize_engine.dart';
import 'state_accumulator.dart';
import 'strategy_engine.dart';
import 'utterance_engine.dart';

/// Sole lifecycle, consistency, transition, and atomic-commit authority.
final class InteractionEngine
    implements InteractionEnginePort, InteractionSessionInitializer {
  const InteractionEngine({
    required InteractionClock clock,
    required InteractionIdGenerator idGenerator,
    required InteractionSeedSource seedSource,
    required InteractionRuntimeStore store,
    required NormalizeEngine normalizeEngine,
    required StateAccumulator stateAccumulator,
    required StrategyEngine strategyEngine,
    required UtteranceEngine utteranceEngine,
  }) : _clock = clock,
       _idGenerator = idGenerator,
       _seedSource = seedSource,
       _store = store,
       _normalizeEngine = normalizeEngine,
       _stateAccumulator = stateAccumulator,
       _strategyEngine = strategyEngine,
       _utteranceEngine = utteranceEngine;

  final InteractionClock _clock;
  final InteractionIdGenerator _idGenerator;
  final InteractionSeedSource _seedSource;
  final InteractionRuntimeStore _store;
  final NormalizeEngine _normalizeEngine;
  final StateAccumulator _stateAccumulator;
  final StrategyEngine _strategyEngine;
  final UtteranceEngine _utteranceEngine;

  @override
  Future<ProductSnapshot> initialize(String ritualRoomId) async {
    final seed = await _seedSource.load(ritualRoomId);
    final snapshot = ProductSnapshot.initial(
      interactionId: _idGenerator.generate(),
      ritualRoomId: ritualRoomId,
      anchor: seed.anchor,
      normalizedContext: seed.normalizedContext,
      memory: seed.memory,
      strategy: seed.strategy,
      utterance: seed.utterance,
      updatedAt: _clock.now(),
    );
    await _store.create(InteractionRuntimeState.initial(snapshot));
    return snapshot;
  }

  @override
  Future<ProductSnapshot?> getSnapshot(String interactionId) =>
      _store.runExclusive<ProductSnapshot?>(
        interactionId,
        (current, commit) async => current?.snapshot,
      );

  @override
  Future<AdvanceResult> advance({
    required String interactionId,
    required int expectedRevision,
    required InputEvent input,
  }) {
    return _store.runExclusive<AdvanceResult>(interactionId, (
      current,
      commit,
    ) async {
      if (current == null) {
        return const AdvanceRejected(
          code: AdvanceErrorCode.interactionNotFound,
        );
      }
      if (current.snapshot.schemaVersion !=
          ProductSnapshot.currentSchemaVersion) {
        return AdvanceRejected(
          code: AdvanceErrorCode.unsupportedSchemaVersion,
          latestSnapshot: current.snapshot,
        );
      }
      if (!_isValid(input) || expectedRevision < 0) {
        return AdvanceRejected(
          code: AdvanceErrorCode.invalidInput,
          latestSnapshot: current.snapshot,
        );
      }

      final fingerprint = InputFingerprint.forEvent(input);
      final receipt = current.consistency.findByEventId(input.eventId);
      if (receipt != null && receipt.inputFingerprint == fingerprint) {
        return AdvanceDuplicateIgnored(current.snapshot);
      }
      if (receipt != null) {
        return AdvanceRejected(
          code: AdvanceErrorCode.eventIdConflict,
          latestSnapshot: current.snapshot,
        );
      }
      if (expectedRevision != current.snapshot.revision) {
        return AdvanceRejected(
          code: AdvanceErrorCode.revisionConflict,
          latestSnapshot: current.snapshot,
        );
      }

      try {
        final normalized = await _normalizeEngine.normalize(input);
        final memory = await _stateAccumulator.accumulate(
          normalized: normalized,
          previous: current.snapshot.memory,
          current: current.snapshot,
        );
        final strategy = await _strategyEngine.decide(
          normalized: normalized,
          memory: memory,
          current: current.snapshot,
        );
        final utterance = await _utteranceEngine.realize(
          anchor: current.snapshot.anchor,
          strategy: strategy,
          normalized: normalized,
          memory: memory,
        );

        final occurredAt = _clock.now();
        final nextRevision = current.snapshot.revision + 1;
        final nextSnapshot = ProductSnapshot(
          schemaVersion: current.snapshot.schemaVersion,
          revision: nextRevision,
          interactionId: current.snapshot.interactionId,
          ritualRoomId: current.snapshot.ritualRoomId,
          anchor: current.snapshot.anchor,
          normalizedContext: normalized,
          memory: memory,
          strategy: strategy,
          utterance: utterance,
          metadata: ProductSnapshotMetadata(
            lastEventId: input.eventId,
            updatedAt: occurredAt,
          ),
        );
        final nextConsistency = current.consistency.record(
          ConsistencyReceipt(
            eventId: input.eventId,
            inputFingerprint: fingerprint,
            appliedRevision: nextRevision,
          ),
        );
        final nextJournal = current.journal.append(
          TransitionRecord(
            eventId: input.eventId,
            fromRevision: current.snapshot.revision,
            toRevision: nextRevision,
            occurredAt: occurredAt,
            normalizedInput: normalized,
            updatedContextMemory: memory,
            strategyDecision: strategy,
            utterance: utterance,
          ),
        );
        final nextState = current.commit(
          currentSnapshot: nextSnapshot,
          consistencyState: nextConsistency,
          replayJournal: nextJournal,
        );

        commit(nextState);
        return AdvanceApplied(nextSnapshot);
      } on Object {
        return AdvanceRejected(
          code: AdvanceErrorCode.pipelineFailed,
          latestSnapshot: current.snapshot,
        );
      }
    });
  }

  bool _isValid(InputEvent input) {
    if (input.eventId.trim().isEmpty) {
      return false;
    }
    return switch (input.payload) {
      ReactionSelectionPayload(:final selected) => selected.trim().isNotEmpty,
      VoiceObservationPayload(:final transcript) =>
        transcript.trim().isNotEmpty,
      FreeTextPayload(:final text) => text.trim().isNotEmpty,
      FutureSignalPayload(:final signal, :final value) =>
        signal.trim().isNotEmpty && value.trim().isNotEmpty,
      StrategyPreferencePayload(:final preference) =>
        preference.trim().isNotEmpty,
    };
  }
}
