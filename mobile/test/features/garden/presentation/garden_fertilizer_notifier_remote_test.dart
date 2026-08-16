import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/garden/data/local/garden_fertilizer_local_data_source.dart';
import 'package:mobile/features/garden/data/repositories/garden_fertilizer_repository.dart';
import 'package:mobile/features/garden/data/remote/garden_fertilizer_api_service.dart';
import 'package:mobile/features/garden/domain/models/fertilizer_state.dart';
import 'package:mobile/features/garden/presentation/garden_fertilizer_notifier.dart';
import 'package:mobile/features/practice/data/repositories/garden_growth_repository.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/presentation/garden_growth_notifier.dart';
import '../../../support/isar_test_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): resolveBundledIsarLibraryPath()},
    );
  });

  group('GardenFertilizerNotifier authenticated remote state', () {
    late Directory tempDir;
    late GardenFertilizerLocalDataSource localDataSource;
    late GardenFertilizerRepository repository;
    late GardenFertilizerNotifier notifier;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fertilizer_remote_');
      localDataSource = await GardenFertilizerLocalDataSource.open(
        directory: tempDir.path,
        name: 'fertilizer_${DateTime.now().microsecondsSinceEpoch}',
      );

      repository = _remoteRepository(localDataSource, _FailThenSucceedRemote());
    });

    tearDown(() async {
      notifier.dispose();
      await localDataSource.isar.close(deleteFromDisk: true);
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'remote claim failure keeps state unchanged and offers retry',
      () async {
        final remote = _FailThenSucceedRemote();
        repository = _remoteRepository(localDataSource, remote);
        notifier = GardenFertilizerNotifier(
          repositoryFuture: Future<GardenFertilizerRepository>.value(
            repository,
          ),
          growthNotifier: _GrowthStub(),
        );
        await notifier.initialize();

        await notifier.claim('evt-1');

        expect(notifier.view.backpackCount, 0);
        expect(notifier.view.errorMessage, '网络不可用，请检查网络后重试。');
        expect(notifier.view.canRetry, isTrue);

        await notifier.retryLastOperation();

        expect(notifier.view.backpackCount, 1);
        expect(notifier.view.errorMessage, isNull);
        expect(remote.claimRequestIds, hasLength(2));
        expect(remote.claimRequestIds[0], remote.claimRequestIds[1]);
      },
    );

    test('remote load failure can retry the authenticated read', () async {
      final remote = _FetchFailThenSucceedRemote();
      repository = _remoteRepository(localDataSource, remote);
      notifier = GardenFertilizerNotifier(
        repositoryFuture: Future<GardenFertilizerRepository>.value(repository),
        growthNotifier: _GrowthStub(),
      );
      await notifier.initialize();

      expect(notifier.view.errorMessage, '网络不可用，请检查网络后重试。');
      expect(notifier.view.canRetry, isTrue);

      await notifier.retryLastOperation();

      expect(remote.fetchAttempts, 2);
      expect(notifier.view.errorMessage, isNull);
      expect(notifier.view.canRetry, isFalse);
    });
  });
}

GardenFertilizerRepository _remoteRepository(
  GardenFertilizerLocalDataSource localDataSource,
  GardenFertilizerRemoteDataSource remoteDataSource,
) {
  final session = AccountSession.validated(
    accountId: 'account-1',
    sessionId: 'session-1',
    maskedPhoneNumber: '138****0000',
    createdAt: DateTime.utc(2026, 6, 1),
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    accessTokenExpiresAt: DateTime.utc(2026, 6, 2),
    refreshTokenExpiresAt: DateTime.utc(2026, 7, 1),
  );
  return GardenFertilizerRepository(
    localDataSource: localDataSource,
    remoteDataSource: remoteDataSource,
    accountSnapshotLoader: () async => AccountLocalSnapshot(
      consentState: AccountConsentState.acceptedPendingSync,
      session: session,
    ),
    persistRefreshedSession: (refreshed) async => refreshed,
    requestIdFactory: () => 'stable-request-id',
  );
}

class _FailThenSucceedRemote implements GardenFertilizerRemoteDataSource {
  int _claimAttempts = 0;
  final List<String> claimRequestIds = [];

  @override
  Future<FertilizerState> fetchState({
    AccountSession? session,
    PersistRefreshedSession? persistRefreshedSession,
  }) async => const FertilizerState.initial();

  @override
  Future<FertilizerState> claim({
    required String eventKey,
    required String requestId,
    AccountSession? session,
    PersistRefreshedSession? persistRefreshedSession,
  }) async {
    claimRequestIds.add(requestId);
    if (_claimAttempts++ == 0) {
      throw const GardenFertilizerApiException.network(message: 'offline');
    }
    return FertilizerState(appliedCount: 0, claimedEventKeys: {eventKey});
  }

  @override
  Future<FertilizerState> apply({
    required String requestId,
    AccountSession? session,
    PersistRefreshedSession? persistRefreshedSession,
  }) async => throw UnimplementedError();
}

class _FetchFailThenSucceedRemote implements GardenFertilizerRemoteDataSource {
  int fetchAttempts = 0;

  @override
  Future<FertilizerState> fetchState({
    AccountSession? session,
    PersistRefreshedSession? persistRefreshedSession,
  }) async {
    if (fetchAttempts++ == 0) {
      throw const GardenFertilizerApiException.network(message: 'offline');
    }
    return const FertilizerState.initial();
  }

  @override
  Future<FertilizerState> claim({
    required String eventKey,
    required String requestId,
    AccountSession? session,
    PersistRefreshedSession? persistRefreshedSession,
  }) async => throw UnimplementedError();

  @override
  Future<FertilizerState> apply({
    required String requestId,
    AccountSession? session,
    PersistRefreshedSession? persistRefreshedSession,
  }) async => throw UnimplementedError();
}

class _GrowthStub extends GardenGrowthNotifier {
  _GrowthStub() : super(repository: _GrowthRepoFake());

  @override
  GardenGrowthSnapshot get snapshot => GardenGrowthSnapshot.empty();

  @override
  GardenGrowthLoadStatus get status => GardenGrowthLoadStatus.ready;
}

class _GrowthRepoFake implements GardenGrowthRepository {
  @override
  Future<GardenGrowthSnapshot> buildSnapshot() async =>
      GardenGrowthSnapshot.empty();
}
