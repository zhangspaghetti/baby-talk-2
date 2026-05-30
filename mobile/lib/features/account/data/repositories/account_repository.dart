import 'dart:async';

import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository_contract.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/account/data/services/account_external_link_opener.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';

export 'package:mobile/features/account/data/repositories/account_repository_contract.dart'
    show
        AccountRepositoryContract,
        AccountRuntimeTrigger,
        AccountRuntimeTriggerWire;

typedef AccountConnectivityChecker = Future<bool> Function();

class AccountRepository implements AccountRepositoryContract {
  AccountRepository({
    required AccountLocalStore localStore,
    required PracticeRepository practiceRepository,
    AccountApiService? apiService,
    AuthenticatedApiClient? authenticatedApiClient,
    AccountConnectivityChecker? connectivityChecker,
    this.consentVersion = 'pipl-v1',
  }) : _localStore = localStore,
       _practiceRepository = practiceRepository,
       _apiService = apiService,
       _authenticatedApiClient =
           authenticatedApiClient ??
           (apiService == null
               ? null
               : AuthenticatedApiClient(apiService: apiService)),
       _connectivityChecker = connectivityChecker;

  final AccountLocalStore _localStore;
  final PracticeRepository _practiceRepository;
  final AccountApiService? _apiService;
  final AuthenticatedApiClient? _authenticatedApiClient;
  final AccountConnectivityChecker? _connectivityChecker;
  final String consentVersion;

  Future<AccountLocalSnapshot>? _runtimeSyncFuture;

  @override
  Future<AccountLocalSnapshot> loadSnapshot() async {
    final snapshot = await _readSnapshotSafely();
    final syncSummary = await _readSyncSummarySafely();
    return _mergeSyncSummary(snapshot, syncSummary);
  }

  @override
  Future<AccountLocalSnapshot> signIn({
    required String phoneNumber,
    required String verificationCode,
  }) async {
    final api = _apiService;
    if (api == null) {
      return savePlaceholderSession(
        phoneNumber: phoneNumber,
        verificationCode: verificationCode,
      );
    }

    final installationId =
        await _practiceRepository.readExistingInstallationId() ??
        await _practiceRepository.ensureInstallationId();
    final now = DateTime.now().toUtc();

    try {
      final challenge = await api.createChallenge(phoneNumber: phoneNumber);
      final verified = await api.verifyChallenge(
        challengeId: challenge.challengeId,
        verificationCode: verificationCode,
        installationId: installationId,
      );

      final syncSummary = await _readSyncSummarySafely();
      var snapshot = AccountLocalSnapshot(
        consentState: AccountConsentState.acceptedPendingSync,
        session: _buildSessionFromResponse(verified),
        challenge: AccountChallengePlaceholder(
          maskedPhoneNumber: challenge.maskedPhoneNumber,
          codeLength: challenge.codeLength,
          issuedAt: now,
        ),
        pendingSyncCount: syncSummary.pendingCount,
        syncedCount: syncSummary.syncedCount,
        failedCount: syncSummary.failedCount,
        lastSyncPhase: 'login_verified',
        lastSyncAt: now,
      );
      await _localStore.write(snapshot);

      final accepted = await _runAuthenticated(
        session: snapshot.session!,
        send: (accessToken) => api.acceptConsent(
          accessToken: accessToken,
          consentVersion: consentVersion,
        ),
      );
      snapshot = snapshot.copyWith(
        session: accepted.session,
        clearLastVisibleError: true,
        clearUpgradeUrl: true,
        lastSyncAt: accepted.value.updatedAt,
      );
      await _localStore.write(snapshot);

      return refreshRuntimeState(
        trigger: AccountRuntimeTrigger.loginSuccess,
        seedSnapshot: snapshot,
        forceBootstrap: true,
      );
    } on AuthenticatedApiClientException catch (error) {
      final snapshot = await _handleAuthenticatedFailure(
        currentSnapshot: await _readSnapshotSafely(),
        error: error,
        phasePrefix: 'login_failed',
      );
      await _localStore.write(snapshot);
      return snapshot;
    } on AccountApiException catch (error) {
      final snapshot = await _handleApiFailure(
        currentSnapshot: await _readSnapshotSafely(),
        error: error,
        phasePrefix: 'login_failed',
        preserveSession: true,
      );
      await _localStore.write(snapshot);
      return snapshot;
    }
  }

