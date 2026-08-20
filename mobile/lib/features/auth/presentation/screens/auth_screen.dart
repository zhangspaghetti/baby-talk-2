import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/router/account_entry_route_contract.dart';
import 'package:mobile/app/router/app_route_contract.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/account/domain/models/account_sign_in_challenge.dart';
import 'package:mobile/features/account/data/repositories/account_repository_contract.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:pinput/pinput.dart';
import 'package:go_router/go_router.dart';

/// Auth flow mode — V11 unified entry: codeLogin merges login+register detection.
enum AuthMode { codeLogin, register }

class AuthScreen extends HookConsumerWidget {
  const AuthScreen({super.key, this.origin = AccountEntryOrigin.settings});

  final AccountEntryOrigin origin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final notifier = ref.watch(accountNotifierProvider);
    final mode = useState(AuthMode.codeLogin);
    final contactController = useTextEditingController();
    final codeController = useTextEditingController();

    final captchaPassed = useState(false);
    final resendSeconds = useState(0);
    final acceptedTerms = useState(false);
    final errorMessage = useState<String?>(null);
    final infoMessage = useState<String?>(null);
    final codeSent = notifier.hasSignInChallenge;

    useEffect(() {
      captchaPassed.value = false;
      resendSeconds.value = 0;
      acceptedTerms.value = false;
      codeController.clear();
      errorMessage.value = null;
      infoMessage.value = null;
      return null;
    }, [mode.value]);

