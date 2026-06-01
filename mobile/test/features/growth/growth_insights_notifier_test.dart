import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/growth/data/models/growth_insights_payload.dart';
import 'package:mobile/features/growth/data/remote/growth_insights_api_service.dart';
import 'package:mobile/features/growth/presentation/growth_insights_models.dart';
import 'package:mobile/features/growth/presentation/growth_insights_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DateTime fixedNow() => DateTime(2026, 5, 20, 12);

  GrowthInsightsPayload makePayload({
    required String period,
    int totalEvents = 10,
    int currentStreak = 3,
    int thisWeekCount = 5,
    int lastWeekCount = 3,
    List<InsightsBarBucket>? bars,
    List<InsightsScene>? scenes,
    InsightsSuggestion? suggestion,
  }) {
    return GrowthInsightsPayload(
      period: period,
      windowStart: DateTime(2026, 5, 18),
      windowEnd: DateTime(2026, 5, 20, 12),
      generatedAt: DateTime(2026, 5, 20, 12),
      stats: InsightsStats(
        totalEvents: totalEvents,
        uniquePhrases: 4,
        uniqueActivities: 3,
        imitationCount: 2,
        practicedDays: 3,
        firstEventAt: DateTime(2026, 5, 18),
        lastEventAt: DateTime(2026, 5, 20),
      ),
      streak: InsightsStreak(
        currentStreak: currentStreak,
        longestStreak: 7,
        totalDaysPracticed: 15,
        lastPracticedAt: DateTime(2026, 5, 20),
      ),
      bars: bars ??
          [
            InsightsBarBucket(bucketStart: DateTime(2026, 5, 18), count: 2),
            InsightsBarBucket(bucketStart: DateTime(2026, 5, 19), count: 3),
            InsightsBarBucket(bucketStart: DateTime(2026, 5, 20), count: 5),
          ],
      scenes: scenes ??
          const [
            InsightsScene(
              spaceId: 'space_1',
              sceneTag: '喂饭',
              eventCount: 7,
              activityCount: 2,
              percentage: 0.7,
            ),
            InsightsScene(
              spaceId: 'space_2',
              sceneTag: '洗澡',
              eventCount: 3,
              activityCount: 1,
              percentage: 0.3,
            ),
          ],
      recentActivity: InsightsRecentActivity(
        thisWeekCount: thisWeekCount,
        lastWeekCount: lastWeekCount,
      ),
      suggestion: suggestion,
    );
  }

  group('GrowthInsightsNotifier', () {
    test('returns loading view before initialize completes', () {
      final notifier = GrowthInsightsNotifier(
        apiService: _FakeApiService(),
        prefs: _FakePrefs(),
        now: fixedNow,
      );
      addTearDown(notifier.dispose);

      final view = notifier.viewFor(GrowthPeriod.week);

      expect(view.isLoading, isTrue);
      expect(view.period, GrowthPeriod.week);
      expect(notifier.isLoaded, isFalse);
    });

    test('fetches from API and maps to view state', () async {
      final api = _FakeApiService();
      final notifier = GrowthInsightsNotifier(
        apiService: api,
        prefs: _FakePrefs(),
        now: fixedNow,
      );
      addTearDown(notifier.dispose);

      await notifier.initialize();

      expect(notifier.isLoaded, isTrue);
      expect(notifier.hasError, isFalse);

      final week = notifier.viewFor(GrowthPeriod.week);
      final month = notifier.viewFor(GrowthPeriod.month);
      final year = notifier.viewFor(GrowthPeriod.year);

      expect(week.isLoading, isFalse);
      expect(week.stats.totalEvents, 10);
      expect(month.stats.totalEvents, 10);
      expect(year.stats.totalEvents, 10);

      expect(week.streak.currentStreak, 3);
      expect(week.scenes.length, 2);
      expect(week.scenes.first.sceneTag, '喂饭');

      expect(week.recentActivity, isNotNull);
      expect(week.recentActivity!.thisWeekCount, 5);
      expect(week.recentActivity!.lastWeekCount, 3);

      // Verify API was called for all 3 periods.
      expect(api.calls, ['week', 'month', 'year']);
    });

    test('fetches all 3 periods in parallel', () async {
      final api = _FakeApiService();
      final notifier = GrowthInsightsNotifier(
        apiService: api,
        prefs: _FakePrefs(),
        now: fixedNow,
      );
      addTearDown(notifier.dispose);

      await notifier.initialize();

      // All three calls should have been made.
      expect(api.calls.length, 3);
      expect(api.calls, containsAll(['week', 'month', 'year']));
    });

    test('maps suggestion from API response', () async {
      final api = _FakeApiService(
        weekPayload: makePayload(
          period: 'week',
          suggestion: const InsightsSuggestion(
            spaceId: 'space_3',
            activityId: 'bedtime_story',
            sceneLabel: '睡前',
            phraseEnglish: 'Time to sleep',
          ),
        ),
      );
      final notifier = GrowthInsightsNotifier(
        apiService: api,
        prefs: _FakePrefs(),
        now: fixedNow,
      );
      addTearDown(notifier.dispose);

      await notifier.initialize();

      final week = notifier.viewFor(GrowthPeriod.week);
      expect(week.suggestion, isNotNull);
      expect(week.suggestion!.sceneLabel, '睡前');
      expect(week.suggestion!.phraseEnglish, 'Time to sleep');
      expect(week.suggestion!.spaceId, 'space_3');
    });

    test('caches results to SharedPreferences', () async {
      final prefs = _FakePrefs();
      final api = _FakeApiService();
      final notifier = GrowthInsightsNotifier(
        apiService: api,
        prefs: prefs,
        now: fixedNow,
      );
      addTearDown(notifier.dispose);

      await notifier.initialize();

      // Verify cache keys exist.
      expect(prefs.getString('growth_insights_v1_week'), isNotNull);
      expect(prefs.getString('growth_insights_v1_month'), isNotNull);
      expect(prefs.getString('growth_insights_v1_year'), isNotNull);

      // Verify cache contains valid JSON with cachedAt.
      final raw = prefs.getString('growth_insights_v1_week')!;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      expect(json['cachedAt'], isNotNull);
      expect(json['payload'], isA<Map<String, dynamic>>());
    });

    test('loads from cache for instant paint before API responds', () async {
      final prefs = _FakePrefs();
      // Pre-populate cache.
      await prefs.setString(
        'growth_insights_v1_week',
        jsonEncode({
          'cachedAt': DateTime.now().toUtc().toIso8601String(),
          'payload': {
            'period': 'week',
            'windowStart': '2026-05-18T00:00:00.000Z',
            'windowEnd': '2026-05-20T12:00:00.000Z',
            'generatedAt': '2026-05-20T12:00:00.000Z',
            'stats': {
              'totalEvents': 42,
              'uniquePhrases': 5,
              'uniqueActivities': 3,
              'imitationCount': 2,
              'practicedDays': 4,
            },
            'streak': {
              'currentStreak': 5,
              'longestStreak': 10,
              'totalDaysPracticed': 20,
            },
            'bars': <Map<String, dynamic>>[],
            'scenes': <Map<String, dynamic>>[],
            'recentActivity': {
              'thisWeekCount': 42,
              'lastWeekCount': 10,
            },
          },
        }),
      );

      final api = _FakeApiService();
      final notifier = GrowthInsightsNotifier(
        apiService: api,
        prefs: prefs,
        now: fixedNow,
      );
      addTearDown(notifier.dispose);

      // Before initialize, should be loading.
      expect(notifier.isLoaded, isFalse);

      await notifier.initialize();

      // After initialize, API data overwrites cache.
      final week = notifier.viewFor(GrowthPeriod.week);
      expect(week.isLoading, isFalse);
      expect(week.stats.totalEvents, 10);
    });

    test('falls back to stale cache on API failure', () async {
      final prefs = _FakePrefs();
      // Pre-populate cache.
      await prefs.setString(
        'growth_insights_v1_week',
        jsonEncode({
          'cachedAt': DateTime.now().toUtc().toIso8601String(),
          'payload': {
            'period': 'week',
            'windowStart': '2026-05-18T00:00:00.000Z',
            'windowEnd': '2026-05-20T12:00:00.000Z',
            'generatedAt': '2026-05-20T12:00:00.000Z',
            'stats': {
              'totalEvents': 99,
              'uniquePhrases': 1,
              'uniqueActivities': 1,
              'imitationCount': 0,
              'practicedDays': 1,
            },
            'streak': {
              'currentStreak': 1,
              'longestStreak': 1,
              'totalDaysPracticed': 1,
            },
            'bars': <Map<String, dynamic>>[],
            'scenes': <Map<String, dynamic>>[],
            'recentActivity': {
              'thisWeekCount': 99,
              'lastWeekCount': 0,
            },
          },
        }),
      );

      final api = _FakeApiService(throwOnFetch: true);
      final notifier = GrowthInsightsNotifier(
        apiService: api,
        prefs: prefs,
        now: fixedNow,
      );
      addTearDown(notifier.dispose);

      await notifier.initialize();

      expect(notifier.isLoaded, isTrue);
      expect(notifier.hasError, isFalse); // stale cache available
      final week = notifier.viewFor(GrowthPeriod.week);
      expect(week.stats.totalEvents, 99); // from cache
    });

    test('shows error when API fails and no cache exists', () async {
      final api = _FakeApiService(throwOnFetch: true);
      final notifier = GrowthInsightsNotifier(
        apiService: api,
        prefs: _FakePrefs(),
        now: fixedNow,
      );
      addTearDown(notifier.dispose);

      await notifier.initialize();

      expect(notifier.isLoaded, isTrue);
      expect(notifier.hasError, isTrue);
      final week = notifier.viewFor(GrowthPeriod.week);
      expect(week.hasError, isTrue);
    });

    test('windowStart and windowEnd are mapped from payload', () async {
      final notifier = GrowthInsightsNotifier(
        apiService: _FakeApiService(),
        prefs: _FakePrefs(),
        now: fixedNow,
      );
      addTearDown(notifier.dispose);

      await notifier.initialize();

      final week = notifier.viewFor(GrowthPeriod.week);
      expect(week.windowStart, DateTime(2026, 5, 18));
      expect(week.windowEnd, DateTime(2026, 5, 20, 12));
    });

    test('bar labels are generated from bucketStart dates', () async {
      final notifier = GrowthInsightsNotifier(
        apiService: _FakeApiService(),
        prefs: _FakePrefs(),
        now: fixedNow,
      );
      addTearDown(notifier.dispose);

      await notifier.initialize();

      final week = notifier.viewFor(GrowthPeriod.week);
      // Week bars should have Chinese weekday labels.
      // 2026-05-18 is a Monday, weekday=1 → _weekdayLabels[0] = '一'
      expect(week.bars.length, 3);
      expect(week.bars[0].label, '一');

      final year = notifier.viewFor(GrowthPeriod.year);
      // Year bars should have month numbers.
      expect(year.bars.length, 3);
      expect(year.bars[0].label, '5'); // May
    });
  });
}

