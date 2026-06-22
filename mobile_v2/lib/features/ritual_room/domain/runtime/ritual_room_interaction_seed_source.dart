import '../models/context_memory.dart';
import '../models/normalized_input.dart';
import '../models/strategy_decision.dart';
import '../models/active_utterance.dart';
import '../repositories/ritual_room_repository.dart';
import 'interaction_seed_source.dart';

/// Adapts stable room content into revision-zero interaction product truth.
final class RitualRoomInteractionSeedSource implements InteractionSeedSource {
  const RitualRoomInteractionSeedSource({
    required RitualRoomRepository repository,
  }) : _repository = repository;

  final RitualRoomRepository _repository;

  @override
  Future<InteractionSeed> load(String ritualRoomId) async {
    final room = await _repository.loadRoom(ritualRoomId);
    final activeUtterance = await _repository.resolveActiveUtterance(
      ritualRoomId: ritualRoomId,
      slot: ActiveUtteranceSlot.ready,
    );
    final initialContext = NormalizedInput(
      semanticSignals: const ['shared_action'],
      intentEstimate: 'observe',
      momentHypothesis: room.governanceEvidence.joinabilityHypothesis,
      contextFrame: {
        'actionContext': room.routineAnchor,
        'interactionType': 'caregiver_shared_action_support',
      },
      confidence: 1,
      eventSummary: 'stable ritual room bootstrap',
    );

    return InteractionSeed(
      anchor: room.anchorPhrase,
      normalizedContext: initialContext,
      memory: ContextMemory(
        summary: 'no interaction-local evidence yet',
        eventLog: [],
        signalWeights: {},
        interactionTrend: 'uncertain',
        contextStability: 0,
        narrative:
            'The shared routine is ready for current-interaction evidence.',
      ),
      strategy: StrategyDecision(
        primary: PressurePolicy.lowPressure,
        modifiers: [StrategyModifier.maintain],
        confidence: 1,
        rationale: 'stable room support starts without response pressure',
        pressureLevel: 20,
        recommendedTone: 'soft',
        interactionHint: 'offer one warm shared action',
      ),
      activeUtterance: activeUtterance,
    );
  }
}
