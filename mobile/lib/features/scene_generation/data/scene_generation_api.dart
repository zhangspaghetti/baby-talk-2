import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:mobile/core/network/app_dio.dart';
import 'package:mobile/core/network/auth_headers.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/scene_generation/data/scene_generation_dtos.dart';

const _standardErrorKeys = <String>{
  'timestamp',
  'status',
  'code',
  'message',
  'details',
};
const _standardErrorKeysWithCorrelation = <String>{
  ..._standardErrorKeys,
  'correlationId',
};
const _standardErrorKeysWithoutDetails = <String>{
  'timestamp',
  'status',
  'code',
  'message',
};
const _standardErrorKeysWithCorrelationWithoutDetails = <String>{
  ..._standardErrorKeysWithoutDetails,
  'correlationId',
};
const _versionErrorKeys = <String>{
  'code',
  'message',
  'minimumSupportedVersion',
  'upgradeUrl',
  'details',
  'correlationId',
};
const _versionErrorKeysWithoutDetails = <String>{
  'code',
  'message',
  'minimumSupportedVersion',
  'upgradeUrl',
  'correlationId',
};
const _rateLimitCodes = <String>{
  'custom_scene_rate_limited',
  'generation_rate_limited',
  'scene_generation_rate_limited',
  'rate_limited',
};

enum SceneGenerationApiFailureKind {
  network,
  timeout,
  malformed,
  http,
  unexpected,
}

class SceneGenerationApiException implements Exception {
  const SceneGenerationApiException({
    required this.kind,
    this.statusCode,
    this.code,
    this.retryable = false,
    this.generatedContentId,
    this.requiresNewClientRequestId = false,
  });

  const SceneGenerationApiException.network()
    : this(kind: SceneGenerationApiFailureKind.network);

  const SceneGenerationApiException.timeout()
    : this(kind: SceneGenerationApiFailureKind.timeout);

  const SceneGenerationApiException.malformed()
    : this(kind: SceneGenerationApiFailureKind.malformed);

  const SceneGenerationApiException.unexpected()
    : this(kind: SceneGenerationApiFailureKind.unexpected);

  const SceneGenerationApiException.http({
    required int statusCode,
    String? code,
    bool retryable = false,
    String? generatedContentId,
    bool requiresNewClientRequestId = false,
  }) : this(
         kind: SceneGenerationApiFailureKind.http,
         statusCode: statusCode,
         code: code,
         retryable: retryable,
         generatedContentId: generatedContentId,
         requiresNewClientRequestId: requiresNewClientRequestId,
       );

  final SceneGenerationApiFailureKind kind;
  final int? statusCode;
  final String? code;
  final bool retryable;
  final String? generatedContentId;
  final bool requiresNewClientRequestId;

  bool get isUnauthorized => statusCode == 401 || code == 'invalid_session';

  @override
  String toString() {
    return 'SceneGenerationApiException(kind: $kind, statusCode: $statusCode, '
        'code: $code, retryable: $retryable)';
  }
}

abstract interface class SceneGenerationApiGateway {
  Future<SceneGenerationResponseDto> generate({
    required AccountSession session,
    required PersistRefreshedSession persistRefreshedSession,
    required SceneGenerationRequestDto request,
  });
}

class SceneGenerationApi implements SceneGenerationApiGateway {
  SceneGenerationApi({
    required AuthenticatedApiClient authenticatedApiClient,
    Dio? dio,
    String? baseUrl,
    this.appVersion = defaultAccountApiVersion,
    this.timeout = const Duration(seconds: 60),
  }) : _authenticatedApiClient = authenticatedApiClient,
       _dio =
           dio ?? AppDio.create(baseUrl: baseUrl ?? defaultAccountApiBaseUrl),
       _ownsDio = dio == null;

  final AuthenticatedApiClient _authenticatedApiClient;
  final Dio _dio;
  final bool _ownsDio;
  final String appVersion;
  final Duration timeout;

