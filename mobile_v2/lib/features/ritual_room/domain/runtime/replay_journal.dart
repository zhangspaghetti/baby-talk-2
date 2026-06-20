import '../models/context_memory.dart';
import '../models/normalized_input.dart';
import '../models/product_snapshot.dart';
import '../models/strategy_decision.dart';
import '../models/utterance.dart';

final class TransitionRecord {
  TransitionRecord({
    required this.eventId,
    required this.fromRevision,
    required this.toRevision,
    required DateTime occurredAt,
    required this.normalizedInput,
    required this.updatedContextMemory,
    required this.strategyDecision,
    required this.utterance,
  }) : occurredAt = occurredAt.toUtc() {
    if (toRevision != fromRevision + 1) {
      throw ArgumentError('Transition revisions must advance by exactly one');
    }
  }

  final String eventId;
  final int fromRevision;
  final int toRevision;
  final DateTime occurredAt;
  final NormalizedInput normalizedInput;
  final ContextMemory updatedContextMemory;
  final StrategyDecision strategyDecision;
  final Utterance utterance;

  Map<String, Object> toJson() => {
    'eventId': eventId,
    'fromRevision': fromRevision,
    'toRevision': toRevision,
    'occurredAt': occurredAt.toIso8601String(),
    'normalizedInput': _normalizedToJson(normalizedInput),
    'updatedContextMemory': _memoryToJson(updatedContextMemory),
    'strategyDecision': _strategyToJson(strategyDecision),
    'utterance': _utteranceToJson(utterance),
  };
}

final class ReplayJournal {
  ReplayJournal._(List<TransitionRecord> records)
    : records = List.unmodifiable(records);

  factory ReplayJournal.empty() => ReplayJournal._(const []);

  final List<TransitionRecord> records;

  ReplayJournal append(TransitionRecord record) {
    final expectedFromRevision = records.isEmpty ? 0 : records.last.toRevision;
    if (record.fromRevision != expectedFromRevision) {
      throw StateError(
        'Transition starts at ${record.fromRevision}; '
        'expected $expectedFromRevision',
      );
    }
    return ReplayJournal._([...records, record]);
  }

  ProductSnapshot replayFrom(ProductSnapshot initial) {
    if (initial.revision != 0) {
      throw ArgumentError.value(
        initial.revision,
        'initial',
        'Replay must start from revision 0',
      );
    }

    var current = initial;
    for (final record in records) {
      if (record.fromRevision != current.revision) {
        throw StateError('Replay journal revision chain is invalid');
      }
      current = ProductSnapshot(
        schemaVersion: current.schemaVersion,
        revision: record.toRevision,
        interactionId: current.interactionId,
        ritualRoomId: current.ritualRoomId,
        anchor: current.anchor,
        normalizedContext: record.normalizedInput,
        memory: record.updatedContextMemory,
        strategy: record.strategyDecision,
        utterance: record.utterance,
        metadata: ProductSnapshotMetadata(
          lastEventId: record.eventId,
          updatedAt: record.occurredAt,
        ),
      );
    }
    return current;
  }

  List<Map<String, Object>> toJson() =>
      records.map((record) => record.toJson()).toList(growable: false);
}

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

Map<String, Object> _utteranceToJson(Utterance value) => {
  'primary': value.primary,
  'zhHelper': value.zhHelper,
  'tone': value.tone,
  'clarityLevel': value.clarityLevel,
  'contextFit': value.contextFit,
  'alternatives': value.alternatives,
};
