import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/care_path/data/audio/generated_audio_repository.dart';
import 'package:mobile/features/practice/presentation/practice_audio_controller.dart';

abstract interface class CareAudioPlaybackController {
  Stream<CareAudioPlaybackCompletion> get completionStream;

  CareAudioPlaybackCapabilities get capabilities;

  Future<void> play(CareAudioPlaybackRequest request);

  Future<void> stop();

  Future<void> pause();

  Future<void> resume();

  Future<void> setPlaybackRate(double rate);

  Future<void> dispose();
}

class CareAudioPlaybackRequest {
  const CareAudioPlaybackRequest({
    required this.source,
    required this.sessionId,
    this.playbackRate = 1.0,
  });

  final CareAudioSource source;
  final int sessionId;
  final double playbackRate;
}

class CareAudioPlaybackCapabilities {
  const CareAudioPlaybackCapabilities({
    required this.canAutoPlay,
    required this.canPauseAndResume,
    required this.canChangePlaybackRate,
  });

  static const supported = CareAudioPlaybackCapabilities(
    canAutoPlay: true,
    canPauseAndResume: true,
    canChangePlaybackRate: true,
  );

  static const legacyAssetOnly = CareAudioPlaybackCapabilities(
    canAutoPlay: false,
    canPauseAndResume: false,
    canChangePlaybackRate: false,
  );

  final bool canAutoPlay;
  final bool canPauseAndResume;
  final bool canChangePlaybackRate;
}

class CareTurnAudioPlaybackPolicy {
  const CareTurnAudioPlaybackPolicy({
    required this.autoPlayEnabled,
    required this.playbackRate,
  });

  static const disabled = CareTurnAudioPlaybackPolicy(
    autoPlayEnabled: false,
    playbackRate: 1.0,
  );

  final bool autoPlayEnabled;
  final double playbackRate;
}

class CareAudioPlaybackCompletion {
  const CareAudioPlaybackCompletion({required this.sessionId});

  final int sessionId;
}

class SourceNeutralCareAudioPlaybackController
    implements CareAudioPlaybackController {
  SourceNeutralCareAudioPlaybackController({
    required GeneratedAudioRepository generatedAudioRepository,
    CareAudioOutput? output,
  }) : _generatedAudioRepository = generatedAudioRepository,
       _output = output ?? AudioplayersCareAudioOutput();

  final GeneratedAudioRepository _generatedAudioRepository;
  final CareAudioOutput _output;
  int _intent = 0;

  @override
  CareAudioPlaybackCapabilities get capabilities =>
      CareAudioPlaybackCapabilities.supported;

  @override
  Stream<CareAudioPlaybackCompletion> get completionStream =>
      _output.completionStream;

  @override
  Future<void> play(CareAudioPlaybackRequest request) async {
    final intent = ++_intent;
    _validatePlaybackRate(request.playbackRate);
    switch (request.source) {
      case CareAssetAudioSource(:final assetPath):
        await _output.playAsset(
          _normalizedAssetPath(assetPath),
          sessionId: request.sessionId,
          playbackRate: request.playbackRate,
        );
      case final generatedSource as GeneratedCareAudioSource:
        final payload = await _generatedAudioRepository.load(generatedSource);
        if (intent != _intent) {
          return;
        }
        await _output.playBytes(
          payload.bytes,
          payload.mimeType,
          sessionId: request.sessionId,
          playbackRate: request.playbackRate,
        );
    }
  }

  @override
  Future<void> stop() async {
    _intent += 1;
    await _output.stop();
  }

  @override
  Future<void> pause() => _output.pause();

  @override
  Future<void> resume() => _output.resume();

  @override
  Future<void> setPlaybackRate(double rate) {
    _validatePlaybackRate(rate);
    return _output.setPlaybackRate(rate);
  }

  @override
  Future<void> dispose() async {
    _intent += 1;
    await _output.dispose();
  }

  String _normalizedAssetPath(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(path, 'path', '音频资源缺失。');
    }
    return normalized.startsWith('assets/')
        ? normalized.substring(7)
        : normalized;
  }

  void _validatePlaybackRate(double rate) {
    if (rate < 0.5 || rate > 2.0) {
      throw ArgumentError.value(rate, 'rate', '播放速度必须在 0.5 到 2.0 倍之间。');
    }
  }
}

