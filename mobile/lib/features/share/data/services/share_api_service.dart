import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mobile/features/share/domain/models/share_link_draft.dart';

const String defaultShareApiVersion = String.fromEnvironment(
  'BABY_TALK_API_VERSION',
  defaultValue: '1.2.0',
);
const String defaultShareApiBaseUrl = String.fromEnvironment(
  'BABY_TALK_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8080',
);

enum ShareApiFailureKind { network, timeout, malformed, http }

class ShareApiException implements Exception {
  const ShareApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.code,
    this.details = const <String, Object?>{},
  });

  const ShareApiException.network({required String message})
    : this(kind: ShareApiFailureKind.network, message: message);

  const ShareApiException.timeout({required String message})
    : this(kind: ShareApiFailureKind.timeout, message: message);

  const ShareApiException.malformed({required String message})
    : this(kind: ShareApiFailureKind.malformed, message: message);

  final ShareApiFailureKind kind;
  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, Object?> details;

  bool get isServerFailure => (statusCode ?? 0) >= 500;
  bool get isRetryable => details['retryable'] == true || isServerFailure;

  @override
  String toString() {
    return 'ShareApiException(kind: $kind, statusCode: $statusCode, code: $code, message: $message)';
  }
}

class ShareCreateLinkResponse {
  const ShareCreateLinkResponse({
    required this.token,
    required this.shareUrl,
    required this.expiresAt,
  });

  final String token;
  final String shareUrl;
  final DateTime expiresAt;
}

class ShareApiService {
  ShareApiService({
    http.Client? client,
    Uri? baseUri,
    this.appVersion = defaultShareApiVersion,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _baseUri = baseUri ?? Uri.parse(defaultShareApiBaseUrl);

  final http.Client _client;
  final bool _ownsClient;
  final Uri _baseUri;
  final String appVersion;
  final Duration timeout;

  Future<ShareCreateLinkResponse> createShareLink({
    required ShareLinkDraft draft,
    String? platformHint,
  }) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/share-links',
      body: draft.toCreatePayload(platformHint: platformHint),
    );
    final token = _readRequiredString(json, 'token');
    final shareUrl = _readRequiredAbsoluteUrl(json, 'shareUrl');
    return ShareCreateLinkResponse(
      token: token,
      shareUrl: shareUrl,
      expiresAt: _readRequiredDateTime(json, 'expiresAt'),
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
    Map<String, Object?>? body,
  }) async {
    final request = http.Request(method, _resolveUri(path));
    request.headers['Accept'] = 'application/json';
    request.headers['Content-Type'] = 'application/json';
    request.headers['X-App-Version'] = appVersion;
    if (body != null) {
      request.body = jsonEncode(body);
    }

    http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(timeout);
    } on TimeoutException {
      throw const ShareApiException.timeout(message: '分享链接请求超时。');
    } on SocketException {
      throw const ShareApiException.network(message: '网络不可用。');
    } on http.ClientException {
      throw const ShareApiException.network(message: '分享链接请求失败。');
    }

    final materialized = await http.Response.fromStream(response);
    final decoded = _decodeJson(materialized.body);
    if (materialized.statusCode < 200 || materialized.statusCode >= 300) {
      throw ShareApiException(
        kind: ShareApiFailureKind.http,
        message: _readOptionalString(decoded, 'message') ?? '分享链接创建失败。',
        statusCode: materialized.statusCode,
        code: _readOptionalString(decoded, 'code'),
        details: _readOptionalMap(decoded, 'details'),
      );
    }
    return decoded;
  }

  Uri _resolveUri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final basePath = _baseUri.path.endsWith('/')
        ? _baseUri.path.substring(0, _baseUri.path.length - 1)
        : _baseUri.path;
    return _baseUri.replace(path: '$basePath$normalizedPath');
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
      throw ShareApiException.malformed(message: '分享链接响应格式非法：$error');
    } on Object {
      throw const ShareApiException.malformed(message: '分享链接响应不是合法 JSON。');
    }
  }
}

String _readRequiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw ShareApiException.malformed(message: '字段 `$key` 缺失或不是非空字符串。');
  }
  return value.trim();
}

String? _readOptionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw ShareApiException.malformed(message: '字段 `$key` 不是字符串。');
  }
  return value;
}

String _readRequiredAbsoluteUrl(Map<String, dynamic> json, String key) {
  final value = _readRequiredString(json, key);
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
    throw ShareApiException.malformed(message: '字段 `$key` 不是合法公开链接。');
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'https' && scheme != 'http') {
    throw ShareApiException.malformed(message: '字段 `$key` 不是安全链接。');
  }
  return uri.toString();
}

DateTime _readRequiredDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw ShareApiException.malformed(message: '字段 `$key` 缺失或不是合法时间。');
  }
  try {
    return DateTime.parse(value).toUtc();
  } on FormatException {
    throw ShareApiException.malformed(message: '字段 `$key` 不是合法时间。');
  }
}

Map<String, Object?> _readOptionalMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return const <String, Object?>{};
  }
  if (value is! Map<String, dynamic>) {
    throw ShareApiException.malformed(message: '字段 `$key` 不是对象。');
  }
  return Map<String, Object?>.unmodifiable(value);
}
