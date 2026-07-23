import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_flow_store.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_flow_models.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import '../../../support/isar_test_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): resolveBundledIsarLibraryPath()},
    );
  });

  group('OnboardingFlowStore', () {
    late Directory tempDir;
    late PracticeLocalDataSource localDataSource;
    late OnboardingFlowStore store;
    late OnboardingRepository onboardingRepository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'onboarding_flow_store_test_',
      );
      localDataSource = await PracticeLocalDataSource.open(
        directory: tempDir.path,
        name: 'onboarding_flow_${DateTime.now().microsecondsSinceEpoch}',
      );
      final practiceRepository = PracticeRepository(
        assetPhraseService: AssetPhraseService(bundle: rootBundle),
        localDataSource: localDataSource,
        installationIdService: InstallationIdService(
          directoryResolver: () async => tempDir,
          idGenerator: () => 'install_onboarding_flow_test',
        ),
      );
      store = OnboardingFlowStore(directoryResolver: () async => tempDir);
      onboardingRepository = OnboardingRepository(
        snapshotStore: OnboardingSnapshotStore(
          directoryResolver: () async => tempDir,
        ),
        flowStore: store,
        practiceRepository: practiceRepository,
        starterSpaceId: 'daily_care',
        starterActivityId: 'bath_time',
      );
    });

    tearDown(() async {
      await localDataSource.close(deleteFromDisk: true);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'store writes atomically and restores the last complete JSON object',
      () async {
        final snapshot = OnboardingFlowSnapshot.initial(
          DateTime.utc(2026, 7, 23),
        );

        await store.write(snapshot);

        expect(await store.read(), snapshot);
        expect(
          File('${tempDir.path}/onboarding_flow_snapshot.json').existsSync(),
          isTrue,
        );
        expect(
          File(
            '${tempDir.path}/onboarding_flow_snapshot.json.tmp',
          ).existsSync(),
          isFalse,
        );
      },
    );

    test(
      'corrupt flow file is deleted by repository and restarts safely',
      () async {
        await File(
          '${tempDir.path}/onboarding_flow_snapshot.json',
        ).writeAsString('{bad');

        expect(await onboardingRepository.readFlowSnapshot(), isNull);
        expect(
          File('${tempDir.path}/onboarding_flow_snapshot.json').existsSync(),
          isFalse,
        );
      },
    );

    test('write failure removes its temporary flow file', () async {
      await Directory('${tempDir.path}/onboarding_flow_snapshot.json').create();

      await expectLater(
        store.write(OnboardingFlowSnapshot.initial(DateTime.utc(2026, 7, 23))),
        throwsA(isA<OnboardingFlowPersistenceException>()),
      );

      expect(
        File('${tempDir.path}/onboarding_flow_snapshot.json.tmp').existsSync(),
        isFalse,
      );
    });

    test('delete removes both saved flow and orphan temporary file', () async {
      await store.write(
        OnboardingFlowSnapshot.initial(DateTime.utc(2026, 7, 23)),
      );
      await File(
        '${tempDir.path}/onboarding_flow_snapshot.json.tmp',
      ).writeAsString('orphan');

      await store.deleteIfExists();

      expect(
        File('${tempDir.path}/onboarding_flow_snapshot.json').existsSync(),
        isFalse,
      );
      expect(
        File('${tempDir.path}/onboarding_flow_snapshot.json.tmp').existsSync(),
        isFalse,
      );
    });
  });
}
