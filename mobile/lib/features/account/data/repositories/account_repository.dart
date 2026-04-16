import 'dart:async';

import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/services/account_api_service.dart';
import 'package:mobile/features/account/data/services/account_external_link_opener.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';

typedef AccountConnectivityChecker = Future<bool> Function();

enum AccountRuntimeTrigger {
  appBoot,
  loginSuccess,
  homeVisible,
  foregroundResume,
  manualRetry,
}

extension AccountRuntimeTriggerWire on AccountRuntimeTrigger {
  String get wireValue {
    switch (this) {
      case AccountRuntimeTrigger.appBoot:
        return 'app_boot';
      case AccountRuntimeTrigger.loginSuccess:
        return 'login_success';
      case AccountRuntimeTrigger.homeVisible:
        return 'home_visible';
      case AccountRuntimeTrigger.foregroundResume:
        return 'foreground_resume';
      case AccountRuntimeTrigger.manualRetry:
        return 'manual_retry';
    }
  }
}

class AccountRepository {
  AccountRepository({
    required AccountLocalStore localStore,
    required PracticeRepository practiceRepository,
    AccountApiService? apiService,
    AccountConnectivityChecker? connectivityChecker,
    this.consentVersion = 'pipl-v1',
  }) : _localStore = localStore,
       _practiceRepository = practiceRepository,
       _apiService = apiService,
       _connectivityChecker = connectivityChecker;

  final AccountLocalStore _localStore;
  final PracticeRepository _practiceRepository;
  final AccountApiService? _apiService;
  final AccountConnectivityChecker? _connectivityChecker;
  final String consentVersion;

  Future<AccountLocalSnapshot>? _runtimeSyncFuture;

  Future<AccountLocalSnapshot> loadSnapshot() async {
    final snapshot = await _readSnapshotSafely();
    final syncSummary = await _readSyncSummarySafely();
    return _mergeSyncSummary(snapshot, syncSummary);
  }

