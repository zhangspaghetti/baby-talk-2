import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile/features/care_path/presentation/care_audio_playback_controller.dart';
import 'package:mobile/features/custom_scene/application/custom_scene_submission_controller.dart';

/// App-scoped owner for the single active Care Turn audio session.
class CareAudioSessionCoordinator extends ChangeNotifier
    implements CustomSceneAudioStopper {
  CareAudioSessionCoordinator();

  _CareAudioOwnership? _current;
  int _generation = 0;

  int get generation => _generation;

  Object register(CareAudioPlaybackController controller) {
    final ownership = _CareAudioOwnership(
      token: _CareAudioOwnershipToken(),
      controller: controller,
      generation: ++_generation,
    );
    final previous = _current;
    _current = ownership;
    notifyListeners();
    if (previous != null) {
      unawaited(_stopBestEffort(previous.controller));
    }
    return ownership.token;
  }

  bool isCurrent(Object ownershipToken) {
    final current = _current;
    return current != null &&
        current.generation == _generation &&
        identical(current.token, ownershipToken);
  }

  void unregister(Object ownershipToken) {
    final current = _current;
    if (current == null || !identical(current.token, ownershipToken)) {
      return;
    }
    _current = null;
    _generation += 1;
    notifyListeners();
  }

  @override
  Future<void> stopActive() async {
    final current = _current;
    _current = null;
    _generation += 1;
    notifyListeners();
    if (current == null) {
      return;
    }
    await current.controller.stop();
  }

  Future<void> _stopBestEffort(CareAudioPlaybackController controller) async {
    try {
      await controller.stop();
    } on Object {
      // Replacement must not affect current ownership or safety publication.
    }
  }
}

class _CareAudioOwnership {
  const _CareAudioOwnership({
    required this.token,
    required this.controller,
    required this.generation,
  });

  final _CareAudioOwnershipToken token;
  final CareAudioPlaybackController controller;
  final int generation;
}

class _CareAudioOwnershipToken {
  const _CareAudioOwnershipToken();
}
