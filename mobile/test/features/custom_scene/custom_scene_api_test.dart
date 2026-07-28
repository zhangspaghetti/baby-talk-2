import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/auth_headers.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_api.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_dtos.dart';

void main() {
  group('CustomSceneApi', () {
    test('uses authenticated canonical discovery contract', () async {
      final dio = _mockDio((options) async {
        expect(options.method, 'POST');
        expect(options.path, '/api/v1/practice/discovery');
        expect(options.headers[authorizationHeaderName], 'Bearer access-live');
        final body = options.data as Map<String, Object?>;
        expect(body, <String, Object?>{
          'surface': 'care_path',
          'mode': 'custom_scene',
          'installationId': 'install_1',
          'ageRange': 'm7_11',
          'parentGoal': 'natural_opening',
          'locale': 'zh-CN',
          'customSceneText': '宝宝洗澡时一直躲水。',
          'clientRequestId': 'custom_scene_1',
        });
        expect(body.containsKey('clientTraceId'), isFalse);
        return _response(options, _validResponse());
      });
      final api = CustomSceneApi(
        authenticatedApiClient: AuthenticatedApiClient(
          apiService: _NoRefreshAccountApiService(),
        ),
        dio: dio,
      );

      final response = await api.generate(
        session: _session(),
        persistRefreshedSession: (session) async => session,
        request: const CustomSceneRequestDto(
          installationId: 'install_1',
          babyProfileId: null,
          ageRange: 'm7_11',
          parentGoal: 'natural_opening',
          locale: 'zh-CN',
          customSceneText: '宝宝洗澡时一直躲水。',
          clientRequestId: 'custom_scene_1',
        ),
      );

      expect(response.generatedContentId, 'gcn_1');
    });

    test('keeps backend error message out of API exception', () async {
      final dio = _mockDio((options) async {
        return _response(options, <String, Object?>{
          'timestamp': '2026-07-28T00:00:00Z',
          'status': 409,
          'code': 'client_request_terminal',
          'message': '宝宝洗澡时一直躲水。',
          'details': <String, Object?>{
            'generatedContentId': 'gcn_terminal',
            'retryable': false,
            'requiresNewClientRequestId': true,
          },
        }, statusCode: 409);
      });
      final api = CustomSceneApi(
        authenticatedApiClient: AuthenticatedApiClient(
          apiService: _NoRefreshAccountApiService(),
        ),
        dio: dio,
      );

      expect(
        () => api.generate(
          session: _session(),
          persistRefreshedSession: (session) async => session,
          request: const CustomSceneRequestDto(
            installationId: 'install_1',
            babyProfileId: null,
            ageRange: 'm7_11',
            parentGoal: 'natural_opening',
            locale: 'zh-CN',
            customSceneText: '宝宝洗澡时一直躲水。',
            clientRequestId: 'custom_scene_1',
          ),
        ),
        throwsA(
          isA<CustomSceneApiException>()
              .having((error) => error.code, 'code', 'client_request_terminal')
              .having(
                (error) => error.requiresNewClientRequestId,
                'requiresNewClientRequestId',
                isTrue,
              )
              .having(
                (error) => error.toString(),
                'safe toString',
                isNot(contains('宝宝洗澡时一直躲水。')),
              ),
        ),
      );
    });
  });
}

Dio _mockDio(Future<Response<dynamic>> Function(RequestOptions) handler) {
  return Dio(
    BaseOptions(baseUrl: 'http://localhost:8080', validateStatus: (_) => true),
  )..interceptors.add(_MockInterceptor(handler));
}

Response<dynamic> _response(
  RequestOptions options,
  Object? data, {
  int statusCode = 200,
}) {
  return Response<dynamic>(
    requestOptions: options,
    data: data,
    statusCode: statusCode,
  );
}

AccountSession _session() {
  return AccountSession(
    accountId: 'account_1',
    sessionId: 'session_1',
    maskedPhoneNumber: '138****1234',
    createdAt: DateTime.utc(2026, 7, 28),
    accessToken: 'access-live',
    refreshToken: 'refresh-live',
    tokenType: 'Bearer',
    accessTokenExpiresAt: DateTime.utc(2026, 7, 28, 1),
    refreshTokenExpiresAt: DateTime.utc(2026, 8, 28),
  );
}

class _NoRefreshAccountApiService extends AccountApiService {
  _NoRefreshAccountApiService() : super();

  @override
  Future<AccountSessionResponse> refreshSession({
    required String refreshToken,
  }) {
    throw StateError('refresh should not be called');
  }

  @override
  Future<void> close() async {}
}

class _MockInterceptor extends Interceptor {
  _MockInterceptor(this._handler);

  final Future<Response<dynamic>> Function(RequestOptions) _handler;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      handler.resolve(await _handler(options));
    } on Object catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }
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
