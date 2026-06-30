import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/app/local_sensitive_data_clearance_registry.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/core/local_data_lifecycle/local_sensitive_data_clearance.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/data/repositories/household_repository.dart';
import 'package:mobile/features/household/data/services/household_api_service.dart';
import 'package:mobile/features/household/domain/models/household_role.dart';
import 'package:mobile/features/mentor/data/local/mentor_local_data_source.dart';
import 'package:mobile/features/mentor/data/repositories/mentor_repository.dart';
import 'package:mobile/features/mentor/domain/models/mentor_fact_event.dart';
import 'package:mobile/features/onboarding/data/local/onboarding_snapshot_store.dart';
import 'package:mobile/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/data/local/practice_local_data_source.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/data/services/asset_phrase_service.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {Abi.current(): _resolveBundledIsarLibraryPath()},
    );
  });

  group('createLocalSensitiveDataClearanceOrchestrator', () {
    late _LifecycleHarness harness;

    setUp(() async {
      harness = await _LifecycleHarness.create();
      await harness.seedSensitiveData();
    });

    tearDown(() async {
      await harness.dispose();
    });

    test(
      'registers one real-store clearance step for each lifecycle target',
      () {
        final steps = createLocalSensitiveDataClearanceSteps(
          accountRepository: harness.accountRepository,
          onboardingRepository: harness.onboardingRepository,
          householdRepository: harness.householdRepository,
          practiceRepository: harness.practiceRepository,
          mentorRepository: harness.mentorRepository,
        );

        expect(
          steps.map((step) => step.target),
          LocalSensitiveDataTarget.values,
        );
        expect(
          steps.map((step) => step.primitiveName),
          everyElement(isNotEmpty),
        );
      },
    );

    test(
      'rejects destructive real-store clearance without Staff+ approval',
      () async {
        final orchestrator = createLocalSensitiveDataClearanceOrchestrator(
          accountRepository: harness.accountRepository,
          onboardingRepository: harness.onboardingRepository,
          householdRepository: harness.householdRepository,
          practiceRepository: harness.practiceRepository,
          mentorRepository: harness.mentorRepository,
        );

        final report = await orchestrator.clear(
          LocalSensitiveDataClearanceRequest(
            trigger:
                LocalSensitiveDataClearanceTrigger.accountDeletionConfirmed,
            authorization: const ReportOnlyAuthorization(
              reason: 'missing Staff+ approval',
            ),
            correlationId: 'r038-rejected',
            requestedAt: DateTime.utc(2026, 5, 20, 10),
          ),
        );

        expect(
          report.overallStatus,
          LocalSensitiveDataClearanceOverallStatus.rejectedByGovernance,
        );
        expect(await harness.accountSnapshotIsStored(), isTrue);
        expect(await harness.onboardingSnapshotStore.read(), isNotNull);
        expect((await harness.householdLocalStore.read()).householdId, 'hh_1');
        expect(
          (await harness.practiceRepository.inspectEventLog()).storedEventCount,
          1,
        );
        expect(
          (await harness.mentorRepository.inspectFactLog()).storedFactCount,
          1,
        );
        expect(
          await harness.installationIdService.readExisting(),
          'install_lifecycle',
        );
      },
    );

    test(
      'clears all registered local stores with Staff+ destructive approval',
      () async {
        final orchestrator = createLocalSensitiveDataClearanceOrchestrator(
          accountRepository: harness.accountRepository,
          onboardingRepository: harness.onboardingRepository,
          householdRepository: harness.householdRepository,
          practiceRepository: harness.practiceRepository,
          mentorRepository: harness.mentorRepository,
        );

        final report = await orchestrator.clear(
          LocalSensitiveDataClearanceRequest(
            trigger:
                LocalSensitiveDataClearanceTrigger.accountDeletionConfirmed,
            authorization: StaffPlusDestructiveAuthorization(
              decisionId: 'HDR-R4-LOCAL-LIFECYCLE-TEST',
              approvedBy: 'automated-test',
              approvedAt: DateTime.utc(2026, 5, 20, 10),
              confirmationText: 'Clear local sensitive data in test sandbox',
            ),
            correlationId: 'r038-approved',
            requestedAt: DateTime.utc(2026, 5, 20, 10),
          ),
        );

        expect(
          report.overallStatus,
          LocalSensitiveDataClearanceOverallStatus.completed,
        );
        expect(
          report.results.map((result) => result.status).toSet(),
          <LocalSensitiveDataTargetStatus>{
            LocalSensitiveDataTargetStatus.attemptedAndSucceeded,
          },
        );
        expect(await harness.accountSnapshotIsStored(), isFalse);
        expect(await harness.onboardingSnapshotStore.read(), isNull);
        expect(
          await harness.householdLocalStore.read(),
          HouseholdLocalSnapshot.empty,
        );
        expect(await harness.reopenedPracticeEventCount(), 0);
        expect(await harness.reopenedMentorFactCount(), 0);
        expect(await harness.installationIdService.readExisting(), isNull);
      },
    );
  });
}

