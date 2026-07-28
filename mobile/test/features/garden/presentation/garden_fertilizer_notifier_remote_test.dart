import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
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

  group('GardenFertilizerNotifier remote fallback', () {
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

      repository = GardenFertilizerRepository(
        localDataSource: localDataSource,
        remoteDataSource: _AlwaysFailRemoteDataSource(),
      );

      notifier = GardenFertilizerNotifier(
        repositoryFuture: Future<GardenFertilizerRepository>.value(repository),
        growthNotifier: _GrowthStub(),
      );
      await notifier.initialize();
    });

    tearDown(() async {
      notifier.dispose();
      await localDataSource.isar.close(deleteFromDisk: true);
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('claim falls back to local state when remote claim fails', () async {
      await notifier.claim('evt-1');

      expect(notifier.view.backpackCount, 1);
      expect(notifier.view.claimedPacks, isEmpty);
      expect(notifier.view.pendingPacks, isEmpty);
    });

    test('apply falls back to local state when remote apply fails', () async {
      await notifier.claim('evt-1');
      await notifier.apply();

      expect(notifier.view.backpackCount, 0);
      expect(notifier.view.stageInfo?.appliedCount, 1);
    });

    test('stale remote success does not roll back newer local state', () async {
      final newerLocal = FertilizerState(
        appliedCount: 2,
        claimedEventKeys: {'evt-1', 'evt-2', 'evt-3'},
        lastClaimedAt: DateTime(2026, 5, 30, 12, 0),
        lastAppliedAt: DateTime(2026, 5, 30, 12, 1),
      );

      await localDataSource.writeState(newerLocal);

      final staleRemoteState = FertilizerState(
        appliedCount: 1,
        claimedEventKeys: {'evt-1'},
        lastClaimedAt: DateTime(2026, 5, 30, 11, 0),
        lastAppliedAt: DateTime(2026, 5, 30, 11, 1),
      );

      final staleRepository = GardenFertilizerRepository(
        localDataSource: localDataSource,
        remoteDataSource: _AlwaysStaleRemoteDataSource(staleRemoteState),
      );

      final staleNotifier = GardenFertilizerNotifier(
        repositoryFuture: Future<GardenFertilizerRepository>.value(
          staleRepository,
        ),
        growthNotifier: _GrowthStub(),
      );

      await staleNotifier.initialize();
      await staleNotifier.claim('evt-4');
      await staleNotifier.apply();

      final merged = await localDataSource.readState();
      staleNotifier.dispose();

      expect(merged.appliedCount, 2);
      expect(merged.claimedEventKeys, {'evt-1', 'evt-2', 'evt-3'});
      expect(merged.lastClaimedAt, DateTime(2026, 5, 30, 12, 0));
      expect(merged.lastAppliedAt, DateTime(2026, 5, 30, 12, 1));
    });
  });
}

class _AlwaysFailRemoteDataSource implements GardenFertilizerRemoteDataSource {
  @override
  Future<FertilizerState> fetchState() async {
    throw const GardenFertilizerApiException.network(message: 'offline');
  }

  @override
  Future<FertilizerState> claim({
    required String eventKey,
    required String requestId,
  }) async {
    throw const GardenFertilizerApiException.network(message: 'offline');
  }

  @override
  Future<FertilizerState> apply({required String requestId}) async {
    throw const GardenFertilizerApiException.network(message: 'offline');
  }
}

class _AlwaysStaleRemoteDataSource implements GardenFertilizerRemoteDataSource {
  _AlwaysStaleRemoteDataSource(this.state);

  final FertilizerState state;

  @override
  Future<FertilizerState> fetchState() async => state;

  @override
  Future<FertilizerState> claim({
    required String eventKey,
    required String requestId,
  }) async => state;

  @override
  Future<FertilizerState> apply({required String requestId}) async => state;
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
