import '../models/active_utterance.dart';
import '../models/context_memory.dart';
import '../models/normalized_input.dart';
import '../models/strategy_decision.dart';

final class InteractionSeed {
  const InteractionSeed({
    required this.anchor,
    required this.normalizedContext,
    required this.memory,
    required this.strategy,
    required this.activeUtterance,
  });

  final String anchor;
  final NormalizedInput normalizedContext;
  final ContextMemory memory;
  final StrategyDecision strategy;
  final ActiveUtterance activeUtterance;
}

abstract interface class InteractionSeedSource {
  Future<InteractionSeed> load(String ritualRoomId);
}
