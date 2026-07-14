import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/growth/domain/services/growth_stats_service.dart';

void main() {
  group('GrowthStatsService', () {
    const service = GrowthStatsService();

    PracticeEventRecord _event({
      required String eventKey,
      required String spaceId,
      required String activityId,
      required String phraseId,
      String reactionType = 'other',
      required DateTime clientTimestamp,
    }) {
      return PracticeEventRecord(
        eventKey: eventKey,
        spaceId: spaceId,
        activityId: activityId,
        phraseId: phraseId,
        reactionType: reactionType,
        clientTimestamp: clientTimestamp,
      );
    }

    // -------------------------------------------------------------------------
    // Scene distribution aggregation
    // -------------------------------------------------------------------------

    group('aggregateSceneDistribution', () {
      test('empty events returns empty list', () {
        final result = service.aggregateSceneDistribution(
          events: [],
          spaceLabels: {},
        );

        expect(result, isEmpty);
      });

      test('aggregates events by space', () {
        final events = [
          _event(
            eventKey: 'e1',
            spaceId: 'daily_care',
            activityId: 'bath',
            phraseId: 'p1',
            clientTimestamp: DateTime(2026, 5, 29, 10, 0),
          ),
          _event(
            eventKey: 'e2',
            spaceId: 'daily_care',
            activityId: 'bath',
            phraseId: 'p2',
            clientTimestamp: DateTime(2026, 5, 29, 10, 1),
          ),
          _event(
            eventKey: 'e3',
            spaceId: 'play',
            activityId: 'toy',
            phraseId: 'p3',
            clientTimestamp: DateTime(2026, 5, 29, 10, 2),
          ),
        ];

        final result = service.aggregateSceneDistribution(
          events: events,
          spaceLabels: {'daily_care': '日常护理', 'play': '游戏'},
        );

        expect(result, hasLength(2));
        // Sorted by event count descending.
        expect(result[0].spaceId, 'daily_care');
        expect(result[0].eventCount, 2);
        expect(result[0].activityCount, 1);
        expect(result[0].percentage, closeTo(2 / 3, 0.01));
        expect(result[0].sceneTag, '日常护理');

        expect(result[1].spaceId, 'play');
        expect(result[1].eventCount, 1);
        expect(result[1].percentage, closeTo(1 / 3, 0.01));
      });

      test('unknown space uses spaceId as label', () {
        final events = [
          _event(
            eventKey: 'e1',
            spaceId: 'unknown_space',
            activityId: 'a1',
            phraseId: 'p1',
            clientTimestamp: DateTime(2026, 5, 29),
          ),
        ];

        final result = service.aggregateSceneDistribution(
          events: events,
          spaceLabels: {},
        );

        expect(result.first.sceneTag, 'unknown_space');
      });
    });

    // -------------------------------------------------------------------------
    // Streak calculation
    // -------------------------------------------------------------------------

    group('calculateStreak', () {
      test('empty events returns zero streak', () {
        final result = service.calculateStreak(
          eventTimes: [],
          now: DateTime(2026, 5, 29),
        );

        expect(result.currentStreak, 0);
        expect(result.longestStreak, 0);
        expect(result.totalDaysPracticed, 0);
        expect(result.lastPracticedAt, isNull);
      });

      test('single day gives streak of 1', () {
        final result = service.calculateStreak(
          eventTimes: [DateTime(2026, 5, 29, 10, 0)],
          now: DateTime(2026, 5, 29, 20, 0),
        );

        expect(result.currentStreak, 1);
        expect(result.longestStreak, 1);
        expect(result.totalDaysPracticed, 1);
      });

      test('consecutive days calculate correct streak', () {
        final result = service.calculateStreak(
          eventTimes: [
            DateTime(2026, 5, 27, 10, 0),
            DateTime(2026, 5, 28, 10, 0),
            DateTime(2026, 5, 29, 10, 0),
          ],
          now: DateTime(2026, 5, 29, 20, 0),
        );

        expect(result.currentStreak, 3);
        expect(result.longestStreak, 3);
        expect(result.totalDaysPracticed, 3);
      });

      test('gap in days breaks current streak', () {
        final result = service.calculateStreak(
          eventTimes: [
            DateTime(2026, 5, 25, 10, 0),
            DateTime(2026, 5, 26, 10, 0),
            // gap: 5/27, 5/28 missing
            DateTime(2026, 5, 29, 10, 0),
          ],
          now: DateTime(2026, 5, 29, 20, 0),
        );

        // Current streak is 1 (only today/yesterday).
        expect(result.currentStreak, 1);
        // Longest streak is 2 (5/25-5/26).
        expect(result.longestStreak, 2);
        expect(result.totalDaysPracticed, 3);
      });

      test('multiple events on same day count as one streak day', () {
        final result = service.calculateStreak(
          eventTimes: [
            DateTime(2026, 5, 29, 8, 0),
            DateTime(2026, 5, 29, 10, 0),
            DateTime(2026, 5, 29, 14, 0),
          ],
          now: DateTime(2026, 5, 29, 20, 0),
        );

        expect(result.currentStreak, 1);
        expect(result.totalDaysPracticed, 1);
      });

      test('last practice day determines current streak', () {
        // Practiced 5/27-5/29, but last event is 5/28. Today is 5/29.
        // Gap from last practice (5/28) to today (5/29) = 1 day, so streak alive.
        final result = service.calculateStreak(
          eventTimes: [
            DateTime(2026, 5, 27, 10, 0),
            DateTime(2026, 5, 28, 10, 0),
          ],
          now: DateTime(2026, 5, 29, 20, 0),
        );

        expect(result.currentStreak, 2);
        expect(result.longestStreak, 2);
      });

      test('last practice more than 1 day ago breaks streak', () {
        final result = service.calculateStreak(
          eventTimes: [
            DateTime(2026, 5, 26, 10, 0),
            DateTime(2026, 5, 27, 10, 0),
          ],
          now: DateTime(2026, 5, 29, 20, 0),
        );

        // Gap from 5/27 to 5/29 is 2 days > 1.
        expect(result.currentStreak, 0);
        expect(result.longestStreak, 2);
      });
    });

    // -------------------------------------------------------------------------
    // Stats aggregation by time period
    // -------------------------------------------------------------------------

    group('aggregateByPeriod', () {
      test('empty events returns zero stats', () {
        final result = service.aggregateByPeriod(
          events: [],
          windowStart: DateTime(2026, 5, 1),
          windowEnd: DateTime(2026, 5, 31),
        );

        expect(result.totalEvents, 0);
        expect(result.uniquePhrases, 0);
        expect(result.uniqueActivities, 0);
        expect(result.cooperatingCount, 0);
        expect(result.firstEventAt, isNull);
        expect(result.lastEventAt, isNull);
        expect(result.practicedDays, 0);
      });

      test('filters events within time window', () {
        final events = [
          _event(
            eventKey: 'e1',
            spaceId: 's1',
            activityId: 'a1',
            phraseId: 'p1',
            clientTimestamp: DateTime(2026, 5, 15, 10, 0),
          ),
          _event(
            eventKey: 'e2',
            spaceId: 's1',
            activityId: 'a1',
            phraseId: 'p2',
            clientTimestamp: DateTime(2026, 5, 20, 10, 0),
          ),
          _event(
            eventKey: 'e3',
            spaceId: 's1',
            activityId: 'a2',
            phraseId: 'p3',
            reactionType: 'cooperating',
            clientTimestamp: DateTime(2026, 5, 25, 10, 0),
          ),
          // Outside window.
          _event(
            eventKey: 'e4',
            spaceId: 's1',
            activityId: 'a1',
            phraseId: 'p1',
            clientTimestamp: DateTime(2026, 6, 1, 10, 0),
          ),
        ];

        final result = service.aggregateByPeriod(
          events: events,
          windowStart: DateTime(2026, 5, 10),
          windowEnd: DateTime(2026, 5, 28),
        );

        expect(result.totalEvents, 3);
        expect(result.uniquePhrases, 3);
        expect(result.uniqueActivities, 2);
        expect(result.cooperatingCount, 1);
        expect(result.firstEventAt, DateTime(2026, 5, 15, 10, 0));
        expect(result.lastEventAt, DateTime(2026, 5, 25, 10, 0));
        expect(result.practicedDays, 3);
      });
    });

    // -------------------------------------------------------------------------
    // Convenience period aggregations
    // -------------------------------------------------------------------------

    group('aggregateThisWeek', () {
      test('aggregates events from start of week', () {
        // 2026-05-29 is a Friday (weekday=5), week starts Monday 5/25.
        final events = [
          _event(
            eventKey: 'e1',
            spaceId: 's1',
            activityId: 'a1',
            phraseId: 'p1',
            clientTimestamp: DateTime(2026, 5, 25, 10, 0),
          ),
          _event(
            eventKey: 'e2',
            spaceId: 's1',
            activityId: 'a1',
            phraseId: 'p2',
            clientTimestamp: DateTime(2026, 5, 29, 10, 0),
          ),
          // Last week, should be excluded.
          _event(
            eventKey: 'e3',
            spaceId: 's1',
            activityId: 'a1',
            phraseId: 'p3',
            clientTimestamp: DateTime(2026, 5, 24, 10, 0),
          ),
        ];

        final result = service.aggregateThisWeek(
          events: events,
          now: DateTime(2026, 5, 29, 20, 0),
        );

        expect(result.totalEvents, 2);
      });
    });

    group('aggregateThisMonth', () {
      test('aggregates events from start of month', () {
        final events = [
          _event(
            eventKey: 'e1',
            spaceId: 's1',
            activityId: 'a1',
            phraseId: 'p1',
            clientTimestamp: DateTime(2026, 5, 1, 10, 0),
          ),
          _event(
            eventKey: 'e2',
            spaceId: 's1',
            activityId: 'a1',
            phraseId: 'p2',
            clientTimestamp: DateTime(2026, 5, 29, 10, 0),
          ),
          // Last month, excluded.
          _event(
            eventKey: 'e3',
            spaceId: 's1',
            activityId: 'a1',
            phraseId: 'p3',
            clientTimestamp: DateTime(2026, 4, 30, 10, 0),
          ),
        ];

        final result = service.aggregateThisMonth(
          events: events,
          now: DateTime(2026, 5, 29, 20, 0),
        );

        expect(result.totalEvents, 2);
      });
    });

    group('aggregateThisYear', () {
      test('aggregates events from start of year', () {
        final events = [
          _event(
            eventKey: 'e1',
            spaceId: 's1',
            activityId: 'a1',
            phraseId: 'p1',
            clientTimestamp: DateTime(2026, 1, 15, 10, 0),
          ),
          _event(
            eventKey: 'e2',
            spaceId: 's1',
            activityId: 'a1',
            phraseId: 'p2',
            clientTimestamp: DateTime(2026, 5, 29, 10, 0),
          ),
          // Last year, excluded.
          _event(
            eventKey: 'e3',
            spaceId: 's1',
            activityId: 'a1',
            phraseId: 'p3',
            clientTimestamp: DateTime(2025, 12, 31, 10, 0),
          ),
        ];

        final result = service.aggregateThisYear(
          events: events,
          now: DateTime(2026, 5, 29, 20, 0),
        );

        expect(result.totalEvents, 2);
      });
    });
  });
}
