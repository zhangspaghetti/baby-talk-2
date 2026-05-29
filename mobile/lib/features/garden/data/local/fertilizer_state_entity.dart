import 'package:isar/isar.dart';

part '../../../../generated/features/garden/data/local/fertilizer_state_entity.g.dart';

/// Persisted mutable fertilizer state for Garden V2.
///
/// Single-row collection (fixed [id] = 0). Tracks which practice events have
/// been claimed into the backpack and how many times the player has applied
/// fertilizer (which drives the flower stage).
@collection
class FertilizerStateEntity {
  FertilizerStateEntity();

  /// Fixed single-row id so the state is always upserted in place.
  Id id = 0;

  /// Total number of times fertilizer has been applied (施肥次数).
  late int appliedCount;

  /// Practice event keys already claimed into the backpack (领取).
  late List<String> claimedEventKeys;

  /// Timestamp of the most recent claim, if any.
  DateTime? lastClaimedAt;

  /// Timestamp of the most recent application, if any.
  DateTime? lastAppliedAt;
}
