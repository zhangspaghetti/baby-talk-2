import 'dart:math';

/// Pure Dart Logic Layer service for growth statistics calculations.
///
/// Stateless, no Flutter dependencies, no Repository dependencies.
/// All methods are pure functions operating on their input data.

// ---------------------------------------------------------------------------
// Input / Output data classes
// ---------------------------------------------------------------------------

/// A lightweight practice event record for stats computation.
///
/// This avoids depending on InteractionEventPayload directly, keeping the
/// service decoupled from the data layer.
class PracticeEventRecord {
  const PracticeEventRecord({
    required this.eventKey,
    required this.spaceId,
    required this.activityId,
    required this.phraseId,
    required this.reactionType,
    required this.clientTimestamp,
  });

  final String eventKey;
  final String spaceId;
  final String activityId;
  final String phraseId;
  final String reactionType;
  final DateTime clientTimestamp;
}

/// Aggregated distribution of events per scene (space).
class SceneDistribution {
  const SceneDistribution({
    required this.sceneTag,
    required this.spaceId,
    required this.eventCount,
    required this.activityCount,
    required this.percentage,
  });

  final String sceneTag;
  final String spaceId;
  final int eventCount;
  final int activityCount;
  final double percentage;
}

/// Result of streak calculation.
class StreakResult {
  const StreakResult({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalDaysPracticed,
    required this.lastPracticedAt,
  });

  final int currentStreak;
  final int longestStreak;
  final int totalDaysPracticed;
  final DateTime? lastPracticedAt;
}

