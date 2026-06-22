import '../models/active_utterance.dart';
import '../models/context_memory.dart';
import '../models/normalized_input.dart';
import '../models/product_snapshot.dart';
import '../models/strategy_decision.dart';
import 'consistency_state.dart';
import 'replay_journal.dart';

final class InteractionRuntimeState {
  const InteractionRuntimeState({
    required this.initialSnapshot,
    required this.snapshot,
    required this.consistency,
    required this.journal,
  });

  factory InteractionRuntimeState.initial(ProductSnapshot snapshot) =>
      InteractionRuntimeState(
        initialSnapshot: snapshot,
        snapshot: snapshot,
        consistency: ConsistencyState.empty(),
        journal: ReplayJournal.empty(),
      );

  final ProductSnapshot initialSnapshot;
  final ProductSnapshot snapshot;
  final ConsistencyState consistency;
  final ReplayJournal journal;

  ProductSnapshot get currentSnapshot => snapshot;
  ConsistencyState get consistencyState => consistency;
  ReplayJournal get replayJournal => journal;

  InteractionRuntimeState commit({
    required ProductSnapshot currentSnapshot,
    required ConsistencyState consistencyState,
    required ReplayJournal replayJournal,
  }) {
    if (currentSnapshot.interactionId != initialSnapshot.interactionId) {
      throw ArgumentError('Runtime state cannot change interaction identity');
    }
    return InteractionRuntimeState(
      initialSnapshot: initialSnapshot,
      snapshot: currentSnapshot,
      consistency: consistencyState,
      journal: replayJournal,
    );
  }

  Map<String, Object> toJson() => {
    'initialSnapshot': _snapshotToJson(initialSnapshot),
    'currentSnapshot': _snapshotToJson(snapshot),
    'consistencyState': consistency.toJson(),
    'replayJournal': journal.toJson(),
  };
}

Map<String, Object?> _snapshotToJson(ProductSnapshot value) => {
  'schemaVersion': value.schemaVersion,
  'revision': value.revision,
  'interactionId': value.interactionId,
  'ritualRoomId': value.ritualRoomId,
  'anchor': value.anchor,
  'normalizedContext': _normalizedToJson(value.normalizedContext),
  'memory': _memoryToJson(value.memory),
  'strategy': _strategyToJson(value.strategy),
  'activeUtterance': _activeUtteranceToJson(value.activeUtterance),
  'metadata': {
    'lastEventId': value.metadata.lastEventId,
    'updatedAt': value.metadata.updatedAt.toUtc().toIso8601String(),
  },
};

Map<String, Object> _normalizedToJson(NormalizedInput value) => {
  'semanticSignals': value.semanticSignals,
  'intentEstimate': value.intentEstimate,
  'momentHypothesis': value.momentHypothesis,
  'contextFrame': value.contextFrame,
  'confidence': value.confidence,
  'eventSummary': value.eventSummary,
};

Map<String, Object> _memoryToJson(ContextMemory value) => {
  'summary': value.summary,
  'eventLog': value.eventLog,
  'signalWeights': value.signalWeights,
  'interactionTrend': value.interactionTrend,
  'contextStability': value.contextStability,
  'narrative': value.narrative,
};

Map<String, Object> _strategyToJson(StrategyDecision value) => {
  'primary': value.primary.wireName,
  'modifiers': value.modifiers.map((modifier) => modifier.wireName).toList(),
  'confidence': value.confidence,
  'rationale': value.rationale,
  'pressureLevel': value.pressureLevel,
  'recommendedTone': value.recommendedTone,
  'interactionHint': value.interactionHint,
};

Map<String, Object?> _activeUtteranceToJson(ActiveUtterance value) => {
  'displayId': value.displayId,
  'primary': value.primary,
  'zhSupport': value.zhSupport,
  'audioAssetId': value.audioAssetId,
  'contextLabel': value.contextLabel,
  'gentleSupport': value.gentleSupport,
};
