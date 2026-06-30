import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mobile/features/growth/data/models/growth_insights_payload.dart';
import 'package:mobile/features/growth/data/remote/growth_insights_api_service.dart';
import 'package:mobile/features/growth/domain/services/growth_stats_service.dart';
import 'package:mobile/features/growth/presentation/growth_insights_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loads growth insights from the remote API and exposes aggregated stats
/// (streak + per-period stats + trend buckets) for the growth tab.
///
/// On [initialize], the notifier:
/// 1. Loads cached state from SharedPreferences (instant paint).
/// 2. Fetches all three periods in parallel from the API.
/// 3. Saves fresh data to cache on success.
/// 4. Falls back to stale cache on network failure.
class GrowthInsightsNotifier extends ChangeNotifier {
  GrowthInsightsNotifier({
    required GrowthInsightsApiService apiService,
    SharedPreferences? prefs,
    DateTime Function() now = DateTime.now,
  }) : _apiService = apiService,
       _prefsFuture = prefs != null
           ? Future.value(prefs)
           : SharedPreferences.getInstance(),
       _now = now;

  static const _cacheKeyPrefix = 'growth_insights_reaction_v2_';

  final GrowthInsightsApiService _apiService;
  final Future<SharedPreferences> _prefsFuture;
  final DateTime Function() _now;

  bool _loaded = false;
  bool _hasError = false;
  bool _disposed = false;
  Map<GrowthPeriod, GrowthInsightsViewState> _views = {};

  bool get isLoaded => _loaded;
  bool get hasError => _hasError;

  Future<void> initialize() async {
    if (_loaded) return;

    // 1. Load from cache for instant paint.
    await _loadFromCache();

    // 2. Fetch fresh data from API.
    await _fetchAndCache();
  }

  /// Returns the view-state for [period]. Returns a loading state until
  /// initialization has completed.
  GrowthInsightsViewState viewFor(GrowthPeriod period) {
    if (!_loaded) {
      return GrowthInsightsViewState.loading(period);
    }
    return _views[period] ?? GrowthInsightsViewState.loading(period);
  }

  // ── Cache ────────────────────────────────────────────────────────────────

  String _cacheKey(GrowthPeriod period) => '$_cacheKeyPrefix${period.name}';

