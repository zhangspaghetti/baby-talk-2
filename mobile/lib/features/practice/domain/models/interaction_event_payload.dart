enum BabyReactionType { calm, engaged, imitated, needsBreak }

extension BabyReactionTypeWire on BabyReactionType {
  String get wireValue {
    switch (this) {
      case BabyReactionType.calm:
        return 'calm';
      case BabyReactionType.engaged:
        return 'engaged';
      case BabyReactionType.imitated:
        return 'imitated';
      case BabyReactionType.needsBreak:
        return 'needs_break';
    }
  }
}

BabyReactionType parseBabyReactionType(String value) {
  switch (value.trim()) {
    case 'calm':
      return BabyReactionType.calm;
    case 'engaged':
      return BabyReactionType.engaged;
    case 'imitated':
      return BabyReactionType.imitated;
    case 'needs_break':
      return BabyReactionType.needsBreak;
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

class InteractionEventUploadRecord {
  const InteractionEventUploadRecord({
    required this.eventKey,
    required this.localEventId,
    required this.installationId,
    required this.spaceId,
    required this.activityId,
    required this.phraseId,
    required this.reactionType,
    required this.clientTimestamp,
  });

  final String eventKey;
  final String localEventId;
  final String installationId;
  final String spaceId;
  final String activityId;
  final String phraseId;
  final BabyReactionType reactionType;
  final DateTime clientTimestamp;

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

class InteractionEventPayload {
  InteractionEventPayload({
    required this.localEventId,
    required this.installationId,
    required this.spaceId,
    required this.activityId,
    required this.phraseId,
    required this.reactionType,
    required DateTime clientTimestamp,
    this.syncState = InteractionSyncState.pending,
    this.lastSyncPhase,
    this.lastSyncError,
    DateTime? lastSyncAt,
  }) : clientTimestamp = clientTimestamp.toUtc(),
       lastSyncAt = lastSyncAt?.toUtc() {
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
    if (lastSyncPhase != null && lastSyncPhase!.trim().isEmpty) {
      throw const FormatException('lastSyncPhase 不能为空字符串。');
    }
    if (lastSyncError != null && lastSyncError!.trim().isEmpty) {
      throw const FormatException('lastSyncError 不能为空字符串。');
    }
  }

  factory InteractionEventPayload.fromWire({
    required String localEventId,
    required String installationId,
    required String spaceId,
    required String activityId,
    required String phraseId,
    required String reactionType,
    required DateTime clientTimestamp,
    String? eventKey,
    String syncState = 'pending',
    String? lastSyncPhase,
    String? lastSyncError,
    DateTime? lastSyncAt,
  }) {
    final payload = InteractionEventPayload(
      localEventId: localEventId,
      installationId: installationId,
      spaceId: spaceId,
      activityId: activityId,
      phraseId: phraseId,
      reactionType: parseBabyReactionType(reactionType),
      clientTimestamp: clientTimestamp,
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

  final String localEventId;
  final String installationId;
  final String spaceId;
  final String activityId;
  final String phraseId;
  final BabyReactionType reactionType;
  final DateTime clientTimestamp;
  final InteractionSyncState syncState;
  final String? lastSyncPhase;
  final String? lastSyncError;
  final DateTime? lastSyncAt;

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
}
