import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mobile/features/account/data/services/account_api_service.dart'
    show defaultAccountApiBaseUrl, defaultAccountApiVersion;

/// 动态练习 API 响应中的单个短语
class DynamicPhrase {
  const DynamicPhrase({
    required this.english,
    required this.chinese,
    required this.pronunciation,
    required this.difficulty,
  });

  factory DynamicPhrase.fromJson(Map<String, dynamic> json) {
    return DynamicPhrase(
      english: _readString(json, 'english'),
      chinese: _readString(json, 'chinese'),
      pronunciation: _readString(json, 'pronunciation'),
      difficulty: _readString(json, 'difficulty'),
    );
  }

  final String english;
  final String chinese;
  final String pronunciation;
  final String difficulty;
}

/// 动态练习 API 响应中的单个活动
class DynamicActivity {
  const DynamicActivity({
    required this.title,
    required this.summary,
    required this.sceneTag,
    required this.coachTip,
    required this.phrases,
  });

  factory DynamicActivity.fromJson(Map<String, dynamic> json) {
    final rawPhrases = json['phrases'];
    final phrases = <DynamicPhrase>[];
    if (rawPhrases is List) {
      for (final item in rawPhrases) {
        if (item is Map<String, dynamic>) {
          phrases.add(DynamicPhrase.fromJson(item));
        }
      }
    }
    return DynamicActivity(
      title: _readString(json, 'title'),
      summary: _readString(json, 'summary'),
      sceneTag: _readString(json, 'sceneTag'),
      coachTip: _readString(json, 'coachTip'),
      phrases: List.unmodifiable(phrases),
    );
  }

  final String title;
  final String summary;
  final String sceneTag;
  final String coachTip;
  final List<DynamicPhrase> phrases;
}

/// 动态练习 API 的完整响应
class DynamicPracticeResponse {
  const DynamicPracticeResponse({required this.activities});

  factory DynamicPracticeResponse.fromJson(Map<String, dynamic> json) {
    final rawActivities = json['activities'];
    final activities = <DynamicActivity>[];
    if (rawActivities is List) {
      for (final item in rawActivities) {
        if (item is Map<String, dynamic>) {
          activities.add(DynamicActivity.fromJson(item));
        }
      }
    }
    return DynamicPracticeResponse(activities: List.unmodifiable(activities));
  }

  final List<DynamicActivity> activities;
}

/// 动态练习 API 失败类型
enum DynamicPracticeFailureKind { network, timeout, malformed, http }

/// 动态练习 API 异常
class DynamicPracticeApiException implements Exception {
  const DynamicPracticeApiException({
    required this.kind,
    required this.message,
    this.statusCode,
  });

  const DynamicPracticeApiException.network({required String message})
    : this(kind: DynamicPracticeFailureKind.network, message: message);

  const DynamicPracticeApiException.timeout({required String message})
    : this(kind: DynamicPracticeFailureKind.timeout, message: message);

  const DynamicPracticeApiException.malformed({required String message})
    : this(kind: DynamicPracticeFailureKind.malformed, message: message);

  final DynamicPracticeFailureKind kind;
  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'DynamicPracticeApiException(kind: $kind, statusCode: $statusCode, message: $message)';
}

/// 调用后端 POST /api/v1/mentor/practice/generate 生成动态练习内容
class DynamicPracticeApiService {
  DynamicPracticeApiService({
    http.Client? client,
    Uri? baseUri,
    this.appVersion = defaultAccountApiVersion,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _baseUri = baseUri ?? Uri.parse(defaultAccountApiBaseUrl);

  final http.Client _client;
  final bool _ownsClient;
  final Uri _baseUri;
  final String appVersion;
  final Duration timeout;

  /// 调用 practice/generate API
  ///
  /// [installationId] 设备标识
  /// [babyAgeMonths] 宝宝月龄
  /// [sceneTag] 可选场景标签
  /// [conversationId] 可选会话 ID（暂不使用）
  Future<DynamicPracticeResponse> generatePractice({
    required String installationId,
    required int babyAgeMonths,
    String? sceneTag,
    String? conversationId,
  }) async {
    final body = <String, Object?>{
      'installationId': installationId,
      'surface': 'practice',
      'babyAgeMonths': babyAgeMonths,
      if (sceneTag != null && sceneTag.trim().isNotEmpty)
        'sceneTag': sceneTag.trim(),
      if (conversationId != null && conversationId.trim().isNotEmpty)
        'conversationId': conversationId.trim(),
    };

    final uri = _resolveUri('/api/v1/mentor/practice/generate');
    final request = http.Request('POST', uri);
    request.headers['Accept'] = 'application/json';
    request.headers['Content-Type'] = 'application/json';
    request.headers['X-App-Version'] = appVersion;
    request.body = jsonEncode(body);

    http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(timeout);
    } on TimeoutException {
      throw const DynamicPracticeApiException.timeout(message: '练习生成请求超时。');
    } on SocketException {
      throw const DynamicPracticeApiException.network(message: '网络不可用。');
    } on http.ClientException {
      throw const DynamicPracticeApiException.network(message: '网络请求失败。');
    }

    final materialized = await http.Response.fromStream(response);
    if (materialized.statusCode < 200 || materialized.statusCode >= 300) {
      throw DynamicPracticeApiException(
        kind: DynamicPracticeFailureKind.http,
        message: '练习生成请求失败 (${materialized.statusCode})。',
        statusCode: materialized.statusCode,
      );
    }

    try {
      final decoded = jsonDecode(materialized.body);
      if (decoded is! Map<String, dynamic>) {
        throw const DynamicPracticeApiException.malformed(
          message: '响应顶层不是 JSON 对象。',
        );
      }
      return DynamicPracticeResponse.fromJson(decoded);
    } on DynamicPracticeApiException {
      rethrow;
    } on FormatException catch (e) {
      throw DynamicPracticeApiException.malformed(message: '响应 JSON 解析失败：$e');
    } catch (e) {
      throw DynamicPracticeApiException.malformed(message: '响应解析失败：$e');
    }
  }

  Future<void> close() async {
    if (_ownsClient) {
      _client.close();
    }
  }

  Uri _resolveUri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final basePath = _baseUri.path.endsWith('/')
        ? _baseUri.path.substring(0, _baseUri.path.length - 1)
        : _baseUri.path;
    return _baseUri.replace(path: '$basePath$normalizedPath');
  }
}

String _readString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  return '';
}
