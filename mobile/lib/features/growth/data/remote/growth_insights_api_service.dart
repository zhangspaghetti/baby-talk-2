import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:mobile/core/network/app_dio.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart'
    show defaultAccountApiBaseUrl, defaultAccountApiVersion;
import 'package:mobile/features/growth/data/models/growth_insights_payload.dart';

enum GrowthInsightsApiFailureKind { network, timeout, malformed, http }

class GrowthInsightsApiException implements Exception {
  const GrowthInsightsApiException({
    required this.kind,
    required this.message,
    this.statusCode,
  });

  const GrowthInsightsApiException.network({required String message})
    : this(kind: GrowthInsightsApiFailureKind.network, message: message);

  const GrowthInsightsApiException.timeout({required String message})
    : this(kind: GrowthInsightsApiFailureKind.timeout, message: message);

  const GrowthInsightsApiException.malformed({required String message})
    : this(kind: GrowthInsightsApiFailureKind.malformed, message: message);

  final GrowthInsightsApiFailureKind kind;
  final String message;
  final int? statusCode;

  @override
  String toString() {
    return 'GrowthInsightsApiException(kind: $kind, statusCode: $statusCode, message: $message)';
  }
}

class GrowthInsightsApiService {
  GrowthInsightsApiService({
    Dio? dio,
    String? baseUrl,
    this.appVersion = defaultAccountApiVersion,
  }) : _dio =
           dio ?? AppDio.create(baseUrl: baseUrl ?? defaultAccountApiBaseUrl),
       _ownsDio = dio == null;

  final Dio _dio;
  final bool _ownsDio;
  final String appVersion;

  /// Fetches growth insights for the given [period] (e.g. `'week'`, `'month'`, `'year'`).
  Future<GrowthInsightsPayload> fetchInsights(String period) async {
    final json = await _requestJson(
      'GET',
      '/api/v1/growth/insights',
      query: {'period': period},
    );
    return GrowthInsightsPayload.fromJson(json);
  }

  void close() {
    if (_ownsDio) {
      _dio.close();
    }
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>> _requestJson(
    String method,
    String path, {
    Map<String, Object?>? query,
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
        queryParameters: query,
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        throw const GrowthInsightsApiException.timeout(message: '请求超时。');
      }
      if (error.error is SocketException) {
        throw const GrowthInsightsApiException.network(message: '网络不可用。');
      }
      throw const GrowthInsightsApiException.network(message: '网络请求失败。');
    }

    final statusCode = response.statusCode ?? 0;
    final decoded = _normalizeResponseData(response.data);
    if (statusCode < 200 || statusCode >= 300) {
      throw GrowthInsightsApiException(
        kind: GrowthInsightsApiFailureKind.http,
        message: '请求失败 ($statusCode)。',
        statusCode: statusCode,
      );
    }
    return decoded;
  }

  Map<String, dynamic> _normalizeResponseData(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is String) {
      if (data.trim().isEmpty) {
        throw const GrowthInsightsApiException.malformed(message: '响应体为空。');
      }
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        throw const GrowthInsightsApiException.malformed(
          message: '响应 JSON 不是对象。',
        );
      } on GrowthInsightsApiException {
        rethrow;
      } on Object {
        throw const GrowthInsightsApiException.malformed(
          message: '响应不是合法 JSON。',
        );
      }
    }
    throw const GrowthInsightsApiException.malformed(message: '响应体不是对象。');
  }
}
