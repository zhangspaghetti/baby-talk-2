import '../models/context_memory.dart';
import '../models/normalized_input.dart';
import '../models/strategy_decision.dart';
import '../models/utterance.dart';

final class InteractionSeed {
  const InteractionSeed({
    required this.anchor,
    required this.normalizedContext,
    required this.memory,
    required this.strategy,
    required this.utterance,
  });

  final String anchor;
  final NormalizedInput normalizedContext;
  final ContextMemory memory;
  final StrategyDecision strategy;
  final Utterance utterance;
}

abstract interface class InteractionSeedSource {
  Future<InteractionSeed> load(String ritualRoomId);
}
