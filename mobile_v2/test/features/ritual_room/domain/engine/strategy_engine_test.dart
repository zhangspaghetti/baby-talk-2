import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/strategy_engine.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/context_memory.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/normalized_input.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/product_snapshot.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/strategy_decision.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/active_utterance.dart';

void main() {
  group('RuleBasedStrategyEngine', () {
    test(
      'selects low-pressure multi-axis policy for low joinability',
      () async {
        final decision = await RuleBasedStrategyEngine().decide(
          normalized: _normalized(['avoidance', 'low_joinability']),
          memory: _memory({
            'avoidance': 0.72,
            'low_joinability': 0.65,
            'shared_action': 0.15,
          }),
          current: _snapshot(),
        );

        expect(decision.primary, PressurePolicy.lowPressure);
        expect(
          decision.modifiers,
          containsAll([
            StrategyModifier.simplify,
            StrategyModifier.reduceOptions,
          ]),
        );
        expect(decision.pressureLevel, lessThanOrEqualTo(30));
        expect(decision.recommendedTone, 'soft');
      },
    );

    test(
      'treats strategy preference as evidence, not direct authority',
      () async {
        final decision = await RuleBasedStrategyEngine().decide(
          normalized: _normalized([
            'shared_action',
            'strategy_preference_reduce_options',
          ]),
          memory: _memory({'shared_action': 0.8}),
          current: _snapshot(),
        );

        expect(decision.modifiers, contains(StrategyModifier.reduceOptions));
        expect(decision.primary, isA<PressurePolicy>());
        expect(decision.rationale, isNotEmpty);
        expect(decision.interactionHint, isNotEmpty);
      },
    );

    test('describes language policy without child evaluation', () async {
      final decision = await RuleBasedStrategyEngine().decide(
        normalized: _normalized(['shared_action']),
        memory: _memory({'shared_action': 0.9}),
        current: _snapshot(),
      );
      final policyText = [
        decision.rationale,
        decision.recommendedTone,
        decision.interactionHint,
      ].join(' ').toLowerCase();

      expect(
        policyText,
        isNot(matches(RegExp(r'lesson|score|correct|diagnos|ability|trait'))),
      );
    });
  });
}

NormalizedInput _normalized(List<String> signals) => NormalizedInput(
  semanticSignals: signals,
  intentEstimate: signals.contains('low_joinability') ? 'resist' : 'engage',
  momentHypothesis: signals.contains('low_joinability')
      ? 'the shared action is currently hard to enter'
      : 'the shared action is open to enter',
  contextFrame: const {
    'actionContext': 'putting shoes on',
    'interactionType': 'caregiver_shared_action_support',
  },
  confidence: 0.8,
  eventSummary: 'current interaction evidence',
);

ContextMemory _memory(Map<String, double> weights) => ContextMemory(
  summary: 'current interaction evidence',
  eventLog: const ['compressed evidence'],
  signalWeights: weights,
  interactionTrend: weights.containsKey('low_joinability')
      ? 'decreasing_joinability'
      : 'increasing_joinability',
  contextStability: 0.7,
  narrative: 'the current shared action changed',
);

ProductSnapshot _snapshot() => ProductSnapshot.initial(
  interactionId: 'interaction-1',
  ritualRoomId: 'shoes_on_room_v1',
  anchor: 'Shoes on.',
  normalizedContext: _normalized(['shared_action']),
  memory: _memory({'shared_action': 1}),
  strategy: StrategyDecision(
    primary: PressurePolicy.lowPressure,
    modifiers: const [StrategyModifier.maintain],
    confidence: 0.9,
    rationale: 'begin with one warm shared action',
    pressureLevel: 20,
    recommendedTone: 'soft',
    interactionHint: 'offer one small shared action',
  ),
  activeUtterance: const ActiveUtterance(
    displayId: 'shoes_on_ready_v1',
    primary: 'Existing caregiver line.',
    zhSupport: '现有照护者话术。',
    actionCue: 'shared action moment',
    audioAssetId: 'rr_shoes_001',
  ),
  updatedAt: DateTime.utc(2026, 6, 20),
);
