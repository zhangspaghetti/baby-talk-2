import 'package:isar/isar.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

part 'interaction_event_entity.g.dart';

@collection
class InteractionEventEntity {
  InteractionEventEntity();

  InteractionEventEntity.fromPayload(InteractionEventPayload payload) {
    localEventId = payload.localEventId;
    installationId = payload.installationId;
    spaceId = payload.spaceId;
    activityId = payload.activityId;
    phraseId = payload.phraseId;
    reactionType = payload.reactionType.wireValue;
    clientTimestamp = payload.clientTimestamp;
    syncState = payload.syncState.wireValue;
  }

  Id id = Isar.autoIncrement;

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

  Map<String, Object?> toPersistedFactMap() {
    return {
      'id': id,
      'localEventId': localEventId,
      'installationId': installationId,
      'spaceId': spaceId,
      'activityId': activityId,
      'phraseId': phraseId,
      'reactionType': reactionType,
      'clientTimestamp': clientTimestamp.toIso8601String(),
      'syncState': syncState,
    };
  }
}
