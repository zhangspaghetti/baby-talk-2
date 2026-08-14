import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:mobile/core/network/app_dio.dart';
import 'package:mobile/features/care_entry/domain/onboarding_conversation_models.dart';

const String defaultGuestOnboardingApiVersion = String.fromEnvironment(
  'BABY_TALK_API_VERSION',
  defaultValue: '1.2.0',
);
const String defaultGuestOnboardingApiBaseUrl = String.fromEnvironment(
  'BABY_TALK_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8080',
);

final class GuestOnboardingConversationApiException implements Exception {
  const GuestOnboardingConversationApiException(this.code);

  final String code;

  @override
  String toString() => 'GuestOnboardingConversationApiException($code)';
}

final class GuestOnboardingConversationApi
    implements GuestOnboardingConversationGateway {
  GuestOnboardingConversationApi({
    Dio? dio,
    String? baseUrl,
    this.appVersion = defaultGuestOnboardingApiVersion,
  }) : _dio =
           dio ??
           AppDio.create(baseUrl: baseUrl ?? defaultGuestOnboardingApiBaseUrl);

  final Dio _dio;
  final String appVersion;

  @override
  Future<GuestOnboardingConversation> create(
    CreateGuestOnboardingConversation request,
  ) async {
    Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        '/api/v1/onboarding/conversations',
        options: Options(
          headers: <String, String>{
            'Accept': 'application/json',
            'X-App-Version': appVersion,
          },
        ),
        data: <String, Object?>{
          'installationId': request.installationId,
          'localEventId': request.localEventId,
          'careEntryId': request.careEntryId.value,
          'registryRevision': request.registryRevision,
          'generationScene': <String, Object?>{
            'namespace': request.generationScene.namespace,
            'key': request.generationScene.key,
            'version': request.generationScene.version,
            'facets': request.generationScene.facets,
          },
          'locale': request.locale,
          'timeBand': request.timeBand,
          'babyNickname': null,
        },
      );
    } on DioException {
      throw const GuestOnboardingConversationApiException(
        'onboarding_conversation_unavailable',
      );
    }
    final statusCode = response.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      throw GuestOnboardingConversationApiException(
        _safeErrorCode(response.data) ?? 'onboarding_conversation_http_error',
      );
    }
    try {
      final root = _jsonObject(response.data);
      _requireExactKeys(root, const <String>{
        'conversationId',
        'expiresAt',
        'utterance',
      });
      final utterance = _requiredMap(root, 'utterance');
      _requireExactKeys(utterance, const <String>{
        'utteranceId',
        'englishText',
        'chineseText',
        'pronunciationHint',
        'audioRef',
        'source',
      });
      if (_requiredString(utterance, 'source') != 'remote_generated') {
        throw const FormatException('unsupported utterance source');
      }
      final expiresAt = DateTime.parse(_requiredString(root, 'expiresAt'));
      if (!expiresAt.isUtc) {
        throw const FormatException('expiresAt must be UTC');
      }
      return GuestOnboardingConversation(
        conversationId: _requiredString(root, 'conversationId'),
        expiresAt: expiresAt,
        utterance: OnboardingUtterance(
          utteranceId: _requiredString(utterance, 'utteranceId'),
          english: _requiredString(utterance, 'englishText'),
          chinese: _requiredString(utterance, 'chineseText'),
          pronunciation: _requiredString(utterance, 'pronunciationHint'),
          source: OnboardingUtteranceSource.remoteGenerated,
          remoteAudioRef: _optionalString(utterance, 'audioRef'),
        ),
      );
    } on FormatException {
      throw const GuestOnboardingConversationApiException(
        'malformed_onboarding_conversation_response',
      );
    }
  }
}

Map<String, dynamic> _jsonObject(Object? value) {
  final decoded = value is String ? jsonDecode(value) : value;
  if (decoded is! Map) throw const FormatException('object required');
  return decoded.map<String, dynamic>((key, value) {
    if (key is! String) throw const FormatException('string key required');
    return MapEntry(key, value);
  });
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! Map) throw FormatException('$field must be object');
  return value.map<String, dynamic>((key, value) {
    if (key is! String) throw FormatException('$field has non-string key');
    return MapEntry(key, value);
  });
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! String || value.isEmpty || value != value.trim()) {
    throw FormatException('$field must be normalized string');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String field) {
  final value = json[field];
  return value == null ? null : _requiredString(json, field);
}

void _requireExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.keys.toSet().difference(expected).isNotEmpty ||
      expected.difference(json.keys.toSet()).isNotEmpty) {
    throw const FormatException('unexpected response shape');
  }
}

String? _safeErrorCode(Object? value) {
  try {
    final root = _jsonObject(value);
    final code = root['code'];
    return code is String && RegExp(r'^[a-z0-9_]{1,80}$').hasMatch(code)
        ? code
        : null;
  } on Object {
    return null;
  }
}
