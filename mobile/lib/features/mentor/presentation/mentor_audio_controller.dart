import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum MentorAudioFailureKind { unavailable, failed }

class MentorAudioException implements Exception {
  const MentorAudioException({required this.kind, required this.message});

  final MentorAudioFailureKind kind;
  final String message;

  bool get isUnavailable => kind == MentorAudioFailureKind.unavailable;

  @override
  String toString() {
    return 'MentorAudioException(kind: $kind, message: $message)';
  }
}

abstract class MentorAudioController {
  Future<bool> ensureAvailable();

  Future<void> speakText(String text);

  Future<void> stop();

  Future<void> dispose();
}

class FlutterTtsMentorAudioController implements MentorAudioController {
  FlutterTtsMentorAudioController({FlutterTts? flutterTts})
    : _flutterTts = flutterTts ?? FlutterTts();

  final FlutterTts _flutterTts;

  bool _availabilityChecked = false;
  bool _available = true;

  @override
  Future<bool> ensureAvailable() async {
    if (_availabilityChecked) {
      return _available;
    }
    try {
      await _flutterTts.awaitSpeakCompletion(true);
      await _flutterTts.setSpeechRate(0.44);
      final dynamic engines = await _flutterTts.getEngines;
      if (engines is List) {
        _available = engines.isNotEmpty;
      } else {
        _available = true;
      }
    } on MissingPluginException {
      _available = false;
    } catch (_) {
      _available = false;
    }
    _availabilityChecked = true;
    return _available;
  }

  @override
  Future<void> speakText(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      throw const MentorAudioException(
        kind: MentorAudioFailureKind.failed,
        message: '朗读文本为空。',
      );
    }
    if (!await ensureAvailable()) {
      throw const MentorAudioException(
        kind: MentorAudioFailureKind.unavailable,
        message: '当前设备不支持朗读。',
      );
    }
    try {
      await _flutterTts.stop();
      final dynamic result = await _flutterTts.speak(normalized);
      if (result is int && result != 1) {
        throw const MentorAudioException(
          kind: MentorAudioFailureKind.failed,
          message: '设备拒绝开始朗读。',
        );
      }
    } on MissingPluginException {
      _available = false;
      throw const MentorAudioException(
        kind: MentorAudioFailureKind.unavailable,
        message: '当前设备不支持朗读。',
      );
    } on MentorAudioException {
      rethrow;
    } catch (error) {
      throw MentorAudioException(
        kind: MentorAudioFailureKind.failed,
        message: '朗读失败：$error',
      );
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } on MissingPluginException {
      _available = false;
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
  }
}