  @override
  Future<AccountLocalSnapshot> refreshRuntimeState({
    required AccountRuntimeTrigger trigger,
    AccountLocalSnapshot? seedSnapshot,
    bool forceBootstrap = false,
  }) {
    if (_apiService == null) {
      return loadSnapshot();
    }
    final inFlight = _runtimeSyncFuture;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _refreshRuntimeStateInternal(
      trigger: trigger,
      seedSnapshot: seedSnapshot,
      forceBootstrap: forceBootstrap,
    );
    _runtimeSyncFuture = future;
    return future.whenComplete(() {
      if (identical(_runtimeSyncFuture, future)) {
        _runtimeSyncFuture = null;
      }
    });
  }

  @override
  Future<AccountLocalSnapshot> revokeConsent({
    String reason = 'user_requested',
  }) async {
    final api = _apiService;
    final current = await _readSnapshotSafely();
    final session = current.session;
    if (api == null || session == null) {
      final snapshot = current.copyWith(
        consentState: AccountConsentState.revoked,
        lastSyncPhase: 'consent_revoked_local',
        lastVisibleError: '同意已撤回；重新登录并再次同意后才能继续同步。',
        clearUpgradeUrl: true,
        lastSyncAt: DateTime.now().toUtc(),
      );
      await _localStore.write(snapshot);
      return _mergeSyncSummary(snapshot, await _readSyncSummarySafely());
    }

    try {
      final response = await _runAuthenticated(
        session: session,
        send: (accessToken) =>
            api.revokeConsent(accessToken: accessToken, reason: reason),
      );
      final snapshot = current.copyWith(
        session: response.session,
        consentState: AccountConsentState.revoked,
        lastSyncPhase: 'consent_revoked',
        lastVisibleError: '同意已撤回；重新登录并再次同意后才能继续同步。',
        clearUpgradeUrl: true,
        lastSyncAt: response.value.updatedAt,
      );
      await _localStore.write(snapshot);
      return _mergeSyncSummary(snapshot, await _readSyncSummarySafely());
    } on AuthenticatedApiClientException catch (error) {
      final snapshot = await _handleAuthenticatedFailure(
        currentSnapshot: current,
        error: error,
        phasePrefix: 'revoke_failed',
      );
      await _localStore.write(snapshot);
      return snapshot;
    } on AccountApiException catch (error) {
      final snapshot = await _handleApiFailure(
        currentSnapshot: current,
        error: error,
        phasePrefix: 'revoke_failed',
      );
      await _localStore.write(snapshot);
      return snapshot;
    }
  }

  @override
  Future<AccountLocalSnapshot> deleteAccount({
    String reason = 'forget_me',
  }) async {
    final api = _apiService;
    final current = await _readSnapshotSafely();
    final session = current.session;
    if (api == null || session == null) {
      final snapshot = current.copyWith(
        consentState: AccountConsentState.deleted,
        clearSession: true,
        clearChallenge: true,
        lastSyncPhase: 'account_deleted_local',
        lastVisibleError: '账号已删除；如需重新同步，请重新注册。',
        clearUpgradeUrl: true,
        lastSyncAt: DateTime.now().toUtc(),
      );
      await _localStore.write(snapshot);
      return _mergeSyncSummary(snapshot, await _readSyncSummarySafely());
    }

    try {
      final response = await _runAuthenticated(
        session: session,
        send: (accessToken) =>
            api.deleteAccount(accessToken: accessToken, reason: reason),
      );
      final snapshot = current.copyWith(
        consentState: AccountConsentState.deleted,
        clearSession: true,
        clearChallenge: true,
        lastSyncPhase: 'account_deleted',
        lastVisibleError: '账号已删除；如需重新同步，请重新注册。',
        clearUpgradeUrl: true,
        lastSyncAt: response.value.updatedAt,
      );
      await _localStore.write(snapshot);
      return _mergeSyncSummary(snapshot, await _readSyncSummarySafely());
    } on AuthenticatedApiClientException catch (error) {
      final snapshot = await _handleAuthenticatedFailure(
        currentSnapshot: current,
        error: error,
        phasePrefix: 'delete_failed',
      );
      await _localStore.write(snapshot);
      return snapshot;
    } on AccountApiException catch (error) {
      final snapshot = await _handleApiFailure(
        currentSnapshot: current,
        error: error,
        phasePrefix: 'delete_failed',
      );
      await _localStore.write(snapshot);
      return snapshot;
    }
  }

