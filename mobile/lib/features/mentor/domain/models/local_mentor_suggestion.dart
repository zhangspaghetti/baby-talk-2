enum LocalMentorSuggestionOrigin {
  recentPractice,
  starterPhrase,
  stageGuide,
  sharedCaregiverContext,
  safeFallback,
}

extension LocalMentorSuggestionOriginWire on LocalMentorSuggestionOrigin {
  String get wireValue {
    switch (this) {
      case LocalMentorSuggestionOrigin.recentPractice:
        return 'recent_practice';
      case LocalMentorSuggestionOrigin.starterPhrase:
        return 'starter_phrase';
      case LocalMentorSuggestionOrigin.stageGuide:
        return 'stage_guide';
      case LocalMentorSuggestionOrigin.sharedCaregiverContext:
        return 'shared_caregiver_context';
      case LocalMentorSuggestionOrigin.safeFallback:
        return 'safe_fallback';
    }
  }
}

class LocalMentorSuggestion {
  LocalMentorSuggestion({
    required this.suggestionId,
    required this.origin,
    required this.title,
    required this.body,
    String? phraseEnglish,
    String? phraseChinese,
    String? stageId,
    String? spaceId,
    String? activityId,
    String? phraseId,
    String? reasonCode,
    String? redactedContextSummary,
  }) : phraseEnglish = _normalizeOptional(phraseEnglish),
       phraseChinese = _normalizeOptional(phraseChinese),
       stageId = _normalizeOptional(stageId),
       spaceId = _normalizeOptional(spaceId),
       activityId = _normalizeOptional(activityId),
       phraseId = _normalizeOptional(phraseId),
       reasonCode = _normalizeOptional(reasonCode),
       redactedContextSummary = _normalizeOptional(
         redactedContextSummary,
         maxLength: 200,
       ) {
    if (suggestionId.trim().isEmpty) {
      throw const FormatException('suggestionId 不能为空。');
    }
    if (title.trim().isEmpty) {
      throw const FormatException('title 不能为空。');
    }
    if (body.trim().isEmpty) {
      throw const FormatException('body 不能为空。');
    }
  }

  final String suggestionId;
  final LocalMentorSuggestionOrigin origin;
  final String title;
  final String body;
  final String? phraseEnglish;
  final String? phraseChinese;
  final String? stageId;
  final String? spaceId;
  final String? activityId;
  final String? phraseId;
  final String? reasonCode;
  final String? redactedContextSummary;

  bool get isSafeFallback => origin == LocalMentorSuggestionOrigin.safeFallback;

  Map<String, Object?> toVisibleMap() {
    return {
      'suggestionId': suggestionId,
      'origin': origin.wireValue,
      'title': title,
      'body': body,
      'phraseEnglish': phraseEnglish,
      'phraseChinese': phraseChinese,
      'stageId': stageId,
      'spaceId': spaceId,
      'activityId': activityId,
      'phraseId': phraseId,
      'reasonCode': reasonCode,
    };
  }

  Map<String, Object?> toRedactedContextMap() {
    return {
      'origin': origin.wireValue,
      'redactedContextSummary': redactedContextSummary,
    };
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
