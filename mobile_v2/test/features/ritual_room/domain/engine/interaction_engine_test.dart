import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/interaction_engine.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/interaction_engine_port.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/normalize_engine.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/state_accumulator.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/strategy_engine.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/utterance_engine.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/advance_result.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/active_utterance.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/context_memory.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/input_event.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/normalized_input.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/product_snapshot.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/strategy_decision.dart';
import 'package:mobile_v2/features/ritual_room/domain/repositories/active_utterance_source.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_clock.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_id_generator.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_runtime_state.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_runtime_store.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_seed_source.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_session_initializer.dart';

void main() {
  group('InteractionEngine lifecycle and conflict authority', () {
    test(
      'port exposes reads and advances while concrete engine initializes',
      () {
        final harness = _Harness();
        final InteractionEnginePort port = harness.engine;
        final InteractionSessionInitializer initializer = harness.engine;

        expect(port, same(initializer));
      },
    );

    test(
      'initialize creates exactly one revision-zero runtime aggregate',
      () async {
        final harness = _Harness();

        final snapshot = await harness.engine.initialize('shoes_on_room_v1');
        final runtime = harness.store.debugState(snapshot.interactionId);

        expect(snapshot.schemaVersion, 2);
        expect(snapshot.revision, 0);
        expect(snapshot.interactionId, 'interaction-1');
        expect(snapshot.metadata.lastEventId, isNull);
        expect(harness.ids.calls, 1);
        expect(harness.seed.calls, 1);
        expect(harness.clock.calls, 1);
        expect(runtime, isNotNull);
        expect(runtime!.consistencyState.receipts, isEmpty);
        expect(runtime.replayJournal.records, isEmpty);
        expect(
          await harness.engine.getSnapshot(snapshot.interactionId),
          same(snapshot),
        );
        expect(await harness.engine.getSnapshot('missing-interaction'), isNull);
        expect(harness.ids.calls, 1, reason: 'snapshot reads never initialize');
        expect(
          harness.seed.calls,
          1,
          reason: 'snapshot reads never initialize',
        );
      },
    );

    test(
      'duplicate and event-ID checks precede expected-revision conflict',
      () async {
        final harness = _Harness();
        final initial = await harness.engine.initialize('shoes_on_room_v1');
        final first = _reaction('event-1', 'running_away');
        final second = _reaction('event-2', 'joining_action');

        final firstResult = await harness.engine.advance(
          interactionId: initial.interactionId,
          expectedRevision: 0,
          input: first,
        );
        final secondResult = await harness.engine.advance(
          interactionId: initial.interactionId,
          expectedRevision: 1,
          input: second,
        );
        final delayedDuplicate = await harness.engine.advance(
          interactionId: initial.interactionId,
          expectedRevision: 0,
          input: first,
        );
        final changedReuse = await harness.engine.advance(
          interactionId: initial.interactionId,
          expectedRevision: 2,
          input: _reaction('event-1', 'joining_action'),
        );
        final staleUnseen = await harness.engine.advance(
          interactionId: initial.interactionId,
          expectedRevision: 0,
          input: _reaction('event-3', 'joining_action'),
        );

        expect(firstResult, isA<AdvanceApplied>());
        expect(secondResult, isA<AdvanceApplied>());
        expect(delayedDuplicate, isA<AdvanceDuplicateIgnored>());
        expect(delayedDuplicate.snapshot!.revision, 2);
        expect(
          (changedReuse as AdvanceRejected).code,
          AdvanceErrorCode.eventIdConflict,
        );
        expect(changedReuse.latestSnapshot!.revision, 2);
        expect(
          (staleUnseen as AdvanceRejected).code,
          AdvanceErrorCode.revisionConflict,
        );
        expect(staleUnseen.latestSnapshot!.revision, 2);
        expect(harness.normalize.calls, 2);
        expect(harness.accumulate.calls, 2);
        expect(harness.strategy.calls, 2);
        expect(harness.utterance.calls, 2);
        expect(harness.clock.calls, 3);
      },
    );

    test(
      'unknown interaction is rejected before fingerprint or pipeline work',
      () async {
        final harness = _Harness();

        final result = await harness.engine.advance(
          interactionId: 'missing-interaction',
          expectedRevision: 0,
          input: _reaction('event-1', 'joining_action'),
        );

        expect(
          (result as AdvanceRejected).code,
          AdvanceErrorCode.interactionNotFound,
        );
        expect(result.latestSnapshot, isNull);
        expect(harness.totalPipelineCalls, 0);
        expect(harness.clock.calls, 0);
      },
    );

    test(
      'unsupported schema and invalid input reject without mutation',
      () async {
        final harness = _Harness();
        final initial = await harness.engine.initialize('shoes_on_room_v1');
        final clockBefore = harness.clock.calls;

        for (final schemaVersion in const [1, 3]) {
          final unsupported = ProductSnapshot(
            schemaVersion: schemaVersion,
            revision: initial.revision,
            interactionId: 'unsupported-interaction-$schemaVersion',
            ritualRoomId: initial.ritualRoomId,
            anchor: initial.anchor,
            normalizedContext: initial.normalizedContext,
            memory: initial.memory,
            strategy: initial.strategy,
            activeUtterance: initial.activeUtterance,
            metadata: initial.metadata,
          );
          harness.store.add(InteractionRuntimeState.initial(unsupported));
          final unsupportedResult = await harness.engine.advance(
            interactionId: unsupported.interactionId,
            expectedRevision: 0,
            input: _reaction('event-$schemaVersion', 'joining_action'),
          );

          expect(
            (unsupportedResult as AdvanceRejected).code,
            AdvanceErrorCode.unsupportedSchemaVersion,
          );
          expect(
            harness.store
                .debugState(unsupported.interactionId)!
                .snapshot
                .revision,
            0,
          );
        }
        final invalidResult = await harness.engine.advance(
          interactionId: initial.interactionId,
          expectedRevision: 0,
          input: InputEvent.freeText(
            eventId: '',
            occurredAt: DateTime.utc(2026, 6, 20, 9),
            text: '',
          ),
        );

        expect(
          (invalidResult as AdvanceRejected).code,
          AdvanceErrorCode.invalidInput,
        );
        expect(harness.totalPipelineCalls, 0);
        expect(harness.clock.calls, clockBefore);
        expect(
          harness.store.debugState(initial.interactionId)!.snapshot.revision,
          0,
        );
      },
    );
  });

  test(
    'all five channels evolve one snapshot without diagnostic or raw retention',
    () async {
      const rawVoice = 'RAW_VOICE_SENTINEL_41_04 child ran away';
      const rawText = 'RAW_FREE_TEXT_SENTINEL_41_04 attention moved away';
      final harness = _Harness(useRealPipeline: true);
      final initial = await harness.engine.initialize('shoes_on_room_v1');
      final inputs = <InputEvent>[
        _reaction('reaction-1', 'running_away'),
        InputEvent.voiceObservation(
          eventId: 'voice-1',
          occurredAt: DateTime.utc(2026, 6, 20, 9, 1),
          transcript: rawVoice,
        ),
        InputEvent.freeText(
          eventId: 'text-1',
          occurredAt: DateTime.utc(2026, 6, 20, 9, 2),
          text: rawText,
        ),
        InputEvent.futureSignal(
          eventId: 'signal-1',
          occurredAt: DateTime.utc(2026, 6, 20, 9, 3),
          signal: 'shared_action',
          value: 'present',
        ),
        InputEvent.strategyPreference(
          eventId: 'strategy-1',
          occurredAt: DateTime.utc(2026, 6, 20, 9, 4),
          preference: 'reduce_options',
        ),
      ];

      ProductSnapshot latest = initial;
      for (final input in inputs) {
        final result = await harness.engine.advance(
          interactionId: initial.interactionId,
          expectedRevision: latest.revision,
          input: input,
        );
        latest = (result as AdvanceApplied).snapshot;
      }

      final runtime = harness.store.debugState(initial.interactionId)!;
      final semanticDump = jsonEncode(runtime.toJson()).toLowerCase();
      expect(latest.revision, 5);
      expect(runtime.consistencyState.receipts, hasLength(5));
      expect(runtime.replayJournal.records, hasLength(5));
      expect(semanticDump, isNot(contains(rawVoice.toLowerCase())));
      expect(semanticDump, isNot(contains(rawText.toLowerCase())));
      expect(
        semanticDump,
        isNot(
          matches(
            RegExp(r'child score|correctness|diagnos|\bability\b|\btrait\b'),
          ),
        ),
      );
    },
  );
}

