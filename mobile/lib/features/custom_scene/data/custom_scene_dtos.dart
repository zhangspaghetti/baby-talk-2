class CustomSceneRequestDto {
  const CustomSceneRequestDto({
    required this.installationId,
    required this.babyProfileId,
    required this.ageRange,
    required this.parentGoal,
    required this.locale,
    required this.customSceneText,
    required this.clientRequestId,
  });

  final String installationId;
  final String? babyProfileId;
  final String ageRange;
  final String parentGoal;
  final String locale;
  final String customSceneText;
  final String clientRequestId;

  Map<String, Object?> toJson() => <String, Object?>{
    'surface': 'care_path',
    'mode': 'custom_scene',
    'installationId': installationId,
    if (babyProfileId != null) 'babyProfileId': babyProfileId,
    'ageRange': ageRange,
    'parentGoal': parentGoal,
    'locale': locale,
    'customSceneText': customSceneText,
    'clientRequestId': clientRequestId,
  };
}

class CustomSceneDiscoveryResponseDto {
  CustomSceneDiscoveryResponseDto({
    required this.discoveryTraceId,
    required this.surface,
    required this.mode,
    required this.profileMode,
    required this.source,
    required this.generatedContentId,
    required this.scenes,
    required this.moments,
    required this.starter,
    required this.reactionSupports,
    required this.trace,
  });

  factory CustomSceneDiscoveryResponseDto.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, const <String>{
      'discoveryTraceId',
      'surface',
      'mode',
      'profileMode',
      'source',
      'generatedContentId',
      'scenes',
      'moments',
      'starter',
      'reactionSupports',
      'trace',
    });
    return CustomSceneDiscoveryResponseDto(
      discoveryTraceId: _requiredString(json, 'discoveryTraceId'),
      surface: _requiredString(json, 'surface'),
      mode: _requiredString(json, 'mode'),
      profileMode: _requiredString(json, 'profileMode'),
      source: _requiredString(json, 'source'),
      generatedContentId: _requiredString(json, 'generatedContentId'),
      scenes: _requiredList(json, 'scenes')
          .map((value) => CustomSceneSceneDto.fromJson(_asMap(value, 'scenes')))
          .toList(growable: false),
      moments: _requiredList(json, 'moments')
          .map(
            (value) => CustomSceneMomentDto.fromJson(_asMap(value, 'moments')),
          )
          .toList(growable: false),
      starter: CustomSceneStarterDto.fromJson(_requiredMap(json, 'starter')),
      reactionSupports: _requiredList(json, 'reactionSupports')
          .map(
            (value) => CustomSceneReactionSupportDto.fromJson(
              _asMap(value, 'reactionSupports'),
            ),
          )
          .toList(growable: false),
      trace: CustomSceneTraceDto.fromJson(_requiredMap(json, 'trace')),
    );
  }

  final String discoveryTraceId;
  final String surface;
  final String mode;
  final String profileMode;
  final String source;
  final String generatedContentId;
  final List<CustomSceneSceneDto> scenes;
  final List<CustomSceneMomentDto> moments;
  final CustomSceneStarterDto starter;
  final List<CustomSceneReactionSupportDto> reactionSupports;
  final CustomSceneTraceDto trace;
}

class CustomSceneSceneDto {
  CustomSceneSceneDto({
    required this.sceneId,
    required this.spaceId,
    required this.title,
    required this.rank,
    required this.reasonCode,
  });

  factory CustomSceneSceneDto.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, const <String>{
      'sceneId',
      'spaceId',
      'title',
      'rank',
      'reasonCode',
    });
    return CustomSceneSceneDto(
      sceneId: _requiredString(json, 'sceneId'),
      spaceId: _requiredString(json, 'spaceId'),
      title: _requiredString(json, 'title'),
      rank: _requiredInt(json, 'rank'),
      reasonCode: _requiredString(json, 'reasonCode'),
    );
  }

  final String sceneId;
  final String spaceId;
  final String title;
  final int rank;
  final String reasonCode;
}

