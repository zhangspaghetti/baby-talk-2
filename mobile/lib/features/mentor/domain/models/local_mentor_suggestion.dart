import 'package:freezed_annotation/freezed_annotation.dart';

part '../../../../generated/features/mentor/domain/models/local_mentor_suggestion.freezed.dart';

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

@freezed
class LocalMentorSuggestion with _$LocalMentorSuggestion {
  const LocalMentorSuggestion._();

  const factory LocalMentorSuggestion({
    required String suggestionId,
    required LocalMentorSuggestionOrigin origin,
    required String title,
    required String body,
    String? phraseEnglish,
    String? phraseChinese,
    String? stageId,
    String? spaceId,
    String? activityId,
    String? phraseId,
    String? reasonCode,
    String? redactedContextSummary,
  }) = _LocalMentorSuggestion;

  factory LocalMentorSuggestion.validated({
    required String suggestionId,
    required LocalMentorSuggestionOrigin origin,
    required String title,
    required String body,
    String? phraseEnglish,
    String? phraseChinese,
    String? stageId,
    String? spaceId,
    String? activityId,
    String? phraseId,
    String? reasonCode,
    String? redactedContextSummary,
  }) {
    if (suggestionId.trim().isEmpty) {
      throw const FormatException('suggestionId 不能为空。');
    }
    if (title.trim().isEmpty) {
      throw const FormatException('title 不能为空。');
    }
    if (body.trim().isEmpty) {
      throw const FormatException('body 不能为空。');
    }
    return LocalMentorSuggestion(
      suggestionId: suggestionId,
      origin: origin,
      title: title,
      body: body,
      phraseEnglish: normalizeOptional(phraseEnglish),
      phraseChinese: normalizeOptional(phraseChinese),
      stageId: normalizeOptional(stageId),
      spaceId: normalizeOptional(spaceId),
      activityId: normalizeOptional(activityId),
      phraseId: normalizeOptional(phraseId),
      reasonCode: normalizeOptional(reasonCode),
      redactedContextSummary: normalizeOptional(
        redactedContextSummary,
        maxLength: 200,
      ),
    );
  }

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
