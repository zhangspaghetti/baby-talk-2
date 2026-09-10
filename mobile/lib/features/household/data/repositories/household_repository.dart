import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/services/authenticated_api_client.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/data/services/household_api_service.dart';
import 'package:mobile/features/household/domain/models/household_invite_link.dart';
import 'package:mobile/features/household/domain/models/household_role.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';

typedef HouseholdAccountSnapshotLoader =
    Future<AccountLocalSnapshot> Function();
typedef HouseholdAccountSnapshotReadResultLoader =
    Future<AccountLocalSnapshotReadResult> Function();
typedef HouseholdGeneratedContentScopeClearance =
    Future<void> Function(String householdScope);
typedef HouseholdGeneratedContentScopeFingerprintClearance =
    Future<void> Function(String householdScopeFingerprint);

class HouseholdCreateInviteResult {
  const HouseholdCreateInviteResult({
    required this.snapshot,
    required this.message,
    this.inviteLink,
  });

  final HouseholdLocalSnapshot snapshot;
  final String message;
  final HouseholdInviteLink? inviteLink;

  bool get isSuccess => inviteLink != null;
}

class HouseholdInviteAcceptResult {
  const HouseholdInviteAcceptResult({
    required this.snapshot,
    required this.message,
    this.practiceArgs,
  });

  final HouseholdLocalSnapshot snapshot;
  final String message;
  final PracticeRouteArgs? practiceArgs;

  bool get shouldRouteToPractice => practiceArgs != null;
}

class HouseholdRevokeInviteResult {
  const HouseholdRevokeInviteResult({
    required this.snapshot,
    required this.message,
    this.applied = false,
  });

  final HouseholdLocalSnapshot snapshot;
  final String message;
  final bool applied;

  bool get isSuccess => applied;
}

class HouseholdRepository {
  HouseholdRepository({
    required HouseholdLocalStore localStore,
    required HouseholdApiService apiService,
    required HouseholdAccountSnapshotLoader accountSnapshotLoader,
    HouseholdAccountSnapshotReadResultLoader? accountSnapshotReadResultLoader,
    required PersistRefreshedSession persistRefreshedSession,
    HouseholdGeneratedContentScopeClearance?
    clearGeneratedContentForHouseholdScope,
    HouseholdGeneratedContentScopeFingerprintClearance?
    clearGeneratedContentForHouseholdScopeFingerprint,
  }) : _localStore = localStore,
       _apiService = apiService,
       _accountSnapshotLoader = accountSnapshotLoader,
       _accountSnapshotReadResultLoader = accountSnapshotReadResultLoader,
       _persistRefreshedSession = persistRefreshedSession,
       _clearGeneratedContentForHouseholdScope =
           clearGeneratedContentForHouseholdScope ??
           ((_) async {
             throw StateError('household scope cleanup callback unavailable');
           }),
       _clearGeneratedContentForHouseholdScopeFingerprint =
           clearGeneratedContentForHouseholdScopeFingerprint ??
           ((_) async {
             throw StateError('household scope cleanup callback unavailable');
           });

  final HouseholdLocalStore _localStore;
  final HouseholdApiService _apiService;
  final HouseholdAccountSnapshotLoader _accountSnapshotLoader;
  final HouseholdAccountSnapshotReadResultLoader?
  _accountSnapshotReadResultLoader;
  final PersistRefreshedSession _persistRefreshedSession;
  final HouseholdGeneratedContentScopeClearance
  _clearGeneratedContentForHouseholdScope;
  final HouseholdGeneratedContentScopeFingerprintClearance
  _clearGeneratedContentForHouseholdScopeFingerprint;

  Future<HouseholdLocalSnapshot>? _refreshFuture;
  Future<HouseholdInviteAcceptResult>? _acceptFuture;
  Future<HouseholdCreateInviteResult>? _createFuture;
  Future<HouseholdRevokeInviteResult>? _revokeFuture;
  HouseholdLocalSnapshot? _lastKnownSnapshot;

