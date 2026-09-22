import 'package:mobile/features/scene_generation/domain/scene_generation_source.dart';

class SceneGenerationRequestDto {
  const SceneGenerationRequestDto({
    required this.source,
    required this.locale,
    required this.installationId,
    required this.clientRequestId,
  });

  final SceneGenerationSource source;
  final String locale;
  final String installationId;
  final String clientRequestId;

  Map<String, Object?> toJson() {
    final sourceJson = switch (source) {
      CustomSceneGenerationSource(:final text) => <String, Object?>{
        'type': 'custom',
        'text': text,
      },
      PresetSceneGenerationSource(:final presetSceneId) => <String, Object?>{
        'type': 'preset',
        'presetSceneId': presetSceneId,
      },
    };
    return <String, Object?>{
      'source': sourceJson,
      'locale': locale,
      'installationId': installationId,
      'clientRequestId': clientRequestId,
    };
  }
}

class SceneGenerationResponseDto {
  SceneGenerationResponseDto({
    required this.generatedContentId,
    required this.bundleSchemaVersion,
    required this.route,
    required this.scene,
    required this.starter,
    required this.reactionSupports,
    required this.source,
  });

  factory SceneGenerationResponseDto.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, const <String>{
      'generatedContentId',
      'bundleSchemaVersion',
      'route',
      'scene',
      'starter',
      'reactionSupports',
      'source',
    });
    return SceneGenerationResponseDto(
      generatedContentId: _requiredString(json, 'generatedContentId'),
      bundleSchemaVersion: _requiredString(json, 'bundleSchemaVersion'),
      route: SceneGenerationRouteDto.fromJson(_requiredMap(json, 'route')),
      scene: SceneGenerationSceneDto.fromJson(_requiredMap(json, 'scene')),
      starter: SceneGenerationUtteranceDto.fromJson(
        _requiredMap(json, 'starter'),
      ),
      reactionSupports: _requiredList(json, 'reactionSupports')
          .map(
            (value) => SceneGenerationUtteranceDto.fromJson(
              _asMap(value, 'reactionSupports[]'),
            ),
          )
          .toList(growable: false),
      source: SceneGenerationSourceDto.fromJson(_requiredMap(json, 'source')),
    );
  }

  final String generatedContentId;
  final String bundleSchemaVersion;
  final SceneGenerationRouteDto route;
  final SceneGenerationSceneDto scene;
  final SceneGenerationUtteranceDto starter;
  final List<SceneGenerationUtteranceDto> reactionSupports;
  final SceneGenerationSourceDto source;

  Map<String, Object?> toJson() => <String, Object?>{
    'generatedContentId': generatedContentId,
    'bundleSchemaVersion': bundleSchemaVersion,
    'route': route.toJson(),
    'scene': scene.toJson(),
    'starter': starter.toJson(),
    'reactionSupports': reactionSupports
        .map((value) => value.toJson())
        .toList(growable: false),
    'source': source.toJson(),
  };
}

class SceneGenerationRouteDto {
  SceneGenerationRouteDto({
    required this.sceneId,
    required this.spaceId,
    required this.momentId,
    required this.activityId,
    required this.phraseId,
  });

  factory SceneGenerationRouteDto.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, const <String>{
      'sceneId',
      'spaceId',
      'momentId',
      'activityId',
      'phraseId',
    });
    return SceneGenerationRouteDto(
      sceneId: _requiredString(json, 'sceneId'),
      spaceId: _requiredString(json, 'spaceId'),
      momentId: _requiredString(json, 'momentId'),
      activityId: _requiredString(json, 'activityId'),
      phraseId: _requiredString(json, 'phraseId'),
    );
  }

  final String sceneId;
  final String spaceId;
  final String momentId;
  final String activityId;
  final String phraseId;

  Map<String, Object?> toJson() => <String, Object?>{
    'sceneId': sceneId,
    'spaceId': spaceId,
    'momentId': momentId,
    'activityId': activityId,
    'phraseId': phraseId,
  };
}

class SceneGenerationSceneDto {
  SceneGenerationSceneDto({
    required this.spaceTitle,
    required this.activityTitle,
    required this.sceneTag,
  });

  factory SceneGenerationSceneDto.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, const <String>{
      'spaceTitle',
      'activityTitle',
      'sceneTag',
    });
    return SceneGenerationSceneDto(
      spaceTitle: _requiredString(json, 'spaceTitle'),
      activityTitle: _requiredString(json, 'activityTitle'),
      sceneTag: _requiredString(json, 'sceneTag'),
    );
  }

  final String spaceTitle;
  final String activityTitle;
  final String sceneTag;

  Map<String, Object?> toJson() => <String, Object?>{
    'spaceTitle': spaceTitle,
    'activityTitle': activityTitle,
    'sceneTag': sceneTag,
  };
}

class SceneGenerationUtteranceDto {
  SceneGenerationUtteranceDto({
    required this.utteranceId,
    required this.phraseId,
    required this.english,
    required this.chinese,
    required this.pronunciation,
    required this.tprActionZh,
    required this.deliveryGuidanceZh,
    required this.difficulty,
    required this.role,
    required this.reaction,
    required this.displayOrder,
    required this.providerProvenance,
  });