abstract interface class CareAudioOutput {
  Stream<CareAudioPlaybackCompletion> get completionStream;

  Future<void> playAsset(
    String assetPath, {
    required int sessionId,
    required double playbackRate,
  });

  Future<void> playBytes(
    List<int> bytes,
    String mimeType, {
    required int sessionId,
    required double playbackRate,
  });

  Future<void> stop();

  Future<void> pause();

  Future<void> resume();

  Future<void> setPlaybackRate(double rate);

  Future<void> dispose();
}

class AudioplayersCareAudioOutput implements CareAudioOutput {
  AudioplayersCareAudioOutput({AudioPlayer? player}) : _initialPlayer = player;

  AudioPlayer? _initialPlayer;
  AudioPlayer? _activePlayer;
  StreamSubscription<void>? _completionSubscription;
  double _playbackRate = 1.0;
  bool _pauseRequested = false;
  Future<void>? _pauseOperation;
  final StreamController<CareAudioPlaybackCompletion> _completions =
      StreamController<CareAudioPlaybackCompletion>.broadcast();

  @override
  Stream<CareAudioPlaybackCompletion> get completionStream =>
      _completions.stream;

  @override
  Future<void> playAsset(
    String assetPath, {
    required int sessionId,
    required double playbackRate,
  }) {
    return _startSession(
      sessionId,
      playbackRate: playbackRate,
      start: (player) => player.play(AssetSource(assetPath)),
    );
  }

  @override
  Future<void> playBytes(
    List<int> bytes,
    String mimeType, {
    required int sessionId,
    required double playbackRate,
  }) {
    return _startSession(
      sessionId,
      playbackRate: playbackRate,
      start: (player) => player.play(
        BytesSource(Uint8List.fromList(bytes), mimeType: mimeType),
      ),
    );
  }

  @override
  Future<void> stop() async {
    _pauseRequested = false;
    await _NativeAudioPlaybackSession.update(
      state: 'stopped',
      playbackRate: _playbackRate,
    );
    await _pauseOperation;
    await _disposeActivePlayer();
  }

  @override
  Future<void> pause() async {
    // `playBytes` may still be loading when the Flutter control becomes
    // visible. Remember the intent so `_startSession` pauses the player after
    // its asynchronous `play` call has installed the native source.
    _pauseRequested = true;
    await _NativeAudioPlaybackSession.update(
      state: 'paused',
      playbackRate: _playbackRate,
    );
    final player = _activePlayer;
    final operation = player?.pause();
    _pauseOperation = operation;
    try {
      await operation;
    } finally {
      if (identical(_pauseOperation, operation)) {
        _pauseOperation = null;
      }
    }
  }

  @override
  Future<void> resume() async {
    await _pauseOperation;
    _pauseRequested = false;
    await _activePlayer?.resume();
    await _NativeAudioPlaybackSession.update(
      state: 'playing',
      playbackRate: _playbackRate,
    );
  }

  @override
  Future<void> setPlaybackRate(double rate) async {
    if (rate < 0.5 || rate > 2.0) {
      throw ArgumentError.value(rate, 'rate', '播放速度必须在 0.5 到 2.0 倍之间。');
    }
    _playbackRate = rate;
    await _activePlayer?.setPlaybackRate(rate);
    if (_activePlayer != null) {
      await _NativeAudioPlaybackSession.update(
        state: _pauseRequested ? 'paused' : 'playing',
        playbackRate: rate,
      );
    }
  }

  @override
  Future<void> dispose() async {
    _pauseRequested = false;
    await _NativeAudioPlaybackSession.update(
      state: 'stopped',
      playbackRate: _playbackRate,
    );
    await _pauseOperation;
    await _disposeActivePlayer();
    final initial = _initialPlayer;
    _initialPlayer = null;
    if (initial != null) {
      await initial.dispose();
    }
    await _completions.close();
  }

