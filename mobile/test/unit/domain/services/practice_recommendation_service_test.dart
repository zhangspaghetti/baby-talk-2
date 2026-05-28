import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/practice/domain/services/practice_recommendation_service.dart';

void main() {
  group('PracticeRecommendationService', () {
    const service = PracticeRecommendationService();

    // -------------------------------------------------------------------------
    // Time-based scene recommendation
    // -------------------------------------------------------------------------

    group('recommendScene', () {
      test('morning recommends feeding', () {
        final result = service.recommendScene(const TimeContext(hour: 8));

        expect(result.sceneTag, 'feeding');
        expect(result.sceneTitle, '喂养时光');
        expect(result.confidence, greaterThan(0.7));
      });

      test('late morning recommends feeding', () {
        final result = service.recommendScene(const TimeContext(hour: 10));

        expect(result.sceneTag, 'feeding');
      });

      test('noon recommends play', () {
        final result = service.recommendScene(const TimeContext(hour: 12));

        expect(result.sceneTag, 'play');
        expect(result.sceneTitle, '游戏互动');
      });

      test('afternoon recommends activity', () {
        final result = service.recommendScene(const TimeContext(hour: 15));

        expect(result.sceneTag, 'activity');
        expect(result.sceneTitle, '探索活动');
      });

      test('evening recommends bath', () {
        final result = service.recommendScene(const TimeContext(hour: 18));

        expect(result.sceneTag, 'bath');
        expect(result.sceneTitle, '洗澡时光');
      });

      test('night recommends bedtime', () {
        final result = service.recommendScene(const TimeContext(hour: 22));

        expect(result.sceneTag, 'bedtime');
        expect(result.sceneTitle, '睡前时光');
      });

      test('very early morning recommends bedtime', () {
        final result = service.recommendScene(const TimeContext(hour: 3));

        expect(result.sceneTag, 'bedtime');
      });

      test('every hour has a recommendation', () {
        for (var hour = 0; hour < 24; hour++) {
          final result = service.recommendScene(TimeContext(hour: hour));
          expect(result.sceneTag, isNotEmpty);
          expect(result.sceneTitle, isNotEmpty);
          expect(result.reason, isNotEmpty);
          expect(result.confidence, greaterThan(0.0));
        }
      });
    });

    // -------------------------------------------------------------------------
    // Phrase deduplication
    // -------------------------------------------------------------------------

    group('deduplicatePhrases', () {
      test('empty list returns empty', () {
        final result = service.deduplicatePhrases([]);

        expect(result.deduplicatedPhrases, isEmpty);
        expect(result.duplicateCount, 0);
        expect(result.originalCount, 0);
      });

      test('no duplicates returns all phrases', () {
        const phrases = [
          PhraseReference(
            phraseId: 'p1',
            english: 'Hello',
            sceneTag: 'feeding',
            difficulty: '1',
          ),
          PhraseReference(
            phraseId: 'p2',
            english: 'Goodbye',
            sceneTag: 'play',
            difficulty: '2',
          ),
        ];

        final result = service.deduplicatePhrases(phrases);

        expect(result.deduplicatedPhrases, hasLength(2));
        expect(result.duplicateCount, 0);
        expect(result.originalCount, 2);
      });

      test('removes duplicate phraseIds, keeps first occurrence', () {
        const phrases = [
          PhraseReference(
            phraseId: 'p1',
            english: 'Hello',
            sceneTag: 'feeding',
            difficulty: '1',
          ),
          PhraseReference(
            phraseId: 'p2',
            english: 'Goodbye',
            sceneTag: 'play',
            difficulty: '2',
          ),
          PhraseReference(
            phraseId: 'p1', // duplicate
            english: 'Hello again',
            sceneTag: 'feeding',
            difficulty: '1',
          ),
        ];

        final result = service.deduplicatePhrases(phrases);

        expect(result.deduplicatedPhrases, hasLength(2));
        expect(result.deduplicatedPhrases[0].phraseId, 'p1');
        expect(result.deduplicatedPhrases[0].english, 'Hello');
        expect(result.deduplicatedPhrases[1].phraseId, 'p2');
        expect(result.duplicateCount, 1);
        expect(result.originalCount, 3);
      });

      test('all same phraseId returns single phrase', () {
        const phrases = [
          PhraseReference(
            phraseId: 'p1',
            english: 'A',
            sceneTag: 's',
            difficulty: '1',
          ),
          PhraseReference(
            phraseId: 'p1',
            english: 'B',
            sceneTag: 's',
            difficulty: '1',
          ),
          PhraseReference(
            phraseId: 'p1',
            english: 'C',
            sceneTag: 's',
            difficulty: '1',
          ),
        ];

        final result = service.deduplicatePhrases(phrases);

        expect(result.deduplicatedPhrases, hasLength(1));
        expect(result.duplicateCount, 2);
      });
    });

    // -------------------------------------------------------------------------
    // Difficulty matching
    // -------------------------------------------------------------------------

    group('buildDifficultyProfile', () {
      test('0-6 months targets difficulty 1', () {
        final profile = service.buildDifficultyProfile(3);

        expect(profile.targetDifficulty, 1);
        expect(profile.minDifficulty, 1);
        expect(profile.maxDifficulty, 2);
      });

      test('7-12 months targets difficulty 2', () {
        final profile = service.buildDifficultyProfile(9);

        expect(profile.targetDifficulty, 2);
        expect(profile.minDifficulty, 1);
        expect(profile.maxDifficulty, 3);
      });

      test('13-18 months targets difficulty 3', () {
        final profile = service.buildDifficultyProfile(15);

        expect(profile.targetDifficulty, 3);
        expect(profile.minDifficulty, 1);
        expect(profile.maxDifficulty, 4);
      });

      test('19-24 months targets difficulty 4', () {
        final profile = service.buildDifficultyProfile(22);

        expect(profile.targetDifficulty, 4);
        expect(profile.minDifficulty, 2);
        expect(profile.maxDifficulty, 5);
      });

      test('25+ months targets difficulty 5', () {
        final profile = service.buildDifficultyProfile(30);

        expect(profile.targetDifficulty, 5);
        expect(profile.minDifficulty, 3);
        expect(profile.maxDifficulty, 5);
      });
    });

    group('matchDifficulty', () {
      test('matching difficulty returns appropriate', () {
        const phrase = PhraseReference(
          phraseId: 'p1',
          english: 'Hello',
          sceneTag: 'feeding',
          difficulty: '2',
        );
        const profile = BabyDifficultyProfile(
          babyAgeMonths: 9,
          minDifficulty: 1,
          maxDifficulty: 3,
          targetDifficulty: 2,
        );

        final result = service.matchDifficulty(
          phrase: phrase,
          profile: profile,
        );

        expect(result.isAppropriate, isTrue);
        expect(result.difficultyDelta, 0);
        expect(result.reason, '难度正好合适！');
      });

      test('too easy phrase is flagged', () {
        const phrase = PhraseReference(
          phraseId: 'p1',
          english: 'Hi',
          sceneTag: 'feeding',
          difficulty: '1',
        );
        const profile = BabyDifficultyProfile(
          babyAgeMonths: 20,
          minDifficulty: 2,
          maxDifficulty: 5,
          targetDifficulty: 4,
        );

        final result = service.matchDifficulty(
          phrase: phrase,
          profile: profile,
        );

        expect(result.isAppropriate, isFalse);
        expect(result.reason, contains('太简单'));
      });

      test('too hard phrase is flagged', () {
        const phrase = PhraseReference(
          phraseId: 'p1',
          english: 'Complex sentence',
          sceneTag: 'feeding',
          difficulty: '5',
        );
        const profile = BabyDifficultyProfile(
          babyAgeMonths: 3,
          minDifficulty: 1,
          maxDifficulty: 2,
          targetDifficulty: 1,
        );

        final result = service.matchDifficulty(
          phrase: phrase,
          profile: profile,
        );

        expect(result.isAppropriate, isFalse);
        expect(result.reason, contains('有点难'));
      });

      test('string difficulty labels are parsed', () {
        const phrase = PhraseReference(
          phraseId: 'p1',
          english: 'Hello',
          sceneTag: 'feeding',
          difficulty: 'easy',
        );
        const profile = BabyDifficultyProfile(
          babyAgeMonths: 3,
          minDifficulty: 1,
          maxDifficulty: 2,
          targetDifficulty: 1,
        );

        final result = service.matchDifficulty(
          phrase: phrase,
          profile: profile,
        );

        expect(result.isAppropriate, isTrue);
      });
    });

    group('filterByDifficulty', () {
      test('filters phrases outside difficulty range', () {
        const phrases = [
          PhraseReference(
            phraseId: 'p1',
            english: 'Easy',
            sceneTag: 's',
            difficulty: '1',
          ),
          PhraseReference(
            phraseId: 'p2',
            english: 'Medium',
            sceneTag: 's',
            difficulty: '3',
          ),
          PhraseReference(
            phraseId: 'p3',
            english: 'Hard',
            sceneTag: 's',
            difficulty: '5',
          ),
        ];
        const profile = BabyDifficultyProfile(
          babyAgeMonths: 9,
          minDifficulty: 1,
          maxDifficulty: 3,
          targetDifficulty: 2,
        );

        final result = service.filterByDifficulty(
          phrases: phrases,
          profile: profile,
        );

        expect(result, hasLength(2));
        expect(result[0].phraseId, 'p1');
        expect(result[1].phraseId, 'p2');
      });
    });

    // -------------------------------------------------------------------------
    // Practice session scoring
    // -------------------------------------------------------------------------

    group('scoreSession', () {
      test('empty session scores 0', () {
        const input = PracticeSessionInput(
          phrasesAttempted: 0,
          phrasesCompleted: 0,
          imitationCount: 0,
          needsBreakCount: 0,
          currentStreakDays: 0,
        );

        final result = service.scoreSession(input);

        expect(result.totalScore, 0);
        expect(result.feedback, isNotEmpty);
      });

      test('full completion gives base + completion bonus', () {
        const input = PracticeSessionInput(
          phrasesAttempted: 5,
          phrasesCompleted: 5,
          imitationCount: 0,
          needsBreakCount: 0,
          currentStreakDays: 0,
        );

        final result = service.scoreSession(input);

        // 50 (base) + 0 (imitation) + 20 (completion) + 0 (streak) = 70.
        expect(result.totalScore, 70);
        expect(result.completionBonus, 20);
        expect(result.imitationBonus, 0);
        expect(result.streakBonus, 0);
      });

      test('imitations add bonus', () {
        const input = PracticeSessionInput(
          phrasesAttempted: 3,
          phrasesCompleted: 3,
          imitationCount: 2,
          needsBreakCount: 0,
          currentStreakDays: 0,
        );

        final result = service.scoreSession(input);

        // 30 (base) + 30 (imitation, capped) + 20 (completion) + 0 = 80.
        expect(result.totalScore, 80);
        expect(result.imitationBonus, 30);
      });

      test('streak adds bonus', () {
        const input = PracticeSessionInput(
          phrasesAttempted: 2,
          phrasesCompleted: 2,
          imitationCount: 0,
          needsBreakCount: 0,
          currentStreakDays: 5,
        );

        final result = service.scoreSession(input);

        // 20 (base) + 0 + 20 (completion) + 10 (streak, capped) = 50.
        expect(result.totalScore, 50);
        expect(result.streakBonus, 10);
      });

      test('total score is capped at 100', () {
        const input = PracticeSessionInput(
          phrasesAttempted: 10,
          phrasesCompleted: 10,
          imitationCount: 10,
          needsBreakCount: 0,
          currentStreakDays: 10,
        );

        final result = service.scoreSession(input);

        expect(result.totalScore, 100);
      });

      test('needsBreak is reflected in feedback', () {
        const input = PracticeSessionInput(
          phrasesAttempted: 1,
          phrasesCompleted: 1,
          imitationCount: 0,
          needsBreakCount: 3,
          currentStreakDays: 0,
        );

        final result = service.scoreSession(input);

        expect(result.feedback, contains('需要休息'));
      });

      test('imitation count in feedback', () {
        const input = PracticeSessionInput(
          phrasesAttempted: 3,
          phrasesCompleted: 3,
          imitationCount: 2,
          needsBreakCount: 0,
          currentStreakDays: 0,
        );

        final result = service.scoreSession(input);

        expect(result.feedback, contains('模仿了 2 次'));
      });
    });
  });
}
