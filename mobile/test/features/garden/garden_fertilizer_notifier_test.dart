import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/features/garden/data/local/garden_fertilizer_local_data_source.dart';
import 'package:mobile/features/garden/data/repositories/garden_fertilizer_repository.dart';
import 'package:mobile/features/garden/domain/models/fertilizer_flower_stage.dart';
import 'package:mobile/features/garden/presentation/garden_fertilizer_notifier.dart';
import 'package:mobile/features/practice/data/repositories/garden_growth_repository.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/presentation/garden_growth_notifier.dart';
import '../../support/isar_test_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): resolveBundledIsarLibraryPath()},
    );
  });

  group('GardenFertilizerNotifier celebration', () {
    late Directory tempDir;
    late GardenFertilizerLocalDataSource dataSource;
    late GardenFertilizerRepository repository;
    late GardenFertilizerNotifier notifier;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('fertilizer_notifier_');
      dataSource = await GardenFertilizerLocalDataSource.open(
        directory: tempDir.path,
        name: 'fertilizer_${DateTime.now().microsecondsSinceEpoch}',
      );
      repository = GardenFertilizerRepository(localDataSource: dataSource);
      notifier = GardenFertilizerNotifier(
        repositoryFuture: Future<GardenFertilizerRepository>.value(repository),
        growthNotifier: _GrowthStub(),
      );
      await notifier.initialize();
    });

    tearDown(() async {
      notifier.dispose();
      await dataSource.isar.close(deleteFromDisk: true);
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('celebrationStage is set only when an apply crosses a threshold',
        () async {
      await notifier.claim('a');
      await notifier.claim('b');
      await notifier.claim('c');
      expect(notifier.celebrationStage, isNull);

      await notifier.apply(); // applied 1 → still seed
      expect(notifier.celebrationStage, isNull);
      await notifier.apply(); // applied 2 → still seed
      expect(notifier.celebrationStage, isNull);

      await notifier.apply(); // applied 3 → sprout
      expect(notifier.celebrationStage, FertilizerFlowerStage.sprout);
    });

    test('consumeCelebration clears the pending celebration', () async {
      await notifier.claim('a');
      await notifier.claim('b');
      await notifier.claim('c');
      await notifier.apply();
      await notifier.apply();
      await notifier.apply();
      expect(notifier.celebrationStage, FertilizerFlowerStage.sprout);

      notifier.consumeCelebration();
      expect(notifier.celebrationStage, isNull);
    });

    test('apply on an empty backpack never triggers a celebration', () async {
      await notifier.apply();
      expect(notifier.celebrationStage, isNull);
    });
  });
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
