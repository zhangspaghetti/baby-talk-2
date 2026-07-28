import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_dtos.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_mapper.dart';
import 'package:mobile/features/custom_scene/domain/generated_care_moment.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

void main() {
  const mapper = CustomSceneMapper();

  test('maps complete generated bundle and preserves stable IDs', () {
    final moment = mapper.toGeneratedCareMoment(
      CustomSceneDiscoveryResponseDto.fromJson(_validResponse()),
    );

    expect(moment.generatedContentId, 'gcn_1');
    expect(moment.schemaVersion, generatedCareMomentSchemaVersion);
    expect(moment.starter.role, GeneratedCareUtteranceRole.starter);
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
    support['reaction'] = 'surprised';

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

  test('rejects duplicate branch and wrong role before registration', () {
    final duplicate = _validResponse();
    final supports = duplicate['reactionSupports'] as List<dynamic>;
    final second = supports[1] as Map<String, dynamic>;
    second['reaction'] = 'cooperating';
    second['displayOrder'] = 2;

    expect(
      () => mapper.toGeneratedCareMoment(
        CustomSceneDiscoveryResponseDto.fromJson(duplicate),
      ),
      throwsA(isA<CustomSceneMappingException>()),
    );

    final wrongRole = _validResponse();
    final first =
        (wrongRole['reactionSupports'] as List<dynamic>).first
            as Map<String, dynamic>;
    first['role'] = 'starter';
    expect(
      () => mapper.toGeneratedCareMoment(
        CustomSceneDiscoveryResponseDto.fromJson(wrongRole),
      ),
      throwsA(isA<CustomSceneMappingException>()),
    );
  });

  test('rejects unsupported bundle schema and provenance origin', () {
    final oldSchema = _validResponse()
      ..['bundleSchemaVersion'] = 'custom-scene-generated-output-v0';
    expect(
      () => mapper.toGeneratedCareMoment(
        CustomSceneDiscoveryResponseDto.fromJson(oldSchema),
      ),
      throwsA(isA<CustomSceneMappingException>()),
    );

    final badProvenance = _validResponse();
    final starter =
        ((badProvenance['moments'] as List<dynamic>).single
                as Map<String, dynamic>)['starterUtterances']
            as List<dynamic>;
    final provenance =
        (starter.single as Map<String, dynamic>)['providerProvenance']
            as Map<String, dynamic>;
    provenance['origin'] = 'fixture';
    expect(
      () => mapper.toGeneratedCareMoment(
        CustomSceneDiscoveryResponseDto.fromJson(badProvenance),
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
    'bundleSchemaVersion': generatedCareMomentSchemaVersion,
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
            'role': 'starter',
            'reaction': null,
            'tprActionZh': '靠近宝宝',
            'deliveryGuidanceZh': '慢慢说',
            'displayOrder': 1,
            'providerProvenance': _provenance(),
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
    'reaction': reactionType,
    'utteranceId': 'support_$reactionType',
    'phraseId': 'support_$reactionType',
    'english': 'I am here.',
    'chinese': '我在这里。',
    'pronunciation': 'aɪ æm hɪr',
    'tprActionZh': '靠近宝宝',
    'deliveryGuidanceZh': '慢慢说',
    'difficulty': 'starter',
    'source': 'generated',
    'role': 'reaction_support',
    'displayOrder': const <String, int>{
      'cooperating': 2,
      'hesitant': 3,
      'resisting': 4,
      'no_response': 5,
      'other': 6,
    }[reactionType],
    'providerProvenance': _provenance(),
  };
}

Map<String, Object?> _provenance() => <String, Object?>{
  'origin': 'provider_generated',
  'providerName': 'provider',
  'modelName': 'model',
  'attemptNumber': 1,
};
