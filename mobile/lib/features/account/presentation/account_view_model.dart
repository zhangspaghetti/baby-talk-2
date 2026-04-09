import 'package:flutter/foundation.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';

const _localOnlyPhoneHint = '请先输入本机调试手机号';
const _signedOutPhoneHint = '请输入手机号重新建立同步身份';

class AccountViewModel extends ChangeNotifier {
  AccountViewModel({required AccountRepository repository})
    : _repository = repository;

  final AccountRepository _repository;

  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _isSubmitting = false;
  AccountLocalSnapshot _snapshot = AccountLocalSnapshot.localOnly;
  String? _loadErrorMessage;
  String? _submissionMessage;
  String _phoneNumber = '';
  String _verificationCode = '';
  String? _phoneError;
  String? _verificationCodeError;

  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  bool get isSubmitting => _isSubmitting;
  AccountLocalSnapshot get snapshot => _snapshot;
  String? get loadErrorMessage => _loadErrorMessage;
  String? get submissionMessage => _submissionMessage;
  String get phoneNumber => _phoneNumber;
  String get verificationCode => _verificationCode;
  String? get phoneError => _phoneError;
  String? get verificationCodeError => _verificationCodeError;

  bool get isSignedInPendingSync =>
      _snapshot.session != null &&
      _snapshot.consentState == AccountConsentState.acceptedPendingSync;

  bool get isSignedOut =>
      _snapshot.consentState == AccountConsentState.signedOut;

  bool get isLocalOnly =>
      _snapshot.consentState == AccountConsentState.localOnly;

  String get maskedPhoneNumber =>
      _snapshot.session?.maskedPhoneNumber ??
      _snapshot.challenge?.maskedPhoneNumber ??
      '未登录';

  String get primaryHint {
    if (isSignedInPendingSync) {
      return '已进入待同步占位态，后续联网后会把 append-only 练习事件接到真实后端。';
    }
    if (isSignedOut) {
      return _signedOutPhoneHint;
    }
    return _localOnlyPhoneHint;
  }

  Future<void> initialize() async {
    if (_hasLoaded || _isLoading) {
      return;
    }
    await reload();
  }

  Future<void> reload() async {
    if (_isLoading) {
      return;
    }
    _isLoading = true;
    _loadErrorMessage = null;
    notifyListeners();

    try {
      _snapshot = await _repository.loadSnapshot();
      _hasLoaded = true;
    } catch (error) {
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

  Future<bool> submitPlaceholderSignIn() async {
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
      _submissionMessage = '手机号或验证码格式不正确，未写入任何本地账号状态。';
      notifyListeners();
      return false;
    }

    if (_isSubmitting) {
      return false;
    }

    _isSubmitting = true;
    _submissionMessage = '正在保存本机账号占位状态…';
    notifyListeners();

    try {
      _snapshot = await _repository.savePlaceholderSession(
        phoneNumber: normalizedPhone,
        verificationCode: normalizedCode,
      );
      _submissionMessage = '已保存占位登录，后续切片会把它替换成真实登录/同步合同。';
      _phoneError = null;
      _verificationCodeError = null;
      _phoneNumber = normalizedPhone;
      _verificationCode = '';
      return true;
    } catch (error) {
      _submissionMessage = '账号占位状态保存失败：$error';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> clearPlaceholderSession({bool revertToLocalOnly = false}) async {
    if (_isSubmitting) {
      return;
    }
    _isSubmitting = true;
    _submissionMessage = revertToLocalOnly ? '正在回退到本地档案模式…' : '正在清理占位登录状态…';
    notifyListeners();

    try {
      _snapshot = await _repository.clearPlaceholderSession(
        revertToLocalOnly: revertToLocalOnly,
      );
      _submissionMessage = revertToLocalOnly
          ? '已回到 local-only 档案模式。'
          : '已清理占位登录，当前视为未登录。';
    } catch (error) {
      _submissionMessage = '清理账号状态失败：$error';
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
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
}
