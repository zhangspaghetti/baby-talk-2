import 'package:isar/isar.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

part 'interaction_event_entity.g.dart';

@collection
class InteractionEventEntity {
  InteractionEventEntity();

  InteractionEventEntity.fromPayload(InteractionEventPayload payload) {
    eventKey = payload.eventKey;
    localEventId = payload.localEventId;
    installationId = payload.installationId;
    spaceId = payload.spaceId;
    activityId = payload.activityId;
    phraseId = payload.phraseId;
    reactionType = payload.reactionType.wireValue;
    clientTimestamp = payload.clientTimestamp;
    syncState = payload.syncState.wireValue;
    lastSyncPhase = payload.lastSyncPhase;
    lastSyncError = payload.lastSyncError;
    lastSyncAt = payload.lastSyncAt;
  }

  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: false)
  late String eventKey;

  @Index(unique: true, replace: false)
  late String localEventId;

  late String installationId;

  @Index()
  late String spaceId;

  @Index()
  late String activityId;

  @Index()
  late String phraseId;

  late String reactionType;

  @Index()
  late DateTime clientTimestamp;

  @Index()
  late String syncState;

  String? lastSyncPhase;

  String? lastSyncError;

  DateTime? lastSyncAt;

  Map<String, Object?> toPersistedFactMap() {
    return {
      'id': id,
      'eventKey': eventKey,
      'localEventId': localEventId,
      'installationId': installationId,
      'spaceId': spaceId,
      'activityId': activityId,
      'phraseId': phraseId,
      'reactionType': reactionType,
      'clientTimestamp': clientTimestamp.toIso8601String(),
    };
  }

  Map<String, Object?> toPersistedSyncMetadataMap() {
    return {
      'syncState': syncState,
      'lastSyncPhase': lastSyncPhase,
      'lastSyncError': lastSyncError,
      'lastSyncAt': lastSyncAt?.toIso8601String(),
    };
  }
}
