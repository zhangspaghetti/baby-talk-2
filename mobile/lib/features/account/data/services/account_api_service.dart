import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

const String defaultAccountApiVersion = String.fromEnvironment(
  'BABY_TALK_API_VERSION',
  defaultValue: '1.2.0',
);
const String defaultAccountApiBaseUrl = String.fromEnvironment(
  'BABY_TALK_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8080',
);

enum AccountApiFailureKind { network, timeout, malformed, http }

class AccountApiException implements Exception {
  const AccountApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.code,
    this.minimumSupportedVersion,
    this.upgradeUrl,
    this.details = const <String, Object?>{},
  });

  const AccountApiException.network({required String message})
    : this(kind: AccountApiFailureKind.network, message: message);

  const AccountApiException.timeout({required String message})
    : this(kind: AccountApiFailureKind.timeout, message: message);

  const AccountApiException.malformed({required String message})
    : this(kind: AccountApiFailureKind.malformed, message: message);

  final AccountApiFailureKind kind;
  final String message;
  final int? statusCode;
  final String? code;
  final String? minimumSupportedVersion;
  final String? upgradeUrl;
  final Map<String, Object?> details;

  bool get isVersionBlocked =>
      statusCode == 426 || code == 'app_version_required' || code == 'app_version_unsupported';
  bool get isUnauthorized => statusCode == 401 || code == 'invalid_session';
  bool get isConsentRevoked => code == 'consent_revoked';
  bool get isConsentRequired => code == 'consent_required';
  bool get isAccountDeleted => statusCode == 410 || code == 'account_deleted';
  bool get isRetryable => details['retryable'] == true;
  bool get isServerFailure => (statusCode ?? 0) >= 500;

  @override
  String toString() {
    return 'AccountApiException(kind: $kind, statusCode: $statusCode, code: $code, message: $message)';
  }
}

class AccountChallengeResponse {
  const AccountChallengeResponse({
    required this.challengeId,
    required this.maskedPhoneNumber,
    required this.codeLength,
    required this.expiresAt,
  });

  final String challengeId;
  final String maskedPhoneNumber;
  final int codeLength;
  final DateTime expiresAt;
}

class AccountSessionResponse {
  const AccountSessionResponse({
    required this.accountId,
    required this.sessionId,
    required this.maskedPhoneNumber,
    required this.createdAt,
    required this.consentStatus,
  });

  final String accountId;
  final String sessionId;
  final String maskedPhoneNumber;
  final DateTime createdAt;
  final String consentStatus;
}

class AccountConsentResponse {
  const AccountConsentResponse({
    required this.applied,
    required this.result,
    required this.consentStatus,
    required this.updatedAt,
  });

  final bool applied;
  final String result;
  final String consentStatus;
  final DateTime updatedAt;
}

class AccountDeleteResponse {
  const AccountDeleteResponse({
    required this.applied,
    required this.result,
    required this.deletedEventCount,
    required this.updatedAt,
  });

  final bool applied;
  final String result;
  final int deletedEventCount;
  final DateTime updatedAt;
}

class SyncEventsResponse {
  const SyncEventsResponse({
    required this.receivedCount,
    required this.acceptedCount,
    required this.duplicateCount,
    required this.acceptedEventKeys,
    required this.duplicateEventKeys,
    required this.syncedAt,
  });

  final int receivedCount;
  final int acceptedCount;
  final int duplicateCount;
  final List<String> acceptedEventKeys;
  final List<String> duplicateEventKeys;
  final DateTime syncedAt;
}

class BootstrapResponse {
  const BootstrapResponse({
    required this.consentStatus,
    required this.eventCount,
    required this.events,
    required this.bootstrapAt,
  });

  final String consentStatus;
  final int eventCount;
  final List<InteractionEventPayload> events;
  final DateTime bootstrapAt;
}

