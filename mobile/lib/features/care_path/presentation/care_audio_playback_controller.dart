import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/care_path/data/audio/generated_audio_repository.dart';
import 'package:mobile/features/practice/presentation/practice_audio_controller.dart';

abstract interface class CareAudioPlaybackController {
  Stream<CareAudioPlaybackCompletion> get completionStream;

  Future<void> play(CareAudioPlaybackRequest request);

  Future<void> stop();

  Future<void> dispose();
}

class CareAudioPlaybackRequest {
  const CareAudioPlaybackRequest({
    required this.source,
    required this.sessionId,
  });

  final CareAudioSource source;
  final int sessionId;
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
  Stream<CareAudioPlaybackCompletion> get completionStream =>
      _output.completionStream;

  @override
  Future<void> play(CareAudioPlaybackRequest request) async {
    final intent = ++_intent;
    switch (request.source) {
      case CareAssetAudioSource(:final assetPath):
        await _output.playAsset(
          _normalizedAssetPath(assetPath),
          sessionId: request.sessionId,
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
        );
    }
  }

  @override
  Future<void> stop() async {
    _intent += 1;
    await _output.stop();
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
}

abstract interface class CareAudioOutput {
  Stream<CareAudioPlaybackCompletion> get completionStream;

  Future<void> playAsset(String assetPath, {required int sessionId});

  Future<void> playBytes(
    List<int> bytes,
    String mimeType, {
    required int sessionId,
  });

  Future<void> stop();

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
  Future<void> playAsset(String assetPath, {required int sessionId}) {
    return _startSession(
      sessionId,
      (player) => player.play(AssetSource(assetPath)),
    );
  }

  @override
  Future<void> playBytes(
    List<int> bytes,
    String mimeType, {
    required int sessionId,
  }) {
    return _startSession(
      sessionId,
      (player) => player.play(
        BytesSource(Uint8List.fromList(bytes), mimeType: mimeType),
      ),
    );
  }

  @override
  Future<void> stop() => _disposeActivePlayer();

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
    int sessionId,
    Future<void> Function(AudioPlayer player) start,
  ) async {
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
  Future<void> dispose() async {
    _activeSessionId = null;
    await _delegateCompletionSubscription.cancel();
    await _delegate.dispose();
    await _completions.close();
  }
}
