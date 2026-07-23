enum OnboardingAgeBucket { zeroToSix, sevenToTwelve, oneToTwo, twoToThree }

enum OnboardingSupportGoal { firstWords, moreNatural, dailyHabit }

extension OnboardingAgeBucketWire on OnboardingAgeBucket {
  String get wireValue => switch (this) {
    OnboardingAgeBucket.zeroToSix => '0-6',
    OnboardingAgeBucket.sevenToTwelve => '7-12',
    OnboardingAgeBucket.oneToTwo => '12-24',
    OnboardingAgeBucket.twoToThree => '24-36',
  };

  String get label => switch (this) {
    OnboardingAgeBucket.zeroToSix => '0–6 个月',
    OnboardingAgeBucket.sevenToTwelve => '7–12 个月',
    OnboardingAgeBucket.oneToTwo => '1–2 岁',
    OnboardingAgeBucket.twoToThree => '2–3 岁',
  };
}

OnboardingAgeBucket parseOnboardingAgeBucket(String value) =>
    switch (value.trim()) {
      '0-6' => OnboardingAgeBucket.zeroToSix,
      '7-12' || '6-12' => OnboardingAgeBucket.sevenToTwelve,
      '12-24' || '12-18' || '18-24' => OnboardingAgeBucket.oneToTwo,
      '24-36' => OnboardingAgeBucket.twoToThree,
      final unknown => throw FormatException('未知月龄档: $unknown'),
    };

extension OnboardingSupportGoalWire on OnboardingSupportGoal {
  String get wireValue => switch (this) {
    OnboardingSupportGoal.firstWords => 'first_words',
    OnboardingSupportGoal.moreNatural => 'more_natural',
    OnboardingSupportGoal.dailyHabit => 'daily_habit',
  };
}

OnboardingSupportGoal parseOnboardingSupportGoal(String value) => switch (value
    .trim()) {
  'first_words' => OnboardingSupportGoal.firstWords,
  'more_natural' => OnboardingSupportGoal.moreNatural,
  'daily_habit' => OnboardingSupportGoal.dailyHabit,
  final unknown => throw FormatException('未知 onboarding supportGoal: $unknown'),
};

class StageMatch {
  const StageMatch({
    required this.ageBucket,
    required this.stageId,
    required this.title,
    required this.summary,
    required this.approxMonths,
  });

  final OnboardingAgeBucket ageBucket;
  final String stageId;
  final String title;
  final String summary;
  final int approxMonths;
}

class StageMatchCatalog {
  static const List<StageMatch> all = [
    StageMatch(
      ageBucket: OnboardingAgeBucket.zeroToSix,
      stageId: 'warm_routines',
      title: '日常陪伴起步期',
      summary: '先把英语放进照护动作里，让宝宝把声音和安全感连在一起。',
      approxMonths: 3,
    ),
    StageMatch(
      ageBucket: OnboardingAgeBucket.sevenToTwelve,
      stageId: 'sound_turn_taking',
      title: '声音轮流回应期',
      summary: '宝宝开始追声音和节奏，适合用短句做一来一回的小互动。',
      approxMonths: 9,
    ),
    StageMatch(
      ageBucket: OnboardingAgeBucket.oneToTwo,
      stageId: 'gesture_plus_words',
      title: '动作带词连接期',
      summary: '把动作、表情和关键词绑在一起，帮助宝宝把英文放进熟悉场景。',
      approxMonths: 18,
    ),
    StageMatch(
      ageBucket: OnboardingAgeBucket.twoToThree,
      stageId: 'everyday_phrase_expansion',
      title: '日常短句扩展期',
      summary: '可以把同一场景里的句子慢慢串起来，形成家庭里的稳定英语节奏。',
      approxMonths: 30,
    ),
  ];

  static StageMatch forAgeBucket(OnboardingAgeBucket ageBucket) {
    for (final match in all) {
      if (match.ageBucket == ageBucket) {
        return match;
      }
    }
    throw FormatException('未找到月龄档对应阶段: ${ageBucket.wireValue}');
  }

  static StageMatch? maybeForStageId(String stageId) {
    final normalized = stageId.trim();
    if (normalized == 'mini_scene_imitation') {
      return forAgeBucket(OnboardingAgeBucket.oneToTwo);
    }
    for (final match in all) {
      if (match.stageId == normalized) {
        return match;
      }
    }
    return null;
  }
}