class CustomSceneMomentDto {
  CustomSceneMomentDto({
    required this.momentId,
    required this.sceneId,
    required this.spaceId,
    required this.activityId,
    required this.title,
    required this.sceneTag,
    required this.coachTip,
    required this.rank,
    required this.starterUtterances,
  });

  factory CustomSceneMomentDto.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, const <String>{
      'momentId',
      'sceneId',
      'spaceId',
      'activityId',
      'title',
      'sceneTag',
      'coachTip',
      'rank',
      'starterUtterances',
    });
    return CustomSceneMomentDto(
      momentId: _requiredString(json, 'momentId'),
      sceneId: _requiredString(json, 'sceneId'),
      spaceId: _requiredString(json, 'spaceId'),
      activityId: _requiredString(json, 'activityId'),
      title: _requiredString(json, 'title'),
      sceneTag: _requiredString(json, 'sceneTag'),
      coachTip: _requiredString(json, 'coachTip'),
      rank: _requiredInt(json, 'rank'),
      starterUtterances: _requiredList(json, 'starterUtterances')
          .map(
            (value) => CustomSceneStarterUtteranceDto.fromJson(
              _asMap(value, 'starterUtterances'),
            ),
          )
          .toList(growable: false),
    );
  }

  final String momentId;
  final String sceneId;
  final String spaceId;
  final String activityId;
  final String title;
  final String sceneTag;
  final String coachTip;
  final int rank;
  final List<CustomSceneStarterUtteranceDto> starterUtterances;
}

class CustomSceneStarterUtteranceDto {
  CustomSceneStarterUtteranceDto({
    required this.utteranceId,
    required this.phraseId,
    required this.english,
    required this.chinese,
    required this.pronunciation,
    required this.difficulty,
    required this.source,
  });

  factory CustomSceneStarterUtteranceDto.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, const <String>{
      'utteranceId',
      'phraseId',
      'english',
      'chinese',
      'pronunciation',
      'difficulty',
      'source',
    });
    return CustomSceneStarterUtteranceDto(
      utteranceId: _requiredString(json, 'utteranceId'),
      phraseId: _requiredString(json, 'phraseId'),
      english: _requiredString(json, 'english'),
      chinese: _requiredString(json, 'chinese'),
      pronunciation: _requiredString(json, 'pronunciation'),
      difficulty: _requiredString(json, 'difficulty'),
      source: _requiredString(json, 'source'),
    );
  }

  final String utteranceId;
  final String phraseId;
  final String english;
  final String chinese;
  final String pronunciation;
  final String difficulty;
  final String source;
}

class CustomSceneStarterDto {
  CustomSceneStarterDto({
    required this.sceneId,
    required this.spaceId,
    required this.momentId,
    required this.activityId,
    required this.utteranceId,
    required this.phraseId,
    required this.source,
  });

  factory CustomSceneStarterDto.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, const <String>{
      'sceneId',
      'spaceId',
      'momentId',
      'activityId',
      'utteranceId',
      'phraseId',
      'source',
    });
    return CustomSceneStarterDto(
      sceneId: _requiredString(json, 'sceneId'),
      spaceId: _requiredString(json, 'spaceId'),
      momentId: _requiredString(json, 'momentId'),
      activityId: _requiredString(json, 'activityId'),
      utteranceId: _requiredString(json, 'utteranceId'),
      phraseId: _requiredString(json, 'phraseId'),
      source: _requiredString(json, 'source'),
    );
  }

  final String sceneId;
  final String spaceId;
  final String momentId;
  final String activityId;
  final String utteranceId;
  final String phraseId;
  final String source;
}

class CustomSceneReactionSupportDto {
  CustomSceneReactionSupportDto({
    required this.reactionType,
    required this.utteranceId,
    required this.phraseId,
    required this.english,
    required this.chinese,
    required this.pronunciation,
    required this.tprActionZh,
    required this.deliveryGuidanceZh,
    required this.difficulty,
    required this.source,
  });

