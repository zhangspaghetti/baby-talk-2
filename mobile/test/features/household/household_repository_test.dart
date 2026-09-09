import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/data/repositories/household_repository.dart';
import 'package:mobile/features/household/data/services/household_api_service.dart';
import 'package:mobile/features/household/domain/models/household_invite_link.dart';
import 'package:mobile/features/household/domain/models/household_role.dart';
import 'package:mobile/features/household/domain/models/household_shared_context.dart';
import 'package:mobile/features/practice/data/local/preset_scene_catalog_store.dart';
import 'package:mobile/features/practice/domain/models/preset_scene_definition.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('household API diagnostics do not render private server messages', () {
    const error = HouseholdApiException(
      kind: HouseholdApiFailureKind.http,
      message: '宝宝米米 phone 13800138000 token secret household_a',
      statusCode: 403,
      code: 'role_not_allowed',
    );

    expect(error.toString(), isNot(contains('米米')));
    expect(error.toString(), isNot(contains('13800138000')));
    expect(error.toString(), isNot(contains('secret')));
    expect(error.toString(), isNot(contains('household_a')));
  });

  group('HouseholdRepository', () {
    late _HouseholdRepositoryHarness harness;

    setUp(() async {
      harness = await _HouseholdRepositoryHarness.create();
    });

    tearDown(() async {
      await harness.dispose();
    });

    test(
      'acceptInvite 会持久化 household snapshot，并把 route args 收口到既有 PracticeRouteArgs seam',
      () async {
        harness.api.acceptResponse = HouseholdAcceptInviteResponse(
          householdId: 'household_1',
          role: HouseholdRole.caregiver,
          acceptedAt: DateTime.utc(2026, 4, 16, 12),
          sharedContext: _sharedContextResponse(),
        );

        final result = await harness.repository.acceptInvite(
          token: 'invite_token_1234',
          source: 'invite_link',
        );

        expect(result.shouldRouteToPractice, isTrue);
        expect(result.practiceArgs, isNotNull);
        expect(result.practiceArgs!.spaceId, 'daily_care');
        expect(result.practiceArgs!.activityId, 'bath_time');
        expect(result.practiceArgs!.shareToken, 'invite_token_1234');
        expect(
          result.practiceArgs!.entrySource,
          PracticeRouteEntrySource.inviteReentry,
        );
        expect(result.snapshot.householdId, 'household_1');
        expect(result.snapshot.role, HouseholdRole.caregiver);
        expect(result.snapshot.lastPhase, 'accept_ready');
        expect(result.snapshot.lastAcceptedAt, DateTime.utc(2026, 4, 16, 12));
        expect(harness.api.lastAcceptedSession?.accessToken, 'access_live');

        final persisted = await harness.localStore.read();
        expect(persisted.householdId, 'household_1');
        expect(persisted.role, HouseholdRole.caregiver);
        expect(persisted.sharedContext, isNotNull);
        expect(persisted.sharedContext!.practiceArgs.shareToken, isNull);
        expect(persisted.sharedContext!.practiceArgs.spaceId, 'daily_care');
        expect(persisted.lastAcceptedAt, DateTime.utc(2026, 4, 16, 12));
      },
    );

    test(
      'acceptInvite 的 expired / already_used / invalid_session / consent_required / 426 / unavailable 会映射到可见 phase',
      () async {
        final cases =
            <({HouseholdApiException error, String phase, String text})>[
              (
                error: const HouseholdApiException(
                  kind: HouseholdApiFailureKind.http,
                  message: 'expired',
                  statusCode: 410,
                  code: 'invite_expired',
                ),
                phase: 'accept_invite_expired',
                text: '过期',
              ),
              (
                error: const HouseholdApiException(
                  kind: HouseholdApiFailureKind.http,
                  message: 'already used',
                  statusCode: 409,
                  code: 'invite_already_used',
                ),
                phase: 'accept_invite_already_used',
                text: '已经被使用',
              ),
              (
                error: const HouseholdApiException(
                  kind: HouseholdApiFailureKind.http,
                  message: 'invalid session',
                  statusCode: 401,
                  code: 'invalid_session',
                ),
                phase: 'accept_invite_invalid_session',
                text: '登录已过期',
              ),
              (
                error: const HouseholdApiException(
                  kind: HouseholdApiFailureKind.http,
                  message: 'consent required',
                  statusCode: 409,
                  code: 'consent_required',
                ),
                phase: 'accept_invite_consent_required',
                text: '同意已撤回',
              ),
              (
                error: const HouseholdApiException(
                  kind: HouseholdApiFailureKind.http,
                  message: 'upgrade required',
                  statusCode: 426,
                  code: 'app_version_required',
                ),
                phase: 'accept_invite_upgrade_required_426',
                text: '版本过旧',
              ),
              (
                error: const HouseholdApiException(
                  kind: HouseholdApiFailureKind.http,
                  message: 'server boom',
                  statusCode: 503,
                  code: 'invite_storage_unavailable',
                  details: <String, Object?>{'retryable': true},
                ),
                phase: 'accept_invite_unavailable',
                text: '暂时不可用',
              ),
            ];

        for (final testCase in cases) {
          harness.api.acceptError = testCase.error;
          final result = await harness.repository.acceptInvite(
            token: 'invite_token_1234',
            source: 'invite_link',
          );
          expect(result.shouldRouteToPractice, isFalse);
          expect(result.snapshot.lastPhase, testCase.phase);
          expect(result.message, contains(testCase.text));
          harness.api.acceptError = null;
        }
      },
    );

    test(
      'malformed accept response 会保留最近稳定 shared snapshot 并停在安全 fallback',
      () async {
        await harness.localStore.write(
          HouseholdLocalSnapshot(
            householdId: 'household_seed',
            role: HouseholdRole.caregiver,
            sharedContext: _sharedContextResponse().snapshot,
            lastPhase: 'shared_context_ready',
            lastAcceptedAt: DateTime.utc(2026, 4, 15, 8),
          ),
        );
        harness.api.acceptError = const HouseholdApiException.malformed(
          message: 'missing practice args',
        );

        final result = await harness.repository.acceptInvite(
          token: 'invite_token_1234',
          source: 'invite_link',
        );

        expect(result.shouldRouteToPractice, isFalse);
        expect(result.snapshot.lastPhase, 'accept_invite_malformed_response');
        expect(result.message, contains('安全 fallback'));
        expect(result.snapshot.sharedContext, isNotNull);
        expect(
          result.snapshot.sharedContext!.practiceArgs.scopeLabel,
          'daily_care/bath_time',
        );
      },
    );

    test('旧 snapshot 缺失 household 字段时会兼容回退到 empty household state', () async {
      final file = File(
        '${harness.tempDir.path}${Platform.pathSeparator}${harness.localStore.fileName}',
      );
      await file.writeAsString(
        jsonEncode(<String, Object?>{'lastPhase': 'idle'}),
        flush: true,
      );

      final snapshot = await harness.repository.loadSnapshot();

      expect(snapshot.householdId, isNull);
      expect(snapshot.role, isNull);
      expect(snapshot.sharedContext, isNull);
      expect(snapshot.lastPhase, 'idle');
    });

    test('损坏的 local snapshot 会退回安全空态，而不是污染 account snapshot', () async {
      final file = File(
        '${harness.tempDir.path}${Platform.pathSeparator}${harness.localStore.fileName}',
      );
      await file.writeAsString('not-json', flush: true);

      final snapshot = await harness.repository.loadSnapshot();

      expect(snapshot.householdId, isNull);
      expect(snapshot.sharedContext, isNull);
      expect(snapshot.lastPhase, 'local_snapshot_reset');
      expect(snapshot.lastVisibleError, contains('安全空态'));
      expect(harness.accountSnapshot.session?.sessionId, 'sess_live');
    });

    test('refreshSharedContext 会复用 in-flight guard，避免重复请求', () async {
      harness.api.fetchResponse = _sharedContextResponse();

      final firstFuture = harness.repository.refreshSharedContext(
        reason: 'foreground_resume',
      );
      final secondFuture = harness.repository.refreshSharedContext(
        reason: 'foreground_resume',
      );

      final first = await firstFuture;
      final second = await secondFuture;

      expect(first.householdId, 'household_1');
      expect(second.householdId, 'household_1');
      expect(harness.api.fetchCallCount, 1);
      expect(harness.api.lastFetchedSession?.accessToken, 'access_live');
      expect(first.lastPhase, 'shared_context_ready');
      expect(second.lastPhase, 'shared_context_ready');
    });

    test('缺少 JWT token 时不会发送 protected household 请求', () async {
      harness.accountSnapshot = AccountLocalSnapshot(
        consentState: AccountConsentState.acceptedPendingSync,
        session: AccountSession(
          accountId: 'acct_live',
          sessionId: 'sess_legacy',
          maskedPhoneNumber: '138****8000',
          createdAt: DateTime.utc(2026, 4, 16, 10),
        ),
        lastSyncPhase: 'batch_ack_applied',
      );

      final snapshot = await harness.repository.refreshSharedContext(
        reason: 'foreground_resume',
      );

      expect(snapshot.lastPhase, 'shared_context_invalid_session');
      expect(snapshot.lastVisibleError, contains('重新登录'));
      expect(harness.api.fetchCallCount, 0);
    });

    test(
      'auth refresh failure preserves last durable household scope',
      () async {
        await harness.localStore.write(
          HouseholdLocalSnapshot(
            householdId: 'household_a',
            role: HouseholdRole.caregiver,
            sharedContext: _sharedContextResponse(
              householdId: 'household_a',
            ).snapshot,
            lastPhase: 'shared_context_ready',
          ),
        );
        harness.accountSnapshot = AccountLocalSnapshot(
          consentState: AccountConsentState.acceptedPendingSync,
          session: AccountSession(
            accountId: 'acct_live',
            sessionId: 'sess_legacy',
            maskedPhoneNumber: '138****8000',
            createdAt: DateTime.utc(2026, 4, 16, 10),
          ),
          lastSyncPhase: 'batch_ack_applied',
        );

        final snapshot = await harness.repository.refreshSharedContext();

        expect(snapshot.householdId, 'household_a');
        expect(snapshot.lastPhase, 'shared_context_invalid_session');
        expect(harness.clearedScopes, isEmpty);
        expect((await harness.localStore.read()).householdId, 'household_a');
        expect(harness.api.fetchCallCount, 0);
      },
    );

    test(
      'server confirms household transition only after durable snapshot write',
      () async {
        await harness.localStore.write(
          HouseholdLocalSnapshot(
            householdId: 'household_a',
            role: HouseholdRole.caregiver,
            sharedContext: _sharedContextResponse(
              householdId: 'household_a',
            ).snapshot,
            lastPhase: 'shared_context_ready',
          ),
        );
        harness.api.fetchResponse = _sharedContextResponse(
          householdId: 'household_b',
        );

        final result = await harness.repository.refreshSharedContext();

        expect(result.householdId, 'household_b');
        expect(harness.clearedScopes, <String>['household_a']);
        expect((await harness.localStore.read()).householdId, 'household_b');
      },
    );

    test(
      'membership transition does not clear public preset catalog cache',
      () async {
        final catalogStore = PresetSceneCatalogStore(
          directoryResolver: () async => harness.tempDir,
        );
        await catalogStore.write(
          PresetSceneCatalogSnapshot(
            source: PresetSceneCatalogSource.remote,
            scenes: <PresetSceneDefinition>[
              PresetSceneDefinition(
                presetSceneId: 'bath_time',
                publishedVersion: 1,
                spaceId: 'daily_care',
                title: 'Bath',
                summary: 'Summary',
                sceneTag: 'routine',
                coachTip: 'Tip',
                sortOrder: 1,
              ),
            ],
          ),
        );
        await harness.localStore.write(
          const HouseholdLocalSnapshot(
            householdId: 'household_a',
            role: HouseholdRole.caregiver,
            lastPhase: 'shared_context_ready',
          ),
        );
        harness.api.fetchResponse = _sharedContextResponse(
          householdId: 'household_b',
        );

        await harness.repository.refreshSharedContext();

        expect(
          (await catalogStore.readResult()).status,
          PresetSceneCatalogStoreReadStatus.available,
        );
      },
    );

    test(
      'server-confirmed missing membership clears old scope after durable empty snapshot',
      () async {
        await harness.localStore.write(
          HouseholdLocalSnapshot(
            householdId: 'household_a',
            role: HouseholdRole.caregiver,
            sharedContext: _sharedContextResponse(
              householdId: 'household_a',
            ).snapshot,
            lastPhase: 'shared_context_ready',
          ),
        );
        harness.api.fetchError = const HouseholdApiException(
          kind: HouseholdApiFailureKind.http,
          message: 'membership missing',
          statusCode: 403,
          code: 'role_not_allowed',
        );

        final result = await harness.repository.refreshSharedContext();

        expect(result.householdId, isNull);
        expect(result.role, isNull);
        expect(result.sharedContext, isNull);
        expect(result.lastPhase, 'shared_context_no_membership');
        expect(harness.clearedScopes, <String>['household_a']);
        expect((await harness.localStore.read()).householdId, isNull);
      },
    );

    test(
      'network, timeout, malformed, and persistence failures preserve old scope without clear',
      () async {
        await harness.localStore.write(
          HouseholdLocalSnapshot(
            householdId: 'household_a',
            role: HouseholdRole.caregiver,
            sharedContext: _sharedContextResponse(
              householdId: 'household_a',
            ).snapshot,
            lastPhase: 'shared_context_ready',
          ),
        );

        for (final error in <HouseholdApiException>[
          const HouseholdApiException.network(message: 'offline'),
          const HouseholdApiException.timeout(message: 'timeout'),
          const HouseholdApiException.malformed(message: 'bad payload'),
        ]) {
          harness.api.fetchError = error;
          final result = await harness.repository.refreshSharedContext();
          expect(result.householdId, 'household_a');
          expect(harness.clearedScopes, isEmpty);
        }

        final failingStore = _FailingHouseholdLocalStore(
          directoryResolver: () async => harness.tempDir,
        );
        final failingScopes = <String>[];
        final failingRepository = HouseholdRepository(
          localStore: failingStore,
          apiService: harness.api,
          accountSnapshotLoader: () async => harness.accountSnapshot,
          persistRefreshedSession: (session) async => session,
          clearGeneratedContentForHouseholdScope: (scope) async {
            failingScopes.add(scope);
          },
        );
        await harness.localStore.write(
          HouseholdLocalSnapshot(
            householdId: 'household_a',
            role: HouseholdRole.caregiver,
            sharedContext: _sharedContextResponse(
              householdId: 'household_a',
            ).snapshot,
            lastPhase: 'shared_context_ready',
          ),
        );
        harness.api.fetchError = null;
        harness.api.fetchResponse = _sharedContextResponse(
          householdId: 'household_b',
        );

        final result = await failingRepository.refreshSharedContext();

        expect(result.householdId, 'household_a');
        expect(result.lastPhase, 'shared_context_persist_failed');
        expect(failingScopes, isEmpty);
        await failingRepository.close();
      },
    );

    test(
      'malformed successful response never clears old household scope',
      () async {
        await harness.localStore.write(
          HouseholdLocalSnapshot(
            householdId: 'household_a',
            role: HouseholdRole.caregiver,
            sharedContext: _sharedContextResponse(
              householdId: 'household_a',
            ).snapshot,
            lastPhase: 'shared_context_ready',
          ),
        );
        harness.api.fetchResponse = _sharedContextResponse(householdId: ' ');

        final result = await harness.repository.refreshSharedContext();

        expect(result.householdId, 'household_a');
        expect(result.lastPhase, 'shared_context_malformed_response');
        expect(harness.clearedScopes, isEmpty);
        expect((await harness.localStore.read()).householdId, 'household_a');
      },
    );

    test(
      'cleanup failure after durable transition is reported only through retryable store intent',
      () async {
        await harness.localStore.write(
          HouseholdLocalSnapshot(
            householdId: 'household_a',
            role: HouseholdRole.caregiver,
            sharedContext: _sharedContextResponse(
              householdId: 'household_a',
            ).snapshot,
            lastPhase: 'shared_context_ready',
          ),
        );
        harness.api.fetchResponse = _sharedContextResponse(
          householdId: 'household_b',
        );
        harness.clearCleanupFailures = true;

        final result = await harness.repository.refreshSharedContext();

        expect(result.householdId, 'household_b');
        expect((await harness.localStore.read()).householdId, 'household_b');
        expect(harness.clearedScopes, <String>['household_a']);
      },
    );
  });
}