  Future<AccountLocalSnapshot> savePlaceholderSession({
    required String phoneNumber,
    required String verificationCode,
  }) async {
    final now = DateTime.now().toUtc();
    final syncSummary = await _readSyncSummarySafely();
    final maskedPhoneNumber = _maskPhoneNumber(phoneNumber);
    final snapshot = AccountLocalSnapshot(
      consentState: AccountConsentState.acceptedPendingSync,
      session: AccountSession(
        accountId: 'placeholder-account-${now.millisecondsSinceEpoch}',
        sessionId: 'placeholder-session-${now.microsecondsSinceEpoch}',
        maskedPhoneNumber: maskedPhoneNumber,
        createdAt: now,
      ),
      challenge: AccountChallengePlaceholder(
        maskedPhoneNumber: maskedPhoneNumber,
        codeLength: verificationCode.length,
        issuedAt: now,
      ),
      pendingSyncCount: syncSummary.pendingCount,
      syncedCount: syncSummary.syncedCount,
      failedCount: syncSummary.failedCount,
      lastSyncPhase: syncSummary.pendingCount > 0
          ? 'pending_local_upload'
          : 'awaiting_first_sync',
      lastVisibleError: syncSummary.failedCount > 0
          ? '仍有 ${syncSummary.failedCount} 条本地记录等待后续重试。'
          : null,
      lastSyncAt: syncSummary.lastEventAt,
    );
    await _localStore.write(snapshot);
    return snapshot;
  }

  @override
  Future<AccountLocalSnapshot> clearPlaceholderSession({
    bool revertToLocalOnly = false,
  }) async {
    // 真正退出账号时，先尽力通知后端使 refresh token 失效（best-effort：
    // 离线或后端失败不应阻塞本地清理）。回到本机档案模式（revertToLocalOnly）
    // 不属于会话注销，跳过。
    if (!revertToLocalOnly) {
      await _bestEffortBackendLogout();
    }
    final syncSummary = await _readSyncSummarySafely();
    final snapshot = AccountLocalSnapshot(
      consentState: revertToLocalOnly
          ? AccountConsentState.localOnly
          : AccountConsentState.signedOut,
      pendingSyncCount: syncSummary.pendingCount,
      syncedCount: syncSummary.syncedCount,
      failedCount: syncSummary.failedCount,
      lastSyncPhase: revertToLocalOnly ? 'local_only' : 'signed_out',
      lastVisibleError: syncSummary.failedCount > 0
          ? '仍有 ${syncSummary.failedCount} 条本地记录等待后续重试。'
          : null,
      lastSyncAt: syncSummary.lastEventAt,
    );
    await _localStore.write(snapshot);
    return snapshot;
  }

  Future<void> _bestEffortBackendLogout() async {
    final api = _apiService;
    if (api == null) {
      return;
    }
    try {
      final current = await _readSnapshotSafely();
      final refreshToken = current.session?.refreshToken;
      if (refreshToken == null || refreshToken.trim().isEmpty) {
        return;
      }
      await api.logout(refreshToken: refreshToken);
    } on Object {
      // best-effort：忽略任何登出失败，本地清理照常进行。
    }
  }

