import '../models/active_utterance.dart';
import '../models/context_memory.dart';
import '../models/normalized_input.dart';
import '../models/strategy_decision.dart';
import '../repositories/active_utterance_source.dart';

abstract interface class UtteranceEngine {
  Future<ActiveUtterance> realize({
    required String ritualRoomId,
    required StrategyDecision strategy,
    required NormalizedInput normalized,
    required ContextMemory memory,
  });
}

final class RuleBasedUtteranceEngine implements UtteranceEngine {
  const RuleBasedUtteranceEngine({required ActiveUtteranceSource source})
    : _source = source;

  final ActiveUtteranceSource _source;

  @override
  Future<ActiveUtterance> realize({
    required String ritualRoomId,
    required StrategyDecision strategy,
    required NormalizedInput normalized,
    required ContextMemory memory,
  }) {
    final signals = normalized.semanticSignals;
    final slot =
        signals.contains('low_joinability') || signals.contains('avoidance')
        ? ActiveUtteranceSlot.notReadyYet
        : ActiveUtteranceSlot.ready;
    return _source.resolveActiveUtterance(
      ritualRoomId: ritualRoomId,
      slot: slot,
    );
  }
}