class _HouseholdRepositoryHarness {
  _HouseholdRepositoryHarness({
    required this.tempDir,
    required this.localStore,
    required this.api,
    required this.accountSnapshot,
    required this.repository,
    required this.clearedScopes,
  });

  final Directory tempDir;
  final HouseholdLocalStore localStore;
  final _FakeHouseholdApiService api;
  AccountLocalSnapshot accountSnapshot;
  final HouseholdRepository repository;
  final List<String> clearedScopes;
  bool clearCleanupFailures = false;

  static Future<_HouseholdRepositoryHarness> create() async {
    final tempDir = await Directory.systemTemp.createTemp(
      'household_repository_test_',
    );
    final localStore = HouseholdLocalStore(
      directoryResolver: () async => tempDir,
    );
    final api = _FakeHouseholdApiService();
    late _HouseholdRepositoryHarness harness;
    final clearedScopes = <String>[];
    final repository = HouseholdRepository(
      localStore: localStore,
      apiService: api,
      accountSnapshotLoader: () async => harness.accountSnapshot,
      persistRefreshedSession: (refreshedSession) async {
        harness.accountSnapshot = harness.accountSnapshot.copyWith(
          session: refreshedSession,
        );
        return refreshedSession;
      },
      clearGeneratedContentForHouseholdScope: (scope) async {
        clearedScopes.add(scope);
        if (harness.clearCleanupFailures) {
          throw StateError('simulated household content cleanup failure');
        }
      },
    );
    harness = _HouseholdRepositoryHarness(
      tempDir: tempDir,
      localStore: localStore,
      api: api,
      accountSnapshot: AccountLocalSnapshot(
        consentState: AccountConsentState.acceptedPendingSync,
        session: _jwtSession(),
        lastSyncPhase: 'batch_ack_applied',
      ),
      repository: repository,
      clearedScopes: clearedScopes,
    );
    return harness;
  }