  @override
  Future<void> close() async {
    _apiService?.close();
  }

  Future<void> deleteLocalSnapshotForLifecycle() {
    return _localStore.deleteIfExists();
  }

  Future<AccountSession> persistRefreshedSession(
    AccountSession refreshedSession,
  ) => _persistRefreshedSession(refreshedSession);

  Future<AccountLocalSnapshot> _refreshRuntimeStateInternal({
    required AccountRuntimeTrigger trigger,
    AccountLocalSnapshot? seedSnapshot,
    required bool forceBootstrap,
  }) async {
    final current = seedSnapshot ?? await _readSnapshotSafely();
    if (current.session == null ||
        current.consentState == AccountConsentState.deleted) {
      return _mergeSyncSummary(current, await _readSyncSummarySafely());
    }

    if (current.consentState == AccountConsentState.revoked) {
      final snapshot = current.copyWith(
        lastSyncPhase: 'consent_revoked',
        lastVisibleError: '同意已撤回；重新登录并再次同意后才能继续同步。',
        lastSyncAt: DateTime.now().toUtc(),
      );
      await _localStore.write(snapshot);
      return _mergeSyncSummary(snapshot, await _readSyncSummarySafely());
    }

    final isConnected =
        await (_connectivityChecker?.call() ?? Future.value(true));
    if (!isConnected) {
      final preserveUpgradeState = _shouldPreserveUpgradeState(current);
      final snapshot = current.copyWith(
        lastSyncPhase: preserveUpgradeState
            ? current.lastSyncPhase
            : '${trigger.wireValue}_offline',
        lastVisibleError: preserveUpgradeState
            ? _visibleUpgradeMessage(
                minimumSupportedVersion: null,
                upgradeFailureKind: _validateUpgradeFailureKind(
                  current.upgradeUrl,
                ),
              )
            : '当前离线，已保留本机待同步记录，可稍后重试。',
        lastSyncAt: DateTime.now().toUtc(),
      );
      await _localStore.write(snapshot);
      return _mergeSyncSummary(snapshot, await _readSyncSummarySafely());
    }

    final installationId =
        await _practiceRepository.readExistingInstallationId() ??
        await _practiceRepository.ensureInstallationId();
    var workingSnapshot = current;

    try {
      if (forceBootstrap || workingSnapshot.session != null) {
        final bootstrap = await _runAuthenticated(
          session: workingSnapshot.session!,
          send: (accessToken) => _apiService!.bootstrap(
            accessToken: accessToken,
            installationId: installationId,
          ),
        );
        await _practiceRepository.importServerEvents(bootstrap.value.events);
        workingSnapshot = workingSnapshot.copyWith(
          session: bootstrap.session,
          lastSyncPhase: bootstrap.value.eventCount == 0
              ? 'bootstrap_empty'
              : 'bootstrap_imported',
          clearLastVisibleError: true,
          clearUpgradeUrl: true,
          lastSyncAt: bootstrap.value.bootstrapAt,
        );
        await _localStore.write(workingSnapshot);
      }
    } on AuthenticatedApiClientException catch (error) {
      final snapshot = await _handleAuthenticatedFailure(
        currentSnapshot: workingSnapshot,
        error: error,
        phasePrefix: 'bootstrap_failed',
      );
      await _localStore.write(snapshot);
      return snapshot;
    } on AccountApiException catch (error) {
      final snapshot = await _handleApiFailure(
        currentSnapshot: workingSnapshot,
        error: error,
        phasePrefix: 'bootstrap_failed',
      );
      await _localStore.write(snapshot);
      return snapshot;
    } on FormatException catch (_) {
      final snapshot = workingSnapshot.copyWith(
        lastSyncPhase: 'bootstrap_malformed',
        lastVisibleError: '服务响应异常，未导入远端恢复数据。',
        lastSyncAt: DateTime.now().toUtc(),
      );
      await _localStore.write(snapshot);
      return snapshot;
    }

    final pendingUploads = await _practiceRepository.listPendingUploadRecords();
    if (pendingUploads.isEmpty) {
      final merged = _mergeSyncSummary(
        workingSnapshot.copyWith(
          lastSyncPhase: 'sync_idle_no_pending',
          clearLastVisibleError: true,
          clearUpgradeUrl: true,
          lastSyncAt: DateTime.now().toUtc(),
        ),
        await _readSyncSummarySafely(),
      );
      await _localStore.write(merged);
      return merged;
    }

    try {
      final response = await _runAuthenticated(
        session: workingSnapshot.session!,
        send: (accessToken) => _apiService!.syncEvents(
          accessToken: accessToken,
          installationId: installationId,
          events: pendingUploads,
        ),
      );
      final ackedKeys = <String>{
        ...response.value.acceptedEventKeys,
        ...response.value.duplicateEventKeys,
      };
      await _practiceRepository.markEventsSynced(
        ackedKeys,
        phase: 'batch_ack_applied',
        syncedAt: response.value.syncedAt,
      );
      final merged = _mergeSyncSummary(
        workingSnapshot.copyWith(
          session: response.session,
          lastSyncPhase: response.value.duplicateCount > 0
              ? 'batch_ack_duplicate_applied'
              : 'batch_ack_applied',
          clearLastVisibleError: true,
          clearUpgradeUrl: true,
          lastSyncAt: response.value.syncedAt,
        ),
        await _readSyncSummarySafely(),
      );
      await _localStore.write(merged);
      return merged;
    } on AuthenticatedApiClientException catch (error) {
      final eventKeys = pendingUploads.map((event) => event.eventKey);
      await _practiceRepository.markEventsFailed(
        eventKeys,
        phase: _phaseForAuthenticatedFailure(error),
        errorMessage: error.visibleMessage,
        failedAt: DateTime.now().toUtc(),
        keepPending: true,
      );
      final snapshot = await _handleAuthenticatedFailure(
        currentSnapshot: workingSnapshot,
        error: error,
        phasePrefix: 'sync_failed',
      );
      await _localStore.write(snapshot);
      return snapshot;
    } on AccountApiException catch (error) {
      final eventKeys = pendingUploads.map((event) => event.eventKey);
      await _practiceRepository.markEventsFailed(
        eventKeys,
        phase: _phaseForSyncFailure(error),
        errorMessage: _visibleMessageForError(error),
        failedAt: DateTime.now().toUtc(),
        keepPending: true,
      );
      final snapshot = await _handleApiFailure(
        currentSnapshot: workingSnapshot,
        error: error,
        phasePrefix: 'sync_failed',
      );
      await _localStore.write(snapshot);
      return snapshot;
    }
  }

