import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';

import '../../support/onboarding_test_fixtures.dart';

void main() {
  group('OnboardingRepository', () {
    late Directory tempDir;
    late OnboardingRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'onboarding_repository_test_',
      );
      repository = OnboardingRepository(
        snapshotStore: OnboardingSnapshotStore(
          directoryResolver: () async => tempDir,
        ),
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('persists and restores the completed V4 handoff identity', () async {
      final snapshot = await saveCompletedOnboardingSnapshot(
        repository,
        childDisplayName: '小满',
        ageBucket: OnboardingAgeBucket.sevenToTwelve,
        selectedSceneIds: const <String>['bath_time'],
        firstTraceEventKey: 'install_test:evt_first_turn',
        completedAt: DateTime.utc(2026, 8, 15, 8),
      );

      final restored = await repository.readCompletedSnapshot();

      expect(restored?.toJsonMap(), snapshot.toJsonMap());
      expect(restored?.currentStage, 'sound_turn_taking');
      expect(restored?.firstTraceEventKey, 'install_test:evt_first_turn');
    });

    test('clears a corrupt or unknown-age snapshot', () async {
      final file = File(
        '${tempDir.path}${Platform.pathSeparator}onboarding_snapshot.json',
      );
      await file.writeAsString(
        '{"childDisplayName":"米米","ageBucket":"99-100",'
        '"approxMonths":99,"currentStage":"sound_turn_taking",'
        '"starterSpaceId":"daily_care","starterActivityId":"bath_time",'
        '"starterPhraseId":"bath_time_warm_water",'
        '"completedAt":"2026-08-15T08:00:00.000Z",'
        '"consentState":"local_only"}',
        flush: true,
      );

      expect(await repository.readCompletedSnapshot(), isNull);
      expect(await file.exists(), isFalse);
    });

    test('does not expose an incomplete snapshot as completed', () async {
      await repository.saveSnapshot(
        OnboardingSnapshot(
          childDisplayName: '   ',
          ageBucket: OnboardingAgeBucket.zeroToSix,
          approxMonths: 3,
          currentStage: 'warm_routines',
          starterSpaceId: 'daily_care',
          starterActivityId: 'bath_time',
          starterPhraseId: 'bath_time_warm_water',
          consentState: OnboardingConsentState.localOnly,
          completedAt: DateTime.utc(2026, 8, 15),
        ),
      );

      expect(await repository.readSnapshot(), isNotNull);
      expect(await repository.readCompletedSnapshot(), isNull);
    });

    test(
      'clearAllLocalState removes active and retired M1 artifacts',
      () async {
        const names = <String>[
          'onboarding_snapshot.json',
          'onboarding_flow_snapshot.json',
          'onboarding_flow_snapshot.json.tmp',
          'onboarding_flow_snapshot.m1_quarantine.json',
          'onboarding_snapshot.m1_quarantine.json',
        ];
        for (final name in names) {
          await File(
            '${tempDir.path}${Platform.pathSeparator}$name',
          ).writeAsString('{}');
        }

        await repository.clearAllLocalState();

        for (final name in names) {
          expect(
            await File(
              '${tempDir.path}${Platform.pathSeparator}$name',
            ).exists(),
            isFalse,
            reason: name,
          );
        }
      },
    );

    test('surfaces snapshot persistence failures', () async {
      final brokenRepository = OnboardingRepository(
        snapshotStore: OnboardingSnapshotStore(
          directoryResolver: () async => throw StateError('disk denied'),
        ),
      );

      await expectLater(
        saveCompletedOnboardingSnapshot(
          brokenRepository,
          firstTraceEventKey: 'install_test:evt_first_turn',
        ),
        throwsA(isA<OnboardingSnapshotPersistenceException>()),
      );
    });
  });
}