  Future<HouseholdLocalSnapshot> loadSnapshot() async {
    final readResult = await _readSnapshotWithStatus();
    final sessionGate = await _resolveSessionGate(action: 'household_boot');
    if (!readResult.wasReadSuccessfully) {
      if (!sessionGate.canProceed &&
          _shouldHideHouseholdContext(sessionGate.privacyPolicy)) {
        // A failed durable read must not authorize a write or content clear;
        // still hide any cached private context from the current UI.
        return _mergeSessionGateSnapshot(readResult.snapshot, sessionGate);
      }
      return readResult.snapshot;
    }
    if (!sessionGate.canProceed &&
        sessionGate.privacyPolicy ==
            _HouseholdSessionGatePrivacyPolicy.accountReadUnavailable) {
      return _mergeSessionGateSnapshot(readResult.snapshot, sessionGate);
    }
    if (!sessionGate.canProceed &&
        sessionGate.privacyPolicy ==
            _HouseholdSessionGatePrivacyPolicy.clearHouseholdContext) {
      return _persistMergedSessionGateSnapshot(
        current: readResult.snapshot,
        sessionGate: sessionGate,
      );
    }
    final snapshot = await _retryPendingHouseholdScopeClear(
      readResult.snapshot,
    );
    if (sessionGate.canProceed) {
      return snapshot;
    }
    return _persistMergedSessionGateSnapshot(
      current: snapshot,
      sessionGate: sessionGate,
    );
  }

  Future<_HouseholdSnapshotReadResult> _readSnapshotWithStatus() async {
    try {
      final snapshot = await _localStore.read();
      _lastKnownSnapshot = snapshot;
      return _HouseholdSnapshotReadResult(
        snapshot: snapshot,
        wasReadSuccessfully: true,
      );
    } on FormatException {
      final fallback = _lastKnownSnapshot ?? HouseholdLocalSnapshot.empty;
      return _HouseholdSnapshotReadResult(
        snapshot: fallback.copyWith(
          lastPhase: 'local_snapshot_reset',
          lastVisibleError: _lastKnownSnapshot == null
              ? 'household 本地状态损坏，已回退到安全空态。'
              : 'household 本地状态损坏，已保留最近一次稳定结果。',
        ),
        wasReadSuccessfully: false,
      );
    } on HouseholdLocalStoreException catch (error) {
      return _HouseholdSnapshotReadResult(
        snapshot: (_lastKnownSnapshot ?? HouseholdLocalSnapshot.empty).copyWith(
          lastPhase: 'local_store_unavailable',
          lastVisibleError: _sanitizeVisibleError(error.message),
        ),
        wasReadSuccessfully: false,
      );
    }
  }

  Future<HouseholdCreateInviteResult> createInvite({
    HouseholdRole role = HouseholdRole.caregiver,
    String source = 'household_settings',
  }) {
    final inFlight = _createFuture;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _createInviteInternal(role: role, source: source);
    _createFuture = future;
    return future.whenComplete(() {
      if (identical(_createFuture, future)) {
        _createFuture = null;
      }
    });
  }

  Future<HouseholdRevokeInviteResult> revokeInvite({
    required String token,
    String source = 'household_settings',
  }) {
    final inFlight = _revokeFuture;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _revokeInviteInternal(token: token, source: source);
    _revokeFuture = future;
    return future.whenComplete(() {
      if (identical(_revokeFuture, future)) {
        _revokeFuture = null;
      }
    });
  }

  Future<HouseholdInviteAcceptResult> acceptInvite({
    required String token,
    required String source,
  }) {
    final inFlight = _acceptFuture;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _acceptInviteInternal(token: token, source: source);
    _acceptFuture = future;
    return future.whenComplete(() {
      if (identical(_acceptFuture, future)) {
        _acceptFuture = null;
      }
    });
  }

  Future<HouseholdLocalSnapshot> refreshSharedContext({
    String reason = 'manual_refresh',
  }) {
    final inFlight = _refreshFuture;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _refreshSharedContextInternal(reason: reason);
    _refreshFuture = future;
    return future.whenComplete(() {
      if (identical(_refreshFuture, future)) {
        _refreshFuture = null;
      }
    });
  }

  Future<void> close() async {
    _apiService.close();
  }

  Future<void> deleteLocalSnapshotForLifecycle() {
    return _localStore.deleteIfExists();
  }

