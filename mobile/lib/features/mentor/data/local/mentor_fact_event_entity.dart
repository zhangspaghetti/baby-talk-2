import 'package:mobile/features/mentor/domain/models/mentor_fact_event.dart';
import 'package:isar/isar.dart';

part '../../../../generated/features/mentor/data/local/mentor_fact_event_entity.g.dart';

@collection
class MentorFactEventEntity {
  MentorFactEventEntity();

  MentorFactEventEntity.fromPayload(MentorFactEvent payload) {
    eventKey = payload.eventKey;
    localEventId = payload.localEventId;
    installationId = payload.installationId;
    eventType = payload.eventType.wireValue;
    phase = payload.phase;
    createdAt = payload.createdAt;
    correlationId = payload.correlationId;
    redactedSummary = payload.redactedSummary;
    visibleStatus = payload.visibleStatus;
    visibleDetail = payload.visibleDetail;
    retryable = payload.retryable;
    contextFallbackUsed = payload.contextFallbackUsed;
  }

  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: false)
  late String eventKey;

  @Index(unique: true, replace: false)
  late String localEventId;

  late String installationId;

  @Index()
  late String eventType;

  @Index()
  late DateTime createdAt;

  late String phase;

  String? correlationId;

  String? redactedSummary;

  String? visibleStatus;

  String? visibleDetail;

  bool retryable = false;

  bool contextFallbackUsed = false;

  Map<String, Object?> toPersistedFactMap() {
    return {
      'id': id,
      'eventKey': eventKey,
      'localEventId': localEventId,
      'installationId': installationId,
      'eventType': eventType,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Map<String, Object?> toPersistedDiagnosticsMap() {
    return {
      'phase': phase,
      'correlationId': correlationId,
      'redactedSummary': redactedSummary,
      'visibleStatus': visibleStatus,
      'visibleDetail': visibleDetail,
      'retryable': retryable,
      'contextFallbackUsed': contextFallbackUsed,
    };
  }
}
