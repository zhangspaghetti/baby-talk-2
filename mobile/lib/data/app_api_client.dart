import 'dart:convert';

import 'package:baby_talk_mobile/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

abstract class BabyTalkSyncApi {
  const BabyTalkSyncApi();

  Future<String> createSession();

  Future<AppVersionStatus> fetchVersionStatus();

  Future<AppSnapshot> fetchBootstrap({required String sessionId});

  Future<AppSnapshot> completeOnboarding({
    required String sessionId,
    required String caregiverName,
    required String childName,
    required int childAgeMonths,
    required AppDifficulty difficulty,
  });

  Future<AppActionResult> submitPhraseReaction({
    required String sessionId,
    required String activityId,
    required String phraseId,
    required PhraseReaction reaction,
  });

  Future<AppActionResult> waterPatch({
    required String sessionId,
    required String spaceId,
  });

  Future<void> uploadAnalyticsEvents({
    required String sessionId,
    required List<AnalyticsEvent> events,
  });

  Future<CoachChatReply> askCoach({
    required String sessionId,
    required String prompt,
  });
}

class DisabledBabyTalkApiClient extends BabyTalkSyncApi {
  const DisabledBabyTalkApiClient();

  @override
  Future<String> createSession() {
    return Future<String>.error(const BabyTalkApiException('远端同步已禁用。'));
  }

  @override
  Future<AppVersionStatus> fetchVersionStatus() {
    return Future<AppVersionStatus>.error(
      const BabyTalkApiException('远端同步已禁用。'),
    );
  }

  @override
  Future<AppSnapshot> fetchBootstrap({required String sessionId}) {
    return Future<AppSnapshot>.error(const BabyTalkApiException('远端同步已禁用。'));
  }

  @override
  Future<AppSnapshot> completeOnboarding({
    required String sessionId,
    required String caregiverName,
    required String childName,
    required int childAgeMonths,
    required AppDifficulty difficulty,
  }) {
    return Future<AppSnapshot>.error(const BabyTalkApiException('远端同步已禁用。'));
  }

  @override
  Future<AppActionResult> submitPhraseReaction({
    required String sessionId,
    required String activityId,
    required String phraseId,
    required PhraseReaction reaction,
  }) {
    return Future<AppActionResult>.error(
      const BabyTalkApiException('远端同步已禁用。'),
    );
  }

  @override
  Future<AppActionResult> waterPatch({
    required String sessionId,
    required String spaceId,
  }) {
    return Future<AppActionResult>.error(
      const BabyTalkApiException('远端同步已禁用。'),
    );
  }

  @override
  Future<void> uploadAnalyticsEvents({
    required String sessionId,
    required List<AnalyticsEvent> events,
  }) {
    return Future<void>.error(const BabyTalkApiException('远端同步已禁用。'));
  }

  @override
  Future<CoachChatReply> askCoach({
    required String sessionId,
    required String prompt,
  }) {
    return Future<CoachChatReply>.error(const BabyTalkApiException('远端同步已禁用。'));
  }
}

class HttpBabyTalkApiClient extends BabyTalkSyncApi {
  const HttpBabyTalkApiClient({
    this.baseUrl = const String.fromEnvironment(
      'BABY_TALK_API_BASE_URL',
      defaultValue: 'http://127.0.0.1:8080',
    ),
    this.appVersion = const String.fromEnvironment(
      'BABY_TALK_APP_VERSION',
      defaultValue: '1.0.0+1',
    ),
    http.Client? httpClient,
  }) : _httpClient = httpClient;

  final String baseUrl;
  final String appVersion;
  final http.Client? _httpClient;

  static const Duration _timeout = Duration(seconds: 3);

  @override
  Future<String> createSession() async {
    final json = await _postJson('/api/v1/auth/session', const {});
    return _stringValue(json, 'sessionId');
  }

