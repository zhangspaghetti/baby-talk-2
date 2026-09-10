import 'dart:async';

import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:mobile/core/local_data_lifecycle/local_sensitive_data_clearance.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository_contract.dart';
import 'package:mobile/features/account/data/services/account_external_link_opener.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_sign_in_challenge.dart';
import 'package:mobile/features/account/domain/repositories/account_challenge_repository_contract.dart';

const _localOnlyPhoneHint = '先离线练习也没关系，登录后会补同步最近记录。';
const _signedOutPhoneHint = '请输入手机号与验证码，完成登录并同意同步。';

typedef AccountLocalSensitiveDataClearanceRunner =
    Future<LocalSensitiveDataClearanceReport> Function({
      required LocalSensitiveDataClearanceTrigger trigger,
      required String correlationId,
      required DateTime requestedAt,
    });

typedef AccountSessionEndedHandler = Future<void> Function();
typedef AccountConsentAcceptanceHandler =
    Future<AccountLocalSnapshot> Function({required String consentVersion});

class AccountNotifier extends ChangeNotifier with WidgetsBindingObserver {
  AccountNotifier({
    required AccountRepositoryContract repository,
    AccountExternalLinkOpener? linkOpener,
    AccountChallengeRepositoryContract? challengeRepository,
    AccountConsentAcceptanceHandler? acceptConsent,
    AccountLocalSensitiveDataClearanceRunner? localDataClearanceRunner,
    AccountSessionEndedHandler? onAccountSessionEnded,
    LocalSensitiveDataClock? clearanceClock,
  }) : _repository = repository,
       _linkOpener = linkOpener ?? const UrlLauncherAccountExternalLinkOpener(),
       _challengeRepository = challengeRepository,
       _acceptConsent = acceptConsent,
       _localDataClearanceRunner = localDataClearanceRunner,
       _onAccountSessionEnded = onAccountSessionEnded,
       _clearanceClock = clearanceClock ?? DateTime.now;

  final AccountRepositoryContract _repository;
  final AccountExternalLinkOpener _linkOpener;
  final AccountChallengeRepositoryContract? _challengeRepository;
  final AccountConsentAcceptanceHandler? _acceptConsent;
  final AccountLocalSensitiveDataClearanceRunner? _localDataClearanceRunner;
  final AccountSessionEndedHandler? _onAccountSessionEnded;
  final LocalSensitiveDataClock _clearanceClock;

  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _isGlobalOperationBusy = false;
  bool _observerAttached = false;
  bool _disposed = false;
  int _runtimeChangeToken = 0;
  Future<void>? _initializeFuture;
  Future<void>? _runtimeRefreshFuture;
  Future<bool>? _logoutFuture;
  AccountLocalSnapshot _snapshot = AccountLocalSnapshot.localOnly;
  String? _loadErrorMessage;
  String? _submissionMessage;
  String _phoneNumber = '';
  String _verificationCode = '';
  String? _phoneError;
  String? _verificationCodeError;
  AccountSignInChallenge? _signInChallenge;
  String? _challengePhoneNumber;
  int _challengeOperationEpoch = 0;
  int? _activeChallengeOperationEpoch;

  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  bool get _isChallengeOperationBusy =>
      _activeChallengeOperationEpoch != null &&
      _activeChallengeOperationEpoch == _challengeOperationEpoch;
  bool get isBusy => _isGlobalOperationBusy || _isChallengeOperationBusy;
  int get runtimeChangeToken => _runtimeChangeToken;
  AccountLocalSnapshot get snapshot => _snapshot;
  String? get loadErrorMessage => _loadErrorMessage;
  String? get submissionMessage => _submissionMessage;
  String get phoneNumber => _phoneNumber;
  String get verificationCode => _verificationCode;
  String? get phoneError => _phoneError;
  String? get verificationCodeError => _verificationCodeError;
  AccountSignInChallenge? get signInChallenge => _signInChallenge;
  bool get hasSignInChallenge => _signInChallenge != null;

