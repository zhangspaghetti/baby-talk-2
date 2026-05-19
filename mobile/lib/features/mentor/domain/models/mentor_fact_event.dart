import 'package:freezed_annotation/freezed_annotation.dart';

part '../../../../generated/features/mentor/domain/models/mentor_fact_event.freezed.dart';

enum MentorFactType {
  panelOpened,
  suggestionServed,
  offlineFallbackServed,
  contextFallbackUsed,
  chatRequested,
  chatResponseDelivered,
  chatFailed,
  ttsPlayed,
  ttsUnavailable,
}

extension MentorFactTypeWire on MentorFactType {
  String get wireValue {
    switch (this) {
      case MentorFactType.panelOpened:
        return 'panel_opened';
      case MentorFactType.suggestionServed:
        return 'suggestion_served';
      case MentorFactType.offlineFallbackServed:
        return 'offline_fallback_served';
      case MentorFactType.contextFallbackUsed:
        return 'context_fallback_used';
      case MentorFactType.chatRequested:
        return 'chat_requested';
      case MentorFactType.chatResponseDelivered:
        return 'chat_response_delivered';
      case MentorFactType.chatFailed:
        return 'chat_failed';
      case MentorFactType.ttsPlayed:
        return 'tts_played';
      case MentorFactType.ttsUnavailable:
        return 'tts_unavailable';
    }
  }
}

MentorFactType parseMentorFactType(String value) {
  switch (value.trim()) {
    case 'panel_opened':
      return MentorFactType.panelOpened;
    case 'suggestion_served':
      return MentorFactType.suggestionServed;
    case 'offline_fallback_served':
      return MentorFactType.offlineFallbackServed;
    case 'context_fallback_used':
      return MentorFactType.contextFallbackUsed;
    case 'chat_requested':
      return MentorFactType.chatRequested;
    case 'chat_response_delivered':
      return MentorFactType.chatResponseDelivered;
    case 'chat_failed':
      return MentorFactType.chatFailed;
    case 'tts_played':
      return MentorFactType.ttsPlayed;
    case 'tts_unavailable':
      return MentorFactType.ttsUnavailable;
    default:
      throw FormatException('未知 mentor fact type: $value');
  }
}

@freezed
class MentorFactEvent with _$MentorFactEvent {
  MentorFactEvent._();

  factory MentorFactEvent({
    required String localEventId,
    required String installationId,
    required MentorFactType eventType,
    required String phase,
    required DateTime createdAt,
    String? correlationId,
    String? redactedSummary,
    String? visibleStatus,
    String? visibleDetail,
    @Default(false) bool retryable,
    @Default(false) bool contextFallbackUsed,
  }) = _MentorFactEvent;

  factory MentorFactEvent.validated({
    required String localEventId,
    required String installationId,
    required MentorFactType eventType,
    required String phase,
    required DateTime createdAt,
    String? correlationId,
    String? redactedSummary,
    String? visibleStatus,
    String? visibleDetail,
    bool retryable = false,
    bool contextFallbackUsed = false,
  }) {
    if (localEventId.trim().isEmpty) {
      throw const FormatException('localEventId 不能为空。');
    }
    if (installationId.trim().isEmpty) {
      throw const FormatException('installationId 不能为空。');
    }
    if (phase.trim().isEmpty) {
      throw const FormatException('phase 不能为空。');
    }
    return MentorFactEvent(
      localEventId: localEventId,
      installationId: installationId,
      eventType: eventType,
      phase: phase,
      createdAt: createdAt.toUtc(),
      correlationId: normalizeOptional(correlationId),
      redactedSummary: normalizeOptional(redactedSummary, maxLength: 240),
      visibleStatus: normalizeOptional(visibleStatus, maxLength: 80),
      visibleDetail: normalizeOptional(visibleDetail, maxLength: 160),
      retryable: retryable,
      contextFallbackUsed: contextFallbackUsed,
    );
  }

  factory MentorFactEvent.fromWire({
    required String localEventId,
    required String installationId,
    required String eventType,
    required String phase,
    required DateTime createdAt,
    String? eventKey,
    String? correlationId,
    String? redactedSummary,
    String? visibleStatus,
    String? visibleDetail,
    bool retryable = false,
    bool contextFallbackUsed = false,
  }) {
    final payload = MentorFactEvent.validated(
      localEventId: localEventId,
      installationId: installationId,
      eventType: parseMentorFactType(eventType),
      phase: phase,
      createdAt: createdAt,
      correlationId: correlationId,
      redactedSummary: redactedSummary,
      visibleStatus: visibleStatus,
      visibleDetail: visibleDetail,
      retryable: retryable,
      contextFallbackUsed: contextFallbackUsed,
    );
    if (eventKey != null && eventKey.trim() != payload.eventKey) {
      throw FormatException(
        'eventKey 与 installationId/localEventId 不一致：$eventKey != ${payload.eventKey}',
      );
    }
    return payload;
  }

  String get eventKey => '$installationId:$localEventId';

  Map<String, Object?> toFactMap() {
    return {
      'eventKey': eventKey,
      'localEventId': localEventId,
      'installationId': installationId,
      'eventType': eventType.wireValue,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Map<String, Object?> toRedactedMetadataMap() {
    return {
      'phase': phase,
      'correlationId': correlationId,
      'redactedSummary': redactedSummary,
      'retryable': retryable,
      'contextFallbackUsed': contextFallbackUsed,
    };
  }

  Map<String, Object?> toVisibleMetadataMap() {
    return {'visibleStatus': visibleStatus, 'visibleDetail': visibleDetail};
  }

  static String? normalizeOptional(String? value, {int? maxLength}) {
    if (value == null) {
      return null;
    }
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    if (maxLength == null || normalized.length <= maxLength) {
      return normalized;
    }
    return normalized.substring(0, maxLength);
  }
}