class AccountApiService {
  AccountApiService({
    http.Client? client,
    Uri? baseUri,
    this.appVersion = defaultAccountApiVersion,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _baseUri = baseUri ?? Uri.parse(defaultAccountApiBaseUrl);

  final http.Client _client;
  final bool _ownsClient;
  final Uri _baseUri;
  final String appVersion;
  final Duration timeout;

  Future<AccountChallengeResponse> createChallenge({
    required String phoneNumber,
  }) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/auth/challenges',
      body: <String, Object?>{'phoneNumber': phoneNumber},
    );
    return AccountChallengeResponse(
      challengeId: _readRequiredString(json, 'challengeId'),
      maskedPhoneNumber: _readRequiredString(json, 'maskedPhoneNumber'),
      codeLength: _readRequiredInt(json, 'codeLength'),
      expiresAt: _readRequiredDateTime(json, 'expiresAt'),
    );
  }

  Future<AccountSessionResponse> verifyChallenge({
    required String challengeId,
    required String verificationCode,
    required String installationId,
  }) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/auth/verify',
      body: <String, Object?>{
        'challengeId': challengeId,
        'verificationCode': verificationCode,
        'installationId': installationId,
      },
    );
    return AccountSessionResponse(
      accountId: _readRequiredString(json, 'accountId'),
      sessionId: _readRequiredString(json, 'sessionId'),
      maskedPhoneNumber: _readRequiredString(json, 'maskedPhoneNumber'),
      createdAt: _readRequiredDateTime(json, 'createdAt'),
      consentStatus: _readRequiredString(json, 'consentStatus'),
    );
  }

  Future<AccountConsentResponse> acceptConsent({
    required String sessionId,
    required String consentVersion,
  }) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/consent/accept',
      sessionId: sessionId,
      body: <String, Object?>{'consentVersion': consentVersion},
    );
    return AccountConsentResponse(
      applied: _readRequiredBool(json, 'applied'),
      result: _readRequiredString(json, 'result'),
      consentStatus: _readRequiredString(json, 'consentStatus'),
      updatedAt: _readRequiredDateTime(json, 'updatedAt'),
    );
  }

  Future<AccountConsentResponse> revokeConsent({
    required String sessionId,
    required String reason,
  }) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/consent/revoke',
      sessionId: sessionId,
      body: <String, Object?>{'reason': reason},
    );
    return AccountConsentResponse(
      applied: _readRequiredBool(json, 'applied'),
      result: _readRequiredString(json, 'result'),
      consentStatus: _readRequiredString(json, 'consentStatus'),
      updatedAt: _readRequiredDateTime(json, 'updatedAt'),
    );
  }

  Future<AccountDeleteResponse> deleteAccount({
    required String sessionId,
    required String reason,
  }) async {
    final json = await _requestJson(
      'DELETE',
      '/api/v1/account',
      sessionId: sessionId,
      body: <String, Object?>{'reason': reason},
    );
    return AccountDeleteResponse(
      applied: _readRequiredBool(json, 'applied'),
      result: _readRequiredString(json, 'result'),
      deletedEventCount: _readRequiredInt(json, 'deletedEventCount'),
      updatedAt: _readRequiredDateTime(json, 'updatedAt'),
    );
  }

  Future<SyncEventsResponse> syncEvents({
    required String sessionId,
    required String installationId,
    required List<InteractionEventUploadRecord> events,
  }) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/sync/events',
      sessionId: sessionId,
      body: <String, Object?>{
        'installationId': installationId,
        'events': events.map((event) => event.toJsonMap()).toList(growable: false),
      },
    );
    return SyncEventsResponse(
      receivedCount: _readRequiredInt(json, 'receivedCount'),
      acceptedCount: _readRequiredInt(json, 'acceptedCount'),
      duplicateCount: _readRequiredInt(json, 'duplicateCount'),
      acceptedEventKeys: _readRequiredStringList(json, 'acceptedEventKeys'),
      duplicateEventKeys: _readRequiredStringList(json, 'duplicateEventKeys'),
      syncedAt: _readRequiredDateTime(json, 'syncedAt'),
    );
  }

  Future<BootstrapResponse> bootstrap({
    required String sessionId,
    required String installationId,
  }) async {
    final json = await _requestJson(
      'GET',
      '/api/v1/bootstrap',
      sessionId: sessionId,
      queryParameters: <String, String>{'installationId': installationId},
    );

    final consentStatus = _readRequiredString(json, 'consentStatus');
    if (consentStatus != 'accepted') {
      throw const AccountApiException.malformed(
        message: 'bootstrap 响应缺少 accepted consentStatus。',
      );
    }

    final rawEvents = _readRequiredList(json, 'events');
    final events = rawEvents.map((rawEvent) {
      final event = _readRequiredMap(rawEvent, 'events[]');
      final receivedAt = _readRequiredDateTime(event, 'receivedAt');
      return InteractionEventPayload.fromWire(
        eventKey: _readRequiredString(event, 'eventKey'),
        localEventId: _readRequiredString(event, 'localEventId'),
        installationId: _readRequiredString(event, 'installationId'),
        spaceId: _readRequiredString(event, 'spaceId'),
        activityId: _readRequiredString(event, 'activityId'),
        phraseId: _readRequiredString(event, 'phraseId'),
        reactionType: _readRequiredString(event, 'reactionType'),
        clientTimestamp: _readRequiredDateTime(event, 'clientTimestamp'),
        syncState: InteractionSyncState.synced.wireValue,
        lastSyncPhase: 'bootstrap_import',
        lastSyncAt: receivedAt,
      );
    }).toList(growable: false);

    final eventCount = _readRequiredInt(json, 'eventCount');
    if (eventCount != events.length) {
      throw const AccountApiException.malformed(
        message: 'bootstrap eventCount 与 events 长度不一致。',
      );
    }

    return BootstrapResponse(
      consentStatus: consentStatus,
      eventCount: eventCount,
      events: events,
      bootstrapAt: _readRequiredDateTime(json, 'bootstrapAt'),
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
      throw const AccountApiException.timeout(message: '请求超时。');
    } on SocketException {
      throw const AccountApiException.network(message: '网络不可用。');
    } on http.ClientException {
      throw const AccountApiException.network(message: '网络请求失败。');
    }

    final materialized = await http.Response.fromStream(response);
    final decoded = _decodeJson(materialized.body);
    if (materialized.statusCode < 200 || materialized.statusCode >= 300) {
      throw AccountApiException(
        kind: AccountApiFailureKind.http,
        message: _readOptionalString(decoded, 'message') ?? '请求失败。',
        statusCode: materialized.statusCode,
        code: _readOptionalString(decoded, 'code'),
        minimumSupportedVersion:
            materialized.headers['x-min-supported-version'] ??
            _readOptionalString(decoded, 'minimumSupportedVersion'),
        upgradeUrl:
            materialized.headers['x-upgrade-url'] ??
            _readOptionalString(decoded, 'upgradeUrl'),
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
      throw AccountApiException.malformed(message: '响应格式非法：$error');
    } on Object {
      throw const AccountApiException.malformed(message: '响应不是合法 JSON。');
    }
  }
}

