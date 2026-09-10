import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
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
    String? accountContext,
  }) : _apiService = apiService,
       _prefsFuture = prefs != null
           ? Future.value(prefs)
           : SharedPreferences.getInstance(),
       _now = now,
       _accountContext = _normalizeAccountContext(accountContext);

  static const _cacheKeyPrefix = 'growth_insights_reaction_v2_';

  final GrowthInsightsApiService _apiService;
  final Future<SharedPreferences> _prefsFuture;
  final DateTime Function() _now;

  String? _accountContext;
  bool _loaded = false;
  bool _hasError = false;
  bool _disposed = false;
  int _scopeGeneration = 0;
  Future<void>? _initializeFuture;
  Map<GrowthPeriod, GrowthInsightsViewState> _views = {};

  bool get isLoaded => _loaded;
  bool get hasError => _hasError;
  String? get accountContext => _accountContext;

  Future<void> initialize() {
    if (_disposed || _loaded) return Future.value();
    final existing = _initializeFuture;
    if (existing != null) return existing;

    final generation = _scopeGeneration;
    final accountContext = _accountContext;
    final future = _initializeInternal(
      generation: generation,
      accountContext: accountContext,
    );
    _initializeFuture = future;
    return future.whenComplete(() {
      if (identical(_initializeFuture, future)) {
        _initializeFuture = null;
      }
    });
  }

  Future<void> _initializeInternal({
    required int generation,
    required String? accountContext,
  }) async {
    // 1. Load from the current account's cache for instant paint.
    await _loadFromCache(
      generation: generation,
      accountContext: accountContext,
    );
    if (!_ownsScope(generation, accountContext)) return;

    // 2. Fetch fresh data from API.
    await _fetchAndCache(
      generation: generation,
      accountContext: accountContext,
    );
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

  String? _cacheKey(String? accountContext, GrowthPeriod period) {
    final normalized = _normalizeAccountContext(accountContext);
    if (normalized == null) return null;
    final scopeFingerprint = sha256.convert(utf8.encode(normalized)).toString();
    return '$_cacheKeyPrefix${scopeFingerprint}_${period.name}';
  }

  Future<void> _loadFromCache({
    required int generation,
    required String? accountContext,
  }) async {
    // Anonymous/local-only state has no account-owned remote cache. In
    // particular, never read legacy period-only keys into an account view.
    if (accountContext == null) return;
    try {
      final prefs = await _prefsFuture;
      for (final period in GrowthPeriod.values) {
        if (!_ownsScope(generation, accountContext)) return;
        final key = _cacheKey(accountContext, period);
        if (key == null) return;
        final raw = prefs.getString(key);
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
        _views[period] = _mapToViewState(period, payload, isCached: true);
      }
      if (_views.isNotEmpty && _ownsScope(generation, accountContext)) {
        _loaded = true;
        if (!_disposed) notifyListeners();
      }
    } catch (_) {
      // Cache read failure is non-fatal; we'll fetch from API.
    }
  }

  Future<void> _saveToCache({required String accountContext}) async {
    try {
      final prefs = await _prefsFuture;
      final now = _now().toUtc().toIso8601String();
      for (final period in GrowthPeriod.values) {
        if (!_ownsScope(_scopeGeneration, accountContext)) return;
        final view = _views[period];
        if (view == null || view.hasError || view.isCached) continue;
        // Reconstruct the payload fields from the view-state for serialization.
        final payload = _viewStateToPayloadJson(period, view);
        final cacheEntry = jsonEncode({'cachedAt': now, 'payload': payload});
        final key = _cacheKey(accountContext, period);
        if (key == null) return;
        await prefs.setString(key, cacheEntry);
      }
    } catch (_) {
      // Cache write failure is non-fatal.
    }
  }

  // ── API fetch ────────────────────────────────────────────────────────────

  Future<void> _fetchAndCache({
    required int generation,
    required String? accountContext,
  }) async {
    final newViews = <GrowthPeriod, GrowthInsightsViewState>{};
    bool anySuccess = false;

    // Fetch all 3 periods in parallel. Keep each failure explicit: a failed
    // request must never be represented as a zero-value growth payload.
    final periods = GrowthPeriod.values;
    final results = await Future.wait<_GrowthFetchResult>([
      for (final period in periods) _fetchPeriod(period),
    ]);

    if (!_ownsScope(generation, accountContext)) return;

    for (var i = 0; i < periods.length; i++) {
      final result = results[i];
      if (result.payload case final payload?) {
        newViews[periods[i]] = _mapToViewState(periods[i], payload);
        anySuccess = true;
      } else if (!_views.containsKey(periods[i])) {
        newViews[periods[i]] = GrowthInsightsViewState.error(periods[i]);
      }
    }

    if (newViews.isNotEmpty) {
      _views = {..._views, ...newViews};
    }
    if (anySuccess) {
      if (accountContext != null) {
        await _saveToCache(accountContext: accountContext);
      }
      if (!_ownsScope(generation, accountContext)) return;
    }
    _hasError =
        _views.values.isNotEmpty &&
        _views.values.every((view) => view.hasError);

    _loaded = true;
    if (!_disposed) notifyListeners();
  }

  /// Changes the owner of this notifier and invalidates every result that was
  /// loaded for the previous owner. The account context is only used to
  /// select an account-owned cache partition; it is never logged or exposed
  /// in a cache key in clear text.
  void bindAccountContext(String? accountContext, {bool notify = true}) {
    final normalized = _normalizeAccountContext(accountContext);
    if (_accountContext == normalized) return;

    _accountContext = normalized;
    _scopeGeneration += 1;
    _loaded = false;
    _hasError = false;
    _views = {};
    _initializeFuture = null;
    if (notify) notifyListeners();
  }

  Future<_GrowthFetchResult> _fetchPeriod(GrowthPeriod period) async {
    try {
      return _GrowthFetchResult.success(
        await _apiService.fetchInsights(period.name),
      );
    } on Object {
      return const _GrowthFetchResult.failure();
    }
  }

  bool _ownsScope(int generation, String? accountContext) {
    return !_disposed &&
        generation == _scopeGeneration &&
        accountContext == _accountContext;
  }

  static String? _normalizeAccountContext(String? accountContext) {
    final normalized = accountContext?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }

  // ── Mapping ──────────────────────────────────────────────────────────────

  GrowthInsightsViewState _mapToViewState(
    GrowthPeriod period,
    GrowthInsightsPayload payload, {
    bool isCached = false,
  }) {
    return GrowthInsightsViewState(
      isLoading: false,
      hasError: false,
      isCached: isCached,
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

class _GrowthFetchResult {
  const _GrowthFetchResult.success(this.payload);
  const _GrowthFetchResult.failure() : payload = null;

  final GrowthInsightsPayload? payload;
}
