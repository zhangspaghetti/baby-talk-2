import 'dart:convert';

import 'package:baby_talk_mobile/data/app_api_client.dart';
import 'package:baby_talk_mobile/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('adds version and session headers to coach requests', () async {
    final client = HttpBabyTalkApiClient(
      baseUrl: 'http://example.com',
      appVersion: '1.0.0+1',
      httpClient: MockClient((request) async {
        expect(
          request.headers.entries.any(
            (entry) =>
                entry.key.toLowerCase() == 'x-app-version' &&
                entry.value == '1.0.0+1',
          ),
          isTrue,
        );
        expect(
          request.headers.entries.any(
            (entry) =>
                entry.key.toLowerCase() == 'x-session-id' &&
                entry.value == 'session-1',
          ),
          isTrue,
        );
        return http.Response(
          jsonEncode({
            'answer': '先陪我试一句。',
            'suggestedPhraseEnglish': 'Try one short phrase.',
            'suggestedPhraseChinese': '先试一句短的。',
            'followUpPrompt': '你想练洗澡还是喂饭？',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final reply = await client.askCoach(
      sessionId: 'session-1',
      prompt: '洗澡怎么开口',
    );
    expect(reply.answer, '先陪我试一句。');
  });

  test('fetchVersionStatus rejects unsupported app version', () async {
    final client = HttpBabyTalkApiClient(
      baseUrl: 'http://example.com',
      appVersion: '0.9.0',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/config/version');
        expect(
          request.headers.keys.any(
            (key) => key.toLowerCase() == 'x-app-version',
          ),
          isFalse,
        );
        return http.Response(
          jsonEncode({
            'currentVersion': '1.0.0',
            'minSupportedVersion': '1.0.0',
            'requestedVersion': null,
            'upgradeRequired': false,
            'message': '当前最低支持版本是 1.0.0。',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    expect(
      client.fetchVersionStatus(),
      throwsA(
        isA<BabyTalkUpgradeRequiredException>()
            .having(
              (error) => error.minSupportedVersion,
              'minSupportedVersion',
              '1.0.0',
            )
            .having((error) => error.appVersion, 'appVersion', '0.9.0'),
      ),
    );
  });

  test('creates session and maps 401 to session exception', () async {
    final client = HttpBabyTalkApiClient(
      baseUrl: 'http://example.com',
      appVersion: '1.0.0+1',
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/v1/auth/session') {
          return http.Response(
            jsonEncode({'sessionId': 'session-1'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response(
          '',
          401,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final sessionId = await client.createSession();
    expect(sessionId, 'session-1');

    expect(
      client.fetchBootstrap(sessionId: sessionId),
      throwsA(isA<BabyTalkSessionExpiredException>()),
    );
  });

  test('maps 426 responses to upgrade exceptions', () async {
    final client = HttpBabyTalkApiClient(
      baseUrl: 'http://example.com',
      appVersion: '0.9.0',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'currentVersion': '1.0.0',
            'minSupportedVersion': '1.0.0',
            'requestedVersion': '0.9.0',
            'upgradeRequired': true,
            'message': '当前 App 版本 0.9.0 过旧，请升级到 1.0.0 或更高版本。',
          }),
          426,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    expect(
      client.askCoach(sessionId: 'session-1', prompt: '哭闹时怎么办'),
      throwsA(
        isA<BabyTalkUpgradeRequiredException>()
            .having((error) => error.currentVersion, 'currentVersion', '1.0.0')
            .having(
              (error) => error.minSupportedVersion,
              'minSupportedVersion',
              '1.0.0',
            ),
      ),
    );
  });

  test('uploads analytics events with session and version headers', () async {
    final client = HttpBabyTalkApiClient(
      baseUrl: 'http://example.com',
      appVersion: '1.0.0+1',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/analytics/events');
        expect(request.method, 'POST');
        expect(request.headers['X-App-Version'], '1.0.0+1');
        expect(request.headers['X-Session-Id'], 'session-1');

        final decoded = jsonDecode(request.body) as Map<String, dynamic>;
        final events = decoded['events'] as List<dynamic>;
        expect(events, hasLength(1));
        expect(
          (events.first as Map<String, dynamic>)['eventName'],
          'app_opened',
        );

        return http.Response(
          jsonEncode({'acceptedCount': 1}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await client.uploadAnalyticsEvents(
      sessionId: 'session-1',
      events: [
        AnalyticsEvent(
          eventId: 'evt-1',
          eventName: 'app_opened',
          occurredAt: DateTime.utc(2026, 4, 6, 9),
          screenName: 'home',
        ),
      ],
    );
  });
}
