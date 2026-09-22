import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:mobile/core/network/app_dio.dart';
import 'package:mobile/core/network/api_version.dart';
import 'package:mobile/core/network/auth_headers.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/household/domain/models/household_invite_link.dart';
import 'package:mobile/features/household/domain/models/household_role.dart';
import 'package:mobile/features/household/domain/models/household_shared_context.dart';

const String defaultHouseholdApiBaseUrl = String.fromEnvironment(
  'BABY_TALK_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8080',
);
const String defaultHouseholdApiVersion = defaultAppApiVersion;

enum HouseholdApiFailureKind { network, timeout, malformed, http }

class HouseholdApiException implements Exception {
  const HouseholdApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.code,
    this.details = const <String, Object?>{},
  });

  const HouseholdApiException.network({required String message})
    : this(kind: HouseholdApiFailureKind.network, message: message);

  const HouseholdApiException.timeout({required String message})
    : this(kind: HouseholdApiFailureKind.timeout, message: message);

  const HouseholdApiException.malformed({required String message})
    : this(kind: HouseholdApiFailureKind.malformed, message: message);

  final HouseholdApiFailureKind kind;
  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, Object?> details;

  bool get isRetryable => details['retryable'] == true;
  bool get isServerFailure => (statusCode ?? 0) >= 500;
  bool get isUnauthorized => statusCode == 401 || code == 'invalid_session';
  bool get isConsentRequired => code == 'consent_required';
  bool get isConsentRevoked => code == 'consent_revoked';
  bool get isMembershipMissing => code == 'household_membership_missing';
  bool get isRoleNotAllowed => code == 'role_not_allowed';
  bool get isInviteExpired => code == 'invite_expired';
  bool get isInviteAlreadyUsed => code == 'invite_already_used';
  bool get isInviteRevoked => code == 'invite_revoked';
  bool get isSharedContextUnavailable => code == 'shared_context_unavailable';
  bool get isVersionBlocked =>
      statusCode == 426 ||
      code == 'app_version_required' ||
      code == 'app_version_unsupported';

  @override
  String toString() {
    // Server messages may contain private household or child text. Callers
    // receive the sanitized visible message separately; diagnostics expose
    // only stable transport classification.
    return 'HouseholdApiException(kind: $kind, statusCode: $statusCode, code: $code)';
  }
}

class HouseholdSharedContextResponse {
  const HouseholdSharedContextResponse({
    required this.householdId,
    required this.role,
    required this.lastAcceptedAt,
    required this.snapshot,
  });

  final String householdId;
  final HouseholdRole role;
  final DateTime lastAcceptedAt;
  final HouseholdSharedContext snapshot;
}

class HouseholdAcceptInviteResponse {
  const HouseholdAcceptInviteResponse({
    required this.householdId,
    required this.role,
    required this.acceptedAt,
    required this.sharedContext,
  });

  final String householdId;
  final HouseholdRole role;
  final DateTime acceptedAt;
  final HouseholdSharedContextResponse sharedContext;
}

class HouseholdRevokeInviteResponse {
  const HouseholdRevokeInviteResponse({
    required this.applied,
    required this.result,
    required this.token,
    required this.updatedAt,
  });

  final bool applied;
  final String result;
  final String token;
  final DateTime updatedAt;
}

class HouseholdApiService {
  HouseholdApiService({
    Dio? dio,
    AuthenticatedApiClient? authenticatedApiClient,
    String? baseUrl,
    this.appVersion = defaultHouseholdApiVersion,
    this.timeout = const Duration(seconds: 8),
  }) : _dio =
           dio ?? AppDio.create(baseUrl: baseUrl ?? defaultHouseholdApiBaseUrl),
       _authenticatedApiClient = authenticatedApiClient,
       _ownsDio = dio == null;

  final Dio _dio;
  final AuthenticatedApiClient? _authenticatedApiClient;
  final bool _ownsDio;
  final String appVersion;
  final Duration timeout;

  Future<HouseholdInviteLink> createInvite({
    required AccountSession session,
    required PersistRefreshedSession persistRefreshedSession,
    required HouseholdRole role,
    required String source,
  }) async {
    final json = await _requestAuthenticatedJson(
      method: 'POST',
      path: '/api/v1/caregiver-invites',
      session: session,
      persistRefreshedSession: persistRefreshedSession,
      body: <String, Object?>{'role': role.wireValue, 'source': source},
    );
    return HouseholdInviteLink(
      householdId: _readRequiredString(json, 'householdId'),
      token: _readRequiredString(json, 'token'),
      inviteUrl: _readRequiredString(json, 'inviteUrl'),
      role: parseHouseholdRole(_readRequiredString(json, 'role')),
      source: _readRequiredString(json, 'source'),
      expiresAt: _readRequiredDateTime(json, 'expiresAt'),
    );
  }

  Future<HouseholdAcceptInviteResponse> acceptInvite({
    required AccountSession session,
    required PersistRefreshedSession persistRefreshedSession,
    required String token,
    required String source,
  }) async {
    final json = await _requestAuthenticatedJson(
      method: 'POST',
      path: '/api/v1/caregiver-invites/accept',
      session: session,
      persistRefreshedSession: persistRefreshedSession,
      body: <String, Object?>{'token': token, 'source': source},
    );
    return HouseholdAcceptInviteResponse(
      householdId: _readRequiredString(json, 'householdId'),
      role: parseHouseholdRole(_readRequiredString(json, 'role')),
      acceptedAt: _readRequiredDateTime(json, 'acceptedAt'),
      sharedContext: _readSharedContextResponse(
        _readRequiredMap(json, 'sharedContext'),
      ),
    );
  }

