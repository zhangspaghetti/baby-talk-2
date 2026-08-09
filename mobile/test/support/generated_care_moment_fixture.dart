import 'package:mobile/features/custom_scene/domain/generated_care_moment.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

GeneratedCareMoment generatedCareMomentFixture({
  required String generatedContentId,
  String? sceneId,
  String? spaceId,
  String? momentId,
  String? activityId,
  String title = '洗澡',
  String sceneTag = 'bath',
  String coachTip = '慢慢来',
  String utteranceIdPrefix = 'utterance',
  String phraseIdPrefix = 'phrase',
  String english = 'Warm water',
  String Function(String suffix)? englishForSuffix,
  String chinese = '温水来了',
  String pronunciation = 'wɔːm',
  String tprActionZh = '靠近宝宝',
  String deliveryGuidanceZh = '慢慢说',
  String providerName = 'provider',
  String modelName = 'model',
}) {
  GeneratedCareUtterance utterance(
    String suffix, {
    required GeneratedCareUtteranceRole role,
    required BabyReactionType? reaction,
    required int displayOrder,
  }) {
    return GeneratedCareUtterance(
      utteranceId: '${utteranceIdPrefix}_$suffix',
      phraseId: '${phraseIdPrefix}_$suffix',
      english: englishForSuffix?.call(suffix) ?? english,
      chinese: chinese,
      pronunciation: pronunciation,
      tprActionZh: tprActionZh,
      deliveryGuidanceZh: deliveryGuidanceZh,
      difficulty: 'starter',
      source: 'generated',
      role: role,
      reaction: reaction,
      displayOrder: displayOrder,
      providerProvenance: GeneratedCareProviderProvenance(
        origin: GeneratedCareProviderOrigin.providerGenerated,
        providerName: providerName,
        modelName: modelName,
        attemptNumber: 1,
      ),
    );
  }

  return GeneratedCareMoment(
    schemaVersion: generatedCareMomentSchemaVersion,
    generatedContentId: generatedContentId,
    sceneId: sceneId ?? 'scene_$generatedContentId',
    spaceId: spaceId ?? 'space_$generatedContentId',
    momentId: momentId ?? 'moment_$generatedContentId',
    activityId: activityId ?? 'activity_$generatedContentId',
    title: title,
    sceneTag: sceneTag,
    coachTip: coachTip,
    source: 'generated',
    starter: utterance(
      'starter',
      role: GeneratedCareUtteranceRole.starter,
      reaction: null,
      displayOrder: 1,
    ),
    reactionSupports:
        GeneratedReactionSupportMap(<BabyReactionType, GeneratedCareUtterance>{
          for (final reaction in BabyReactionType.values)
            reaction: utterance(
              reaction.name,
              role: GeneratedCareUtteranceRole.reactionSupport,
              reaction: reaction,
              displayOrder: BabyReactionType.values.indexOf(reaction) + 2,
            ),
        }),
  );
}