  factory SceneGenerationUtteranceDto.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, const <String>{
      'utteranceId',
      'phraseId',
      'english',
      'chinese',
      'pronunciation',
      'tprActionZh',
      'deliveryGuidanceZh',
      'difficulty',
      'role',
      'reaction',
      'displayOrder',
      'providerProvenance',
    });
    return SceneGenerationUtteranceDto(
      utteranceId: _requiredString(json, 'utteranceId'),
      phraseId: _requiredString(json, 'phraseId'),
      english: _requiredString(json, 'english'),
      chinese: _requiredString(json, 'chinese'),
      pronunciation: _requiredString(json, 'pronunciation'),
      tprActionZh: _requiredString(json, 'tprActionZh'),
      deliveryGuidanceZh: _requiredString(json, 'deliveryGuidanceZh'),
      difficulty: _requiredString(json, 'difficulty'),
      role: _requiredString(json, 'role'),
      reaction: _optionalString(json, 'reaction'),
      displayOrder: _requiredInt(json, 'displayOrder'),
      providerProvenance: SceneGenerationProviderProvenanceDto.fromJson(
        _requiredMap(json, 'providerProvenance'),
      ),
    );
  }

  final String utteranceId;
  final String phraseId;
  final String english;
  final String chinese;
  final String pronunciation;
  final String tprActionZh;
  final String deliveryGuidanceZh;
  final String difficulty;
  final String role;
  final String? reaction;
  final int displayOrder;
  final SceneGenerationProviderProvenanceDto providerProvenance;

  Map<String, Object?> toJson() => <String, Object?>{
    'utteranceId': utteranceId,
    'phraseId': phraseId,
    'english': english,
    'chinese': chinese,
    'pronunciation': pronunciation,
    'tprActionZh': tprActionZh,
    'deliveryGuidanceZh': deliveryGuidanceZh,
    'difficulty': difficulty,
    'role': role,
    'reaction': reaction,
    'displayOrder': displayOrder,
    'providerProvenance': providerProvenance.toJson(),
  };
}

class SceneGenerationProviderProvenanceDto {
  SceneGenerationProviderProvenanceDto({
    required this.origin,
    required this.providerName,
    required this.modelName,
    required this.attemptNumber,
  });

  factory SceneGenerationProviderProvenanceDto.fromJson(
    Map<String, dynamic> json,
  ) {
    _requireExactKeys(json, const <String>{
      'origin',
      'providerName',
      'modelName',
      'attemptNumber',
    });
    return SceneGenerationProviderProvenanceDto(
      origin: _requiredString(json, 'origin'),
      providerName: _requiredString(json, 'providerName'),
      modelName: _requiredString(json, 'modelName'),
      attemptNumber: _requiredInt(json, 'attemptNumber'),
    );
  }

  final String origin;
  final String providerName;
  final String modelName;
  final int attemptNumber;

  Map<String, Object?> toJson() => <String, Object?>{
    'origin': origin,
    'providerName': providerName,
    'modelName': modelName,
    'attemptNumber': attemptNumber,
  };
}

class SceneGenerationSourceDto {
  SceneGenerationSourceDto({
    required this.type,
    required this.presetSceneId,
    required this.presetSceneVersion,
  }) {
    _validateMetadata();
  }

  factory SceneGenerationSourceDto.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, const <String>{
      'type',
      'presetSceneId',
      'presetSceneVersion',
    });
    return SceneGenerationSourceDto(
      type: _requiredString(json, 'type'),
      presetSceneId: _optionalString(json, 'presetSceneId'),
      presetSceneVersion: _optionalInt(json, 'presetSceneVersion'),
    );
  }

  final String type;
  final String? presetSceneId;
  final int? presetSceneVersion;

  void _validateMetadata() {
    if (type == 'custom') {
      if (presetSceneId != null || presetSceneVersion != null) {
        throw const FormatException(
          'custom scene source cannot include preset metadata',
        );
      }
      return;
    }
    if (type == 'preset') {
      if (presetSceneId == null ||
          presetSceneId!.trim().isEmpty ||
          presetSceneVersion == null ||
          presetSceneVersion! < 1) {
        throw const FormatException(
          'preset scene source requires valid metadata',
        );
      }
      return;
    }
    throw const FormatException('unsupported scene generation source type');
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type,
    'presetSceneId': presetSceneId,
    'presetSceneVersion': presetSceneVersion,
  };
}

void _requireExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      !json.keys.toSet().containsAll(expected) ||
      !expected.containsAll(json.keys)) {
    throw const FormatException('scene generation response keys are invalid');
  }
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  return _asMap(json[key], key);
}

Map<String, dynamic> _asMap(Object? value, String field) {
  if (value is! Map) {
    throw FormatException('scene generation field is not an object: $field');
  }
  final result = <String, dynamic>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('scene generation field has invalid key: $field');
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('scene generation field is not a string: $key');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('scene generation optional field is invalid: $key');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('scene generation field is not an integer: $key');
  }
  return value;
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! int) {
    throw FormatException('scene generation optional field is invalid: $key');
  }
  return value;
}

List<Object?> _requiredList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('scene generation field is not an array: $key');
  }
  return List<Object?>.from(value);
}

// Compatibility aliases keep DTO names readable at call sites that use the
// backend response terminology.
typedef SceneGenerationResponseRouteDto = SceneGenerationRouteDto;
typedef SceneGenerationResponseSceneDto = SceneGenerationSceneDto;
typedef SceneGenerationResponseUtteranceDto = SceneGenerationUtteranceDto;
typedef SceneGenerationResponseSourceDto = SceneGenerationSourceDto;
