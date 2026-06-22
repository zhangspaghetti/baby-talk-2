import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/interaction_engine.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/normalize_engine.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/state_accumulator.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/strategy_engine.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/utterance_engine.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/advance_result.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/context_memory.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/input_event.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/normalized_input.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/product_snapshot.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/strategy_decision.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/active_utterance.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_clock.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_id_generator.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_runtime_store.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_seed_source.dart';

void main() {
  test(
    'accepted transition reads one clock and commits all evidence once',
    () async {
      final harness = _AtomicHarness();
      final initial = await harness.engine.initialize('shoes_on_room_v1');
      final before = harness.measure(initial.interactionId);

      final result = await harness.engine.advance(
        interactionId: initial.interactionId,
        expectedRevision: 0,
        input: _event('event-1'),
      );
      final after = harness.measure(initial.interactionId);
      final record = harness.store
          .debugState(initial.interactionId)!
          .replayJournal
          .records
          .single;

      expect(result, isA<AdvanceApplied>());
      expect(after.revision, before.revision + 1);
      expect(after.receipts, before.receipts + 1);
      expect(after.records, before.records + 1);
      expect(after.normalizeCalls, before.normalizeCalls + 1);
      expect(after.accumulateCalls, before.accumulateCalls + 1);
      expect(after.strategyCalls, before.strategyCalls + 1);
      expect(after.utteranceCalls, before.utteranceCalls + 1);
      expect(after.clockCalls, before.clockCalls + 1);
      expect(result.snapshot!.metadata.updatedAt, record.occurredAt);
    },
  );

  test(
    'pipeline failure leaks no revision, receipt, journal, or clock work',
    () async {
      final harness = _AtomicHarness(failUtterance: true);
      final initial = await harness.engine.initialize('shoes_on_room_v1');
      final before = harness.measure(initial.interactionId);

      final result = await harness.engine.advance(
        interactionId: initial.interactionId,
        expectedRevision: 0,
        input: _event('event-1'),
      );
      final after = harness.measure(initial.interactionId);

      expect((result as AdvanceRejected).code, AdvanceErrorCode.pipelineFailed);
      expect(after.revision, before.revision);
      expect(after.receipts, before.receipts);
      expect(after.records, before.records);
      expect(after.normalizeCalls, before.normalizeCalls + 1);
      expect(after.accumulateCalls, before.accumulateCalls + 1);
      expect(after.strategyCalls, before.strategyCalls + 1);
      expect(after.utteranceCalls, before.utteranceCalls + 1);
      expect(after.clockCalls, before.clockCalls);
    },
  );

  test(
    'duplicate and revision rejection run no pipeline or clock work',
    () async {
      final harness = _AtomicHarness();
      final initial = await harness.engine.initialize('shoes_on_room_v1');
      await harness.engine.advance(
        interactionId: initial.interactionId,
        expectedRevision: 0,
        input: _event('event-1'),
      );
      final beforeDuplicate = harness.measure(initial.interactionId);

      final duplicate = await harness.engine.advance(
        interactionId: initial.interactionId,
        expectedRevision: 0,
        input: _event('event-1'),
      );
      final afterDuplicate = harness.measure(initial.interactionId);
      final stale = await harness.engine.advance(
        interactionId: initial.interactionId,
        expectedRevision: 0,
        input: _event('event-2'),
      );
      final afterStale = harness.measure(initial.interactionId);

      expect(duplicate, isA<AdvanceDuplicateIgnored>());
      expect(
        (stale as AdvanceRejected).code,
        AdvanceErrorCode.revisionConflict,
      );
      expect(afterDuplicate, beforeDuplicate);
      expect(afterStale, beforeDuplicate);
    },
  );

  test(
    'two concurrent requests from one revision produce exactly one commit',
    () async {
      final gate = Completer<void>();
      final entered = Completer<void>();
      final harness = _AtomicHarness(
        pipelineGate: gate,
        pipelineEntered: entered,
      );
      final initial = await harness.engine.initialize('shoes_on_room_v1');
      final before = harness.measure(initial.interactionId);

      final first = harness.engine.advance(
        interactionId: initial.interactionId,
        expectedRevision: 0,
        input: _event('event-1'),
      );
      await entered.future;
      final second = harness.engine.advance(
        interactionId: initial.interactionId,
        expectedRevision: 0,
        input: _event('event-2'),
      );
      gate.complete();
      final results = await Future.wait([first, second]);
      final after = harness.measure(initial.interactionId);

      expect(results.whereType<AdvanceApplied>(), hasLength(1));
      expect(
        results.whereType<AdvanceRejected>().where(
          (result) => result.code == AdvanceErrorCode.revisionConflict,
        ),
        hasLength(1),
      );
      expect(after.revision, before.revision + 1);
      expect(after.receipts, before.receipts + 1);
      expect(after.records, before.records + 1);
      expect(after.normalizeCalls, before.normalizeCalls + 1);
      expect(after.accumulateCalls, before.accumulateCalls + 1);
      expect(after.strategyCalls, before.strategyCalls + 1);
      expect(after.utteranceCalls, before.utteranceCalls + 1);
      expect(after.clockCalls, before.clockCalls + 1);
    },
  );
}

InputEvent _event(String id) => InputEvent.reactionSelection(
  eventId: id,
  occurredAt: DateTime.utc(2026, 6, 20, 11),
  selected: 'joining_action',
);

final class _Measure {
  const _Measure({
    required this.revision,
    required this.receipts,
    required this.records,
    required this.normalizeCalls,
    required this.accumulateCalls,
    required this.strategyCalls,
    required this.utteranceCalls,
    required this.clockCalls,
  });

