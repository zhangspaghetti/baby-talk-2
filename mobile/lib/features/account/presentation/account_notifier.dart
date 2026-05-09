import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/data/services/account_external_link_opener.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';

const _localOnlyPhoneHint = '先离线练习也没关系，登录后会把 append-only 事件补传到后端。';
const _signedOutPhoneHint = '请输入手机号与验证码，完成登录并同意后再同步。';

/// Riverpod-ready notifier that replaces [AccountViewModel].
///
/// Uses [ChangeNotifier] as the base so existing widget code can adapt
/// incrementally without a full rewrite of the UI layer.
///
/// The API surface intentionally mirrors the old ViewModel so that callers
/// only need to swap the type they resolve.
///
/// [WidgetsBindingObserver] is kept as a mixin so the notifier reacts to
/// app lifecycle changes (foreground resume) exactly as the old ViewModel did.
class AccountNotifier extends ChangeNotifier with WidgetsBindingObserver {
  AccountNotifier({
    required AccountRepository repository,
    AccountExternalLinkOpener? linkOpener,
  }) : _repository = repository,
       _linkOpener = linkOpener ?? const UrlLauncherAccountExternalLinkOpener();

  final AccountRepository _repository;
  final AccountExternalLinkOpener _linkOpener;

  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _isBusy = false;
  bool _observerAttached = false;
  bool _disposed = false;
  int _runtimeChangeToken = 0;
  Future<void>? _initializeFuture;
  Future<void>? _runtimeRefreshFuture;
  AccountLocalSnapshot _snapshot = AccountLocalSnapshot.localOnly;
  String? _loadErrorMessage;
  String? _submissionMessage;
  String _phoneNumber = '';
  String _verificationCode = '';
  String? _phoneError;
  String? _verificationCodeError;

  // -- Getters ---------------------------------------------------------------

  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  bool get isBusy => _isBusy;
  int get runtimeChangeToken => _runtimeChangeToken;
  AccountLocalSnapshot get snapshot => _snapshot;
  String? get loadErrorMessage => _loadErrorMessage;
  String? get submissionMessage => _submissionMessage;
  String get phoneNumber => _phoneNumber;
  String get verificationCode => _verificationCode;
  String? get phoneError => _phoneError;
  String? get verificationCodeError => _verificationCodeError;

  bool get isSignedIn =>
      _snapshot.session != null &&
      _snapshot.consentState != AccountConsentState.signedOut &&
      _snapshot.consentState != AccountConsentState.deleted;

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
    if (!showUpgradeAction || _isBusy) {
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
    return '升级完成后返回这里，再点一次"重试同步"即可恢复。';
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
        return '当前版本已被服务端拦截，请升级后再返回重试同步。';
      }
      return '当前版本已被服务端拦截。$upgradeHint';
    }
    if (isSignedIn && hasPendingSync) {
      return '当前仍有待同步事件；可以继续练习，前台会在合适时机自动重试。';
    }
    if (isSignedIn) {
      return '账号已建立，同 installation 的重登会先 bootstrap 再恢复最近结果。';
    }
    if (isSignedOut) {
      return _signedOutPhoneHint;
    }
    return _localOnlyPhoneHint;
  }

  // -- Public API ------------------------------------------------------------

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
    } catch (error) {
      if (_disposed) {
        return;
      }
      _loadErrorMessage = '账号状态读取失败：$error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updatePhoneNumber(String value) {
    _phoneNumber = value;
    if (_phoneError != null) {
      _phoneError = null;
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

  Future<bool> submitSignIn() async {
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

    if (_isBusy) {
      return false;
    }

    _isBusy = true;
    _submissionMessage = '正在登录、同意并同步最近结果…';
    notifyListeners();

    try {
      _snapshot = await _repository.signIn(
        phoneNumber: normalizedPhone,
        verificationCode: normalizedCode,
      );
      _phoneError = null;
      _verificationCodeError = null;
      _phoneNumber = normalizedPhone;
      _verificationCode = '';
      _bumpRuntimeToken();
      _submissionMessage = _buildActionMessage('登录已完成');
      return _snapshot.session != null;
    } catch (error) {
      _submissionMessage = '登录失败：$error';
      return false;
    } finally {
      _isBusy = false;
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
    if (_isBusy) {
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
    _isBusy = true;
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
      _snapshot = nextSnapshot;
      _bumpRuntimeToken();
      if (announceIdleNoop || _snapshot.lastVisibleError != null) {
        _submissionMessage = _buildActionMessage('已刷新账号与同步状态');
      }
    } catch (error) {
      if (_disposed) {
        return;
      }
      _submissionMessage = '刷新同步状态失败：$error';
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> openUpgradePage() async {
    if (!showUpgradeAction) {
      return false;
    }
    if (_isBusy) {
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

    _isBusy = true;
    _submissionMessage = '正在打开升级页面…';
    notifyListeners();

    try {
      await _linkOpener.openUpgradeUrl(validation.normalizedUrl!);
      _submissionMessage = '已打开升级页面；升级完成后请返回再试。';
      return true;
    } on AccountExternalLinkException catch (error) {
      _submissionMessage = error.message;
      return false;
    } catch (error) {
      _submissionMessage = '打开升级页面失败：$error';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> clearSession({bool revertToLocalOnly = false}) async {
    if (_isBusy) {
      return;
    }
    _isBusy = true;
    _submissionMessage = revertToLocalOnly ? '正在回到 local-only…' : '正在退出账号…';
    notifyListeners();

    try {
      _snapshot = await _repository.clearPlaceholderSession(
        revertToLocalOnly: revertToLocalOnly,
      );
      _bumpRuntimeToken();
      _submissionMessage = revertToLocalOnly
          ? '已回到 local-only 档案模式。'
          : '已退出账号；本机练习记录仍保留。';
    } catch (error) {
      _submissionMessage = '清理账号状态失败：$error';
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> revokeConsent() async {
    if (_isBusy) {
      return;
    }
    _isBusy = true;
    _submissionMessage = '正在撤回同意…';
    notifyListeners();

    try {
      _snapshot = await _repository.revokeConsent();
      _bumpRuntimeToken();
      _submissionMessage = '已撤回同意；后续需重新登录并再次同意。';
    } catch (error) {
      _submissionMessage = '撤回同意失败：$error';
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> deleteAccount() async {
    if (_isBusy) {
      return;
    }
    _isBusy = true;
    _submissionMessage = '正在删除账号…';
    notifyListeners();

    try {
      _snapshot = await _repository.deleteAccount();
      _bumpRuntimeToken();
      _submissionMessage = '账号已删除；如需恢复同步，请重新注册。';
    } catch (error) {
      _submissionMessage = '删除账号失败：$error';
    } finally {
      _isBusy = false;
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

  // -- Private helpers -------------------------------------------------------

  String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  bool _isValidPhone(String value) {
    return RegExp(r'^1\d{10}$').hasMatch(value);
  }

  bool _isValidCode(String value) {
    return RegExp(r'^\d{6}$').hasMatch(value);
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
        return '应用已回到前台，正在检查待同步事件…';
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
      return '$prefix：仍有 ${_snapshot.pendingSyncCount} 条待同步事件。';
    }
    if (isSignedIn) {
      return '$prefix：账号已接通，最近结果可恢复。';
    }
    return prefix;
  }

  void _bumpRuntimeToken() {
    _runtimeChangeToken += 1;
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
    _disposed = true;
    if (_observerAttached) {
      WidgetsBinding.instance.removeObserver(this);
      _observerAttached = false;
    }
    unawaited(_repository.close());
    super.dispose();
  }
}
