import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mobile/core/device/installation_id_service.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
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

  group('AccountRepository', () {
    late _AccountRepositoryHarness harness;

    setUp(() async {
      harness = await _AccountRepositoryHarness.create();
    });

    tearDown(() async {
      await harness.dispose();
    });

    test('signIn 会 bootstrap + ack 本地 pending，并保持 append-only 恢复结果', () async {
      await harness.practiceRepository.recordReaction(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'bath_time_warm_water',
        reactionType: BabyReactionType.engaged,
        clientTimestamp: DateTime.utc(2026, 4, 9, 2, 0),
        localEventId: 'evt_local_1',
      );
      harness.api.bootstrapEvents = [
        InteractionEventPayload(
          localEventId: 'evt_server_1',
          installationId: harness.installationId,
          spaceId: 'daily_care',
          activityId: 'bath_time',
          phraseId: 'bath_time_splash_splash',
          reactionType: BabyReactionType.calm,
          clientTimestamp: DateTime.utc(2026, 4, 9, 1, 59),
          syncState: InteractionSyncState.synced,
          lastSyncPhase: 'bootstrap_import',
          lastSyncAt: DateTime.utc(2026, 4, 9, 2),
        ),
      ];

      final repository = harness.buildRepository();
      final snapshot = await repository.signIn(
        phoneNumber: '13800138000',
        verificationCode: '246810',
      );

      expect(snapshot.consentState, AccountConsentState.acceptedPendingSync);
      expect(snapshot.session?.maskedPhoneNumber, '138****8000');
      expect(snapshot.pendingSyncCount, 0);
      expect(snapshot.syncedCount, 2);
      expect(snapshot.failedCount, 0);
      expect(snapshot.lastSyncPhase, 'batch_ack_applied');
      expect(snapshot.lastVisibleError, isNull);
      expect(harness.api.syncedBatches, hasLength(1));
      expect(harness.api.syncedBatches.single, hasLength(1));
      expect(
        harness.api.syncedBatches.single.single.eventKey,
        '${harness.installationId}:evt_local_1',
      );
      expect(
        harness.api.syncedBatches.single.single.toJsonMap().keys,
        isNot(contains('syncState')),
      );

      final history = await harness.practiceRepository.listEventHistory(
        activityId: 'bath_time',
      );
      expect(history, hasLength(2));
      expect(
        history.map((event) => event.syncState),
        everyElement(InteractionSyncState.synced),
      );

      final restore = await harness.practiceRepository.restorePracticeState(
        spaceId: 'daily_care',
        activityId: 'bath_time',
      );
      expect(restore.homeSummary.totalEvents, 2);
      expect(restore.resumeInfo.completedCount, 2);
      expect(restore.homeSummary.recentResult?.phraseEnglish, 'Warm water.');
    });

    test('离线重试会保留 pending 并暴露可见错误', () async {
      await harness.practiceRepository.recordReaction(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'bath_time_warm_water',
        reactionType: BabyReactionType.engaged,
        clientTimestamp: DateTime.utc(2026, 4, 9, 3),
        localEventId: 'evt_pending_offline',
      );
      final seedSnapshot = await harness.seedSignedInSnapshot();
      final repository = harness.buildRepository(connectivity: false);

      final snapshot = await repository.refreshRuntimeState(
        trigger: AccountRuntimeTrigger.manualRetry,
        seedSnapshot: seedSnapshot,
      );

      expect(snapshot.pendingSyncCount, 1);
      expect(snapshot.syncedCount, 0);
      expect(snapshot.failedCount, 0);
      expect(snapshot.lastSyncPhase, 'manual_retry_offline');
      expect(snapshot.lastVisibleError, contains('当前离线'));
      expect(
        await harness.practiceRepository.listPendingUploadRecords(),
        hasLength(1),
      );
      expect(harness.api.syncedBatches, isEmpty);
    });

    test('426 会转成升级提示且不清空本地 pending', () async {
      await harness.practiceRepository.recordReaction(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        phraseId: 'bath_time_all_clean',
        reactionType: BabyReactionType.calm,
        clientTimestamp: DateTime.utc(2026, 4, 9, 4),
        localEventId: 'evt_upgrade_required',
      );
      await harness.seedSignedInSnapshot();
      harness.api.throwVersionBlockedOnBootstrap = true;
      final repository = harness.buildRepository();

      final snapshot = await repository.refreshRuntimeState(
        trigger: AccountRuntimeTrigger.manualRetry,
      );

      expect(snapshot.pendingSyncCount, 1);
      expect(snapshot.lastSyncPhase, 'bootstrap_failed_upgrade_required_426');
      expect(snapshot.lastVisibleError, contains('最低需要 9.9.9'));
      expect(
        await harness.practiceRepository.listPendingUploadRecords(),
        hasLength(1),
      );
      expect(harness.api.syncedBatches, isEmpty);
    });
  });
}

