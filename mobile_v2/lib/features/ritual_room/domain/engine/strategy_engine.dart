import '../models/context_memory.dart';
import '../models/normalized_input.dart';
import '../models/product_snapshot.dart';
import '../models/strategy_decision.dart';

abstract interface class StrategyEngine {
  Future<StrategyDecision> decide({
    required NormalizedInput normalized,
    required ContextMemory memory,
    required ProductSnapshot current,
  });
}

final class RuleBasedStrategyEngine implements StrategyEngine {
  @override
  Future<StrategyDecision> decide({
    required NormalizedInput normalized,
    required ContextMemory memory,
    required ProductSnapshot current,
  }) async {
    final lowJoinability = _hasLowJoinability(normalized, memory);
    final prefersFewerOptions = normalized.semanticSignals.contains(
      'strategy_preference_reduce_options',
    );

    if (lowJoinability) {
      return StrategyDecision(
        primary: PressurePolicy.lowPressure,
        modifiers: const [
          StrategyModifier.simplify,
          StrategyModifier.reduceOptions,
        ],
        confidence: 0.82,
        rationale: 'current signals indicate low joinability',
        pressureLevel: 25,
        recommendedTone: 'soft',
        interactionHint:
            'offer one small shared action without requiring a response',
      );
    }

    final modifiers = <StrategyModifier>[
      StrategyModifier.continueInteraction,
      StrategyModifier.maintain,
      if (prefersFewerOptions) StrategyModifier.reduceOptions,
    ];
    return StrategyDecision(
      primary: PressurePolicy.lowPressure,
      modifiers: modifiers,
      confidence: 0.8,
      rationale: 'current signals keep the ${current.anchor} routine open',
      pressureLevel: 20,
      recommendedTone: 'soft',
      interactionHint: prefersFewerOptions
          ? 'offer one clear shared action'
          : 'continue with one warm shared action',
    );
  }

  bool _hasLowJoinability(NormalizedInput normalized, ContextMemory memory) {
    if (normalized.semanticSignals.contains('low_joinability')) {
      return true;
    }
    return (memory.signalWeights['low_joinability'] ?? 0) >
        (memory.signalWeights['shared_action'] ?? 0);
  }
}
