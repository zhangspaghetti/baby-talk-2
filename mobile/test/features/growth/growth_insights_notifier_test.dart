import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/growth/presentation/growth_insights_models.dart';
import 'package:mobile/features/growth/presentation/growth_insights_notifier.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

void main() {
  // 2026-05-20 is a Wednesday → ISO week is Mon 05-18 .. Sun 05-24.
  DateTime fixedNow() => DateTime(2026, 5, 20, 12);

  InteractionEventPayload event({
    required String localEventId,
    required String phraseId,
    required String activityId,
    required BabyReactionType reactionType,
    required DateTime clientTimestamp,
  }) {
    return InteractionEventPayload(
      localEventId: localEventId,
      installationId: 'install_test',
      spaceId: 'space_1',
      activityId: activityId,
      phraseId: phraseId,
      reactionType: reactionType,
      clientTimestamp: clientTimestamp,
    );
  }

  // 3 events this week (05-19, 05-20 x2), 1 earlier this month (05-01),
  // 1 earlier this year (03-15), 1 previous year (2025-12-01).
  // → week total = 3, month total = 4, year total = 5, all = 6.
  List<InteractionEventPayload> sampleEvents() => [
    event(
      localEventId: 'e1',
      phraseId: 'p1',
      activityId: 'a1',
      reactionType: BabyReactionType.engaged,
      clientTimestamp: DateTime(2026, 5, 20, 9),
    ),
    event(
      localEventId: 'e2',
      phraseId: 'p2',
      activityId: 'a1',
      reactionType: BabyReactionType.imitated,
      clientTimestamp: DateTime(2026, 5, 20, 10),
    ),
    event(
      localEventId: 'e3',
      phraseId: 'p1',
      activityId: 'a2',
      reactionType: BabyReactionType.calm,
      clientTimestamp: DateTime(2026, 5, 19, 9),
    ),
    event(
      localEventId: 'e4',
      phraseId: 'p3',
      activityId: 'a2',
      reactionType: BabyReactionType.engaged,
      clientTimestamp: DateTime(2026, 5, 1, 9),
    ),
    event(
      localEventId: 'e5',
      phraseId: 'p4',
      activityId: 'a3',
      reactionType: BabyReactionType.engaged,
      clientTimestamp: DateTime(2026, 3, 15, 9),
    ),
    event(
      localEventId: 'e6',
      phraseId: 'p5',
      activityId: 'a3',
      reactionType: BabyReactionType.engaged,
      clientTimestamp: DateTime(2025, 12, 1, 9),
    ),
  ];

  int barSum(List<GrowthBarBucket> bars) =>
      bars.fold(0, (sum, bucket) => sum + bucket.count);

  group('GrowthInsightsNotifier', () {
    test('returns loading view before initialize completes', () {
      final notifier = GrowthInsightsNotifier(
        repositoryFuture: Completer<PracticeRepository>().future,
        now: fixedNow,
      );
      addTearDown(notifier.dispose);

      final view = notifier.viewFor(GrowthPeriod.week);

      expect(view.isLoading, isTrue);
      expect(view.period, GrowthPeriod.week);
      expect(notifier.isLoaded, isFalse);
    });

    test('aggregates week/month/year totals from event history', () async {
      final notifier = GrowthInsightsNotifier(
        repositoryFuture: Future.value(_FakeRepository(sampleEvents())),
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
      expect(week.stats.totalEvents, 3);
      expect(month.stats.totalEvents, 4);
      expect(year.stats.totalEvents, 5);

      // Bar buckets must sum to the same window total (shared boundaries).
      expect(barSum(week.bars), 3);
      expect(barSum(month.bars), 4);
      expect(barSum(year.bars), 5);

      // Bucket cardinality: 7 days, monthly weeks, 12 months.
      expect(week.bars.length, 7);
      expect(year.bars.length, 12);
    });

    test('tracks imitation count and streak for recent events', () async {
      final notifier = GrowthInsightsNotifier(
        repositoryFuture: Future.value(_FakeRepository(sampleEvents())),
        now: fixedNow,
      );
      addTearDown(notifier.dispose);

      await notifier.initialize();
      final week = notifier.viewFor(GrowthPeriod.week);

      expect(week.stats.imitationCount, 1);
      expect(week.isEmpty, isFalse);
      expect(week.streak.currentStreak, greaterThanOrEqualTo(2));
    });

    test('exposes empty view when there is no history', () async {
      final notifier = GrowthInsightsNotifier(
        repositoryFuture: Future.value(_FakeRepository(const [])),
        now: fixedNow,
      );
      addTearDown(notifier.dispose);

      await notifier.initialize();
      final week = notifier.viewFor(GrowthPeriod.week);

      expect(week.isEmpty, isTrue);
      expect(week.stats.totalEvents, 0);
      expect(barSum(week.bars), 0);
    });

    test('flags error state when repository throws', () async {
      final notifier = GrowthInsightsNotifier(
        repositoryFuture: Future.value(_ThrowingRepository()),
        now: fixedNow,
      );
      addTearDown(notifier.dispose);

      await notifier.initialize();
      final week = notifier.viewFor(GrowthPeriod.week);

      expect(notifier.hasError, isTrue);
      expect(week.hasError, isTrue);
      expect(week.stats.totalEvents, 0);
    });
  });
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
}

class _ThrowingRepository extends Fake implements PracticeRepository {
  @override
  Future<List<InteractionEventPayload>> listEventHistory({
    String? spaceId,
    String? activityId,
  }) async {
    throw StateError('boom');
  }
}