class _LifecycleHarness {
  _LifecycleHarness._({
    required this.tempDir,
    required this.practiceDbName,
    required this.mentorDbName,
    required this.secureStorage,
    required this.accountLocalStore,
    required this.onboardingSnapshotStore,
    required this.householdLocalStore,
    required this.installationIdService,
    required this.practiceRepository,
    required this.onboardingRepository,
    required this.accountRepository,
    required this.householdRepository,
    required this.mentorRepository,
  });

  final Directory tempDir;
  final String practiceDbName;
  final String mentorDbName;
  final _InMemorySecureStorage secureStorage;
  final AccountLocalStore accountLocalStore;
  final OnboardingSnapshotStore onboardingSnapshotStore;
  final HouseholdLocalStore householdLocalStore;
  final InstallationIdService installationIdService;
  final PracticeRepository practiceRepository;
  final OnboardingRepository onboardingRepository;
  final AccountRepository accountRepository;
  final HouseholdRepository householdRepository;
  final MentorRepository mentorRepository;

  static Future<_LifecycleHarness> create() async {
    final tempDir = await Directory.systemTemp.createTemp(
      'local_sensitive_data_clearance_',
    );
    final practiceDbName = 'practice_${DateTime.now().microsecondsSinceEpoch}';
    final mentorDbName = 'mentor_${DateTime.now().microsecondsSinceEpoch}';
    final installationIdService = InstallationIdService(
      directoryResolver: () async => tempDir,
      idGenerator: () => 'install_lifecycle',
    );
    final practiceRepository = PracticeRepository(
      assetPhraseService: AssetPhraseService(bundle: rootBundle),
      localDataSource: await PracticeLocalDataSource.open(
        directory: tempDir.path,
        name: practiceDbName,
      ),
      installationIdService: installationIdService,
    );
    final onboardingSnapshotStore = OnboardingSnapshotStore(
      directoryResolver: () async => tempDir,
    );
    final onboardingRepository = OnboardingRepository(
      snapshotStore: onboardingSnapshotStore,
      practiceRepository: practiceRepository,
      starterSpaceId: 'daily_care',
      starterActivityId: 'bath_time',
    );
    final secureStorage = _InMemorySecureStorage();
    final accountLocalStore = AccountLocalStore(
      secureStorage: secureStorage,
      storageKey: 'lifecycle_account',
    );
    final accountRepository = AccountRepository(
      localStore: accountLocalStore,
      practiceRepository: practiceRepository,
    );
    final householdLocalStore = HouseholdLocalStore(
      directoryResolver: () async => tempDir,
    );
    final householdRepository = HouseholdRepository(
      localStore: householdLocalStore,
      apiService: HouseholdApiService(baseUrl: 'http://127.0.0.1:1'),
      accountSnapshotLoader: accountRepository.loadSnapshot,
      persistRefreshedSession: accountRepository.persistRefreshedSession,
    );
    final mentorRepository = MentorRepository(
      localDataSource: await MentorLocalDataSource.open(
        directory: tempDir.path,
        name: mentorDbName,
      ),
      practiceRepository: practiceRepository,
      onboardingSnapshotStore: onboardingSnapshotStore,
      householdSnapshotLoader: householdRepository.loadSnapshot,
    );
    return _LifecycleHarness._(
      tempDir: tempDir,
      practiceDbName: practiceDbName,
      mentorDbName: mentorDbName,
      secureStorage: secureStorage,
      accountLocalStore: accountLocalStore,
      onboardingSnapshotStore: onboardingSnapshotStore,
      householdLocalStore: householdLocalStore,
      installationIdService: installationIdService,
      practiceRepository: practiceRepository,
      onboardingRepository: onboardingRepository,
      accountRepository: accountRepository,
      householdRepository: householdRepository,
      mentorRepository: mentorRepository,
    );
  }