class _AccountRepositoryHarness {
  _AccountRepositoryHarness({
    required this.tempDir,
    required this.localDataSource,
    required this.practiceRepository,
    required this.accountLocalStore,
    required this.assetPhraseService,
    required this.installationId,
    required this.api,
  });

  final Directory tempDir;
  final PracticeLocalDataSource localDataSource;
  final PracticeRepository practiceRepository;
  final AccountLocalStore accountLocalStore;
  final AssetPhraseService assetPhraseService;
  final String installationId;
  final _FakeAccountApiService api;

  static Future<_AccountRepositoryHarness> create() async {
    final tempDir = await Directory.systemTemp.createTemp(
      'account_repository_test_',
    );
    final localDataSource = await PracticeLocalDataSource.open(
      directory: tempDir.path,
      name: 'account_repository_${DateTime.now().microsecondsSinceEpoch}',
    );
    final assetPhraseService = AssetPhraseService(bundle: rootBundle);
    const installationId = 'install_account_repository_test';
    final installationIdService = InstallationIdService(
      directoryResolver: () async => tempDir,
      idGenerator: () => installationId,
    );
    await installationIdService.getOrCreate();
    final practiceRepository = PracticeRepository(
      assetPhraseService: assetPhraseService,
      localDataSource: localDataSource,
      installationIdService: installationIdService,
    );
    final accountLocalStore = AccountLocalStore(
      directoryResolver: () async => tempDir,
    );
    return _AccountRepositoryHarness(
      tempDir: tempDir,
      localDataSource: localDataSource,
      practiceRepository: practiceRepository,
      accountLocalStore: accountLocalStore,
      assetPhraseService: assetPhraseService,
      installationId: installationId,
      api: _FakeAccountApiService(installationId: installationId),
    );
  }

  AccountRepository buildRepository({bool connectivity = true}) {
    return AccountRepository(
      localStore: accountLocalStore,
      practiceRepository: practiceRepository,
      apiService: api,
      connectivityChecker: () async => connectivity,
    );
  }

  Future<AccountLocalSnapshot> seedSignedInSnapshot() async {
    final syncSummary = await practiceRepository.getSyncSummary();
    final snapshot = AccountLocalSnapshot(
      consentState: AccountConsentState.acceptedPendingSync,
      session: AccountSession(
        accountId: 'acct_test',
        sessionId: 'sess_seed',
        maskedPhoneNumber: '138****8000',
        createdAt: DateTime.utc(2026, 4, 9, 2),
      ),
      challenge: AccountChallengePlaceholder(
        maskedPhoneNumber: '138****8000',
        codeLength: 6,
        issuedAt: DateTime.utc(2026, 4, 9, 2),
      ),
      pendingSyncCount: syncSummary.pendingCount,
      syncedCount: syncSummary.syncedCount,
      failedCount: syncSummary.failedCount,
      lastSyncPhase: syncSummary.lastSyncPhase ?? 'seed_signed_in',
      lastSyncAt: syncSummary.lastEventAt,
    );
    await accountLocalStore.write(snapshot);
    return snapshot;
  }