  Future<HouseholdCreateInviteResult> _createInviteInternal({
    required HouseholdRole role,
    required String source,
  }) async {
    final preflight = await _householdCommandPreflight(action: 'create_invite');
    final current = preflight.snapshot;
    if (!preflight.canProceed) {
      return HouseholdCreateInviteResult(
        snapshot: current,
        message: current.lastVisibleError ?? '当前无法创建邀请。',
      );
    }
    final sessionGate = preflight.sessionGate!;

    try {
      final inviteLink = await _apiService.createInvite(
        session: sessionGate.session!,
        persistRefreshedSession: _persistRefreshedSession,
        role: role,
        source: source.trim(),
      );
      final snapshot = await _persistSnapshot(
        current.copyWith(
          householdId: inviteLink.householdId,
          role: HouseholdRole.primaryCaregiver,
          lastPhase: 'create_invite_created',
          clearLastVisibleError: true,
        ),
        phaseOnWriteFailure: 'create_invite_persist_failed',
        messageOnWriteFailure: '邀请链接已创建，但 household 本地状态保存失败。',
      );
      return HouseholdCreateInviteResult(
        snapshot: snapshot,
        inviteLink: inviteLink,
        message: snapshot.lastVisibleError ?? '邀请链接已创建。',
      );
    } on HouseholdApiException catch (error) {
      final snapshot = await _persistSnapshot(
        _snapshotForApiError(
          current: current,
          error: error,
          action: 'create_invite',
          preserveSharedContext: true,
        ),
      );
      return HouseholdCreateInviteResult(
        snapshot: snapshot,
        message: snapshot.lastVisibleError ?? '当前无法创建邀请。',
      );
    }
  }

  Future<HouseholdRevokeInviteResult> _revokeInviteInternal({
    required String token,
    required String source,
  }) async {
    final preflight = await _householdCommandPreflight(
      action: 'revoke_invite',
      blockOnPendingClear: false,
    );
    final current = preflight.snapshot;
    if (!preflight.canProceed) {
      return HouseholdRevokeInviteResult(
        snapshot: current,
        message: current.lastVisibleError ?? '当前无法撤销邀请。',
      );
    }
    final sessionGate = preflight.sessionGate!;

    try {
      final response = await _apiService.revokeInvite(
        session: sessionGate.session!,
        persistRefreshedSession: _persistRefreshedSession,
        token: token.trim(),
      );
      final snapshot = await _persistSnapshot(
        current.copyWith(
          lastPhase: 'revoke_invite_revoked',
          clearLastVisibleError: true,
        ),
        phaseOnWriteFailure: 'revoke_invite_persist_failed',
        messageOnWriteFailure: '邀请已撤销，但 household 本地状态保存失败。',
      );
      return HouseholdRevokeInviteResult(
        snapshot: snapshot,
        applied: response.applied,
        message: snapshot.lastVisibleError ?? '邀请已撤销。',
      );
    } on HouseholdApiException catch (error) {
      final snapshot = await _persistSnapshot(
        _snapshotForApiError(
          current: current,
          error: error,
          action: 'revoke_invite',
          preserveSharedContext: true,
        ),
      );
      return HouseholdRevokeInviteResult(
        snapshot: snapshot,
        message: snapshot.lastVisibleError ?? '当前无法撤销邀请。',
      );
    }
  }

  Future<HouseholdInviteAcceptResult> _acceptInviteInternal({
    required String token,
    required String source,
  }) async {
    final preflight = await _householdCommandPreflight(action: 'accept_invite');
    final current = preflight.snapshot;
    if (!preflight.canProceed) {
      return HouseholdInviteAcceptResult(
        snapshot: current,
        message: current.lastVisibleError ?? '当前无法接受邀请。',
      );
    }
    final sessionGate = preflight.sessionGate!;

    try {
      final response = await _apiService.acceptInvite(
        session: sessionGate.session!,
        persistRefreshedSession: _persistRefreshedSession,
        token: token.trim(),
        source: source.trim(),
      );
      final persistedSnapshot = await _persistSnapshot(
        HouseholdLocalSnapshot(
          householdId: response.householdId,
          role: response.role,
          sharedContext: response.sharedContext.snapshot,
          lastPhase: 'accept_ready',
          lastAcceptedAt: response.acceptedAt,
        ),
        phaseOnWriteFailure: 'accept_ready_persist_failed',
        messageOnWriteFailure: '邀请已接受，但 household 本地状态保存失败。',
      );
      final practiceArgs = PracticeRouteArgs(
        spaceId: response.sharedContext.snapshot.practiceArgs.spaceId,
        activityId: response.sharedContext.snapshot.practiceArgs.activityId,
        shareToken: token.trim(),
        entrySource: PracticeRouteEntrySource.inviteReentry,
      );
      return HouseholdInviteAcceptResult(
        snapshot: persistedSnapshot,
        practiceArgs: practiceArgs,
        message: persistedSnapshot.lastVisibleError ?? '邀请已接受，正在进入共享练习。',
      );
    } on HouseholdApiException catch (error) {
      final snapshot = await _persistSnapshot(
        _snapshotForApiError(
          current: current,
          error: error,
          action: 'accept_invite',
          preserveSharedContext: true,
        ),
      );
      return HouseholdInviteAcceptResult(
        snapshot: snapshot,
        message: snapshot.lastVisibleError ?? '当前无法接受邀请。',
      );
    }
  }

