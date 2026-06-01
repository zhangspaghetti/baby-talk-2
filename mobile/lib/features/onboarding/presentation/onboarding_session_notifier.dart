import 'package:flutter/foundation.dart';
import 'package:mobile/features/onboarding/data/services/scene_phrase_service.dart';
import 'package:mobile/features/onboarding/domain/models/baby_reaction.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_session.dart';
import 'package:mobile/features/onboarding/domain/models/practice_record.dart';
import 'package:mobile/features/onboarding/domain/models/practice_scene.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';

class OnboardingSessionNotifier extends ChangeNotifier {
  OnboardingSessionNotifier({required ScenePhraseService phraseService})
      : _phraseService = phraseService;

  final ScenePhraseService _phraseService;
  final OnboardingSession _session = OnboardingSession();

  ScenePhrase? _currentPhrase;
  bool _showReactionPicker = false;
  final Set<String> _usedPhraseIds = {};

  OnboardingSession get session => _session;
  ScenePhrase? get currentPhrase => _currentPhrase;
  bool get showReactionPicker => _showReactionPicker;

  bool get phrasePoolExhausted {
    final scene = _session.selectedScene;
    if (scene == null) return false;
    return _phraseService.getRandomPhrase(scene, _usedPhraseIds) == null;
  }

  void setChildName(String name) {
    _session.childName = name;
    notifyListeners();
  }

  void selectScene(PracticeScene scene) {
    _session.selectedScene = scene;
    _usedPhraseIds.clear();
    _loadNextPhrase();
    notifyListeners();
  }

  void selectAgeBucket(OnboardingAgeBucket bucket) {
    _session.ageBucket = bucket;
    notifyListeners();
  }

  void recordSaid() {
    final phrase = _currentPhrase;
    if (phrase == null) return;

    _session.addRecord(PracticeRecord(
      phraseId: phrase.phraseId,
      english: phrase.english,
      chinese: phrase.chinese,
      scene: phrase.scene,
      practicedAt: DateTime.now(),
    ));
    _usedPhraseIds.add(phrase.phraseId);
    _showReactionPicker = true;
    notifyListeners();
  }

  void selectReaction(BabyReaction reaction) {
    final lastIndex = _session.records.length - 1;
    if (lastIndex >= 0) {
      _session.updateReaction(lastIndex, reaction);
    }
    _showReactionPicker = false;
    if (!phrasePoolExhausted) {
      _loadNextPhrase(); // auto-advance only when there are more phrases
    }
    notifyListeners();
  }

  void skipReaction() {
    _showReactionPicker = false;
    if (!phrasePoolExhausted) {
      _loadNextPhrase(); // auto-advance only when there are more phrases
    }
    notifyListeners();
  }

  void nextPhrase() {
    _showReactionPicker = false;
    _loadNextPhrase();
    notifyListeners();
  }

  void swapPhrase() {
    _loadNextPhrase();
    notifyListeners();
  }

  void _loadNextPhrase() {
    final scene = _session.selectedScene;
    if (scene == null) {
      _currentPhrase = null;
      return;
    }
    _currentPhrase = _phraseService.getRandomPhrase(scene, _usedPhraseIds);
  }
}
