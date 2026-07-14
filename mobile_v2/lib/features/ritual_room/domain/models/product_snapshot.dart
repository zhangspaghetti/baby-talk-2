import 'active_utterance.dart';
import 'context_memory.dart';
import 'normalized_input.dart';
import 'strategy_decision.dart';

final class ProductSnapshotMetadata {
  const ProductSnapshotMetadata({
    required this.lastEventId,
    required this.updatedAt,
  });

  final String? lastEventId;
  final DateTime updatedAt;
}

/// Current product truth for one evolving ritual interaction.
final class ProductSnapshot {
  const ProductSnapshot({
    required this.schemaVersion,
    required this.revision,
    required this.interactionId,
    required this.ritualRoomId,
    required this.anchor,
    required this.normalizedContext,
    required this.memory,
    required this.strategy,
    required this.activeUtterance,
    required this.metadata,
  });

  factory ProductSnapshot.initial({
    required String interactionId,
    required String ritualRoomId,
    required String anchor,
    required NormalizedInput normalizedContext,
    required ContextMemory memory,
    required StrategyDecision strategy,
    required ActiveUtterance activeUtterance,
    required DateTime updatedAt,
  }) => ProductSnapshot(
    schemaVersion: currentSchemaVersion,
    revision: 0,
    interactionId: interactionId,
    ritualRoomId: ritualRoomId,
    anchor: anchor,
    normalizedContext: normalizedContext,
    memory: memory,
    strategy: strategy,
    activeUtterance: activeUtterance,
    metadata: ProductSnapshotMetadata(
      lastEventId: null,
      updatedAt: updatedAt.toUtc(),
    ),
  );

  static const int currentSchemaVersion = 2;

  final int schemaVersion;
  final int revision;
  final String interactionId;
  final String ritualRoomId;
  final String anchor;
  final NormalizedInput normalizedContext;
  final ContextMemory memory;
  final StrategyDecision strategy;
  final ActiveUtterance activeUtterance;
  final ProductSnapshotMetadata metadata;
}
