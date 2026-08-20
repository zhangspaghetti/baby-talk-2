import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository_contract.dart';
import 'package:mobile/features/account/presentation/account_notifier.dart';
import 'package:mobile/features/growth/data/models/growth_insights_payload.dart';
import 'package:mobile/features/growth/data/remote/growth_insights_api_service.dart';
import 'package:mobile/features/growth/presentation/growth_insights_models.dart';
import 'package:mobile/features/growth/presentation/growth_insights_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 8, 20, 12);

  test('keeps Growth cache and in-memory state isolated per account', () async {
    final prefs = _FakePrefs();
    final api = _FakeApiService(payload: _payload(totalEvents: 11));
    final notifier = GrowthInsightsNotifier(
      apiService: api,
      prefs: prefs,
      accountContext: 'account-a',
      now: () => now,
    );
    addTearDown(notifier.dispose);

    await notifier.initialize();
    expect(notifier.viewFor(GrowthPeriod.week).stats.totalEvents, 11);

    api.payload = _payload(totalEvents: 22);
    notifier.bindAccountContext('account-b');
    expect(notifier.viewFor(GrowthPeriod.week).isLoading, isTrue);
    await notifier.initialize();
    expect(notifier.viewFor(GrowthPeriod.week).stats.totalEvents, 22);

    api.throwOnFetch = true;
    notifier.bindAccountContext('account-a');
    await notifier.initialize();
    expect(notifier.viewFor(GrowthPeriod.week).stats.totalEvents, 11);
    expect(notifier.viewFor(GrowthPeriod.week).isCached, isTrue);
    expect(
      prefs.getKeys().where(
        (key) => key.startsWith('growth_insights_reaction_v2_'),
      ),
      hasLength(6),
    );
    expect(prefs.getKeys().any((key) => key.contains('account-a')), isFalse);
    expect(prefs.getKeys().any((key) => key.contains('account-b')), isFalse);
  });

  test('does not reuse anonymous failure after login', () async {
    final api = _FakeApiService(throwOnFetch: true);
    final notifier = GrowthInsightsNotifier(
      apiService: api,
      prefs: _FakePrefs(),
      now: () => now,
    );
    addTearDown(notifier.dispose);

    await notifier.initialize();
    expect(notifier.hasError, isTrue);
    expect(notifier.viewFor(GrowthPeriod.week).hasError, isTrue);

    api.throwOnFetch = false;
    api.payload = _payload(totalEvents: 31);
    notifier.bindAccountContext('account-a');
    await notifier.initialize();

    expect(notifier.hasError, isFalse);
    expect(notifier.viewFor(GrowthPeriod.week).stats.totalEvents, 31);
  });

  test('a new notifier can read only the matching account cache', () async {
    final prefs = _FakePrefs();
    final writer = GrowthInsightsNotifier(
      apiService: _FakeApiService(payload: _payload(totalEvents: 41)),
      prefs: prefs,
      accountContext: 'account-a',
      now: () => now,
    );
    addTearDown(writer.dispose);
    await writer.initialize();

    final reader = GrowthInsightsNotifier(
      apiService: _FakeApiService(throwOnFetch: true),
      prefs: prefs,
      accountContext: 'account-b',
      now: () => now,
    );
    addTearDown(reader.dispose);
    await reader.initialize();
    expect(reader.viewFor(GrowthPeriod.week).hasError, isTrue);

    final matchingReader = GrowthInsightsNotifier(
      apiService: _FakeApiService(throwOnFetch: true),
      prefs: prefs,
      accountContext: 'account-a',
      now: () => now,
    );
    addTearDown(matchingReader.dispose);
    await matchingReader.initialize();
    expect(matchingReader.viewFor(GrowthPeriod.week).stats.totalEvents, 41);
    expect(matchingReader.viewFor(GrowthPeriod.week).isCached, isTrue);
  });

  test(
    'provider refreshes the same notifier when account scope changes',
    () async {
      final account = _StubAccountNotifier('account-a');
      final api = _FakeApiService(payload: _payload(totalEvents: 51));
      final container = ProviderContainer(
        overrides: [
          accountNotifierProvider.overrideWith((ref) => account),
          growthInsightsApiServiceProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(growthInsightsNotifierProvider);
      await notifier.initialize();
      expect(notifier.viewFor(GrowthPeriod.week).stats.totalEvents, 51);

      api.payload = _payload(totalEvents: 61);
      account.setScope('account-b');
      await Future<void>.delayed(Duration.zero);

      final switchedNotifier = container.read(growthInsightsNotifierProvider);
      expect(switchedNotifier.accountContext, 'account-b');
      await switchedNotifier.initialize();
      expect(switchedNotifier.viewFor(GrowthPeriod.week).stats.totalEvents, 61);
    },
  );
}

GrowthInsightsPayload _payload({required int totalEvents, String? period}) {
  return GrowthInsightsPayload(
    period: period ?? 'week',
    windowStart: DateTime(2026, 8, 17),
    windowEnd: DateTime(2026, 8, 20, 12),
    generatedAt: DateTime(2026, 8, 20, 12),
    stats: InsightsStats(
      totalEvents: totalEvents,
      uniquePhrases: totalEvents,
      uniqueActivities: 1,
      cooperatingCount: 1,
      practicedDays: 1,
      firstEventAt: DateTime(2026, 8, 17),
      lastEventAt: DateTime(2026, 8, 20),
    ),
    streak: const InsightsStreak(
      currentStreak: 1,
      longestStreak: 1,
      totalDaysPracticed: 1,
      lastPracticedAt: null,
    ),
    bars: const [],
    scenes: const [],
    recentActivity: const InsightsRecentActivity(
      thisWeekCount: 1,
      lastWeekCount: 0,
    ),
  );
}

class _FakeApiService implements GrowthInsightsApiService {
  _FakeApiService({this.throwOnFetch = false, GrowthInsightsPayload? payload})
    : payload = payload ?? _payload(totalEvents: 1);

  bool throwOnFetch;
  GrowthInsightsPayload payload;

  @override
  String get appVersion => '1.0.0';

  @override
  Future<GrowthInsightsPayload> fetchInsights(String period) async {
    if (throwOnFetch) {
      throw const GrowthInsightsApiException.network(message: 'offline');
    }
    return payload.period == period
        ? payload
        : _payload(totalEvents: payload.stats.totalEvents, period: period);
  }

  @override
  void close() {}
}

class _FakePrefs implements SharedPreferences {
  final Map<String, Object?> _store = <String, Object?>{};

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

class _StubAccountNotifier extends AccountNotifier {
  _StubAccountNotifier(this._scope)
    : super(repository: _StubAccountRepository());

  String? _scope;

  @override
  String? get stableAccountContext => _scope;

  void setScope(String? scope) {
    _scope = scope;
    notifyListeners();
  }
}

class _StubAccountRepository implements AccountRepositoryContract {
  @override
  Future<AccountLocalSnapshot> loadSnapshot() async =>
      AccountLocalSnapshot.localOnly;

  @override
  Future<AccountLocalSnapshot> signIn({
    required String phoneNumber,
    required String verificationCode,
  }) async => AccountLocalSnapshot.localOnly;

  @override
  Future<AccountLocalSnapshot> refreshRuntimeState({
    required AccountRuntimeTrigger trigger,
    AccountLocalSnapshot? seedSnapshot,
    bool forceBootstrap = false,
  }) async => AccountLocalSnapshot.localOnly;

  @override
  Future<AccountLocalSnapshot> clearPlaceholderSession({
    bool revertToLocalOnly = false,
  }) async => AccountLocalSnapshot.localOnly;

  @override
  Future<AccountLocalSnapshot> revokeConsent({
    String reason = 'user_requested',
  }) async => AccountLocalSnapshot.localOnly;

  @override
  Future<AccountLocalSnapshot> deleteAccount({
    String reason = 'forget_me',
  }) async => AccountLocalSnapshot.localOnly;

  @override
  Future<void> close() async {}
}