  Future<HouseholdSharedContextResponse> fetchSharedContext({
    required AccountSession session,
    required PersistRefreshedSession persistRefreshedSession,
  }) async {
    final json = await _requestAuthenticatedJson(
      method: 'GET',
      path: '/api/v1/household/shared-context',
      session: session,
      persistRefreshedSession: persistRefreshedSession,
    );
    return _readSharedContextResponse(json);
  }

  Future<HouseholdRevokeInviteResponse> revokeInvite({
    required AccountSession session,
    required PersistRefreshedSession persistRefreshedSession,
    required String token,
  }) async {
    final json = await _requestAuthenticatedJson(
      method: 'POST',
      path: '/api/v1/caregiver-invites/${Uri.encodeComponent(token)}/revoke',
      session: session,
      persistRefreshedSession: persistRefreshedSession,
    );
    return HouseholdRevokeInviteResponse(
      applied: _readRequiredBool(json, 'applied'),
      result: _readRequiredString(json, 'result'),
      token: _readRequiredString(json, 'token'),
      updatedAt: _readRequiredDateTime(json, 'updatedAt'),
    );
  }

  void close() {
    if (_ownsDio) {
      _dio.close();
    }
  }

  HouseholdSharedContextResponse _readSharedContextResponse(
    Map<String, dynamic> json,
  ) {
    return HouseholdSharedContextResponse(
      householdId: _readRequiredString(json, 'householdId'),
      role: parseHouseholdRole(_readRequiredString(json, 'role')),
      lastAcceptedAt: _readRequiredDateTime(json, 'lastAcceptedAt'),
      snapshot: HouseholdSharedContext.fromJsonMap(
        _readRequiredMap(json, 'snapshot'),
      ),
    );
  }

  Future<Map<String, dynamic>> _requestAuthenticatedJson({
    required String method,
    required String path,
    required AccountSession session,
    required PersistRefreshedSession persistRefreshedSession,
    Map<String, String>? queryParameters,
    Map<String, Object?>? body,
  }) async {
    final authenticatedApiClient = _authenticatedApiClient;
    if (authenticatedApiClient == null) {
      throw StateError('HouseholdApiService 缺少 authenticatedApiClient 注入。');
    }

    try {
      final result = await authenticatedApiClient.execute<Map<String, dynamic>>(
        session: session,
        send: (accessToken) => _requestJson(
          method,
          path,
          queryParameters: queryParameters,
          body: body,
          accessToken: accessToken,
        ),
        persistRefreshedSession: persistRefreshedSession,
      );
      return result.value;
    } on AuthenticatedApiClientException catch (error) {
      throw _mapAuthException(error);
    }
  }

  HouseholdApiException _mapAuthException(
    AuthenticatedApiClientException error,
  ) {
    switch (error.kind) {
      case AuthenticatedApiClientFailureKind.refreshTimeout:
        return HouseholdApiException.timeout(message: error.visibleMessage);
      case AuthenticatedApiClientFailureKind.refreshNetwork:
        return HouseholdApiException.network(message: error.visibleMessage);
      case AuthenticatedApiClientFailureKind.missingCredentials:
      case AuthenticatedApiClientFailureKind.refreshMalformed:
      case AuthenticatedApiClientFailureKind.refreshFailed:
      case AuthenticatedApiClientFailureKind.sessionExpired:
      case AuthenticatedApiClientFailureKind.persistenceFailure:
        return HouseholdApiException(
          kind: HouseholdApiFailureKind.http,
          message: error.visibleMessage,
          statusCode: 401,
          code: 'invalid_session',
          details: <String, Object?>{'phase': error.phaseSuffix},
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
    final authorizationHeader = buildBearerAuthorizationHeaderValue(
      accessToken,
    );
    final headers = <String, String>{
      'Accept': 'application/json',
      'X-App-Version': appVersion,
      authorizationHeaderName: ?authorizationHeader,
    };

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
        throw const HouseholdApiException.timeout(message: '请求超时。');
      }
      if (error.error is SocketException) {
        throw const HouseholdApiException.network(message: '网络不可用。');
      }
      throw const HouseholdApiException.network(message: '网络请求失败。');
    }

    final statusCode = response.statusCode ?? 0;
    final decoded = _normalizeResponseData(response.data);

    if (statusCode < 200 || statusCode >= 300) {
      throw HouseholdApiException(
        kind: HouseholdApiFailureKind.http,
        message: _readOptionalString(decoded, 'message') ?? '请求失败。',
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
      throw HouseholdApiException.malformed(message: '响应格式非法：$error');
    } on Object {
      throw const HouseholdApiException.malformed(message: '响应不是合法 JSON。');
    }
  }
}

String _readRequiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw HouseholdApiException.malformed(message: '字段 `$key` 缺失或不是非空字符串。');
  }
  return value;
}

bool _readRequiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw HouseholdApiException.malformed(message: '字段 `$key` 缺失或不是布尔值。');
  }
  return value;
}

String? _readOptionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw HouseholdApiException.malformed(message: '字段 `$key` 不是字符串。');
  }
  return value;
}

DateTime _readRequiredDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw HouseholdApiException.malformed(message: '字段 `$key` 缺失或不是合法时间。');
  }
  return DateTime.parse(value).toUtc();
}

Map<String, dynamic> _readRequiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map<String, dynamic>) {
    throw HouseholdApiException.malformed(message: '字段 `$key` 不是对象。');
  }
  return value;
}

Map<String, Object?> _readOptionalMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return const <String, Object?>{};
  }
  if (value is! Map<String, dynamic>) {
    throw HouseholdApiException.malformed(message: '字段 `$key` 不是对象。');
  }
  return Map<String, Object?>.unmodifiable(value);
}
