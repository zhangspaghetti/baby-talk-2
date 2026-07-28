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
          moment.starterUtterances.length == 1,
    );

    final starterDto = moment.starterUtterances.single;
    _require(
      starterDto.source == 'generated' &&
          starterDto.utteranceId == starter.utteranceId &&
          starterDto.phraseId == starter.phraseId,
    );
    final generatedStarter = GeneratedCareUtterance(
      utteranceId: starterDto.utteranceId,
      phraseId: starterDto.phraseId,
      english: starterDto.english,
      chinese: starterDto.chinese,
      pronunciation: starterDto.pronunciation,
      difficulty: starterDto.difficulty,
      source: starterDto.source,
    );

    final supports = <BabyReactionType, GeneratedCareUtterance>{};
    for (final support in response.reactionSupports) {
      _require(support.source == 'generated');
      final reaction = _parseReaction(support.reactionType);
      if (supports.containsKey(reaction)) {
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

  void _require(bool condition) {
    if (!condition) {
      throw const CustomSceneMappingException();
    }
  }
}
