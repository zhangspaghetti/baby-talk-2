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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): _resolveBundledIsarLibraryPath()},
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

String _resolveBundledIsarLibraryPath() {
  final pubCacheRoot = Platform.environment['PUB_CACHE'];
  final localAppData = Platform.environment['LOCALAPPDATA'];
  final candidateRoots = <Directory>[
    if (pubCacheRoot != null) Directory(pubCacheRoot),
    if (localAppData != null) Directory('$localAppData\\Pub\\Cache'),
  ];

  for (final root in candidateRoots) {
    final hostedDirectory = Directory(
      '${root.path}${Platform.pathSeparator}hosted',
    );
    if (!hostedDirectory.existsSync()) {
      continue;
    }

    for (final host in hostedDirectory.listSync().whereType<Directory>()) {
      for (final packageDir in host.listSync().whereType<Directory>()) {
        final packageName = packageDir.path.split(RegExp(r'[\\/]')).last;
        if (!packageName.startsWith('isar_flutter_libs-')) {
          continue;
        }

        final dll = File(
          '${packageDir.path}${Platform.pathSeparator}windows${Platform.pathSeparator}isar.dll',
        );
        if (dll.existsSync()) {
          return dll.path;
        }
      }
    }
  }

  throw StateError('未在 pub cache 中找到 isar_flutter_libs/windows/isar.dll');
}