  Future<AccountLocalSnapshot> signIn({
    required String phoneNumber,
    required String verificationCode,
  }) async {
    if (_apiService == null) {
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
      final challenge = await _apiService.createChallenge(phoneNumber: phoneNumber);
      final session = await _apiService.verifyChallenge(
        challengeId: challenge.challengeId,
        verificationCode: verificationCode,
        installationId: installationId,
      );
      await _apiService.acceptConsent(
        sessionId: session.sessionId,
        consentVersion: consentVersion,
      );

      final syncSummary = await _readSyncSummarySafely();
      final snapshot = AccountLocalSnapshot(
        consentState: AccountConsentState.acceptedPendingSync,
        session: AccountSession(
          accountId: session.accountId,
          sessionId: session.sessionId,
          maskedPhoneNumber: session.maskedPhoneNumber,
          createdAt: session.createdAt,
        ),
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
      return refreshRuntimeState(
        trigger: AccountRuntimeTrigger.loginSuccess,
        seedSnapshot: snapshot,
        forceBootstrap: true,
      );
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
      final response = await api.revokeConsent(
        sessionId: session.sessionId,
        reason: reason,
      );
      final snapshot = current.copyWith(
        consentState: AccountConsentState.revoked,
        lastSyncPhase: 'consent_revoked',
        lastVisibleError: '同意已撤回；重新登录并再次同意后才能继续同步。',
        clearUpgradeUrl: true,
        lastSyncAt: response.updatedAt,
      );
      await _localStore.write(snapshot);
      return _mergeSyncSummary(snapshot, await _readSyncSummarySafely());
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
      final response = await api.deleteAccount(
        sessionId: session.sessionId,
        reason: reason,
      );
      final snapshot = current.copyWith(
        consentState: AccountConsentState.deleted,
        clearSession: true,
        clearChallenge: true,
        lastSyncPhase: 'account_deleted',
        lastVisibleError: '账号已删除；如需重新同步，请重新注册。',
        clearUpgradeUrl: true,
        lastSyncAt: response.updatedAt,
      );
      await _localStore.write(snapshot);
      return _mergeSyncSummary(snapshot, await _readSyncSummarySafely());
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

  Future<AccountLocalSnapshot> clearPlaceholderSession({
    bool revertToLocalOnly = false,
  }) async {
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

  Future<void> close() async {
    await _apiService?.close();
  }

  Future<AccountLocalSnapshot> _refreshRuntimeStateInternal({
    required AccountRuntimeTrigger trigger,
    AccountLocalSnapshot? seedSnapshot,
    required bool forceBootstrap,
  }) async {
    final current = seedSnapshot ?? await _readSnapshotSafely();
    final session = current.session;
    if (session == null || current.consentState == AccountConsentState.deleted) {
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

    final isConnected = await (_connectivityChecker?.call() ?? Future.value(true));
    if (!isConnected) {
      final preserveUpgradeState = _shouldPreserveUpgradeState(current);
      final snapshot = current.copyWith(
        lastSyncPhase: preserveUpgradeState
            ? current.lastSyncPhase
            : '${trigger.wireValue}_offline',
        lastVisibleError: preserveUpgradeState
            ? _visibleUpgradeMessage(
                minimumSupportedVersion: null,
                upgradeFailureKind: _validateUpgradeFailureKind(current.upgradeUrl),
              )
            : '当前离线，已保留本地待同步事件，可稍后重试。',
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
      if (forceBootstrap || session.sessionId.isNotEmpty) {
        final bootstrap = await _apiService!.bootstrap(
          sessionId: session.sessionId,
          installationId: installationId,
        );
        await _practiceRepository.importServerEvents(bootstrap.events);
        workingSnapshot = workingSnapshot.copyWith(
          lastSyncPhase: bootstrap.eventCount == 0
              ? 'bootstrap_empty'
              : 'bootstrap_imported',
          clearLastVisibleError: true,
          clearUpgradeUrl: true,
          lastSyncAt: bootstrap.bootstrapAt,
        );
        await _localStore.write(workingSnapshot);
      }
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
      final response = await _apiService!.syncEvents(
        sessionId: session.sessionId,
        installationId: installationId,
        events: pendingUploads,
      );
      final ackedKeys = <String>{
        ...response.acceptedEventKeys,
        ...response.duplicateEventKeys,
      };
      await _practiceRepository.markEventsSynced(
        ackedKeys,
        phase: 'batch_ack_applied',
        syncedAt: response.syncedAt,
      );
      final merged = _mergeSyncSummary(
        workingSnapshot.copyWith(
          lastSyncPhase: response.duplicateCount > 0
              ? 'batch_ack_duplicate_applied'
              : 'batch_ack_applied',
          clearLastVisibleError: true,
          clearUpgradeUrl: true,
          lastSyncAt: response.syncedAt,
        ),
        await _readSyncSummarySafely(),
      );
      await _localStore.write(merged);
      return merged;
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
      phase = 'signed_out';
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
          snapshot.lastVisibleError == null && syncSummary.lastSyncError == null,
      lastVisibleError: _mergeVisibleError(snapshot.lastVisibleError, syncSummary),
      clearLastSyncAt: snapshot.lastSyncAt == null && syncSummary.lastEventAt == null,
      lastSyncAt: syncSummary.lastEventAt ?? snapshot.lastSyncAt,
    );
  }

  String? _mergeVisibleError(
    String? currentVisibleError,
    PracticeSyncSummary syncSummary,
  ) {
    if (syncSummary.lastSyncError != null && syncSummary.lastSyncError!.trim().isNotEmpty) {
      return _sanitizeVisibleError(syncSummary.lastSyncError!);
    }
    return currentVisibleError;
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

  AccountExternalLinkFailureKind? _validateUpgradeFailureKind(String? upgradeUrl) {
    final validation = validateAccountUpgradeUrl(upgradeUrl);
    return validation.failureKind;
  }

  String _visibleUpgradeMessage({
    required String? minimumSupportedVersion,
    required AccountExternalLinkFailureKind? upgradeFailureKind,
  }) {
    final versionHint =
        minimumSupportedVersion == null || minimumSupportedVersion.trim().isEmpty
        ? '当前版本过旧，请升级后再同步。'
        : '当前版本过旧，最低需要 $minimumSupportedVersion。';
    if (upgradeFailureKind == null) {
      return versionHint;
    }
    return '$versionHint ${messageForAccountUpgradeUrlFailure(upgradeFailureKind)}';
  }

  String _visibleMessageForError(AccountApiException error) {
    if (error.kind == AccountApiFailureKind.timeout) {
      return '同步超时，已保留本地待同步事件，可稍后重试。';
    }
    if (error.kind == AccountApiFailureKind.network) {
      return '当前离线，已保留本地待同步事件，可稍后重试。';
    }
    if (error.isVersionBlocked) {
      return _visibleUpgradeMessage(
        minimumSupportedVersion: error.minimumSupportedVersion,
        upgradeFailureKind: validateAccountUpgradeUrl(error.upgradeUrl).failureKind,
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
      return '服务暂时不可用，已保留本地待同步事件。';
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
