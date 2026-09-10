import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/care_entry/data/guest_onboarding_conversation_api.dart';
import 'package:mobile/features/care_entry/data/guest_onboarding_audio_api.dart';
import 'package:mobile/features/care_entry/domain/care_entry_models.dart';
import 'package:mobile/features/care_entry/domain/onboarding_conversation_models.dart';

void main() {
  test('serializes exact guest contract and parses domain result', () async {
    final dio = _mockDio((options) async {
      expect(options.path, '/api/v1/onboarding/conversations');
      expect(options.headers['X-App-Version'], '1.3.0');
      expect(options.data, <String, Object?>{
        'installationId': 'install-test-1234',
        'localEventId': 'onboarding-request-1',
        'careEntryId': 'care.bedtime_soothing',
        'registryRevision': '2026-08-14.1',
        'generationScene': <String, Object?>{
          'namespace': 'babytalk.care',
          'key': 'bedtime',
          'version': 1,
          'facets': <String, String>{'parentTonePreference': 'short_gentle'},
        },
        'locale': 'zh-CN',
        'timeBand': 'evening',
        'babyNickname': null,
      });
      return Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: _response(),
      );
    });

    final result = await GuestOnboardingConversationApi(
      dio: dio,
      audioCapabilities: GuestAudioCapabilityVault(),
    ).create(_request());

    expect(result.conversationId, 'onbc_1');
    expect(result.utterance.english, 'Time to sleep.');
    expect(result.utterance.source, OnboardingUtteranceSource.remoteGenerated);
    expect(result.utterance.remoteAudioAvailable, isTrue);
  });

  test(
    'rejects unknown response fields and does not expose server message',
    () {
      final body = _response()..['prompt'] = 'private server details';
      final api = GuestOnboardingConversationApi(
        audioCapabilities: GuestAudioCapabilityVault(),
        dio: _mockDio(
          (options) async => Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: body,
          ),
        ),
      );

      expect(
        () => api.create(_request()),
        throwsA(
          isA<GuestOnboardingConversationApiException>()
              .having(
                (error) => error.code,
                'code',
                'malformed_onboarding_conversation_response',
              )
              .having(
                (error) => error.toString(),
                'safe error',
                isNot(contains('private server details')),
              ),
        ),
      );
    },
  );

  test('serializes exact no-reaction next-turn contract', () async {
    final vault = GuestAudioCapabilityVault();
    final api = GuestOnboardingConversationApi(
      audioCapabilities: vault,
      dio: _mockDio((options) async {
        expect(options.path, '/api/v1/onboarding/conversations/onbc_1/turns');
        expect(options.headers['X-App-Version'], '1.3.0');
        expect(options.data, <String, Object?>{
          'localEventId': 'next-event-1',
          'previousUtteranceId': 'utterance-1',
          'parentAction': 'said_it',
          'reactionProvided': false,
          'reaction': null,
          'reactionText': null,
          'generationScene': <String, Object?>{
            'namespace': 'babytalk.care',
            'key': 'bedtime',
            'version': 1,
            'facets': <String, String>{'parentTonePreference': 'short_gentle'},
          },
        });
        return Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: <String, Object?>{
            'conversationId': 'onbc_1',
            'expiresAt': '2026-08-15T12:00:00Z',
            'utterance': <String, Object?>{
              'utteranceId': 'utterance-next-1',
              'englishText': 'We can go slowly.',
              'chineseText': '我们可以慢慢来。',
              'pronunciationHint': 'wi kan go slo-li',
              'audioRef': 'next-secret-capability',
              'source': 'remote_generated',
            },
          },
        );
      }),
    );

    final result = await api.nextSupport(
      const NextGuestOnboardingTurn(
        conversationId: 'onbc_1',
        localEventId: 'next-event-1',
        previousUtteranceId: 'utterance-1',
        generationScene: GenerationSceneRef(
          id: GenerationSceneId('generation.bedtime'),
          namespace: 'babytalk.care',
          key: 'bedtime',
          version: 1,
          facets: <String, String>{'parentTonePreference': 'short_gentle'},
        ),
      ),
    );

    expect(result.utterance.english, 'We can go slowly.');
    expect(result.utterance.remoteAudioAvailable, isTrue);
  });

  test(
    'serializes canonical other reaction and bounded private text',
    () async {
      final api = GuestOnboardingConversationApi(
        audioCapabilities: GuestAudioCapabilityVault(),
        dio: _mockDio((options) async {
          final data = options.data as Map<String, Object?>;
          expect(data['reactionProvided'], isTrue);
          expect(data['reaction'], 'other');
          expect(data['reactionText'], '宝宝想抱一会儿');
          return Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: _response(),
          );
        }),
      );

      await api.nextSupport(
        const NextGuestOnboardingTurn(
          conversationId: 'onbc_1',
          localEventId: 'next-event-other',
          previousUtteranceId: 'utterance-1',
          reaction: CareReaction.other,
          reactionText: '宝宝想抱一会儿',
          generationScene: GenerationSceneRef(
            id: GenerationSceneId('generation.bedtime'),
            namespace: 'babytalk.care',
            key: 'bedtime',
            version: 1,
            facets: <String, String>{'parentTonePreference': 'short_gentle'},
          ),
        ),
      );
    },
  );
}

CreateGuestOnboardingConversation _request() =>
    const CreateGuestOnboardingConversation(
      installationId: 'install-test-1234',
      localEventId: 'onboarding-request-1',
      careEntryId: CareEntryId('care.bedtime_soothing'),
      registryRevision: '2026-08-14.1',
      generationScene: GenerationSceneRef(
        id: GenerationSceneId('generation.bedtime'),
        namespace: 'babytalk.care',
        key: 'bedtime',
        version: 1,
        facets: <String, String>{'parentTonePreference': 'short_gentle'},
      ),
      locale: 'zh-CN',
      timeBand: 'evening',
    );

Map<String, Object?> _response() => <String, Object?>{
  'conversationId': 'onbc_1',
  'expiresAt': '2026-08-15T12:00:00Z',
  'utterance': <String, Object?>{
    'utteranceId': 'utterance-1',
    'englishText': 'Time to sleep.',
    'chineseText': '该睡觉啦。',
    'pronunciationHint': 'taim tu sliip',
    'audioRef': 'secret-capability',
    'source': 'remote_generated',
  },
};

Dio _mockDio(Future<Response<dynamic>> Function(RequestOptions) handler) => Dio(
  BaseOptions(baseUrl: 'http://localhost:8080', validateStatus: (_) => true),
)..interceptors.add(_MockInterceptor(handler));

final class _MockInterceptor extends Interceptor {
  _MockInterceptor(this.handler);
  final Future<Response<dynamic>> Function(RequestOptions) handler;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler next) async {
    next.resolve(await handler(options));
  }
}