  Future<HouseholdLocalSnapshot> _refreshSharedContextInternal({
    required String reason,
  }) async {
    final preflight = await _householdCommandPreflight(
      action: 'shared_context',
    );
    if (!preflight.canProceed) {
      // A server response cannot establish a safe A->B transition when the
      // durable A read or an earlier cleanup retry failed. Do not call the
      // server or write/clear.
      return preflight.snapshot;
    }
    final current = preflight.snapshot;
    final sessionGate = preflight.sessionGate!;

    try {
      final response = await _apiService.fetchSharedContext(
        session: sessionGate.session!,
        persistRefreshedSession: _persistRefreshedSession,
      );
      final householdId = response.householdId.trim();
      if (householdId.isEmpty) {
        return _persistSnapshot(
          _snapshotForApiError(
            current: current,
            error: const HouseholdApiException.malformed(
              message: 'shared context household identity missing',
            ),
            action: 'shared_context',
            preserveSharedContext: true,
          ),
        );
      }
      final persisted = await _persistConfirmedHouseholdSnapshot(
        previous: current,
        next: HouseholdLocalSnapshot(
          householdId: householdId,
          role: response.role,
          sharedContext: response.snapshot,
          lastPhase: 'shared_context_ready',
          lastAcceptedAt: response.lastAcceptedAt,
        ),
        phaseOnWriteFailure: 'shared_context_persist_failed',
        messageOnWriteFailure: '共享上下文已刷新，但 household 本地状态保存失败。',
        fallbackOnWriteFailure: current,
      );
      return persisted;
    } on HouseholdApiException catch (error) {
      if (_isServerConfirmedMissingMembership(error)) {
        return _persistConfirmedHouseholdSnapshot(
          previous: current,
          next: const HouseholdLocalSnapshot(
            lastPhase: 'shared_context_no_membership',
            lastVisibleError: '当前账号尚未加入共享家庭。',
          ),
          phaseOnWriteFailure: 'shared_context_persist_failed',
          messageOnWriteFailure: '共享家庭状态已更新，但本地状态保存失败。',
          fallbackOnWriteFailure: current,
        );
      }
      return _persistSnapshot(
        _snapshotForApiError(
          current: current,
          error: error,
          action: 'shared_context',
          preserveSharedContext: true,
          fallbackMessage: reason == 'foreground_resume'
              ? '前台恢复时共享上下文刷新失败，已保留最近一次稳定结果。'
              : null,
        ),
      );
    } on FormatException {
      return _persistSnapshot(
        _snapshotForApiError(
          current: current,
          error: const HouseholdApiException.malformed(
            message: 'shared context response is malformed',
          ),
          action: 'shared_context',
          preserveSharedContext: true,
        ),
      );
    }
  }

  Future<_HouseholdCommandPreflight> _householdCommandPreflight({
    required String action,
    bool blockOnPendingClear = true,
  }) async {
    final readResult = await _readSnapshotWithStatus();
    if (!readResult.wasReadSuccessfully) {
      final sessionGate = await _resolveSessionGate(action: action);
      if (!sessionGate.canProceed &&
          _shouldHideHouseholdContext(sessionGate.privacyPolicy)) {
        return _HouseholdCommandPreflight.blocked(
          _mergeSessionGateSnapshot(readResult.snapshot, sessionGate),
          sessionGate: sessionGate,
        );
      }
      return _HouseholdCommandPreflight.blocked(readResult.snapshot);
    }
    final sessionGate = await _resolveSessionGate(action: action);
    if (!sessionGate.canProceed &&
        sessionGate.privacyPolicy ==
            _HouseholdSessionGatePrivacyPolicy.accountReadUnavailable) {
      return _HouseholdCommandPreflight.blocked(
        _mergeSessionGateSnapshot(readResult.snapshot, sessionGate),
        sessionGate: sessionGate,
      );
    }
    if (!sessionGate.canProceed &&
        sessionGate.privacyPolicy ==
            _HouseholdSessionGatePrivacyPolicy.clearHouseholdContext) {
      return _HouseholdCommandPreflight.blocked(
        await _persistMergedSessionGateSnapshot(
          current: readResult.snapshot,
          sessionGate: sessionGate,
        ),
        sessionGate: sessionGate,
      );
    }
    final snapshot = await _retryPendingHouseholdScopeClear(
      readResult.snapshot,
    );
    if (!sessionGate.canProceed) {
      return _HouseholdCommandPreflight.blocked(
        await _persistMergedSessionGateSnapshot(
          current: snapshot,
          sessionGate: sessionGate,
        ),
        sessionGate: sessionGate,
      );
    }
    if (blockOnPendingClear &&
        snapshot.pendingClearHouseholdScopeFingerprint != null) {
      return _HouseholdCommandPreflight.blocked(
        snapshot.copyWith(
          lastPhase: '${action}_pending_household_clear',
          lastVisibleError: '上一家庭数据清理尚未完成，请稍后重试。',
        ),
        sessionGate: sessionGate,
      );
    }
    return _HouseholdCommandPreflight.ready(snapshot, sessionGate);
  }