  @override
  Future<AppVersionStatus> fetchVersionStatus() async {
    final json = await _getJson(
      '/api/v1/config/version',
      includeVersionHeader: false,
    );
    final status = _versionStatusFromJson(json);
    if (!_isVersionSupported(appVersion, status.minSupportedVersion)) {
      throw BabyTalkUpgradeRequiredException(
        message: '当前 App 版本过旧，请升级到 ${status.minSupportedVersion} 或更高版本后继续同步。',
        appVersion: appVersion,
        currentVersion: status.currentVersion,
        minSupportedVersion: status.minSupportedVersion,
      );
    }

    return status;
  }

  @override
  Future<AppSnapshot> fetchBootstrap({required String sessionId}) async {
    final json = await _getJson('/api/v1/app/bootstrap', sessionId: sessionId);
    return _snapshotFromJson(json);
  }

  @override
  Future<AppSnapshot> completeOnboarding({
    required String sessionId,
    required String caregiverName,
    required String childName,
    required int childAgeMonths,
    required AppDifficulty difficulty,
  }) async {
    final json = await _postJson('/api/v1/app/onboarding', {
      'caregiverName': caregiverName,
      'childName': childName,
      'childAgeMonths': childAgeMonths,
      'difficulty': difficulty.name,
    }, sessionId: sessionId);

    return _snapshotFromJson(json);
  }

  @override
  Future<AppActionResult> submitPhraseReaction({
    required String sessionId,
    required String activityId,
    required String phraseId,
    required PhraseReaction reaction,
  }) async {
    final json = await _postJson('/api/v1/app/reactions', {
      'activityId': activityId,
      'phraseId': phraseId,
      'reaction': reaction.name,
    }, sessionId: sessionId);

    return _actionResultFromJson(json);
  }

  @override
  Future<AppActionResult> waterPatch({
    required String sessionId,
    required String spaceId,
  }) async {
    final json = await _postJson('/api/v1/app/water', {
      'spaceId': spaceId,
    }, sessionId: sessionId);
    return _actionResultFromJson(json);
  }

  @override
  Future<void> uploadAnalyticsEvents({
    required String sessionId,
    required List<AnalyticsEvent> events,
  }) async {
    await _postJson('/api/v1/analytics/events', {
      'events': events.map((event) => event.toJson()).toList(growable: false),
    }, sessionId: sessionId);
  }

