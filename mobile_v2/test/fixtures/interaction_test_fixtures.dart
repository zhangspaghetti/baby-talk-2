import 'package:mobile_v2/features/ritual_room/data/dto/interaction_advance_request.dart';
import 'package:mobile_v2/features/ritual_room/data/mappers/interaction_mapper.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/active_utterance.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/context_memory.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/input_event.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/normalized_input.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/product_snapshot.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/strategy_decision.dart';

const interactionId = 'interaction-1';
const ritualRoomId = 'shoes_on_room_v1';

final interactionInputs = <InputEvent>[
  InputEvent.reactionSelection(
    eventId: 'event-reaction',
    occurredAt: DateTime.utc(2026, 6, 20, 9),
    selected: 'running_away',
  ),
  InputEvent.voiceObservation(
    eventId: 'event-voice',
    occurredAt: DateTime.utc(2026, 6, 20, 9, 1),
    transcript: 'attention moved away from the shoes',
  ),
  InputEvent.freeText(
    eventId: 'event-text',
    occurredAt: DateTime.utc(2026, 6, 20, 9, 2),
    text: 'the shared action is difficult to enter',
  ),
  InputEvent.futureSignal(
    eventId: 'event-signal',
    occurredAt: DateTime.utc(2026, 6, 20, 9, 3),
    signal: 'shared_action',
    value: 'available',
  ),
  InputEvent.strategyPreference(
    eventId: 'event-strategy',
    occurredAt: DateTime.utc(2026, 6, 20, 9, 4),
    preference: 'reduce_options',
  ),
];

ProductSnapshot interactionSnapshot({int revision = 0}) => ProductSnapshot(
  schemaVersion: ProductSnapshot.currentSchemaVersion,
  revision: revision,
  interactionId: interactionId,
  ritualRoomId: ritualRoomId,
  anchor: 'Shoes on.',
  normalizedContext: interactionNormalizedInput('shared_action'),
  memory: interactionMemory('shared_action'),
  strategy: interactionStrategy(),
  activeUtterance: interactionActiveUtterance(),
  metadata: ProductSnapshotMetadata(
    lastEventId: revision == 0 ? null : 'event-$revision',
    updatedAt: DateTime.utc(2026, 6, 20, 10, revision),
  ),
);

NormalizedInput interactionNormalizedInput(String signal) => NormalizedInput(
  semanticSignals: [signal],
  intentEstimate: 'observe',
  momentHypothesis: 'the shared-action moment is available',
  contextFrame: const {
    'actionContext': 'putting shoes on',
    'interactionType': 'caregiver_shared_action_support',
  },
  confidence: 0.8,
  eventSummary: 'compressed $signal evidence',
);

ContextMemory interactionMemory(String signal) => ContextMemory(
  summary: 'interaction-local evidence',
  eventLog: ['compressed $signal evidence'],
  signalWeights: {signal: 1},
  interactionTrend: 'uncertain',
  contextStability: 0.8,
  narrative: 'the current shared routine has mixed evidence',
);

StrategyDecision interactionStrategy() => StrategyDecision(
  primary: PressurePolicy.lowPressure,
  modifiers: const [StrategyModifier.maintain],
  confidence: 0.8,
  rationale: 'current interaction evidence selects low pressure',
  pressureLevel: 20,
  recommendedTone: 'soft',
  interactionHint: 'offer one small shared action',
);

ActiveUtterance interactionActiveUtterance({
  String displayId = 'shoes_on_ready_v1',
  String primary = 'Let’s put your shoes on.',
  String zhSupport = '我们来穿鞋吧。',
  String actionCue = 'shared action moment',
  String audioAssetId = 'rr_shoes_001',
  String? contextLabel,
  String? gentleSupport,
}) => ActiveUtterance(
  displayId: displayId,
  primary: primary,
  zhSupport: zhSupport,
  actionCue: actionCue,
  audioAssetId: audioAssetId,
  contextLabel: contextLabel,
  gentleSupport: gentleSupport,
);

InteractionAdvanceRequest interactionRequest({
  int expectedRevision = 0,
  InputEvent? input,
}) => InteractionAdvanceRequest(
  expectedRevision: expectedRevision,
  input: const InteractionMapper().inputFromDomain(
    input ?? interactionInputs.first,
  ),
);
