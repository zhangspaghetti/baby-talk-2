import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mobile/core/network/app_dio.dart';
import 'package:mobile/core/network/auth_headers.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/care_path/data/audio/generated_audio_memory_cache.dart';

enum GeneratedAudioApiFailureKind { network, timeout, malformed, http }

class GeneratedAudioApiException implements Exception {
  const GeneratedAudioApiException({
    required this.kind,
    this.statusCode,
    this.code,
  });

  final GeneratedAudioApiFailureKind kind;
  final int? statusCode;
  final String? code;

  bool get isUnauthorized => statusCode == 401 || code == 'invalid_session';
}

abstract interface class GeneratedAudioGateway {
  Future<GeneratedAudioPayload> fetch({
    required AccountSession session,
    required PersistRefreshedSession persistRefreshedSession,
    required String generatedContentId,
    required String utteranceId,
    required String expectedVoiceVersion,
    required String expectedFormat,
  });
}

class GeneratedAudioApi implements GeneratedAudioGateway {
  GeneratedAudioApi({
    required AuthenticatedApiClient authenticatedApiClient,
    Dio? dio,
    String? baseUrl,
    this.appVersion = defaultAccountApiVersion,
    this.timeout = const Duration(seconds: 10),
    this.maxBytes = 512 * 1024,
  }) : _authenticatedApiClient = authenticatedApiClient,
       _dio =
           dio ?? AppDio.create(baseUrl: baseUrl ?? defaultAccountApiBaseUrl),
       _ownsDio = dio == null;

  final AuthenticatedApiClient _authenticatedApiClient;
  final Dio _dio;
  final bool _ownsDio;
  final String appVersion;
  final Duration timeout;
  final int maxBytes;

  @override
  Future<GeneratedAudioPayload> fetch({
    required AccountSession session,
    required PersistRefreshedSession persistRefreshedSession,
    required String generatedContentId,
    required String utteranceId,
    required String expectedVoiceVersion,
    required String expectedFormat,
  }) async {
    try {
      final authenticated = await _authenticatedApiClient
          .execute<GeneratedAudioPayload>(
            session: session,
            persistRefreshedSession: persistRefreshedSession,
            send: (accessToken) async {
              try {
                return await _get(
                  accessToken: accessToken,
                  generatedContentId: generatedContentId,
                  utteranceId: utteranceId,
                  expectedVoiceVersion: expectedVoiceVersion,
                  expectedFormat: expectedFormat,
                );
              } on GeneratedAudioApiException catch (error) {
                if (!error.isUnauthorized) {
                  rethrow;
                }
                throw AccountApiException(
                  kind: AccountApiFailureKind.http,
                  message: '认证状态失效。',
                  statusCode: error.statusCode,
                  code: error.code,
                );
              }
            },
          );
      return authenticated.value;
    } on AuthenticatedApiClientException {
      throw const GeneratedAudioApiException(
        kind: GeneratedAudioApiFailureKind.http,
        statusCode: 401,
        code: 'invalid_session',
      );
    }
  }

  Future<GeneratedAudioPayload> _get({
    required String accessToken,
    required String generatedContentId,
    required String utteranceId,
    required String expectedVoiceVersion,
    required String expectedFormat,
  }) async {
    final authorization = buildBearerAuthorizationHeaderValue(accessToken);
    if (authorization == null) {
      throw const GeneratedAudioApiException(
        kind: GeneratedAudioApiFailureKind.http,
        statusCode: 401,
        code: 'invalid_session',
      );
    }
    Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(
        '/api/v1/practice/generated-content/$generatedContentId/utterances/$utteranceId/audio',
        options: Options(
          responseType: ResponseType.bytes,
          headers: <String, String>{
            'Accept': 'audio/mpeg, application/json',
            'X-App-Version': appVersion,
            authorizationHeaderName: authorization,
          },
          sendTimeout: timeout,
          receiveTimeout: timeout,
          validateStatus: (_) => true,
        ),
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        throw const GeneratedAudioApiException(
          kind: GeneratedAudioApiFailureKind.timeout,
        );
      }
      if (error.error is SocketException ||
          error.type == DioExceptionType.connectionError) {
        throw const GeneratedAudioApiException(
          kind: GeneratedAudioApiFailureKind.network,
        );
      }
      throw const GeneratedAudioApiException(
        kind: GeneratedAudioApiFailureKind.network,
      );
    }

    final statusCode = response.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      throw GeneratedAudioApiException(
        kind: GeneratedAudioApiFailureKind.http,
        statusCode: statusCode,
      );
    }
    final mimeType = response.headers
        .value('content-type')
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    final voiceVersion = response.headers
        .value('x-generated-audio-voice-version')
        ?.trim();
    final bytes = response.data;
    if (mimeType != 'audio/mpeg' ||
        expectedFormat != 'mp3' ||
        voiceVersion == null ||
        voiceVersion != expectedVoiceVersion ||
        bytes is! List<int> ||
        bytes.isEmpty ||
        bytes.length > maxBytes) {
      throw const GeneratedAudioApiException(
        kind: GeneratedAudioApiFailureKind.malformed,
      );
    }
    return GeneratedAudioPayload(
      bytes: Uint8List.fromList(bytes),
      mimeType: 'audio/mpeg',
      voiceVersion: voiceVersion,
    );
  }

  void close() {
    if (_ownsDio) {
      _dio.close();
    }
  }
}
