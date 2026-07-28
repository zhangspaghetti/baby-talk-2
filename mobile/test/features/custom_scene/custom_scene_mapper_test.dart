import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_dtos.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_mapper.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

void main() {
  const mapper = CustomSceneMapper();

  test('maps complete generated bundle and preserves stable IDs', () {
    final moment = mapper.toGeneratedCareMoment(
      CustomSceneDiscoveryResponseDto.fromJson(_validResponse()),
    );

    expect(moment.generatedContentId, 'gcn_1');
    expect(moment.sceneId, 'space_bath');
    expect(moment.momentId, 'activity_bath');
    expect(moment.starter.utteranceId, 'phrase_starter');
    expect(
      moment.reactionSupports[BabyReactionType.hesitant].utteranceId,
      'support_hesitant',
    );
  });

  test(
    'rejects unknown response fields instead of constructing partial data',
    () {
      final response = _validResponse()..['providerDebug'] = 'never expose';

      expect(
        () => CustomSceneDiscoveryResponseDto.fromJson(response),
        throwsFormatException,
      );
    },
  );

  test('rejects an unknown reaction enum', () {
    final response = _validResponse();
    final support =
        (response['reactionSupports'] as List<dynamic>).first
            as Map<String, dynamic>;
    support['reactionType'] = 'surprised';

    expect(
      () => mapper.toGeneratedCareMoment(
        CustomSceneDiscoveryResponseDto.fromJson(response),
      ),
      throwsA(isA<CustomSceneMappingException>()),
    );
  });

  test('rejects an incomplete reaction bundle', () {
    final response = _validResponse();
    (response['reactionSupports'] as List<dynamic>).removeLast();

    expect(
      () => mapper.toGeneratedCareMoment(
        CustomSceneDiscoveryResponseDto.fromJson(response),
      ),
      throwsA(isA<CustomSceneMappingException>()),
    );
  });
}

Map<String, dynamic> _validResponse() {
  return <String, dynamic>{
    'discoveryTraceId': 'disc_1',
    'surface': 'care_path',
    'mode': 'custom_scene',
    'profileMode': 'authenticated_request',
    'source': 'generated',
    'generatedContentId': 'gcn_1',
    'scenes': <Map<String, Object?>>[
      <String, Object?>{
        'sceneId': 'space_bath',
        'spaceId': 'space_bath',
        'title': '洗澡',
        'rank': 1,
        'reasonCode': 'custom_scene_match',
      },
    ],
    'moments': <Map<String, Object?>>[
      <String, Object?>{
        'momentId': 'activity_bath',
        'sceneId': 'space_bath',
        'spaceId': 'space_bath',
        'activityId': 'activity_bath',
        'title': '洗澡时',
        'sceneTag': 'bath',
        'coachTip': '轻声说',
        'rank': 1,
        'starterUtterances': <Map<String, Object?>>[
          <String, Object?>{
            'utteranceId': 'phrase_starter',
            'phraseId': 'phrase_starter',
            'english': 'Warm water.',
            'chinese': '温水来了。',
            'pronunciation': 'wɔːm ˈwɔːtər',
            'difficulty': 'starter',
            'source': 'generated',
          },
        ],
      },
    ],
    'starter': <String, Object?>{
      'sceneId': 'space_bath',
      'spaceId': 'space_bath',
      'momentId': 'activity_bath',
      'activityId': 'activity_bath',
      'utteranceId': 'phrase_starter',
      'phraseId': 'phrase_starter',
      'source': 'generated',
    },
    'reactionSupports': <Map<String, Object?>>[
      _support('cooperating'),
      _support('hesitant'),
      _support('resisting'),
      _support('no_response'),
      _support('other'),
    ],
    'trace': <String, Object?>{
      'strategy': 'custom_scene_generated',
      'fallbackReason': null,
      'candidateCount': 1,
      'returnedCount': 1,
    },
  };
}

Map<String, Object?> _support(String reactionType) {
  return <String, Object?>{
    'reactionType': reactionType,
    'utteranceId': 'support_$reactionType',
    'phraseId': 'support_$reactionType',
    'english': 'I am here.',
    'chinese': '我在这里。',
    'pronunciation': 'aɪ æm hɪr',
    'tprActionZh': '靠近宝宝',
    'deliveryGuidanceZh': '慢慢说',
    'difficulty': 'starter',
    'source': 'generated',
  };
}
