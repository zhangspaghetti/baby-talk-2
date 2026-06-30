import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/garden/domain/services/garden_fertilizer_service.dart';

void main() {
  group('GardenFertilizerService', () {
    const service = GardenFertilizerService();

    // -------------------------------------------------------------------------
    // Flower stage calculation
    // -------------------------------------------------------------------------

    group('calculateFlowerStage', () {
      test('no events returns seed', () {
        const stats = ActivityStats(
          totalEvents: 0,
          completedPhraseCount: 0,
          totalPhraseCount: 5,
          hasCooperatingReaction: false,
        );

        expect(service.calculateFlowerStage(stats), GardenFlowerStage.seed);
      });

      test('single event with 1 completed phrase returns sprout', () {
        const stats = ActivityStats(
          totalEvents: 1,
          completedPhraseCount: 1,
          totalPhraseCount: 5,
          hasCooperatingReaction: false,
        );

        expect(service.calculateFlowerStage(stats), GardenFlowerStage.sprout);
      });

      test('2 completed phrases returns growing', () {
        const stats = ActivityStats(
          totalEvents: 2,
          completedPhraseCount: 2,
          totalPhraseCount: 5,
          hasCooperatingReaction: false,
        );

        expect(service.calculateFlowerStage(stats), GardenFlowerStage.growing);
      });

      test('2+ total events with fewer phrases returns growing', () {
        const stats = ActivityStats(
          totalEvents: 3,
          completedPhraseCount: 1,
          totalPhraseCount: 5,
          hasCooperatingReaction: false,
        );

        expect(service.calculateFlowerStage(stats), GardenFlowerStage.growing);
      });

      test('all phrases completed without cooperation returns blooming', () {
        const stats = ActivityStats(
          totalEvents: 5,
          completedPhraseCount: 5,
          totalPhraseCount: 5,
          hasCooperatingReaction: false,
        );

        expect(service.calculateFlowerStage(stats), GardenFlowerStage.blooming);
      });

      test('all phrases completed with cooperation returns fullBloom', () {
        const stats = ActivityStats(
          totalEvents: 5,
          completedPhraseCount: 5,
          totalPhraseCount: 5,
          hasCooperatingReaction: true,
        );

        expect(
          service.calculateFlowerStage(stats),
          GardenFlowerStage.fullBloom,
        );
      });

      test('all phrases completed with extra events returns fullBloom', () {
        const stats = ActivityStats(
          totalEvents: 6,
          completedPhraseCount: 5,
          totalPhraseCount: 5,
          hasCooperatingReaction: false,
        );

        expect(
          service.calculateFlowerStage(stats),
          GardenFlowerStage.fullBloom,
        );
      });

      test('totalPhraseCount 0 with events does not crash', () {
        const stats = ActivityStats(
          totalEvents: 1,
          completedPhraseCount: 0,
          totalPhraseCount: 0,
          hasCooperatingReaction: false,
        );

        // Not completed (0 >= 0 is true but totalPhraseCount > 0 guard).
        // Falls through to growing check: completedPhraseCount >= 2 is false,
        // totalEvents >= 2 is false. Returns sprout.
        expect(service.calculateFlowerStage(stats), GardenFlowerStage.sprout);
      });
    });

    // -------------------------------------------------------------------------
    // Patch stage calculation
    // -------------------------------------------------------------------------

    group('calculatePatchStage', () {
      test('no events returns quiet', () {
        const stats = SpaceStats(
          totalKnownEvents: 0,
          startedActivityCount: 0,
          completedActivityCount: 0,
          totalActivityCount: 5,
        );

        expect(service.calculatePatchStage(stats), GardenPatchStage.quiet);
      });

      test('1 event with no started activities returns tended', () {
        const stats = SpaceStats(
          totalKnownEvents: 1,
          startedActivityCount: 0,
          completedActivityCount: 0,
          totalActivityCount: 5,
        );

        expect(service.calculatePatchStage(stats), GardenPatchStage.tended);
      });

      test('2+ events returns rooted', () {
        const stats = SpaceStats(
          totalKnownEvents: 2,
          startedActivityCount: 1,
          completedActivityCount: 0,
          totalActivityCount: 5,
        );

        expect(service.calculatePatchStage(stats), GardenPatchStage.rooted);
      });

      test('all activities completed returns glowing', () {
        const stats = SpaceStats(
          totalKnownEvents: 10,
          startedActivityCount: 5,
          completedActivityCount: 5,
          totalActivityCount: 5,
        );

        expect(service.calculatePatchStage(stats), GardenPatchStage.glowing);
      });

      test('all activities completed with 1 event returns glowing', () {
        const stats = SpaceStats(
          totalKnownEvents: 1,
          startedActivityCount: 1,
          completedActivityCount: 1,
          totalActivityCount: 1,
        );

        expect(service.calculatePatchStage(stats), GardenPatchStage.glowing);
      });
    });

    // -------------------------------------------------------------------------
    // Daily cap check
    // -------------------------------------------------------------------------

    group('checkDailyCap', () {
      test('empty list is not at cap', () {
        final result = service.checkDailyCap(eventsOnDay: []);

        expect(result.isAtCap, isFalse);
        expect(result.eventCountToday, 0);
        expect(result.remainingCapacity, 30);
      });

      test('fewer events than cap is not at cap', () {
        final events = List.generate(10, (_) => DateTime(2026, 5, 29));
        final result = service.checkDailyCap(eventsOnDay: events);

        expect(result.isAtCap, isFalse);
        expect(result.eventCountToday, 10);
        expect(result.remainingCapacity, 20);
      });

      test('exactly at cap returns isAtCap', () {
        final events = List.generate(30, (_) => DateTime(2026, 5, 29));
        final result = service.checkDailyCap(eventsOnDay: events);

        expect(result.isAtCap, isTrue);
        expect(result.eventCountToday, 30);
        expect(result.remainingCapacity, 0);
      });

      test('over cap still reports isAtCap', () {
        final events = List.generate(35, (_) => DateTime(2026, 5, 29));
        final result = service.checkDailyCap(eventsOnDay: events);

        expect(result.isAtCap, isTrue);
        expect(result.eventCountToday, 35);
        expect(result.remainingCapacity, 0);
      });

      test('custom cap is respected', () {
        final events = List.generate(5, (_) => DateTime(2026, 5, 29));
        final result = service.checkDailyCap(eventsOnDay: events, dailyCap: 5);

        expect(result.isAtCap, isTrue);
        expect(result.remainingCapacity, 0);
      });
    });

    // -------------------------------------------------------------------------
    // Fertilizer expiry
    // -------------------------------------------------------------------------

    group('computeExpiry', () {
      test('not expired within TTL', () {
        final appliedAt = DateTime(2026, 5, 29, 10, 0);
        final now = DateTime(2026, 5, 29, 12, 0);
        final ttl = const Duration(hours: 24);

        final result = service.computeExpiry(
          appliedAt: appliedAt,
          ttl: ttl,
          now: now,
        );

        expect(result.isExpired, isFalse);
        expect(result.remainingDuration, const Duration(hours: 22));
        expect(result.expiresAt, DateTime(2026, 5, 30, 10, 0));
      });

      test('expired after TTL', () {
        final appliedAt = DateTime(2026, 5, 29, 10, 0);
        final now = DateTime(2026, 5, 30, 11, 0);
        final ttl = const Duration(hours: 24);

        final result = service.computeExpiry(
          appliedAt: appliedAt,
          ttl: ttl,
          now: now,
        );

        expect(result.isExpired, isTrue);
        expect(result.remainingDuration, Duration.zero);
      });

      test('exact TTL boundary is not expired (isAfter)', () {
        final appliedAt = DateTime(2026, 5, 29, 10, 0);
        final now = DateTime(2026, 5, 30, 10, 0);
        final ttl = const Duration(hours: 24);

        final result = service.computeExpiry(
          appliedAt: appliedAt,
          ttl: ttl,
          now: now,
        );

        expect(result.isExpired, isFalse);
        expect(result.remainingDuration, Duration.zero);
      });

      test('default TTL is 24 hours', () {
        expect(service.defaultTtl, const Duration(hours: 24));
      });
    });

    // -------------------------------------------------------------------------
    // Stage threshold calculation
    // -------------------------------------------------------------------------

    group('computeStageThreshold', () {
      test('seed to sprout requires 1 event', () {
        const stats = ActivityStats(
          totalEvents: 0,
          completedPhraseCount: 0,
          totalPhraseCount: 5,
          hasCooperatingReaction: false,
        );

        final result = service.computeStageThreshold(
          currentStage: GardenFlowerStage.seed,
          stats: stats,
        );

        expect(result.currentStage, '种子');
        expect(result.nextStage, '发芽');
        expect(result.requiredEvents, 1);
        expect(result.isThresholdMet, isFalse);
      });

      test('seed to sprout with 1 event is met', () {
        const stats = ActivityStats(
          totalEvents: 1,
          completedPhraseCount: 1,
          totalPhraseCount: 5,
          hasCooperatingReaction: false,
        );

        final result = service.computeStageThreshold(
          currentStage: GardenFlowerStage.seed,
          stats: stats,
        );

        expect(result.isThresholdMet, isTrue);
      });

      test('sprout to growing requires 2 phrases or 2 events', () {
        const stats = ActivityStats(
          totalEvents: 1,
          completedPhraseCount: 1,
          totalPhraseCount: 5,
          hasCooperatingReaction: false,
        );

        final result = service.computeStageThreshold(
          currentStage: GardenFlowerStage.sprout,
          stats: stats,
        );

        expect(result.nextStage, '生长');
        expect(result.isThresholdMet, isFalse);
      });

      test('sprout to growing with 2 events is met', () {
        const stats = ActivityStats(
          totalEvents: 2,
          completedPhraseCount: 1,
          totalPhraseCount: 5,
          hasCooperatingReaction: false,
        );

        final result = service.computeStageThreshold(
          currentStage: GardenFlowerStage.sprout,
          stats: stats,
        );

        expect(result.isThresholdMet, isTrue);
      });

      test('growing to blooming requires all phrases completed', () {
        const stats = ActivityStats(
          totalEvents: 3,
          completedPhraseCount: 3,
          totalPhraseCount: 5,
          hasCooperatingReaction: false,
        );

        final result = service.computeStageThreshold(
          currentStage: GardenFlowerStage.growing,
          stats: stats,
        );

        expect(result.nextStage, '开花');
        expect(result.isThresholdMet, isFalse);
      });

      test('growing to blooming met when all phrases done', () {
        const stats = ActivityStats(
          totalEvents: 5,
          completedPhraseCount: 5,
          totalPhraseCount: 5,
          hasCooperatingReaction: false,
        );

        final result = service.computeStageThreshold(
          currentStage: GardenFlowerStage.growing,
          stats: stats,
        );

        expect(result.isThresholdMet, isTrue);
      });

      test('blooming to fullBloom requires cooperation or extra events', () {
        const stats = ActivityStats(
          totalEvents: 5,
          completedPhraseCount: 5,
          totalPhraseCount: 5,
          hasCooperatingReaction: false,
        );

        final result = service.computeStageThreshold(
          currentStage: GardenFlowerStage.blooming,
          stats: stats,
        );

        expect(result.nextStage, '盛放');
        expect(result.isThresholdMet, isFalse);
      });

      test('blooming to fullBloom met with cooperation', () {
        const stats = ActivityStats(
          totalEvents: 5,
          completedPhraseCount: 5,
          totalPhraseCount: 5,
          hasCooperatingReaction: true,
        );

        final result = service.computeStageThreshold(
          currentStage: GardenFlowerStage.blooming,
          stats: stats,
        );

        expect(result.isThresholdMet, isTrue);
      });

      test('fullBloom is always met', () {
        const stats = ActivityStats(
          totalEvents: 10,
          completedPhraseCount: 5,
          totalPhraseCount: 5,
          hasCooperatingReaction: true,
        );

        final result = service.computeStageThreshold(
          currentStage: GardenFlowerStage.fullBloom,
          stats: stats,
        );

        expect(result.isThresholdMet, isTrue);
        expect(result.currentStage, result.nextStage);
      });
    });
  });
}
