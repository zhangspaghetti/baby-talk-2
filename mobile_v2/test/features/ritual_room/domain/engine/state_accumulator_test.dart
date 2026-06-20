import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/state_accumulator.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/context_memory.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/normalized_input.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/product_snapshot.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/strategy_decision.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/utterance.dart';

void main() {
  group('DecayStateAccumulator', () {
    test(
      'new shared-action evidence reverses an earlier decreasing trend',
      () async {
        final accumulator = DecayStateAccumulator(decay: 0.65);
        final current = _snapshot();

        final resistant = await accumulator.accumulate(
          normalized: _normalized(
            signals: ['avoidance', 'low_joinability'],
            summary: 'the shared action became harder to enter',
          ),
          previous: _emptyMemory(),
          current: current,
        );
        final engaged = await accumulator.accumulate(
          normalized: _normalized(
            signals: ['shared_action'],
            summary: 'the shared action became available again',
          ),
          previous: resistant,
          current: current,
        );

        expect(resistant.interactionTrend, 'decreasing_joinability');
        expect(engaged.interactionTrend, isNot('decreasing_joinability'));
        expect(engaged.signalWeights['shared_action'], greaterThan(0));
        expect(
          engaged.signalWeights['low_joinability'],
          lessThan(resistant.signalWeights['low_joinability']!),
        );
      },
    );

    test('decays and clamps every interaction-local signal weight', () async {
      final accumulator = DecayStateAccumulator(decay: 0.5);
      final previous = ContextMemory(
        summary: 'earlier evidence',
        eventLog: ['earlier compressed evidence'],
        signalWeights: {'low_joinability': 1, 'shared_action': 0.9},
        interactionTrend: 'uncertain',
        contextStability: 0.4,
        narrative: 'the current interaction contains mixed evidence',
      );

      final updated = await accumulator.accumulate(
        normalized: _normalized(
          signals: ['shared_action'],
          summary: 'one shared action is available',
        ),
        previous: previous,
        current: _snapshot(),
      );

      expect(updated.signalWeights['low_joinability'], closeTo(0.5, 0.001));
      expect(
        updated.signalWeights.values.every(
          (weight) => weight >= 0 && weight <= 1,
        ),
        isTrue,
      );
    });

    test(
      'retains at most eight irreversible compressed event summaries',
      () async {
        final accumulator = DecayStateAccumulator(decay: 0.65);
        var memory = _emptyMemory();

        for (var index = 0; index < 10; index += 1) {
          memory = await accumulator.accumulate(
            normalized: _normalized(
              signals: index.isEven ? ['shared_action'] : ['low_joinability'],
              summary: 'compressed interaction evidence $index',
            ),
            previous: memory,
            current: _snapshot(),
          );
        }

        expect(memory.eventLog, hasLength(8));
        expect(memory.eventLog.first, 'compressed interaction evidence 2');
        expect(
          '${memory.summary} ${memory.narrative} ${memory.eventLog.join(' ')}',
          isNot(matches(RegExp(r'child score|trait|diagnos|correctness'))),
        );
      },
    );
  });
}

NormalizedInput _normalized({
  required List<String> signals,
  required String summary,
}) => NormalizedInput(
  semanticSignals: signals,
  intentEstimate: signals.contains('shared_action') ? 'engage' : 'resist',
  momentHypothesis: signals.contains('shared_action')
      ? 'the shared action is open to enter'
      : 'the shared action is currently hard to enter',
  contextFrame: const {
    'actionContext': 'putting shoes on',
    'interactionType': 'caregiver_shared_action_support',
  },
  confidence: 0.8,
  eventSummary: summary,
);

ContextMemory _emptyMemory() => ContextMemory(
  summary: 'the interaction has just started',
  eventLog: const [],
  signalWeights: const {},
  interactionTrend: 'uncertain',
  contextStability: 0,
  narrative: 'the current interaction is open',
);

ProductSnapshot _snapshot() => ProductSnapshot.initial(
  interactionId: 'interaction-1',
  ritualRoomId: 'shoes_on_room_v1',
  anchor: 'Shoes on.',
  normalizedContext: _normalized(
    signals: ['shared_action'],
    summary: 'the shared shoe routine is available',
  ),
  memory: _emptyMemory(),
  strategy: StrategyDecision(
    primary: PressurePolicy.lowPressure,
    modifiers: const [StrategyModifier.maintain],
    confidence: 0.9,
    rationale: 'begin with one warm shared action',
    pressureLevel: 20,
    recommendedTone: 'soft',
    interactionHint: 'offer one small shared action',
  ),
  utterance: Utterance(
    primary: "Let's put your shoes on.",
    zhHelper: '我们来穿鞋吧。',
    tone: 'soft',
    clarityLevel: 'high',
    contextFit: 'beginning the shared shoe routine',
    alternatives: const [],
  ),
  updatedAt: DateTime.utc(2026, 6, 20),
);