  Future<void> seedSensitiveData() async {
    await accountLocalStore.write(AccountLocalSnapshot.localOnly);
    await onboardingSnapshotStore.write(_completedSnapshot());
    await householdLocalStore.write(
      const HouseholdLocalSnapshot(
        householdId: 'hh_1',
        role: HouseholdRole.primaryCaregiver,
        lastPhase: 'ready',
      ),
    );
    await practiceRepository.recordReaction(
      spaceId: 'daily_care',
      activityId: 'bath_time',
      phraseId: 'bath_time_warm_water',
      reactionType: BabyReactionType.cooperating,
      clientTimestamp: DateTime.utc(2026, 5, 20, 10),
      localEventId: 'lifecycle_practice_1',
    );
    await mentorRepository.appendFact(
      eventType: MentorFactType.panelOpened,
      phase: 'opened',
      createdAt: DateTime.utc(2026, 5, 20, 10, 1),
      localEventId: 'lifecycle_mentor_1',
    );
  }

  Future<bool> accountSnapshotIsStored() {
    return secureStorage.hasStoredKey(accountLocalStore.storageKey);
  }

  Future<int> reopenedPracticeEventCount() async {
    final dataSource = await PracticeLocalDataSource.open(
      directory: tempDir.path,
      name: practiceDbName,
    );
    try {
      return (await dataSource.listRawEntities()).length;
    } finally {
      await dataSource.close(deleteFromDisk: true);
    }
  }

  Future<int> reopenedMentorFactCount() async {
    final dataSource = await MentorLocalDataSource.open(
      directory: tempDir.path,
      name: mentorDbName,
    );
    try {
      return (await dataSource.listRawEntities()).length;
    } finally {
      await dataSource.close(deleteFromDisk: true);
    }
  }

  Future<void> dispose() async {
    await accountRepository.close();
    await householdRepository.close();
    await mentorRepository.close(deleteFromDisk: true);
    await practiceRepository.close(deleteFromDisk: true);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
}

OnboardingSnapshot _completedSnapshot() {
  return OnboardingSnapshot(
    childDisplayName: '米米',
    ageBucket: OnboardingAgeBucket.twelveToEighteen,
    approxMonths: 15,
    currentStage: 'gesture_plus_words',
    starterSpaceId: 'daily_care',
    starterActivityId: 'bath_time',
    starterPhraseId: 'bath_time_warm_water',
    consentState: OnboardingConsentState.localOnly,
    completedAt: DateTime.utc(2026, 5, 20, 10),
  );
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

class _InMemorySecureStorage extends FlutterSecureStorage {
  _InMemorySecureStorage();

  final Map<String, String> _store = <String, String>{};

  Future<bool> hasStoredKey(String key) async => _store.containsKey(key);

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _store.containsKey(key);

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _store[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.remove(key);
  }
}
