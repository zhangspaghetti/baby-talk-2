import 'package:flutter/foundation.dart';
import 'package:mobile/features/care_entry/domain/care_entry_models.dart';

enum OnboardingConversationPhase {
  loading,
  selection,
  resolvingFirstUtterance,
  firstUtterance,
  savingPhraseSaid,
  reactionPrompt,
  savingReaction,
  resolvingNextSupport,
  nextSupportReady,
  completing,
  completed,
  failure,
}

enum OnboardingUtteranceSource { localFallback, remoteGenerated }

@immutable
final class OnboardingUtterance {
  const OnboardingUtterance({
    required this.utteranceId,
    required this.english,
    required this.chinese,
    required this.pronunciation,
    required this.source,
    this.localAudioAsset,
    this.remoteAudioAvailable = false,
  });

  factory OnboardingUtterance.local({
    required String utteranceId,
    required CareFirstUtterance utterance,
  }) => OnboardingUtterance(
    utteranceId: utteranceId,
    english: utterance.english,
    chinese: utterance.chinese,
    pronunciation: utterance.pronunciation,
    source: OnboardingUtteranceSource.localFallback,
    localAudioAsset: utterance.audioAsset,
  );

  final String utteranceId;
  final String english;
  final String chinese;
  final String pronunciation;
  final OnboardingUtteranceSource source;
  final String? localAudioAsset;
  final bool remoteAudioAvailable;
}

abstract interface class GuestOnboardingAudioPlayer {
  Future<void> play({
    required String conversationId,
    required String utteranceId,
  });

  Future<void> stop();

  Future<void> dispose();
}

@immutable
final class GuestOnboardingConversation {
  const GuestOnboardingConversation({
    required this.conversationId,
    required this.expiresAt,
    required this.utterance,
  });

  final String conversationId;
  final DateTime expiresAt;
  final OnboardingUtterance utterance;
}

@immutable
final class CreateGuestOnboardingConversation {
  const CreateGuestOnboardingConversation({
    required this.installationId,
    required this.localEventId,
    required this.careEntryId,
    required this.registryRevision,
    required this.generationScene,
    required this.locale,
    required this.timeBand,
  });

  final String installationId;
  final String localEventId;
  final CareEntryId careEntryId;
  final String registryRevision;
  final GenerationSceneRef generationScene;
  final String locale;
  final String timeBand;
}

@immutable
final class NextGuestOnboardingTurn {
  const NextGuestOnboardingTurn({
    required this.conversationId,
    required this.localEventId,
    required this.previousUtteranceId,
    required this.generationScene,
    this.reaction,
    this.reactionText,
  });

  final String conversationId;
  final String localEventId;
  final String previousUtteranceId;
  final GenerationSceneRef generationScene;
  final CareReaction? reaction;
  final String? reactionText;
}

abstract interface class GuestOnboardingConversationGateway {
  Future<GuestOnboardingConversation> create(
    CreateGuestOnboardingConversation request,
  );

  Future<GuestOnboardingConversation> nextSupport(
    NextGuestOnboardingTurn request,
  );
}

typedef OnboardingInstallationIdLoader = Future<String> Function();

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
    this.conversationRequestEventId,
    this.phraseSaidEventId,
    this.phraseSaidAt,
    this.selectedReaction,
    this.nextSupportId,
    this.nextSupportEnglish,
    this.nextSupportChinese,
    this.nextSupportSource,
    this.completionId,
    this.gardenTraceId,
    this.completedAt,
  });

  final int schemaVersion;
  final String registryRevision;
  final OnboardingCheckpointPhase phase;
  final CareEntryId selectedEntryId;
  final CareEntryId? activeEntryId;
  final String? conversationRequestEventId;
  final String? phraseSaidEventId;
  final DateTime? phraseSaidAt;
  final CareReaction? selectedReaction;
  final CareSupportId? nextSupportId;
  final String? nextSupportEnglish;
  final String? nextSupportChinese;
  final OnboardingUtteranceSource? nextSupportSource;
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
    Object? conversationRequestEventId = _unset,
    Object? phraseSaidEventId = _unset,
    Object? phraseSaidAt = _unset,
    Object? selectedReaction = _unset,
    Object? nextSupportId = _unset,
    Object? nextSupportEnglish = _unset,
    Object? nextSupportChinese = _unset,
    Object? nextSupportSource = _unset,
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
      conversationRequestEventId: identical(conversationRequestEventId, _unset)
          ? this.conversationRequestEventId
          : conversationRequestEventId as String?,
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
      nextSupportEnglish: identical(nextSupportEnglish, _unset)
          ? this.nextSupportEnglish
          : nextSupportEnglish as String?,
      nextSupportChinese: identical(nextSupportChinese, _unset)
          ? this.nextSupportChinese
          : nextSupportChinese as String?,
      nextSupportSource: identical(nextSupportSource, _unset)
          ? this.nextSupportSource
          : nextSupportSource as OnboardingUtteranceSource?,
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

  Future<OnboardingConversationSnapshot?> saveNextSupport(
    OnboardingConversationSnapshot checkpoint, {
    required bool Function() commitIfCurrent,
  });

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
