import 'package:flutter/material.dart';

enum GrowthStage { seed, sprout, bud, bloom }

enum DiaryEntryType { autoNote, manualNote }

enum AppDifficulty {
  gentle('轻松', '先把敢开口这件事做顺'),
  balanced('标准', '兼顾陪伴感和进步感'),
  stretch('进阶', '今天多推一步，词句更完整');

  const AppDifficulty(this.label, this.description);

  final String label;
  final String description;
}

enum PhraseReaction {
  listened('安静听', '先听进去了'),
  babbled('跟着发声', '宝宝给了你一个回应'),
  skipped('没进入状态', '今天先别硬推');

  const PhraseReaction(this.label, this.detail);

  final String label;
  final String detail;
}

enum RoadmapStage {
  listening('阶段 1', '听感唤醒', 0, 5, '先让英语像家里的背景音出现'),
  dailyDialog('阶段 2', '日常对话', 6, 11, '把吃睡洗抱接到一句短语上'),
  actionPlay('阶段 3', '动作互动', 12, 17, '边做动作边说，宝宝更容易跟上'),
  storySpark('阶段 4', '绘本联想', 18, 23, '把画面、声音和指令串起来'),
  expressionLeap('阶段 5', '表达跃迁', 24, 36, '从单句走向更完整的情境表达');

  const RoadmapStage(
    this.badge,
    this.title,
    this.minMonths,
    this.maxMonths,
    this.coachCopy,
  );

  final String badge;
  final String title;
  final int minMonths;
  final int maxMonths;
  final String coachCopy;

  String get label => '$badge: $title';

  static RoadmapStage forAgeMonths(int months) {
    for (final stage in RoadmapStage.values) {
      if (months >= stage.minMonths && months <= stage.maxMonths) {
        return stage;
      }
    }

    return RoadmapStage.expressionLeap;
  }
}

class CelebrationMoment {
  const CelebrationMoment({
    required this.title,
    required this.detail,
    required this.activityName,
    required this.gainedPoints,
  });

  final String title;
  final String detail;
  final String activityName;
  final int gainedPoints;
}

class AppSnapshot {
  const AppSnapshot({
    required this.caregiverName,
    required this.childName,
    required this.childAgeMonths,
    required this.difficulty,
    required this.onboardingComplete,
    required this.growthPoints,
    required this.weeklyPhraseCount,
    required this.streakDays,
    required this.earnedMilestoneIds,
    required this.spaces,
    required this.diaryEntries,
    required this.milestones,
    required this.coachSuggestions,
  });

  final String caregiverName;
  final String childName;
  final int childAgeMonths;
  final AppDifficulty difficulty;
  final bool onboardingComplete;
  final int growthPoints;
  final int weeklyPhraseCount;
  final int streakDays;
  final Set<String> earnedMilestoneIds;
  final List<SpaceItem> spaces;
  final List<DiaryEntry> diaryEntries;
  final List<MilestoneEntry> milestones;
  final List<CoachSuggestion> coachSuggestions;
}

class AppActionResult {
  const AppActionResult({required this.snapshot, this.celebration});

  final AppSnapshot snapshot;
  final CelebrationMoment? celebration;
}

enum CoachChatRole { mentor, caregiver }

class CoachChatReply {
  const CoachChatReply({
    required this.answer,
    this.suggestedPhraseEnglish,
    this.suggestedPhraseChinese,
    this.followUpPrompt,
  });

  final String answer;
  final String? suggestedPhraseEnglish;
  final String? suggestedPhraseChinese;
  final String? followUpPrompt;
}

class CoachChatMessage {
  const CoachChatMessage({
    required this.id,
    required this.role,
    required this.body,
    this.suggestedPhraseEnglish,
    this.suggestedPhraseChinese,
    this.followUpPrompt,
  });

  final String id;
  final CoachChatRole role;
  final String body;
  final String? suggestedPhraseEnglish;
  final String? suggestedPhraseChinese;
  final String? followUpPrompt;
}

class PhraseItem {
  const PhraseItem({
    required this.id,
    required this.english,
    required this.chinese,
    this.mastered = false,
  });

  final String id;
  final String english;
  final String chinese;
  final bool mastered;

  PhraseItem copyWith({bool? mastered}) {
    return PhraseItem(
      id: id,
      english: english,
      chinese: chinese,
      mastered: mastered ?? this.mastered,
    );
  }
}

class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.name,
    required this.shortLabel,
    required this.icon,
    required this.progress,
    required this.growthStage,
    required this.phrases,
  });

  final String id;
  final String name;
  final String shortLabel;
  final IconData icon;
  final double progress;
  final GrowthStage growthStage;
  final List<PhraseItem> phrases;

  PhraseItem get leadPhrase => phrases.first;

  bool get isMastered => progress >= 0.8;

  ActivityItem copyWith({
    double? progress,
    GrowthStage? growthStage,
    List<PhraseItem>? phrases,
  }) {
    return ActivityItem(
      id: id,
      name: name,
      shortLabel: shortLabel,
      icon: icon,
      progress: progress ?? this.progress,
      growthStage: growthStage ?? this.growthStage,
      phrases: phrases ?? this.phrases,
    );
  }
}

class SpaceItem {
  const SpaceItem({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.mapOffset,
    required this.activities,
  });

  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Offset mapOffset;
  final List<ActivityItem> activities;

  double get progress {
    final total = activities.fold<double>(
      0,
      (sum, activity) => sum + activity.progress,
    );
    return activities.isEmpty ? 0 : total / activities.length;
  }

  int get completedActivities =>
      activities.where((activity) => activity.isMastered).length;

  SpaceItem copyWith({List<ActivityItem>? activities}) {
    return SpaceItem(
      id: id,
      name: name,
      subtitle: subtitle,
      icon: icon,
      color: color,
      mapOffset: mapOffset,
      activities: activities ?? this.activities,
    );
  }
}

class DiaryEntry {
  const DiaryEntry({
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    required this.type,
  });

  final String title;
  final String subtitle;
  final String timeLabel;
  final DiaryEntryType type;
}

class MilestoneEntry {
  const MilestoneEntry({
    required this.title,
    required this.detail,
    required this.timeLabel,
  });

  final String title;
  final String detail;
  final String timeLabel;
}

class CoachSuggestion {
  const CoachSuggestion({required this.title, required this.detail});

  final String title;
  final String detail;
}

extension GrowthStageCopy on GrowthStage {
  String get label {
    switch (this) {
      case GrowthStage.seed:
        return '种子';
      case GrowthStage.sprout:
        return '发芽';
      case GrowthStage.bud:
        return '含苞';
      case GrowthStage.bloom:
        return '盛开';
    }
  }

  String get emoji {
    switch (this) {
      case GrowthStage.seed:
        return '🌰';
      case GrowthStage.sprout:
        return '🌱';
      case GrowthStage.bud:
        return '🌼';
      case GrowthStage.bloom:
        return '🌸';
    }
  }
}
