/// Pure Dart Logic Layer service for practice session recommendations.
///
/// Stateless, no Flutter dependencies, no Repository dependencies.
/// All methods are pure functions operating on their input data.

library;

// ---------------------------------------------------------------------------
// Input / Output data classes
// ---------------------------------------------------------------------------

/// A lightweight phrase reference for recommendation input.
class PhraseReference {
  const PhraseReference({
    required this.phraseId,
    required this.english,
    required this.sceneTag,
    required this.difficulty,
  });

  final String phraseId;
  final String english;
  final String sceneTag;
  final String difficulty;
}

/// Context for time-based scene recommendation.
class TimeContext {
  const TimeContext({required this.hour, this.isWeekend = false});

  final int hour;
  final bool isWeekend;
}

/// A scene recommendation with its reason.
class SceneRecommendation {
  const SceneRecommendation({
    required this.sceneTag,
    required this.sceneTitle,
    required this.reason,
    required this.confidence,
  });

  final String sceneTag;
  final String sceneTitle;
  final String reason;
  final double confidence;
}

/// Result of phrase deduplication.
class DeduplicationResult {
  const DeduplicationResult({
    required this.deduplicatedPhrases,
    required this.duplicateCount,
    required this.originalCount,
  });

  final List<PhraseReference> deduplicatedPhrases;
  final int duplicateCount;
  final int originalCount;
}

/// Difficulty match result for a single phrase.
class DifficultyMatch {
  const DifficultyMatch({
    required this.phrase,
    required this.isAppropriate,
    required this.difficultyDelta,
    required this.reason,
  });

  final PhraseReference phrase;
  final bool isAppropriate;
  final int difficultyDelta;
  final String reason;
}

/// Difficulty profile for a baby based on age.
class BabyDifficultyProfile {
  const BabyDifficultyProfile({
    required this.babyAgeMonths,
    required this.minDifficulty,
    required this.maxDifficulty,
    required this.targetDifficulty,
  });

  final int babyAgeMonths;
  final int minDifficulty;
  final int maxDifficulty;
  final int targetDifficulty;
}

/// Score and feedback for a practice session.
class SessionScore {
  const SessionScore({
    required this.totalScore,
    required this.cooperationBonus,
    required this.completionBonus,
    required this.streakBonus,
    required this.feedback,
  });

  final int totalScore;
  final int cooperationBonus;
  final int completionBonus;
  final int streakBonus;
  final String feedback;
}

/// Practice session input for scoring.
class PracticeSessionInput {
  const PracticeSessionInput({
    required this.phrasesAttempted,
    required this.phrasesCompleted,
    required this.cooperatingCount,
    required this.resistingCount,
    required this.currentStreakDays,
  });