  bool get isSignedIn =>
      _snapshot.session != null &&
      _snapshot.consentState != AccountConsentState.signedOut &&
      _snapshot.consentState != AccountConsentState.deleted;

  /// Persisted identity usable by account-scoped projections and recovery.
  /// Busy/loading snapshots are deliberately not considered ready.
  String? get stableAccountContext {
    if (!hasLoaded || isLoading || isBusy || !isSignedIn) {
      return null;
    }
    return scopedAccountContext;
  }

  /// Current in-memory scope identity, including busy transitions. Callers use
  /// this only to invalidate stale account-scoped work; never persist or log it.
  String? get scopedAccountContext {
    if (isSignedOut || isRevoked || isDeleted) {
      return null;
    }
    final value = _snapshot.session?.accountId.trim();
    return value == null || value.isEmpty ? null : value;
  }

  bool get hasPendingSync => _snapshot.pendingSyncCount > 0;
  bool get hasSyncFailure =>
      (_snapshot.lastVisibleError?.trim().isNotEmpty ?? false) &&
      !isSignedOut &&
      !isLocalOnly &&
      !isRevoked &&
      !isDeleted;

  bool get isSignedOut =>
      _snapshot.consentState == AccountConsentState.signedOut;

  bool get isLocalOnly =>
      _snapshot.consentState == AccountConsentState.localOnly;

  bool get isRevoked => _snapshot.consentState == AccountConsentState.revoked;

  bool get isDeleted => _snapshot.consentState == AccountConsentState.deleted;

  bool get isVersionBlocked => _snapshot.isUpgradeRequired;

  String? get upgradeUrl => _snapshot.upgradeUrl;

  bool get showUpgradeAction => isVersionBlocked;

  bool get canOpenUpgradePage {
    if (!showUpgradeAction || isBusy) {
      return false;
    }
    return validateAccountUpgradeUrl(_snapshot.upgradeUrl).isValid;
  }

  String get upgradeActionLabel => canOpenUpgradePage ? '立即升级' : '升级入口暂不可用';

  String? get upgradeActionHint {
    if (!showUpgradeAction) {
      return null;
    }
    final failureKind = validateAccountUpgradeUrl(
      _snapshot.upgradeUrl,
    ).failureKind;
    if (failureKind != null) {
      return messageForAccountUpgradeUrlFailure(failureKind);
    }
    return '升级完成后返回这里，再点一次“重试同步”即可恢复。';
  }

  String get maskedPhoneNumber =>
      _snapshot.session?.maskedPhoneNumber ??
      _snapshot.challenge?.maskedPhoneNumber ??
      '未登录';

  String get primaryHint {
    if (isDeleted) {
      return '账号已删除；本机练习记录仍可见，但重新同步前需要重新注册。';
    }
    if (isRevoked) {
      return '同意已撤回；重新登录并再次同意后才能继续同步。';
    }
    if (isVersionBlocked) {
      final upgradeHint = upgradeActionHint;
      if (upgradeHint == null) {
        return '当前版本暂时无法继续同步，请升级后再返回重试。';
      }
      return '当前版本暂时无法继续同步。$upgradeHint';
    }
    if (isSignedIn && hasPendingSync) {
      return '当前仍有练习记录待同步；可以继续练习，应用会在合适时机自动重试。';
    }
    if (isSignedIn) {
      return '账号已建立；在同一设备重新登录后，会恢复最近结果。';
    }
    if (isSignedOut) {
      return _signedOutPhoneHint;
    }
    return _localOnlyPhoneHint;
  }

  Future<void> initialize() {
    if (_observerAttached == false) {
      WidgetsBinding.instance.addObserver(this);
      _observerAttached = true;
    }
    if (_disposed) {
      return Future.value();
    }
    if (_hasLoaded || _isLoading) {
      return _initializeFuture ?? Future.value();
    }
    final future = _initializeInternal();
    _initializeFuture = future;
    return future.whenComplete(() {
      if (identical(_initializeFuture, future)) {
        _initializeFuture = null;
      }
    });
  }

