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

class MentorFactEvent {
  MentorFactEvent({
    required this.localEventId,
    required this.installationId,
    required this.eventType,
    required this.phase,
    required DateTime createdAt,
    String? correlationId,
    String? redactedSummary,
    String? visibleStatus,
    String? visibleDetail,
    this.retryable = false,
    this.contextFallbackUsed = false,
  }) : createdAt = createdAt.toUtc(),
       correlationId = _normalizeOptional(correlationId),
       redactedSummary = _normalizeOptional(redactedSummary, maxLength: 240),
       visibleStatus = _normalizeOptional(visibleStatus, maxLength: 80),
       visibleDetail = _normalizeOptional(visibleDetail, maxLength: 160) {
    if (localEventId.trim().isEmpty) {
      throw const FormatException('localEventId 不能为空。');
    }
    if (installationId.trim().isEmpty) {
      throw const FormatException('installationId 不能为空。');
    }
    if (phase.trim().isEmpty) {
      throw const FormatException('phase 不能为空。');
    }
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
    final payload = MentorFactEvent(
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

  final String localEventId;
  final String installationId;
  final MentorFactType eventType;
  final String phase;
  final DateTime createdAt;
  final String? correlationId;
  final String? redactedSummary;
  final String? visibleStatus;
  final String? visibleDetail;
  final bool retryable;
  final bool contextFallbackUsed;

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

  static String? _normalizeOptional(String? value, {int? maxLength}) {
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
