import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:mobile/core/network/app_dio.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart'
    show defaultAccountApiBaseUrl, defaultAccountApiVersion;
import 'package:mobile/features/practice/domain/models/preset_scene_definition.dart';

const String presetSceneCatalogPath = '/api/v1/practice/preset-scenes';

enum PresetSceneCatalogFailureKind { network, timeout, malformed, http }

class PresetSceneCatalogApiException implements Exception {
  const PresetSceneCatalogApiException({
    required this.kind,
    required this.message,
    this.statusCode,
  });

  const PresetSceneCatalogApiException.network({
    String message = '预置场景目录网络不可用。',
  }) : this(kind: PresetSceneCatalogFailureKind.network, message: message);

  const PresetSceneCatalogApiException.timeout({String message = '预置场景目录请求超时。'})
    : this(kind: PresetSceneCatalogFailureKind.timeout, message: message);

  const PresetSceneCatalogApiException.malformed({
    String message = '预置场景目录响应格式非法。',
  }) : this(kind: PresetSceneCatalogFailureKind.malformed, message: message);

  final PresetSceneCatalogFailureKind kind;
  final String message;
  final int? statusCode;

  @override
  String toString() {
    // Never include response body or URL: catalog payload is server-owned and
    // diagnostics must stay safe even when the server returns private text.
    return 'PresetSceneCatalogApiException(kind: $kind, statusCode: $statusCode)';
  }
}

/// Public, unauthenticated transport for the published preset catalog.
///
/// The class is intentionally non-final so repository tests and platform
/// adapters can provide a small fake without replacing the repository seam.
class PresetSceneCatalogApi {
  PresetSceneCatalogApi({
    Dio? dio,
    String? baseUrl,
    this.appVersion = defaultAccountApiVersion,
    this.timeout = const Duration(seconds: 3),
    Future<List<PresetSceneDefinition>> Function()? loader,
  }) : _dio =
           dio ?? AppDio.create(baseUrl: baseUrl ?? defaultAccountApiBaseUrl),
       _ownsDio = dio == null,
       _loader = loader;

  final Dio _dio;
  final bool _ownsDio;
  final Future<List<PresetSceneDefinition>> Function()? _loader;
  final String appVersion;
  final Duration timeout;
  CancelToken? _cancelTokenForNextRequest;

  Future<List<PresetSceneDefinition>> fetchPublishedScenes() {
    final loader = _loader;
    if (loader != null) {
      return loader().then(List<PresetSceneDefinition>.unmodifiable);
    }
    return _fetchPublishedScenes(cancelToken: _cancelTokenForNextRequest);
  }

  /// Runs the normal fetch while allowing a repository timeout to cancel the
  /// underlying Dio request. Subclasses overriding [fetchPublishedScenes]
  /// retain a simple fake seam; their late futures are still ignored by the
  /// repository before any cache write.
  Future<List<PresetSceneDefinition>> fetchPublishedScenesWithCancellation({
    CancelToken? cancelToken,
  }) {
    final previous = _cancelTokenForNextRequest;
    _cancelTokenForNextRequest = cancelToken;
    final future = fetchPublishedScenes();
    return future.whenComplete(() {
      if (identical(_cancelTokenForNextRequest, cancelToken)) {
        _cancelTokenForNextRequest = previous;
      }
    });
  }

  Future<List<PresetSceneDefinition>> _fetchPublishedScenes({
    CancelToken? cancelToken,
  }) async {
    Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(
        presetSceneCatalogPath,
        cancelToken: cancelToken,
        options: Options(
          headers: <String, String>{
            'Accept': 'application/json',
            'X-App-Version': appVersion,
          },
          validateStatus: (_) => true,
          sendTimeout: timeout,
          receiveTimeout: timeout,
        ),
      );
    } on DioException catch (error) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        throw const PresetSceneCatalogApiException.timeout();
      }
      if (error.error is SocketException) {
        throw const PresetSceneCatalogApiException.network();
      }
      throw const PresetSceneCatalogApiException.network();
    }

    final statusCode = response.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      throw PresetSceneCatalogApiException(
        kind: PresetSceneCatalogFailureKind.http,
        message: '预置场景目录请求失败。',
        statusCode: statusCode,
      );
    }

    try {
      final decoded = _decodeResponse(response.data);
      return PresetSceneDefinition.parseList(decoded);
    } on PresetSceneCatalogApiException {
      rethrow;
    } on FormatException {
      throw const PresetSceneCatalogApiException.malformed();
    } on Object {
      throw const PresetSceneCatalogApiException.malformed();
    }
  }

  /// Alias kept at the transport boundary for callers that call the endpoint
  /// a catalog fetch rather than a published-scenes fetch.
  Future<List<PresetSceneDefinition>> fetchCatalog() => fetchPublishedScenes();

  void close() {
    if (_ownsDio) {
      _dio.close();
    }
  }

  Object? _decodeResponse(dynamic data) {
    if (data is List) {
      return data;
    }
    if (data is String && data.trim().isNotEmpty) {
      try {
        return jsonDecode(data);
      } on FormatException {
        throw const PresetSceneCatalogApiException.malformed();
      }
    }
    throw const PresetSceneCatalogApiException.malformed();
  }
}