  @override
  Future<CoachChatReply> askCoach({
    required String sessionId,
    required String prompt,
  }) async {
    final json = await _postJson('/api/v1/coach/ask', {
      'prompt': prompt,
    }, sessionId: sessionId);
    return _coachReplyFromJson(json);
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    bool includeVersionHeader = true,
    String? sessionId,
  }) async {
    return _send(
      (client) => client.get(
        _uri(path),
        headers: _headers(
          includeVersionHeader: includeVersionHeader,
          sessionId: sessionId,
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, Object?> body, {
    bool includeVersionHeader = true,
    String? sessionId,
  }) async {
    return _send(
      (client) => client.post(
        _uri(path),
        headers: _headers(
          includeContentType: true,
          includeVersionHeader: includeVersionHeader,
          sessionId: sessionId,
        ),
        body: jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function(http.Client client) request,
  ) async {
    final client = _httpClient ?? http.Client();
    final shouldClose = _httpClient == null;

    try {
      final response = await request(client).timeout(_timeout);
      if (response.statusCode == 401) {
        throw const BabyTalkSessionExpiredException('同步会话已失效，请重新建立。');
      }
      if (response.statusCode == 426) {
        throw _upgradeExceptionFromResponse(response);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw BabyTalkApiException('接口返回异常状态 ${response.statusCode}。');
      }

      final decoded = _decodeObject(response.body);
      if (decoded == null) {
        throw const BabyTalkApiException('接口响应不是对象结构。');
      }

      return decoded;
    } catch (error) {
      if (error is BabyTalkApiException) {
        rethrow;
      }
      throw BabyTalkApiException('无法连接 Baby Talk 后端：$error');
    } finally {
      if (shouldClose) {
        client.close();
      }
    }
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> _headers({
    bool includeContentType = false,
    bool includeVersionHeader = true,
    String? sessionId,
  }) {
    final headers = <String, String>{};
    if (includeContentType) {
      headers['Content-Type'] = 'application/json';
    }
    if (includeVersionHeader) {
      headers['X-App-Version'] = appVersion;
    }
    if (sessionId != null && sessionId.isNotEmpty) {
      headers['X-Session-Id'] = sessionId;
    }
    return headers;
  }

  Map<String, dynamic>? _decodeObject(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on FormatException {
      return null;
    }

    return null;
  }

  BabyTalkUpgradeRequiredException _upgradeExceptionFromResponse(
    http.Response response,
  ) {
    final json = _decodeObject(response.body);
    if (json != null) {
      return BabyTalkUpgradeRequiredException(
        message:
            _nullableStringValue(json, 'message') ?? '当前 App 版本过旧，请升级后继续同步。',
        appVersion:
            _nullableStringValue(json, 'requestedVersion') ?? appVersion,
        currentVersion: _nullableStringValue(json, 'currentVersion'),
        minSupportedVersion: _nullableStringValue(json, 'minSupportedVersion'),
      );
    }

    return BabyTalkUpgradeRequiredException(
      message: '当前 App 版本过旧，请升级后继续同步。',
      appVersion: appVersion,
      currentVersion: response.headers['x-current-version'],
      minSupportedVersion: response.headers['x-min-supported-version'],
    );
  }

  AppActionResult _actionResultFromJson(Map<String, dynamic> json) {
    return AppActionResult(
      snapshot: _snapshotFromJson(_mapValue(json, 'snapshot')),
      celebration: _nullableMapValue(json, 'celebration') == null
          ? null
          : _celebrationFromJson(_nullableMapValue(json, 'celebration')!),
    );
  }

  AppSnapshot _snapshotFromJson(Map<String, dynamic> json) {
    final coachSuggestions = _listValue(json, 'coachSuggestions')
        .map((item) => _coachSuggestionFromJson(item as Map<String, dynamic>))
        .toList(growable: false);

    return AppSnapshot(
      caregiverName: _stringValue(json, 'caregiverName'),
      childName: _stringValue(json, 'childName'),
      childAgeMonths: _intValue(json, 'childAgeMonths'),
      difficulty: _difficultyFromString(_stringValue(json, 'difficulty')),
      onboardingComplete: json['onboardingComplete'] as bool? ?? false,
      growthPoints: _intValue(json, 'growthPoints'),
      weeklyPhraseCount: _intValue(json, 'weeklyPhraseCount'),
      streakDays: _intValue(json, 'streakDays'),
      earnedMilestoneIds: _listValue(
        json,
        'earnedMilestoneIds',
      ).map((item) => item.toString()).toSet(),
      spaces: _listValue(json, 'spaces')
          .map((item) => _spaceFromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      diaryEntries: _listValue(json, 'diaryEntries')
          .map((item) => _diaryEntryFromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      milestones: _listValue(json, 'milestones')
          .map((item) => _milestoneFromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      coachSuggestions: coachSuggestions,
    );
  }

  CelebrationMoment _celebrationFromJson(Map<String, dynamic> json) {
    return CelebrationMoment(
      title: _stringValue(json, 'title'),
      detail: _stringValue(json, 'detail'),
      activityName: _stringValue(json, 'activityName'),
      gainedPoints: _intValue(json, 'gainedPoints'),
    );
  }

  CoachChatReply _coachReplyFromJson(Map<String, dynamic> json) {
    return CoachChatReply(
      answer: _stringValue(json, 'answer'),
      suggestedPhraseEnglish: _nullableStringValue(
        json,
        'suggestedPhraseEnglish',
      ),
      suggestedPhraseChinese: _nullableStringValue(
        json,
        'suggestedPhraseChinese',
      ),
      followUpPrompt: _nullableStringValue(json, 'followUpPrompt'),
    );
  }

  AppVersionStatus _versionStatusFromJson(Map<String, dynamic> json) {
    return AppVersionStatus(
      currentVersion: _stringValue(json, 'currentVersion'),
      minSupportedVersion: _stringValue(json, 'minSupportedVersion'),
      upgradeRequired: json['upgradeRequired'] as bool? ?? false,
      message: _nullableStringValue(json, 'message'),
    );
  }

  SpaceItem _spaceFromJson(Map<String, dynamic> json) {
    return SpaceItem(
      id: _stringValue(json, 'id'),
      name: _stringValue(json, 'name'),
      subtitle: _stringValue(json, 'subtitle'),
      icon: _iconFromKey(_stringValue(json, 'iconKey')),
      color: _colorFromHex(_stringValue(json, 'colorHex')),
      mapOffset: Offset(
        _doubleValue(json, 'mapOffsetX'),
        _doubleValue(json, 'mapOffsetY'),
      ),
      activities: _listValue(json, 'activities')
          .map((item) => _activityFromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  ActivityItem _activityFromJson(Map<String, dynamic> json) {
    return ActivityItem(
      id: _stringValue(json, 'id'),
      name: _stringValue(json, 'name'),
      shortLabel: _stringValue(json, 'shortLabel'),
      icon: _iconFromKey(_stringValue(json, 'iconKey')),
      progress: _doubleValue(json, 'progress'),
      growthStage: _growthStageFromString(_stringValue(json, 'growthStage')),
      phrases: _listValue(json, 'phrases')
          .map((item) => _phraseFromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  PhraseItem _phraseFromJson(Map<String, dynamic> json) {
    return PhraseItem(
      id: _stringValue(json, 'id'),
      english: _stringValue(json, 'english'),
      chinese: _stringValue(json, 'chinese'),
      mastered: json['mastered'] as bool? ?? false,
    );
  }

  DiaryEntry _diaryEntryFromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      title: _stringValue(json, 'title'),
      subtitle: _stringValue(json, 'subtitle'),
      timeLabel: _stringValue(json, 'timeLabel'),
      type: _diaryEntryTypeFromString(_stringValue(json, 'type')),
    );
  }

  MilestoneEntry _milestoneFromJson(Map<String, dynamic> json) {
    return MilestoneEntry(
      title: _stringValue(json, 'title'),
      detail: _stringValue(json, 'detail'),
      timeLabel: _stringValue(json, 'timeLabel'),
    );
  }

  CoachSuggestion _coachSuggestionFromJson(Map<String, dynamic> json) {
    return CoachSuggestion(
      title: _stringValue(json, 'title'),
      detail: _stringValue(json, 'detail'),
    );
  }

  Map<String, dynamic> _mapValue(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is Map<String, dynamic>) {
      return value;
    }
    throw BabyTalkApiException('缺少对象字段 $key。');
  }

  Map<String, dynamic>? _nullableMapValue(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is Map<String, dynamic>) {
      return value;
    }
    throw BabyTalkApiException('字段 $key 不是对象结构。');
  }

  List<dynamic> _listValue(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is List<dynamic>) {
      return value;
    }
    throw BabyTalkApiException('缺少列表字段 $key。');
  }

  String _stringValue(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String) {
      return value;
    }
    throw BabyTalkApiException('缺少字符串字段 $key。');
  }

  String? _nullableStringValue(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }
    throw BabyTalkApiException('字段 $key 不是字符串。');
  }

  int _intValue(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    throw BabyTalkApiException('缺少整数字段 $key。');
  }

  double _doubleValue(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    throw BabyTalkApiException('缺少数字字段 $key。');
  }

  bool _isVersionSupported(String version, String minSupportedVersion) {
    return _compareVersions(version, minSupportedVersion) >= 0;
  }

  int _compareVersions(String left, String right) {
    final leftParts = _parseVersion(left);
    final rightParts = _parseVersion(right);
    final length = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;

    for (var index = 0; index < length; index += 1) {
      final leftPart = index < leftParts.length ? leftParts[index] : 0;
      final rightPart = index < rightParts.length ? rightParts[index] : 0;
      if (leftPart != rightPart) {
        return leftPart.compareTo(rightPart);
      }
    }

    return 0;
  }

  List<int> _parseVersion(String value) {
    var normalized = value.trim();
    final buildSeparator = normalized.indexOf('+');
    if (buildSeparator >= 0) {
      normalized = normalized.substring(0, buildSeparator);
    }

    final preReleaseSeparator = normalized.indexOf('-');
    if (preReleaseSeparator >= 0) {
      normalized = normalized.substring(0, preReleaseSeparator);
    }

    final tokens = normalized.split('.');
    final parts = <int>[];
    for (final token in tokens) {
      final digits = token.replaceAll(RegExp('[^0-9]'), '');
      parts.add(int.tryParse(digits.isEmpty ? '0' : digits) ?? 0);
    }
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts;
  }

  AppDifficulty _difficultyFromString(String value) {
    switch (value) {
      case 'gentle':
        return AppDifficulty.gentle;
      case 'stretch':
        return AppDifficulty.stretch;
      case 'balanced':
      default:
        return AppDifficulty.balanced;
    }
  }

  GrowthStage _growthStageFromString(String value) {
    switch (value) {
      case 'sprout':
        return GrowthStage.sprout;
      case 'bud':
        return GrowthStage.bud;
      case 'bloom':
        return GrowthStage.bloom;
      case 'seed':
      default:
        return GrowthStage.seed;
    }
  }

  DiaryEntryType _diaryEntryTypeFromString(String value) {
    switch (value) {
      case 'manual_note':
        return DiaryEntryType.manualNote;
      case 'auto_note':
      default:
        return DiaryEntryType.autoNote;
    }
  }

  IconData _iconFromKey(String key) {
    switch (key) {
      case 'wb_sunny_outlined':
        return Icons.wb_sunny_outlined;
      case 'baby_changing_station_outlined':
        return Icons.baby_changing_station_outlined;
      case 'checkroom_outlined':
        return Icons.checkroom_outlined;
      case 'bubble_chart_outlined':
        return Icons.bubble_chart_outlined;
      case 'bathtub_outlined':
        return Icons.bathtub_outlined;
      case 'pan_tool_alt_outlined':
        return Icons.pan_tool_alt_outlined;
      case 'favorite_border':
        return Icons.favorite_border;
      case 'restaurant_outlined':
        return Icons.restaurant_outlined;
      case 'self_improvement_outlined':
        return Icons.self_improvement_outlined;
      case 'directions_run_outlined':
        return Icons.directions_run_outlined;
      case 'waving_hand_outlined':
        return Icons.waving_hand_outlined;
      case 'stroller_outlined':
        return Icons.stroller_outlined;
      case 'auto_stories_outlined':
        return Icons.auto_stories_outlined;
      case 'menu_book_outlined':
        return Icons.menu_book_outlined;
      case 'music_note_outlined':
        return Icons.music_note_outlined;
      case 'nightlight_outlined':
        return Icons.nightlight_outlined;
      case 'bedtime_outlined':
        return Icons.bedtime_outlined;
      case 'brightness_2_outlined':
        return Icons.brightness_2_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  Color _colorFromHex(String value) {
    final normalized = value.replaceFirst('#', '');
    final withAlpha = normalized.length == 6 ? 'FF$normalized' : normalized;
    return Color(int.parse(withAlpha, radix: 16));
  }
}

class BabyTalkApiException implements Exception {
  const BabyTalkApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BabyTalkUpgradeRequiredException extends BabyTalkApiException {
  const BabyTalkUpgradeRequiredException({
    required String message,
    required this.appVersion,
    this.currentVersion,
    this.minSupportedVersion,
  }) : super(message);

  final String appVersion;
  final String? currentVersion;
  final String? minSupportedVersion;
}

class BabyTalkSessionExpiredException extends BabyTalkApiException {
  const BabyTalkSessionExpiredException(super.message);
}

class AppVersionStatus {
  const AppVersionStatus({
    required this.currentVersion,
    required this.minSupportedVersion,
    required this.upgradeRequired,
    this.message,
  });

  final String currentVersion;
  final String minSupportedVersion;
  final bool upgradeRequired;
  final String? message;
}
