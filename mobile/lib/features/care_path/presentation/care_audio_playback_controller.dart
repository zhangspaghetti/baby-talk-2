import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
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
  Future<void> stop() => _disposeActivePlayer();

  @override
  Future<void> pause() => _activePlayer?.pause() ?? Future.value();

  @override
  Future<void> resume() => _activePlayer?.resume() ?? Future.value();

  @override
  Future<void> setPlaybackRate(double rate) async {
    if (rate < 0.5 || rate > 2.0) {
      throw ArgumentError.value(rate, 'rate', '播放速度必须在 0.5 到 2.0 倍之间。');
    }
    await _activePlayer?.setPlaybackRate(rate);
  }

  @override
  Future<void> dispose() async {
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
    final player = _initialPlayer ?? AudioPlayer();
    _initialPlayer = null;
    _activePlayer = player;
    _completionSubscription = player.onPlayerComplete.listen((_) {
      if (identical(_activePlayer, player)) {
        _completions.add(CareAudioPlaybackCompletion(sessionId: sessionId));
      }
    });
    try {
      await start(player);
      // audioplayers applies playback rate after a source starts. Calling it
      // before play only updates the cached value on some platforms.
      await player.setPlaybackRate(playbackRate);
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
