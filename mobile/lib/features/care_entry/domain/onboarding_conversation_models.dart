import 'package:flutter/foundation.dart';
import 'package:mobile/features/care_entry/domain/care_entry_models.dart';

enum OnboardingConversationPhase {
  loading,
  selection,
  firstUtterance,
  savingPhraseSaid,
  reactionPrompt,
  nextSupportReady,
  completing,
  completed,
  failure,
}

enum OnboardingCheckpointPhase {
  selection,
  firstUtterance,
  reactionPrompt,
  nextSupportReady,
  completed,
}

@immutable
final class OnboardingGardenTrace {
  const OnboardingGardenTrace({
    required this.traceId,
    required this.careEntryId,
    required this.occurredAt,
    required this.completedAt,
  });

  final String traceId;
  final CareEntryId careEntryId;
  final DateTime occurredAt;
  final DateTime completedAt;
}

@immutable
final class OnboardingConversationSnapshot {
  const OnboardingConversationSnapshot({
    this.schemaVersion = 2,
    required this.registryRevision,
    required this.phase,
    required this.selectedEntryId,
    this.activeEntryId,
    this.phraseSaidEventId,
    this.phraseSaidAt,
    this.selectedReaction,
    this.nextSupportId,
    this.completionId,
    this.gardenTraceId,
    this.completedAt,
  });

  final int schemaVersion;
  final String registryRevision;
  final OnboardingCheckpointPhase phase;
  final CareEntryId selectedEntryId;
  final CareEntryId? activeEntryId;
  final String? phraseSaidEventId;
  final DateTime? phraseSaidAt;
  final CareReaction? selectedReaction;
  final CareSupportId? nextSupportId;
  final String? completionId;
  final String? gardenTraceId;
  final DateTime? completedAt;

  OnboardingGardenTrace? get gardenTrace {
    final traceId = gardenTraceId;
    final entryId = activeEntryId;
    final traceOccurredAt = phraseSaidAt;
    final traceCompletedAt = completedAt;
    if (traceId == null ||
        entryId == null ||
        traceOccurredAt == null ||
        traceCompletedAt == null) {
      return null;
    }
    return OnboardingGardenTrace(
      traceId: traceId,
      careEntryId: entryId,
      occurredAt: traceOccurredAt,
      completedAt: traceCompletedAt,
    );
  }

  OnboardingConversationSnapshot copyWith({
    OnboardingCheckpointPhase? phase,
    CareEntryId? selectedEntryId,
    Object? activeEntryId = _unset,
    Object? phraseSaidEventId = _unset,
    Object? phraseSaidAt = _unset,
    Object? selectedReaction = _unset,
    Object? nextSupportId = _unset,
    Object? completionId = _unset,
    Object? gardenTraceId = _unset,
    Object? completedAt = _unset,
  }) {
    return OnboardingConversationSnapshot(
      schemaVersion: schemaVersion,
      registryRevision: registryRevision,
      phase: phase ?? this.phase,
      selectedEntryId: selectedEntryId ?? this.selectedEntryId,
      activeEntryId: identical(activeEntryId, _unset)
          ? this.activeEntryId
          : activeEntryId as CareEntryId?,
      phraseSaidEventId: identical(phraseSaidEventId, _unset)
          ? this.phraseSaidEventId
          : phraseSaidEventId as String?,
      phraseSaidAt: identical(phraseSaidAt, _unset)
          ? this.phraseSaidAt
          : phraseSaidAt as DateTime?,
      selectedReaction: identical(selectedReaction, _unset)
          ? this.selectedReaction
          : selectedReaction as CareReaction?,
      nextSupportId: identical(nextSupportId, _unset)
          ? this.nextSupportId
          : nextSupportId as CareSupportId?,
      completionId: identical(completionId, _unset)
          ? this.completionId
          : completionId as String?,
      gardenTraceId: identical(gardenTraceId, _unset)
          ? this.gardenTraceId
          : gardenTraceId as String?,
      completedAt: identical(completedAt, _unset)
          ? this.completedAt
          : completedAt as DateTime?,
    );
  }
}

abstract interface class OnboardingConversationRepository {
  Future<OnboardingConversationSnapshot?> read();

  Future<OnboardingConversationSnapshot> save(
    OnboardingConversationSnapshot checkpoint,
  );

  Future<OnboardingConversationSnapshot> recordPhraseSaid({
    required OnboardingConversationSnapshot checkpoint,
    required String eventId,
    required DateTime occurredAt,
  });

  Future<OnboardingConversationSnapshot> complete({
    required OnboardingConversationSnapshot checkpoint,
    required String completionId,
    required DateTime completedAt,
  });
}

abstract interface class OnboardingDelayScheduler {
  OnboardingScheduledTask schedule(Duration delay, void Function() action);
}

abstract interface class OnboardingScheduledTask {
  void cancel();
}

const Object _unset = Object();
