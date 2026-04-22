import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:mobile/features/practice/data/services/dynamic_practice_api_service.dart';

void main() {
  group('DynamicPracticeApiService', () {
    late DynamicPracticeApiService service;

    DynamicPracticeApiService createService(http.Client client) {
      return DynamicPracticeApiService(
        client: client,
        baseUri: Uri.parse('http://localhost:8080'),
      );
    }

    test('解析合法 JSON 响应 — activities 和 phrases 正确映射', () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/mentor/practice/generate');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['installationId'], 'test-install');
        expect(body['babyAgeMonths'], 6);
        expect(body['surface'], 'practice');

        return http.Response(
          jsonEncode({
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
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      service = createService(mockClient);
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
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          jsonEncode({'activities': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      service = createService(mockClient);
      final response = await service.generatePractice(
        installationId: 'test-install',
        babyAgeMonths: 3,
      );
      expect(response.activities, isEmpty);
    });

    test('可选参数 sceneTag 和 conversationId 正确传递', () async {
      final mockClient = http_testing.MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['sceneTag'], 'bedtime');
        expect(body['conversationId'], 'conv-123');
        return http.Response(
          jsonEncode({'activities': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      service = createService(mockClient);
      await service.generatePractice(
        installationId: 'test-install',
        babyAgeMonths: 8,
        sceneTag: 'bedtime',
        conversationId: 'conv-123',
      );
    });

    test('非 JSON 响应抛出 malformed 异常', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          'This is not JSON at all',
          200,
          headers: {'content-type': 'text/plain'},
        );
      });

      service = createService(mockClient);
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
      final mockClient = http_testing.MockClient((request) async {
        return http.Response(
          '{"error":"internal"}',
          500,
          headers: {'content-type': 'application/json'},
        );
      });

      service = createService(mockClient);
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
      final mockClient = http_testing.MockClient((request) async {
        throw const SocketException('Connection refused');
      });

      service = createService(mockClient);
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