  final int phrasesAttempted;
  final int phrasesCompleted;
  final int cooperatingCount;
  final int resistingCount;
  final int currentStreakDays;
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class PracticeRecommendationService {
  const PracticeRecommendationService();

  /// Recommends a scene based on the time of day.
  ///
  /// Mapping:
  /// - 05:00-10:59 (morning):   feeding / daily care
  /// - 11:00-13:59 (midday):    play / food
  /// - 14:00-16:59 (afternoon):  play / activity
  /// - 17:00-19:59 (evening):    bath / bedtime prep
  /// - 20:00-04:59 (night):     bedtime
  SceneRecommendation recommendScene(TimeContext context) {
    final hour = context.hour;

    if (hour >= 5 && hour < 11) {
      return SceneRecommendation(
        sceneTag: 'feeding',
        sceneTitle: '喂养时光',
        reason: '早上是宝宝最专注的时段，适合在喂养时轻声说英文短句。',
        confidence: 0.9,
      );
    }

    if (hour >= 11 && hour < 14) {
      return SceneRecommendation(
        sceneTag: 'play',
        sceneTitle: '游戏互动',
        reason: '中午宝宝精力充沛，用游戏场景自然引入英文单词。',
        confidence: 0.85,
      );
    }

    if (hour >= 14 && hour < 17) {
      return SceneRecommendation(
        sceneTag: 'activity',
        sceneTitle: '探索活动',
        reason: '下午适合在活动场景中重复简短英文句子。',
        confidence: 0.8,
      );
    }

    if (hour >= 17 && hour < 20) {
      return SceneRecommendation(
        sceneTag: 'bath',
        sceneTitle: '洗澡时光',
        reason: '傍晚洗澡时水流声和温柔语气最搭英文短句。',
        confidence: 0.85,
      );
    }

    // Night: 20:00-04:59
    return SceneRecommendation(
      sceneTag: 'bedtime',
      sceneTitle: '睡前时光',
      reason: '睡前用最轻柔的声音说一两句英文，帮宝宝建立英语和安全感的联系。',
      confidence: 0.75,
    );
  }

  /// Removes duplicate phrases from the input list.
  ///
  /// Deduplication is based on [PhraseReference.phraseId]. The first occurrence
  /// of each phrase is kept; subsequent duplicates are removed.
  ///
  /// Returns [DeduplicationResult] with the deduplicated list and counts.
  DeduplicationResult deduplicatePhrases(List<PhraseReference> phrases) {
    final seen = <String>{};
    final deduplicated = <PhraseReference>[];

    for (final phrase in phrases) {
      if (seen.add(phrase.phraseId)) {
        deduplicated.add(phrase);
      }
    }

    return DeduplicationResult(
      deduplicatedPhrases: deduplicated,
      duplicateCount: phrases.length - deduplicated.length,
      originalCount: phrases.length,
    );
  }

  /// Builds a difficulty profile appropriate for the given baby age in months.
  ///
  /// Difficulty scale: 1 (easiest) to 5 (hardest).
  ///
  /// - 0-6 months:   target 1, range [1, 2]
  /// - 7-12 months:  target 2, range [1, 3]
  /// - 13-18 months: target 3, range [1, 4]
  /// - 19-24 months: target 4, range [2, 5]
  /// - 25+ months:   target 5, range [3, 5]
  BabyDifficultyProfile buildDifficultyProfile(int babyAgeMonths) {
    final clamped = babyAgeMonths.clamp(0, 60);

    if (clamped <= 6) {
      return const BabyDifficultyProfile(
        babyAgeMonths: 0,
        minDifficulty: 1,
        maxDifficulty: 2,
        targetDifficulty: 1,
      );
    }
    if (clamped <= 12) {
      return const BabyDifficultyProfile(
        babyAgeMonths: 7,
        minDifficulty: 1,
        maxDifficulty: 3,
        targetDifficulty: 2,
      );
    }
    if (clamped <= 18) {
      return const BabyDifficultyProfile(
        babyAgeMonths: 13,
        minDifficulty: 1,
        maxDifficulty: 4,
        targetDifficulty: 3,
      );
    }
    if (clamped <= 24) {
      return const BabyDifficultyProfile(
        babyAgeMonths: 19,
        minDifficulty: 2,
        maxDifficulty: 5,
        targetDifficulty: 4,
      );
    }
    return BabyDifficultyProfile(
      babyAgeMonths: clamped,
      minDifficulty: 3,
      maxDifficulty: 5,
      targetDifficulty: 5,
    );
  }

  /// Matches a phrase against the baby's difficulty profile.
  ///
  /// [phrase] contains the difficulty level as a string (1-5 or label).
  /// Returns a [DifficultyMatch] indicating whether the phrase is appropriate.
  DifficultyMatch matchDifficulty({
    required PhraseReference phrase,
    required BabyDifficultyProfile profile,
  }) {
    final phraseDifficulty = _parseDifficulty(phrase.difficulty);
    final delta = (phraseDifficulty - profile.targetDifficulty).abs();

    final isAppropriate =
        phraseDifficulty >= profile.minDifficulty &&
        phraseDifficulty <= profile.maxDifficulty;

    String reason;
    if (!isAppropriate) {
      if (phraseDifficulty < profile.minDifficulty) {
        reason = '这个短语对宝宝来说太简单了。';
      } else {
        reason = '这个短语对宝宝来说有点难，建议换一个更简单的。';
      }
    } else if (delta == 0) {
      reason = '难度正好合适！';
    } else if (phraseDifficulty < profile.targetDifficulty) {
      reason = '稍微简单一点，适合巩固练习。';
    } else {
      reason = '稍微有挑战，适合进阶练习。';
    }

    return DifficultyMatch(
      phrase: phrase,
      isAppropriate: isAppropriate,
      difficultyDelta: delta,
      reason: reason,
    );
  }

  /// Filters a list of phrases to only those appropriate for the baby's age.
  List<PhraseReference> filterByDifficulty({
    required List<PhraseReference> phrases,
    required BabyDifficultyProfile profile,
  }) {
    return phrases.where((phrase) {
      final difficulty = _parseDifficulty(phrase.difficulty);
      return difficulty >= profile.minDifficulty &&
          difficulty <= profile.maxDifficulty;
    }).toList();
  }

  /// Scores a practice session based on activity and reaction metrics.
  ///
  /// Scoring:
  /// - Base: 10 points per completed phrase (max 50)
  /// - Cooperation bonus: 15 points per cooperating reaction (max 30)
  /// - Completion bonus: 20 points if all attempted phrases completed
  /// - Streak bonus: 2 points per streak day (max 10)
  ///
  /// Total is clamped to 0-100.
  SessionScore scoreSession(PracticeSessionInput input) {
    final baseScore = (input.phrasesCompleted * 10).clamp(0, 50);
    final cooperationBonus = (input.cooperatingCount * 15).clamp(0, 30);

    final completionBonus =
        input.phrasesAttempted > 0 &&
            input.phrasesCompleted >= input.phrasesAttempted
        ? 20
        : 0;

    final streakBonus = (input.currentStreakDays * 2).clamp(0, 10);

    final total = baseScore + cooperationBonus + completionBonus + streakBonus;
    final totalScore = total.clamp(0, 100);

    final feedback = _buildScoreFeedback(
      totalScore: totalScore,
      cooperatingCount: input.cooperatingCount,
      resistingCount: input.resistingCount,
      completionBonus: completionBonus,
    );

    return SessionScore(
      totalScore: totalScore,
      cooperationBonus: cooperationBonus,
      completionBonus: completionBonus,
      streakBonus: streakBonus,
      feedback: feedback,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  int _parseDifficulty(String difficulty) {
    final parsed = int.tryParse(difficulty);
    if (parsed != null) return parsed.clamp(1, 5);
    // Fallback: map common string labels.
    switch (difficulty.toLowerCase()) {
      case 'easy':
      case 'simple':
        return 1;
      case 'medium':
      case 'moderate':
        return 3;
      case 'hard':
      case 'difficult':
        return 5;
      default:
        return 3;
    }
  }

  String _buildScoreFeedback({
    required int totalScore,
    required int cooperatingCount,
    required int resistingCount,
    required int completionBonus,
  }) {
    final parts = <String>[];

    if (totalScore >= 80) {
      parts.add('这次练习很棒！');
    } else if (totalScore >= 50) {
      parts.add('练习做得不错，继续保持。');
    } else if (totalScore >= 20) {
      parts.add('每一次开口都是进步。');
    } else {
      parts.add('宝宝今天可能不太在状态，下次再试试。');
    }

    if (cooperatingCount > 0) {
      parts.add('宝宝配合了 $cooperatingCount 次，特别棒！');
    }

    if (resistingCount > 0) {
      parts.add('宝宝不想继续时，及时停下来是对的。');
    }

    if (completionBonus > 0) {
      parts.add('完整练完了一组短语。');
    }

    return parts.join(' ');
  }
}
