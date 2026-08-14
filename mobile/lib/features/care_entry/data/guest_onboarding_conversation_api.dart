import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:mobile/core/network/app_dio.dart';
import 'package:mobile/features/care_entry/data/guest_onboarding_audio_api.dart';
import 'package:mobile/features/care_entry/domain/care_entry_models.dart';
import 'package:mobile/features/care_entry/domain/onboarding_conversation_models.dart';

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
    required GuestAudioCapabilityVault audioCapabilities,
    Dio? dio,
    String? baseUrl,
    this.appVersion = defaultGuestOnboardingApiVersion,
  }) : _audioCapabilities = audioCapabilities,
       _dio =
           dio ??
           AppDio.create(baseUrl: baseUrl ?? defaultGuestOnboardingApiBaseUrl);

  final Dio _dio;
  final GuestAudioCapabilityVault _audioCapabilities;
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
    return _parseResponse(response.data);
  }

  @override
  Future<GuestOnboardingConversation> nextSupport(
    NextGuestOnboardingTurn request,
  ) async {
    if (!_safeId.hasMatch(request.conversationId) ||
        !_safeId.hasMatch(request.localEventId) ||
        !_safeId.hasMatch(request.previousUtteranceId)) {
      throw const GuestOnboardingConversationApiException(
        'invalid_onboarding_turn',
      );
    }
    Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        '/api/v1/onboarding/conversations/${request.conversationId}/turns',
        options: Options(
          headers: <String, String>{
            'Accept': 'application/json',
            'X-App-Version': appVersion,
          },
        ),
        data: <String, Object?>{
          'localEventId': request.localEventId,
          'previousUtteranceId': request.previousUtteranceId,
          'parentAction': 'said_it',
          'reactionProvided': request.reaction != null,
          'reaction': request.reaction?.wireValue,
          'reactionText': request.reactionText,
          'generationScene': <String, Object?>{
            'namespace': request.generationScene.namespace,
            'key': request.generationScene.key,
            'version': request.generationScene.version,
            'facets': request.generationScene.facets,
          },
        },
      );
    } on DioException {
      throw const GuestOnboardingConversationApiException(
        'onboarding_turn_unavailable',
      );
    }
    final statusCode = response.statusCode ?? 0;
    if (statusCode < 200 || statusCode >= 300) {
      throw GuestOnboardingConversationApiException(
        _safeErrorCode(response.data) ?? 'onboarding_turn_http_error',
      );
    }
    final result = _parseResponse(response.data);
    if (result.conversationId != request.conversationId) {
      throw const GuestOnboardingConversationApiException(
        'malformed_onboarding_conversation_response',
      );
    }
    return result;
  }

  GuestOnboardingConversation _parseResponse(Object? body) {
    try {
      final root = _jsonObject(body);
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
      final conversationId = _requiredId(root, 'conversationId');
      final utteranceId = _requiredId(utterance, 'utteranceId');
      final capability = _requiredString(utterance, 'audioRef');
      _audioCapabilities.register(
        conversationId: conversationId,
        utteranceId: utteranceId,
        capability: capability,
        expiresAt: expiresAt,
      );
      return GuestOnboardingConversation(
        conversationId: conversationId,
        expiresAt: expiresAt,
        utterance: OnboardingUtterance(
          utteranceId: utteranceId,
          english: _requiredString(utterance, 'englishText'),
          chinese: _requiredString(utterance, 'chineseText'),
          pronunciation: _requiredString(utterance, 'pronunciationHint'),
          source: OnboardingUtteranceSource.remoteGenerated,
          remoteAudioAvailable: true,
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

String _requiredId(Map<String, dynamic> json, String field) {
  final value = _requiredString(json, field);
  if (!_safeId.hasMatch(value)) {
    throw FormatException('$field must be safe id');
  }
  return value;
}

final RegExp _safeId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.:-]{5,95}$');

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
