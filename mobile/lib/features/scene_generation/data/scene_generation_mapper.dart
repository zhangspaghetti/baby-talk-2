import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/scene_generation/data/scene_generation_dtos.dart';
import 'package:mobile/features/scene_generation/domain/generated_care_moment.dart';
import 'package:mobile/features/scene_generation/domain/scene_generation_source.dart';

class SceneGenerationMappingException implements Exception {
  const SceneGenerationMappingException();

  @override
  String toString() => 'Scene generation response is malformed.';
}

class SceneGenerationMapper {
  const SceneGenerationMapper();

  GeneratedCareMoment toGeneratedCareMoment(
    SceneGenerationResponseDto response, {
    required SceneGenerationSource expectedSource,
  }) {
    try {
      final sourceType = SceneGenerationSourceType.parse(response.source.type);
      _validateSourceAndRoute(response, expectedSource, sourceType);
      final starter = _toUtterance(
        response.starter,
        expectedRole: GeneratedCareUtteranceRole.starter,
        expectedReaction: null,
        expectedDisplayOrder: 1,
      );
      if (response.route.phraseId != starter.phraseId) {
        throw const SceneGenerationMappingException();
      }

      final supports = <BabyReactionType, GeneratedCareUtterance>{};
      for (final dto in response.reactionSupports) {
        final rawReaction = dto.reaction;
        if (rawReaction == null) {
          throw const SceneGenerationMappingException();
        }
        final reaction = _parseReaction(rawReaction);
        if (supports.containsKey(reaction)) {
          throw const SceneGenerationMappingException();
        }
        supports[reaction] = _toUtterance(
          dto,
          expectedRole: GeneratedCareUtteranceRole.reactionSupport,
          expectedReaction: reaction,
          expectedDisplayOrder: BabyReactionType.values.indexOf(reaction) + 2,
        );
      }
      final reactionSupports = GeneratedReactionSupportMap(supports);
      final allUtterances = <GeneratedCareUtterance>[
        starter,
        for (final reaction in BabyReactionType.values)
          reactionSupports[reaction],
      ];
      final phraseIds = allUtterances.map((value) => value.phraseId).toSet();
      final utteranceIds = allUtterances
          .map((value) => value.utteranceId)
          .toSet();
      if (phraseIds.length != allUtterances.length ||
          utteranceIds.length != allUtterances.length) {
        throw const SceneGenerationMappingException();
      }

      return GeneratedCareMoment(
        schemaVersion: response.bundleSchemaVersion,
        generatedContentId: response.generatedContentId,
        sceneId: response.route.sceneId,
        spaceId: response.route.spaceId,
        momentId: response.route.momentId,
        activityId: response.route.activityId,
        title: response.scene.activityTitle,
        sceneTag: response.scene.sceneTag,
        coachTip: starter.deliveryGuidanceZh,
        source: 'generated',
        inputSource: sourceType,
        presetSceneId: response.source.presetSceneId,
        presetSceneVersion: response.source.presetSceneVersion,
        starter: starter,
        reactionSupports: reactionSupports,
      );
    } on SceneGenerationMappingException {
      rethrow;
    } on ArgumentError {
      throw const SceneGenerationMappingException();
    } on FormatException {
      throw const SceneGenerationMappingException();
    } on StateError {
      throw const SceneGenerationMappingException();
    } on Object {
      throw const SceneGenerationMappingException();
    }
  }

  void _validateSourceAndRoute(
    SceneGenerationResponseDto response,
    SceneGenerationSource expectedSource,
    SceneGenerationSourceType sourceType,
  ) {
    final expectedType = switch (expectedSource) {
      CustomSceneGenerationSource() => SceneGenerationSourceType.custom,
      PresetSceneGenerationSource() => SceneGenerationSourceType.preset,
    };
    if (sourceType != expectedType ||
        response.route.sceneId != response.route.spaceId ||
        response.route.momentId != response.route.activityId ||
        response.route.phraseId != response.starter.phraseId) {
      throw const SceneGenerationMappingException();
    }
    if (expectedSource case PresetSceneGenerationSource(:final presetSceneId)) {
      if (response.source.presetSceneId != presetSceneId ||
          response.route.activityId != presetSceneId) {
        throw const SceneGenerationMappingException();
      }
    }
  }

  GeneratedCareUtterance _toUtterance(
    SceneGenerationUtteranceDto dto, {
    required GeneratedCareUtteranceRole expectedRole,
    required BabyReactionType? expectedReaction,
    required int expectedDisplayOrder,
  }) {
    final role = GeneratedCareUtteranceRole.parse(dto.role);
    final reaction = dto.reaction == null
        ? null
        : _parseReaction(dto.reaction!);
    if (role != expectedRole ||
        reaction != expectedReaction ||
        dto.displayOrder != expectedDisplayOrder) {
      throw const SceneGenerationMappingException();
    }
    return GeneratedCareUtterance(
      utteranceId: dto.utteranceId,
      phraseId: dto.phraseId,
      english: dto.english,
      chinese: dto.chinese,
      pronunciation: dto.pronunciation,
      tprActionZh: dto.tprActionZh,
      deliveryGuidanceZh: dto.deliveryGuidanceZh,
      difficulty: dto.difficulty,
      source: 'generated',
      role: role,
      reaction: reaction,
      displayOrder: dto.displayOrder,
      providerProvenance: _provenance(dto.providerProvenance),
    );
  }

  BabyReactionType _parseReaction(String wireValue) {
    try {
      return parseBabyReactionType(wireValue);
    } on FormatException {
      throw const SceneGenerationMappingException();
    }
  }

  GeneratedCareProviderProvenance _provenance(
    SceneGenerationProviderProvenanceDto dto,
  ) {
    try {
      return GeneratedCareProviderProvenance(
        origin: GeneratedCareProviderOrigin.parse(dto.origin),
        providerName: dto.providerName,
        modelName: dto.modelName,
        attemptNumber: dto.attemptNumber,
      );
    } on ArgumentError {
      throw const SceneGenerationMappingException();
    } on FormatException {
      throw const SceneGenerationMappingException();
    }
  }
}
