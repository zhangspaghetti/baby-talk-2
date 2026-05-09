import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/practice/data/services/dynamic_practice_api_service.dart';

/// Mock interceptor that simulates HTTP responses for testing.
class _MockInterceptor extends Interceptor {
  _MockInterceptor(this._handler);
  final Future<Response<dynamic>> Function(RequestOptions options) _handler;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final response = await _handler(options);
      handler.resolve(response);
    } catch (error) {
      if (error is DioException) {
        handler.reject(error);
      } else {
        handler.reject(
          DioException(
            requestOptions: options,
            error: error,
            type: DioExceptionType.unknown,
          ),
        );
      }
    }
  }
}

Dio _createMockDio(
  Future<Response<dynamic>> Function(RequestOptions options) handler,
) {
  return Dio(
    BaseOptions(
      baseUrl: 'http://localhost:8080',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
      validateStatus: (status) => true,
    ),
  )..interceptors.add(_MockInterceptor(handler));
}

void main() {
  group('DynamicPracticeApiService', () {
    late DynamicPracticeApiService service;

    DynamicPracticeApiService createService(Dio dio) {
      return DynamicPracticeApiService(dio: dio);
    }

    test('解析合法 JSON 响应 — activities 和 phrases 正确映射', () async {
      final dio = _createMockDio((options) async {
        expect(options.method, 'POST');
        expect(options.path, '/api/v1/mentor/practice/generate');
        final body = options.data as Map<String, dynamic>;
        expect(body['installationId'], 'test-install');
        expect(body['babyAgeMonths'], 6);
        expect(body['surface'], 'practice');

        return Response(
          requestOptions: options,
          data: {
            'activities': [
              {
                'title': 'Morning Greeting',
                'summary': 'Say hello in the morning',
                'sceneTag': 'morning',
                'coachTip': '温柔地对宝宝说',
                'phrases': [
                  {
                    'english': 'Good morning, baby!',
                    'chinese': '早上好，宝宝！',
                    'pronunciation': '/ɡʊd ˈmɔːrnɪŋ/',
                    'difficulty': 'easy',
                  },
                  {
                    'english': 'Time to wake up!',
                    'chinese': '起床时间到了！',
                    'pronunciation': '/taɪm tə weɪk ʌp/',
                    'difficulty': 'medium',
                  },
                ],
              },
            ],
          },
          statusCode: 200,
          headers: Headers.fromMap({
            'content-type': ['application/json'],
          }),
        );
      });

      service = createService(dio);
      final response = await service.generatePractice(
        installationId: 'test-install',
        babyAgeMonths: 6,
      );

      expect(response.activities, hasLength(1));
      final activity = response.activities.first;
      expect(activity.title, 'Morning Greeting');
      expect(activity.summary, 'Say hello in the morning');
      expect(activity.sceneTag, 'morning');
      expect(activity.coachTip, '温柔地对宝宝说');
      expect(activity.phrases, hasLength(2));

      final first = activity.phrases[0];
      expect(first.english, 'Good morning, baby!');
      expect(first.chinese, '早上好，宝宝！');
      expect(first.pronunciation, '/ɡʊd ˈmɔːrnɪŋ/');
      expect(first.difficulty, 'easy');

      final second = activity.phrases[1];
      expect(second.english, 'Time to wake up!');
      expect(second.difficulty, 'medium');
    });

    test('空 activities 列表正常处理', () async {
      final dio = _createMockDio((options) async {
        return Response(
          requestOptions: options,
          data: {'activities': []},
          statusCode: 200,
          headers: Headers.fromMap({
            'content-type': ['application/json'],
          }),
        );
      });

      service = createService(dio);
      final response = await service.generatePractice(
        installationId: 'test-install',
        babyAgeMonths: 3,
      );
      expect(response.activities, isEmpty);
    });

    test('可选参数 sceneTag 和 conversationId 正确传递', () async {
      final dio = _createMockDio((options) async {
        final body = options.data as Map<String, dynamic>;
        expect(body['sceneTag'], 'bedtime');
        expect(body['conversationId'], 'conv-123');
        return Response(
          requestOptions: options,
          data: {'activities': []},
          statusCode: 200,
          headers: Headers.fromMap({
            'content-type': ['application/json'],
          }),
        );
      });

      service = createService(dio);
      await service.generatePractice(
        installationId: 'test-install',
        babyAgeMonths: 8,
        sceneTag: 'bedtime',
        conversationId: 'conv-123',
      );
    });

    test('accessToken 存在时带上 Authorization 头', () async {
      final dio = _createMockDio((options) async {
        expect(
          options.headers[HttpHeaders.authorizationHeader],
          'Bearer token-123',
        );
        return Response(
          requestOptions: options,
          data: {'activities': []},
          statusCode: 200,
          headers: Headers.fromMap({
            'content-type': ['application/json'],
          }),
        );
      });

      service = createService(dio);
      await service.generatePractice(
        installationId: 'test-install',
        babyAgeMonths: 8,
        accessToken: ' token-123 ',
      );
    });

    test('非 JSON 响应抛出 malformed 异常', () async {
      final dio = _createMockDio((options) async {
        return Response(
          requestOptions: options,
          data: 'This is not JSON at all',
          statusCode: 200,
          headers: Headers.fromMap({
            'content-type': ['text/plain'],
          }),
        );
      });

      service = createService(dio);
      expect(
        () => service.generatePractice(
          installationId: 'test-install',
          babyAgeMonths: 6,
        ),
        throwsA(
          isA<DynamicPracticeApiException>().having(
            (e) => e.kind,
            'kind',
            DynamicPracticeFailureKind.malformed,
          ),
        ),
      );
    });

    test('HTTP 500 响应抛出 http 异常', () async {
      final dio = _createMockDio((options) async {
        return Response(
          requestOptions: options,
          data: {'error': 'internal'},
          statusCode: 500,
          headers: Headers.fromMap({
            'content-type': ['application/json'],
          }),
        );
      });

      service = createService(dio);
      expect(
        () => service.generatePractice(
          installationId: 'test-install',
          babyAgeMonths: 6,
        ),
        throwsA(
          isA<DynamicPracticeApiException>()
              .having((e) => e.kind, 'kind', DynamicPracticeFailureKind.http)
              .having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });

    test('网络异常抛出 network 异常', () async {
      final dio = _createMockDio((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const SocketException('Connection refused'),
        );
      });

      service = createService(dio);
      expect(
        () => service.generatePractice(
          installationId: 'test-install',
          babyAgeMonths: 6,
        ),
        throwsA(
          isA<DynamicPracticeApiException>().having(
            (e) => e.kind,
            'kind',
            DynamicPracticeFailureKind.network,
          ),
        ),
      );
    });

    test('DynamicPracticeResponse.fromJson 处理缺失字段', () {
      final response = DynamicPracticeResponse.fromJson(<String, dynamic>{});
      expect(response.activities, isEmpty);
    });

    test('DynamicActivity.fromJson 字段缺失时返回空字符串', () {
      final activity = DynamicActivity.fromJson(<String, dynamic>{
        'title': 'Test',
        'phrases': [],
      });
      expect(activity.title, 'Test');
      expect(activity.summary, '');
      expect(activity.sceneTag, '');
      expect(activity.coachTip, '');
      expect(activity.phrases, isEmpty);
    });
  });
}
