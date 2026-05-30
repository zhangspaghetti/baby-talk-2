import 'package:flutter/foundation.dart';
import 'package:mobile/features/growth/data/remote/growth_summary_api_service.dart';
import 'package:mobile/features/growth/domain/services/growth_stats_service.dart';
import 'package:mobile/features/growth/presentation/growth_insights_models.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';

/// Loads the local practice event history and exposes aggregated growth
/// insights (streak + per-period stats + trend buckets) for the growth tab.
///
/// All heavy lifting is delegated to the pure [GrowthStatsService]; this
/// notifier only handles loading, caching, and time-bucket construction.
class GrowthInsightsNotifier extends ChangeNotifier {
  GrowthInsightsNotifier({
    required Future<PracticeRepository> repositoryFuture,
    GrowthStatsService statsService = const GrowthStatsService(),
    DateTime Function() now = DateTime.now,
  }) : _repositoryFuture = repositoryFuture,
       _stats = statsService,
       _now = now;

  final Future<PracticeRepository> _repositoryFuture;
  final GrowthStatsService _stats;
  final DateTime Function() _now;

  List<PracticeEventRecord> _records = const <PracticeEventRecord>[];
  Map<String, String> _spaceLabels = const <String, String>{};
  PracticeActivityCatalog? _catalog;
  bool _loaded = false;
  bool _hasError = false;
  bool _disposed = false;
  Map<GrowthPeriod, PeriodStats> _periodStats =
      const <GrowthPeriod, PeriodStats>{};

  bool get isLoaded => _loaded;
  bool get hasError => _hasError;

  Future<void> initialize() async {
    if (_loaded) return;
    try {
      final repository = await _repositoryFuture;
      final events = await repository.listEventHistory();
      _records = events
          .map(
            (e) => PracticeEventRecord(
              eventKey: e.eventKey,
              spaceId: e.spaceId,
              activityId: e.activityId,
              phraseId: e.phraseId,
              reactionType: e.reactionType.wireValue,
              clientTimestamp: e.clientTimestamp,
            ),
          )
          .toList(growable: false);
      // Resolve human-readable scene labels (spaceId -> title). Best-effort:
      // a catalog failure must not drop the loaded event history.
      try {
        final catalog = await repository.getActivityCatalog();
        _catalog = catalog;
        _spaceLabels = {
          for (final space in catalog.spaces) space.spaceId: space.title,
        };
      } catch (_) {
        _catalog = null;
        _spaceLabels = const <String, String>{};
      }

      final now = _now();
      _periodStats = {
        GrowthPeriod.week: await _loadPeriodStats(
          period: GrowthPeriod.week,
          now: now,
        ),
        GrowthPeriod.month: await _loadPeriodStats(
          period: GrowthPeriod.month,
          now: now,
        ),
        GrowthPeriod.year: await _loadPeriodStats(
          period: GrowthPeriod.year,
          now: now,
        ),
      };
      _hasError = false;
    } catch (_) {
      _records = const <PracticeEventRecord>[];
      _periodStats = const <GrowthPeriod, PeriodStats>{};
      _hasError = true;
    } finally {
      _loaded = true;
      if (!_disposed) notifyListeners();
    }
  }

  /// Builds the view-state for [period]. Returns a loading state until the
  /// event history has finished loading.
  GrowthInsightsViewState viewFor(GrowthPeriod period) {
    if (!_loaded) {
      return GrowthInsightsViewState.loading(period);
    }

    final now = _now();
    final streak = _stats.calculateStreak(
      eventTimes: _records.map((e) => e.clientTimestamp).toList(),
      now: now,
    );

    final PeriodStats stats;
    final List<GrowthBarBucket> bars;
    final DateTime windowStart;
    switch (period) {
      case GrowthPeriod.week:
        stats =
            _periodStats[GrowthPeriod.week] ??
            _stats.aggregateThisWeek(events: _records, now: now);
        bars = _weekBuckets(now);
        windowStart = _weekStart(now);
        break;
      case GrowthPeriod.month:
        stats =
            _periodStats[GrowthPeriod.month] ??
            _stats.aggregateThisMonth(events: _records, now: now);
        bars = _monthBuckets(now);
        windowStart = DateTime(now.toLocal().year, now.toLocal().month, 1);
        break;
      case GrowthPeriod.year:
        stats =
            _periodStats[GrowthPeriod.year] ??
            _stats.aggregateThisYear(events: _records, now: now);
        bars = _yearBuckets(now);
        windowStart = DateTime(now.toLocal().year, 1, 1);
        break;
    }

    final windowRecords = _records.where((e) {
      final ts = e.clientTimestamp;
      return !ts.isBefore(windowStart) && !ts.isAfter(now);
    }).toList(growable: false);
    final scenes = _stats.aggregateSceneDistribution(
      events: windowRecords,
      spaceLabels: _spaceLabels,
    );

    return GrowthInsightsViewState(
      isLoading: false,
      hasError: _hasError,
      period: period,
      streak: streak,
      stats: stats,
      bars: bars,
      scenes: scenes,
      windowStart: windowStart,
      windowEnd: now,
      suggestion: _nextStepSuggestion(period),
      recentActivity: _recentActivity(now),
    );
  }

