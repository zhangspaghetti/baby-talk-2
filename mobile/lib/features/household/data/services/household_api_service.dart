import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mobile/features/household/domain/models/household_invite_link.dart';
import 'package:mobile/features/household/domain/models/household_role.dart';
import 'package:mobile/features/household/domain/models/household_shared_context.dart';

const String defaultHouseholdApiBaseUrl = String.fromEnvironment(
  'BABY_TALK_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8080',
);
const String defaultHouseholdApiVersion = String.fromEnvironment(
  'BABY_TALK_API_VERSION',
  defaultValue: '1.2.0',
);

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
    return 'HouseholdApiException(kind: $kind, statusCode: $statusCode, code: $code, message: $message)';
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

class HouseholdApiService {
  HouseholdApiService({
    http.Client? client,
    Uri? baseUri,
    this.appVersion = defaultHouseholdApiVersion,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _baseUri = baseUri ?? Uri.parse(defaultHouseholdApiBaseUrl);

  final http.Client _client;
  final bool _ownsClient;
  final Uri _baseUri;
  final String appVersion;
  final Duration timeout;

  Future<HouseholdInviteLink> createInvite({
    required String sessionId,
    required HouseholdRole role,
    required String source,
  }) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/caregiver-invites',
      sessionId: sessionId,
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
    required String sessionId,
    required String token,
    required String source,
  }) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/caregiver-invites/accept',
      sessionId: sessionId,
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
    required String sessionId,
  }) async {
    final json = await _requestJson(
      'GET',
      '/api/v1/household/shared-context',
      sessionId: sessionId,
    );
    return _readSharedContextResponse(json);
  }

  Future<void> close() async {
    if (_ownsClient) {
      _client.close();
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

  Future<Map<String, dynamic>> _requestJson(
    String method,
    String path, {
    required String sessionId,
    Map<String, String>? queryParameters,
    Map<String, Object?>? body,
  }) async {
    final request = http.Request(method, _resolveUri(path, queryParameters));
    request.headers['Accept'] = 'application/json';
    request.headers['Content-Type'] = 'application/json';
    request.headers['X-App-Version'] = appVersion;
    request.headers['X-Session-Id'] = sessionId.trim();
    if (body != null) {
      request.body = jsonEncode(body);
    }

    http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(timeout);
    } on TimeoutException {
      throw const HouseholdApiException.timeout(message: '请求超时。');
    } on SocketException {
      throw const HouseholdApiException.network(message: '网络不可用。');
    } on http.ClientException {
      throw const HouseholdApiException.network(message: '网络请求失败。');
    }

    final materialized = await http.Response.fromStream(response);
    final decoded = _decodeJson(materialized.body);
    if (materialized.statusCode < 200 || materialized.statusCode >= 300) {
      throw HouseholdApiException(
        kind: HouseholdApiFailureKind.http,
        message: _readOptionalString(decoded, 'message') ?? '请求失败。',
        statusCode: materialized.statusCode,
        code: _readOptionalString(decoded, 'code'),
        details: _readOptionalMap(decoded, 'details'),
      );
    }
    return decoded;
  }

  Uri _resolveUri(String path, Map<String, String>? queryParameters) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final basePath = _baseUri.path.endsWith('/')
        ? _baseUri.path.substring(0, _baseUri.path.length - 1)
        : _baseUri.path;
    return _baseUri.replace(
      path: '$basePath$normalizedPath',
      queryParameters: queryParameters,
    );
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
