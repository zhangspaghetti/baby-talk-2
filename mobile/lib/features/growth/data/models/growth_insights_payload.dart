// Deserialization models for the `/api/v1/growth/insights` response.

class GrowthInsightsPayload {
  const GrowthInsightsPayload({
    required this.period,
    required this.windowStart,
    required this.windowEnd,
    required this.generatedAt,
    required this.stats,
    required this.streak,
    required this.bars,
    required this.scenes,
    required this.recentActivity,
    this.suggestion,
    this.isFallback = false,
  });

  final String period;
  final DateTime windowStart;
  final DateTime windowEnd;
  final DateTime generatedAt;
  final InsightsStats stats;
  final InsightsStreak streak;
  final List<InsightsBarBucket> bars;
  final List<InsightsScene> scenes;
  final InsightsRecentActivity recentActivity;
  final InsightsSuggestion? suggestion;
  final bool isFallback;

  factory GrowthInsightsPayload.fromJson(Map<String, dynamic> json) {
    return GrowthInsightsPayload(
      period: json['period'] as String? ?? '',
      windowStart:
          _readDateTime(json, 'windowStart') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      windowEnd:
          _readDateTime(json, 'windowEnd') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      generatedAt:
          _readDateTime(json, 'generatedAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      stats: InsightsStats.fromJson(
        json['stats'] as Map<String, dynamic>? ?? {},
      ),
      streak: InsightsStreak.fromJson(
        json['streak'] as Map<String, dynamic>? ?? {},
      ),
      bars:
          (json['bars'] as List<dynamic>?)
              ?.map(
                (e) => InsightsBarBucket.fromJson(e as Map<String, dynamic>),
              )
              .toList(growable: false) ??
          const [],
      scenes:
          (json['scenes'] as List<dynamic>?)
              ?.map((e) => InsightsScene.fromJson(e as Map<String, dynamic>))
              .toList(growable: false) ??
          const [],
      recentActivity: InsightsRecentActivity.fromJson(
        json['recentActivity'] as Map<String, dynamic>? ?? {},
      ),
      suggestion: json['suggestion'] != null
          ? InsightsSuggestion.fromJson(
              json['suggestion'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class InsightsStats {
  const InsightsStats({
    required this.totalEvents,
    required this.uniquePhrases,
    required this.uniqueActivities,
    required this.cooperatingCount,
    required this.practicedDays,
    this.firstEventAt,
    this.lastEventAt,
  });

  final int totalEvents;
  final int uniquePhrases;
  final int uniqueActivities;
  final int cooperatingCount;
  final int practicedDays;
  final DateTime? firstEventAt;
  final DateTime? lastEventAt;

  factory InsightsStats.fromJson(Map<String, dynamic> json) {
    return InsightsStats(
      totalEvents: _readInt(json, 'totalEvents'),
      uniquePhrases: _readInt(json, 'uniquePhrases'),
      uniqueActivities: _readInt(json, 'uniqueActivities'),
      cooperatingCount: _readInt(json, 'cooperatingCount'),
      practicedDays: _readInt(json, 'practicedDays'),
      firstEventAt: _readDateTime(json, 'firstEventAt'),
      lastEventAt: _readDateTime(json, 'lastEventAt'),
    );
  }
}

class InsightsStreak {
  const InsightsStreak({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalDaysPracticed,
    this.lastPracticedAt,
  });

  final int currentStreak;
  final int longestStreak;
  final int totalDaysPracticed;
  final DateTime? lastPracticedAt;

  factory InsightsStreak.fromJson(Map<String, dynamic> json) {
    return InsightsStreak(
      currentStreak: _readInt(json, 'currentStreak'),
      longestStreak: _readInt(json, 'longestStreak'),
      totalDaysPracticed: _readInt(json, 'totalDaysPracticed'),
      lastPracticedAt: _readDateTime(json, 'lastPracticedAt'),
    );
  }
}

class InsightsBarBucket {
  const InsightsBarBucket({required this.bucketStart, required this.count});

  final DateTime bucketStart;
  final int count;

  factory InsightsBarBucket.fromJson(Map<String, dynamic> json) {
    return InsightsBarBucket(
      bucketStart:
          _readDateTime(json, 'bucketStart') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      count: _readInt(json, 'count'),
    );
  }
}

class InsightsScene {
  const InsightsScene({
    required this.spaceId,
    required this.sceneTag,
    required this.eventCount,
    required this.activityCount,
    required this.percentage,
  });

  final String spaceId;
  final String sceneTag;
  final int eventCount;
  final int activityCount;
  final double percentage;

  factory InsightsScene.fromJson(Map<String, dynamic> json) {
    return InsightsScene(
      spaceId: json['spaceId'] as String? ?? '',
      sceneTag: json['sceneTag'] as String? ?? '',
      eventCount: _readInt(json, 'eventCount'),
      activityCount: _readInt(json, 'activityCount'),
      percentage: _readDouble(json, 'percentage'),
    );
  }
}

class InsightsRecentActivity {
  const InsightsRecentActivity({
    required this.thisWeekCount,
    required this.lastWeekCount,
  });

  final int thisWeekCount;
  final int lastWeekCount;

  factory InsightsRecentActivity.fromJson(Map<String, dynamic> json) {
    return InsightsRecentActivity(
      thisWeekCount: _readInt(json, 'thisWeekCount'),
      lastWeekCount: _readInt(json, 'lastWeekCount'),
    );
  }
}

class InsightsSuggestion {
  const InsightsSuggestion({
    required this.spaceId,
    required this.activityId,
    required this.sceneLabel,
    required this.phraseEnglish,
  });

  final String spaceId;
  final String activityId;
  final String sceneLabel;
  final String phraseEnglish;

  factory InsightsSuggestion.fromJson(Map<String, dynamic> json) {
    return InsightsSuggestion(
      spaceId: json['spaceId'] as String? ?? '',
      activityId: json['activityId'] as String? ?? '',
      sceneLabel: json['sceneLabel'] as String? ?? '',
      phraseEnglish: json['phraseEnglish'] as String? ?? '',
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

int _readInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

double _readDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return 0.0;
}

DateTime? _readDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}