  /// This-week vs last-week practice counts for the lightweight recent-activity
  /// module (spec §8). Always weekly, independent of the selected period.
  GrowthRecentActivity _recentActivity(DateTime now) {
    final thisWeekStart = _weekStart(now);
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
    final thisWeek = _countInRange(
      thisWeekStart,
      thisWeekStart.add(const Duration(days: 7)),
    );
    final lastWeek = _countInRange(lastWeekStart, thisWeekStart);
    return GrowthRecentActivity(
      thisWeekCount: thisWeek,
      lastWeekCount: lastWeek,
    );
  }

  /// A gentle next-step suggestion for the week/month views: the first scene
  /// the user has never practiced, paired with one concrete phrase to try.
  /// Returns null for the year view, when the catalog is unavailable, or once
  /// every scene has at least one recorded event.
  GrowthNextStepSuggestion? _nextStepSuggestion(GrowthPeriod period) {
    if (period == GrowthPeriod.year) return null;
    final catalog = _catalog;
    if (catalog == null) return null;

    for (final space in catalog.spaces) {
      if (space.totalEvents > 0) continue;
      for (final activity in space.activities) {
        final phrase = activity.nextPhraseEnglish;
        if (phrase == null || phrase.trim().isEmpty) continue;
        return GrowthNextStepSuggestion(
          sceneLabel: space.title,
          phraseEnglish: phrase,
          spaceId: space.spaceId,
          activityId: activity.activityId,
        );
      }
    }
    return null;
  }

  // ── Bucket builders ──────────────────────────────────────────────────────

  static const List<String> _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  /// Seven daily buckets for the current week (Monday → Sunday).
  List<GrowthBarBucket> _weekBuckets(DateTime now) {
    final weekStart = _weekStart(now);
    return List<GrowthBarBucket>.generate(7, (i) {
      final day = weekStart.add(Duration(days: i));
      return GrowthBarBucket(
        label: _weekdayLabels[i],
        count: _countInDay(day),
      );
    });
  }

  /// Monday 00:00 of the week that contains [now] (local).
  DateTime _weekStart(DateTime now) {
    final local = now.toLocal();
    final today = DateTime(local.year, local.month, local.day);
    return today.subtract(Duration(days: local.weekday - 1));
  }

  /// Weekly buckets covering the current month (第1周 … 第N周).
  List<GrowthBarBucket> _monthBuckets(DateTime now) {
    final local = now.toLocal();
    final monthStart = DateTime(local.year, local.month, 1);
    final daysInMonth = DateTime(local.year, local.month + 1, 0).day;
    final weekCount = (daysInMonth / 7).ceil();
    return List<GrowthBarBucket>.generate(weekCount, (i) {
      final start = monthStart.add(Duration(days: i * 7));
      final end = monthStart.add(Duration(days: (i + 1) * 7));
      return GrowthBarBucket(
        label: '第${i + 1}周',
        count: _countInRange(start, end),
      );
    });
  }

  /// Twelve monthly buckets for the current year (1月 … 12月).
  List<GrowthBarBucket> _yearBuckets(DateTime now) {
    final local = now.toLocal();
    return List<GrowthBarBucket>.generate(12, (i) {
      final start = DateTime(local.year, i + 1, 1);
      final end = DateTime(local.year, i + 2, 1);
      return GrowthBarBucket(
        label: '${i + 1}',
        count: _countInRange(start, end),
      );
    });
  }

  int _countInDay(DateTime day) {
    final next = day.add(const Duration(days: 1));
    return _countInRange(day, next);
  }

  /// Counts events with a local timestamp in [start, end).
  int _countInRange(DateTime start, DateTime end) {
    var count = 0;
    for (final record in _records) {
      final local = record.clientTimestamp.toLocal();
      if (!local.isBefore(start) && local.isBefore(end)) {
        count += 1;
      }
    }
    return count;
  }

  Future<PeriodStats> _loadPeriodStats({
    required GrowthPeriod period,
    required DateTime now,
  }) async {
    try {
      final summary = await _stats.loadSummary(period: _toSummaryPeriod(period));
      return summary.stats;
    } catch (_) {
      return _computeLocalPeriodStats(period: period, now: now);
    }
  }

  PeriodStats _computeLocalPeriodStats({
    required GrowthPeriod period,
    required DateTime now,
  }) {
    switch (period) {
      case GrowthPeriod.week:
        return _stats.aggregateThisWeek(events: _records, now: now);
      case GrowthPeriod.month:
        return _stats.aggregateThisMonth(events: _records, now: now);
      case GrowthPeriod.year:
        return _stats.aggregateThisYear(events: _records, now: now);
    }
  }

  GrowthSummaryPeriod _toSummaryPeriod(GrowthPeriod period) {
    switch (period) {
      case GrowthPeriod.week:
        return GrowthSummaryPeriod.week;
      case GrowthPeriod.month:
        return GrowthSummaryPeriod.month;
      case GrowthPeriod.year:
        return GrowthSummaryPeriod.year;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
