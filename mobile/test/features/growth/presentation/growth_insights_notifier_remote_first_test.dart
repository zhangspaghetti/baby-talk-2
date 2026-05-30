import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/growth/data/remote/growth_summary_api_service.dart';
import 'package:mobile/features/growth/domain/services/growth_stats_service.dart';
import 'package:mobile/features/growth/presentation/growth_insights_models.dart';
import 'package:mobile/features/growth/presentation/growth_insights_notifier.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';

void main() {
  DateTime fixedNow() => DateTime(2026, 5, 20, 12);

  InteractionEventPayload event({
    required String id,
    required DateTime clientTimestamp,
  }) {
    return InteractionEventPayload(
      localEventId: id,
      installationId: 'install_test',
      spaceId: 'space_1',
      activityId: 'a1',
      phraseId: 'p1',
      reactionType: BabyReactionType.engaged,
      clientTimestamp: clientTimestamp,
    );
  }

  test('uses remote summary data when remote load succeeds', () async {
    final statsService = _StubGrowthStatsService(
      weekResult: const PeriodStats(
        totalEvents: 99,
        uniquePhrases: 10,
        uniqueActivities: 7,
        imitationCount: 5,
        firstEventAt: null,
        lastEventAt: null,
        practicedDays: 6,
      ),
      monthResult: const PeriodStats(
        totalEvents: 88,
        uniquePhrases: 9,
        uniqueActivities: 6,
        imitationCount: 4,
        firstEventAt: null,
        lastEventAt: null,
        practicedDays: 5,
      ),
      yearResult: const PeriodStats(
        totalEvents: 77,
        uniquePhrases: 8,
        uniqueActivities: 5,
        imitationCount: 3,
        firstEventAt: null,
        lastEventAt: null,
        practicedDays: 4,
      ),
    );

    final notifier = GrowthInsightsNotifier(
      repositoryFuture: Future.value(
        _FakeRepository([
          event(id: 'e1', clientTimestamp: DateTime(2026, 5, 20, 9)),
          event(id: 'e2', clientTimestamp: DateTime(2026, 5, 19, 9)),
        ]),
      ),
      statsService: statsService,
      now: fixedNow,
    );
    addTearDown(notifier.dispose);

    await notifier.initialize();

    final week = notifier.viewFor(GrowthPeriod.week);
    expect(week.stats.totalEvents, 99);
    expect(statsService.loadedPeriods, [
      GrowthSummaryPeriod.week,
      GrowthSummaryPeriod.month,
      GrowthSummaryPeriod.year,
    ]);
  });

  test('falls back to local stats when remote load throws', () async {
    final statsService = _StubGrowthStatsService(throwOnLoad: true);
    final notifier = GrowthInsightsNotifier(
      repositoryFuture: Future.value(
        _FakeRepository([
          event(id: 'e1', clientTimestamp: DateTime(2026, 5, 20, 9)),
          event(id: 'e2', clientTimestamp: DateTime(2026, 5, 20, 10)),
        ]),
      ),
      statsService: statsService,
      now: fixedNow,
    );
    addTearDown(notifier.dispose);

    await notifier.initialize();

    final week = notifier.viewFor(GrowthPeriod.week);
    expect(week.stats.totalEvents, 2);
    expect(week.stats.uniquePhrases, 1);
    expect(statsService.loadedPeriods, [
      GrowthSummaryPeriod.week,
      GrowthSummaryPeriod.month,
      GrowthSummaryPeriod.year,
    ]);
  });
}

class _StubGrowthStatsService extends GrowthStatsService {
  _StubGrowthStatsService({
    this.throwOnLoad = false,
    this.weekResult,
    this.monthResult,
    this.yearResult,
  });

  final bool throwOnLoad;
  final PeriodStats? weekResult;
  final PeriodStats? monthResult;
  final PeriodStats? yearResult;
  final List<GrowthSummaryPeriod> loadedPeriods = <GrowthSummaryPeriod>[];

  @override
  Future<GrowthSummaryResult> loadSummary({
    required GrowthSummaryPeriod period,
  }) async {
    loadedPeriods.add(period);
    if (throwOnLoad) {
      throw StateError('remote failed');
    }

    PeriodStats pick() {
      switch (period) {
        case GrowthSummaryPeriod.week:
          return weekResult!;
        case GrowthSummaryPeriod.month:
          return monthResult!;
        case GrowthSummaryPeriod.year:
          return yearResult!;
      }
    }

    return GrowthSummaryResult(
      source: GrowthSummarySource.remote,
      stats: pick(),
    );
  }
}

class _FakeRepository extends Fake implements PracticeRepository {
  _FakeRepository(this._events);

  final List<InteractionEventPayload> _events;

  @override
  Future<List<InteractionEventPayload>> listEventHistory({
    String? spaceId,
    String? activityId,
  }) async {
    return _events;
  }

  @override
  Future<PracticeActivityCatalog> getActivityCatalog() async {
    final space = PracticeCatalogSpaceSummary(
      spaceId: 'space_1',
      title: 'Scene 1',
      description: '',
      activities: const <PracticeCatalogActivitySummary>[],
      totalEvents: _events.length,
      startedActivityCount: 1,
      completedActivityCount: 0,
    );

    return PracticeActivityCatalog(
      installationId: 'install_test',
      spaces: [space],
      activities: const <PracticeCatalogActivitySummary>[],
      totalStoredEvents: _events.length,
      validEvents: _events.length,
      knownEvents: _events.length,
      skippedMalformedEvents: 0,
      skippedUnknownContentEvents: 0,
    );
  }
}
