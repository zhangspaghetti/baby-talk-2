import 'dart:convert';

import 'package:baby_talk_mobile/data/app_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('adds X-App-Version header to coach requests', () async {
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

    final reply = await client.askCoach(prompt: '洗澡怎么开口');
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
      client.askCoach(prompt: '哭闹时怎么办'),
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
}
