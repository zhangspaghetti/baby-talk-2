import 'package:mobile/features/custom_scene/data/custom_scene_dtos.dart';
import 'package:mobile/features/custom_scene/domain/generated_care_moment.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

class CustomSceneMappingException implements Exception {
  const CustomSceneMappingException();
}

class CustomSceneMapper {
  const CustomSceneMapper();

  GeneratedCareMoment toGeneratedCareMoment(
    CustomSceneDiscoveryResponseDto response,
  ) {
    _require(
      response.surface == 'care_path' &&
          response.mode == 'custom_scene' &&
          response.source == 'generated' &&
          (response.profileMode == 'authenticated_profile' ||
              response.profileMode == 'authenticated_request') &&
          response.trace.strategy == 'custom_scene_generated' &&
          response.trace.candidateCount == 1 &&
          response.trace.returnedCount == 1,
    );
    _require(response.scenes.length == 1 && response.moments.length == 1);

    final scene = response.scenes.single;
    final moment = response.moments.single;
    final starter = response.starter;
    _require(
      scene.rank == 1 &&
          scene.reasonCode == 'custom_scene_match' &&
          moment.rank == 1 &&
          scene.sceneId == scene.spaceId &&
          moment.sceneId == scene.sceneId &&
          moment.spaceId == scene.spaceId &&
          starter.sceneId == scene.sceneId &&
          starter.spaceId == scene.spaceId &&
          starter.momentId == moment.momentId &&
          starter.activityId == moment.activityId &&
          starter.source == 'generated' &&
          response.bundleSchemaVersion == generatedCareMomentSchemaVersion &&
          moment.starterUtterances.length == 1,
    );

    final starterDto = moment.starterUtterances.single;
    _require(
      starterDto.source == 'generated' &&
          starterDto.utteranceId == starter.utteranceId &&
          starterDto.phraseId == starter.phraseId &&
          starterDto.role == GeneratedCareUtteranceRole.starter.wireValue &&
          starterDto.reaction == null &&
          starterDto.displayOrder == 1,
    );
    final generatedStarter = GeneratedCareUtterance(
      utteranceId: starterDto.utteranceId,
      phraseId: starterDto.phraseId,
      english: starterDto.english,
      chinese: starterDto.chinese,
      pronunciation: starterDto.pronunciation,
      tprActionZh: starterDto.tprActionZh,
      deliveryGuidanceZh: starterDto.deliveryGuidanceZh,
      difficulty: starterDto.difficulty,
      source: starterDto.source,
      role: _parseRole(starterDto.role),
      reaction: _parseNullableReaction(starterDto.reaction),
      displayOrder: starterDto.displayOrder,
      providerProvenance: _provenance(starterDto.providerProvenance),
    );

    final supports = <BabyReactionType, GeneratedCareUtterance>{};
    for (final support in response.reactionSupports) {
      _require(support.source == 'generated');
      final reaction = _parseReaction(support.reaction);
      if (supports.containsKey(reaction) ||
          support.role !=
              GeneratedCareUtteranceRole.reactionSupport.wireValue ||
          support.displayOrder !=
              BabyReactionType.values.indexOf(reaction) + 2) {
        throw const CustomSceneMappingException();
      }
      supports[reaction] = GeneratedCareUtterance(
        utteranceId: support.utteranceId,
        phraseId: support.phraseId,
        english: support.english,
        chinese: support.chinese,
        pronunciation: support.pronunciation,
        tprActionZh: support.tprActionZh,
        deliveryGuidanceZh: support.deliveryGuidanceZh,
        difficulty: support.difficulty,
        source: support.source,
        role: _parseRole(support.role),
        reaction: reaction,
        displayOrder: support.displayOrder,
        providerProvenance: _provenance(support.providerProvenance),
      );
    }
    final GeneratedReactionSupportMap supportMap;
    try {
      supportMap = GeneratedReactionSupportMap(supports);
    } on ArgumentError {
      throw const CustomSceneMappingException();
    }
    final utteranceIds = <String>{
      generatedStarter.utteranceId,
      ...supportMap.values.values.map((value) => value.utteranceId),
    };
    _require(utteranceIds.length == 6);

    return GeneratedCareMoment(
      schemaVersion: response.bundleSchemaVersion,
      generatedContentId: response.generatedContentId,
      sceneId: scene.sceneId,
      spaceId: scene.spaceId,
      momentId: moment.momentId,
      activityId: moment.activityId,
      title: moment.title,
      sceneTag: moment.sceneTag,
      coachTip: moment.coachTip,
      source: response.source,
      starter: generatedStarter,
      reactionSupports: supportMap,
    );
  }

  BabyReactionType _parseReaction(String wireValue) {
    try {
      return parseBabyReactionType(wireValue);
    } on FormatException {
      throw const CustomSceneMappingException();
    }
  }

  BabyReactionType? _parseNullableReaction(String? wireValue) {
    if (wireValue == null) {
      return null;
    }
    return _parseReaction(wireValue);
  }

  GeneratedCareUtteranceRole _parseRole(String wireValue) {
    try {
      return GeneratedCareUtteranceRole.parse(wireValue);
    } on FormatException {
      throw const CustomSceneMappingException();
    }
  }

  GeneratedCareProviderProvenance _provenance(
    CustomSceneProviderProvenanceDto dto,
  ) {
    try {
      return GeneratedCareProviderProvenance(
        origin: GeneratedCareProviderOrigin.parse(dto.origin),
        providerName: dto.providerName,
        modelName: dto.modelName,
        attemptNumber: dto.attemptNumber,
      );
    } on ArgumentError {
      throw const CustomSceneMappingException();
    } on FormatException {
      throw const CustomSceneMappingException();
    }
  }

  void _require(bool condition) {
    if (!condition) {
      throw const CustomSceneMappingException();
    }
  }
}
