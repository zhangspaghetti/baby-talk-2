import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/domain/models/baby_reaction.dart';
import 'package:mobile/features/onboarding/domain/models/practice_record.dart';
import 'package:mobile/features/onboarding/domain/models/practice_scene.dart';

void main() {
  group('PracticeRecord', () {
    test('creates record with required fields', () {
      final record = PracticeRecord(
        phraseId: 'p1',
        english: 'Are you hungry?',
        chinese: '你饿了吗？',
        scene: PracticeScene.feeding,
        practicedAt: DateTime(2026, 6, 1, 8, 0),
      );
      expect(record.phraseId, 'p1');
      expect(record.english, 'Are you hungry?');
      expect(record.reaction, isNull);
    });

    test('creates record with reaction', () {
      final record = PracticeRecord(
        phraseId: 'p1',
        english: 'Are you hungry?',
        chinese: '你饿了吗？',
        scene: PracticeScene.feeding,
        reaction: BabyReaction.responded,
        practicedAt: DateTime(2026, 6, 1, 8, 0),
      );
      expect(record.reaction, BabyReaction.responded);
    });

    test('copyWithReaction returns new record with reaction set', () {
      final record = PracticeRecord(
        phraseId: 'p1',
        english: 'Are you hungry?',
        chinese: '你饿了吗？',
        scene: PracticeScene.feeding,
        practicedAt: DateTime(2026, 6, 1, 8, 0),
      );
      final withReaction = record.copyWithReaction(BabyReaction.calmed);
      expect(withReaction.reaction, BabyReaction.calmed);
      expect(withReaction.phraseId, 'p1');
      expect(record.reaction, isNull);
    });
  });
}