  Future<_SessionGateResult> _resolveSessionGate({
    required String action,
  }) async {
    final accountRead = await _readAccountSnapshotSafely();
    if (!accountRead.wasReadSuccessfully) {
      return _SessionGateResult.accountReadUnavailable(action: action);
    }
    final accountSnapshot = accountRead.snapshot;
    final consentState = accountSnapshot.consentState;
    final session = accountSnapshot.session;
    if (consentState == AccountConsentState.revoked) {
      return _SessionGateResult.blocked(
        HouseholdLocalSnapshot(
          lastPhase: '${action}_consent_required',
          lastVisibleError: '同意已撤回；重新登录并再次同意后才能继续共享。',
        ),
        privacyPolicy: _HouseholdSessionGatePrivacyPolicy.clearHouseholdContext,
      );
    }
    if (consentState == AccountConsentState.deleted) {
      return _SessionGateResult.blocked(
        HouseholdLocalSnapshot(
          lastPhase: '${action}_account_deleted',
          lastVisibleError: '账号已删除；请重新注册后再继续共享。',
        ),
        privacyPolicy: _HouseholdSessionGatePrivacyPolicy.clearHouseholdContext,
      );
    }
    if (consentState == AccountConsentState.localOnly ||
        consentState == AccountConsentState.signedOut) {
      return _SessionGateResult.blocked(
        HouseholdLocalSnapshot(
          lastPhase: '${action}_invalid_session',
          lastVisibleError: '请先登录并完成同意，再继续照护邀请流程。',
        ),
        privacyPolicy: _HouseholdSessionGatePrivacyPolicy.clearHouseholdContext,
      );
    }
    if (session == null || !session.hasJwtTokens) {
      return _SessionGateResult.blocked(
        HouseholdLocalSnapshot(
          lastPhase: '${action}_invalid_session',
          lastVisibleError: '登录已过期，请重新登录后再试。',
        ),
        privacyPolicy:
            _HouseholdSessionGatePrivacyPolicy.preserveStableHousehold,
      );
    }
    return _SessionGateResult.ready(session);
  }

  bool _shouldHideHouseholdContext(
    _HouseholdSessionGatePrivacyPolicy privacyPolicy,
  ) {
    return privacyPolicy ==
            _HouseholdSessionGatePrivacyPolicy.clearHouseholdContext ||
        privacyPolicy ==
            _HouseholdSessionGatePrivacyPolicy.accountReadUnavailable;
  }

  HouseholdLocalSnapshot _mergeSessionGateSnapshot(
    HouseholdLocalSnapshot current,
    _SessionGateResult sessionGate,
  ) {
    final gateSnapshot = sessionGate.snapshot!;
    final pendingScopeFingerprint =
        sessionGate.privacyPolicy ==
                _HouseholdSessionGatePrivacyPolicy.clearHouseholdContext &&
            current.pendingClearHouseholdScopeFingerprint == null &&
            current.householdId != null
        ? _householdScopeFingerprint(current.householdId!)
        : current.pendingClearHouseholdScopeFingerprint;
    final merged = current.copyWith(
      lastPhase: gateSnapshot.lastPhase,
      lastVisibleError: gateSnapshot.lastVisibleError,
      clearLastVisibleError: gateSnapshot.lastVisibleError == null,
      pendingClearHouseholdScopeFingerprint: pendingScopeFingerprint,
    );
    if (_shouldHideHouseholdContext(sessionGate.privacyPolicy)) {
      return merged.copyWith(clearHouseholdId: true);
    }
    return merged;
  }

