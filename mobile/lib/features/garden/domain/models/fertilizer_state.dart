import 'package:mobile/features/garden/domain/models/fertilizer_flower_stage.dart';

/// Persisted fertilizer state, decoupled from the Isar entity.
class FertilizerState {
  const FertilizerState({
    required this.appliedCount,
    required this.claimedEventKeys,
    this.lastClaimedAt,
    this.lastAppliedAt,
  });

  const FertilizerState.initial()
    : appliedCount = 0,
      claimedEventKeys = const <String>{},
      lastClaimedAt = null,
      lastAppliedAt = null;

  final int appliedCount;
  final Set<String> claimedEventKeys;
  final DateTime? lastClaimedAt;
  final DateTime? lastAppliedAt;

  /// Packs claimed into the backpack but not yet applied.
  int get backpackCount => (claimedEventKeys.length - appliedCount).clamp(
    0,
    claimedEventKeys.length,
  );
}

/// A single fertilizer pack derived from a practice trace (痕迹).
class FertilizerPack {
  const FertilizerPack({
    required this.eventKey,
    required this.title,
    required this.detail,
    required this.occurredAt,
    required this.claimed,
  });

  /// Stable key (== interaction event key) used to track claim state.
  final String eventKey;

  /// Primary line (e.g. activity / scene title).
  final String title;

  /// Secondary line (e.g. the practiced phrase).
  final String detail;

  final DateTime occurredAt;

  /// Whether this pack has been claimed into the backpack.
  final bool claimed;
}

/// Immutable view state composed by the notifier from the garden snapshot and
/// the persisted fertilizer state.
class GardenFertilizerViewState {
  const GardenFertilizerViewState({
    required this.isLoading,
    required this.pendingPacks,
    required this.claimedPacks,
    required this.backpackCount,
    required this.stageInfo,
  });

  const GardenFertilizerViewState.loading()
    : isLoading = true,
      pendingPacks = const <FertilizerPack>[],
      claimedPacks = const <FertilizerPack>[],
      backpackCount = 0,
      stageInfo = null;

  final bool isLoading;

  /// Packs available to claim (待领取), newest first.
  final List<FertilizerPack> pendingPacks;

  /// Packs already claimed (已领取), newest first.
  final List<FertilizerPack> claimedPacks;

  /// Packs in the backpack available to apply (施肥).
  final int backpackCount;

  /// Current flower stage info; null only while loading.
  final FertilizerStageInfo? stageInfo;

  bool get hasPendingPacks => pendingPacks.isNotEmpty;

  bool get canApply => backpackCount > 0;

  /// True before any trace exists at all (empty-state).
  bool get isEmpty =>
      !isLoading && pendingPacks.isEmpty && claimedPacks.isEmpty;
}