  Future<void> _startSession(
    int sessionId, {
    required double playbackRate,
    required Future<void> Function(AudioPlayer player) start,
  }) async {
    await _disposeActivePlayer();
    _playbackRate = playbackRate;
    final player = _initialPlayer ?? AudioPlayer();
    _initialPlayer = null;
    _activePlayer = player;
    _completionSubscription = player.onPlayerComplete.listen((_) {
      if (identical(_activePlayer, player)) {
        unawaited(
          _NativeAudioPlaybackSession.update(
            state: 'completed',
            playbackRate: _playbackRate,
          ),
        );
        _completions.add(CareAudioPlaybackCompletion(sessionId: sessionId));
      }
    });
    try {
      await start(player);
      // audioplayers applies playback rate after a source starts. Calling it
      // before play only updates the cached value on some platforms.
      await player.setPlaybackRate(playbackRate);
      if (_pauseRequested) {
        await player.pause();
        await _NativeAudioPlaybackSession.update(
          state: 'paused',
          playbackRate: playbackRate,
        );
      } else {
        await _NativeAudioPlaybackSession.update(
          state: 'playing',
          playbackRate: playbackRate,
        );
      }
    } catch (_) {
      if (identical(_activePlayer, player)) {
        await _disposeActivePlayer();
      }
      rethrow;
    }
  }

  Future<void> _disposeActivePlayer() async {
    final player = _activePlayer;
    _activePlayer = null;
    final subscription = _completionSubscription;
    _completionSubscription = null;
    await subscription?.cancel();
    if (player != null) {
      await player.stop();
      await player.dispose();
    }
  }
}

/// Keeps Android's MediaSession state aligned with audioplayers output.
///
/// The bridge is best-effort: desktop, web, and widget tests do not register
/// the Android channel, but audio playback remains fully functional there.
class _NativeAudioPlaybackSession {
  const _NativeAudioPlaybackSession._();

  static const _channel = MethodChannel('com.babytalk.mobile/audio-session');

  static Future<void> update({
    required String state,
    required double playbackRate,
  }) async {
    try {
      await _channel.invokeMethod<void>('update', {
        'state': state,
        'playbackRate': playbackRate,
      });
    } on MissingPluginException {
      // Native session is Android-only.
    } on PlatformException {
      // A missing or unavailable system session must not break playback.
    }
  }
}

/// Compatibility adapter for existing test and legacy factories. It never
/// converts generated bytes into files and deliberately rejects them.
class LegacyPracticeCareAudioPlaybackController
    implements CareAudioPlaybackController {
  LegacyPracticeCareAudioPlaybackController(this._delegate) {
    _delegateCompletionSubscription = _delegate.completionStream.listen((_) {
      final sessionId = _activeSessionId;
      if (sessionId != null) {
        _completions.add(CareAudioPlaybackCompletion(sessionId: sessionId));
      }
    });
  }

  final PracticeAudioController _delegate;
  final StreamController<CareAudioPlaybackCompletion> _completions =
      StreamController<CareAudioPlaybackCompletion>.broadcast();
  late final StreamSubscription<void> _delegateCompletionSubscription;
  int? _activeSessionId;

  @override
  CareAudioPlaybackCapabilities get capabilities =>
      CareAudioPlaybackCapabilities.legacyAssetOnly;

  @override
  Stream<CareAudioPlaybackCompletion> get completionStream =>
      _completions.stream;

  @override
  Future<void> play(CareAudioPlaybackRequest request) async {
    if (request.source case CareAssetAudioSource(:final assetPath)) {
      _activeSessionId = request.sessionId;
      final normalized = assetPath.startsWith('assets/')
          ? assetPath.substring(7)
          : assetPath;
      try {
        await _delegate.playAsset(normalized);
      } catch (_) {
        if (_activeSessionId == request.sessionId) {
          _activeSessionId = null;
        }
        rethrow;
      }
      return;
    }
    throw UnsupportedError('生成音频控制器不可用。');
  }

  @override
  Future<void> stop() async {
    _activeSessionId = null;
    await _delegate.stop();
  }

  @override
  Future<void> pause() => _delegate.stop();

  @override
  Future<void> resume() => Future.value();

  @override
  Future<void> setPlaybackRate(double rate) => Future.value();

  @override
  Future<void> dispose() async {
    _activeSessionId = null;
    await _delegateCompletionSubscription.cancel();
    await _delegate.dispose();
    await _completions.close();
  }
}
