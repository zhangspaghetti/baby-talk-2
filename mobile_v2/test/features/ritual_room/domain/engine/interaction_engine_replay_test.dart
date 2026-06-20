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
import 'package:mobile_v2/features/ritual_room/domain/models/utterance.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_clock.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_id_generator.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_runtime_store.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_seed_source.dart';

void main() {
  test(
    'replay applies recorded outputs directly with no module clock or ID calls',
    () async {
      final harness = _ReplayHarness();
      final initial = await harness.engine.initialize('shoes_on_room_v1');
      final events = [
        InputEvent.reactionSelection(
          eventId: 'event-1',
          occurredAt: DateTime.utc(2026, 6, 20, 13),
          selected: 'running_away',
        ),
        InputEvent.futureSignal(
          eventId: 'event-2',
          occurredAt: DateTime.utc(2026, 6, 20, 13, 1),
          signal: 'shared_action',
          value: 'present',
        ),
      ];
      ProductSnapshot latest = initial;
      for (final event in events) {
        final result = await harness.engine.advance(
          interactionId: initial.interactionId,
          expectedRevision: latest.revision,
          input: event,
        );
        latest = (result as AdvanceApplied).snapshot;
      }
      final runtime = harness.store.debugState(initial.interactionId)!;
      final callsBeforeReplay = harness.calls;

      final replayed = runtime.replayJournal.replayFrom(runtime.initialSnapshot);

      _expectSnapshot(replayed, latest);
      expect(harness.calls, callsBeforeReplay);
      expect(runtime.replayJournal.records, hasLength(2));
    },
  );
}

final class _CallCounts {
  const _CallCounts({
    required this.ids,
    required this.clock,
    required this.normalize,
    required this.accumulate,
    required this.strategy,
    required this.utterance,
  });

  final int ids;
  final int clock;
  final int normalize;
  final int accumulate;
  final int strategy;
  final int utterance;

  @override
  bool operator ==(Object other) =>
      other is _CallCounts &&
      ids == other.ids &&
      clock == other.clock &&
      normalize == other.normalize &&
      accumulate == other.accumulate &&
      strategy == other.strategy &&
      utterance == other.utterance;

  @override
  int get hashCode =>
      Object.hash(ids, clock, normalize, accumulate, strategy, utterance);
}