  Future<void> dispose() async {
    await repository.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  }
}

class _FailingHouseholdLocalStore extends HouseholdLocalStore {
  _FailingHouseholdLocalStore({required super.directoryResolver});

  @override
  Future<void> write(HouseholdLocalSnapshot snapshot) async {
    throw const HouseholdLocalStoreException(
      'simulated snapshot write failure',
    );
  }
}

class _FakeHouseholdApiService extends HouseholdApiService {
  _FakeHouseholdApiService() : super(baseUrl: 'http://localhost:8080');

  HouseholdAcceptInviteResponse? acceptResponse;
  HouseholdSharedContextResponse? fetchResponse;
  HouseholdApiException? acceptError;
  HouseholdApiException? fetchError;
  Completer<HouseholdSharedContextResponse>? fetchCompleter;
  AccountSession? lastCreatedSession;
  AccountSession? lastAcceptedSession;
  AccountSession? lastFetchedSession;
  int fetchCallCount = 0;

  @override
  Future<HouseholdInviteLink> createInvite({
    required AccountSession session,
    required Future<AccountSession> Function(AccountSession refreshedSession)
    persistRefreshedSession,
    required HouseholdRole role,
    required String source,
  }) async {
    lastCreatedSession = session;
    return HouseholdInviteLink(
      householdId: 'household_1',
      token: 'invite_token_1234',
      inviteUrl: 'https://invite.example.com/invite/invite_token_1234',
      role: role,
      source: source,
      expiresAt: DateTime.utc(2026, 4, 19, 12),
    );
  }

