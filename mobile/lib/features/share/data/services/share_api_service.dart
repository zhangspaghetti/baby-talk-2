import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:mobile/core/network/app_dio.dart';
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
    Dio? dio,
    String? baseUrl,
    this.appVersion = defaultShareApiVersion,
    this.timeout = const Duration(seconds: 8),
  }) : _dio = dio ?? AppDio.create(baseUrl: baseUrl ?? defaultShareApiBaseUrl),
       _ownsDio = dio == null;

  final Dio _dio;
  final bool _ownsDio;
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

  void close() {
    if (_ownsDio) {
      _dio.close();
    }
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'X-App-Version': appVersion,
    };

    Response<dynamic> response;
    try {
      response = await _dio.request<dynamic>(
        path,
        options: Options(method: method, headers: headers),
        data: body,
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        throw const ShareApiException.timeout(message: '分享链接请求超时。');
      }
      if (error.error is SocketException) {
        throw const ShareApiException.network(message: '网络不可用。');
      }
      throw const ShareApiException.network(message: '分享链接请求失败。');
    }

    final statusCode = response.statusCode ?? 0;
    final decoded = _normalizeResponseData(response.data);

    if (statusCode < 200 || statusCode >= 300) {
      throw ShareApiException(
        kind: ShareApiFailureKind.http,
        message: _readOptionalString(decoded, 'message') ?? '分享链接创建失败。',
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