  Future<void> _loadFromCache() async {
    try {
      final prefs = await _prefsFuture;
      for (final period in GrowthPeriod.values) {
        final raw = prefs.getString(_cacheKey(period));
        if (raw == null) continue;
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final cachedAtStr = json['cachedAt'] as String?;
        if (cachedAtStr == null) continue;
        final cachedAt = DateTime.tryParse(cachedAtStr);
        if (cachedAt == null) continue;
        if (_now().difference(cachedAt).inMinutes > 15) continue;
        final payload = GrowthInsightsPayload.fromJson(
          json['payload'] as Map<String, dynamic>,
        );
        _views[period] = _mapToViewState(period, payload);
      }
      if (_views.isNotEmpty) {
        _loaded = true;
        if (!_disposed) notifyListeners();
      }
    } catch (_) {
      // Cache read failure is non-fatal; we'll fetch from API.
    }
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await _prefsFuture;
      final now = _now().toUtc().toIso8601String();
      for (final period in GrowthPeriod.values) {
        final view = _views[period];
        if (view == null) continue;
        // Reconstruct the payload fields from the view-state for serialization.
        final payload = _viewStateToPayloadJson(period, view);
        final cacheEntry = jsonEncode({'cachedAt': now, 'payload': payload});
        await prefs.setString(_cacheKey(period), cacheEntry);
      }
    } catch (_) {
      // Cache write failure is non-fatal.
    }
  }

  // ── API fetch ────────────────────────────────────────────────────────────

  Future<void> _fetchAndCache() async {
    final newViews = <GrowthPeriod, GrowthInsightsViewState>{};
    bool anySuccess = false;

    // Fetch all 3 periods in parallel. Wrap each in catchError so a single
    // period failure doesn't cancel the others via AggregateException.
    final periods = GrowthPeriod.values;
    final results = await Future.wait([
      for (final period in periods)
        _apiService
            .fetchInsights(period.name)
            .catchError(
              (Object e) => GrowthInsightsPayload(
                period: period.name,
                windowStart: _now(),
                windowEnd: _now(),
                generatedAt: _now(),
                stats: const InsightsStats(
                  totalEvents: 0,
                  uniquePhrases: 0,
                  uniqueActivities: 0,
                  cooperatingCount: 0,
                  practicedDays: 0,
                ),
                streak: const InsightsStreak(
                  currentStreak: 0,
                  longestStreak: 0,
                  totalDaysPracticed: 0,
                ),
                bars: const [],
                scenes: const [],
                recentActivity: const InsightsRecentActivity(
                  thisWeekCount: 0,
                  lastWeekCount: 0,
                ),
                isFallback: true,
              ),
            ),
    ]);

    for (var i = 0; i < periods.length; i++) {
      if (!results[i].isFallback) {
        newViews[periods[i]] = _mapToViewState(periods[i], results[i]);
        anySuccess = true;
      }
    }

    if (anySuccess) {
      _views = {..._views, ...newViews};
      _hasError = false;
      await _saveToCache();
    } else if (_views.isEmpty) {
      _hasError = true;
      // Populate _views with error states so viewFor returns hasError
      // instead of the loading placeholder.
      for (final period in GrowthPeriod.values) {
        _views[period] = GrowthInsightsViewState.error(period);
      }
    }
    // else: keep stale cache data already loaded, _hasError stays false.

    _loaded = true;
    if (!_disposed) notifyListeners();
  }

  // ── Mapping ──────────────────────────────────────────────────────────────

  GrowthInsightsViewState _mapToViewState(
    GrowthPeriod period,
    GrowthInsightsPayload payload,
  ) {
    return GrowthInsightsViewState(
      isLoading: false,
      hasError: false,
      period: period,
      streak: StreakResult(
        currentStreak: payload.streak.currentStreak,
        longestStreak: payload.streak.longestStreak,
        totalDaysPracticed: payload.streak.totalDaysPracticed,
        lastPracticedAt: payload.streak.lastPracticedAt,
      ),
      stats: PeriodStats(
        totalEvents: payload.stats.totalEvents,
        uniquePhrases: payload.stats.uniquePhrases,
        uniqueActivities: payload.stats.uniqueActivities,
        cooperatingCount: payload.stats.cooperatingCount,
        practicedDays: payload.stats.practicedDays,
        firstEventAt: payload.stats.firstEventAt,
        lastEventAt: payload.stats.lastEventAt,
      ),
      bars: payload.bars
          .map(
            (b) => GrowthBarBucket(
              label: _barLabel(period, b.bucketStart),
              count: b.count,
              bucketStart: b.bucketStart,
            ),
          )
          .toList(growable: false),
      scenes: payload.scenes
          .map(
            (s) => SceneDistribution(
              spaceId: s.spaceId,
              sceneTag: s.sceneTag,
              eventCount: s.eventCount,
              activityCount: s.activityCount,
              percentage: s.percentage,
            ),
          )
          .toList(growable: false),
      windowStart: payload.windowStart,
      windowEnd: payload.windowEnd,
      suggestion: payload.suggestion != null
          ? GrowthNextStepSuggestion(
              spaceId: payload.suggestion!.spaceId,
              activityId: payload.suggestion!.activityId,
              sceneLabel: payload.suggestion!.sceneLabel,
              phraseEnglish: payload.suggestion!.phraseEnglish,
            )
          : null,
      recentActivity: GrowthRecentActivity(
        thisWeekCount: payload.recentActivity.thisWeekCount,
        lastWeekCount: payload.recentActivity.lastWeekCount,
      ),
    );
  }

  static const List<String> _weekdayLabels = [
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '日',
  ];

  String _barLabel(GrowthPeriod period, DateTime bucketStart) {
    switch (period) {
      case GrowthPeriod.week:
        // bucketStart is a Monday-based day.
        final weekday = bucketStart.toLocal().weekday;
        return _weekdayLabels[weekday - 1];
      case GrowthPeriod.month:
        // Approximate week-in-month index from day-of-month.
        final dayOfMonth = bucketStart.toLocal().day;
        final weekIndex = ((dayOfMonth - 1) ~/ 7) + 1;
        return '第$weekIndex周';
      case GrowthPeriod.year:
        return '${bucketStart.toLocal().month}';
    }
  }

  /// Serializes a [GrowthInsightsViewState] back to a JSON map that can be
  /// wrapped in a cache entry with a `cachedAt` timestamp.
  Map<String, dynamic> _viewStateToPayloadJson(
    GrowthPeriod period,
    GrowthInsightsViewState view,
  ) {
    return {
      'period': period.name,
      'windowStart': view.windowStart?.toUtc().toIso8601String(),
      'windowEnd': view.windowEnd?.toUtc().toIso8601String(),
      'generatedAt': _now().toUtc().toIso8601String(),
      'stats': {
        'totalEvents': view.stats.totalEvents,
        'uniquePhrases': view.stats.uniquePhrases,
        'uniqueActivities': view.stats.uniqueActivities,
        'cooperatingCount': view.stats.cooperatingCount,
        'practicedDays': view.stats.practicedDays,
        'firstEventAt': view.stats.firstEventAt?.toUtc().toIso8601String(),
        'lastEventAt': view.stats.lastEventAt?.toUtc().toIso8601String(),
      },
      'streak': {
        'currentStreak': view.streak.currentStreak,
        'longestStreak': view.streak.longestStreak,
        'totalDaysPracticed': view.streak.totalDaysPracticed,
        'lastPracticedAt': view.streak.lastPracticedAt
            ?.toUtc()
            .toIso8601String(),
      },
      'bars': [
        for (final bar in view.bars)
          {
            'bucketStart': bar.bucketStart.toUtc().toIso8601String(),
            'count': bar.count,
          },
      ],
      'scenes': [
        for (final scene in view.scenes)
          {
            'spaceId': scene.spaceId,
            'sceneTag': scene.sceneTag,
            'eventCount': scene.eventCount,
            'activityCount': scene.activityCount,
            'percentage': scene.percentage,
          },
      ],
      'recentActivity': {
        'thisWeekCount': view.recentActivity?.thisWeekCount ?? 0,
        'lastWeekCount': view.recentActivity?.lastWeekCount ?? 0,
      },
      if (view.suggestion != null)
        'suggestion': {
          'spaceId': view.suggestion!.spaceId,
          'activityId': view.suggestion!.activityId,
          'sceneLabel': view.suggestion!.sceneLabel,
          'phraseEnglish': view.suggestion!.phraseEnglish,
        },
    };
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
