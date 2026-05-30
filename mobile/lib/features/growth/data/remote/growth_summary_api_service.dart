import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:mobile/core/network/app_dio.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart'
    show defaultAccountApiBaseUrl, defaultAccountApiVersion;

enum GrowthSummaryApiFailureKind { network, timeout, malformed, http }

class GrowthSummaryApiException implements Exception {
  const GrowthSummaryApiException({
    required this.kind,
    required this.message,
    this.statusCode,
  });

  const GrowthSummaryApiException.network({required String message})
    : this(kind: GrowthSummaryApiFailureKind.network, message: message);

  const GrowthSummaryApiException.timeout({required String message})
    : this(kind: GrowthSummaryApiFailureKind.timeout, message: message);

  const GrowthSummaryApiException.malformed({required String message})
    : this(kind: GrowthSummaryApiFailureKind.malformed, message: message);

  final GrowthSummaryApiFailureKind kind;
  final String message;
  final int? statusCode;

  @override
  String toString() {
    return 'GrowthSummaryApiException(kind: $kind, statusCode: $statusCode, message: $message)';
  }
}

enum GrowthSummaryPeriod { week, month, year }

extension GrowthSummaryPeriodWire on GrowthSummaryPeriod {
  String get wireValue {
    switch (this) {
      case GrowthSummaryPeriod.week:
        return 'week';
      case GrowthSummaryPeriod.month:
        return 'month';
      case GrowthSummaryPeriod.year:
        return 'year';
    }
  }
}

class GrowthSummaryPayload {
  const GrowthSummaryPayload({
    required this.totalEvents,
    required this.uniquePhrases,
    required this.uniqueActivities,
    required this.imitationCount,
    required this.practicedDays,
    this.firstEventAt,
    this.lastEventAt,
  });

  final int totalEvents;
  final int uniquePhrases;
  final int uniqueActivities;
  final int imitationCount;
  final int practicedDays;
  final DateTime? firstEventAt;
  final DateTime? lastEventAt;
}

abstract class GrowthSummaryRemoteDataSource {
  Future<GrowthSummaryPayload> fetchSummary({
    required GrowthSummaryPeriod period,
  });
}

class GrowthSummaryApiService implements GrowthSummaryRemoteDataSource {
  GrowthSummaryApiService({
    Dio? dio,
    String? baseUrl,
    this.appVersion = defaultAccountApiVersion,
  }) : _dio =
           dio ?? AppDio.create(baseUrl: baseUrl ?? defaultAccountApiBaseUrl),
       _ownsDio = dio == null;

  final Dio _dio;
  final bool _ownsDio;
  final String appVersion;

  @override
  Future<GrowthSummaryPayload> fetchSummary({
    required GrowthSummaryPeriod period,
  }) async {
    final json = await _requestJson('GET', '/api/v1/growth/summary', query: {
      'period': period.wireValue,
    });
    return _readPayload(json);
  }

  void close() {
    if (_ownsDio) {
      _dio.close();
    }
  }

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
        throw const GrowthSummaryApiException.timeout(message: '请求超时。');
      }
      if (error.error is SocketException) {
        throw const GrowthSummaryApiException.network(message: '网络不可用。');
      }
      throw const GrowthSummaryApiException.network(message: '网络请求失败。');
    }

    final statusCode = response.statusCode ?? 0;
    final decoded = _normalizeResponseData(response.data);
    if (statusCode < 200 || statusCode >= 300) {
      throw GrowthSummaryApiException(
        kind: GrowthSummaryApiFailureKind.http,
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
        throw const GrowthSummaryApiException.malformed(message: '响应体为空。');
      }
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        throw const GrowthSummaryApiException.malformed(
          message: '响应 JSON 不是对象。',
        );
      } on GrowthSummaryApiException {
        rethrow;
      } on Object {
        throw const GrowthSummaryApiException.malformed(
          message: '响应不是合法 JSON。',
        );
      }
    }
    throw const GrowthSummaryApiException.malformed(message: '响应体不是对象。');
  }

  GrowthSummaryPayload _readPayload(Map<String, dynamic> json) {
    final summary = _readSummaryMap(json);
    final hasCoreFields =
        _hasIntValue(summary, 'totalEvents') || _hasIntValue(summary, 'eventCount');
    if (!hasCoreFields) {
      throw const GrowthSummaryApiException.malformed(
        message: '缺少成长摘要关键字段。',
      );
    }

    return GrowthSummaryPayload(
      totalEvents: _readInt(summary, 'totalEvents', fallbackKey: 'eventCount'),
      uniquePhrases: _readInt(summary, 'uniquePhrases'),
      uniqueActivities: _readInt(summary, 'uniqueActivities'),
      imitationCount: _readInt(summary, 'imitationCount'),
      practicedDays: _readInt(summary, 'practicedDays'),
      firstEventAt: _readDateTime(summary, 'firstEventAt'),
      lastEventAt: _readDateTime(summary, 'lastEventAt'),
    );
  }
}

Map<String, dynamic> _readSummaryMap(Map<String, dynamic> json) {
  final summary = json['summary'];
  if (summary is Map<String, dynamic>) {
    return summary;
  }
  return json;
}

bool _hasIntValue(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is num;
}

int _readInt(Map<String, dynamic> json, String key, {String? fallbackKey}) {
  final dynamic primary = json[key];
  if (primary is int) {
    return primary;
  }
  if (primary is num) {
    return primary.toInt();
  }

  if (fallbackKey == null) {
    return 0;
  }

  final dynamic fallback = json[fallbackKey];
  if (fallback is int) {
    return fallback;
  }
  if (fallback is num) {
    return fallback.toInt();
  }
  return 0;
}

DateTime? _readDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value)?.toLocal();
}