  factory CustomSceneReactionSupportDto.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, const <String>{
      'reactionType',
      'utteranceId',
      'phraseId',
      'english',
      'chinese',
      'pronunciation',
      'tprActionZh',
      'deliveryGuidanceZh',
      'difficulty',
      'source',
    });
    return CustomSceneReactionSupportDto(
      reactionType: _requiredString(json, 'reactionType'),
      utteranceId: _requiredString(json, 'utteranceId'),
      phraseId: _requiredString(json, 'phraseId'),
      english: _requiredString(json, 'english'),
      chinese: _requiredString(json, 'chinese'),
      pronunciation: _requiredString(json, 'pronunciation'),
      tprActionZh: _requiredString(json, 'tprActionZh'),
      deliveryGuidanceZh: _requiredString(json, 'deliveryGuidanceZh'),
      difficulty: _requiredString(json, 'difficulty'),
      source: _requiredString(json, 'source'),
    );
  }

  final String reactionType;
  final String utteranceId;
  final String phraseId;
  final String english;
  final String chinese;
  final String pronunciation;
  final String tprActionZh;
  final String deliveryGuidanceZh;
  final String difficulty;
  final String source;
}

class CustomSceneTraceDto {
  CustomSceneTraceDto({
    required this.strategy,
    required this.fallbackReason,
    required this.candidateCount,
    required this.returnedCount,
  });

  factory CustomSceneTraceDto.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, const <String>{
      'strategy',
      'fallbackReason',
      'candidateCount',
      'returnedCount',
    });
    return CustomSceneTraceDto(
      strategy: _requiredString(json, 'strategy'),
      fallbackReason: _optionalString(json, 'fallbackReason'),
      candidateCount: _requiredInt(json, 'candidateCount'),
      returnedCount: _requiredInt(json, 'returnedCount'),
    );
  }

  final String strategy;
  final String? fallbackReason;
  final int candidateCount;
  final int returnedCount;
}

class CustomSceneApiErrorDto {
  CustomSceneApiErrorDto({
    required this.status,
    required this.code,
    required this.retryable,
    required this.generatedContentId,
    required this.requiresNewClientRequestId,
  });

  factory CustomSceneApiErrorDto.fromJson(Map<String, dynamic> json) {
    _requireExactKeys(json, const <String>{
      'timestamp',
      'status',
      'code',
      'message',
      'details',
    });
    final details = _requiredMap(json, 'details');
    return CustomSceneApiErrorDto(
      status: _requiredInt(json, 'status'),
      code: _requiredString(json, 'code'),
      retryable: _optionalBool(details, 'retryable') ?? false,
      generatedContentId: _optionalString(details, 'generatedContentId'),
      requiresNewClientRequestId:
          _optionalBool(details, 'requiresNewClientRequestId') ?? false,
    );
  }

  final int status;
  final String code;
  final bool retryable;
  final String? generatedContentId;
  final bool requiresNewClientRequestId;
}

void _requireExactKeys(Map<String, dynamic> json, Set<String> expected) {
  final actual = json.keys.toSet();
  if (actual.length != expected.length || !actual.containsAll(expected)) {
    throw FormatException('响应字段与固定合同不匹配。');
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('字段 `$key` 缺失或不是非空字符串。');
  }
  return value.trim();
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('字段 `$key` 不是字符串。');
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('字段 `$key` 缺失或不是整数。');
  }
  return value;
}

bool? _optionalBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! bool) {
    throw FormatException('字段 `$key` 不是布尔值。');
  }
  return value;
}

List<dynamic> _requiredList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('字段 `$key` 缺失或不是列表。');
  }
  return value;
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  return _asMap(json[key], key);
}

Map<String, dynamic> _asMap(Object? value, String fieldName) {
  if (value is! Map) {
    throw FormatException('字段 `$fieldName` 缺失或不是对象。');
  }
  final mapped = <String, dynamic>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('字段 `$fieldName` 含有非字符串 key。');
    }
    mapped[entry.key as String] = entry.value;
  }
  return mapped;
}
