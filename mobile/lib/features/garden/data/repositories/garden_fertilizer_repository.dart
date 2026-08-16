import 'package:mobile/features/garden/data/local/garden_fertilizer_local_data_source.dart';
import 'package:mobile/features/garden/data/remote/garden_fertilizer_api_service.dart';
import 'package:mobile/features/garden/domain/models/fertilizer_state.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';

typedef GardenFertilizerAccountSnapshotLoader =
    Future<AccountLocalSnapshot> Function();

class GardenFertilizerRepositoryException implements Exception {
  const GardenFertilizerRepositoryException(this.message);
  final String message;
}

/// Repository for the Garden V2 fertilizer state (claim + apply).
///
/// Only owns the mutable fertilizer state. The list of claimable packs is
/// derived elsewhere from the garden growth snapshot (practice traces).
class GardenFertilizerRepository {
  GardenFertilizerRepository({
    required GardenFertilizerLocalDataSource localDataSource,
    GardenFertilizerRemoteDataSource? remoteDataSource,
    GardenFertilizerAccountSnapshotLoader? accountSnapshotLoader,
    PersistRefreshedSession? persistRefreshedSession,
    String Function()? requestIdFactory,
  }) : _localDataSource = localDataSource,
       _remoteDataSource = remoteDataSource,
       _accountSnapshotLoader = accountSnapshotLoader,
       _persistRefreshedSession = persistRefreshedSession,
       _requestIdFactory = requestIdFactory ?? _defaultRequestId;

  final GardenFertilizerLocalDataSource _localDataSource;
  final GardenFertilizerRemoteDataSource? _remoteDataSource;
  final GardenFertilizerAccountSnapshotLoader? _accountSnapshotLoader;
  final PersistRefreshedSession? _persistRefreshedSession;
  final String Function() _requestIdFactory;

  Future<FertilizerState> load() async {
    final remoteDataSource = _remoteDataSource;
    if (remoteDataSource == null) {
      return _localDataSource.readState();
    }

    final remoteState = await remoteDataSource.fetchState(
      session: await _requireAuthenticatedSession(),
      persistRefreshedSession: _persistRefreshedSession,
    );
    return _localDataSource.writeState(remoteState);
  }

  /// Claims the pack identified by [eventKey] into the backpack.
  ///
  /// Idempotent: claiming an already-claimed key is a no-op.
  String createRequestId() => _requestIdFactory();

  Future<FertilizerState> claim(String eventKey, {String? requestId}) async {
    final remoteDataSource = _remoteDataSource;
    if (remoteDataSource != null) {
      final remoteState = await remoteDataSource.claim(
        eventKey: eventKey,
        requestId: requestId ?? _requestIdFactory(),
        session: await _requireAuthenticatedSession(),
        persistRefreshedSession: _persistRefreshedSession,
      );
      return _localDataSource.writeState(remoteState);
    }

    return _claimLocal(eventKey);
  }

  /// Applies one pack of fertilizer (施肥), consuming one backpack pack.
  ///
  /// No-op when the backpack is empty.
  Future<FertilizerState> apply({String? requestId}) async {
    final remoteDataSource = _remoteDataSource;
    if (remoteDataSource != null) {
      final remoteState = await remoteDataSource.apply(
        requestId: requestId ?? _requestIdFactory(),
        session: await _requireAuthenticatedSession(),
        persistRefreshedSession: _persistRefreshedSession,
      );
      return _localDataSource.writeState(remoteState);
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

  Future<AccountSession> _requireAuthenticatedSession() async {
    final loader = _accountSnapshotLoader;
    if (loader == null) {
      throw const GardenFertilizerRepositoryException('请先登录后再管理花园。');
    }
    final session = (await loader()).session;
    if (session == null || !session.hasJwtTokens) {
      throw const GardenFertilizerRepositoryException('请先登录后再管理花园。');
    }
    return session;
  }
}

String _defaultRequestId() {
  return 'fert_${DateTime.now().microsecondsSinceEpoch}';
}