  Future<_AuthenticatedRepositoryResult<T>> _runAuthenticated<T>({
    required AccountSession session,
    required Future<T> Function(String accessToken) send,
  }) async {
    final client = _authenticatedApiClient;
    if (client == null) {
      throw StateError('AuthenticatedApiClient 未初始化。');
    }
    final result = await client.execute(
      session: session,
      send: send,
      persistRefreshedSession: _persistRefreshedSession,
    );
    return _AuthenticatedRepositoryResult<T>(
      value: result.value,
      session: result.session,
    );
  }

  Future<AccountSession> _persistRefreshedSession(
    AccountSession refreshedSession,
  ) async {
    final current = await _readSnapshotSafely();
    final currentSession = current.session;
    if (currentSession == null ||
        currentSession.accountId != refreshedSession.accountId ||
        currentSession.sessionId != refreshedSession.sessionId) {
      throw const AuthenticatedApiClientException.persistenceFailure();
    }

    final snapshot = current.copyWith(
      session: refreshedSession,
      lastSyncPhase: 'auth_token_refreshed',
      clearLastVisibleError: true,
      clearUpgradeUrl: true,
      lastSyncAt: DateTime.now().toUtc(),
    );
    try {
      await _localStore.write(snapshot);
    } on AccountLocalStoreException {
      throw const AuthenticatedApiClientException.persistenceFailure();
    }
    return refreshedSession;
  }

