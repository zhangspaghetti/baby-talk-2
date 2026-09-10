import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:mobile/core/network/app_dio.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart'
    show defaultAccountApiBaseUrl, defaultAccountApiVersion;
import 'package:mobile/features/garden/data/models/garden_snapshot_payload.dart';

enum GardenSnapshotApiFailureKind { network, timeout, malformed, http }

class GardenSnapshotApiException implements Exception {
  const GardenSnapshotApiException({
    required this.kind,
    required this.message,
    this.statusCode,
  });

  const GardenSnapshotApiException.network({required String message})
    : this(kind: GardenSnapshotApiFailureKind.network, message: message);

  const GardenSnapshotApiException.timeout({required String message})
    : this(kind: GardenSnapshotApiFailureKind.timeout, message: message);

  const GardenSnapshotApiException.malformed({required String message})
    : this(kind: GardenSnapshotApiFailureKind.malformed, message: message);

  final GardenSnapshotApiFailureKind kind;
  final String message;
  final int? statusCode;

  @override
  String toString() {
    return 'GardenSnapshotApiException(kind: $kind, statusCode: $statusCode, message: $message)';
  }
}

class GardenSnapshotApiService {
  GardenSnapshotApiService({
    Dio? dio,
    String? baseUrl,
    this.appVersion = defaultAccountApiVersion,
  }) : _dio =
           dio ?? AppDio.create(baseUrl: baseUrl ?? defaultAccountApiBaseUrl),
       _ownsDio = dio == null;

  final Dio _dio;
  final bool _ownsDio;
  final String appVersion;

  /// Fetches the garden snapshot from the remote API.
  Future<GardenSnapshotPayload> fetchSnapshot() async {
    final json = await _requestJson('GET', '/api/v1/garden/snapshot');
    return GardenSnapshotPayload.fromJson(json);
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
        throw const GardenSnapshotApiException.timeout(message: '请求超时。');
      }
      if (error.error is SocketException) {
        throw const GardenSnapshotApiException.network(message: '网络不可用。');
      }
      throw const GardenSnapshotApiException.network(message: '网络请求失败。');
    }

    final statusCode = response.statusCode ?? 0;
    final decoded = _normalizeResponseData(response.data);
    if (statusCode < 200 || statusCode >= 300) {
      throw GardenSnapshotApiException(
        kind: GardenSnapshotApiFailureKind.http,
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
        throw const GardenSnapshotApiException.malformed(message: '响应体为空。');
      }
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        throw const GardenSnapshotApiException.malformed(
          message: '响应 JSON 不是对象。',
        );
      } on GardenSnapshotApiException {
        rethrow;
      } on Object {
        throw const GardenSnapshotApiException.malformed(
          message: '响应不是合法 JSON。',
        );
      }
    }
    throw const GardenSnapshotApiException.malformed(message: '响应体不是对象。');
  }
}