final class _ReplayHarness {
  _ReplayHarness() {
    engine = InteractionEngine(
      clock: clock,
      idGenerator: ids,
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
  final ids = _Ids();
  final normalize = _Normalize();
  final accumulate = _Accumulate();
  final strategy = _Strategy();
  final utterance = _Utterance();
  late final InteractionEngine engine;

  _CallCounts get calls => _CallCounts(
    ids: ids.calls,
    clock: clock.calls,
    normalize: normalize.calls,
    accumulate: accumulate.calls,
    strategy: strategy.calls,
    utterance: utterance.calls,
  );
}

final class _Clock implements InteractionClock {
  int calls = 0;

  @override
  DateTime now() => DateTime.utc(2026, 6, 20, 14, calls++);
}

final class _Ids implements InteractionIdGenerator {
  int calls = 0;

  @override
  String generate() => 'interaction-${++calls}';
}

final class _Seed implements InteractionSeedSource {
  @override
  Future<InteractionSeed> load(String ritualRoomId) async => InteractionSeed(
    anchor: 'Shoes on.',
    normalizedContext: _normalized('seed'),
    memory: _memory('seed'),
    strategy: _strategy('seed'),
    utterance: _utterance('seed'),
  );
}

final class _Normalize implements NormalizeEngine {
  int calls = 0;

  @override
  Future<NormalizedInput> normalize(InputEvent event) async {
    calls += 1;
    return _normalized(event.eventId);
  }
}

final class _Accumulate implements StateAccumulator {
  int calls = 0;

  @override
  Future<ContextMemory> accumulate({
    required NormalizedInput normalized,
    required ContextMemory previous,
    required ProductSnapshot current,
  }) async {
    calls += 1;
    return _memory(normalized.eventSummary);
  }
}

final class _Strategy implements StrategyEngine {
  int calls = 0;

  @override
  Future<StrategyDecision> decide({
    required NormalizedInput normalized,
    required ContextMemory memory,
    required ProductSnapshot current,
  }) async {
    calls += 1;
    return _strategy(normalized.eventSummary);
  }
}

final class _Utterance implements UtteranceEngine {
  int calls = 0;

  @override
  Future<Utterance> realize({
    required String anchor,
    required StrategyDecision strategy,
    required NormalizedInput normalized,
    required ContextMemory memory,
  }) async {
    calls += 1;
    return _utterance(normalized.eventSummary);
  }
}

NormalizedInput _normalized(String marker) => NormalizedInput(
  semanticSignals: ['signal-$marker'],
  intentEstimate: 'observe',
  momentHypothesis: 'current shared-action evidence $marker',
  contextFrame: const {'actionContext': 'putting shoes on'},
  confidence: 0.8,
  eventSummary: 'summary-$marker',
);

ContextMemory _memory(String marker) => ContextMemory(
  summary: 'memory-$marker',
  eventLog: ['log-$marker'],
  signalWeights: {'signal-$marker': 1},
  interactionTrend: 'uncertain',
  contextStability: 0.8,
  narrative: 'narrative-$marker',
);

StrategyDecision _strategy(String marker) => StrategyDecision(
  primary: PressurePolicy.lowPressure,
  modifiers: const [StrategyModifier.maintain],
  confidence: 0.8,
  rationale: 'rationale-$marker',
  pressureLevel: 20,
  recommendedTone: 'soft',
  interactionHint: 'hint-$marker',
);

Utterance _utterance(String marker) => Utterance(
  primary: 'primary-$marker',
  zhHelper: 'helper-$marker',
  tone: 'soft',
  clarityLevel: 'high',
  contextFit: 'fit-$marker',
  alternatives: const [],
);

void _expectSnapshot(ProductSnapshot actual, ProductSnapshot expected) {
  expect(actual.schemaVersion, expected.schemaVersion);
  expect(actual.revision, expected.revision);
  expect(actual.interactionId, expected.interactionId);
  expect(actual.ritualRoomId, expected.ritualRoomId);
  expect(actual.anchor, expected.anchor);
  expect(actual.normalizedContext.semanticSignals, expected.normalizedContext.semanticSignals);
  expect(actual.normalizedContext.intentEstimate, expected.normalizedContext.intentEstimate);
  expect(actual.normalizedContext.momentHypothesis, expected.normalizedContext.momentHypothesis);
  expect(actual.normalizedContext.contextFrame, expected.normalizedContext.contextFrame);
  expect(actual.normalizedContext.confidence, expected.normalizedContext.confidence);
  expect(actual.normalizedContext.eventSummary, expected.normalizedContext.eventSummary);
  expect(actual.memory.summary, expected.memory.summary);
  expect(actual.memory.eventLog, expected.memory.eventLog);
  expect(actual.memory.signalWeights, expected.memory.signalWeights);
  expect(actual.memory.interactionTrend, expected.memory.interactionTrend);
  expect(actual.memory.contextStability, expected.memory.contextStability);
  expect(actual.memory.narrative, expected.memory.narrative);
  expect(actual.strategy.primary, expected.strategy.primary);
  expect(actual.strategy.modifiers, expected.strategy.modifiers);
  expect(actual.strategy.confidence, expected.strategy.confidence);
  expect(actual.strategy.rationale, expected.strategy.rationale);
  expect(actual.strategy.pressureLevel, expected.strategy.pressureLevel);
  expect(actual.strategy.recommendedTone, expected.strategy.recommendedTone);
  expect(actual.strategy.interactionHint, expected.strategy.interactionHint);
  expect(actual.utterance.primary, expected.utterance.primary);
  expect(actual.utterance.zhHelper, expected.utterance.zhHelper);
  expect(actual.utterance.tone, expected.utterance.tone);
  expect(actual.utterance.clarityLevel, expected.utterance.clarityLevel);
  expect(actual.utterance.contextFit, expected.utterance.contextFit);
  expect(actual.utterance.alternatives, expected.utterance.alternatives);
  expect(actual.metadata.lastEventId, expected.metadata.lastEventId);
  expect(actual.metadata.updatedAt, expected.metadata.updatedAt);
}