  AccountSession _buildSessionFromResponse(AccountSessionResponse response) {
    return AccountSession(
      accountId: response.accountId,
      sessionId: response.sessionId,
      maskedPhoneNumber: response.maskedPhoneNumber,
      createdAt: response.createdAt,
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      tokenType: response.tokenType ?? 'Cookie',
      accessTokenExpiresAt: response.accessTokenExpiresAt,
      refreshTokenExpiresAt: response.refreshTokenExpiresAt,
    );
  }

  Future<AccountLocalSnapshot> _handleApiFailure({
    required AccountLocalSnapshot currentSnapshot,
    required AccountApiException error,
    required String phasePrefix,
    bool preserveSession = false,
  }) async {
    final syncSummary = await _readSyncSummarySafely();
    if (error.isUnauthorized) {
      return _mergeSyncSummary(
        currentSnapshot.copyWith(
          consentState: AccountConsentState.signedOut,
          clearSession: !preserveSession,
          lastSyncPhase: '${phasePrefix}_session_expired',
          lastVisibleError: '登录已过期，请重新登录后再试。',
          clearUpgradeUrl: true,
          lastSyncAt: DateTime.now().toUtc(),
        ),
        syncSummary,
      );
    }
    if (error.isConsentRevoked || error.isConsentRequired) {
      return _mergeSyncSummary(
        currentSnapshot.copyWith(
          consentState: AccountConsentState.revoked,
          lastSyncPhase: '${phasePrefix}_consent_revoked',
          lastVisibleError: '同意已撤回；重新登录并再次同意后才能继续同步。',
          clearUpgradeUrl: true,
          lastSyncAt: DateTime.now().toUtc(),
        ),
        syncSummary,
      );
    }
    if (error.isAccountDeleted) {
      return _mergeSyncSummary(
        currentSnapshot.copyWith(
          consentState: AccountConsentState.deleted,
          clearSession: true,
          clearChallenge: true,
          lastSyncPhase: '${phasePrefix}_account_deleted',
          lastVisibleError: '账号已删除；如需重新同步，请重新注册。',
          clearUpgradeUrl: true,
          lastSyncAt: DateTime.now().toUtc(),
        ),
        syncSummary,
      );
    }
    if (error.isVersionBlocked) {
      final validation = validateAccountUpgradeUrl(error.upgradeUrl);
      final upgradeFailureKind = validation.failureKind;
      return _mergeSyncSummary(
        currentSnapshot.copyWith(
          lastSyncPhase: '${phasePrefix}_upgrade_required_426',
          lastVisibleError: _visibleUpgradeMessage(
            minimumSupportedVersion: error.minimumSupportedVersion,
            upgradeFailureKind: upgradeFailureKind,
          ),
          upgradeUrl: validation.normalizedUrl,
          clearUpgradeUrl: !validation.isValid,
          lastSyncAt: DateTime.now().toUtc(),
        ),
        syncSummary,
      );
    }
    return _mergeSyncSummary(
      currentSnapshot.copyWith(
        lastSyncPhase: '${phasePrefix}_${_phaseSuffixForError(error)}',
        lastVisibleError: _visibleMessageForError(error),
        clearUpgradeUrl: true,
        lastSyncAt: DateTime.now().toUtc(),
      ),
      syncSummary,
    );
  }

  Future<AccountLocalSnapshot> _handleAuthenticatedFailure({
    required AccountLocalSnapshot currentSnapshot,
    required AuthenticatedApiClientException error,
    required String phasePrefix,
  }) async {
    final syncSummary = await _readSyncSummarySafely();
    return _mergeSyncSummary(
      currentSnapshot.copyWith(
        consentState: AccountConsentState.signedOut,
        clearSession: true,
        lastSyncPhase: '${phasePrefix}_${error.phaseSuffix}',
        lastVisibleError: error.visibleMessage,
        clearUpgradeUrl: true,
        lastSyncAt: DateTime.now().toUtc(),
      ),
      syncSummary,
    );
  }

