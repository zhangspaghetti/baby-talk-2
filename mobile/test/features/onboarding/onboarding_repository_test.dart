import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import '../../support/isar_test_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): resolveBundledIsarLibraryPath()},
    );
  });

  group('OnboardingRepository', () {
    late Directory tempDir;
    late String dbName;
    late PracticeLocalDataSource localDataSource;
    late PracticeRepository practiceRepository;
    late OnboardingSnapshotStore snapshotStore;
    late OnboardingRepository onboardingRepository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'onboarding_repository_test_',
      );
      dbName = 'onboarding_${DateTime.now().microsecondsSinceEpoch}';
      localDataSource = await PracticeLocalDataSource.open(
        directory: tempDir.path,
        name: dbName,
      );
      practiceRepository = PracticeRepository(
        assetPhraseService: AssetPhraseService(bundle: rootBundle),
        localDataSource: localDataSource,
        installationIdService: InstallationIdService(
          directoryResolver: () async => tempDir,
          idGenerator: () => 'install_onboarding_test',
        ),
      );
      snapshotStore = OnboardingSnapshotStore(
        directoryResolver: () async => tempDir,
      );
      onboardingRepository = OnboardingRepository(
        snapshotStore: snapshotStore,
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

    test(
      'legacy completion preserves legacy snapshot without M1 trace proof',
      () async {
        final snapshot = await onboardingRepository.completeLegacyOnboarding(
          childDisplayName: '宝宝',
          ageBucket: OnboardingAgeBucket.zeroToSix,
          completedAt: DateTime.utc(2026, 7, 23, 12),
        );

        expect(snapshot.schemaVersion, 1);
        expect(snapshot.firstTraceEventKey, isNull);
        expect(snapshot.isCompleted, isTrue);
      },
    );

    test('完成 onboarding 时写入本地 snapshot，阶段映射与实际第一轮来自真实内容', () async {
      final starterSeed = await onboardingRepository.resolveStarterSeed();
      final snapshot = await onboardingRepository.completeOnboarding(
        childDisplayName: '小满',
        ageBucket: OnboardingAgeBucket.sevenToTwelve,
        selectedSceneIds: const ['bath_time'],
        supportGoal: OnboardingSupportGoal.firstWords,
        starterSpaceId: starterSeed.spaceId,
        starterActivityId: starterSeed.activityId,
        starterPhraseId: starterSeed.phraseId,
        firstTraceEventKey: 'install_onboarding_test:evt_onboarding_first',
        completedAt: DateTime.utc(2026, 4, 8, 8),
      );
      final restored = await onboardingRepository.readCompletedSnapshot();
      final inspection = await practiceRepository.inspectEventLog();
      final storedFile = File(
        '${tempDir.path}${Platform.pathSeparator}onboarding_snapshot.json',
      );
      final storedJson = await storedFile.readAsString();

      expect(starterSeed.spaceId, 'daily_care');
      expect(starterSeed.activityId, 'bath_time');
      expect(starterSeed.phraseId, 'bath_time_warm_water');
      expect(starterSeed.phraseEnglish, 'Warm water.');
      expect(
        starterSeed.audioAssetSource,
        'audio/phrases/bath_time_warm_water.mp3',
      );

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

      expect(inspection.storedEventCount, 0);
      expect(inspection.validEventCount, 0);
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

    test(
      'completion trusts actual turn instead of configured starter seed',
      () async {
        final invalidBundleRepository = await _createPracticeRepository(
          directory: tempDir,
          dbName: '${dbName}_invalid_seed',
          bundle: _FakeAssetBundle(
            strings: const {
              'assets/content/seed_content.json':
                  '{"spaces":[{"id":"daily_care","title":"日常照护","description":"desc","activities":[{"id":"bath_time","title":"洗澡时间","summary":"summary","sceneTag":"Bath time","coachTip":"tip","phrases":[{"id":"bath_time_warm_water","step":1,"english":"","chinese":"温温的水。","pronunciation":"warm","difficulty":"starter","audioAsset":"assets/audio/phrases/bath_time_warm_water.mp3"}]}]}]}',
            },
            binaryAssets: const {
              'assets/audio/phrases/bath_time_warm_water.mp3',
            },
          ),
        );
        addTearDown(() => invalidBundleRepository.close(deleteFromDisk: true));
        final repository = OnboardingRepository(
          snapshotStore: snapshotStore,
          practiceRepository: invalidBundleRepository.repository,
          starterSpaceId: 'daily_care',
          starterActivityId: 'bath_time',
        );

        final snapshot = await repository.completeOnboarding(
          childDisplayName: '小满',
          ageBucket: OnboardingAgeBucket.zeroToSix,
          selectedSceneIds: const ['bath_time'],
          supportGoal: OnboardingSupportGoal.firstWords,
          starterSpaceId: 'daily_care',
          starterActivityId: 'bath_time',
          starterPhraseId: 'bath_time_warm_water',
          firstTraceEventKey: 'install_onboarding_test:evt_onboarding_first',
        );

        expect(snapshot.starterPhraseId, 'bath_time_warm_water');
      },
    );

    test('目录不可用时暴露明确的 snapshot 持久化错误', () async {
      final brokenStore = OnboardingSnapshotStore(
        directoryResolver: () async => throw StateError('disk denied'),
      );
      final repository = OnboardingRepository(
        snapshotStore: brokenStore,
        practiceRepository: practiceRepository,
        starterSpaceId: 'daily_care',
        starterActivityId: 'bath_time',
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

class _PracticeRepositoryHarness {
  const _PracticeRepositoryHarness({
    required this.localDataSource,
    required this.repository,
  });

  final PracticeLocalDataSource localDataSource;
  final PracticeRepository repository;

  Future<void> close({bool deleteFromDisk = false}) async {
    await localDataSource.close(deleteFromDisk: deleteFromDisk);
  }
}

Future<_PracticeRepositoryHarness> _createPracticeRepository({
  required Directory directory,
  required String dbName,
  required AssetBundle bundle,
}) async {
  final localDataSource = await PracticeLocalDataSource.open(
    directory: directory.path,
    name: dbName,
  );
  final repository = PracticeRepository(
    assetPhraseService: AssetPhraseService(bundle: bundle),
    localDataSource: localDataSource,
    installationIdService: InstallationIdService(
      directoryResolver: () async => directory,
      idGenerator: () => 'install_onboarding_test',
    ),
  );
  return _PracticeRepositoryHarness(
    localDataSource: localDataSource,
    repository: repository,
  );
}

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle({required this.strings, required this.binaryAssets});

  final Map<String, String> strings;
  final Set<String> binaryAssets;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final value = strings[key];
    if (value == null) {
      throw StateError('Missing string asset: $key');
    }
    return value;
  }

  @override
  Future<ByteData> load(String key) async {
    if (!binaryAssets.contains(key)) {
      throw StateError('Missing binary asset: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(const [1, 2, 3]));
  }
}