  Future<void> _initializeInternal() async {
    await reload();
    if (_disposed) {
      return;
    }
    unawaited(
      refreshRuntimeState(
        trigger: AccountRuntimeTrigger.appBoot,
        announceIdleNoop: false,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        refreshRuntimeState(
          trigger: AccountRuntimeTrigger.foregroundResume,
          announceIdleNoop: false,
        ),
      );
    }
  }

  Future<void> reload() async {
    if (_disposed || _isLoading) {
      return;
    }
    _isLoading = true;
    _loadErrorMessage = null;
    notifyListeners();

    try {
      final nextSnapshot = await _repository.loadSnapshot();
      if (_disposed) {
        return;
      }
      _snapshot = nextSnapshot;
      _hasLoaded = true;
      _bumpRuntimeToken();
    } on Object {
      if (_disposed) {
        return;
      }
      _loadErrorMessage = '账号状态读取失败，请重试。';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updatePhoneNumber(String value) {
    final previousNormalized = _normalizePhone(_phoneNumber);
    _phoneNumber = value;
    final normalized = _normalizePhone(value);
    var shouldNotify = false;
    if (normalized != previousNormalized &&
        (_signInChallenge != null ||
            _challengePhoneNumber != null ||
            _isChallengeOperationBusy)) {
      _challengeOperationEpoch += 1;
      _activeChallengeOperationEpoch = null;
      _signInChallenge = null;
      _challengePhoneNumber = null;
      _verificationCode = '';
      _verificationCodeError = null;
      _submissionMessage = null;
      shouldNotify = true;
    }
    if (_phoneError != null) {
      _phoneError = null;
      shouldNotify = true;
    }
    if (shouldNotify) {
      notifyListeners();
    }
  }

  void updateVerificationCode(String value) {
    _verificationCode = value;
    if (_verificationCodeError != null) {
      _verificationCodeError = null;
      notifyListeners();
    }
  }

  Future<bool> requestSignInChallenge({
    required AccountChallengePurpose purpose,
    bool forceRefresh = false,
  }) async {
    final normalizedPhone = _normalizePhone(_phoneNumber);
    if (!_isValidPhone(normalizedPhone)) {
      _phoneError = '请输入 11 位手机号。';
      _submissionMessage = '手机号格式不正确，未发送验证码。';
      notifyListeners();
      return false;
    }
    if (isBusy) {
      return false;
    }
    final existing = _signInChallenge;
    if (!forceRefresh &&
        existing != null &&
        _challengePhoneNumber == normalizedPhone &&
        existing.purpose == purpose &&
        existing.expiresAt.isAfter(DateTime.now().toUtc())) {
      return true;
    }

    final operationEpoch = ++_challengeOperationEpoch;
    _activeChallengeOperationEpoch = operationEpoch;
    _phoneError = null;
    _submissionMessage = '正在发送验证码…';
    notifyListeners();
    try {
      final challengeRepository = _challengeRepository;
      if (challengeRepository == null) {
        throw UnsupportedError('当前账号仓库不支持验证码发送。');
      }
      final challenge = await challengeRepository.requestSignInChallenge(
        phoneNumber: normalizedPhone,
        purpose: purpose,
      );
      if (_disposed || operationEpoch != _challengeOperationEpoch) {
        return false;
      }
      _signInChallenge = challenge;
      _challengePhoneNumber = normalizedPhone;
      _phoneNumber = normalizedPhone;
      _submissionMessage = '验证码已发送至 ${_signInChallenge!.maskedPhoneNumber}';
      return true;
    } catch (_) {
      if (_disposed || operationEpoch != _challengeOperationEpoch) {
        return false;
      }
      _signInChallenge = null;
      _challengePhoneNumber = null;
      _submissionMessage = '发送验证码失败，请稍后重试。';
      return false;
    } finally {
      if (!_disposed &&
          operationEpoch == _challengeOperationEpoch &&
          _activeChallengeOperationEpoch == operationEpoch) {
        _activeChallengeOperationEpoch = null;
        notifyListeners();
      }
    }
  }

  Future<bool> submitChallengeSignIn({
    required AccountChallengePurpose purpose,
    bool acceptedConsent = false,
    String consentVersion = currentAccountConsentVersion,
  }) async {
    final normalizedPhone = _normalizePhone(_phoneNumber);
    final normalizedCode = _verificationCode.trim();
    final challenge = _signInChallenge;
    var hasError = false;
    if (!_isValidPhone(normalizedPhone)) {
      _phoneError = '请输入 11 位手机号。';
      hasError = true;
    } else {
      _phoneError = null;
    }
    if (challenge == null ||
        _challengePhoneNumber != normalizedPhone ||
        challenge.purpose != purpose) {
      _verificationCodeError = '请先发送验证码。';
      hasError = true;
    } else if (challenge.isExpired) {
      _verificationCodeError = '验证码已过期，请重新发送。';
      _submissionMessage = '验证码已过期，请重新发送。';
      hasError = true;
    } else if (!_isValidCode(normalizedCode)) {
      _verificationCodeError = '请输入 6 位验证码。';
      hasError = true;
    } else {
      _verificationCodeError = null;
    }
    if (hasError) {
      if (_verificationCodeError != '验证码已过期，请重新发送。') {
        _submissionMessage = '手机号或验证码格式不正确，未发起真实登录。';
      }
      notifyListeners();
      return false;
    }
    if (!acceptedConsent) {
      _submissionMessage = '请先阅读并同意服务条款和隐私协议（版本 $consentVersion）。';
      notifyListeners();
      return false;
    }
    if (isBusy) {
      return false;
    }

    final operationEpoch = ++_challengeOperationEpoch;
    _activeChallengeOperationEpoch = operationEpoch;
    _submissionMessage = '正在登录并同步最近结果…';
    notifyListeners();
    try {
      final challengeRepository = _challengeRepository;
      if (challengeRepository == null) {
        throw UnsupportedError('当前账号仓库不支持验证码登录。');
      }
      final completion = await challengeRepository.completeSignIn(
        phoneNumber: normalizedPhone,
        verificationCode: normalizedCode,
        challenge: challenge!,
      );
      if (_disposed || operationEpoch != _challengeOperationEpoch) {
        return false;
      }
      if (!completion.isAuthenticated) {
        _submissionMessage = completion.userMessage ?? '验证失败，请稍后重试。';
        return false;
      }
      var nextSnapshot = await _repository.loadSnapshot();
      final acceptConsent = _acceptConsent;
      if (acceptConsent != null) {
        nextSnapshot = await acceptConsent(consentVersion: consentVersion);
      }
      if (_disposed || operationEpoch != _challengeOperationEpoch) {
        return false;
      }
      _snapshot = nextSnapshot;
      _phoneError = null;
      _verificationCodeError = null;
      _verificationCode = '';
      _signInChallenge = null;
      _challengePhoneNumber = null;
      _bumpRuntimeToken();
      _submissionMessage = _buildActionMessage('登录已完成');
      return _snapshot.session != null;
    } catch (_) {
      if (_disposed || operationEpoch != _challengeOperationEpoch) {
        return false;
      }
      _submissionMessage = '验证失败，请稍后重试。';
      return false;
    } finally {
      if (!_disposed &&
          operationEpoch == _challengeOperationEpoch &&
          _activeChallengeOperationEpoch == operationEpoch) {
        _activeChallengeOperationEpoch = null;
        notifyListeners();
      }
    }
  }

  void clearSignInChallenge() {
    final shouldNotify =
        _signInChallenge != null ||
        _challengePhoneNumber != null ||
        _isChallengeOperationBusy ||
        _verificationCode.isNotEmpty;
    _challengeOperationEpoch += 1;
    _activeChallengeOperationEpoch = null;
    _signInChallenge = null;
    _challengePhoneNumber = null;
    _verificationCode = '';
    _verificationCodeError = null;
    _submissionMessage = null;
    if (shouldNotify) {
      notifyListeners();
    }
  }

  Future<bool> submitSignIn({
    bool acceptedConsent = false,
    String consentVersion = currentAccountConsentVersion,
  }) async {
    final normalizedPhone = _normalizePhone(_phoneNumber);
    final normalizedCode = _verificationCode.trim();
    var hasError = false;

    if (!_isValidPhone(normalizedPhone)) {
      _phoneError = '请输入 11 位手机号。';
      hasError = true;
    } else {
      _phoneError = null;
    }

    if (!_isValidCode(normalizedCode)) {
      _verificationCodeError = '请输入 6 位验证码。';
      hasError = true;
    } else {
      _verificationCodeError = null;
    }

    if (hasError) {
      _submissionMessage = '手机号或验证码格式不正确，未发起真实登录。';
      notifyListeners();
      return false;
    }
    if (!acceptedConsent) {
      _submissionMessage = '请先阅读并同意服务条款和隐私协议（版本 $consentVersion）。';
      notifyListeners();
      return false;
    }

    if (isBusy) {
      return false;
    }

    _isGlobalOperationBusy = true;
    _submissionMessage = '正在登录并同步最近结果…';
    notifyListeners();

    try {
      _snapshot = await _repository.signIn(
        phoneNumber: normalizedPhone,
        verificationCode: normalizedCode,
      );
      final acceptConsent = _acceptConsent;
      if (acceptConsent != null) {
        _snapshot = await acceptConsent(consentVersion: consentVersion);
      }
      _phoneError = null;
      _verificationCodeError = null;
      _phoneNumber = normalizedPhone;
      _verificationCode = '';
      _bumpRuntimeToken();
      _submissionMessage = _buildActionMessage('登录已完成');
      return _snapshot.session != null;
    } on Object {
      _submissionMessage = '登录失败，请稍后重试。';
      return false;
    } finally {
      _isGlobalOperationBusy = false;
      notifyListeners();
    }
  }

  Future<void> refreshRuntimeState({
    required AccountRuntimeTrigger trigger,
    bool announceIdleNoop = true,
  }) {
    if (_disposed) {
      return Future.value();
    }
    if (isBusy) {
      return _runtimeRefreshFuture ?? Future.value();
    }

    final future = _refreshRuntimeStateInternal(
      trigger: trigger,
      announceIdleNoop: announceIdleNoop,
    );
    _runtimeRefreshFuture = future;
    return future.whenComplete(() {
      if (identical(_runtimeRefreshFuture, future)) {
        _runtimeRefreshFuture = null;
      }
    });
  }

  Future<void> _refreshRuntimeStateInternal({
    required AccountRuntimeTrigger trigger,
    required bool announceIdleNoop,
  }) async {
    _isGlobalOperationBusy = true;
    if (announceIdleNoop) {
      _submissionMessage = _messageForTrigger(trigger);
      notifyListeners();
    }

    try {
      final nextSnapshot = await _repository.refreshRuntimeState(
        trigger: trigger,
      );
      if (_disposed) {
        return;
      }
      final changed =
          _snapshotFingerprint(_snapshot) != _snapshotFingerprint(nextSnapshot);
      _snapshot = nextSnapshot;
      if (changed) {
        _bumpRuntimeToken();
      }
      if (announceIdleNoop || _snapshot.lastVisibleError != null) {
        _submissionMessage = _buildActionMessage('已刷新账号与同步状态');
      }
    } on Object {
      if (_disposed) {
        return;
      }
      _submissionMessage = '刷新同步状态失败，请稍后重试。';
    } finally {
      _isGlobalOperationBusy = false;
      notifyListeners();
    }
  }

  Future<bool> openUpgradePage() async {
    if (!showUpgradeAction) {
      return false;
    }
    if (isBusy) {
      return false;
    }

    final validation = validateAccountUpgradeUrl(_snapshot.upgradeUrl);
    if (!validation.isValid) {
      _submissionMessage = messageForAccountUpgradeUrlFailure(
        validation.failureKind ?? AccountExternalLinkFailureKind.launchFailed,
      );
      notifyListeners();
      return false;
    }

    _isGlobalOperationBusy = true;
    _submissionMessage = '正在打开升级页面…';
    notifyListeners();

    try {
      await _linkOpener.openUpgradeUrl(validation.normalizedUrl!);
      _submissionMessage = '已打开升级页面；升级完成后请返回再试。';
      return true;
    } on AccountExternalLinkException catch (error) {
      _submissionMessage = error.message;
      return false;
    } on Object {
      _submissionMessage = '打开升级页面失败，请稍后重试。';
      return false;
    } finally {
      _isGlobalOperationBusy = false;
      notifyListeners();
    }
  }

  Future<void> clearSession({bool revertToLocalOnly = false}) async {
    if (!revertToLocalOnly) {
      await logout();
      return;
    }
    if (isBusy) {
      return;
    }
    _isGlobalOperationBusy = true;
    _submissionMessage = revertToLocalOnly ? '正在回到本机档案…' : '正在退出账号…';
    notifyListeners();

    try {
      LocalSensitiveDataClearanceReport? clearanceReport;
      var clearanceFailed = false;
      try {
        clearanceReport = await _clearLocalSensitiveDataForLogout();
      } catch (_) {
        clearanceFailed = true;
      }
      _snapshot = await _repository.clearPlaceholderSession(
        revertToLocalOnly: revertToLocalOnly,
      );
      if (revertToLocalOnly) {
        await _cancelReminderAfterAccountExit();
      }
      _bumpRuntimeToken();
      _submissionMessage =
          clearanceFailed || clearanceReport?.hasFailures == true
          ? '已退出账号，但部分本机敏感数据清理失败。'
          : revertToLocalOnly
          ? '已回到本机档案模式。'
          : '已退出账号；本机练习记录仍保留。';
    } on Object {
      _submissionMessage = '清理账号状态失败，请重试。';
    } finally {
      _isGlobalOperationBusy = false;
      notifyListeners();
    }
  }

  Future<bool> logout() {
    final running = _logoutFuture;
    if (running != null) {
      return running;
    }
    if (_disposed) {
      return Future<bool>.value(false);
    }
    if (!isSignedIn) {
      return Future<bool>.value(true);
    }
    if (isBusy) {
      return Future<bool>.value(false);
    }

    late final Future<bool> tracked;
    tracked = _logoutInternal().whenComplete(() {
      if (identical(_logoutFuture, tracked)) {
        _logoutFuture = null;
      }
    });
    _logoutFuture = tracked;
    return tracked;
  }

  Future<bool> _logoutInternal() async {
    _isGlobalOperationBusy = true;
    _submissionMessage = '正在退出登录…';
    notifyListeners();

    try {
      final signedOutSnapshot = await _repository.clearPlaceholderSession();
      if (_disposed) {
        return false;
      }
      _snapshot = signedOutSnapshot;
      _bumpRuntimeToken();
      _clearTransientAuthenticationInput();
      await _cancelReminderAfterAccountExit();

      LocalSensitiveDataClearanceReport? clearanceReport;
      var clearanceFailed = false;
      try {
        clearanceReport = await _clearLocalSensitiveDataForLogout();
      } on Object {
        clearanceFailed = true;
      }
      final clearanceCompleted =
          !clearanceFailed &&
          (clearanceReport == null ||
              clearanceReport.overallStatus ==
                  LocalSensitiveDataClearanceOverallStatus.completed);
      _submissionMessage = clearanceCompleted
          ? '已退出登录。'
          : '已退出登录，但部分本机敏感数据清理失败，请联系支持。';
      return clearanceCompleted;
    } on Object {
      _submissionMessage = '退出登录失败，请重试。';
      return false;
    } finally {
      _isGlobalOperationBusy = false;
      notifyListeners();
    }
  }

  void _clearTransientAuthenticationInput() {
    _challengeOperationEpoch += 1;
    _activeChallengeOperationEpoch = null;
    _phoneNumber = '';
    _verificationCode = '';
    _phoneError = null;
    _verificationCodeError = null;
    _signInChallenge = null;
    _challengePhoneNumber = null;
  }

  Future<void> revokeConsent() async {
    if (isBusy) {
      return;
    }
    _isGlobalOperationBusy = true;
    _submissionMessage = '正在撤回同意…';
    notifyListeners();

    try {
      _snapshot = await _repository.revokeConsent();
      await _cancelReminderAfterAccountExit();
      final clearanceReport =
          await _clearLocalSensitiveDataForConsentWithdrawal();
      _bumpRuntimeToken();
      _submissionMessage = clearanceReport?.hasFailures == true
          ? '已撤回同意，但部分本机敏感数据清理失败。'
          : '已撤回同意；后续需重新登录并再次同意。';
    } on Object {
      _submissionMessage = '撤回同意失败，请重试。';
    } finally {
      _isGlobalOperationBusy = false;
      notifyListeners();
    }
  }

  Future<void> deleteAccount() async {
    if (isBusy) {
      return;
    }
    _isGlobalOperationBusy = true;
    _submissionMessage = '正在删除账号…';
    notifyListeners();

    try {
      _snapshot = await _repository.deleteAccount();
      await _cancelReminderAfterAccountExit();
      LocalSensitiveDataClearanceReport? clearanceReport;
      try {
        clearanceReport = await _clearLocalSensitiveDataForAccountDeletion();
      } on Object {
        _bumpRuntimeToken();
        _submissionMessage = '账号已删除，但本机敏感数据清理失败，请联系支持。';
        return;
      }
      _bumpRuntimeToken();
      _submissionMessage = _messageForAccountDeletion(clearanceReport);
    } on Object {
      _submissionMessage = '删除账号失败，请重试。';
    } finally {
      _isGlobalOperationBusy = false;
      notifyListeners();
    }
  }

  Future<void> _cancelReminderAfterAccountExit() async {
    try {
      await _onAccountSessionEnded?.call();
    } on Object {
      // Account exit succeeds even when native reminder cleanup is unavailable.
    }
  }

  Future<void> clearRetainedLocalData() async {
    if (isBusy) {
      return;
    }
    _isGlobalOperationBusy = true;
    _submissionMessage = '正在清除本机保留数据…';
    notifyListeners();
    try {
      await _cancelReminderAfterAccountExit();
      final runner = _localDataClearanceRunner;
      if (runner == null) {
        throw StateError('本机数据清理服务不可用。');
      }
      final requestedAt = _clearanceClock().toUtc();
      final report = await runner(
        trigger: LocalSensitiveDataClearanceTrigger.deviceEraseConfirmed,
        correlationId:
            'account-device-erase-${requestedAt.microsecondsSinceEpoch}',
        requestedAt: requestedAt,
      );
      if (report.overallStatus !=
          LocalSensitiveDataClearanceOverallStatus.completed) {
        _submissionMessage = '本机数据清理未完成；账号不会被删除。请重试。';
        return;
      }
      _snapshot = await _repository.loadSnapshot();
      _bumpRuntimeToken();
      _submissionMessage = '本机保留数据已清除；账号不会被删除。';
    } on Object {
      _submissionMessage = '本机数据清理失败，请重试。';
    } finally {
      _isGlobalOperationBusy = false;
      notifyListeners();
    }
  }

  Future<void> handleHomeVisible() {
    if (!_hasLoaded && !_isLoading) {
      return initialize();
    }
    return refreshRuntimeState(
      trigger: AccountRuntimeTrigger.homeVisible,
      announceIdleNoop: false,
    );
  }

  String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  bool _isValidPhone(String value) {
    return RegExp(r'^1\d{10}$').hasMatch(value);
  }

  bool _isValidCode(String value) {
    return RegExp(r'^\d{6}$').hasMatch(value);
  }

  Future<LocalSensitiveDataClearanceReport?>
  _clearLocalSensitiveDataForAccountDeletion() {
    final runner = _localDataClearanceRunner;
    if (runner == null) {
      return Future<LocalSensitiveDataClearanceReport?>.value();
    }
    final requestedAt = _clearanceClock().toUtc();
    return runner(
      trigger: LocalSensitiveDataClearanceTrigger.accountDeletionConfirmed,
      correlationId: 'account-delete-${requestedAt.microsecondsSinceEpoch}',
      requestedAt: requestedAt,
    );
  }

  Future<LocalSensitiveDataClearanceReport?>
  _clearLocalSensitiveDataForLogout() {
    final runner = _localDataClearanceRunner;
    if (runner == null) {
      return Future<LocalSensitiveDataClearanceReport?>.value();
    }
    final requestedAt = _clearanceClock().toUtc();
    return runner(
      trigger: LocalSensitiveDataClearanceTrigger.logoutSessionOnly,
      correlationId: 'account-logout-${requestedAt.microsecondsSinceEpoch}',
      requestedAt: requestedAt,
    );
  }

  Future<LocalSensitiveDataClearanceReport?>
  _clearLocalSensitiveDataForConsentWithdrawal() {
    final runner = _localDataClearanceRunner;
    if (runner == null) {
      return Future<LocalSensitiveDataClearanceReport?>.value();
    }
    final requestedAt = _clearanceClock().toUtc();
    return runner(
      trigger: LocalSensitiveDataClearanceTrigger.consentWithdrawalConfirmed,
      correlationId:
          'account-consent-withdrawal-${requestedAt.microsecondsSinceEpoch}',
      requestedAt: requestedAt,
    );
  }

  String _messageForAccountDeletion(
    LocalSensitiveDataClearanceReport? clearanceReport,
  ) {
    if (clearanceReport == null) {
      return '账号已删除；如需恢复同步，请重新注册。';
    }
    return switch (clearanceReport.overallStatus) {
      LocalSensitiveDataClearanceOverallStatus.completed => '账号已删除；本机敏感数据已清理。',
      LocalSensitiveDataClearanceOverallStatus.completedWithFailures =>
        '账号已删除，但部分本机敏感数据清理失败，请联系支持。',
      LocalSensitiveDataClearanceOverallStatus.rejectedByGovernance =>
        '账号已删除，但本机敏感数据清理被治理门拒绝，请联系支持。',
    };
  }

  String _messageForTrigger(AccountRuntimeTrigger trigger) {
    switch (trigger) {
      case AccountRuntimeTrigger.appBoot:
        return '正在对齐本机账号与远端恢复状态…';
      case AccountRuntimeTrigger.loginSuccess:
        return '正在登录并同步最近结果…';
      case AccountRuntimeTrigger.homeVisible:
        return '正在检查首页返回后的同步状态…';
      case AccountRuntimeTrigger.foregroundResume:
        return '应用已打开，正在检查待同步记录…';
      case AccountRuntimeTrigger.manualRetry:
        return '正在手动重试同步…';
    }
  }

  String _buildActionMessage(String prefix) {
    final error = _snapshot.lastVisibleError;
    if (error != null && error.trim().isNotEmpty) {
      return '$prefix：$error';
    }
    if (isSignedIn && hasPendingSync) {
      return '$prefix：仍有 ${_snapshot.pendingSyncCount} 条练习记录待同步。';
    }
    if (isSignedIn) {
      return '$prefix：账号已接通，最近结果可恢复。';
    }
    return prefix;
  }

  void _bumpRuntimeToken() {
    _runtimeChangeToken += 1;
  }

  String _snapshotFingerprint(AccountLocalSnapshot snapshot) {
    return jsonEncode(snapshot.toJsonMap());
  }

  @override
  void notifyListeners() {
    if (_disposed) {
      return;
    }
    super.notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    if (_observerAttached) {
      WidgetsBinding.instance.removeObserver(this);
      _observerAttached = false;
    }
    unawaited(_repository.close());
    super.dispose();
  }
}
