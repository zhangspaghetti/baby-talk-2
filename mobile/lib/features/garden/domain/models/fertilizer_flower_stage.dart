/// Garden V2 fertilizer flower stages, driven by cumulative apply count.
///
/// Thresholds (per 2026-05-28-flutter-mobile-garden-v2-design.md §4):
/// 0 → 种子, 3 → 发芽, 10 → 含苞, 25 → 盛开, 50 → 结果.
enum FertilizerFlowerStage { seed, sprout, budding, blooming, fruiting }

extension FertilizerFlowerStageCopy on FertilizerFlowerStage {
  String get label {
    switch (this) {
      case FertilizerFlowerStage.seed:
        return '种子';
      case FertilizerFlowerStage.sprout:
        return '发芽';
      case FertilizerFlowerStage.budding:
        return '含苞';
      case FertilizerFlowerStage.blooming:
        return '盛开';
      case FertilizerFlowerStage.fruiting:
        return '结果';
    }
  }

  /// Cumulative apply count required to reach this stage.
  int get requiredApplies {
    switch (this) {
      case FertilizerFlowerStage.seed:
        return 0;
      case FertilizerFlowerStage.sprout:
        return 3;
      case FertilizerFlowerStage.budding:
        return 10;
      case FertilizerFlowerStage.blooming:
        return 25;
      case FertilizerFlowerStage.fruiting:
        return 50;
    }
  }

  String get warmSummary {
    switch (this) {
      case FertilizerFlowerStage.seed:
        return '种子已经种下，说一句英文就能收到第一包肥料。';
      case FertilizerFlowerStage.sprout:
        return '小芽破土了，继续施肥让它长高。';
      case FertilizerFlowerStage.budding:
        return '花苞悄悄出现，离开花不远了。';
      case FertilizerFlowerStage.blooming:
        return '花朵绽放，这片练习已经有了稳定节奏。';
      case FertilizerFlowerStage.fruiting:
        return '结出果实，可以回来复习加深熟悉感。';
    }
  }
}

/// Resolved stage information for a given cumulative apply count.
class FertilizerStageInfo {
  const FertilizerStageInfo({
    required this.stage,
    required this.appliedCount,
    required this.nextStage,
    required this.nextThreshold,
    required this.currentThreshold,
  });

  final FertilizerFlowerStage stage;
  final int appliedCount;

  /// Next stage, or null if already at the final stage.
  final FertilizerFlowerStage? nextStage;

  /// Apply count required for [nextStage], or null at the final stage.
  final int? nextThreshold;

  /// Apply count at which the current [stage] began.
  final int currentThreshold;

  bool get isFinalStage => nextStage == null;

  /// Applies still needed to reach the next stage (0 when final).
  int get appliesToNext {
    final target = nextThreshold;
    if (target == null) return 0;
    return (target - appliedCount).clamp(0, target);
  }

  /// Progress (0..1) from the current threshold toward the next.
  double get progressToNext {
    final target = nextThreshold;
    if (target == null) return 1;
    final span = target - currentThreshold;
    if (span <= 0) return 1;
    final done = (appliedCount - currentThreshold).clamp(0, span);
    return done / span;
  }
}

/// Pure resolver mapping a cumulative apply count to a [FertilizerStageInfo].
FertilizerStageInfo resolveFertilizerStage(int appliedCount) {
  final count = appliedCount < 0 ? 0 : appliedCount;
  const stages = FertilizerFlowerStage.values;
  var current = stages.first;
  for (final stage in stages) {
    if (count >= stage.requiredApplies) {
      current = stage;
    } else {
      break;
    }
  }
  final currentIndex = current.index;
  final hasNext = currentIndex < stages.length - 1;
  final next = hasNext ? stages[currentIndex + 1] : null;
  return FertilizerStageInfo(
    stage: current,
    appliedCount: count,
    nextStage: next,
    nextThreshold: next?.requiredApplies,
    currentThreshold: current.requiredApplies,
  );
}