  Future<AccountLocalSnapshot> _readSnapshotSafely() async {
    try {
      return await _localStore.read();
    } on FormatException {
      return AccountLocalSnapshot.signedOut;
    }
  }

  Future<PracticeSyncSummary> _readSyncSummarySafely() async {
    try {
      return await _practiceRepository.getSyncSummary();
    } catch (_) {
      return const PracticeSyncSummary();
    }
  }

  AccountLocalSnapshot _mergeSyncSummary(
    AccountLocalSnapshot snapshot,
    PracticeSyncSummary syncSummary,
  ) {
    String phase;
    if (snapshot.consentState == AccountConsentState.localOnly) {
      phase = 'local_only';
    } else if (snapshot.consentState == AccountConsentState.signedOut) {
      phase =
          snapshot.lastSyncPhase == 'idle' ||
              snapshot.lastSyncPhase.trim().isEmpty
          ? 'signed_out'
          : snapshot.lastSyncPhase;
    } else if (snapshot.consentState == AccountConsentState.revoked) {
      phase = snapshot.lastSyncPhase;
    } else if (snapshot.consentState == AccountConsentState.deleted) {
      phase = snapshot.lastSyncPhase;
    } else if (_shouldPreserveUpgradeState(snapshot)) {
      phase = snapshot.lastSyncPhase;
    } else if (syncSummary.pendingCount > 0) {
      phase = syncSummary.lastSyncPhase ?? snapshot.lastSyncPhase;
    } else {
      phase = syncSummary.lastSyncPhase ?? snapshot.lastSyncPhase;
    }

    return snapshot.copyWith(
      pendingSyncCount: syncSummary.pendingCount,
      syncedCount: syncSummary.syncedCount,
      failedCount: syncSummary.failedCount,
      lastSyncPhase: phase,
      clearLastVisibleError:
          snapshot.lastVisibleError == null &&
          syncSummary.lastSyncError == null,
      lastVisibleError: _mergeVisibleError(
        snapshot.lastVisibleError,
        syncSummary,
      ),
      clearLastSyncAt:
          snapshot.lastSyncAt == null && syncSummary.lastEventAt == null,
      lastSyncAt: syncSummary.lastEventAt ?? snapshot.lastSyncAt,
    );
  }

  String? _mergeVisibleError(
    String? currentVisibleError,
    PracticeSyncSummary syncSummary,
  ) {
    if (syncSummary.lastSyncError != null &&
        syncSummary.lastSyncError!.trim().isNotEmpty) {
      return _sanitizeVisibleError(syncSummary.lastSyncError!);
    }
    return currentVisibleError;
  }

  String _phaseForAuthenticatedFailure(AuthenticatedApiClientException error) {
    switch (error.kind) {
      case AuthenticatedApiClientFailureKind.refreshTimeout:
        return 'upload_refresh_timeout';
      case AuthenticatedApiClientFailureKind.refreshNetwork:
        return 'upload_refresh_network';
      case AuthenticatedApiClientFailureKind.refreshMalformed:
        return 'upload_refresh_malformed';
      case AuthenticatedApiClientFailureKind.refreshFailed:
        return 'upload_refresh_failed';
      case AuthenticatedApiClientFailureKind.persistenceFailure:
        return 'upload_session_persist_failed';
      case AuthenticatedApiClientFailureKind.missingCredentials:
      case AuthenticatedApiClientFailureKind.sessionExpired:
        return 'upload_session_expired';
    }
  }

  String _phaseForSyncFailure(AccountApiException error) {
    if (error.kind == AccountApiFailureKind.timeout) {
      return 'upload_timeout';
    }
    if (error.kind == AccountApiFailureKind.network) {
      return 'upload_offline';
    }
    if (error.isVersionBlocked) {
      return 'upload_upgrade_required_426';
    }
    if (error.isUnauthorized) {
      return 'upload_session_expired';
    }
    if (error.isConsentRevoked || error.isConsentRequired) {
      return 'upload_consent_revoked';
    }
    if (error.isAccountDeleted) {
      return 'upload_account_deleted';
    }
    if (error.kind == AccountApiFailureKind.malformed) {
      return 'upload_malformed_response';
    }
    if (error.isServerFailure) {
      return 'upload_server_error';
    }
    return 'upload_request_failed';
  }

