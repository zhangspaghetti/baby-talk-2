import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/growth/data/models/growth_insights_payload.dart';
import 'package:mobile/features/growth/data/remote/growth_insights_api_service.dart';
import 'package:mobile/features/growth/presentation/growth_insights_models.dart';
import 'package:mobile/features/growth/presentation/growth_insights_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses remote API data when fetch succeeds', () async {
    final api = _FakeApiService(
      weekPayload: _makePayload(
        period: 'week',
        totalEvents: 99,
        uniquePhrases: 10,
        uniqueActivities: 7,
      ),
    );

    final notifier = GrowthInsightsNotifier(
      apiService: api,
      prefs: _FakePrefs(),
    );
    addTearDown(notifier.dispose);

    await notifier.initialize();

    final week = notifier.viewFor(GrowthPeriod.week);
    expect(week.stats.totalEvents, 99);
    expect(week.stats.uniquePhrases, 10);
    expect(week.stats.uniqueActivities, 7);
    expect(api.calls, ['week', 'month', 'year']);
  });

  test('falls back to stale cache when remote fetch throws', () async {
    final prefs = _FakePrefs();
    // Pre-populate cache with stale data.
    await prefs.setString(
      'growth_insights_reaction_v2_week',
      _cacheEntry(totalEvents: 42, uniquePhrases: 5, uniqueActivities: 3),
    );

    final api = _FakeApiService(throwOnFetch: true);
    final notifier = GrowthInsightsNotifier(apiService: api, prefs: prefs);
    addTearDown(notifier.dispose);

    await notifier.initialize();

    final week = notifier.viewFor(GrowthPeriod.week);
    expect(week.stats.totalEvents, 42); // from cache
    expect(week.isCached, isTrue);
    expect(notifier.hasError, isFalse); // stale cache available
  });

  test('shows error when remote fails and no cache exists', () async {
    final api = _FakeApiService(throwOnFetch: true);
    final notifier = GrowthInsightsNotifier(
      apiService: api,
      prefs: _FakePrefs(),
    );
    addTearDown(notifier.dispose);

    await notifier.initialize();

    expect(notifier.hasError, isTrue);
    final week = notifier.viewFor(GrowthPeriod.week);
    expect(week.hasError, isTrue);
  });

  test('keeps a failed period as an error instead of zero-value data', () async {
    final api = _FakeApiService(failedPeriods: {'month'});
    final notifier = GrowthInsightsNotifier(
      apiService: api,
      prefs: _FakePrefs(),
    );
    addTearDown(notifier.dispose);

    await notifier.initialize();

    expect(notifier.viewFor(GrowthPeriod.week).hasError, isFalse);
    expect(notifier.viewFor(GrowthPeriod.month).hasError, isTrue);
    expect(notifier.viewFor(GrowthPeriod.month).stats.totalEvents, 0);
    expect(notifier.viewFor(GrowthPeriod.month).isEmpty, isFalse);
  });
}

GrowthInsightsPayload _makePayload({
  required String period,
  int totalEvents = 10,
  int uniquePhrases = 4,
  int uniqueActivities = 3,
}) {
  return GrowthInsightsPayload(
    period: period,
    windowStart: DateTime(2026, 5, 18),
    windowEnd: DateTime(2026, 5, 20, 12),
    generatedAt: DateTime(2026, 5, 20, 12),
    stats: InsightsStats(
      totalEvents: totalEvents,
      uniquePhrases: uniquePhrases,
      uniqueActivities: uniqueActivities,
      cooperatingCount: 2,
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
    scenes: const [
      InsightsScene(
        spaceId: 'space_1',
        sceneTag: '喂饭',
        eventCount: 7,
        activityCount: 2,
        percentage: 0.7,
      ),
    ],
    recentActivity: const InsightsRecentActivity(
      thisWeekCount: 5,
      lastWeekCount: 3,
    ),
  );
}

String _cacheEntry({
  required int totalEvents,
  required int uniquePhrases,
  required int uniqueActivities,
}) {
  return '''{
    "cachedAt": "${DateTime.now().toUtc().toIso8601String()}",
    "payload": {
      "period": "week",
      "windowStart": "2026-05-18T00:00:00.000Z",
      "windowEnd": "2026-05-20T12:00:00.000Z",
      "generatedAt": "2026-05-20T12:00:00.000Z",
      "stats": {
        "totalEvents": $totalEvents,
        "uniquePhrases": $uniquePhrases,
        "uniqueActivities": $uniqueActivities,
        "cooperatingCount": 0,
        "practicedDays": 1
      },
      "streak": {
        "currentStreak": 1,
        "longestStreak": 1,
        "totalDaysPracticed": 1
      },
      "bars": [],
      "scenes": [],
      "recentActivity": {
        "thisWeekCount": $totalEvents,
        "lastWeekCount": 0
      }
    }
  }''';
}

class _FakeApiService implements GrowthInsightsApiService {
  _FakeApiService({
    this.throwOnFetch = false,
    this.failedPeriods = const <String>{},
    GrowthInsightsPayload? weekPayload,
  }) : weekPayload = weekPayload ?? _makePayload(period: 'week');

  final bool throwOnFetch;
  final Set<String> failedPeriods;
  final GrowthInsightsPayload weekPayload;
  final List<String> calls = [];

  @override
  String get appVersion => '1.0.0';

  @override
  Future<GrowthInsightsPayload> fetchInsights(String period) async {
    calls.add(period);
    if (throwOnFetch || failedPeriods.contains(period)) {
      throw const GrowthInsightsApiException.network(message: 'offline');
    }
    if (period == 'week') return weekPayload;
    return _makePayload(period: period);
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
