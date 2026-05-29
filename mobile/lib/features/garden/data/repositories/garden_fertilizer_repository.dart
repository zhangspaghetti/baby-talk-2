import 'package:mobile/features/garden/data/local/garden_fertilizer_local_data_source.dart';
import 'package:mobile/features/garden/domain/models/fertilizer_state.dart';

/// Repository for the Garden V2 fertilizer state (claim + apply).
///
/// Only owns the mutable fertilizer state. The list of claimable packs is
/// derived elsewhere from the garden growth snapshot (practice traces).
class GardenFertilizerRepository {
  GardenFertilizerRepository({
    required GardenFertilizerLocalDataSource localDataSource,
  }) : _localDataSource = localDataSource;

  final GardenFertilizerLocalDataSource _localDataSource;

  Future<FertilizerState> load() => _localDataSource.readState();

  /// Claims the pack identified by [eventKey] into the backpack.
  ///
  /// Idempotent: claiming an already-claimed key is a no-op.
  Future<FertilizerState> claim(String eventKey) async {
    final current = await _localDataSource.readState();
    if (current.claimedEventKeys.contains(eventKey)) {
      return current;
    }
    final next = FertilizerState(
      appliedCount: current.appliedCount,
      claimedEventKeys: {...current.claimedEventKeys, eventKey},
      lastClaimedAt: DateTime.now(),
      lastAppliedAt: current.lastAppliedAt,
    );
    return _localDataSource.writeState(next);
  }

  /// Applies one pack of fertilizer (施肥), consuming one backpack pack.
  ///
  /// No-op when the backpack is empty.
  Future<FertilizerState> apply() async {
    final current = await _localDataSource.readState();
    if (current.backpackCount <= 0) {
      return current;
    }
    final next = FertilizerState(
      appliedCount: current.appliedCount + 1,
      claimedEventKeys: current.claimedEventKeys,
      lastClaimedAt: current.lastClaimedAt,
      lastAppliedAt: DateTime.now(),
    );
    return _localDataSource.writeState(next);
  }
}
