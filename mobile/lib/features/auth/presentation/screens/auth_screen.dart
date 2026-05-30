import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:pinput/pinput.dart';

/// Auth flow mode — V11 unified entry: codeLogin merges login+register detection.
enum AuthMode { codeLogin, passwordLogin, register, resetPassword }

class AuthScreen extends HookConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final mode = useState(AuthMode.codeLogin);
    final contactController = useTextEditingController();
    final codeController = useTextEditingController();
    final passwordController = useTextEditingController();
    final confirmPasswordController = useTextEditingController();

    final codeSent = useState(false);
    final captchaPassed = useState(false);
    final resendSeconds = useState(0);
    final acceptedTerms = useState(false);
    final passwordVisible = useState(false);
    final confirmPasswordVisible = useState(false);
    final errorMessage = useState<String?>(null);
    final infoMessage = useState<String?>(null);
    final isSubmitting = useState(false);

    useEffect(() {
      codeSent.value = false;
      captchaPassed.value = false;
      resendSeconds.value = 0;
      acceptedTerms.value = mode.value != AuthMode.register;
      passwordVisible.value = false;
      confirmPasswordVisible.value = false;
      codeController.clear();
      passwordController.clear();
      confirmPasswordController.clear();
      errorMessage.value = null;
      infoMessage.value = null;
      isSubmitting.value = false;
      return null;
    }, [mode.value]);

    useEffect(() {
      if (!codeSent.value || resendSeconds.value <= 0) {
        return null;
      }
      final timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (resendSeconds.value <= 1) {
          resendSeconds.value = 0;
          timer.cancel();
          return;
        }
        resendSeconds.value -= 1;
      });
      return timer.cancel;
    }, [codeSent.value]);

    final isCodeFlow = _usesVerificationCode(mode.value);
    final isResetPassword = mode.value == AuthMode.resetPassword;
    final showSegmented = !isResetPassword;

    Future<void> requestCode() async {
      errorMessage.value = null;
      infoMessage.value = null;
      if (!_isValidContact(contactController.text, mode.value)) {
        errorMessage.value = mode.value == AuthMode.passwordLogin ||
                mode.value == AuthMode.resetPassword
            ? '请输入正确的手机号或邮箱。'
            : '请输入 11 位手机号。';
        return;
      }
      await _showCaptchaSheet(
        context,
        purposeLabel: _captchaPurpose(mode.value),
        onPassed: () {
          captchaPassed.value = true;
          codeSent.value = true;
          resendSeconds.value = 59;
          infoMessage.value = l.discoverCodeSentToast;
        },
      );
    }

    void submit() {
      errorMessage.value = null;
      infoMessage.value = null;

      final validationError = _validateSubmission(
        mode: mode.value,
        contact: contactController.text,
        code: codeController.text,
        password: passwordController.text,
        confirmPassword: confirmPasswordController.text,
        codeSent: codeSent.value,
        acceptedTerms: acceptedTerms.value,
      );
      if (validationError != null) {
        errorMessage.value = validationError;
        return;
      }

      infoMessage.value = _successMessage(mode.value);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('BabyTalk')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppLayoutConstants.spacingXl),
              child: Semantics(
                container: true,
                label: _screenSemanticsLabel(mode.value, codeSent.value),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Brand trust header ---
                    _BrandHeader(colors: colors, l: l),
                    const SizedBox(height: AppLayoutConstants.spacingXl),

                    // --- Mode selector ---
                    if (showSegmented)
                      Semantics(
                        label: '认证方式选择',
                        child: _AuthModeSelector(
                          mode: mode.value,
                          onChanged: (m) => mode.value = m,
                        ),
                      )
                    else
                      _ModeHeader(
                        title: l.discoverResetPasswordTitle,
                        description: l.discoverResetPasswordSubtitle,
                      ),

                    const SizedBox(height: AppLayoutConstants.spacingXl),

                    // --- Contact input ---
                    Semantics(
                      textField: true,
                      label: _contactLabel(mode.value, l),
                      hint: _contactHelp(mode.value, l),
                      child: TextField(
                        key: const Key('auth-contact-field'),
                        controller: contactController,
                        keyboardType: _keyboardTypeForMode(mode.value),
                        autofillHints: _autofillHintsForMode(mode.value),
                        textInputAction: isCodeFlow
                            ? TextInputAction.next
                            : TextInputAction.done,
                        inputFormatters: _inputFormattersForMode(mode.value),
                        decoration: InputDecoration(
                          labelText: _contactLabel(mode.value, l),
                          helperText: _contactHelp(mode.value, l),
                          prefixText:
                              _usesPhoneOnly(mode.value) ? '+86 ' : null,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          errorMessage.value = null;
                          infoMessage.value = null;
                        },
                      ),
                    ),
                    const SizedBox(height: AppLayoutConstants.spacingMd),

                    // --- Verification code or password ---
                    if (isCodeFlow) ...[
                      _VerificationCodeStep(
                        mode: mode.value,
                        codeSent: codeSent.value,
                        captchaPassed: captchaPassed.value,
                        resendSeconds: resendSeconds.value,
                        codeController: codeController,
                        onSendCode: requestCode,
                      ),

                      // Password fields for register / reset
                      if (codeSent.value &&
                          (mode.value == AuthMode.register ||
                              mode.value == AuthMode.resetPassword)) ...[
                        const SizedBox(height: AppLayoutConstants.spacingMd),
                        _PasswordField(
                          controller: passwordController,
                          labelText: mode.value == AuthMode.register
                              ? l.discoverSetPasswordLabel
                              : l.discoverNewPasswordLabel,
                          semanticsLabel: mode.value == AuthMode.register
                              ? '设置注册密码'
                              : '输入新密码',
                          visible: passwordVisible.value,
                          onToggleVisibility: () {
                            passwordVisible.value = !passwordVisible.value;
                          },
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: AppLayoutConstants.spacingMd),
                        _PasswordField(
                          controller: confirmPasswordController,
                          labelText: l.discoverConfirmPasswordLabel,
                          semanticsLabel: '再次输入密码用于确认',
                          visible: confirmPasswordVisible.value,
                          onToggleVisibility: () {
                            confirmPasswordVisible.value =
                                !confirmPasswordVisible.value;
                          },
                          textInputAction: TextInputAction.done,
                        ),
                      ],
                    ] else ...[
                      // Password login mode
                      _PasswordField(
                        controller: passwordController,
                        labelText: l.discoverPasswordLabel,
                        semanticsLabel: '输入登录密码',
                        visible: passwordVisible.value,
                        onToggleVisibility: () {
                          passwordVisible.value = !passwordVisible.value;
                        },
                        textInputAction: TextInputAction.done,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Semantics(
                          button: true,
                          label: '忘记密码，进入重置密码流程',
                          child: TextButton(
                            onPressed: () =>
                                mode.value = AuthMode.resetPassword,
                            child: Text(l.discoverForgotPassword),
                          ),
                        ),
                      ),
                    ],

                    // --- Terms (register only) ---
                    if (mode.value == AuthMode.register) ...[
                      const SizedBox(height: AppLayoutConstants.spacingMd),
                      _TermsRow(
                        accepted: acceptedTerms.value,
                        onChanged: (v) => acceptedTerms.value = v,
                      ),
                    ],

                    // --- Privacy note (code login, pre-submit) ---
                    if (mode.value == AuthMode.codeLogin &&
                        !codeSent.value) ...[
                      const SizedBox(height: AppLayoutConstants.spacingSm),
                      Semantics(
                        label: l.discoverPrivacyNote,
                        child: Text(
                          l.discoverPrivacyNote,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],

                    // --- Status messages ---
                    if (errorMessage.value != null) ...[
                      const SizedBox(height: AppLayoutConstants.spacingMd),
                      _StatusMessage(
                        message: errorMessage.value!,
                        isError: true,
                      ),
                    ],
                    if (infoMessage.value != null) ...[
                      const SizedBox(height: AppLayoutConstants.spacingMd),
                      _StatusMessage(
                        message: infoMessage.value!,
                        isError: false,
                      ),
                    ],

                    // --- Submit button ---
                    const SizedBox(height: AppLayoutConstants.spacingXl),
                    Semantics(
                      button: true,
                      label: _mainButtonSemantics(mode.value, codeSent.value),
                      child: FilledButton(
                        onPressed: isSubmitting.value ? null : submit,
                        child: isSubmitting.value
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_getMainButtonText(mode.value, l)),
                      ),
                    ),

                    // --- Footer links ---
                    const SizedBox(height: AppLayoutConstants.spacingMd),
                    _FooterLinks(mode: mode, codeSent: codeSent),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Static helpers ────────────────────────────────────────

  static bool _usesVerificationCode(AuthMode mode) {
    return mode == AuthMode.codeLogin ||
        mode == AuthMode.register ||
        mode == AuthMode.resetPassword;
  }

  static bool _usesPhoneOnly(AuthMode mode) {
    return mode == AuthMode.codeLogin || mode == AuthMode.register;
  }

  static TextInputType _keyboardTypeForMode(AuthMode mode) {
    return _usesPhoneOnly(mode) ? TextInputType.phone : TextInputType.emailAddress;
  }

  static List<String> _autofillHintsForMode(AuthMode mode) {
    if (_usesPhoneOnly(mode)) {
      return const [AutofillHints.telephoneNumber];
    }
    return const [AutofillHints.username, AutofillHints.email];
  }

  static List<TextInputFormatter> _inputFormattersForMode(AuthMode mode) {
    if (!_usesPhoneOnly(mode)) {
      return const [];
    }
    return [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(11),
    ];
  }

  static String _contactLabel(AuthMode mode, AppLocalizations l) {
    switch (mode) {
      case AuthMode.codeLogin:
      case AuthMode.register:
        return l.discoverPhoneLabel;
      case AuthMode.passwordLogin:
      case AuthMode.resetPassword:
        return '手机号或邮箱';
    }
  }

  static String _contactHelp(AuthMode mode, AppLocalizations l) {
    switch (mode) {
      case AuthMode.codeLogin:
        return l.discoverPhoneHint;
      case AuthMode.passwordLogin:
        return '输入注册手机号或邮箱';
      case AuthMode.register:
        return '用于创建 BabyTalk 账号';
      case AuthMode.resetPassword:
        return '用于接收重置验证码';
    }
  }

  static String _captchaPurpose(AuthMode mode) {
    switch (mode) {
      case AuthMode.codeLogin:
        return '登录验证码';
      case AuthMode.register:
        return '注册验证码';
      case AuthMode.resetPassword:
        return '重置密码验证码';
      case AuthMode.passwordLogin:
        return '验证码';
    }
  }

  static String _screenSemanticsLabel(AuthMode mode, bool codeSent) {
    final step = codeSent ? '验证码已发送，请输入验证码继续' : '请先填写账号信息';
    switch (mode) {
      case AuthMode.codeLogin:
        return '验证码登录页面，$step';
      case AuthMode.passwordLogin:
        return '密码登录页面，请输入账号和密码';
      case AuthMode.register:
        return '注册账号页面，$step';
      case AuthMode.resetPassword:
        return '重置密码页面，$step';
    }
  }

  static String _getMainButtonText(AuthMode mode, AppLocalizations l) {
    switch (mode) {
      case AuthMode.codeLogin:
      case AuthMode.passwordLogin:
        return l.discoverLoginButton;
      case AuthMode.register:
        return '完成注册';
      case AuthMode.resetPassword:
        return '确认重置并登录';
    }
  }

  static String _mainButtonSemantics(AuthMode mode, bool codeSent) {
    switch (mode) {
      case AuthMode.codeLogin:
        return codeSent ? '提交验证码登录' : '登录，需先发送验证码';
      case AuthMode.passwordLogin:
        return '提交密码登录';
      case AuthMode.register:
        return codeSent ? '提交验证码和密码完成注册' : '注册，需先发送验证码';
      case AuthMode.resetPassword:
        return codeSent ? '提交验证码和新密码完成重置' : '重置密码，需先发送验证码';
    }
  }

  static bool _isValidContact(String value, AuthMode mode) {
    final trimmed = value.trim();
    if (_usesPhoneOnly(mode)) {
      return RegExp(r'^\d{11}$').hasMatch(trimmed);
    }
    return RegExp(r'^\d{11}$').hasMatch(trimmed) ||
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed);
  }

  static String? _validateSubmission({
    required AuthMode mode,
    required String contact,
    required String code,
    required String password,
    required String confirmPassword,
    required bool codeSent,
    required bool acceptedTerms,
  }) {
    if (!_isValidContact(contact, mode)) {
      return mode == AuthMode.passwordLogin || mode == AuthMode.resetPassword
          ? '请输入正确的手机号或邮箱。'
          : '请输入 11 位手机号。';
    }

    if (mode == AuthMode.passwordLogin) {
      if (password.length < 6) {
        return '请输入至少 6 位密码。';
      }
      return null;
    }

    if (!codeSent) {
      return '请先点击发送验证码并完成人机校验。';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code.trim())) {
      return '请输入 6 位短信验证码。';
    }

    if (mode == AuthMode.register || mode == AuthMode.resetPassword) {
      if (password.length < 8) {
        return '密码至少需要 8 位，建议包含字母和数字。';
      }
      if (password != confirmPassword) {
        return '两次输入的密码不一致。';
      }
    }

    if (mode == AuthMode.register && !acceptedTerms) {
      return '请先阅读并同意服务条款和隐私协议。';
    }

    return null;
  }

  static String _successMessage(AuthMode mode) {
    switch (mode) {
      case AuthMode.codeLogin:
      case AuthMode.passwordLogin:
        return '登录信息已提交。';
      case AuthMode.register:
        return '注册信息已提交。';
      case AuthMode.resetPassword:
        return '密码重置信息已提交。';
    }
  }

  static Future<void> _showCaptchaSheet(
    BuildContext context, {
    required String purposeLabel,
    required VoidCallback onPassed,
  }) {
    final l = AppLocalizations.of(context)!;
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppLayoutConstants.spacingXl),
          child: Semantics(
            container: true,
            label: '人机校验弹层，通过后发送$purposeLabel',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l.discoverCaptchaTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: AppLayoutConstants.spacingXs),
                Text(
                  l.discoverCaptchaDescription,
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppLayoutConstants.spacingXl),
                Semantics(
                  label: l.discoverCaptchaArea,
                  hint: '点击模拟验证通过按钮完成校验',
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(
                        AppLayoutConstants.cardRadius,
                      ),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '请完成拼图 / CAPTCHA',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: AppLayoutConstants.spacingXl),
                Semantics(
                  button: true,
                  label: '模拟人机校验通过并发送验证码',
                  child: FilledButton(
                    onPressed: () {
                      onPassed();
                      Navigator.of(ctx).pop();
                    },
                    child: Text(l.discoverCaptchaPass),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(l.discoverCaptchaCancel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Brand Header (V11 trust copy)
// ─────────────────────────────────────────────────────────────

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.colors, required this.l});

  final BabyTalkColors colors;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.discoverUnifiedLoginTitle,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.discoverUnifiedLoginSubtitle,
            style: TextStyle(
              fontSize: 15,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 14,
                color: colors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                l.discoverTrustPrivacy,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Auth Mode Selector (Segmented)
// ─────────────────────────────────────────────────────────────

class _AuthModeSelector extends StatelessWidget {
  const _AuthModeSelector({
    required this.mode,
    required this.onChanged,
  });

  final AuthMode mode;
  final ValueChanged<AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Semantics(
      label: '认证方式选择',
      child: SegmentedButton<AuthMode>(
        segments: [
          ButtonSegment(
            value: AuthMode.codeLogin,
            label: Text(l.discoverModeCodeLogin),
          ),
          ButtonSegment(
            value: AuthMode.passwordLogin,
            label: Text(l.discoverModePasswordLogin),
          ),
          ButtonSegment(
            value: AuthMode.register,
            label: Text(l.discoverModeRegister),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (selection) {
          onChanged(selection.first);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Mode Header (for reset password)
// ─────────────────────────────────────────────────────────────

class _ModeHeader extends StatelessWidget {
  const _ModeHeader({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(description, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Verification Code Step (V11: improved autofill + visual)
// ─────────────────────────────────────────────────────────────

class _VerificationCodeStep extends StatelessWidget {
  const _VerificationCodeStep({
    required this.mode,
    required this.codeSent,
    required this.captchaPassed,
    required this.resendSeconds,
    required this.codeController,
    required this.onSendCode,
  });

  final AuthMode mode;
  final bool codeSent;
  final bool captchaPassed;
  final int resendSeconds;
  final TextEditingController codeController;
  final VoidCallback onSendCode;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;

    if (!codeSent) {
      return Semantics(
        button: true,
        label: '${_sendButtonText(mode, l)}，点击后打开人机校验',
        child: OutlinedButton(
          onPressed: onSendCode,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(
              AppLayoutConstants.buttonMinHeight,
            ),
          ),
          child: Text(_sendButtonText(mode, l)),
        ),
      );
    }

    // pinput OTP boxes — Warm Paper token-driven theme (替代自研等宽 TextField)。
    final defaultPinTheme = PinTheme(
      width: 48,
      height: 56,
      textStyle: TextStyle(
        fontSize: 18,
        fontFamily: 'JetBrains Mono',
        color: colors.textPrimary,
      ),
      decoration: BoxDecoration(
        color: colors.bgSunken,
        borderRadius: BorderRadius.circular(AppLayoutConstants.smallRadius),
        border: Border.all(color: colors.outlineSoft),
      ),
    );
    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: colors.bgSurface,
        border: Border.all(color: colors.accent, width: 1.5),
      ),
    );
    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: colors.bgSurface,
        border: Border.all(color: colors.accent),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status line
        Semantics(
          liveRegion: true,
          label: captchaPassed ? l.discoverVerificationPassed : l.discoverVerificationPending,
          child: Text(
            captchaPassed ? l.discoverVerificationPassed : '等待验证码发送。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: AppLayoutConstants.spacingSm),

        // Field label
        Text(
          l.discoverCodeLabel,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppLayoutConstants.spacingXs),

        // Code input (V11: pinput OTP boxes — SMS autofill + monospaced)
        Semantics(
          textField: true,
          label: '短信验证码输入框，6 位数字，支持自动填充',
          child: Pinput(
            key: const Key('auth-code-field'),
            controller: codeController,
            length: 6,
            keyboardType: TextInputType.number,
            defaultPinTheme: defaultPinTheme,
            focusedPinTheme: focusedPinTheme,
            submittedPinTheme: submittedPinTheme,
            separatorBuilder: (_) =>
                const SizedBox(width: AppLayoutConstants.spacingXs),
          ),
        ),
        const SizedBox(height: AppLayoutConstants.spacingXs),

        // Auto-fill hint + resend
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                l.discoverCodeAutoHint,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: colors.textMuted),
              ),
            ),
            Semantics(
              button: true,
              label: resendSeconds == 0
                  ? l.discoverResendCode
                  : l.discoverResendCountdown(resendSeconds),
              child: TextButton(
                onPressed: resendSeconds == 0 ? onSendCode : null,
                child: Text(
                  resendSeconds == 0
                      ? l.discoverResendCode
                      : '${resendSeconds}s',
                  style: TextStyle(
                    color:
                        resendSeconds == 0 ? colors.accent : colors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppLayoutConstants.spacingXs),

        // Resend countdown
        Semantics(
          liveRegion: true,
          label: resendSeconds == 0
              ? '可以重新发送验证码'
              : '重新发送验证码倒计时 $resendSeconds 秒',
          child: Text(
            resendSeconds == 0
                ? l.discoverResendReady
                : l.discoverResendCountdown(resendSeconds),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  static String _sendButtonText(AuthMode mode, AppLocalizations l) {
    switch (mode) {
      case AuthMode.codeLogin:
        return l.discoverGetCode;
      case AuthMode.register:
        return '发送注册验证码';
      case AuthMode.resetPassword:
        return '发送重置验证码';
      case AuthMode.passwordLogin:
        return l.discoverGetCode;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Password Field
// ─────────────────────────────────────────────────────────────

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.labelText,
    required this.semanticsLabel,
    required this.visible,
    required this.onToggleVisibility,
    required this.textInputAction,
  });

  final TextEditingController controller;
  final String labelText;
  final String semanticsLabel;
  final bool visible;
  final VoidCallback onToggleVisibility;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      textField: true,
      label: semanticsLabel,
      child: TextField(
        key: ValueKey(labelText),
        controller: controller,
        obscureText: !visible,
        autofillHints: const [AutofillHints.password],
        textInputAction: textInputAction,
        decoration: InputDecoration(
          labelText: labelText,
          helperText: '至少 8 位，建议包含字母和数字',
          border: const OutlineInputBorder(),
          prefixIcon: Icon(
            Icons.lock_outline,
            size: 20,
            color: colors.textMuted,
          ),
          suffixIcon: Semantics(
            button: true,
            label: visible ? '隐藏密码' : '显示密码',
            child: IconButton(
              onPressed: onToggleVisibility,
              icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Terms Row
// ─────────────────────────────────────────────────────────────

class _TermsRow extends StatelessWidget {
  const _TermsRow({required this.accepted, required this.onChanged});

  final bool accepted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    return Semantics(
      checked: accepted,
      button: true,
      label: '同意服务条款和隐私协议',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppLayoutConstants.cardRadius),
        onTap: () => onChanged(!accepted),
        child: Row(
          children: [
            Checkbox(
              value: accepted,
              onChanged: (value) => onChanged(value ?? false),
            ),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodySmall,
                  children: [
                    TextSpan(text: l.discoverTermsPrefix),
                    TextSpan(
                      text: l.discoverTermsOfService,
                      style: TextStyle(
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: l.discoverPrivacyPolicy),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Status Message
// ─────────────────────────────────────────────────────────────

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final foreground = isError ? colors.error : colors.success;
    final background = isError ? colors.errorSoft : colors.successSoft;

    return Semantics(
      liveRegion: true,
      label: isError ? '错误提示：$message' : '状态提示：$message',
      child: Container(
        padding: const EdgeInsets.all(AppLayoutConstants.spacingMd),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppLayoutConstants.cardRadius),
          border: Border.all(color: foreground.withValues(alpha: 0.24)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: foreground,
            ),
            const SizedBox(width: AppLayoutConstants.spacingXs),
            Expanded(
              child: Text(message, style: TextStyle(color: foreground)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Footer Links
// ─────────────────────────────────────────────────────────────

class _FooterLinks extends StatelessWidget {
  const _FooterLinks({required this.mode, required this.codeSent});

  final ValueNotifier<AuthMode> mode;
  final ValueNotifier<bool> codeSent;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    if (mode.value == AuthMode.resetPassword) {
      return Center(
        child: TextButton(
          onPressed: () => mode.value = AuthMode.passwordLogin,
          child: Text(l.discoverReturnToLogin),
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppLayoutConstants.spacingXs,
      children: [
        if (mode.value != AuthMode.codeLogin)
          TextButton(
            onPressed: () => mode.value = AuthMode.codeLogin,
            child: Text(l.discoverModeCodeLogin),
          ),
        if (mode.value != AuthMode.passwordLogin)
          TextButton(
            onPressed: () => mode.value = AuthMode.passwordLogin,
            child: Text(l.discoverModePasswordLogin),
          ),
        if (mode.value != AuthMode.register)
          TextButton(
            onPressed: () => mode.value = AuthMode.register,
            child: Text(l.discoverModeRegister),
          ),
      ],
    );
  }
}
