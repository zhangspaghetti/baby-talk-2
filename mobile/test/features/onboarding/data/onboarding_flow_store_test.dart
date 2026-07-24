import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_flow_store.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_flow_models.dart';

void main() {
  group('OnboardingFlowStore', () {
    late Directory tempDir;
    late OnboardingFlowStore store;
    late OnboardingRepository onboardingRepository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'onboarding_flow_store_test_',
      );
      store = OnboardingFlowStore(directoryResolver: () async => tempDir);
      onboardingRepository = OnboardingRepository(
        snapshotStore: OnboardingSnapshotStore(
          directoryResolver: () async => tempDir,
        ),
        flowStore: store,
      );
    });

    tearDown(() async {
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
