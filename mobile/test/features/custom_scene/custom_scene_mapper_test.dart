import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_dtos.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_mapper.dart';
import 'package:mobile/features/custom_scene/domain/custom_scene_result.dart';
import 'package:mobile/features/custom_scene/domain/generated_care_moment.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

void main() {
  const mapper = CustomSceneMapper();

  test('maps generated_scene and preserves admitted provenance', () {
    final result = mapper.toCustomSceneResult(
      CustomSceneDiscoveryV2ResponseDto.fromJson(_validResponse()),
    );
    expect(result, isA<GeneratedSceneResult>());
    final generated = result as GeneratedSceneResult;
    final moment = generated.moment;

    expect(moment.generatedContentId, 'gcn_1');
    expect(moment.schemaVersion, generatedCareMomentSchemaVersion);
    expect(moment.safetyPolicyVersion, 'health-safety-v1');
    expect(moment.contentRefreshEpoch, 2);
    expect(generated.policyVersion, 'health-safety-v1');
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
      () => CustomSceneDiscoveryV2ResponseDto.fromJson(response),
        throwsFormatException,
      );
    },
  );

  test('rejects an unknown reaction enum', () {
    final response = _validResponse();
    final support =
        ((response['scene'] as Map<String, dynamic>)['reactionSupports']
                as List<dynamic>)
            .first
            as Map<String, dynamic>;
    support['reaction'] = 'surprised';

    expect(
      () => mapper.toCustomSceneResult(
        CustomSceneDiscoveryV2ResponseDto.fromJson(response),
      ),
      throwsA(isA<CustomSceneMappingException>()),
    );
  });

  test('rejects an incomplete reaction bundle', () {
    final response = _validResponse();
    ((response['scene'] as Map<String, dynamic>)['reactionSupports']
            as List<dynamic>)
        .removeLast();

    expect(
      () => mapper.toCustomSceneResult(
        CustomSceneDiscoveryV2ResponseDto.fromJson(response),
      ),
      throwsA(isA<CustomSceneMappingException>()),
    );
  });

  test('rejects duplicate branch and wrong role before registration', () {
    final duplicate = _validResponse();
    final supports =
        (duplicate['scene'] as Map<String, dynamic>)['reactionSupports']
            as List<dynamic>;
    final second = supports[1] as Map<String, dynamic>;
    second['reaction'] = 'cooperating';
    second['displayOrder'] = 2;

    expect(
      () => mapper.toCustomSceneResult(
        CustomSceneDiscoveryV2ResponseDto.fromJson(duplicate),
      ),
      throwsA(isA<CustomSceneMappingException>()),
    );

    final wrongRole = _validResponse();
    final first =
        ((wrongRole['scene'] as Map<String, dynamic>)['reactionSupports']
                as List<dynamic>)
            .first
            as Map<String, dynamic>;
    first['role'] = 'starter';
    expect(
      () => mapper.toCustomSceneResult(
        CustomSceneDiscoveryV2ResponseDto.fromJson(wrongRole),
      ),
      throwsA(isA<CustomSceneMappingException>()),
    );
  });

  test('rejects unsupported bundle schema and provenance origin', () {
    final oldSchema = _validResponse();
    (oldSchema['scene'] as Map<String, dynamic>)['bundleSchemaVersion'] =
        'custom-scene-generated-output-v0';
    expect(
      () => mapper.toCustomSceneResult(
        CustomSceneDiscoveryV2ResponseDto.fromJson(oldSchema),
      ),
      throwsA(isA<CustomSceneMappingException>()),
    );

    final badProvenance = _validResponse();
    final starter =
        (((badProvenance['scene'] as Map<String, dynamic>)['moments']
                        as List<dynamic>)
                    .single
                as Map<String, dynamic>)['starterUtterances']
            as List<dynamic>;
    final provenance =
        (starter.single as Map<String, dynamic>)['providerProvenance']
            as Map<String, dynamic>;
    provenance['origin'] = 'fixture';
    expect(
      () => mapper.toCustomSceneResult(
        CustomSceneDiscoveryV2ResponseDto.fromJson(badProvenance),
      ),
      throwsA(isA<CustomSceneMappingException>()),
    );
  });

  test('maps health_safety with fixed Chinese notice only', () {
    final result = mapper.toCustomSceneResult(
      CustomSceneDiscoveryV2ResponseDto.fromJson(_healthResponse()),
    );

    expect(result, isA<HealthSafetyResult>());
    final safety = (result as HealthSafetyResult).safety;
    expect(safety.action, 'seek_medical_help');
    expect(safety.templateId, 'health-concern-v1');
    expect(safety.policyVersion, 'health-safety-v1');
    expect(safety.locale, 'zh-CN');
    expect(safety.titleZh, '先关注宝宝的身体状况');
    expect(safety.messageZh, '请联系儿科医生进行评估。');
  });

  test('maps assessment_unavailable with embedded fallback copy', () {
    final result = mapper.toCustomSceneResult(
      CustomSceneDiscoveryV2ResponseDto.fromJson(
        _unavailableResponse(),
      ),
    );

    expect(result, isA<AssessmentUnavailableResult>());
    final safety = (result as AssessmentUnavailableResult).safety;
    expect(safety.templateId, 'health-assessment-unavailable-v1');
    expect(safety.action, 'uncertain');
    expect(safety.policyVersion, 'health-safety-v1');
    expect(safety.locale, 'zh-CN');
    expect(safety.titleZh, '暂时无法判断这段描述');
    expect(
      safety.messageZh,
      '暂时无法完成判断，已暂停生成。如果你正在担心宝宝身体不适，请联系儿科医生；如果情况紧急，请立即联系当地急救服务。',
    );
  });

  test('rejects cross-variant payload fields and unknown values', () {
    final healthWithScene = _healthResponse()..['scene'] = _generatedScene();
    expect(
      () => CustomSceneDiscoveryV2ResponseDto.fromJson(healthWithScene),
      throwsFormatException,
    );

    final generatedWithSafety = _validResponse()
      ..['safety'] = _healthResponse()['safety'];
    expect(
      () => CustomSceneDiscoveryV2ResponseDto.fromJson(generatedWithSafety),
      throwsFormatException,
    );

    for (final mutation in <Map<String, dynamic> Function(Map<String, dynamic>)>[
      (json) => json..['resultType'] = 'future_result',
      (json) => json..['policyVersion'] = 'health-safety-v2',
      (json) {
        final safety = json['safety'] as Map<String, dynamic>;
        safety['action'] = 'diagnose';
        return json;
      },
      (json) {
        final safety = json['safety'] as Map<String, dynamic>;
        safety['templateId'] = 'health-future-v1';
        return json;
      },
    ]) {
      expect(
        () => CustomSceneDiscoveryV2ResponseDto.fromJson(
          mutation(_healthResponse()),
        ),
        throwsFormatException,
      );
    }
  });

  test('rejects non-Chinese locale, missing copy, and missing schema version', () {
    final nonChinese = _healthResponse();
    (nonChinese['safety'] as Map<String, dynamic>)['locale'] = 'en-US';
    expect(
      () => CustomSceneDiscoveryV2ResponseDto.fromJson(nonChinese),
      throwsFormatException,
    );

    final missingCopy = _healthResponse();
    (missingCopy['safety'] as Map<String, dynamic>).remove('messageZh');
    expect(
      () => CustomSceneDiscoveryV2ResponseDto.fromJson(missingCopy),
      throwsFormatException,
    );

    final missingSchema = _healthResponse()..remove('schemaVersion');
    expect(
      () => CustomSceneDiscoveryV2ResponseDto.fromJson(missingSchema),
      throwsFormatException,
    );
  });

  test('maps malformed or future JSON to assessment unavailable fallback', () {
    final result = mapper.fromJson(<String, dynamic>{
      'schemaVersion': 'custom-scene-result-v9',
      'discoveryTraceId': 'disc_future',
      'resultType': 'future_result',
    });

    expect(result, isA<AssessmentUnavailableResult>());
    expect(
      (result as AssessmentUnavailableResult).safety.templateId,
      'health-assessment-unavailable-v1',
    );
  });
}

