import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/utterance_engine.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/context_memory.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/normalized_input.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/strategy_decision.dart';

void main() {
  group('RuleBasedUtteranceEngine', () {
    test(
      'realizes a preselected policy as exactly one speakable line',
      () async {
        final decision = _decision();

        final utterance = await RuleBasedUtteranceEngine().realize(
          anchor: 'Shoes on.',
          strategy: decision,
          normalized: _normalized(),
          memory: _memory(),
        );

        expect(utterance.primary, isNotEmpty);
        expect(
          utterance.primary
              .trim()
              .split(RegExp(r'[.!?]+'))
              .where((part) => part.trim().isNotEmpty),
          hasLength(1),
        );
        expect(utterance.alternatives, isEmpty);
        expect(utterance.primary.toLowerCase(), contains('shoe'));
        expect(utterance.tone, decision.recommendedTone);
      },
    );

    test(
      'does not mutate or override the supplied strategy decision',
      () async {
        final decision = _decision();
        final originalModifiers = List<StrategyModifier>.of(decision.modifiers);

        await RuleBasedUtteranceEngine().realize(
          anchor: 'Shoes on.',
          strategy: decision,
          normalized: _normalized(),
          memory: _memory(),
        );

        expect(decision.primary, PressurePolicy.lowPressure);
        expect(decision.modifiers, originalModifiers);
        expect(decision.pressureLevel, 25);
        expect(decision.interactionHint, 'offer one small shared action');
      },
    );

    test(
      'keeps the stable ritual anchor and avoids lesson semantics',
      () async {
        final utterance = await RuleBasedUtteranceEngine().realize(
          anchor: 'Shoes on.',
          strategy: _decision(),
          normalized: _normalized(),
          memory: _memory(),
        );
        final language = [
          utterance.primary,
          utterance.zhHelper,
          utterance.contextFit,
        ].join(' ').toLowerCase();

        expect(utterance.primary.toLowerCase(), contains('shoe'));
        expect(
          language,
          isNot(matches(RegExp(r'lesson|score|correct|diagnos|ability|trait'))),
        );
      },
    );
  });
}

StrategyDecision _decision() => StrategyDecision(
  primary: PressurePolicy.lowPressure,
  modifiers: const [StrategyModifier.simplify, StrategyModifier.reduceOptions],
  confidence: 0.82,
  rationale: 'current signals indicate low joinability',
  pressureLevel: 25,
  recommendedTone: 'soft',
  interactionHint: 'offer one small shared action',
);

NormalizedInput _normalized() => NormalizedInput(
  semanticSignals: const ['avoidance', 'low_joinability'],
  intentEstimate: 'resist',
  momentHypothesis: 'the shared action is currently hard to enter',
  contextFrame: const {
    'actionContext': 'putting shoes on',
    'interactionType': 'caregiver_shared_action_support',
  },
  confidence: 0.78,
  eventSummary: 'the shared shoe routine is currently difficult to enter',
);

ContextMemory _memory() => ContextMemory(
  summary: 'the shared shoe routine is currently difficult to enter',
  eventLog: const ['the shared action did not begin'],
  signalWeights: const {
    'avoidance': 0.72,
    'low_joinability': 0.65,
    'shared_action': 0.15,
  },
  interactionTrend: 'decreasing_joinability',
  contextStability: 0.68,
  narrative: 'the routine became harder to join',
);
