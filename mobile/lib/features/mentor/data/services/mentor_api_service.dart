import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart'
    show defaultAccountApiBaseUrl, defaultAccountApiVersion;
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';

const String defaultMentorApiVersion = defaultAccountApiVersion;
const String defaultMentorApiBaseUrl = defaultAccountApiBaseUrl;

const int mentorPromptMaxLength = 280;

class MentorRateLimitStatus {
  const MentorRateLimitStatus({
    required this.limited,
    required this.limit,
    required this.remaining,
    required this.windowSeconds,
  });

  final bool limited;
  final int limit;
  final int remaining;
  final int windowSeconds;
}

class MentorChatResponse {
  const MentorChatResponse({
    required this.correlationId,
    required this.responseText,
    required this.code,
    required this.phase,
    required this.retryable,
    required this.fallbackUsed,
    required this.authenticated,
    required this.rateLimit,
    required this.respondedAt,
    this.conversationId,
  });

  final String correlationId;
  final String responseText;
  final String code;
  final String phase;
  final bool retryable;
  final bool fallbackUsed;
  final bool authenticated;
  final MentorRateLimitStatus rateLimit;
  final DateTime respondedAt;
  final String? conversationId;
}

enum MentorApiFailureKind { network, timeout, malformed, http }

class MentorApiException implements Exception {
  const MentorApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.code,
    this.details = const <String, Object?>{},
  });

  const MentorApiException.network({required String message})
    : this(kind: MentorApiFailureKind.network, message: message);

  const MentorApiException.timeout({required String message})
    : this(kind: MentorApiFailureKind.timeout, message: message);

  const MentorApiException.malformed({required String message})
    : this(kind: MentorApiFailureKind.malformed, message: message);

  final MentorApiFailureKind kind;
  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, Object?> details;

  bool get isOffline => kind == MentorApiFailureKind.network;
  bool get isTimeout =>
      kind == MentorApiFailureKind.timeout ||
      statusCode == 504 ||
      code == 'provider_timeout';
  bool get isUnauthorized => statusCode == 401 || code == 'invalid_session';
  bool get isConsentRevoked => statusCode == 403 && code == 'consent_revoked';
  bool get isAccountDeleted => code == 'account_deleted' || statusCode == 410;
  bool get isVersionBlocked =>
      statusCode == 426 ||
      code == 'app_version_required' ||
      code == 'app_version_unsupported';
  bool get isRateLimited => statusCode == 429 || code == 'mentor_rate_limited';
  bool get isMalformed =>
      kind == MentorApiFailureKind.malformed ||
      code == 'provider_malformed_response';
  bool get isRetryable => details['retryable'] == true;
  bool get isServerFailure => (statusCode ?? 0) >= 500;
  String? get phase => details['phase'] as String?;
  String? get correlationId => details['correlationId'] as String?;

  @override
  String toString() {
    return 'MentorApiException(kind: $kind, statusCode: $statusCode, code: $code, message: $message)';
  }
}

