import 'package:audioplayers/audioplayers.dart';

abstract class PracticeAudioController {
  Stream<void> get completionStream;

  Future<void> playAsset(String assetPath);

  Future<void> stop();

  Future<void> dispose();
}

class AudioplayersPracticeAudioController implements PracticeAudioController {
  AudioplayersPracticeAudioController({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<void> get completionStream => _player.onPlayerComplete;

  @override
  Future<void> playAsset(String assetPath) {
    return _player.play(AssetSource(assetPath));
  }

  @override
  Future<void> stop() {
    return _player.stop();
  }

  @override
  Future<void> dispose() {
    return _player.dispose();
  }
}
