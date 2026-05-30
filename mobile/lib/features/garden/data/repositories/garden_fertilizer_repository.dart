import 'package:mobile/features/garden/data/local/garden_fertilizer_local_data_source.dart';
import 'package:mobile/features/garden/data/remote/garden_fertilizer_api_service.dart';
import 'package:mobile/features/garden/domain/models/fertilizer_state.dart';

/// Repository for the Garden V2 fertilizer state (claim + apply).
///
/// Only owns the mutable fertilizer state. The list of claimable packs is
/// derived elsewhere from the garden growth snapshot (practice traces).
class GardenFertilizerRepository {
  GardenFertilizerRepository({
    required GardenFertilizerLocalDataSource localDataSource,
    GardenFertilizerRemoteDataSource? remoteDataSource,
    String Function()? requestIdFactory,
  }) : _localDataSource = localDataSource,
       _remoteDataSource = remoteDataSource,
       _requestIdFactory = requestIdFactory ?? _defaultRequestId;

  final GardenFertilizerLocalDataSource _localDataSource;
  final GardenFertilizerRemoteDataSource? _remoteDataSource;
  final String Function() _requestIdFactory;

  Future<FertilizerState> load() async {
    final remoteDataSource = _remoteDataSource;
    if (remoteDataSource == null) {
      return _localDataSource.readState();
    }

    try {
      final remoteState = await remoteDataSource.fetchState();
      return _localDataSource.writeState(remoteState);
    } on Object {
      return _localDataSource.readState();
    }
  }

  /// Claims the pack identified by [eventKey] into the backpack.
  ///
  /// Idempotent: claiming an already-claimed key is a no-op.
  Future<FertilizerState> claim(String eventKey) async {
    final remoteDataSource = _remoteDataSource;
    if (remoteDataSource != null) {
      try {
        final remoteState = await remoteDataSource.claim(
          eventKey: eventKey,
          requestId: _requestIdFactory(),
        );
        return _localDataSource.writeState(remoteState);
      } on Object {
        // Remote failure falls back to local optimistic logic.
      }
    }

    return _claimLocal(eventKey);
  }

  /// Applies one pack of fertilizer (施肥), consuming one backpack pack.
  ///
  /// No-op when the backpack is empty.
  Future<FertilizerState> apply() async {
    final remoteDataSource = _remoteDataSource;
    if (remoteDataSource != null) {
      try {
        final remoteState = await remoteDataSource.apply(
          requestId: _requestIdFactory(),
        );
        return _localDataSource.writeState(remoteState);
      } on Object {
        // Remote failure falls back to local optimistic logic.
      }
    }

    return _applyLocal();
  }

  Future<FertilizerState> _claimLocal(String eventKey) async {
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

  Future<FertilizerState> _applyLocal() async {
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

String _defaultRequestId() {
  return 'fert_${DateTime.now().microsecondsSinceEpoch}';
}
