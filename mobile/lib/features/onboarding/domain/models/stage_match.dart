enum OnboardingAgeBucket {
  zeroToSix,
  sixToTwelve,
  twelveToEighteen,
  eighteenToTwentyFour,
  twentyFourToThirtySix,
}

extension OnboardingAgeBucketWire on OnboardingAgeBucket {
  String get wireValue {
    switch (this) {
      case OnboardingAgeBucket.zeroToSix:
        return '0-6';
      case OnboardingAgeBucket.sixToTwelve:
        return '6-12';
      case OnboardingAgeBucket.twelveToEighteen:
        return '12-18';
      case OnboardingAgeBucket.eighteenToTwentyFour:
        return '18-24';
      case OnboardingAgeBucket.twentyFourToThirtySix:
        return '24-36';
    }
  }

  String get label => '$wireValue 月';
}

OnboardingAgeBucket parseOnboardingAgeBucket(String value) {
  switch (value.trim()) {
    case '0-6':
      return OnboardingAgeBucket.zeroToSix;
    case '6-12':
      return OnboardingAgeBucket.sixToTwelve;
    case '12-18':
      return OnboardingAgeBucket.twelveToEighteen;
    case '18-24':
      return OnboardingAgeBucket.eighteenToTwentyFour;
    case '24-36':
      return OnboardingAgeBucket.twentyFourToThirtySix;
    default:
      throw FormatException('未知月龄档: $value');
  }
}

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
      ageBucket: OnboardingAgeBucket.sixToTwelve,
      stageId: 'sound_turn_taking',
      title: '声音轮流回应期',
      summary: '宝宝开始追声音和节奏，适合用短句做一来一回的小互动。',
      approxMonths: 9,
    ),
    StageMatch(
      ageBucket: OnboardingAgeBucket.twelveToEighteen,
      stageId: 'gesture_plus_words',
      title: '动作带词连接期',
      summary: '把动作、表情和关键词绑在一起，帮助宝宝把英文放进熟悉场景。',
      approxMonths: 15,
    ),
    StageMatch(
      ageBucket: OnboardingAgeBucket.eighteenToTwentyFour,
      stageId: 'mini_scene_imitation',
      title: '场景模仿萌芽期',
      summary: '宝宝开始模仿完整片段，适合练一两句可重复的小场景英文。',
      approxMonths: 21,
    ),
    StageMatch(
      ageBucket: OnboardingAgeBucket.twentyFourToThirtySix,
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
    for (final match in all) {
      if (match.stageId == normalized) {
        return match;
      }
    }
    return null;
  }
}
