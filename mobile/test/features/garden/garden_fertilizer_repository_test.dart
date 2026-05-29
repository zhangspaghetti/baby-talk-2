import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/features/garden/data/local/garden_fertilizer_local_data_source.dart';
import 'package:mobile/features/garden/data/repositories/garden_fertilizer_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): _resolveBundledIsarLibraryPath()},
    );
  });

  group('GardenFertilizerRepository', () {
    late Directory tempDir;
    late GardenFertilizerLocalDataSource localDataSource;
    late GardenFertilizerRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fertilizer_repo_test_');
      localDataSource = await GardenFertilizerLocalDataSource.open(
        directory: tempDir.path,
        name: 'fertilizer_${DateTime.now().microsecondsSinceEpoch}',
      );
      repository = GardenFertilizerRepository(localDataSource: localDataSource);
    });

    tearDown(() async {
      await localDataSource.isar.close(deleteFromDisk: true);
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('load returns initial state on a fresh store', () async {
      final state = await repository.load();
      expect(state.appliedCount, 0);
      expect(state.claimedEventKeys, isEmpty);
      expect(state.backpackCount, 0);
    });

    test('claim adds a pack to the backpack and is idempotent', () async {
      final afterFirst = await repository.claim('evt-1');
      expect(afterFirst.claimedEventKeys, {'evt-1'});
      expect(afterFirst.backpackCount, 1);

      final afterDuplicate = await repository.claim('evt-1');
      expect(afterDuplicate.claimedEventKeys, {'evt-1'});
      expect(afterDuplicate.backpackCount, 1);

      final afterSecond = await repository.claim('evt-2');
      expect(afterSecond.claimedEventKeys, {'evt-1', 'evt-2'});
      expect(afterSecond.backpackCount, 2);
    });

    test('apply consumes a backpack pack and raises applied count', () async {
      await repository.claim('evt-1');
      await repository.claim('evt-2');

      final afterApply = await repository.apply();
      expect(afterApply.appliedCount, 1);
      expect(afterApply.backpackCount, 1);
    });

    test('apply is a no-op when the backpack is empty', () async {
      final state = await repository.apply();
      expect(state.appliedCount, 0);
      expect(state.backpackCount, 0);
    });

    test('state persists across data source reopen', () async {
      await repository.claim('evt-1');
      await repository.claim('evt-2');
      await repository.apply();

      final dbName = 'fertilizer_persist_${DateTime.now().microsecondsSinceEpoch}';
      final ds1 = await GardenFertilizerLocalDataSource.open(
        directory: tempDir.path,
        name: dbName,
      );
      final repo1 = GardenFertilizerRepository(localDataSource: ds1);
      await repo1.claim('evt-3');
      await repo1.apply();
      await ds1.isar.close();

      final ds2 = await GardenFertilizerLocalDataSource.open(
        directory: tempDir.path,
        name: dbName,
      );
      final repo2 = GardenFertilizerRepository(localDataSource: ds2);
      final reloaded = await repo2.load();
      expect(reloaded.claimedEventKeys, {'evt-3'});
      expect(reloaded.appliedCount, 1);
      await ds2.isar.close(deleteFromDisk: true);
    });
  });
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
