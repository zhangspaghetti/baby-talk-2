import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/growth/presentation/growth_insights_models.dart';
import 'package:mobile/features/growth/presentation/growth_insights_notifier.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';

void main() {
  // 2026-05-20 is a Wednesday → ISO week is Mon 05-18 .. Sun 05-24.
  DateTime fixedNow() => DateTime(2026, 5, 20, 12);

  InteractionEventPayload event({
    required String localEventId,
    required String phraseId,
    required String activityId,
    required BabyReactionType reactionType,
    required DateTime clientTimestamp,
    String spaceId = 'space_1',
  }) {
    return InteractionEventPayload(
      localEventId: localEventId,
      installationId: 'install_test',
      spaceId: spaceId,
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
      spaceId: 'space_2',
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

    test('ranks scene distribution with catalog labels', () async {
      final notifier = GrowthInsightsNotifier(
        repositoryFuture: Future.value(_FakeRepository(sampleEvents())),
        now: fixedNow,
      );
      addTearDown(notifier.dispose);

      await notifier.initialize();
      final week = notifier.viewFor(GrowthPeriod.week);

      // Week: space_1 has e1+e2 (2 events), space_2 has e3 (1 event).
      expect(week.scenes.length, 2);
      expect(week.scenes.first.spaceId, 'space_1');
      expect(week.scenes.first.eventCount, 2);
      expect(week.scenes.first.sceneTag, '喂饭');
      expect(week.scenes.last.spaceId, 'space_2');
      expect(week.scenes.last.sceneTag, '洗澡');
    });

    test('suggests an uncovered scene for week/month but not year', () async {
      final notifier = GrowthInsightsNotifier(
        repositoryFuture: Future.value(_FakeRepository(sampleEvents())),
        now: fixedNow,
      );
      addTearDown(notifier.dispose);

      await notifier.initialize();

      final week = notifier.viewFor(GrowthPeriod.week);
      final month = notifier.viewFor(GrowthPeriod.month);
      final year = notifier.viewFor(GrowthPeriod.year);

      // space_3 (睡前) is the first uncovered scene with a concrete phrase.
      expect(week.suggestion, isNotNull);
      expect(week.suggestion!.sceneLabel, '睡前');
      expect(week.suggestion!.phraseEnglish, 'Time to sleep');
      expect(week.suggestion!.spaceId, 'space_3');
      expect(week.suggestion!.activityId, 'bedtime_story');

      expect(month.suggestion, isNotNull);
      expect(month.suggestion!.spaceId, 'space_3');

      // The year view never surfaces the gentle next-step nudge.
      expect(year.suggestion, isNull);
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

  @override
  Future<PracticeActivityCatalog> getActivityCatalog() async {
    PracticeCatalogActivitySummary activity(
      String spaceId,
      String spaceTitle,
      String activityId, {
      String? nextPhraseEnglish,
      int totalEvents = 0,
    }) {
      return PracticeCatalogActivitySummary(
        spaceId: spaceId,
        spaceTitle: spaceTitle,
        activityId: activityId,
        title: '$spaceTitle 活动',
        summary: '',
        sceneTag: spaceTitle,
        coachTip: '',
        totalPhraseCount: 1,
        completedPhraseCount: 0,
        completedPhraseIds: const <String>[],
        nextPhraseId: nextPhraseEnglish == null ? null : 'next_$activityId',
        nextPhraseEnglish: nextPhraseEnglish,
        totalEvents: totalEvents,
        skippedUnknownPhraseCount: 0,
        skippedMalformedEventCount: 0,
      );
    }

    PracticeCatalogSpaceSummary space(
      String id,
      String title, {
      required int totalEvents,
      List<PracticeCatalogActivitySummary> activities =
          const <PracticeCatalogActivitySummary>[],
    }) {
      return PracticeCatalogSpaceSummary(
        spaceId: id,
        title: title,
        description: '',
        activities: activities,
        totalEvents: totalEvents,
        startedActivityCount: totalEvents > 0 ? 1 : 0,
        completedActivityCount: 0,
      );
    }

    // space_1 / space_2 already practiced; space_3 (睡前) is uncovered and
    // exposes a concrete next phrase → drives the next-step suggestion.
    final spaces = [
      space('space_1', '喂饭', totalEvents: 2),
      space('space_2', '洗澡', totalEvents: 1),
      space(
        'space_3',
        '睡前',
        totalEvents: 0,
        activities: [
          activity(
            'space_3',
            '睡前',
            'bedtime_story',
            nextPhraseEnglish: 'Time to sleep',
          ),
        ],
      ),
    ];

    return PracticeActivityCatalog(
      installationId: 'install_test',
      spaces: spaces,
      activities: [
        for (final s in spaces) ...s.activities,
      ],
      totalStoredEvents: _events.length,
      validEvents: _events.length,
      knownEvents: _events.length,
      skippedMalformedEvents: 0,
      skippedUnknownContentEvents: 0,
    );
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