  String _phaseSuffixForError(AccountApiException error) {
    if (error.kind == AccountApiFailureKind.timeout) {
      return 'timeout';
    }
    if (error.kind == AccountApiFailureKind.network) {
      return 'offline';
    }
    if (error.kind == AccountApiFailureKind.malformed) {
      return 'malformed';
    }
    if (error.isServerFailure) {
      return 'server_error';
    }
    return 'request_failed';
  }

  bool _shouldPreserveUpgradeState(AccountLocalSnapshot snapshot) {
    return snapshot.isUpgradeRequired;
  }

  AccountExternalLinkFailureKind? _validateUpgradeFailureKind(
    String? upgradeUrl,
  ) {
    final validation = validateAccountUpgradeUrl(upgradeUrl);
    return validation.failureKind;
  }

  String _visibleUpgradeMessage({
    required String? minimumSupportedVersion,
    required AccountExternalLinkFailureKind? upgradeFailureKind,
  }) {
    final versionHint =
        minimumSupportedVersion == null ||
            minimumSupportedVersion.trim().isEmpty
        ? '当前版本过旧，请升级后再同步。'
        : '当前版本过旧，最低需要 $minimumSupportedVersion。';
    if (upgradeFailureKind == null) {
      return versionHint;
    }
    return '$versionHint ${messageForAccountUpgradeUrlFailure(upgradeFailureKind)}';
  }

  String _visibleMessageForError(AccountApiException error) {
    if (error.kind == AccountApiFailureKind.timeout) {
      return '同步超时，已保留本机待同步记录，可稍后重试。';
    }
    if (error.kind == AccountApiFailureKind.network) {
      return '当前离线，已保留本机待同步记录，可稍后重试。';
    }
    if (error.isVersionBlocked) {
      return _visibleUpgradeMessage(
        minimumSupportedVersion: error.minimumSupportedVersion,
        upgradeFailureKind: validateAccountUpgradeUrl(
          error.upgradeUrl,
        ).failureKind,
      );
    }
    if (error.isUnauthorized) {
      return '登录已过期，请重新登录后再试。';
    }
    if (error.isConsentRevoked || error.isConsentRequired) {
      return '同意已撤回；重新登录并再次同意后才能继续同步。';
    }
    if (error.isAccountDeleted) {
      return '账号已删除；如需重新同步，请重新注册。';
    }
    if (error.kind == AccountApiFailureKind.malformed) {
      return '服务响应异常，未导入远端恢复数据。';
    }
    if (error.isServerFailure) {
      return '服务暂时不可用，已保留本机待同步记录。';
    }
    return _sanitizeVisibleError(error.message);
  }

  String _sanitizeVisibleError(String value) {
    var sanitized = value;
    sanitized = sanitized.replaceAll(RegExp(r'1\d{10}'), '***手机号***');
    sanitized = sanitized.replaceAll(RegExp(r'\b\d{4,8}\b'), '***验证码***');
    sanitized = sanitized.replaceAll(
      RegExp(r'token\s*[:=]\s*[^\s,;]+', caseSensitive: false),
      'token=***',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'session\s*[:=]\s*[^\s,;]+', caseSensitive: false),
      'session=***',
    );
    return sanitized;
  }

  String _maskPhoneNumber(String phoneNumber) {
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) {
      return '***';
    }
    final prefix = digits.substring(0, 3);
    final suffix = digits.substring(digits.length - 4);
    return '$prefix****$suffix';
  }
}

class _AuthenticatedRepositoryResult<T> {
  const _AuthenticatedRepositoryResult({
    required this.value,
    required this.session,
  });

  final T value;
  final AccountSession session;
}
