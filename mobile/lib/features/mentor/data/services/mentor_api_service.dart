import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mobile/features/account/data/services/account_api_service.dart'
    show defaultAccountApiBaseUrl, defaultAccountApiVersion;

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
      kind == MentorApiFailureKind.timeout || statusCode == 504 || code == 'provider_timeout';
  bool get isUnauthorized => statusCode == 401 || code == 'invalid_session';
  bool get isConsentRevoked => statusCode == 403 && code == 'consent_revoked';
  bool get isAccountDeleted => code == 'account_deleted' || statusCode == 410;
  bool get isVersionBlocked =>
      statusCode == 426 || code == 'app_version_required' || code == 'app_version_unsupported';
  bool get isRateLimited => statusCode == 429 || code == 'mentor_rate_limited';
  bool get isMalformed =>
      kind == MentorApiFailureKind.malformed || code == 'provider_malformed_response';
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
    http.Client? client,
    Uri? baseUri,
    this.appVersion = defaultMentorApiVersion,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _baseUri = baseUri ?? Uri.parse(defaultMentorApiBaseUrl);

  final http.Client _client;
  final bool _ownsClient;
  final Uri _baseUri;
  final String appVersion;
  final Duration timeout;

  Future<MentorChatResponse> sendChat({
    required String installationId,
    required String prompt,
    required String surface,
    required String mode,
    required String correlationId,
    String? sessionId,
    String? contextSummary,
  }) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/mentor/chat',
      sessionId: sessionId,
      body: <String, Object?>{
        'installationId': installationId,
        'prompt': prompt,
        'surface': surface,
        'mode': mode,
        'correlationId': correlationId,
        if (contextSummary != null && contextSummary.trim().isNotEmpty)
          'contextSummary': contextSummary.trim(),
      },
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
        limited: _readRequiredBool(_readRequiredMap(json, 'rateLimit'), 'limited'),
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
    );
  }

  Future<void> close() async {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    String path, {
    String? sessionId,
    Map<String, String>? queryParameters,
    Map<String, Object?>? body,
  }) async {
    final request = http.Request(method, _resolveUri(path, queryParameters));
    request.headers['Accept'] = 'application/json';
    request.headers['Content-Type'] = 'application/json';
    request.headers['X-App-Version'] = appVersion;
    if (sessionId != null && sessionId.trim().isNotEmpty) {
      request.headers['X-Session-Id'] = sessionId.trim();
    }
    if (body != null) {
      request.body = jsonEncode(body);
    }

    http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(timeout);
    } on TimeoutException {
      throw const MentorApiException.timeout(message: '请求超时。');
    } on SocketException {
      throw const MentorApiException.network(message: '网络不可用。');
    } on http.ClientException {
      throw const MentorApiException.network(message: '网络请求失败。');
    }

    final materialized = await http.Response.fromStream(response);
    final decoded = _decodeJson(materialized.body);
    if (materialized.statusCode < 200 || materialized.statusCode >= 300) {
      throw MentorApiException(
        kind: MentorApiFailureKind.http,
        message: _readOptionalString(decoded, 'message') ?? 'Mentor 请求失败。',
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
      throw MentorApiException.malformed(message: '响应格式非法：$error');
    } on Object {
      throw const MentorApiException.malformed(message: '响应不是合法 JSON。');
    }
  }
}

String _readRequiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw MentorApiException.malformed(message: '字段 `$key` 缺失或不是非空字符串。');
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
    throw MentorApiException.malformed(message: '字段 `$key` 缺失或不是布尔值。');
  }
  return value;
}

DateTime _readRequiredDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw MentorApiException.malformed(message: '字段 `$key` 缺失或不是合法时间。');
  }
  return DateTime.parse(value).toUtc();
}

Map<String, dynamic> _readRequiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map<String, dynamic>) {
    throw MentorApiException.malformed(message: '字段 `$key` 缺失或不是对象。');
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