class _FakeApiService implements GrowthInsightsApiService {
  _FakeApiService({
    this.throwOnFetch = false,
    GrowthInsightsPayload? weekPayload,
    GrowthInsightsPayload? monthPayload,
    GrowthInsightsPayload? yearPayload,
  })  : weekPayload = weekPayload ?? _defaultPayload('week'),
        monthPayload = monthPayload ?? _defaultPayload('month'),
        yearPayload = yearPayload ?? _defaultPayload('year');

  final bool throwOnFetch;
  final GrowthInsightsPayload weekPayload;
  final GrowthInsightsPayload monthPayload;
  final GrowthInsightsPayload yearPayload;
  final List<String> calls = [];

  @override
  String get appVersion => '1.0.0';

  static GrowthInsightsPayload _defaultPayload(String period) {
    return GrowthInsightsPayload(
      period: period,
      windowStart: DateTime(2026, 5, 18),
      windowEnd: DateTime(2026, 5, 20, 12),
      generatedAt: DateTime(2026, 5, 20, 12),
      stats: InsightsStats(
        totalEvents: 10,
        uniquePhrases: 4,
        uniqueActivities: 3,
        imitationCount: 2,
        practicedDays: 3,
        firstEventAt: DateTime(2026, 5, 18),
        lastEventAt: DateTime(2026, 5, 20),
      ),
      streak: InsightsStreak(
        currentStreak: 3,
        longestStreak: 7,
        totalDaysPracticed: 15,
        lastPracticedAt: DateTime(2026, 5, 20),
      ),
      bars: [
        InsightsBarBucket(bucketStart: DateTime(2026, 5, 18), count: 2),
        InsightsBarBucket(bucketStart: DateTime(2026, 5, 19), count: 3),
        InsightsBarBucket(bucketStart: DateTime(2026, 5, 20), count: 5),
      ],
      scenes: [
        InsightsScene(
          spaceId: 'space_1',
          sceneTag: '喂饭',
          eventCount: 7,
          activityCount: 2,
          percentage: 0.7,
        ),
        InsightsScene(
          spaceId: 'space_2',
          sceneTag: '洗澡',
          eventCount: 3,
          activityCount: 1,
          percentage: 0.3,
        ),
      ],
      recentActivity: InsightsRecentActivity(
        thisWeekCount: 5,
        lastWeekCount: 3,
      ),
    );
  }