InputEvent _reaction(String eventId, String selected) =>
    InputEvent.reactionSelection(
      eventId: eventId,
      occurredAt: DateTime.utc(2026, 6, 20, 9),
      selected: selected,
    );

final class _Harness {
  _Harness({bool useRealPipeline = false})
    : store = InMemoryInteractionRuntimeStore(),
      clock = _CountingClock(),
      ids = _CountingIdGenerator(),
      seed = _CountingSeedSource(),
      normalize = _CountingNormalizeEngine(
        delegate: useRealPipeline ? RuleBasedNormalizeEngine() : null,
      ),
      accumulate = _CountingStateAccumulator(
        delegate: useRealPipeline ? DecayStateAccumulator() : null,
      ),
      strategy = _CountingStrategyEngine(
        delegate: useRealPipeline ? RuleBasedStrategyEngine() : null,
      ),
      utterance = _CountingUtteranceEngine(
        delegate: useRealPipeline
            ? RuleBasedUtteranceEngine(source: _ActiveSource())
            : null,
      ) {
    engine = InteractionEngine(
      clock: clock,
      idGenerator: ids,
      seedSource: seed,
      store: store,
      normalizeEngine: normalize,
      stateAccumulator: accumulate,
      strategyEngine: strategy,
      utteranceEngine: utterance,
    );
  }