String _readRequiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw AccountApiException.malformed(message: '字段 `$key` 缺失或不是非空字符串。');
  }
  return value;
}

String? _readOptionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw AccountApiException.malformed(message: '字段 `$key` 不是字符串。');
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
  throw AccountApiException.malformed(message: '字段 `$key` 缺失或不是整数。');
}

bool _readRequiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw AccountApiException.malformed(message: '字段 `$key` 缺失或不是布尔值。');
  }
  return value;
}

DateTime _readRequiredDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw AccountApiException.malformed(message: '字段 `$key` 缺失或不是合法时间。');
  }
  return DateTime.parse(value).toUtc();
}

List<Object?> _readRequiredList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List<Object?>) {
    throw AccountApiException.malformed(message: '字段 `$key` 缺失或不是数组。');
  }
  return value;
}

List<String> _readRequiredStringList(Map<String, dynamic> json, String key) {
  final rawList = _readRequiredList(json, key);
  final values = <String>[];
  for (final entry in rawList) {
    if (entry is! String || entry.trim().isEmpty) {
      throw AccountApiException.malformed(message: '字段 `$key` 包含非法字符串项。');
    }
    values.add(entry);
  }
  return List.unmodifiable(values);
}

Map<String, dynamic> _readRequiredMap(Object? rawValue, String key) {
  if (rawValue is! Map<String, dynamic>) {
    throw AccountApiException.malformed(message: '字段 `$key` 不是对象。');
  }
  return rawValue;
}

Map<String, Object?> _readOptionalMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return const <String, Object?>{};
  }
  if (value is! Map<String, dynamic>) {
    throw AccountApiException.malformed(message: '字段 `$key` 不是对象。');
  }
  return Map<String, Object?>.unmodifiable(value);
}
