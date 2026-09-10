import 'package:freezed_annotation/freezed_annotation.dart';

part '../../../../generated/features/practice/domain/models/interaction_event_payload.freezed.dart';

enum BabyReactionType { cooperating, hesitant, resisting, noResponse, other }

extension BabyReactionTypeWire on BabyReactionType {
  String get wireValue {
    switch (this) {
      case BabyReactionType.cooperating:
        return 'cooperating';
      case BabyReactionType.hesitant:
        return 'hesitant';
      case BabyReactionType.resisting:
        return 'resisting';
      case BabyReactionType.noResponse:
        return 'no_response';
      case BabyReactionType.other:
        return 'other';
    }
  }
}

BabyReactionType parseBabyReactionType(String value) {
  switch (value.trim()) {
    case 'cooperating':
      return BabyReactionType.cooperating;
    case 'hesitant':
      return BabyReactionType.hesitant;
    case 'resisting':
      return BabyReactionType.resisting;
    case 'no_response':
      return BabyReactionType.noResponse;
    case 'other':
      return BabyReactionType.other;
    default:
      throw FormatException('未知 reaction type: $value');
  }
}

enum InteractionSyncState { pending, synced, failed }

extension InteractionSyncStateWire on InteractionSyncState {
  String get wireValue {
    switch (this) {
      case InteractionSyncState.pending:
        return 'pending';
      case InteractionSyncState.synced:
        return 'synced';
      case InteractionSyncState.failed:
        return 'failed';
    }
  }
}

InteractionSyncState parseInteractionSyncState(String value) {
  switch (value.trim()) {
    case 'pending':
      return InteractionSyncState.pending;
    case 'synced':
      return InteractionSyncState.synced;
    case 'failed':
      return InteractionSyncState.failed;
    default:
      throw FormatException('未知 syncState: $value');
  }
}

@freezed
class InteractionEventUploadRecord with _$InteractionEventUploadRecord {
  const InteractionEventUploadRecord._();

  const factory InteractionEventUploadRecord({
    required String eventKey,
    required String localEventId,
    required String installationId,
    required String spaceId,
    required String activityId,
    required String phraseId,
    required BabyReactionType reactionType,
    required DateTime clientTimestamp,
  }) = _InteractionEventUploadRecord;

  factory InteractionEventUploadRecord.fromPayload(
    InteractionEventPayload payload,
  ) {
    return InteractionEventUploadRecord(
      eventKey: payload.eventKey,
      localEventId: payload.localEventId,
      installationId: payload.installationId,
      spaceId: payload.spaceId,
      activityId: payload.activityId,
      phraseId: payload.phraseId,
      reactionType: payload.reactionType,
      clientTimestamp: payload.clientTimestamp,
    );
  }

  Map<String, Object?> toJsonMap() {
    return {
      'eventKey': eventKey,
      'localEventId': localEventId,
      'installationId': installationId,
      'spaceId': spaceId,
      'activityId': activityId,
      'phraseId': phraseId,
      'reactionType': reactionType.wireValue,
      'clientTimestamp': clientTimestamp.toIso8601String(),
    };
  }
}

@freezed
class InteractionEventPayload with _$InteractionEventPayload {
  InteractionEventPayload._();

  factory InteractionEventPayload({
    required String localEventId,
    required String installationId,
    required String spaceId,
    required String activityId,
    required String phraseId,
    required BabyReactionType reactionType,
    required DateTime clientTimestamp,
    String? generatedContentId,
    String? utteranceId,
    @Default(InteractionSyncState.pending) InteractionSyncState syncState,
    String? lastSyncPhase,
    String? lastSyncError,
    DateTime? lastSyncAt,
  }) = _InteractionEventPayload;

