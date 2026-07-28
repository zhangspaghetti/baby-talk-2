import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:mobile/core/network/app_dio.dart';
import 'package:mobile/core/network/auth_headers.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/custom_scene/data/custom_scene_dtos.dart';

enum CustomSceneApiFailureKind { network, timeout, malformed, http }

class CustomSceneApiException implements Exception {
  const CustomSceneApiException({
    required this.kind,
    this.statusCode,
    this.code,
    this.retryable = false,
    this.generatedContentId,
    this.requiresNewClientRequestId = false,
  });

  const CustomSceneApiException.network()
    : this(kind: CustomSceneApiFailureKind.network);

  const CustomSceneApiException.timeout()
    : this(kind: CustomSceneApiFailureKind.timeout);

  const CustomSceneApiException.malformed()
    : this(kind: CustomSceneApiFailureKind.malformed);

  final CustomSceneApiFailureKind kind;
  final int? statusCode;
  final String? code;
  final bool retryable;
  final String? generatedContentId;
  final bool requiresNewClientRequestId;

  bool get isUnauthorized => statusCode == 401 || code == 'invalid_session';

  @override
  String toString() {
    return 'CustomSceneApiException(kind: $kind, statusCode: $statusCode, '
        'code: $code, retryable: $retryable)';
  }
}

abstract interface class CustomSceneDiscoveryGateway {
  Future<CustomSceneDiscoveryResponseDto> generate({
    required AccountSession session,
    required PersistRefreshedSession persistRefreshedSession,
    required CustomSceneRequestDto request,
  });
}

class CustomSceneApi implements CustomSceneDiscoveryGateway {
  CustomSceneApi({
    required AuthenticatedApiClient authenticatedApiClient,
    Dio? dio,
    String? baseUrl,
    this.appVersion = defaultAccountApiVersion,
    this.timeout = const Duration(seconds: 15),
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
  Future<CustomSceneDiscoveryResponseDto> generate({
    required AccountSession session,
    required PersistRefreshedSession persistRefreshedSession,
    required CustomSceneRequestDto request,
  }) async {
    try {
      final authenticated = await _authenticatedApiClient
          .execute<CustomSceneDiscoveryResponseDto>(
            session: session,
            persistRefreshedSession: persistRefreshedSession,
            send: (accessToken) async {
              try {
                return await _post(accessToken: accessToken, request: request);
              } on CustomSceneApiException catch (error) {
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
      throw CustomSceneApiException(
        kind: CustomSceneApiFailureKind.http,
        statusCode: 401,
        code: 'invalid_session',
        retryable: false,
      );
    }
  }

  Future<CustomSceneDiscoveryResponseDto> _post({
    required String accessToken,
    required CustomSceneRequestDto request,
  }) async {
    final authorization = buildBearerAuthorizationHeaderValue(accessToken);
    Response<dynamic> response;
    try {
      response = await _dio.request<dynamic>(
        '/api/v1/practice/discovery',
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
        throw const CustomSceneApiException.timeout();
      }
      if (error.error is SocketException ||
          error.type == DioExceptionType.connectionError) {
        throw const CustomSceneApiException.network();
      }
      throw const CustomSceneApiException.network();
    }

    final statusCode = response.statusCode ?? 0;
    final decoded = _decodeObject(response.data);
    if (statusCode < 200 || statusCode >= 300) {
      final error = _parseError(decoded);
      if (error.status != statusCode) {
        throw const CustomSceneApiException.malformed();
      }
      throw CustomSceneApiException(
        kind: CustomSceneApiFailureKind.http,
        statusCode: statusCode,
        code: error.code,
        retryable: error.retryable,
        generatedContentId: error.generatedContentId,
        requiresNewClientRequestId: error.requiresNewClientRequestId,
      );
    }

    try {
      return CustomSceneDiscoveryResponseDto.fromJson(decoded);
    } on FormatException {
      throw const CustomSceneApiException.malformed();
    }
  }

  Map<String, dynamic> _decodeObject(Object? data) {
    try {
      if (data is String) {
        if (data.trim().isEmpty) {
          throw const FormatException('空响应。');
        }
        return _toStringKeyedMap(jsonDecode(data));
      }
      return _toStringKeyedMap(data);
    } on FormatException {
      throw const CustomSceneApiException.malformed();
    } on Object {
      throw const CustomSceneApiException.malformed();
    }
  }

  CustomSceneApiErrorDto _parseError(Map<String, dynamic> json) {
    try {
      return CustomSceneApiErrorDto.fromJson(json);
    } on FormatException {
      throw const CustomSceneApiException.malformed();
    }
  }

  void close() {
    if (_ownsDio) {
      _dio.close();
    }
  }
}

Map<String, dynamic> _toStringKeyedMap(Object? value) {
  if (value is! Map) {
    throw const FormatException('响应顶层不是对象。');
  }
  final mapped = <String, dynamic>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw const FormatException('响应对象含非字符串 key。');
    }
    mapped[entry.key as String] = entry.value;
  }
  return mapped;
}