Map<String, dynamic> _validResponse() => <String, dynamic>{
  'schemaVersion': 'custom-scene-result-v2',
  'discoveryTraceId': 'disc_1',
  'resultType': 'generated_scene',
  'policyVersion': 'health-safety-v1',
  'scene': _generatedScene(),
};

Map<String, dynamic> _healthResponse() => <String, dynamic>{
  'schemaVersion': 'custom-scene-result-v2',
  'discoveryTraceId': 'disc_health',
  'resultType': 'health_safety',
  'safety': <String, Object?>{
    'action': 'seek_medical_help',
    'templateId': 'health-concern-v1',
    'policyVersion': 'health-safety-v1',
    'locale': 'zh-CN',
    'titleZh': '先关注宝宝的身体状况',
    'messageZh': '请联系儿科医生进行评估。',
  },
};

Map<String, dynamic> _unavailableResponse() => <String, dynamic>{
  'schemaVersion': 'custom-scene-result-v2',
  'discoveryTraceId': 'disc_unavailable',
  'resultType': 'assessment_unavailable',
  'safety': <String, Object?>{
    'action': 'uncertain',
    'templateId': 'health-assessment-unavailable-v1',
    'policyVersion': 'health-safety-v1',
    'locale': 'zh-CN',
    'titleZh': '暂时无法判断这段描述',
    'messageZh':
        '暂时无法完成判断，已暂停生成。如果你正在担心宝宝身体不适，请联系儿科医生；如果情况紧急，请立即联系当地急救服务。',
  },
};

Map<String, Object?> _generatedScene() {
  return <String, Object?>{
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