  final InMemoryInteractionRuntimeStore store;
  final _CountingClock clock;
  final _CountingIdGenerator ids;
  final _CountingSeedSource seed;
  final _CountingNormalizeEngine normalize;
  final _CountingStateAccumulator accumulate;
  final _CountingStrategyEngine strategy;
  final _CountingUtteranceEngine utterance;
  late final InteractionEngine engine;

  int get totalPipelineCalls =>
      normalize.calls + accumulate.calls + strategy.calls + utterance.calls;
}

final class _CountingClock implements InteractionClock {
  int calls = 0;

  @override
  DateTime now() => DateTime.utc(2026, 6, 20, 10, calls++);
}

final class _CountingIdGenerator implements InteractionIdGenerator {
  int calls = 0;

  @override
  String generate() => 'interaction-${++calls}';
}

final class _CountingSeedSource implements InteractionSeedSource {
  int calls = 0;

  @override
  Future<InteractionSeed> load(String ritualRoomId) async {
    calls += 1;
    return InteractionSeed(
      anchor: 'Shoes on.',
      normalizedContext: _normalized('shared_action'),
      memory: _memory('shared_action'),
      strategy: _strategy(),
      activeUtterance: _activeUtterance(),
    );
  }
}

final class _CountingNormalizeEngine implements NormalizeEngine {
  _CountingNormalizeEngine({this.delegate});

  final NormalizeEngine? delegate;
  int calls = 0;

  @override
  Future<NormalizedInput> normalize(InputEvent event) async {
    calls += 1;
    return delegate?.normalize(event) ?? _normalized(event.type.wireName);
  }
}

final class _CountingStateAccumulator implements StateAccumulator {
  _CountingStateAccumulator({this.delegate});

  final StateAccumulator? delegate;
  int calls = 0;

  @override
  Future<ContextMemory> accumulate({
    required NormalizedInput normalized,
    required ContextMemory previous,
    required ProductSnapshot current,
  }) async {
    calls += 1;
    return delegate?.accumulate(
          normalized: normalized,
          previous: previous,
          current: current,
        ) ??
        _memory(normalized.semanticSignals.first);
  }
}

final class _CountingStrategyEngine implements StrategyEngine {
  _CountingStrategyEngine({this.delegate});

  final StrategyEngine? delegate;
  int calls = 0;

  @override
  Future<StrategyDecision> decide({
    required NormalizedInput normalized,
    required ContextMemory memory,
    required ProductSnapshot current,
  }) async {
    calls += 1;
    return delegate?.decide(
          normalized: normalized,
          memory: memory,
          current: current,
        ) ??
        _strategy();
  }
}

final class _CountingUtteranceEngine implements UtteranceEngine {
  _CountingUtteranceEngine({this.delegate});

  final UtteranceEngine? delegate;
  int calls = 0;

  @override
  Future<ActiveUtterance> realize({
    required String ritualRoomId,
    required StrategyDecision strategy,
    required NormalizedInput normalized,
    required ContextMemory memory,
  }) async {
    calls += 1;
    return delegate?.realize(
          ritualRoomId: ritualRoomId,
          strategy: strategy,
          normalized: normalized,
          memory: memory,
        ) ??
        _activeUtterance();
  }
}

NormalizedInput _normalized(String signal) => NormalizedInput(
  semanticSignals: [signal],
  intentEstimate: 'observe',
  momentHypothesis: 'the shared-action moment is available',
  contextFrame: const {
    'actionContext': 'putting shoes on',
    'interactionType': 'caregiver_shared_action_support',
  },
  confidence: 0.8,
  eventSummary: 'compressed $signal evidence',
);

ContextMemory _memory(String signal) => ContextMemory(
  summary: 'interaction-local evidence',
  eventLog: ['compressed $signal evidence'],
  signalWeights: {signal: 1},
  interactionTrend: 'uncertain',
  contextStability: 0.8,
  narrative: 'the current shared routine has mixed evidence',
);

StrategyDecision _strategy() => StrategyDecision(
  primary: PressurePolicy.lowPressure,
  modifiers: const [StrategyModifier.maintain],
  confidence: 0.8,
  rationale: 'current interaction evidence selects low pressure',
  pressureLevel: 20,
  recommendedTone: 'soft',
  interactionHint: 'offer one small shared action',
);

ActiveUtterance _activeUtterance() => const ActiveUtterance(
  displayId: 'shoes_on_ready_v1',
  primary: 'Let’s put your shoes on.',
  zhSupport: '我们来穿鞋吧。',
  actionCue: 'shared action moment',
  audioAssetId: 'rr_shoes_001',
);

final class _ActiveSource implements ActiveUtteranceSource {
  @override
  Future<ActiveUtterance> resolveActiveUtterance({
    required String ritualRoomId,
    required ActiveUtteranceSlot slot,
  }) async => _activeUtterance();
}
