import 'package:flutter/foundation.dart';
import 'package:mobile/features/growth/domain/services/growth_stats_service.dart';
import 'package:mobile/features/growth/presentation/growth_insights_models.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

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
  bool _loaded = false;
  bool _hasError = false;
  bool _disposed = false;

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
      _hasError = false;
    } catch (_) {
      _records = const <PracticeEventRecord>[];
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
    switch (period) {
      case GrowthPeriod.week:
        stats = _stats.aggregateThisWeek(events: _records, now: now);
        bars = _weekBuckets(now);
        break;
      case GrowthPeriod.month:
        stats = _stats.aggregateThisMonth(events: _records, now: now);
        bars = _monthBuckets(now);
        break;
      case GrowthPeriod.year:
        stats = _stats.aggregateThisYear(events: _records, now: now);
        bars = _yearBuckets(now);
        break;
    }

    return GrowthInsightsViewState(
      isLoading: false,
      hasError: _hasError,
      period: period,
      streak: streak,
      stats: stats,
      bars: bars,
    );
  }

  // ── Bucket builders ──────────────────────────────────────────────────────

  static const List<String> _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  /// Seven daily buckets for the current week (Monday → Sunday).
  List<GrowthBarBucket> _weekBuckets(DateTime now) {
    final local = now.toLocal();
    final today = DateTime(local.year, local.month, local.day);
    final weekStart = today.subtract(Duration(days: local.weekday - 1));
    return List<GrowthBarBucket>.generate(7, (i) {
      final day = weekStart.add(Duration(days: i));
      return GrowthBarBucket(
        label: _weekdayLabels[i],
        count: _countInDay(day),
      );
    });
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

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