  Future<void> dispose() async {
    await practiceRepository.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
}

class _FakeAccountApiService extends AccountApiService {
  _FakeAccountApiService({required this.installationId}) : super();

  final String installationId;
  final List<List<InteractionEventUploadRecord>> syncedBatches = [];
  List<InteractionEventPayload> bootstrapEvents = [];
  bool throwVersionBlockedOnBootstrap = false;

  @override
  Future<AccountChallengeResponse> createChallenge({
    required String phoneNumber,
  }) async {
    return AccountChallengeResponse(
      challengeId: 'challenge_1',
      maskedPhoneNumber: '138****8000',
      codeLength: 6,
      expiresAt: DateTime.utc(2026, 4, 9, 2, 5),
    );
  }

  @override
  Future<AccountSessionResponse> verifyChallenge({
    required String challengeId,
    required String verificationCode,
    required String installationId,
  }) async {
    expect(challengeId, 'challenge_1');
    expect(verificationCode, '246810');
    expect(installationId, this.installationId);
    return AccountSessionResponse(
      accountId: 'acct_test',
      sessionId: 'sess_live',
      maskedPhoneNumber: '138****8000',
      createdAt: DateTime.utc(2026, 4, 9, 2, 1),
      consentStatus: 'signed_out',
    );
  }

  @override
  Future<AccountConsentResponse> acceptConsent({
    required String sessionId,
    required String consentVersion,
  }) async {
    expect(sessionId, isNotEmpty);
    expect(consentVersion, 'pipl-v1');
    return AccountConsentResponse(
      applied: true,
      result: 'applied',
      consentStatus: 'accepted',
      updatedAt: DateTime.utc(2026, 4, 9, 2, 1, 30),
    );
  }

  @override
  Future<BootstrapResponse> bootstrap({
    required String sessionId,
    required String installationId,
  }) async {
    expect(sessionId, isNotEmpty);
    expect(installationId, this.installationId);
    if (throwVersionBlockedOnBootstrap) {
      throw const AccountApiException(
        kind: AccountApiFailureKind.http,
        message: 'version blocked',
        statusCode: 426,
        code: 'app_version_required',
        minimumSupportedVersion: '9.9.9',
      );
    }
    return BootstrapResponse(
      consentStatus: 'accepted',
      eventCount: bootstrapEvents.length,
      events: List<InteractionEventPayload>.unmodifiable(bootstrapEvents),
      bootstrapAt: DateTime.utc(2026, 4, 9, 2, 2),
    );
  }

  @override
  Future<SyncEventsResponse> syncEvents({
    required String sessionId,
    required String installationId,
    required List<InteractionEventUploadRecord> events,
  }) async {
    expect(sessionId, isNotEmpty);
    expect(installationId, this.installationId);
    syncedBatches.add(List<InteractionEventUploadRecord>.unmodifiable(events));
    return SyncEventsResponse(
      receivedCount: events.length,
      acceptedCount: events.length,
      duplicateCount: 0,
      acceptedEventKeys: events.map((event) => event.eventKey).toList(),
      duplicateEventKeys: const [],
      syncedAt: DateTime.utc(2026, 4, 9, 2, 3),
    );
  }

  @override
  Future<AccountConsentResponse> revokeConsent({
    required String sessionId,
    required String reason,
  }) async {
    return AccountConsentResponse(
      applied: true,
      result: 'applied',
      consentStatus: 'revoked',
      updatedAt: DateTime.utc(2026, 4, 9, 2, 4),
    );
  }

  @override
  Future<AccountDeleteResponse> deleteAccount({
    required String sessionId,
    required String reason,
  }) async {
    return AccountDeleteResponse(
      applied: true,
      result: 'applied',
      deletedEventCount: 0,
      updatedAt: DateTime.utc(2026, 4, 9, 2, 5),
    );
  }

  @override
  Future<void> close() async {}
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