/// A detected milestone with its achievement time.
class MilestoneResult {
  const MilestoneResult({
    required this.id,
    required this.title,
    required this.body,
    required this.achievedAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime achievedAt;
}

/// Aggregated stats for a time period.
class PeriodStats {
  const PeriodStats({
    required this.totalEvents,
    required this.uniquePhrases,
    required this.uniqueActivities,
    required this.imitationCount,
    required this.firstEventAt,
    required this.lastEventAt,
    required this.practicedDays,
  });

  final int totalEvents;
  final int uniquePhrases;
  final int uniqueActivities;
  final int imitationCount;
  final DateTime? firstEventAt;
  final DateTime? lastEventAt;
  final int practicedDays;
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class GrowthStatsService {
  const GrowthStatsService();

  /// Aggregates events by scene (space) and returns the distribution.
  ///
  /// Each result includes the event count, unique activity count, and the
  /// percentage of total events that belong to that scene.
  ///
  /// [events] are the practice events to aggregate.
  /// [spaceLabels] maps spaceId to a human-readable scene tag/label.
  List<SceneDistribution> aggregateSceneDistribution({
    required List<PracticeEventRecord> events,
    required Map<String, String> spaceLabels,
  }) {
    if (events.isEmpty) {
      return const <SceneDistribution>[];
    }

    final sceneEventCounts = <String, int>{};
    final sceneActivityCounts = <String, Set<String>>{};

    for (final event in events) {
      sceneEventCounts[event.spaceId] =
          (sceneEventCounts[event.spaceId] ?? 0) + 1;
      sceneActivityCounts.putIfAbsent(
        event.spaceId,
        () => <String>{},
      ).add(event.activityId);
    }

    final totalEvents = events.length;
    final results = <SceneDistribution>[];

    for (final entry in sceneEventCounts.entries) {
      final spaceId = entry.key;
      final count = entry.value;
      results.add(SceneDistribution(
        sceneTag: spaceLabels[spaceId] ?? spaceId,
        spaceId: spaceId,
        eventCount: count,
        activityCount: sceneActivityCounts[spaceId]?.length ?? 0,
        percentage: totalEvents > 0 ? count / totalEvents : 0.0,
      ));
    }

    results.sort((a, b) => b.eventCount.compareTo(a.eventCount));
    return results;
  }

  /// Calculates consecutive practice day streaks from a list of event timestamps.
  ///
  /// [now] is the reference point for "today" (use the current date/time).
  /// Events are normalized to date-only (local time) for streak computation.
  ///
  /// Returns [StreakResult] with current streak, longest streak, total unique
  /// practice days, and the most recent practice time.
  StreakResult calculateStreak({
    required List<DateTime> eventTimes,
    required DateTime now,
  }) {
    if (eventTimes.isEmpty) {
      return const StreakResult(
        currentStreak: 0,
        longestStreak: 0,
        totalDaysPracticed: 0,
        lastPracticedAt: null,
      );
    }

    // Normalize to date-only (local time) and deduplicate.
    final practiceDays = <DateTime>{};
    for (final time in eventTimes) {
      final local = time.toLocal();
      practiceDays.add(DateTime(local.year, local.month, local.day));
    }

    final sortedDays = practiceDays.toList()..sort();
    final lastPracticedAt =
        eventTimes.reduce((a, b) => a.isAfter(b) ? a : b);

    final today = DateTime(now.year, now.month, now.day);
    final totalDaysPracticed = sortedDays.length;

    // Calculate longest streak.
    var longestStreak = 1;
    var currentRun = 1;
    for (var i = 1; i < sortedDays.length; i++) {
      final diff = sortedDays[i].difference(sortedDays[i - 1]).inDays;
      if (diff == 1) {
        currentRun += 1;
        longestStreak = max(longestStreak, currentRun);
      } else if (diff > 1) {
        currentRun = 1;
      }
    }
    if (sortedDays.length > 1) {
      longestStreak = max(longestStreak, currentRun);
    } else {
      longestStreak = sortedDays.length;
    }

    // Calculate current streak (backwards from today or yesterday).
    var currentStreak = 0;

    // If the latest practice day is not today or yesterday, streak is broken.
    final lastDay = sortedDays.last;
    final gapFromToday = today.difference(lastDay).inDays;
    if (gapFromToday > 1) {
      return StreakResult(
        currentStreak: 0,
        longestStreak: longestStreak,
        totalDaysPracticed: totalDaysPracticed,
        lastPracticedAt: lastPracticedAt,
      );
    }

    var checkDate = lastDay;
    for (var i = sortedDays.length - 1; i >= 0; i--) {
      if (sortedDays[i] == checkDate) {
        currentStreak += 1;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (sortedDays[i].isBefore(checkDate)) {
        break;
      }
    }

    return StreakResult(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      totalDaysPracticed: totalDaysPracticed,
      lastPracticedAt: lastPracticedAt,
    );
  }

  /// Detects milestones from a chronological list of events.
  ///
  /// Returns a list of [MilestoneResult] in chronological order.
  /// [knownActivityIds] and [knownSpaceIds] define the full content catalog
  /// so the service can detect "all activities completed" milestones.
  List<MilestoneResult> detectMilestones({
    required List<PracticeEventRecord> events,
    required Set<String> knownActivityIds,
    required Set<String> knownSpaceIds,
  }) {
    if (events.isEmpty) {
      return const <MilestoneResult>[];
    }

    final milestones = <MilestoneResult>[];
    final seenFirstEvent = <String>{};
    final seenImitated = <String>{};
    var totalKnownEvents = 0;

    for (final event in events) {
      totalKnownEvents += 1;

      // First opening milestone.
      if (totalKnownEvents == 1) {
        milestones.add(MilestoneResult(
          id: 'first_opening',
          title: '第一句已经说出口',
          body: '从这一句开始，花园会记住每一次温柔的练习。',
          achievedAt: event.clientTimestamp,
        ));
      }

      // First imitated milestone per activity.
      if (event.reactionType == 'imitated' &&
          !seenImitated.contains(event.activityId)) {
        seenImitated.add(event.activityId);
        milestones.add(MilestoneResult(
          id: 'first_imitated_${event.activityId}',
          title: '宝宝开始回应你的声音',
          body: '一旦出现模仿反应，成长页会把它记成一次暖暖的回声。',
          achievedAt: event.clientTimestamp,
        ));
      }

      // Activity started.
      if (!seenFirstEvent.contains(event.activityId)) {
        seenFirstEvent.add(event.activityId);
        milestones.add(MilestoneResult(
          id: 'activity_${event.activityId}_started',
          title: '开始照料"${event.activityId}"',
          body: '你已经把第一句放进真实动作里，这朵花开始冒芽。',
          achievedAt: event.clientTimestamp,
        ));
      }
    }

    milestones.sort((a, b) => a.achievedAt.compareTo(b.achievedAt));
    return milestones;
  }

  /// Aggregates stats for events within a given time window.
  ///
  /// [events] are all events. [windowStart] and [windowEnd] define the
  /// inclusive time range. Events with clientTimestamp within this range
  /// are included.
  PeriodStats aggregateByPeriod({
    required List<PracticeEventRecord> events,
    required DateTime windowStart,
    required DateTime windowEnd,
  }) {
    final filtered = events.where((e) {
      return !e.clientTimestamp.isBefore(windowStart) &&
          !e.clientTimestamp.isAfter(windowEnd);
    }).toList();

    if (filtered.isEmpty) {
      return const PeriodStats(
        totalEvents: 0,
        uniquePhrases: 0,
        uniqueActivities: 0,
        imitationCount: 0,
        firstEventAt: null,
        lastEventAt: null,
        practicedDays: 0,
      );
    }

    final phrases = <String>{};
    final activities = <String>{};
    final practiceDays = <DateTime>{};
    var imitationCount = 0;
    DateTime? firstEventAt;
    DateTime? lastEventAt;

    for (final event in filtered) {
      phrases.add(event.phraseId);
      activities.add(event.activityId);
      if (event.reactionType == 'imitated') {
        imitationCount += 1;
      }

      final local = event.clientTimestamp.toLocal();
      practiceDays.add(DateTime(local.year, local.month, local.day));

      if (firstEventAt == null || event.clientTimestamp.isBefore(firstEventAt)) {
        firstEventAt = event.clientTimestamp;
      }
      if (lastEventAt == null || event.clientTimestamp.isAfter(lastEventAt)) {
        lastEventAt = event.clientTimestamp;
      }
    }

    return PeriodStats(
      totalEvents: filtered.length,
      uniquePhrases: phrases.length,
      uniqueActivities: activities.length,
      imitationCount: imitationCount,
      firstEventAt: firstEventAt,
      lastEventAt: lastEventAt,
      practicedDays: practiceDays.length,
    );
  }

  /// Convenience: aggregate stats for "this week" relative to [now].
  ///
  /// Week starts on Monday. [now] is the reference point.
  PeriodStats aggregateThisWeek({
    required List<PracticeEventRecord> events,
    required DateTime now,
  }) {
    final localNow = now.toLocal();
    final weekday = localNow.weekday; // 1=Monday, 7=Sunday
    final weekStart = DateTime(
      localNow.year,
      localNow.month,
      localNow.day,
    ).subtract(Duration(days: weekday - 1));

    return aggregateByPeriod(
      events: events,
      windowStart: weekStart,
      windowEnd: localNow,
    );
  }

  /// Convenience: aggregate stats for "this month" relative to [now].
  PeriodStats aggregateThisMonth({
    required List<PracticeEventRecord> events,
    required DateTime now,
  }) {
    final localNow = now.toLocal();
    final monthStart = DateTime(localNow.year, localNow.month, 1);

    return aggregateByPeriod(
      events: events,
      windowStart: monthStart,
      windowEnd: localNow,
    );
  }

  /// Convenience: aggregate stats for "this year" relative to [now].
  PeriodStats aggregateThisYear({
    required List<PracticeEventRecord> events,
    required DateTime now,
  }) {
    final localNow = now.toLocal();
    final yearStart = DateTime(localNow.year, 1, 1);

    return aggregateByPeriod(
      events: events,
      windowStart: yearStart,
      windowEnd: localNow,
    );
  }
}
