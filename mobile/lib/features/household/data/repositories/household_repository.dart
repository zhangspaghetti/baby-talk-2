import 'dart:async';

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

class HouseholdRepository {
  HouseholdRepository({
    required HouseholdLocalStore localStore,
    required HouseholdApiService apiService,
    required HouseholdAccountSnapshotLoader accountSnapshotLoader,
    required PersistRefreshedSession persistRefreshedSession,
  }) : _localStore = localStore,
       _apiService = apiService,
       _accountSnapshotLoader = accountSnapshotLoader,
       _persistRefreshedSession = persistRefreshedSession;

  final HouseholdLocalStore _localStore;
  final HouseholdApiService _apiService;
  final HouseholdAccountSnapshotLoader _accountSnapshotLoader;
  final PersistRefreshedSession _persistRefreshedSession;

  Future<HouseholdLocalSnapshot>? _refreshFuture;
  Future<HouseholdInviteAcceptResult>? _acceptFuture;
  Future<HouseholdCreateInviteResult>? _createFuture;

  Future<HouseholdLocalSnapshot> loadSnapshot() async {
    try {
      return await _localStore.read();
    } on FormatException {
      return const HouseholdLocalSnapshot(
        lastPhase: 'local_snapshot_reset',
        lastVisibleError: 'household 本地状态损坏，已回退到安全空态。',
      );
    } on HouseholdLocalStoreException catch (error) {
      return HouseholdLocalSnapshot(
        lastPhase: 'local_store_unavailable',
        lastVisibleError: _sanitizeVisibleError(error.message),
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
    final current = await _readSnapshotSafely();
    final sessionGate = await _resolveSessionGate(action: 'create_invite');
    if (!sessionGate.canProceed) {
      final snapshot = await _persistSnapshot(sessionGate.snapshot!);
      return HouseholdCreateInviteResult(
        snapshot: snapshot,
        message: snapshot.lastVisibleError ?? '当前无法创建邀请。',
      );
    }

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

  Future<HouseholdInviteAcceptResult> _acceptInviteInternal({
    required String token,
    required String source,
  }) async {
    final current = await _readSnapshotSafely();
    final sessionGate = await _resolveSessionGate(action: 'accept_invite');
    if (!sessionGate.canProceed) {
      final snapshot = await _persistSnapshot(sessionGate.snapshot!);
      return HouseholdInviteAcceptResult(
        snapshot: snapshot,
        message: snapshot.lastVisibleError ?? '当前无法接受邀请。',
      );
    }

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
    final current = await _readSnapshotSafely();
    final sessionGate = await _resolveSessionGate(action: 'shared_context');
    if (!sessionGate.canProceed) {
      return _persistSnapshot(sessionGate.snapshot!);
    }

    try {
      final response = await _apiService.fetchSharedContext(
        session: sessionGate.session!,
        persistRefreshedSession: _persistRefreshedSession,
      );
      return _persistSnapshot(
        HouseholdLocalSnapshot(
          householdId: response.householdId,
          role: response.role,
          sharedContext: response.snapshot,
          lastPhase: 'shared_context_ready',
          lastAcceptedAt: response.lastAcceptedAt,
        ),
        phaseOnWriteFailure: 'shared_context_persist_failed',
        messageOnWriteFailure: '共享上下文已刷新，但 household 本地状态保存失败。',
      );
    } on HouseholdApiException catch (error) {
      return _persistSnapshot(
        _snapshotForApiError(
          current: current,
          error: error,
          action: 'shared_context',
          preserveSharedContext:
              error.kind != HouseholdApiFailureKind.malformed,
          fallbackMessage: reason == 'foreground_resume'
              ? '前台恢复时共享上下文刷新失败，已保留最近一次稳定结果。'
              : null,
        ),
      );
    }
  }

  Future<HouseholdLocalSnapshot> _readSnapshotSafely() async {
    return loadSnapshot();
  }

  Future<_SessionGateResult> _resolveSessionGate({
    required String action,
  }) async {
    final accountSnapshot = await _readAccountSnapshotSafely();
    final session = accountSnapshot.session;
    if (session == null ||
        accountSnapshot.consentState == AccountConsentState.localOnly ||
        accountSnapshot.consentState == AccountConsentState.signedOut) {
      return _SessionGateResult.blocked(
        HouseholdLocalSnapshot(
          lastPhase: '${action}_invalid_session',
          lastVisibleError: '请先登录并完成同意，再继续照护邀请流程。',
        ),
      );
    }
    if (!session.hasJwtTokens) {
      return _SessionGateResult.blocked(
        HouseholdLocalSnapshot(
          lastPhase: '${action}_invalid_session',
          lastVisibleError: '登录已过期，请重新登录后再试。',
        ),
      );
    }
    if (accountSnapshot.consentState == AccountConsentState.revoked) {
      return _SessionGateResult.blocked(
        HouseholdLocalSnapshot(
          lastPhase: '${action}_consent_required',
          lastVisibleError: '同意已撤回；重新登录并再次同意后才能继续共享。',
        ),
      );
    }
    if (accountSnapshot.consentState == AccountConsentState.deleted) {
      return _SessionGateResult.blocked(
        HouseholdLocalSnapshot(
          lastPhase: '${action}_account_deleted',
          lastVisibleError: '账号已删除；请重新注册后再继续共享。',
        ),
      );
    }
    return _SessionGateResult.ready(session);
  }

  Future<AccountLocalSnapshot> _readAccountSnapshotSafely() async {
    try {
      return await _accountSnapshotLoader();
    } on FormatException {
      return AccountLocalSnapshot.signedOut;
    } catch (_) {
      return AccountLocalSnapshot.signedOut;
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
    try {
      await _localStore.write(snapshot);
      return snapshot;
    } on HouseholdLocalStoreException catch (error) {
      return snapshot.copyWith(
        lastPhase:
            phaseOnWriteFailure ?? '${snapshot.lastPhase}_persist_failed',
        lastVisibleError:
            messageOnWriteFailure ?? _sanitizeVisibleError(error.message),
      );
    }
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

class _SessionGateResult {
  const _SessionGateResult._({this.session, this.snapshot});

  const _SessionGateResult.ready(AccountSession session)
    : this._(session: session);

  const _SessionGateResult.blocked(HouseholdLocalSnapshot snapshot)
    : this._(snapshot: snapshot);

  final AccountSession? session;
  final HouseholdLocalSnapshot? snapshot;

  bool get canProceed => session != null;
}