  final int revision;
  final int receipts;
  final int records;
  final int normalizeCalls;
  final int accumulateCalls;
  final int strategyCalls;
  final int utteranceCalls;
  final int clockCalls;

  @override
  bool operator ==(Object other) =>
      other is _Measure &&
      revision == other.revision &&
      receipts == other.receipts &&
      records == other.records &&
      normalizeCalls == other.normalizeCalls &&
      accumulateCalls == other.accumulateCalls &&
      strategyCalls == other.strategyCalls &&
      utteranceCalls == other.utteranceCalls &&
      clockCalls == other.clockCalls;

  @override
  int get hashCode => Object.hash(
    revision,
    receipts,
    records,
    normalizeCalls,
    accumulateCalls,
    strategyCalls,
    utteranceCalls,
    clockCalls,
  );
}

final class _AtomicHarness {
  _AtomicHarness({
    bool failUtterance = false,
    Completer<void>? pipelineGate,
    Completer<void>? pipelineEntered,
  }) {
    normalize = _NormalizeSpy(gate: pipelineGate, entered: pipelineEntered);
    utterance = _UtteranceSpy(fail: failUtterance);
    engine = InteractionEngine(
      clock: clock,
      idGenerator: _Id(),
      seedSource: _Seed(),
      store: store,
      normalizeEngine: normalize,
      stateAccumulator: accumulate,
      strategyEngine: strategy,
      utteranceEngine: utterance,
    );
  }

  final store = InMemoryInteractionRuntimeStore();
  final clock = _Clock();
  late final _NormalizeSpy normalize;
  final accumulate = _AccumulatorSpy();
  final strategy = _StrategySpy();
  late final _UtteranceSpy utterance;
  late final InteractionEngine engine;

  _Measure measure(String interactionId) {
    final state = store.debugState(interactionId)!;
    return _Measure(
      revision: state.snapshot.revision,
      receipts: state.consistencyState.receipts.length,
      records: state.replayJournal.records.length,
      normalizeCalls: normalize.calls,
      accumulateCalls: accumulate.calls,
      strategyCalls: strategy.calls,
      utteranceCalls: utterance.calls,
      clockCalls: clock.calls,
    );
  }
}

final class _Clock implements InteractionClock {
  int calls = 0;

  @override
  DateTime now() => DateTime.utc(2026, 6, 20, 12, calls++);
}

final class _Id implements InteractionIdGenerator {
  @override
  String generate() => 'interaction-atomic';
}

final class _Seed implements InteractionSeedSource {
  @override
  Future<InteractionSeed> load(String ritualRoomId) async => InteractionSeed(
    anchor: 'Shoes on.',
    normalizedContext: _normalized(),
    memory: _memory(),
    strategy: _strategy(),
    activeUtterance: _activeUtterance(),
  );
}

final class _NormalizeSpy implements NormalizeEngine {
  _NormalizeSpy({this.gate, this.entered});

  final Completer<void>? gate;
  final Completer<void>? entered;
  int calls = 0;

  @override
  Future<NormalizedInput> normalize(InputEvent event) async {
    calls += 1;
    if (entered != null && !entered!.isCompleted) {
      entered!.complete();
    }
    if (gate != null) {
      await gate!.future;
    }
    return _normalized();
  }
}

final class _AccumulatorSpy implements StateAccumulator {
  int calls = 0;

  @override
  Future<ContextMemory> accumulate({
    required NormalizedInput normalized,
    required ContextMemory previous,
    required ProductSnapshot current,
  }) async {
    calls += 1;
    return _memory();
  }
}

final class _StrategySpy implements StrategyEngine {
  int calls = 0;

  @override
  Future<StrategyDecision> decide({
    required NormalizedInput normalized,
    required ContextMemory memory,
    required ProductSnapshot current,
  }) async {
    calls += 1;
    return _strategy();
  }
}

final class _UtteranceSpy implements UtteranceEngine {
  _UtteranceSpy({required this.fail});

  final bool fail;
  int calls = 0;

  @override
  Future<ActiveUtterance> realize({
    required String ritualRoomId,
    required StrategyDecision strategy,
    required NormalizedInput normalized,
    required ContextMemory memory,
  }) async {
    calls += 1;
    if (fail) {
      throw StateError('planned pipeline failure');
    }
    return _activeUtterance();
  }
}

NormalizedInput _normalized() => NormalizedInput(
  semanticSignals: const ['shared_action'],
  intentEstimate: 'engage',
  momentHypothesis: 'the shared action is open to enter',
  contextFrame: const {'actionContext': 'putting shoes on'},
  confidence: 0.8,
  eventSummary: 'the shared routine is available',
);

ContextMemory _memory() => ContextMemory(
  summary: 'current interaction evidence',
  eventLog: const ['compressed shared-action evidence'],
  signalWeights: const {'shared_action': 1},
  interactionTrend: 'increasing_joinability',
  contextStability: 0.8,
  narrative: 'the current shared routine is available',
);

StrategyDecision _strategy() => StrategyDecision(
  primary: PressurePolicy.lowPressure,
  modifiers: const [StrategyModifier.maintain],
  confidence: 0.8,
  rationale: 'current evidence selects low pressure',
  pressureLevel: 20,
  recommendedTone: 'soft',
  interactionHint: 'offer one small shared action',
);

ActiveUtterance _activeUtterance() => const ActiveUtterance(
  displayId: 'shoes_on_ready_v1',
  primary: 'Let’s put your shoes on.',
  zhSupport: '我们来穿鞋吧。',
  audioAssetId: 'rr_shoes_001',
);