  Future<HouseholdLocalSnapshot> _persistMergedSessionGateSnapshot({
    required HouseholdLocalSnapshot current,
    required _SessionGateResult sessionGate,
  }) async {
    if (sessionGate.privacyPolicy ==
        _HouseholdSessionGatePrivacyPolicy.accountReadUnavailable) {
      // Account state is unknown: hide cached private context in memory, but
      // do not persist a guessed signed-out state or authorize cleanup.
      return _mergeSessionGateSnapshot(current, sessionGate);
    }
    final merged = _mergeSessionGateSnapshot(current, sessionGate);
    final persisted = await _persistSnapshotWithResult(
      merged,
      fallbackOnWriteFailure: merged,
    );
    if (!persisted.wasDurablyStored ||
        sessionGate.privacyPolicy !=
            _HouseholdSessionGatePrivacyPolicy.clearHouseholdContext ||
        persisted.snapshot.pendingClearHouseholdScopeFingerprint == null) {
      return persisted.snapshot;
    }
    try {
      await _clearGeneratedContentForHouseholdScopeFingerprint(
        persisted.snapshot.pendingClearHouseholdScopeFingerprint!,
      );
    } on Object {
      // Keep the pending fingerprint durable until both stores complete.
      return persisted.snapshot;
    }
    return _clearPendingHouseholdScopeIntent(persisted.snapshot);
  }

  Future<AccountLocalSnapshotReadResult> _readAccountSnapshotSafely() async {
    try {
      final loader = _accountSnapshotReadResultLoader;
      if (loader != null) {
        return await loader();
      }
      return AccountLocalSnapshotReadResult.available(
        await _accountSnapshotLoader(),
      );
    } on FormatException {
      return AccountLocalSnapshotReadResult.unavailable();
    } on AccountLocalStoreException {
      return AccountLocalSnapshotReadResult.unavailable();
    } on Object {
      return AccountLocalSnapshotReadResult.unavailable();
    }
  }

  HouseholdLocalSnapshot _snapshotForApiError({
    required HouseholdLocalSnapshot current,
    required HouseholdApiException error,
    required String action,
    required bool preserveSharedContext,
    String? fallbackMessage,
  }) {
    final base = preserveSharedContext
        ? current
        : const HouseholdLocalSnapshot();
    if (error.isUnauthorized) {
      return base.copyWith(
        lastPhase: '${action}_invalid_session',
        lastVisibleError: '登录已过期，请重新登录后再试。',
      );
    }
    if (error.isConsentRequired || error.isConsentRevoked) {
      return base.copyWith(
        lastPhase: '${action}_consent_required',
        lastVisibleError: '同意已撤回；重新登录并再次同意后才能继续共享。',
      );
    }
    if (error.isRoleNotAllowed) {
      return base.copyWith(
        lastPhase: '${action}_role_not_allowed',
        lastVisibleError: '当前角色不能执行这个邀请动作。',
      );
    }
    if (error.isInviteExpired) {
      return base.copyWith(
        lastPhase: '${action}_expired',
        lastVisibleError: '这份邀请已过期，请让主照护者重新发送。',
      );
    }
    if (error.isInviteAlreadyUsed) {
      return base.copyWith(
        lastPhase: '${action}_already_used',
        lastVisibleError: '这份邀请已经被使用，不能重复接受。',
      );
    }
    if (error.isInviteRevoked) {
      return base.copyWith(
        lastPhase: '${action}_revoked',
        lastVisibleError: '这份邀请已撤销，请让主照护者重新发送。',
      );
    }
    if (error.isSharedContextUnavailable) {
      return base.copyWith(
        lastPhase: '${action}_shared_context_unavailable',
        lastVisibleError: '共享上下文暂不可用，请稍后重试。',
      );
    }
    if (error.isVersionBlocked) {
      return base.copyWith(
        lastPhase: '${action}_upgrade_required_426',
        lastVisibleError: '当前版本过旧，请升级 Baby Talk 后再继续邀请流程。',
      );
    }
    if (error.kind == HouseholdApiFailureKind.timeout) {
      return base.copyWith(
        lastPhase: '${action}_timeout',
        lastVisibleError:
            fallbackMessage ?? '请求超时，已保留最近一次稳定的 household 状态，可稍后重试。',
      );
    }
    if (error.kind == HouseholdApiFailureKind.network) {
      return base.copyWith(
        lastPhase: '${action}_offline',
        lastVisibleError: '当前离线，已保留最近一次稳定的 household 状态。',
      );
    }
    if (error.kind == HouseholdApiFailureKind.malformed) {
      return base.copyWith(
        lastPhase: '${action}_malformed_response',
        lastVisibleError: '服务响应异常，已停留在安全 fallback。',
      );
    }
    if (error.isServerFailure || error.code == 'invite_storage_unavailable') {
      return base.copyWith(
        lastPhase: '${action}_unavailable',
        lastVisibleError: '邀请服务暂时不可用，请稍后重试。',
      );
    }
    return base.copyWith(
      lastPhase: '${action}_request_failed',
      lastVisibleError: _sanitizeVisibleError(error.message),
    );
  }

