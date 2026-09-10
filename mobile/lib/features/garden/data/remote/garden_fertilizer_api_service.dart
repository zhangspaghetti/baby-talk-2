import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:mobile/core/network/app_dio.dart';
import 'package:mobile/core/network/auth_headers.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart'
    show
        AccountApiException,
        AccountApiFailureKind,
        defaultAccountApiBaseUrl,
        defaultAccountApiVersion;
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
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
  Future<FertilizerState> fetchState({
    AccountSession? session,
    PersistRefreshedSession? persistRefreshedSession,
  });

  Future<FertilizerState> claim({
    required String eventKey,
    required String requestId,
    AccountSession? session,
    PersistRefreshedSession? persistRefreshedSession,
  });

  Future<FertilizerState> apply({
    required String requestId,
    AccountSession? session,
    PersistRefreshedSession? persistRefreshedSession,
  });
}

class GardenFertilizerApiService implements GardenFertilizerRemoteDataSource {
  GardenFertilizerApiService({
    Dio? dio,
    AuthenticatedApiClient? authenticatedApiClient,
    String? baseUrl,
    this.appVersion = defaultAccountApiVersion,
  }) : _dio =
           dio ?? AppDio.create(baseUrl: baseUrl ?? defaultAccountApiBaseUrl),
       _authenticatedApiClient = authenticatedApiClient,
       _ownsDio = dio == null;

  final Dio _dio;
  final AuthenticatedApiClient? _authenticatedApiClient;
  final bool _ownsDio;
  final String appVersion;

  @override
  Future<FertilizerState> fetchState({
    AccountSession? session,
    PersistRefreshedSession? persistRefreshedSession,
  }) async {
    final json = await _request(
      'GET',
      '/api/v1/garden/fertilizer',
      session: session,
      persistRefreshedSession: persistRefreshedSession,
    );
    return _readFertilizerState(json);
  }

  @override
  Future<FertilizerState> claim({
    required String eventKey,
    required String requestId,
    AccountSession? session,
    PersistRefreshedSession? persistRefreshedSession,
  }) async {
    final json = await _request(
      'POST',
      '/api/v1/garden/fertilizer/claim',
      body: <String, Object?>{'eventKey': eventKey, 'requestId': requestId},
      session: session,
      persistRefreshedSession: persistRefreshedSession,
    );
    return _readFertilizerState(json);
  }

  @override
  Future<FertilizerState> apply({
    required String requestId,
    AccountSession? session,
    PersistRefreshedSession? persistRefreshedSession,
  }) async {
    final json = await _request(
      'POST',
      '/api/v1/garden/fertilizer/apply',
      body: <String, Object?>{'requestId': requestId},
      session: session,
      persistRefreshedSession: persistRefreshedSession,
    );
    return _readFertilizerState(json);
  }

  void close() {
    if (_ownsDio) {
      _dio.close();
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
    AccountSession? session,
    PersistRefreshedSession? persistRefreshedSession,
  }) async {
    if (session == null) return _requestJson(method, path, body: body);
    final client = _authenticatedApiClient;
    final persist = persistRefreshedSession;
    if (client == null || persist == null) {
      throw const GardenFertilizerApiException.malformed(
        message: '肥料服务缺少认证配置。',
      );
    }
    try {
      return (await client.execute<Map<String, dynamic>>(
        session: session,
        persistRefreshedSession: persist,
        send: (token) async {
          try {
            return await _requestJson(
              method,
              path,
              body: body,
              accessToken: token,
            );
          } on GardenFertilizerApiException catch (error) {
            if (error.statusCode == 401) {
              throw AccountApiException(
                kind: AccountApiFailureKind.http,
                message: error.message,
                statusCode: error.statusCode,
              );
            }
            rethrow;
          }
        },
      )).value;
    } on AuthenticatedApiClientException catch (error) {
      throw GardenFertilizerApiException(
        kind: GardenFertilizerApiFailureKind.http,
        message: error.visibleMessage,
        statusCode: 401,
      );
    }
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    String path, {
    Map<String, Object?>? body,
    String? accessToken,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'X-App-Version': appVersion,
      authorizationHeaderName: ?buildBearerAuthorizationHeaderValue(
        accessToken,
      ),
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
    if (data is String) {
      if (data.trim().isEmpty) {
        throw const GardenFertilizerApiException.malformed(message: '响应体为空。');
      }
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        throw const GardenFertilizerApiException.malformed(
          message: '响应 JSON 不是对象。',
        );
      } on GardenFertilizerApiException {
        rethrow;
      } on Object {
        throw const GardenFertilizerApiException.malformed(
          message: '响应不是合法 JSON。',
        );
      }
    }
    throw const GardenFertilizerApiException.malformed(message: '响应体不是对象。');
  }

  FertilizerState _readFertilizerState(Map<String, dynamic> json) {
    final stateJson = _readStateMap(json);
    final hasAppliedCount = _hasIntValue(stateJson, 'appliedCount');
    final hasClaimedEventKeys = _hasStringListValue(
      stateJson,
      'claimedEventKeys',
    );

    if (!hasAppliedCount && !hasClaimedEventKeys) {
      throw const GardenFertilizerApiException.malformed(
        message: '缺少可用的肥料状态关键字段。',
      );
    }

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

bool _hasIntValue(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is num;
}

bool _hasStringListValue(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is List;
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
