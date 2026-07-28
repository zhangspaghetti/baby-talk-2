import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

class GeneratedCareUtterance {
  GeneratedCareUtterance({
    required String utteranceId,
    required String phraseId,
    required String english,
    required String chinese,
    required String pronunciation,
    required String difficulty,
    required String source,
    String? tprActionZh,
    String? deliveryGuidanceZh,
  }) : utteranceId = _required(utteranceId, 'utteranceId'),
       phraseId = _required(phraseId, 'phraseId'),
       english = _required(english, 'english'),
       chinese = _required(chinese, 'chinese'),
       pronunciation = _required(pronunciation, 'pronunciation'),
       difficulty = _required(difficulty, 'difficulty'),
       source = _required(source, 'source'),
       tprActionZh = _optional(tprActionZh),
       deliveryGuidanceZh = _optional(deliveryGuidanceZh);

  final String utteranceId;
  final String phraseId;
  final String english;
  final String chinese;
  final String pronunciation;
  final String difficulty;
  final String source;
  final String? tprActionZh;
  final String? deliveryGuidanceZh;
}

class GeneratedReactionSupportMap {
  GeneratedReactionSupportMap(
    Map<BabyReactionType, GeneratedCareUtterance> values,
  ) : _values = Map<BabyReactionType, GeneratedCareUtterance>.unmodifiable(
        values,
      ) {
    if (_values.length != BabyReactionType.values.length ||
        !BabyReactionType.values.every(_values.containsKey)) {
      throw ArgumentError.value(values, 'values', '必须覆盖全部 canonical reaction。');
    }
  }

  final Map<BabyReactionType, GeneratedCareUtterance> _values;

  GeneratedCareUtterance operator [](BabyReactionType reaction) {
    return _values[reaction]!;
  }

  Map<BabyReactionType, GeneratedCareUtterance> get values => _values;
}

class GeneratedCareMoment {
  GeneratedCareMoment({
    required String generatedContentId,
    required String sceneId,
    required String spaceId,
    required String momentId,
    required String activityId,
    required String title,
    required String sceneTag,
    required String coachTip,
    required String source,
    required this.starter,
    required this.reactionSupports,
  }) : generatedContentId = _required(generatedContentId, 'generatedContentId'),
       sceneId = _required(sceneId, 'sceneId'),
       spaceId = _required(spaceId, 'spaceId'),
       momentId = _required(momentId, 'momentId'),
       activityId = _required(activityId, 'activityId'),
       title = _required(title, 'title'),
       sceneTag = _required(sceneTag, 'sceneTag'),
       coachTip = _required(coachTip, 'coachTip'),
       source = _required(source, 'source');

  final String generatedContentId;
  final String sceneId;
  final String spaceId;
  final String momentId;
  final String activityId;
  final String title;
  final String sceneTag;
  final String coachTip;
  final String source;
  final GeneratedCareUtterance starter;
  final GeneratedReactionSupportMap reactionSupports;
}

String _required(String value, String fieldName) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, fieldName, '不能为空。');
  }
  return normalized;
}

String? _optional(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
