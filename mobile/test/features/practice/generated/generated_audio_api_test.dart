import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/auth_headers.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/care_path/data/audio/generated_audio_api.dart';

void main() {
  test(
    'uses authenticated approved-utterance audio route and validates bytes',
    () async {
      final api = GeneratedAudioApi(
        authenticatedApiClient: AuthenticatedApiClient(
          apiService: _NoRefreshAccountApiService(),
        ),
        dio: _mockDio((options) async {
          expect(options.method, 'GET');
          expect(
            options.path,
            '/api/v1/practice/generated-content/pgc_1/utterances/utt_1/audio',
          );
          expect(
            options.headers[authorizationHeaderName],
            'Bearer access-live',
          );
          expect(options.headers['Accept'], 'audio/mpeg');
          return _response(
            options,
            Uint8List.fromList(<int>[1, 2, 3]),
            headers: <String, List<String>>{
              'content-type': <String>['audio/mpeg'],
              'x-generated-audio-voice-version': <String>['generated-tts-v1'],
            },
          );
        }),
      );

      final result = await api.fetch(
        session: _session(),
        persistRefreshedSession: (session) async => session,
        generatedContentId: 'pgc_1',
        utteranceId: 'utt_1',
        expectedVoiceVersion: 'generated-tts-v1',
        expectedFormat: 'mp3',
      );

      expect(result.bytes, <int>[1, 2, 3]);
      expect(result.mimeType, 'audio/mpeg');
    },
  );

  test('rejects empty, oversized, or wrong-MIME audio response', () async {
    for (final response in <_AudioResponse>[
      _AudioResponse(Uint8List(0), 'audio/mpeg'),
      _AudioResponse(Uint8List(513 * 1024), 'audio/mpeg'),
      _AudioResponse(Uint8List.fromList(<int>[1]), 'audio/wav'),
    ]) {
      final api = GeneratedAudioApi(
        authenticatedApiClient: AuthenticatedApiClient(
          apiService: _NoRefreshAccountApiService(),
        ),
        dio: _mockDio(
          (options) async => _response(
            options,
            response.bytes,
            headers: <String, List<String>>{
              'content-type': <String>[response.mimeType],
              'x-generated-audio-voice-version': <String>['generated-tts-v1'],
            },
          ),
        ),
      );

      expect(
        () => api.fetch(
          session: _session(),
          persistRefreshedSession: (session) async => session,
          generatedContentId: 'pgc_1',
          utteranceId: 'utt_1',
          expectedVoiceVersion: 'generated-tts-v1',
          expectedFormat: 'mp3',
        ),
        throwsA(
          isA<GeneratedAudioApiException>().having(
            (error) => error.kind,
            'kind',
            GeneratedAudioApiFailureKind.malformed,
          ),
        ),
      );
    }
  });
}

class _AudioResponse {
  const _AudioResponse(this.bytes, this.mimeType);

  final Uint8List bytes;
  final String mimeType;
}

Dio _mockDio(Future<Response<dynamic>> Function(RequestOptions) handler) {
  return Dio(
    BaseOptions(baseUrl: 'http://localhost:8080', validateStatus: (_) => true),
  )..interceptors.add(_MockInterceptor(handler));
}

Response<dynamic> _response(
  RequestOptions options,
  Object? data, {
  Map<String, List<String>>? headers,
}) {
  return Response<dynamic>(
    requestOptions: options,
    data: data,
    statusCode: 200,
    headers: headers == null ? null : Headers.fromMap(headers),
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
