/// Pure Dart Logic Layer service for garden fertilizer calculations.
///
/// Stateless, no Flutter dependencies, no Repository dependencies.
/// All methods are pure functions operating on their input data.

// ---------------------------------------------------------------------------
// Enums mirroring domain models (no Flutter/Freezed dependency)
// ---------------------------------------------------------------------------

enum GardenFlowerStage { seed, sprout, growing, blooming, fullBloom }

extension GardenFlowerStageLabel on GardenFlowerStage {
  String get label {
    switch (this) {
      case GardenFlowerStage.seed:
        return '种子';
      case GardenFlowerStage.sprout:
        return '发芽';
      case GardenFlowerStage.growing:
        return '生长';
      case GardenFlowerStage.blooming:
        return '开花';
      case GardenFlowerStage.fullBloom:
        return '盛放';
    }
  }
}

enum GardenPatchStage { quiet, tended, rooted, glowing }

extension GardenPatchStageLabel on GardenPatchStage {
  String get label {
    switch (this) {
      case GardenPatchStage.quiet:
        return '安静等待';
      case GardenPatchStage.tended:
        return '刚被照料';
      case GardenPatchStage.rooted:
        return '正在扎根';
      case GardenPatchStage.glowing:
        return '温柔发亮';
    }
  }
}

// ---------------------------------------------------------------------------
// Input / Output data classes
// ---------------------------------------------------------------------------

/// Input data representing a single activity's state for stage calculation.
class ActivityStats {
  const ActivityStats({
    required this.totalEvents,
    required this.completedPhraseCount,
    required this.totalPhraseCount,
    required this.hasImitated,
  });

  final int totalEvents;
  final int completedPhraseCount;
  final int totalPhraseCount;
  final bool hasImitated;
}

/// Input data representing a space (patch) state for patch stage calculation.
class SpaceStats {
  const SpaceStats({
    required this.totalKnownEvents,
    required this.startedActivityCount,
    required this.completedActivityCount,
    required this.totalActivityCount,
  });

  final int totalKnownEvents;
  final int startedActivityCount;
  final int completedActivityCount;
  final int totalActivityCount;
}

/// Result of a daily fertilizer cap check.
class DailyCapCheck {
  const DailyCapCheck({
    required this.eventCountToday,
    required this.dailyCap,
    required this.isAtCap,
    required this.remainingCapacity,
  });

  final int eventCountToday;
  final int dailyCap;
  final bool isAtCap;
  final int remainingCapacity;
}

/// Represents the expiry state of a fertilizer application.
class FertilizerExpiry {
  const FertilizerExpiry({
    required this.appliedAt,
    required this.expiresAt,
    required this.isExpired,
    required this.remainingDuration,
  });

  final DateTime appliedAt;
  final DateTime expiresAt;
  final bool isExpired;
  final Duration remainingDuration;
}

/// Threshold information for advancing between flower stages.
class StageThreshold {
  const StageThreshold({
    required this.currentStage,
    required this.nextStage,
    required this.totalEvents,
    required this.completedPhrases,
    required this.requiredEvents,
    required this.requiredPhrases,
    required this.isThresholdMet,
  });