  Future<HouseholdLocalSnapshot> _persistSnapshot(
    HouseholdLocalSnapshot snapshot, {
    String? phaseOnWriteFailure,
    String? messageOnWriteFailure,
  }) async {
    final result = await _persistSnapshotWithResult(
      snapshot,
      phaseOnWriteFailure: phaseOnWriteFailure,
      messageOnWriteFailure: messageOnWriteFailure,
    );
    return result.snapshot;
  }

  Future<_PersistSnapshotResult> _persistSnapshotWithResult(
    HouseholdLocalSnapshot snapshot, {
    String? phaseOnWriteFailure,
    String? messageOnWriteFailure,
    HouseholdLocalSnapshot? fallbackOnWriteFailure,
  }) async {
    try {
      await _localStore.write(snapshot);
      _lastKnownSnapshot = snapshot;
      return _PersistSnapshotResult(snapshot: snapshot, wasDurablyStored: true);
    } on HouseholdLocalStoreException catch (error) {
      final fallback =
          fallbackOnWriteFailure ??
          _lastKnownSnapshot ??
          HouseholdLocalSnapshot.empty;
      return _PersistSnapshotResult(
        snapshot: fallback.copyWith(
          lastPhase:
              phaseOnWriteFailure ?? '${snapshot.lastPhase}_persist_failed',
          lastVisibleError:
              messageOnWriteFailure ?? _sanitizeVisibleError(error.message),
        ),
        wasDurablyStored: false,
      );
    } on Object {
      final fallback =
          fallbackOnWriteFailure ??
          _lastKnownSnapshot ??
          HouseholdLocalSnapshot.empty;
      return _PersistSnapshotResult(
        snapshot: fallback.copyWith(
          lastPhase:
              phaseOnWriteFailure ?? '${snapshot.lastPhase}_persist_failed',
          lastVisibleError:
              messageOnWriteFailure ?? 'household 本地状态保存失败，已保留最近一次稳定结果。',
        ),
        wasDurablyStored: false,
      );
    }
  }

  bool _isServerConfirmedMissingMembership(HouseholdApiException error) {
    if (error.kind != HouseholdApiFailureKind.http || error.statusCode != 403) {
      return false;
    }
    return error.isMembershipMissing;
  }

  String _pendingHouseholdScopeFingerprint({
    required HouseholdLocalSnapshot previous,
    required HouseholdLocalSnapshot next,
  }) {
    final previousScope = previous.householdId;
    if (previousScope == null || previousScope == next.householdId) {
      return next.pendingClearHouseholdScopeFingerprint ?? '';
    }
    return _householdScopeFingerprint(previousScope);
  }

  Future<HouseholdLocalSnapshot> _persistConfirmedHouseholdSnapshot({
    required HouseholdLocalSnapshot previous,
    required HouseholdLocalSnapshot next,
    required String phaseOnWriteFailure,
    required String messageOnWriteFailure,
    required HouseholdLocalSnapshot fallbackOnWriteFailure,
  }) async {
    final pendingScopeFingerprint = _pendingHouseholdScopeFingerprint(
      previous: previous,
      next: next,
    );
    final candidate = pendingScopeFingerprint.isEmpty
        ? next.copyWith(clearPendingClearHouseholdScopeFingerprint: true)
        : next.copyWith(
            pendingClearHouseholdScopeFingerprint: pendingScopeFingerprint,
          );
    final persisted = await _persistSnapshotWithResult(
      candidate,
      phaseOnWriteFailure: phaseOnWriteFailure,
      messageOnWriteFailure: messageOnWriteFailure,
      fallbackOnWriteFailure: fallbackOnWriteFailure,
    );
    if (!persisted.wasDurablyStored ||
        persisted.snapshot.pendingClearHouseholdScopeFingerprint == null) {
      return persisted.snapshot;
    }

    final previousScope = previous.householdId;
    try {
      if (previousScope == null) {
        await _clearGeneratedContentForHouseholdScopeFingerprint(
          persisted.snapshot.pendingClearHouseholdScopeFingerprint!,
        );
      } else {
        await _clearGeneratedContentForHouseholdScope(previousScope);
      }
    } on Object {
      // Keep the pending fingerprint durable until both stores complete.
      return persisted.snapshot;
    }
    return _clearPendingHouseholdScopeIntent(persisted.snapshot);
  }

