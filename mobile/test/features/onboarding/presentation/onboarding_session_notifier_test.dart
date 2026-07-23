import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/data/services/scene_phrase_service.dart';
import 'package:mobile/features/onboarding/domain/models/baby_reaction.dart';
import 'package:mobile/features/onboarding/domain/models/practice_scene.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_session_notifier.dart';

void main() {
  group('OnboardingSessionNotifier', () {
    late OnboardingSessionNotifier notifier;
    late ScenePhraseService phraseService;

    setUp(() {
      phraseService = ScenePhraseService();
      notifier = OnboardingSessionNotifier(phraseService: phraseService);
    });

    test('initial state has empty session', () {
      expect(notifier.session.childName, '');
      expect(notifier.session.selectedScene, isNull);
      expect(notifier.session.records, isEmpty);
    });

    test('setChildName updates session', () {
      notifier.setChildName('小宝');
      expect(notifier.session.childName, '小宝');
    });

    test('selectScene updates session and loads first phrase', () {
      notifier.selectScene(PracticeScene.feeding);
      expect(notifier.session.selectedScene, PracticeScene.feeding);
      expect(notifier.currentPhrase, isNotNull);
      expect(notifier.currentPhrase!.scene, PracticeScene.feeding);
    });

    test('recordSaid adds record and advances to reaction state', () {
      notifier.selectScene(PracticeScene.feeding);
      notifier.recordSaid();
      expect(notifier.session.practicedCount, 1);
      expect(notifier.showReactionPicker, true);
    });

    test('selectReaction updates last record', () {
      notifier.selectScene(PracticeScene.feeding);
      notifier.recordSaid();
      notifier.selectReaction(BabyReaction.responded);
      expect(notifier.session.records.last.reaction, BabyReaction.responded);
      expect(notifier.showReactionPicker, false);
    });

    test('nextPhrase loads a different phrase', () {
      notifier.selectScene(PracticeScene.feeding);
      notifier.recordSaid();
      notifier.selectReaction(BabyReaction.responded);
      notifier.nextPhrase();
      expect(notifier.currentPhrase, isNotNull);
      expect(notifier.showReactionPicker, false);
    });

    test('swapPhrase replaces current phrase with unused one', () {
      notifier.selectScene(PracticeScene.feeding);
      notifier.swapPhrase();
      expect(notifier.currentPhrase, isNotNull);
    });

    test('phrasePoolExhausted returns true when all phrases used', () {
      notifier.selectScene(PracticeScene.feeding);
      for (int i = 0; i < 4; i++) {
        notifier.recordSaid();
        notifier.selectReaction(BabyReaction.responded);
        if (i < 3) notifier.nextPhrase();
      }
      expect(notifier.phrasePoolExhausted, true);
    });

    test('selectAgeBucket updates session', () {
      notifier.selectAgeBucket(OnboardingAgeBucket.sevenToTwelve);
      expect(notifier.session.ageBucket, OnboardingAgeBucket.sevenToTwelve);
    });
  });
}