  @override
  Future<GrowthInsightsPayload> fetchInsights(String period) async {
    calls.add(period);
    if (throwOnFetch) {
      throw const GrowthInsightsApiException.network(message: 'offline');
    }
    switch (period) {
      case 'week':
        return weekPayload;
      case 'month':
        return monthPayload;
      case 'year':
        return yearPayload;
      default:
        return _defaultPayload(period);
    }
  }

  @override
  void close() {}
}

/// Minimal in-memory SharedPreferences fake for unit tests.
class _FakePrefs implements SharedPreferences {
  final Map<String, Object?> _store = {};

  @override
  Object? get(String key) => _store[key];

  @override
  Future<bool> setString(String key, String value) async {
    _store[key] = value;
    return true;
  }

  @override
  String? getString(String key) => _store[key] as String?;

  @override
  Set<String> getKeys() => _store.keys.toSet();

  @override
  Future<bool> commit() async => true;

  // Unused SharedPreferences members.
  @override
  Future<bool> setBool(String key, bool value) async => false;
  @override
  bool? getBool(String key) => null;
  @override
  Future<bool> setInt(String key, int value) async => false;
  @override
  int? getInt(String key) => null;
  @override
  Future<bool> setDouble(String key, double value) async => false;
  @override
  double? getDouble(String key) => null;
  @override
  Future<bool> setStringList(String key, List<String> value) async => false;
  @override
  List<String>? getStringList(String key) => null;
  @override
  Future<bool> remove(String key) async => false;
  @override
  Future<bool> clear() async => false;
  @override
  Future<void> reload() async {}
  @override
  bool containsKey(String key) => _store.containsKey(key);
}