    useEffect(() {
      if (!codeSent || resendSeconds.value <= 0) {
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
    }, [codeSent, resendSeconds.value > 0]);

    void changeMode(AuthMode nextMode) {
      notifier.clearSignInChallenge();
      mode.value = nextMode;
    }

    Future<void> requestCode() async {
      errorMessage.value = null;
      infoMessage.value = null;
      if (!_isValidContact(contactController.text)) {
        errorMessage.value = '请输入 11 位手机号。';
        return;
      }

      await _showCaptchaSheet(
        context,
        purposeLabel: _captchaPurpose(mode.value),
        onPassed: () async {
          captchaPassed.value = true;
          final account = ref.read(accountNotifierProvider.notifier);
          account.updatePhoneNumber(contactController.text);
          final sent = await account.requestSignInChallenge(
            purpose: _purposeForMode(mode.value),
            forceRefresh: codeSent,
          );
          if (sent) {
            final result = account.signInChallenge!;
            resendSeconds.value = 59;
            infoMessage.value = '验证码已发送至 ${result.maskedPhoneNumber}';
          } else {
            errorMessage.value = account.submissionMessage ?? '发送验证码失败，请稍后重试。';
            captchaPassed.value = false;
          }
        },
      );
    }

    Future<void> submit() async {
      errorMessage.value = null;
      infoMessage.value = null;

      final validationError = _validateSubmission(
        mode: mode.value,
        contact: contactController.text,
        code: codeController.text,
        codeSent: codeSent,
        acceptedTerms: acceptedTerms.value,
      );
      if (validationError != null) {
        errorMessage.value = validationError;
        return;
      }

      try {
        final account = ref.read(accountNotifierProvider.notifier);
        account
          ..updatePhoneNumber(contactController.text)
          ..updateVerificationCode(codeController.text);
        final succeeded = await account.submitChallengeSignIn(
          purpose: _purposeForMode(mode.value),
          acceptedConsent: acceptedTerms.value,
        );
        if (!succeeded) {
          errorMessage.value = account.submissionMessage ?? '验证失败，请稍后重试。';
          return;
        }
        infoMessage.value = _successMessage(mode.value);
        if (context.mounted &&
            (origin == AccountEntryOrigin.onboardingContinuation ||
                origin == AccountEntryOrigin.customSceneContinuation)) {
          Navigator.of(context).pop(AccountEntryResult.signedIn);
        }
      } catch (_) {
        errorMessage.value = '操作失败，请稍后重试。';
      }
    }

    Future<void> confirmLogout() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const Key('auth-logout-confirm-dialog'),
          title: Text(l.accountClearConfirmTitle),
          content: Text(l.accountClearConfirmBody),
          actions: [
            TextButton(
              key: const Key('auth-logout-cancel-button'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l.accountLifecycleCancel),
            ),
            FilledButton(
              key: const Key('auth-logout-confirm-button'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l.accountClearConfirmAction),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) {
        return;
      }
      final loggedOut = await ref
          .read(accountNotifierProvider.notifier)
          .logout();
      if (loggedOut && context.mounted) {
        final router = GoRouter.maybeOf(context);
        if (router != null) {
          router.go(AppRouteNames.shell);
        } else {
          await Navigator.of(context).maybePop();
        }
      }
    }

    if (notifier.isSignedIn) {
      return Scaffold(
        appBar: AppBar(title: Text(l.accountEntryTitle)),
        backgroundColor: colors.bgBase,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppLayoutConstants.spacingXl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 48,
                      color: colors.accent,
                    ),
                    const SizedBox(height: AppLayoutConstants.spacingMd),
                    Text(
                      l.accountPrimaryActionSignedInBody,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (notifier.submissionMessage != null) ...[
                      const SizedBox(height: AppLayoutConstants.spacingMd),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          notifier.submissionMessage!,
                          key: const Key('auth-account-message'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppLayoutConstants.spacingXl),
                    Semantics(
                      button: true,
                      label: '退出登录',
                      enabled: !notifier.isBusy,
                      onTap: notifier.isBusy ? null : confirmLogout,
                      excludeSemantics: true,
                      child: OutlinedButton(
                        key: const Key('auth-logout-button'),
                        onPressed: notifier.isBusy ? null : confirmLogout,
                        child: const Text('退出登录'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.bgBase,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppLayoutConstants.spacingXl,
                vertical: AppLayoutConstants.spacing2xl,
              ),
              child: Semantics(
                container: true,
                label: _screenSemanticsLabel(mode.value, codeSent),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Brand trust header ---
                    _BrandHeader(colors: colors, l: l),
                    const SizedBox(height: AppLayoutConstants.spacing2xl),

                    // --- Mode selector ---
                    Semantics(
                      label: '认证方式选择',
                      child: _AuthModeSelector(
                        mode: mode.value,
                        onChanged: changeMode,
                      ),
                    ),

                    const SizedBox(height: AppLayoutConstants.spacingXl),

                    // --- Contact input ---
                    Semantics(
                      textField: true,
                      label: _contactLabel(mode.value, l),
                      hint: _contactHelp(mode.value, l),
                      child: _WarmTextField(
                        key: const Key('auth-contact-field'),
                        controller: contactController,
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        labelText: _contactLabel(mode.value, l),
                        hintText: _contactHelp(mode.value, l),
                        prefixIcon: Icons.phone_outlined,
                        onChanged: (value) {
                          final challengeBeforeEdit = notifier.signInChallenge;
                          notifier.updatePhoneNumber(value);
                          if (challengeBeforeEdit != null &&
                              notifier.signInChallenge == null) {
                            codeController.clear();
                            resendSeconds.value = 0;
                            captchaPassed.value = false;
                            infoMessage.value = null;
                          }
                          errorMessage.value = null;
                        },
                      ),
                    ),
                    const SizedBox(height: AppLayoutConstants.spacingMd),

                    // --- Verification code ---
                    _VerificationCodeStep(
                      mode: mode.value,
                      codeSent: codeSent,
                      captchaPassed: captchaPassed.value,
                      resendSeconds: resendSeconds.value,
                      codeController: codeController,
                      onSendCode: requestCode,
                    ),

                    // --- Terms/privacy (all authentication modes) ---
                    const SizedBox(height: AppLayoutConstants.spacingMd),
                    _TermsRow(
                      accepted: acceptedTerms.value,
                      onChanged: (v) => acceptedTerms.value = v,
                      onOpenTerms: () =>
                          _showAuthPolicy(context, privacy: false),
                      onOpenPrivacy: () =>
                          _showAuthPolicy(context, privacy: true),
                    ),

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
                    if (errorMessage.value == null &&
                        infoMessage.value == null &&
                        notifier.submissionMessage != null) ...[
                      const SizedBox(height: AppLayoutConstants.spacingMd),
                      _StatusMessage(
                        message: notifier.submissionMessage!,
                        isError: notifier.submissionMessage!.contains('失败'),
                      ),
                    ],

                    // --- Submit button ---
                    const SizedBox(height: AppLayoutConstants.spacingXl),
                    Semantics(
                      button: true,
                      label: _mainButtonSemantics(mode.value, codeSent),
                      child: FilledButton(
                        key: const Key('auth-submit-button'),
                        onPressed: notifier.isBusy ? null : submit,
                        child: notifier.isBusy
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

  static String _contactLabel(AuthMode mode, AppLocalizations l) {
    switch (mode) {
      case AuthMode.codeLogin:
      case AuthMode.register:
        return l.discoverPhoneLabel;
    }
  }

  static String _contactHelp(AuthMode mode, AppLocalizations l) {
    switch (mode) {
      case AuthMode.codeLogin:
        return l.discoverPhoneHint;
      case AuthMode.register:
        return '用于创建 BabyTalk 账号';
    }
  }

  static String _captchaPurpose(AuthMode mode) {
    switch (mode) {
      case AuthMode.codeLogin:
        return '登录验证码';
      case AuthMode.register:
        return '注册验证码';
    }
  }

  static AccountChallengePurpose _purposeForMode(AuthMode mode) {
    return mode == AuthMode.register
        ? AccountChallengePurpose.register
        : AccountChallengePurpose.login;
  }

  static String _screenSemanticsLabel(AuthMode mode, bool codeSent) {
    final step = codeSent ? '验证码已发送，请输入验证码继续' : '请先填写账号信息';
    switch (mode) {
      case AuthMode.codeLogin:
        return '验证码登录页面，$step';
      case AuthMode.register:
        return '注册账号页面，$step';
    }
  }

  static String _getMainButtonText(AuthMode mode, AppLocalizations l) {
    switch (mode) {
      case AuthMode.codeLogin:
        return l.discoverLoginButton;
      case AuthMode.register:
        return '完成注册';
    }
  }

  static String _mainButtonSemantics(AuthMode mode, bool codeSent) {
    switch (mode) {
      case AuthMode.codeLogin:
        return codeSent ? '提交验证码登录' : '登录，需先发送验证码';
      case AuthMode.register:
        return codeSent ? '提交验证码完成注册' : '注册，需先发送验证码';
    }
  }

  static bool _isValidContact(String value) {
    return RegExp(r'^\d{11}$').hasMatch(value.trim());
  }

  static String? _validateSubmission({
    required AuthMode mode,
    required String contact,
    required String code,
    required bool codeSent,
    required bool acceptedTerms,
  }) {
    if (!_isValidContact(contact)) {
      return '请输入 11 位手机号。';
    }

    if (!codeSent) {
      return '请先点击发送验证码并完成人机校验。';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code.trim())) {
      return '请输入 6 位短信验证码。';
    }

    if (!acceptedTerms) {
      return '请先阅读并同意服务条款和隐私协议。';
    }

    return null;
  }

  static String _successMessage(AuthMode mode) {
    switch (mode) {
      case AuthMode.codeLogin:
        return '验证成功，账号已登录。';
      case AuthMode.register:
        return '验证成功，账号已接通。';
    }
  }

  static Future<void> _showCaptchaSheet(
    BuildContext context, {
    required String purposeLabel,
    required Future<void> Function() onPassed,
  }) {
    final l = AppLocalizations.of(context)!;
    var isSubmitting = false;
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => PopScope(
          canPop: !isSubmitting,
          child: SafeArea(
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
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setModalState(() => isSubmitting = true);
                                try {
                                  await onPassed();
                                  if (ctx.mounted) {
                                    Navigator.of(ctx).pop();
                                  }
                                } catch (_) {
                                  if (ctx.mounted) {
                                    setModalState(() => isSubmitting = false);
                                  }
                                  rethrow;
                                }
                              },
                        child: Text(l.discoverCaptchaPass),
                      ),
                    ),
                    TextButton(
                      onPressed: isSubmitting
                          ? null
                          : () => Navigator.of(ctx).pop(),
                      child: Text(l.discoverCaptchaCancel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Brand Header (Warm Paper Kindness design)
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
        children: [
          // Logo / brand icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.accent, colors.accent.withValues(alpha: 0.8)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: colors.accent.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.child_care, size: 40, color: Colors.white),
          ),
          const SizedBox(height: AppLayoutConstants.spacingXl),

          // Title
          Text(
            l.discoverUnifiedLoginTitle,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppLayoutConstants.spacingSm),

          // Subtitle
          Text(
            l.discoverUnifiedLoginSubtitle,
            style: TextStyle(
              fontSize: 15,
              color: colors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppLayoutConstants.spacingMd),

          // Trust badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppLayoutConstants.spacingMd,
              vertical: AppLayoutConstants.spacingXs,
            ),
            decoration: BoxDecoration(
              color: colors.bgAccentSoft,
              borderRadius: BorderRadius.circular(
                AppLayoutConstants.pillRadius,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 14, color: colors.accent),
                const SizedBox(width: 6),
                Text(
                  l.discoverTrustPrivacy,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Warm Text Field (Warm Paper Kindness design)
// ─────────────────────────────────────────────────────────────

class _WarmTextField extends StatelessWidget {
  const _WarmTextField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
  });

  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(AppLayoutConstants.cardRadius),
        boxShadow: colors.warmShadowSm,
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        textInputAction: textInputAction,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        style: TextStyle(fontSize: 16, color: colors.textPrimary),
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          labelStyle: TextStyle(color: colors.textSecondary, fontSize: 14),
          hintStyle: TextStyle(color: colors.textMuted, fontSize: 14),
          prefixIcon: Icon(prefixIcon, size: 20, color: colors.textMuted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppLayoutConstants.cardRadius),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppLayoutConstants.cardRadius),
            borderSide: BorderSide(color: colors.outlineSoft),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppLayoutConstants.cardRadius),
            borderSide: BorderSide(color: colors.accent, width: 2),
          ),
          filled: true,
          fillColor: colors.bgSurface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppLayoutConstants.spacingMd,
            vertical: AppLayoutConstants.spacingMd,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Auth Mode Selector (Segmented)
// ─────────────────────────────────────────────────────────────

class _AuthModeSelector extends StatelessWidget {
  const _AuthModeSelector({required this.mode, required this.onChanged});

  final AuthMode mode;
  final ValueChanged<AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    return Semantics(
      label: '认证方式选择',
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.bgSunken,
          borderRadius: BorderRadius.circular(AppLayoutConstants.cardRadius),
        ),
        child: Row(
          children: [
            _buildTab(
              context,
              label: l.discoverModeCodeLogin,
              isSelected: mode == AuthMode.codeLogin,
              onTap: () => onChanged(AuthMode.codeLogin),
            ),
            _buildTab(
              context,
              label: l.discoverModeRegister,
              isSelected: mode == AuthMode.register,
              onTap: () => onChanged(AuthMode.register),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = context.appColors;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? colors.bgSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppLayoutConstants.smallRadius),
            boxShadow: isSelected ? colors.warmShadowSm : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? colors.accent : colors.textSecondary,
            ),
          ),
        ),
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
          label: captchaPassed
              ? l.discoverVerificationPassed
              : l.discoverVerificationPending,
          child: Text(
            captchaPassed ? l.discoverVerificationPassed : '等待验证码发送。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: AppLayoutConstants.spacingSm),

        // Field label
        Text(
          l.discoverCodeLabel,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
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
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
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
                    color: resendSeconds == 0
                        ? colors.accent
                        : colors.textMuted,
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
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Terms Row
// ─────────────────────────────────────────────────────────────

class _TermsRow extends StatelessWidget {
  const _TermsRow({
    required this.accepted,
    required this.onChanged,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final bool accepted;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

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
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(l.discoverTermsPrefix),
                  TextButton(
                    key: const Key('auth-terms-button'),
                    onPressed: onOpenTerms,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      l.discoverTermsOfService,
                      style: TextStyle(
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const Text('和'),
                  TextButton(
                    key: const Key('auth-privacy-button'),
                    onPressed: onOpenPrivacy,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      l.discoverPrivacyPolicy,
                      style: TextStyle(
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  Text('（版本 $currentAccountConsentVersion）'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showAuthPolicy(
  BuildContext context, {
  required bool privacy,
}) async {
  final l = AppLocalizations.of(context)!;
  final title = privacy ? l.discoverPrivacyPolicy : l.discoverTermsOfService;
  final body = privacy
      ? '隐私协议版本 $currentAccountConsentVersion\n\n'
            '只有在你明确勾选当前版本后，账号同步才会发送最小必要资料。你可以随时在账号页撤回同意或清除本机数据。'
      : '服务条款版本 $currentAccountConsentVersion\n\n'
            '登录前请阅读并确认账号同步、家庭照护和跨设备恢复的使用边界。';
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: Key(privacy ? 'auth-privacy-dialog' : 'auth-terms-dialog'),
      title: Text(title),
      content: SingleChildScrollView(child: Text(body)),
      actions: [
        TextButton(
          key: Key(
            privacy ? 'auth-privacy-dialog-close' : 'auth-terms-dialog-close',
          ),
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l.close),
        ),
      ],
    ),
  );
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
