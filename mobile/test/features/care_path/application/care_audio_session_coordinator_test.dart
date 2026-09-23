import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/care_path/presentation/care_audio_playback_controller.dart';
import 'package:mobile/features/care_path/application/care_audio_session_coordinator.dart';

void main() {
  test('older ownership token cannot unregister newer owner', () async {
    final coordinator = CareAudioSessionCoordinator();
    final first = _RecordingController();
    final second = _RecordingController();

    final firstToken = coordinator.register(first);
    coordinator.register(second);
    coordinator.unregister(firstToken);

    await coordinator.stopActive();

    expect(first.stopCalls, 1);
    expect(second.stopCalls, 1);
  });

  test('stopping during a pending load invalidates late playback', () async {
    final coordinator = CareAudioSessionCoordinator();
    final controller = _LatePlaybackController();
    coordinator.register(controller);

    final playing = controller.play(const _Request());
    await controller.loadStarted.future;
    await coordinator.stopActive();
    controller.loadFinished.complete();
    await playing;

    expect(controller.played, 0);
    expect(controller.completions, 0);
    expect(controller.stopCalls, 1);
  });

  test(
    'repeated stop is idempotent and unregistered owner is not retained',
    () async {
      final coordinator = CareAudioSessionCoordinator();
      final controller = _RecordingController();
      final token = coordinator.register(controller);

      coordinator.unregister(token);
      await coordinator.stopActive();
      await coordinator.stopActive();

      expect(controller.stopCalls, 0);
    },
  );
}

class _Request extends CareAudioPlaybackRequest {
  const _Request()
    : super(
        source: const CareAssetAudioSource(assetPath: 'assets/seed.mp3'),
        sessionId: 1,
      );
}

class _RecordingController implements CareAudioPlaybackController {
  final StreamController<CareAudioPlaybackCompletion> _completion =
      StreamController<CareAudioPlaybackCompletion>.broadcast();
  int stopCalls = 0;

  @override
  CareAudioPlaybackCapabilities get capabilities =>
      CareAudioPlaybackCapabilities.supported;

  @override
  Stream<CareAudioPlaybackCompletion> get completionStream =>
      _completion.stream;

  @override
  Future<void> play(CareAudioPlaybackRequest request) async {}

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> setPlaybackRate(double rate) async {}

  @override
  Future<void> dispose() async {
    await _completion.close();
  }
}

class _LatePlaybackController extends _RecordingController {
  final loadStarted = Completer<void>();
  final loadFinished = Completer<void>();
  int _generation = 0;
  int played = 0;
  int completions = 0;

  @override
  Future<void> play(CareAudioPlaybackRequest request) async {
    final generation = _generation;
    loadStarted.complete();
    await loadFinished.future;
    if (generation != _generation) {
      return;
    }
    played += 1;
    completions += 1;
  }

  @override
  Future<void> stop() async {
    await super.stop();
    _generation += 1;
  }
}