  final String currentStage;
  final String nextStage;
  final int totalEvents;
  final int completedPhrases;
  final int requiredEvents;
  final int requiredPhrases;
  final bool isThresholdMet;
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class GardenFertilizerService {
  const GardenFertilizerService();

  /// Determines the flower stage for an activity based on its current stats.
  ///
  /// Stages are: seed -> sprout -> growing -> blooming -> fullBloom.
  ///
  /// Rules (derived from GardenGrowthRepository._deriveFlowerStage):
  /// - seed:   totalEvents == 0
  /// - sprout: started but only 1 phrase completed and < 2 total events
  /// - growing: >= 2 completed phrases OR >= 2 total events (not yet complete)
  /// - blooming: all phrases completed, no imitation and no extra events
  /// - fullBloom: all phrases completed AND (has imitation OR extra events)
  GardenFlowerStage calculateFlowerStage(ActivityStats stats) {
    if (stats.totalEvents == 0) {
      return GardenFlowerStage.seed;
    }

    final isCompleted = stats.totalPhraseCount > 0 &&
        stats.completedPhraseCount >= stats.totalPhraseCount;

    if (isCompleted) {
      if (stats.hasImitated || stats.totalEvents > stats.totalPhraseCount) {
        return GardenFlowerStage.fullBloom;
      }
      return GardenFlowerStage.blooming;
    }

    if (stats.completedPhraseCount >= 2 || stats.totalEvents >= 2) {
      return GardenFlowerStage.growing;
    }

    return GardenFlowerStage.sprout;
  }

  /// Determines the patch (space) stage based on aggregated space stats.
  ///
  /// Stages are: quiet -> tended -> rooted -> glowing.
  ///
  /// Rules (derived from GardenGrowthRepository._derivePatchStage):
  /// - quiet:   no events at all
  /// - tended:  only 1 event and no started activities
  /// - rooted:  >= 2 events OR has started activities (not all complete)
  /// - glowing: all activities in the space are completed
  GardenPatchStage calculatePatchStage(SpaceStats stats) {
    if (stats.totalKnownEvents == 0) {
      return GardenPatchStage.quiet;
    }

    if (stats.totalActivityCount > 0 &&
        stats.completedActivityCount >= stats.totalActivityCount) {
      return GardenPatchStage.glowing;
    }

    if (stats.totalKnownEvents >= 2 || stats.startedActivityCount > 0) {
      return GardenPatchStage.rooted;
    }

    return GardenPatchStage.tended;
  }

  /// Checks whether the user has hit the daily fertilizer cap.
  ///
  /// [eventsOnDay] are all interaction events whose DateTime.day matches the
  /// target day (in local time). [dailyCap] is the maximum allowed events per
  /// day (default 30).
  DailyCapCheck checkDailyCap({
    required List<DateTime> eventsOnDay,
    int dailyCap = 30,
  }) {
    final count = eventsOnDay.length;
    final isAtCap = count >= dailyCap;
    final remaining = (dailyCap - count).clamp(0, dailyCap);
    return DailyCapCheck(
      eventCountToday: count,
      dailyCap: dailyCap,
      isAtCap: isAtCap,
      remainingCapacity: remaining,
    );
  }

  /// Computes the expiry state of a fertilizer applied at [appliedAt] with a
  /// given [ttl] (time-to-live).
  ///
  /// Returns whether the fertilizer has expired relative to [now] and the
  /// remaining duration (clamped to Duration.zero if expired).
  FertilizerExpiry computeExpiry({
    required DateTime appliedAt,
    required Duration ttl,
    required DateTime now,
  }) {
    final expiresAt = appliedAt.add(ttl);
    final isExpired = now.isAfter(expiresAt);
    final remaining =
        isExpired ? Duration.zero : expiresAt.difference(now);
    return FertilizerExpiry(
      appliedAt: appliedAt,
      expiresAt: expiresAt,
      isExpired: isExpired,
      remainingDuration: remaining,
    );
  }

  /// Returns the default fertilizer TTL (24 hours).
  Duration get defaultTtl => const Duration(hours: 24);

  /// Computes the threshold required to advance from [currentStage] to the next
  /// stage, and whether the current stats meet that threshold.
  ///
  /// Thresholds are calibrated so that:
  /// - seed -> sprout:      1 event is enough
  /// - sprout -> growing:   2 events or 2 completed phrases
  /// - growing -> blooming: all phrases completed
  /// - blooming -> fullBloom: all phrases completed + imitation or extra events
  StageThreshold computeStageThreshold({
    required GardenFlowerStage currentStage,
    required ActivityStats stats,
  }) {
    switch (currentStage) {
      case GardenFlowerStage.seed:
        return StageThreshold(
          currentStage: GardenFlowerStage.seed.label,
          nextStage: GardenFlowerStage.sprout.label,
          totalEvents: stats.totalEvents,
          completedPhrases: stats.completedPhraseCount,
          requiredEvents: 1,
          requiredPhrases: 1,
          isThresholdMet: stats.totalEvents >= 1,
        );
      case GardenFlowerStage.sprout:
        return StageThreshold(
          currentStage: GardenFlowerStage.sprout.label,
          nextStage: GardenFlowerStage.growing.label,
          totalEvents: stats.totalEvents,
          completedPhrases: stats.completedPhraseCount,
          requiredEvents: 2,
          requiredPhrases: 2,
          isThresholdMet:
              stats.completedPhraseCount >= 2 || stats.totalEvents >= 2,
        );
      case GardenFlowerStage.growing:
        return StageThreshold(
          currentStage: GardenFlowerStage.growing.label,
          nextStage: GardenFlowerStage.blooming.label,
          totalEvents: stats.totalEvents,
          completedPhrases: stats.completedPhraseCount,
          requiredEvents: stats.totalPhraseCount,
          requiredPhrases: stats.totalPhraseCount,
          isThresholdMet: stats.totalPhraseCount > 0 &&
              stats.completedPhraseCount >= stats.totalPhraseCount,
        );
      case GardenFlowerStage.blooming:
        return StageThreshold(
          currentStage: GardenFlowerStage.blooming.label,
          nextStage: GardenFlowerStage.fullBloom.label,
          totalEvents: stats.totalEvents,
          completedPhrases: stats.completedPhraseCount,
          requiredEvents: stats.totalPhraseCount + 1,
          requiredPhrases: stats.totalPhraseCount,
          isThresholdMet: stats.totalPhraseCount > 0 &&
              stats.completedPhraseCount >= stats.totalPhraseCount &&
              (stats.hasImitated ||
                  stats.totalEvents > stats.totalPhraseCount),
        );
      case GardenFlowerStage.fullBloom:
        return StageThreshold(
          currentStage: GardenFlowerStage.fullBloom.label,
          nextStage: GardenFlowerStage.fullBloom.label,
          totalEvents: stats.totalEvents,
          completedPhrases: stats.completedPhraseCount,
          requiredEvents: 0,
          requiredPhrases: 0,
          isThresholdMet: true,
        );
    }
  }
}
