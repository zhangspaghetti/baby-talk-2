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
  }) : clientTimestamp = clientTimestamp.toUtc() {
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
  }

  factory InteractionEventPayload.fromWire({
    required String localEventId,
    required String installationId,
    required String spaceId,
    required String activityId,
    required String phraseId,
    required String reactionType,
    required DateTime clientTimestamp,
    String syncState = 'pending',
  }) {
    return InteractionEventPayload(
      localEventId: localEventId,
      installationId: installationId,
      spaceId: spaceId,
      activityId: activityId,
      phraseId: phraseId,
      reactionType: parseBabyReactionType(reactionType),
      clientTimestamp: clientTimestamp,
      syncState: parseInteractionSyncState(syncState),
    );
  }

  final String localEventId;
  final String installationId;
  final String spaceId;
  final String activityId;
  final String phraseId;
  final BabyReactionType reactionType;
  final DateTime clientTimestamp;
  final InteractionSyncState syncState;

  String get eventKey => '$installationId:$localEventId';

  Map<String, Object?> toFactMap() {
    return {
      'localEventId': localEventId,
      'installationId': installationId,
      'spaceId': spaceId,
      'activityId': activityId,
      'phraseId': phraseId,
      'reactionType': reactionType.wireValue,
      'clientTimestamp': clientTimestamp.toIso8601String(),
      'syncState': syncState.wireValue,
    };
  }
}