  Future<HouseholdLocalSnapshot> _retryPendingHouseholdScopeClear(
    HouseholdLocalSnapshot snapshot,
  ) async {
    final pending = snapshot.pendingClearHouseholdScopeFingerprint;
    if (pending == null) {
      return snapshot;
    }
    try {
      await _clearGeneratedContentForHouseholdScopeFingerprint(pending);
    } on Object {
      return snapshot;
    }
    return _clearPendingHouseholdScopeIntent(snapshot);
  }

  Future<HouseholdLocalSnapshot> _clearPendingHouseholdScopeIntent(
    HouseholdLocalSnapshot snapshot,
  ) async {
    final cleared = snapshot.copyWith(
      clearPendingClearHouseholdScopeFingerprint: true,
    );
    final persisted = await _persistSnapshotWithResult(
      cleared,
      phaseOnWriteFailure: 'household_clear_intent_persist_failed',
      messageOnWriteFailure: '共享家庭清理已完成，但本地清理标记保存失败，将在下次重试。',
      fallbackOnWriteFailure: snapshot,
    );
    return persisted.snapshot;
  }

  String _sanitizeVisibleError(String value) {
    var sanitized = value;
    sanitized = sanitized.replaceAll(
      RegExp(r'token\s*[:=]\s*[^\s,;]+', caseSensitive: false),
      'token=***',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'session\s*[:=]\s*[^\s,;]+', caseSensitive: false),
      'session=***',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'household_[A-Za-z0-9_-]+'),
      'household_***',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'\b[A-Za-z0-9_-]{12,64}\b'),
      '***',
    );
    return sanitized;
  }
}

String _householdScopeFingerprint(String householdScope) {
  final normalized = householdScope.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(householdScope, 'householdScope');
  }
  return sha256.convert(utf8.encode(normalized)).toString();
}

class _PersistSnapshotResult {
  const _PersistSnapshotResult({
    required this.snapshot,
    required this.wasDurablyStored,
  });

  final HouseholdLocalSnapshot snapshot;
  final bool wasDurablyStored;
}

class _HouseholdSnapshotReadResult {
  const _HouseholdSnapshotReadResult({
    required this.snapshot,
    required this.wasReadSuccessfully,
  });

  final HouseholdLocalSnapshot snapshot;
  final bool wasReadSuccessfully;
}

class _HouseholdCommandPreflight {
  const _HouseholdCommandPreflight._({
    required this.snapshot,
    required this.canProceed,
    this.sessionGate,
  });

  const _HouseholdCommandPreflight.ready(
    HouseholdLocalSnapshot snapshot,
    _SessionGateResult sessionGate,
  ) : this._(snapshot: snapshot, canProceed: true, sessionGate: sessionGate);

  const _HouseholdCommandPreflight.blocked(
    HouseholdLocalSnapshot snapshot, {
    _SessionGateResult? sessionGate,
  }) : this._(snapshot: snapshot, canProceed: false, sessionGate: sessionGate);

  final HouseholdLocalSnapshot snapshot;
  final bool canProceed;
  final _SessionGateResult? sessionGate;
}

enum _HouseholdSessionGatePrivacyPolicy {
  preserveStableHousehold,
  clearHouseholdContext,
  accountReadUnavailable,
}

class _SessionGateResult {
  const _SessionGateResult._({
    this.session,
    this.snapshot,
    required this.privacyPolicy,
  });

  const _SessionGateResult.ready(AccountSession session)
    : this._(
        session: session,
        privacyPolicy:
            _HouseholdSessionGatePrivacyPolicy.preserveStableHousehold,
      );

  const _SessionGateResult.blocked(
    HouseholdLocalSnapshot snapshot, {
    required _HouseholdSessionGatePrivacyPolicy privacyPolicy,
  }) : this._(snapshot: snapshot, privacyPolicy: privacyPolicy);

  _SessionGateResult.accountReadUnavailable({required String action})
    : this.blocked(
        HouseholdLocalSnapshot(
          lastPhase: '${action}_account_read_unavailable',
          lastVisibleError: '账号状态暂不可用，为保护隐私已隐藏共享家庭信息，请稍后重试。',
        ),
        privacyPolicy:
            _HouseholdSessionGatePrivacyPolicy.accountReadUnavailable,
      );

  final AccountSession? session;
  final HouseholdLocalSnapshot? snapshot;
  final _HouseholdSessionGatePrivacyPolicy privacyPolicy;

  bool get canProceed => session != null;
}
