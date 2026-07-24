import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_flow_store.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';

void main() {
  group('OnboardingRepository', () {
    late Directory tempDir;
    late OnboardingFlowStore flowStore;
    late OnboardingSnapshotStore snapshotStore;
    late OnboardingRepository onboardingRepository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'onboarding_repository_test_',
      );
      snapshotStore = OnboardingSnapshotStore(
        directoryResolver: () async => tempDir,
      );
      flowStore = OnboardingFlowStore(directoryResolver: () async => tempDir);
      onboardingRepository = OnboardingRepository(
        snapshotStore: snapshotStore,
        flowStore: flowStore,
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'M1 exposes four low-pressure age ranges and parses legacy wire values',
      () {
        expect(OnboardingAgeBucket.values, <OnboardingAgeBucket>[
          OnboardingAgeBucket.zeroToSix,
          OnboardingAgeBucket.sevenToTwelve,
          OnboardingAgeBucket.oneToTwo,
          OnboardingAgeBucket.twoToThree,
        ]);
        expect(
          parseOnboardingAgeBucket('6-12'),
          OnboardingAgeBucket.sevenToTwelve,
        );
        expect(parseOnboardingAgeBucket('12-18'), OnboardingAgeBucket.oneToTwo);
        expect(parseOnboardingAgeBucket('18-24'), OnboardingAgeBucket.oneToTwo);
        expect(
          parseOnboardingAgeBucket('24-36'),
          OnboardingAgeBucket.twoToThree,
        );
      },
    );

    test(
      'new completion persists actual turn identity, preferences, goal, and trace',
      () async {
        final snapshot = await onboardingRepository.completeOnboarding(
          childDisplayName: '宝宝',
          ageBucket: OnboardingAgeBucket.oneToTwo,
          selectedSceneIds: const ['bath_time', 'bedtime'],
          supportGoal: OnboardingSupportGoal.moreNatural,
          starterSpaceId: 'family_rhythm',
          starterActivityId: 'bedtime',
          starterPhraseId: 'bedtime_dim_the_lights',
          firstTraceEventKey: 'install_onboarding_test:evt_onboarding_first',
          completedAt: DateTime.utc(2026, 7, 23, 12),
        );

        expect(snapshot.schemaVersion, 2);
        expect(snapshot.selectedSceneIds, ['bath_time', 'bedtime']);
        expect(snapshot.supportGoal, OnboardingSupportGoal.moreNatural);
        expect(snapshot.starterSpaceId, 'family_rhythm');
        expect(snapshot.starterActivityId, 'bedtime');
        expect(snapshot.starterPhraseId, 'bedtime_dim_the_lights');
        expect(
          snapshot.firstTraceEventKey,
          'install_onboarding_test:evt_onboarding_first',
        );
        expect(snapshot.isCompleted, isTrue);
      },
    );

    test('new completion rejects missing real trace identity', () async {
      await expectLater(
        onboardingRepository.completeOnboarding(
          childDisplayName: '宝宝',
          ageBucket: OnboardingAgeBucket.zeroToSix,
          selectedSceneIds: const ['bath_time'],
          supportGoal: OnboardingSupportGoal.firstWords,
          starterSpaceId: 'daily_care',
          starterActivityId: 'bath_time',
          starterPhraseId: 'bath_time_warm_water',
          firstTraceEventKey: '   ',
        ),
        throwsFormatException,
      );
    });

    test('完成 onboarding 时写入本地 snapshot，阶段映射与实际第一轮保持一致', () async {
      final snapshot = await onboardingRepository.completeOnboarding(
        childDisplayName: '小满',
        ageBucket: OnboardingAgeBucket.sevenToTwelve,
        selectedSceneIds: const ['bath_time'],
        supportGoal: OnboardingSupportGoal.firstWords,
        starterSpaceId: 'daily_care',
        starterActivityId: 'bath_time',
        starterPhraseId: 'bath_time_warm_water',
        firstTraceEventKey: 'install_onboarding_test:evt_onboarding_first',
        completedAt: DateTime.utc(2026, 4, 8, 8),
      );
      final restored = await onboardingRepository.readCompletedSnapshot();
      final storedFile = File(
        '${tempDir.path}${Platform.pathSeparator}onboarding_snapshot.json',
      );
      final storedJson = await storedFile.readAsString();

      expect(snapshot.childDisplayName, '小满');
      expect(snapshot.ageBucket, OnboardingAgeBucket.sevenToTwelve);
      expect(snapshot.approxMonths, 9);
      expect(snapshot.currentStage, 'sound_turn_taking');
      expect(snapshot.starterSpaceId, 'daily_care');
      expect(snapshot.starterActivityId, 'bath_time');
      expect(snapshot.starterPhraseId, 'bath_time_warm_water');
      expect(snapshot.consentState, OnboardingConsentState.localOnly);
      expect(snapshot.completedAt, DateTime.utc(2026, 4, 8, 8));
      expect(restored?.toJsonMap(), snapshot.toJsonMap());

      expect(storedJson, contains('"childDisplayName":"小满"'));
      expect(storedJson, contains('"ageBucket":"7-12"'));
      expect(storedJson, contains('"schemaVersion":2'));
      expect(
        storedJson,
        contains(
          '"firstTraceEventKey":"install_onboarding_test:evt_onboarding_first"',
        ),
      );
      expect(storedJson, isNot(contains('localEventId')));
      expect(storedJson, isNot(contains('reactionType')));
    });

    test('损坏或未知月龄档 snapshot 会被清空并回到 onboarding', () async {
      final file = File(
        '${tempDir.path}${Platform.pathSeparator}onboarding_snapshot.json',
      );
      await file.writeAsString(
        '{"childDisplayName":"米米","ageBucket":"99-100","approxMonths":99,"currentStage":"sound_turn_taking","starterSpaceId":"daily_care","starterActivityId":"bath_time","starterPhraseId":"bath_time_warm_water","completedAt":"2026-04-08T08:00:00.000Z","consentState":"local_only"}',
        flush: true,
      );

      final restored = await onboardingRepository.readCompletedSnapshot();

      expect(restored, isNull);
      expect(await file.exists(), isFalse);
    });

    test('incomplete snapshot 不会被视为 completed snapshot', () async {
      await onboardingRepository.saveSnapshot(
        OnboardingSnapshot(
          childDisplayName: '   ',
          ageBucket: OnboardingAgeBucket.zeroToSix,
          approxMonths: 3,
          currentStage: 'warm_routines',
          starterSpaceId: 'daily_care',
          starterActivityId: 'bath_time',
          starterPhraseId: 'bath_time_warm_water',
          consentState: OnboardingConsentState.localOnly,
          completedAt: DateTime.utc(2026, 4, 8, 8),
        ),
      );

      final rawSnapshot = await onboardingRepository.readSnapshot();
      final completedSnapshot = await onboardingRepository
          .readCompletedSnapshot();

      expect(rawSnapshot, isNotNull);
      expect(rawSnapshot!.isCompleted, isFalse);
      expect(completedSnapshot, isNull);
    });

    test('目录不可用时暴露明确的 snapshot 持久化错误', () async {
      final brokenStore = OnboardingSnapshotStore(
        directoryResolver: () async => throw StateError('disk denied'),
      );
      final repository = OnboardingRepository(
        snapshotStore: brokenStore,
        flowStore: flowStore,
      );

      await expectLater(
        repository.completeOnboarding(
          childDisplayName: '小满',
          ageBucket: OnboardingAgeBucket.zeroToSix,
          selectedSceneIds: const ['bath_time'],
          supportGoal: OnboardingSupportGoal.firstWords,
          starterSpaceId: 'daily_care',
          starterActivityId: 'bath_time',
          starterPhraseId: 'bath_time_warm_water',
          firstTraceEventKey: 'install_onboarding_test:evt_onboarding_first',
        ),
        throwsA(
          isA<OnboardingSnapshotPersistenceException>().having(
            (error) => error.message,
            'message',
            contains('写入 onboarding snapshot 失败'),
          ),
        ),
      );
    });
  });
}
