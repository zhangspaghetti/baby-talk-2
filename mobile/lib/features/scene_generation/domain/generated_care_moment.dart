import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_source.dart';

export 'package:mobile/features/scene_generation/domain/scene_generation_source.dart'
    show SceneGenerationSourceType;

const generatedCareMomentSchemaVersion = 'custom-scene-generated-output-v1';

enum GeneratedCareUtteranceRole {
  starter('starter'),
  reactionSupport('reaction_support');

  const GeneratedCareUtteranceRole(this.wireValue);

  final String wireValue;

  static GeneratedCareUtteranceRole parse(String value) {
    return GeneratedCareUtteranceRole.values.firstWhere(
      (candidate) => candidate.wireValue == value,
      orElse: () =>
          throw FormatException('unsupported generated utterance role'),
    );
  }
}

enum GeneratedCareProviderOrigin {
  providerGenerated('provider_generated'),
  providerRepaired('provider_repaired');

  const GeneratedCareProviderOrigin(this.wireValue);

  final String wireValue;

  static GeneratedCareProviderOrigin parse(String value) {
    return GeneratedCareProviderOrigin.values.firstWhere(
      (candidate) => candidate.wireValue == value,
      orElse: () => throw FormatException('unsupported provider origin'),
    );
  }
}

class GeneratedCareProviderProvenance {
  GeneratedCareProviderProvenance({
    required this.origin,
    required String providerName,
    required String modelName,
    required int attemptNumber,
  }) : providerName = _required(providerName, 'providerName'),
       modelName = _required(modelName, 'modelName'),
       attemptNumber = _requiredAttemptNumber(attemptNumber);

  final GeneratedCareProviderOrigin origin;
  final String providerName;
  final String modelName;
  final int attemptNumber;
}

class GeneratedCareUtterance {
  GeneratedCareUtterance({
    required String utteranceId,
    required String phraseId,
    required String english,
    required String chinese,
    required String pronunciation,
    required String tprActionZh,
    required String deliveryGuidanceZh,
    required String difficulty,
    required String source,
    required this.role,
    required this.reaction,
    required int displayOrder,
    required this.providerProvenance,
  }) : utteranceId = _required(utteranceId, 'utteranceId'),
       phraseId = _required(phraseId, 'phraseId'),
       english = _required(english, 'english'),
       chinese = _required(chinese, 'chinese'),
       pronunciation = _required(pronunciation, 'pronunciation'),
       tprActionZh = _required(tprActionZh, 'tprActionZh'),
       deliveryGuidanceZh = _required(deliveryGuidanceZh, 'deliveryGuidanceZh'),
       difficulty = _required(difficulty, 'difficulty'),
       source = _required(source, 'source'),
       displayOrder = _requiredDisplayOrder(displayOrder) {
    _validateBranch();
  }

  final String utteranceId;
  final String phraseId;
  final String english;
  final String chinese;
  final String pronunciation;
  final String tprActionZh;
  final String deliveryGuidanceZh;
  final String difficulty;
  final String source;
  final GeneratedCareUtteranceRole role;
  final BabyReactionType? reaction;
  final int displayOrder;
  final GeneratedCareProviderProvenance providerProvenance;

  void _validateBranch() {
    if (role == GeneratedCareUtteranceRole.starter) {
      if (reaction != null || displayOrder != 1) {
        throw ArgumentError(
          'starter must have null reaction and displayOrder 1',
        );
      }
      return;
    }
    final branchReaction = reaction;
    if (branchReaction == null ||
        displayOrder != BabyReactionType.values.indexOf(branchReaction) + 2) {
      throw ArgumentError('reaction support must own canonical reaction/order');
    }
  }
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
    required String schemaVersion,
    required String generatedContentId,
    required String sceneId,
    required String spaceId,
    required String momentId,
    required String activityId,
    required String title,
    required String sceneTag,
    required String coachTip,
    required String source,
    required this.inputSource,
    this.presetSceneId,
    this.presetSceneVersion,
    required this.starter,
    required this.reactionSupports,
  }) : schemaVersion = _requiredSchemaVersion(schemaVersion),
       generatedContentId = _required(generatedContentId, 'generatedContentId'),
       sceneId = _required(sceneId, 'sceneId'),
       spaceId = _required(spaceId, 'spaceId'),
       momentId = _required(momentId, 'momentId'),
       activityId = _required(activityId, 'activityId'),
       title = _required(title, 'title'),
       sceneTag = _required(sceneTag, 'sceneTag'),
       coachTip = _required(coachTip, 'coachTip'),
       source = _required(source, 'source') {
    _validateSourceMetadata();
    if (starter.role != GeneratedCareUtteranceRole.starter ||
        starter.reaction != null ||
        starter.displayOrder != 1) {
      throw ArgumentError('generated starter contract is invalid');
    }
    for (final reaction in BabyReactionType.values) {
      final support = reactionSupports[reaction];
      if (support.role != GeneratedCareUtteranceRole.reactionSupport ||
          support.reaction != reaction ||
          support.displayOrder !=
              BabyReactionType.values.indexOf(reaction) + 2) {
        throw ArgumentError('generated reaction support contract is invalid');
      }
    }
  }

  final String schemaVersion;
  final String generatedContentId;
  final String sceneId;
  final String spaceId;
  final String momentId;
  final String activityId;
  final String title;
  final String sceneTag;
  final String coachTip;
  final String source;
  final SceneGenerationSourceType inputSource;
  final String? presetSceneId;
  final int? presetSceneVersion;
  final GeneratedCareUtterance starter;
  final GeneratedReactionSupportMap reactionSupports;

  void _validateSourceMetadata() {
    switch (inputSource) {
      case SceneGenerationSourceType.custom:
        if (presetSceneId != null || presetSceneVersion != null) {
          throw ArgumentError(
            'custom scene generation cannot have preset metadata',
          );
        }
      case SceneGenerationSourceType.preset:
        if (presetSceneId == null || presetSceneId!.trim().isEmpty) {
          throw ArgumentError('preset scene generation requires preset ID');
        }
        if (presetSceneVersion == null || presetSceneVersion! < 1) {
          throw ArgumentError(
            'preset scene generation requires positive version',
          );
        }
    }
  }
}

String _required(String value, String fieldName) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, fieldName, '不能为空。');
  }
  return normalized;
}

String _requiredSchemaVersion(String value) {
  if (value != generatedCareMomentSchemaVersion) {
    throw ArgumentError.value(
      value,
      'schemaVersion',
      '不支持 generated care moment schema。',
    );
  }
  return value;
}

int _requiredDisplayOrder(int value) {
  if (value < 1 || value > 6) {
    throw ArgumentError.value(value, 'displayOrder', '必须在 1 到 6 之间。');
  }
  return value;
}

int _requiredAttemptNumber(int value) {
  if (value < 1 || value > 5) {
    throw ArgumentError.value(value, 'attemptNumber', '必须在 1 到 5 之间。');
  }
  return value;
}
