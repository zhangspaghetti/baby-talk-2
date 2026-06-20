import '../models/context_memory.dart';
import '../models/normalized_input.dart';
import '../models/strategy_decision.dart';
import '../models/utterance.dart';

abstract interface class UtteranceEngine {
  Future<Utterance> realize({
    required String anchor,
    required StrategyDecision strategy,
    required NormalizedInput normalized,
    required ContextMemory memory,
  });
}

final class RuleBasedUtteranceEngine implements UtteranceEngine {
  @override
  Future<Utterance> realize({
    required String anchor,
    required StrategyDecision strategy,
    required NormalizedInput normalized,
    required ContextMemory memory,
  }) async {
    final action = _actionFor(anchor);
    final simplified =
        strategy.modifiers.contains(StrategyModifier.simplify) ||
        strategy.modifiers.contains(StrategyModifier.reduceOptions);
    final primary = simplified
        ? "Let's try one $action together."
        : "Let's $action together.";

    return Utterance(
      primary: primary,
      zhHelper: simplified ? '我们先一起试一个小动作。' : '我们一起做吧。',
      tone: strategy.recommendedTone,
      clarityLevel: simplified ? 'high' : 'balanced',
      contextFit: _contextFit(normalized, memory),
      alternatives: const [],
    );
  }

  String _actionFor(String anchor) {
    final normalizedAnchor = anchor.trim().toLowerCase();
    if (normalizedAnchor.contains('shoe')) {
      return 'shoe';
    }
    return 'step';
  }

  String _contextFit(NormalizedInput normalized, ContextMemory memory) {
    if (normalized.semanticSignals.contains('low_joinability') ||
        memory.interactionTrend == 'decreasing_joinability') {
      return 'when the shared routine is currently hard to enter';
    }
    return 'when continuing the shared routine';
  }
}