  factory InteractionEventPayload.validated({
    required String localEventId,
    required String installationId,
    required String spaceId,
    required String activityId,
    required String phraseId,
    required BabyReactionType reactionType,
    required DateTime clientTimestamp,
    String? generatedContentId,
    String? utteranceId,
    InteractionSyncState syncState = InteractionSyncState.pending,
    String? lastSyncPhase,
    String? lastSyncError,
    DateTime? lastSyncAt,
  }) {
    if (localEventId.trim().isEmpty) {
      throw const FormatException('localEventId 不能为空。');
    }
    if (installationId.trim().isEmpty) {
      throw const FormatException('installationId 不能为空。');
    }
    if (spaceId.trim().isEmpty) {
      throw const FormatException('spaceId 不能为空。');
    }
    if (activityId.trim().isEmpty) {
      throw const FormatException('activityId 不能为空。');
    }
    if (phraseId.trim().isEmpty) {
      throw const FormatException('phraseId 不能为空。');
    }
    final normalizedGeneratedContentId = _trimToNull(generatedContentId);
    final normalizedUtteranceId = _trimToNull(utteranceId);
    if ((normalizedGeneratedContentId == null) !=
        (normalizedUtteranceId == null)) {
      throw const FormatException('generatedContentId 与 utteranceId 必须同时存在。');
    }
    if (lastSyncPhase != null && lastSyncPhase.trim().isEmpty) {
      throw const FormatException('lastSyncPhase 不能为空字符串。');
    }
    if (lastSyncError != null && lastSyncError.trim().isEmpty) {
      throw const FormatException('lastSyncError 不能为空字符串。');
    }
    return InteractionEventPayload(
      localEventId: localEventId,
      installationId: installationId,
      spaceId: spaceId,
      activityId: activityId,
      phraseId: phraseId,
      reactionType: reactionType,
      clientTimestamp: clientTimestamp.toUtc(),
      generatedContentId: normalizedGeneratedContentId,
      utteranceId: normalizedUtteranceId,
      syncState: syncState,
      lastSyncPhase: lastSyncPhase,
      lastSyncError: lastSyncError,
      lastSyncAt: lastSyncAt?.toUtc(),
    );
  }

  factory InteractionEventPayload.fromWire({
    required String localEventId,
    required String installationId,
    required String spaceId,
    required String activityId,
    required String phraseId,
    required String reactionType,
    required DateTime clientTimestamp,
    String? generatedContentId,
    String? utteranceId,
    String? eventKey,
    String syncState = 'pending',
    String? lastSyncPhase,
    String? lastSyncError,
    DateTime? lastSyncAt,
  }) {
    final payload = InteractionEventPayload.validated(
      localEventId: localEventId,
      installationId: installationId,
      spaceId: spaceId,
      activityId: activityId,
      phraseId: phraseId,
      reactionType: parseBabyReactionType(reactionType),
      clientTimestamp: clientTimestamp,
      generatedContentId: generatedContentId,
      utteranceId: utteranceId,
      syncState: parseInteractionSyncState(syncState),
      lastSyncPhase: lastSyncPhase,
      lastSyncError: lastSyncError,
      lastSyncAt: lastSyncAt,
    );
    if (eventKey != null && eventKey.trim() != payload.eventKey) {
      throw FormatException(
        'eventKey 与 installationId/localEventId 不一致：$eventKey != ${payload.eventKey}',
      );
    }
    return payload;
  }

  String get eventKey => '$installationId:$localEventId';

  InteractionEventUploadRecord get uploadRecord =>
      InteractionEventUploadRecord.fromPayload(this);

  InteractionEventPayload copyWithSyncMetadata({
    InteractionSyncState? syncState,
    String? lastSyncPhase,
    String? lastSyncError,
    bool clearLastSyncError = false,
    DateTime? lastSyncAt,
    bool clearLastSyncAt = false,
  }) {
    return InteractionEventPayload(
      localEventId: localEventId,
      installationId: installationId,
      spaceId: spaceId,
      activityId: activityId,
      phraseId: phraseId,
      reactionType: reactionType,
      clientTimestamp: clientTimestamp,
      generatedContentId: generatedContentId,
      utteranceId: utteranceId,
      syncState: syncState ?? this.syncState,
      lastSyncPhase: lastSyncPhase ?? this.lastSyncPhase,
      lastSyncError: clearLastSyncError
          ? null
          : (lastSyncError ?? this.lastSyncError),
      lastSyncAt: clearLastSyncAt ? null : (lastSyncAt ?? this.lastSyncAt),
    );
  }

  Map<String, Object?> toFactMap() {
    return {
      'eventKey': eventKey,
      'localEventId': localEventId,
      'installationId': installationId,
      'spaceId': spaceId,
      'activityId': activityId,
      'phraseId': phraseId,
      'reactionType': reactionType.wireValue,
      'clientTimestamp': clientTimestamp.toIso8601String(),
      'generatedContentId': generatedContentId,
      'utteranceId': utteranceId,
    };
  }

  Map<String, Object?> toSyncMetadataMap() {
    return {
      'syncState': syncState.wireValue,
      'lastSyncPhase': lastSyncPhase,
      'lastSyncError': lastSyncError,
      'lastSyncAt': lastSyncAt?.toIso8601String(),
    };
  }

  static String? _trimToNull(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
