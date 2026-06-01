import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/data/services/scene_phrase_service.dart';
import 'package:mobile/features/onboarding/domain/models/practice_scene.dart';

void main() {
  group('ScenePhraseService', () {
    late ScenePhraseService service;

    setUp(() {
      service = ScenePhraseService();
    });

    test('getPhrases returns phrases for each scene', () {
      for (final scene in PracticeScene.values) {
        final phrases = service.getPhrases(scene);
        expect(phrases.length, greaterThanOrEqualTo(3),
            reason: '${scene.label} should have at least 3 phrases');
        expect(phrases.length, lessThanOrEqualTo(5),
            reason: '${scene.label} should have at most 5 phrases');
      }
    });

    test('each phrase has non-empty english and chinese', () {
      for (final scene in PracticeScene.values) {
        for (final phrase in service.getPhrases(scene)) {
          expect(phrase.english.trim().isNotEmpty, true);
          expect(phrase.chinese.trim().isNotEmpty, true);
          expect(phrase.phraseId.trim().isNotEmpty, true);
        }
      }
    });

    test('getRandomPhrase returns a phrase not in usedPhraseIds', () {
      final allPhrases = service.getPhrases(PracticeScene.feeding);
      final usedIds = {allPhrases.first.phraseId};
      final result = service.getRandomPhrase(PracticeScene.feeding, usedIds);
      expect(result, isNotNull);
      expect(result!.phraseId, isNot(allPhrases.first.phraseId));
    });

    test('getRandomPhrase returns null when all phrases used', () {
      final allPhrases = service.getPhrases(PracticeScene.feeding);
      final usedIds = allPhrases.map((p) => p.phraseId).toSet();
      final result = service.getRandomPhrase(PracticeScene.feeding, usedIds);
      expect(result, isNull);
    });

    test('getRandomPhrase returns any phrase when usedPhraseIds is empty', () {
      final result =
          service.getRandomPhrase(PracticeScene.feeding, {});
      expect(result, isNotNull);
    });
  });
}