  @override
  Future<HouseholdAcceptInviteResponse> acceptInvite({
    required AccountSession session,
    required Future<AccountSession> Function(AccountSession refreshedSession)
    persistRefreshedSession,
    required String token,
    required String source,
  }) async {
    lastAcceptedSession = session;
    if (acceptError != null) {
      throw acceptError!;
    }
    return acceptResponse ??
        HouseholdAcceptInviteResponse(
          householdId: 'household_1',
          role: HouseholdRole.caregiver,
          acceptedAt: DateTime.utc(2026, 4, 16, 12),
          sharedContext: _sharedContextResponse(),
        );
  }

  @override
  Future<HouseholdSharedContextResponse> fetchSharedContext({
    required AccountSession session,
    required Future<AccountSession> Function(AccountSession refreshedSession)
    persistRefreshedSession,
  }) async {
    lastFetchedSession = session;
    fetchCallCount += 1;
    if (fetchError != null) {
      throw fetchError!;
    }
    final completer = fetchCompleter;
    if (completer != null) {
      return completer.future;
    }
    return fetchResponse ?? _sharedContextResponse();
  }

  @override
  Future<void> close() async {}
}

AccountSession _jwtSession() {
  return AccountSession(
    accountId: 'acct_live',
    sessionId: 'sess_live',
    maskedPhoneNumber: '138****8000',
    createdAt: DateTime.utc(2026, 4, 16, 10),
    accessToken: 'access_live',
    refreshToken: 'refresh_live',
    tokenType: 'Cookie',
    accessTokenExpiresAt: DateTime.utc(2026, 4, 16, 10, 15),
    refreshTokenExpiresAt: DateTime.utc(2026, 4, 23, 10),
  );
}

HouseholdSharedContextResponse _sharedContextResponse({
  String householdId = 'household_1',
}) {
  return HouseholdSharedContextResponse(
    householdId: householdId,
    role: HouseholdRole.caregiver,
    lastAcceptedAt: DateTime.utc(2026, 4, 16, 12),
    snapshot: HouseholdSharedContext(
      babyProfileSummary: '共享宝宝档案：家庭已同步 2 条互动。',
      continuitySummary: '最近 continuity：daily_care/bath_time。',
      gardenSummary: '花园上下文：daily_care/bath_time 已累计 2 条互动。',
      practiceArgs: const PracticeRouteArgs(
        spaceId: 'daily_care',
        activityId: 'bath_time',
      ),
      latestInteractionAt: DateTime.utc(2026, 4, 16, 11, 50),
      updatedAt: DateTime.utc(2026, 4, 16, 12),
    ),
  );
}
