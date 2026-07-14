import 'dart:math';

import 'package:mobile/features/growth/data/remote/growth_summary_api_service.dart';

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

/// Aggregated stats for a time period.
class PeriodStats {
  const PeriodStats({
    required this.totalEvents,
    required this.uniquePhrases,
    required this.uniqueActivities,
    required this.cooperatingCount,
    required this.firstEventAt,
    required this.lastEventAt,
    required this.practicedDays,
  });

  final int totalEvents;
  final int uniquePhrases;
  final int uniqueActivities;
  final int cooperatingCount;
  final DateTime? firstEventAt;
  final DateTime? lastEventAt;
  final int practicedDays;
}

typedef LocalPeriodStatsLoader =
    Future<PeriodStats> Function({required GrowthSummaryPeriod period});

enum GrowthSummarySource { remote, localFallback }

class GrowthSummaryResult {
  const GrowthSummaryResult({required this.source, required this.stats});

  final GrowthSummarySource source;
  final PeriodStats stats;
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class GrowthStatsService {
  const GrowthStatsService()
    : _remoteDataSource = null,
      _localPeriodLoader = null;

  GrowthStatsService.remoteFirst({
    required GrowthSummaryRemoteDataSource remoteDataSource,
    required LocalPeriodStatsLoader localPeriodLoader,
  }) : _remoteDataSource = remoteDataSource,
       _localPeriodLoader = localPeriodLoader;

  final GrowthSummaryRemoteDataSource? _remoteDataSource;
  final LocalPeriodStatsLoader? _localPeriodLoader;

  Future<GrowthSummaryResult> loadSummary({
    required GrowthSummaryPeriod period,
  }) async {
    final remoteDataSource = _remoteDataSource;
    final localPeriodLoader = _localPeriodLoader;
    if (remoteDataSource == null || localPeriodLoader == null) {
      throw StateError('GrowthStatsService 未配置 remote-first 依赖。');
    }

    try {
      final remoteSummary = await remoteDataSource.fetchSummary(period: period);
      return GrowthSummaryResult(
        source: GrowthSummarySource.remote,
        stats: PeriodStats(
          totalEvents: remoteSummary.totalEvents,
          uniquePhrases: remoteSummary.uniquePhrases,
          uniqueActivities: remoteSummary.uniqueActivities,
          cooperatingCount: remoteSummary.cooperatingCount,
          firstEventAt: remoteSummary.firstEventAt,
          lastEventAt: remoteSummary.lastEventAt,
          practicedDays: remoteSummary.practicedDays,
        ),
      );
    } on Object {
      final fallbackStats = await localPeriodLoader(period: period);
      return GrowthSummaryResult(
        source: GrowthSummarySource.localFallback,
        stats: fallbackStats,
      );
    }
  }

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
      sceneActivityCounts
          .putIfAbsent(event.spaceId, () => <String>{})
          .add(event.activityId);
    }

    final totalEvents = events.length;
    final results = <SceneDistribution>[];

    for (final entry in sceneEventCounts.entries) {
      final spaceId = entry.key;
      final count = entry.value;
      results.add(
        SceneDistribution(
          sceneTag: spaceLabels[spaceId] ?? spaceId,
          spaceId: spaceId,
          eventCount: count,
          activityCount: sceneActivityCounts[spaceId]?.length ?? 0,
          percentage: totalEvents > 0 ? count / totalEvents : 0.0,
        ),
      );
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
    final lastPracticedAt = eventTimes.reduce((a, b) => a.isAfter(b) ? a : b);

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
        cooperatingCount: 0,
        firstEventAt: null,
        lastEventAt: null,
        practicedDays: 0,
      );
    }

    final phrases = <String>{};
    final activities = <String>{};
    final practiceDays = <DateTime>{};
    var cooperatingCount = 0;
    DateTime? firstEventAt;
    DateTime? lastEventAt;

    for (final event in filtered) {
      phrases.add(event.phraseId);
      activities.add(event.activityId);
      if (event.reactionType == 'cooperating') {
        cooperatingCount += 1;
      }

      final local = event.clientTimestamp.toLocal();
      practiceDays.add(DateTime(local.year, local.month, local.day));

      if (firstEventAt == null ||
          event.clientTimestamp.isBefore(firstEventAt)) {
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
      cooperatingCount: cooperatingCount,
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