class MentorApiService {
  MentorApiService({
    Dio? dio,
    AuthenticatedApiClient? authenticatedApiClient,
    String? baseUrl,
    this.appVersion = defaultMentorApiVersion,
    this.timeout = const Duration(seconds: 30),
  }) : _dio = dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl ?? defaultMentorApiBaseUrl,
               connectTimeout: timeout,
               receiveTimeout: timeout,
               headers: {'Content-Type': 'application/json'},
               validateStatus: (status) => true,
             ),
           ),
       _authenticatedApiClient = authenticatedApiClient,
       _ownsDio = dio == null;

  final Dio _dio;
  final AuthenticatedApiClient? _authenticatedApiClient;
  final bool _ownsDio;
  final String appVersion;
  final Duration timeout;

  Future<MentorChatResponse> sendChat({
    required String installationId,
    required String prompt,
    required String surface,
    required String mode,
    required String correlationId,
    AccountSession? session,
    PersistRefreshedSession? persistRefreshedSession,
    String? contextSummary,
    String? conversationId,
  }) async {
    final body = <String, Object?>{
      'installationId': installationId,
      'prompt': prompt,
      'surface': surface,
      'mode': mode,
      'correlationId': correlationId,
      if (contextSummary != null && contextSummary.trim().isNotEmpty) ...{
        'contextSummary': contextSummary.trim(),
      },
      if (conversationId != null) ...{'conversationId': conversationId},
    };

    final json = session == null
        ? await _requestJson('POST', '/api/v1/mentor/chat', body: body)
        : await _requestAuthenticatedJson(
            method: 'POST',
            path: '/api/v1/mentor/chat',
            session: session,
            persistRefreshedSession: persistRefreshedSession,
            body: body,
          );

    return MentorChatResponse(
      correlationId: _readRequiredString(json, 'correlationId'),
      responseText: _readRequiredString(json, 'responseText'),
      code: _readRequiredString(json, 'code'),
      phase: _readRequiredString(json, 'phase'),
      retryable: _readRequiredBool(json, 'retryable'),
      fallbackUsed: _readRequiredBool(json, 'fallbackUsed'),
      authenticated: _readRequiredBool(json, 'authenticated'),
      rateLimit: MentorRateLimitStatus(
        limited: _readRequiredBool(
          _readRequiredMap(json, 'rateLimit'),
          'limited',
        ),
        limit: _readRequiredInt(_readRequiredMap(json, 'rateLimit'), 'limit'),
        remaining: _readRequiredInt(
          _readRequiredMap(json, 'rateLimit'),
          'remaining',
        ),
        windowSeconds: _readRequiredInt(
          _readRequiredMap(json, 'rateLimit'),
          'windowSeconds',
        ),
      ),
      respondedAt: _readRequiredDateTime(json, 'respondedAt'),
      conversationId: _readOptionalString(json, 'conversationId'),
    );
  }

  void close() {
    if (_ownsDio) {
      _dio.close();
    }
  }

  Future<Map<String, dynamic>> _requestAuthenticatedJson({
    required String method,
    required String path,
    required AccountSession session,
    required PersistRefreshedSession? persistRefreshedSession,
    Map<String, String>? queryParameters,
    Map<String, Object?>? body,
  }) async {
    final authenticatedApiClient = _authenticatedApiClient;
    if (authenticatedApiClient == null) {
      throw StateError('MentorApiService 缺少 authenticatedApiClient 注入。');
    }
    final persist = persistRefreshedSession;
    if (persist == null) {
      throw StateError('MentorApiService 缺少 persistRefreshedSession 回调。');
    }

    try {
      final result = await authenticatedApiClient.execute<Map<String, dynamic>>(
        session: session,
        send: (accessToken) => _requestJson(
          method,
          path,
          accessToken: accessToken,
          queryParameters: queryParameters,
          body: body,
        ),
        persistRefreshedSession: persist,
      );
      return result.value;
    } on AuthenticatedApiClientException catch (error) {
      throw _mapAuthException(error);
    }
  }

  MentorApiException _mapAuthException(AuthenticatedApiClientException error) {
    switch (error.kind) {
      case AuthenticatedApiClientFailureKind.refreshTimeout:
        return MentorApiException(
          kind: MentorApiFailureKind.timeout,
          message: error.visibleMessage,
          code: 'refresh_timeout',
          details: <String, Object?>{
            'phase': error.phaseSuffix,
            'retryable': true,
          },
        );
      case AuthenticatedApiClientFailureKind.refreshNetwork:
        return MentorApiException(
          kind: MentorApiFailureKind.network,
          message: error.visibleMessage,
          code: 'refresh_network',
          details: <String, Object?>{
            'phase': error.phaseSuffix,
            'retryable': true,
          },
        );
      case AuthenticatedApiClientFailureKind.missingCredentials:
      case AuthenticatedApiClientFailureKind.refreshMalformed:
      case AuthenticatedApiClientFailureKind.refreshFailed:
      case AuthenticatedApiClientFailureKind.sessionExpired:
      case AuthenticatedApiClientFailureKind.persistenceFailure:
        return MentorApiException(
          kind: MentorApiFailureKind.http,
          message: error.visibleMessage,
          statusCode: 401,
          code: 'invalid_session',
          details: <String, Object?>{
            'phase': error.phaseSuffix,
            'retryable': true,
          },
        );
    }
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    String path, {
    String? accessToken,
    Map<String, String>? queryParameters,
    Map<String, Object?>? body,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'X-App-Version': appVersion,
    };
    if (accessToken != null && accessToken.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${accessToken.trim()}';
    }

    Response<dynamic> response;
    try {
      response = await _dio.request<dynamic>(
        path,
        options: Options(method: method, headers: headers),
        data: body,
        queryParameters: queryParameters,
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        throw const MentorApiException.timeout(message: '请求超时。');
      }
      if (error.error is SocketException) {
        throw const MentorApiException.network(message: '网络不可用。');
      }
      throw const MentorApiException.network(message: '网络请求失败。');
    }

    final statusCode = response.statusCode ?? 0;
    final decoded = _normalizeResponseData(response.data);

    if (statusCode < 200 || statusCode >= 300) {
      throw MentorApiException(
        kind: MentorApiFailureKind.http,
        message: _readOptionalString(decoded, 'message') ?? 'Mentor 请求失败。',
        statusCode: statusCode,
        code: _readOptionalString(decoded, 'code'),
        details: _readOptionalMap(decoded, 'details'),
      );
    }
    return decoded;
  }

  Map<String, dynamic> _normalizeResponseData(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String && data.trim().isNotEmpty) {
      return _decodeJson(data);
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _decodeJson(String rawBody) {
    if (rawBody.trim().isEmpty) {
      return <String, dynamic>{};
    }
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw const FormatException('响应顶层必须是对象。');
    } on FormatException catch (error) {
      throw MentorApiException.malformed(message: '响应格式非法：$error');
    } on Object {
      throw const MentorApiException.malformed(message: '响应不是合法 JSON。');
    }
  }
}

String _readRequiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw MentorApiException.malformed(
      message: '字段 `$key` 缺失或不是非空字符串。',
    );
  }
  return value;
}

String? _readOptionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw MentorApiException.malformed(message: '字段 `$key` 不是字符串。');
  }
  return value;
}

int _readRequiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  throw MentorApiException.malformed(message: '字段 `$key` 缺失或不是整数。');
}

bool _readRequiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw MentorApiException.malformed(
      message: '字段 `$key` 缺失或不是布尔值。',
    );
  }
  return value;
}

DateTime _readRequiredDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw MentorApiException.malformed(
      message: '字段 `$key` 缺失或不是合法时间。',
    );
  }
  return DateTime.parse(value).toUtc();
}

Map<String, dynamic> _readRequiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map<String, dynamic>) {
    throw MentorApiException.malformed(message: '字段 `$key` 不是对象。');
  }
  return value;
}

Map<String, Object?> _readOptionalMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return const <String, Object?>{};
  }
  if (value is! Map<String, dynamic>) {
    throw MentorApiException.malformed(message: '字段 `$key` 不是对象。');
  }
  return Map<String, Object?>.unmodifiable(value);
}