  @override
  Future<SceneGenerationResponseDto> generate({
    required AccountSession session,
    required PersistRefreshedSession persistRefreshedSession,
    required SceneGenerationRequestDto request,
  }) async {
    try {
      final authenticated = await _authenticatedApiClient
          .execute<SceneGenerationResponseDto>(
            session: session,
            persistRefreshedSession: persistRefreshedSession,
            send: (accessToken) async {
              try {
                return await _post(accessToken: accessToken, request: request);
              } on SceneGenerationApiException catch (error) {
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
    } on AuthenticatedApiClientException catch (error) {
      throw _mapAuthenticatedFailure(error);
    }
  }

  Future<SceneGenerationResponseDto> _post({
    required String accessToken,
    required SceneGenerationRequestDto request,
  }) async {
    final authorization = buildBearerAuthorizationHeaderValue(accessToken);
    Response<dynamic> response;
    try {
      response = await _dio.request<dynamic>(
        '/api/v1/practice/scene-generations',
        data: request.toJson(),
        options: Options(
          method: 'POST',
          headers: <String, String>{
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'X-App-Version': appVersion,
            authorizationHeaderName: ?authorization,
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
        throw const SceneGenerationApiException.timeout();
      }
      if (error.error is SocketException ||
          error.type == DioExceptionType.connectionError) {
        throw const SceneGenerationApiException.network();
      }
      throw const SceneGenerationApiException.network();
    } on SceneGenerationApiException {
      rethrow;
    } on Object {
      throw const SceneGenerationApiException.network();
    }

    final statusCode = response.statusCode ?? 0;
    final decoded = _decodeObject(response.data);
    if (statusCode < 200 || statusCode >= 300) {
      throw _parseHttpFailure(decoded, statusCode);
    }

    try {
      return SceneGenerationResponseDto.fromJson(decoded);
    } on SceneGenerationApiException {
      rethrow;
    } on Object {
      throw const SceneGenerationApiException.malformed();
    }
  }

  SceneGenerationApiException _parseHttpFailure(
    Map<String, dynamic> json,
    int statusCode,
  ) {
    final keys = json.keys.toSet();
    final code = json['code'];
    final isKnownRateLimit =
        statusCode == 429 || code is String && _rateLimitCodes.contains(code);
    final standard =
        _isExactErrorKeys(keys, _standardErrorKeys) ||
        _isExactErrorKeys(keys, _standardErrorKeysWithCorrelation);
    final standardMissingDetails =
        isKnownRateLimit &&
        (_isExactErrorKeys(keys, _standardErrorKeysWithoutDetails) ||
            _isExactErrorKeys(
              keys,
              _standardErrorKeysWithCorrelationWithoutDetails,
            ));
    final version = _isExactErrorKeys(keys, _versionErrorKeys);
    final versionMissingDetails =
        isKnownRateLimit &&
        _isExactErrorKeys(keys, _versionErrorKeysWithoutDetails);

    if (!standard &&
        !standardMissingDetails &&
        !version &&
        !versionMissingDetails) {
      throw const SceneGenerationApiException.malformed();
    }
    if (code is! String || code.trim().isEmpty) {
      throw const SceneGenerationApiException.malformed();
    }

    if (standard || standardMissingDetails) {
      final responseStatus = json['status'];
      final timestamp = json['timestamp'];
      final message = json['message'];
      final correlationId = json['correlationId'];
      if (responseStatus is! int ||
          responseStatus != statusCode ||
          timestamp is! String ||
          timestamp.trim().isEmpty ||
          message is! String ||
          message.trim().isEmpty ||
          correlationId != null &&
              (correlationId is! String || correlationId.trim().isEmpty)) {
        throw const SceneGenerationApiException.malformed();
      }
    } else {
      final message = json['message'];
      final minimumSupportedVersion = json['minimumSupportedVersion'];
      final upgradeUrl = json['upgradeUrl'];
      final correlationId = json['correlationId'];
      if (message is! String ||
          message.trim().isEmpty ||
          minimumSupportedVersion is! String ||
          minimumSupportedVersion.trim().isEmpty ||
          upgradeUrl is! String ||
          upgradeUrl.trim().isEmpty ||
          correlationId is! String ||
          correlationId.trim().isEmpty) {
        throw const SceneGenerationApiException.malformed();
      }
    }

    final rawDetails = json['details'];
    final Map<String, dynamic> detailsMap;
    if (rawDetails is Map) {
      try {
        detailsMap = _asStringKeyedMap(rawDetails);
      } on Object {
        throw const SceneGenerationApiException.malformed();
      }
    } else if (isKnownRateLimit) {
      detailsMap = const <String, dynamic>{};
    } else {
      throw const SceneGenerationApiException.malformed();
    }

    final generatedContentId = detailsMap['generatedContentId'];
    final retryable = detailsMap['retryable'];
    final requiresNewClientRequestId = detailsMap['requiresNewClientRequestId'];
    if (generatedContentId != null &&
            (generatedContentId is! String ||
                generatedContentId.trim().isEmpty) ||
        retryable != null && retryable is! bool ||
        requiresNewClientRequestId != null &&
            requiresNewClientRequestId is! bool) {
      throw const SceneGenerationApiException.malformed();
    }

    return SceneGenerationApiException.http(
      statusCode: statusCode,
      code: code,
      retryable: retryable == true,
      generatedContentId: generatedContentId as String?,
      requiresNewClientRequestId: requiresNewClientRequestId == true,
    );
  }

  Map<String, dynamic> _decodeObject(Object? data) {
    try {
      if (data is String) {
        if (data.trim().isEmpty) {
          throw const FormatException('empty scene generation response');
        }
        return _asStringKeyedMap(jsonDecode(data));
      }
      return _asStringKeyedMap(data);
    } on SceneGenerationApiException {
      rethrow;
    } on Object {
      throw const SceneGenerationApiException.malformed();
    }
  }

  Map<String, dynamic> _asStringKeyedMap(Object? value) {
    if (value is! Map) {
      throw const FormatException('scene generation response is not an object');
    }
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw const FormatException(
          'scene generation response has invalid key',
        );
      }
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  SceneGenerationApiException _mapAuthenticatedFailure(
    AuthenticatedApiClientException error,
  ) {
    switch (error.kind) {
      case AuthenticatedApiClientFailureKind.missingCredentials:
      case AuthenticatedApiClientFailureKind.sessionExpired:
        return const SceneGenerationApiException.http(
          statusCode: 401,
          code: 'invalid_session',
        );
      case AuthenticatedApiClientFailureKind.refreshTimeout:
        return const SceneGenerationApiException.timeout();
      case AuthenticatedApiClientFailureKind.refreshNetwork:
        return const SceneGenerationApiException.network();
      case AuthenticatedApiClientFailureKind.refreshMalformed:
        return const SceneGenerationApiException.malformed();
      case AuthenticatedApiClientFailureKind.refreshFailed:
      case AuthenticatedApiClientFailureKind.persistenceFailure:
        return const SceneGenerationApiException.unexpected();
    }
  }

  void close() {
    if (_ownsDio) {
      _dio.close();
    }
  }
}

bool _isExactErrorKeys(Set<String> actual, Set<String> expected) {
  return actual.length == expected.length && actual.containsAll(expected);
}
