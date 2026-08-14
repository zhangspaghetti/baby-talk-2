import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:mobile/core/network/app_dio.dart';
import 'package:mobile/features/care_entry/domain/onboarding_conversation_models.dart';

const String onboardingAudioCapabilityHeader = 'X-Onboarding-Audio-Capability';
const String defaultGuestOnboardingApiVersion = String.fromEnvironment(
  'BABY_TALK_API_VERSION',
  defaultValue: '1.2.0',
);
const String defaultGuestOnboardingAudioApiBaseUrl = String.fromEnvironment(
  'BABY_TALK_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8080',
);

final class GuestAudioCapabilityVault {
  final Map<_GuestAudioKey, _GuestAudioCapability> _capabilities =
      <_GuestAudioKey, _GuestAudioCapability>{};

  void register({
    required String conversationId,
    required String utteranceId,
    required String capability,
    required DateTime expiresAt,
  }) {
    if (!_safeGuestAudioId.hasMatch(conversationId) ||
        !_safeGuestAudioId.hasMatch(utteranceId) ||
        capability.isEmpty ||
        capability.length > 512 ||
        !expiresAt.isUtc) {
      throw const FormatException('invalid guest audio capability');
    }
    _capabilities[_GuestAudioKey(conversationId, utteranceId)] =
        _GuestAudioCapability(capability, expiresAt);
  }

  String requireCapability({
    required String conversationId,
    required String utteranceId,
    required DateTime now,
  }) {
    final key = _GuestAudioKey(conversationId, utteranceId);
    final value = _capabilities[key];
    if (value == null || !value.expiresAt.isAfter(now.toUtc())) {
      _capabilities.remove(key);
      throw const GuestOnboardingAudioException();
    }
    return value.capability;
  }

  void clear() => _capabilities.clear();
}

final class GuestOnboardingAudioException implements Exception {
  const GuestOnboardingAudioException();

  @override
  String toString() => 'GuestOnboardingAudioException';
}

abstract interface class GuestAudioOutput {
  Future<void> playBytes(List<int> bytes, String mimeType);

  Future<void> stop();

  Future<void> dispose();
}

final class AudioplayersGuestAudioOutput implements GuestAudioOutput {
  AudioplayersGuestAudioOutput({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> playBytes(List<int> bytes, String mimeType) =>
      _player.play(BytesSource(Uint8List.fromList(bytes), mimeType: mimeType));

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

final class GuestOnboardingAudioApi implements GuestOnboardingAudioPlayer {
  GuestOnboardingAudioApi({
    required GuestAudioCapabilityVault capabilities,
    Dio? dio,
    String? baseUrl,
    this.appVersion = defaultGuestOnboardingApiVersion,
    GuestAudioOutput? output,
    DateTime Function()? clock,
  }) : _capabilities = capabilities,
       _dio =
           dio ??
           AppDio.create(
             baseUrl: baseUrl ?? defaultGuestOnboardingAudioApiBaseUrl,
           ),
       _ownsDio = dio == null,
       _output = output ?? AudioplayersGuestAudioOutput(),
       _clock = clock ?? DateTime.now;

  final GuestAudioCapabilityVault _capabilities;
  final Dio _dio;
  final bool _ownsDio;
  final GuestAudioOutput _output;
  final DateTime Function() _clock;
  final String appVersion;
  CancelToken? _activeRequest;
  Future<void> _outputTail = Future<void>.value();
  int _intent = 0;

  @override
  Future<void> play({
    required String conversationId,
    required String utteranceId,
  }) async {
    if (!_safeGuestAudioId.hasMatch(conversationId) ||
        !_safeGuestAudioId.hasMatch(utteranceId)) {
      throw const GuestOnboardingAudioException();
    }
    final intent = ++_intent;
    _activeRequest?.cancel('superseded');
    await _withOutputLock(_output.stop);
    if (intent != _intent) return;
    final request = CancelToken();
    _activeRequest = request;
    final capability = _capabilities.requireCapability(
      conversationId: conversationId,
      utteranceId: utteranceId,
      now: _clock(),
    );
    Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(
        '/api/v1/onboarding/conversations/$conversationId/'
        'utterances/$utteranceId/audio',
        cancelToken: request,
        options: Options(
          responseType: ResponseType.bytes,
          headers: <String, String>{
            'Accept': 'audio/mpeg',
            'X-App-Version': appVersion,
            onboardingAudioCapabilityHeader: capability,
          },
        ),
      );
    } on DioException {
      if (intent != _intent) return;
      throw const GuestOnboardingAudioException();
    }
    if (intent != _intent) return;
    final status = response.statusCode ?? 0;
    final mimeType = response.headers.value(Headers.contentTypeHeader);
    final data = response.data;
    final bytes = data is Uint8List
        ? data.toList(growable: false)
        : data is List<int>
        ? List<int>.unmodifiable(data)
        : null;
    if (status < 200 ||
        status >= 300 ||
        mimeType != 'audio/mpeg' ||
        bytes == null ||
        bytes.isEmpty ||
        bytes.length > 1024 * 1024) {
      throw const GuestOnboardingAudioException();
    }
    await _withOutputLock(() async {
      if (intent != _intent) return;
      await _output.playBytes(bytes, mimeType!);
      if (intent != _intent) {
        await _output.stop();
      }
    });
  }

  @override
  Future<void> stop() async {
    _intent += 1;
    _activeRequest?.cancel('stopped');
    _activeRequest = null;
    await _withOutputLock(_output.stop);
  }

  @override
  Future<void> dispose() async {
    _intent += 1;
    _activeRequest?.cancel('disposed');
    _activeRequest = null;
    await _withOutputLock(() async {
      await _output.stop();
      await _output.dispose();
    });
    if (_ownsDio) {
      _dio.close(force: true);
    }
  }

  Future<void> _withOutputLock(Future<void> Function() operation) {
    final result = Completer<void>();
    _outputTail = _outputTail.then((_) async {
      try {
        await operation();
        result.complete();
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }
}

final class _GuestAudioKey {
  const _GuestAudioKey(this.conversationId, this.utteranceId);

  final String conversationId;
  final String utteranceId;

  @override
  bool operator ==(Object other) =>
      other is _GuestAudioKey &&
      other.conversationId == conversationId &&
      other.utteranceId == utteranceId;

  @override
  int get hashCode => Object.hash(conversationId, utteranceId);
}

final class _GuestAudioCapability {
  const _GuestAudioCapability(this.capability, this.expiresAt);

  final String capability;
  final DateTime expiresAt;
}

final RegExp _safeGuestAudioId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{5,127}$');
