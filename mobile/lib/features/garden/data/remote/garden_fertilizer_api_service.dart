import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:mobile/core/network/app_dio.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart'
    show defaultAccountApiBaseUrl, defaultAccountApiVersion;
import 'package:mobile/features/garden/domain/models/fertilizer_state.dart';

enum GardenFertilizerApiFailureKind { network, timeout, malformed, http }

class GardenFertilizerApiException implements Exception {
  const GardenFertilizerApiException({
    required this.kind,
    required this.message,
    this.statusCode,
  });

  const GardenFertilizerApiException.network({required String message})
    : this(kind: GardenFertilizerApiFailureKind.network, message: message);

  const GardenFertilizerApiException.timeout({required String message})
    : this(kind: GardenFertilizerApiFailureKind.timeout, message: message);

  const GardenFertilizerApiException.malformed({required String message})
    : this(kind: GardenFertilizerApiFailureKind.malformed, message: message);

  final GardenFertilizerApiFailureKind kind;
  final String message;
  final int? statusCode;

  @override
  String toString() {
    return 'GardenFertilizerApiException(kind: $kind, statusCode: $statusCode, message: $message)';
  }
}

abstract class GardenFertilizerRemoteDataSource {
  Future<FertilizerState> fetchState();

  Future<FertilizerState> claim({
    required String eventKey,
    required String requestId,
  });

  Future<FertilizerState> apply({required String requestId});
}

class GardenFertilizerApiService implements GardenFertilizerRemoteDataSource {
  GardenFertilizerApiService({
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
  Future<FertilizerState> fetchState() async {
    final json = await _requestJson('GET', '/api/v1/garden/fertilizer/state');
    return _readFertilizerState(json);
  }

  @override
  Future<FertilizerState> claim({
    required String eventKey,
    required String requestId,
  }) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/garden/fertilizer/claim',
      body: <String, Object?>{'eventKey': eventKey, 'requestId': requestId},
    );
    return _readFertilizerState(json);
  }

  @override
  Future<FertilizerState> apply({required String requestId}) async {
    final json = await _requestJson(
      'POST',
      '/api/v1/garden/fertilizer/apply',
      body: <String, Object?>{'requestId': requestId},
    );
    return _readFertilizerState(json);
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
        throw const GardenFertilizerApiException.timeout(message: '请求超时。');
      }
      if (error.error is SocketException) {
        throw const GardenFertilizerApiException.network(message: '网络不可用。');
      }
      throw const GardenFertilizerApiException.network(message: '网络请求失败。');
    }

    final statusCode = response.statusCode ?? 0;
    final decoded = _normalizeResponseData(response.data);

    if (statusCode < 200 || statusCode >= 300) {
      throw GardenFertilizerApiException(
        kind: GardenFertilizerApiFailureKind.http,
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
    if (data is String && data.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } on Object {
        throw const GardenFertilizerApiException.malformed(
          message: '响应不是合法 JSON。',
        );
      }
    }
    return <String, dynamic>{};
  }

  FertilizerState _readFertilizerState(Map<String, dynamic> json) {
    final stateJson = _readStateMap(json);

    final appliedCount = _readInt(stateJson, 'appliedCount');
    final claimedEventKeys = _readStringSet(stateJson, 'claimedEventKeys');
    final lastClaimedAt = _readDateTime(stateJson, 'lastClaimedAt');
    final lastAppliedAt = _readDateTime(stateJson, 'lastAppliedAt');

    return FertilizerState(
      appliedCount: appliedCount,
      claimedEventKeys: claimedEventKeys,
      lastClaimedAt: lastClaimedAt,
      lastAppliedAt: lastAppliedAt,
    );
  }
}

Map<String, dynamic> _readStateMap(Map<String, dynamic> json) {
  final state = json['state'];
  if (state is Map<String, dynamic>) {
    return state;
  }
  return json;
}

int _readInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return 0;
}

Set<String> _readStringSet(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    return <String>{};
  }

  final result = <String>{};
  for (final item in value) {
    if (item is String && item.trim().isNotEmpty) {
      result.add(item);
    }
  }
  return result;
}

DateTime? _readDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value)?.toLocal();
}