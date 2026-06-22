import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/utterance_engine.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/active_utterance.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/context_memory.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/normalized_input.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/strategy_decision.dart';
import 'package:mobile_v2/features/ritual_room/domain/repositories/active_utterance_source.dart';

void main() {
  group('RuleBasedUtteranceEngine', () {
    test('low joinability resolves validated not-ready content', () async {
      final source = _FakeActiveUtteranceSource();

      final utterance = await RuleBasedUtteranceEngine(source: source).realize(
        ritualRoomId: 'shoes_on_room_v1',
        strategy: _decision(),
        normalized: _normalized(),
        memory: _memory(),
      );

      expect(source.lastRitualRoomId, 'shoes_on_room_v1');
      expect(source.lastSlot, ActiveUtteranceSlot.notReadyYet);
      expect(utterance.displayId, 'shoes_on_revised_wait_v1');
      expect(utterance.primary, 'You don’t want your shoes on yet.');
      expect(utterance.zhSupport, '你现在还不想穿鞋。');
      expect(utterance.audioAssetId, 'rr_shoes_002');
    });

    test(
      'does not mutate or override the supplied strategy decision',
      () async {
        final decision = _decision();
        final originalModifiers = List<StrategyModifier>.of(decision.modifiers);

        await RuleBasedUtteranceEngine(
          source: _FakeActiveUtteranceSource(),
        ).realize(
          ritualRoomId: 'shoes_on_room_v1',
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
  });
}

final class _FakeActiveUtteranceSource implements ActiveUtteranceSource {
  String? lastRitualRoomId;
  ActiveUtteranceSlot? lastSlot;

  @override
  Future<ActiveUtterance> resolveActiveUtterance({
    required String ritualRoomId,
    required ActiveUtteranceSlot slot,
  }) async {
    lastRitualRoomId = ritualRoomId;
    lastSlot = slot;
    return const ActiveUtterance(
      displayId: 'shoes_on_revised_wait_v1',
      primary: 'You don’t want your shoes on yet.',
      zhSupport: '你现在还不想穿鞋。',
      contextLabel: '还不想穿',
      gentleSupport: '可以先等等。',
      audioAssetId: 'rr_shoes_002',
    );
  }
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
