import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum AuthMode { codeLogin, passwordLogin, register, resetPassword }

class AuthScreen extends HookConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final contactLabel = _contactLabel(mode.value);
    final contactHelp = _contactHelp(mode.value);

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
          infoMessage.value = '${_codeSentMessage(mode.value)}，请查看短信。';
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
              padding: const EdgeInsets.all(24.0),
              child: Semantics(
                container: true,
                label: _screenSemanticsLabel(mode.value, codeSent.value),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        '陪伴宝宝说英语',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _subtitleForMode(mode.value),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),

                    if (mode.value != AuthMode.resetPassword)
                      Semantics(
                        label: '认证方式选择，可选择验证码登录、密码登录或注册',
                        child: SegmentedButton<AuthMode>(
                          segments: const [
                            ButtonSegment(
                              value: AuthMode.codeLogin,
                              label: Text('验证码登录'),
                            ),
                            ButtonSegment(
                              value: AuthMode.passwordLogin,
                              label: Text('密码登录'),
                            ),
                            ButtonSegment(
                              value: AuthMode.register,
                              label: Text('注册'),
                            ),
                          ],
                          selected: {mode.value},
                          onSelectionChanged: (selection) {
                            mode.value = selection.first;
                          },
                        ),
                      )
                    else
                      _ModeHeader(
                        title: '重置密码',
                        description: '通过验证码确认身份后设置新密码。',
                      ),

                    const SizedBox(height: 24),
                    Semantics(
                      textField: true,
                      label: contactLabel,
                      hint: contactHelp,
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
                          labelText: contactLabel,
                          helperText: contactHelp,
                          prefixText: _usesPhoneOnly(mode.value) ? '+86 ' : null,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          errorMessage.value = null;
                          infoMessage.value = null;
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (isCodeFlow) ...[
                      _VerificationCodeStep(
                        mode: mode.value,
                        codeSent: codeSent.value,
                        captchaPassed: captchaPassed.value,
                        resendSeconds: resendSeconds.value,
                        codeController: codeController,
                        onSendCode: requestCode,
                      ),
                      if (codeSent.value &&
                          (mode.value == AuthMode.register ||
                              mode.value == AuthMode.resetPassword)) ...[
                        const SizedBox(height: 16),
                        _PasswordField(
                          controller: passwordController,
                          labelText: mode.value == AuthMode.register
                              ? '设置密码'
                              : '新密码',
                          semanticsLabel: mode.value == AuthMode.register
                              ? '设置注册密码'
                              : '输入新密码',
                          visible: passwordVisible.value,
                          onToggleVisibility: () {
                            passwordVisible.value = !passwordVisible.value;
                          },
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 16),
                        _PasswordField(
                          controller: confirmPasswordController,
                          labelText: '确认密码',
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
                      _PasswordField(
                        controller: passwordController,
                        labelText: '密码',
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
                            onPressed: () => mode.value = AuthMode.resetPassword,
                            child: const Text('忘记密码？'),
                          ),
                        ),
                      ),
                    ],

                    if (mode.value == AuthMode.register) ...[
                      const SizedBox(height: 16),
                      _TermsRow(
                        accepted: acceptedTerms.value,
                        onChanged: (value) => acceptedTerms.value = value,
                      ),
                    ],

                    if (errorMessage.value != null) ...[
                      const SizedBox(height: 16),
                      _StatusMessage(
                        message: errorMessage.value!,
                        isError: true,
                      ),
                    ],
                    if (infoMessage.value != null) ...[
                      const SizedBox(height: 16),
                      _StatusMessage(
                        message: infoMessage.value!,
                        isError: false,
                      ),
                    ],

                    const SizedBox(height: 24),
                    Semantics(
                      button: true,
                      label: _mainButtonSemantics(mode.value, codeSent.value),
                      child: FilledButton(
                        onPressed: submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                        child: Text(_getMainButtonText(mode.value)),
                      ),
                    ),
                    const SizedBox(height: 16),
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
    return [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)];
  }

  static String _contactLabel(AuthMode mode) {
    switch (mode) {
      case AuthMode.codeLogin:
      case AuthMode.register:
        return '手机号';
      case AuthMode.passwordLogin:
      case AuthMode.resetPassword:
        return '手机号或邮箱';
    }
  }

  static String _contactHelp(AuthMode mode) {
    switch (mode) {
      case AuthMode.codeLogin:
        return '用于接收登录验证码';
      case AuthMode.passwordLogin:
        return '输入注册手机号或邮箱';
      case AuthMode.register:
        return '用于创建 BabyTalk 账号';
      case AuthMode.resetPassword:
        return '用于接收重置验证码';
    }
  }

  static String _subtitleForMode(AuthMode mode) {
    switch (mode) {
      case AuthMode.codeLogin:
        return '输入手机号后发送验证码，完成安全验证再登录。';
      case AuthMode.passwordLogin:
        return '使用已注册账号和密码登录。';
      case AuthMode.register:
        return '创建新账号前需要验证手机号。';
      case AuthMode.resetPassword:
        return '忘记密码时，用验证码确认身份并设置新密码。';
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

  static String _codeSentMessage(AuthMode mode) {
    switch (mode) {
      case AuthMode.codeLogin:
        return '登录验证码已发送';
      case AuthMode.register:
        return '注册验证码已发送';
      case AuthMode.resetPassword:
        return '重置验证码已发送';
      case AuthMode.passwordLogin:
        return '验证码已发送';
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

  static String _getMainButtonText(AuthMode mode) {
    switch (mode) {
      case AuthMode.codeLogin:
      case AuthMode.passwordLogin:
        return '登录';
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
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
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
                    '安全验证',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '请先完成校验，验证通过后再发送$purposeLabel。',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                Semantics(
                  label: 'CAPTCHA 校验区域，当前为模拟拼图验证',
                  hint: '点击模拟验证通过按钮完成校验',
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '请完成拼图 / CAPTCHA',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Semantics(
                  button: true,
                  label: '模拟人机校验通过并发送验证码',
                  child: FilledButton(
                    onPressed: () {
                      onPassed();
                      Navigator.of(ctx).pop();
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: const Text('模拟验证通过'),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('取消'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
    if (!codeSent) {
      return Semantics(
        button: true,
        label: '${_sendButtonText(mode)}，点击后打开人机校验',
        child: OutlinedButton(
          onPressed: onSendCode,
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          child: Text(_sendButtonText(mode)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          label: captchaPassed ? '人机校验已通过，验证码已发送' : '验证码待发送',
          child: Text(
            captchaPassed ? '验证码已发送，请输入短信中的 6 位数字。' : '等待验证码发送。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          textField: true,
          label: '短信验证码输入框，6 位数字，支持粘贴和自动填充',
          child: TextField(
            key: const Key('auth-code-field'),
            controller: codeController,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            textInputAction: TextInputAction.next,
            inputFormatters: const [],
            maxLength: 6,
            decoration: InputDecoration(
              labelText: '验证码',
              helperText: '可直接粘贴短信验证码',
              counterText: '',
              border: const OutlineInputBorder(),
              suffixIcon: TextButton(
                onPressed: resendSeconds == 0 ? onSendCode : null,
                child: Text(resendSeconds == 0 ? '重新发送' : '${resendSeconds}s'),
              ),
            ),
            style: const TextStyle(letterSpacing: 8),
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          label: resendSeconds == 0
              ? '可以重新发送验证码'
              : '重新发送验证码倒计时 $resendSeconds 秒',
          child: Text(
            resendSeconds == 0 ? '没有收到？可以重新发送。' : '$resendSeconds 秒后可重新发送。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  static String _sendButtonText(AuthMode mode) {
    switch (mode) {
      case AuthMode.codeLogin:
        return '发送验证码';
      case AuthMode.register:
        return '发送注册验证码';
      case AuthMode.resetPassword:
        return '发送重置验证码';
      case AuthMode.passwordLogin:
        return '发送验证码';
    }
  }
}

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

class _TermsRow extends StatelessWidget {
  const _TermsRow({required this.accepted, required this.onChanged});

  final bool accepted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: accepted,
      button: true,
      label: '同意服务条款和隐私协议',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onChanged(!accepted),
        child: Row(
          children: [
            Checkbox(value: accepted, onChanged: (value) => onChanged(value ?? false)),
            const Expanded(
              child: Text('我已阅读并同意《服务条款》和《隐私协议》'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = isError ? colorScheme.error : colorScheme.primary;
    final background = foreground.withValues(alpha: 0.08);

    return Semantics(
      liveRegion: true,
      label: isError ? '错误提示：$message' : '状态提示：$message',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: foreground.withValues(alpha: 0.24)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: foreground),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: TextStyle(color: foreground))),
          ],
        ),
      ),
    );
  }
}

class _FooterLinks extends StatelessWidget {
  const _FooterLinks({required this.mode, required this.codeSent});

  final ValueNotifier<AuthMode> mode;
  final ValueNotifier<bool> codeSent;

  @override
  Widget build(BuildContext context) {
    if (mode.value == AuthMode.resetPassword) {
      return Center(
        child: TextButton(
          onPressed: () => mode.value = AuthMode.passwordLogin,
          child: const Text('返回密码登录'),
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        if (mode.value != AuthMode.codeLogin)
          TextButton(
            onPressed: () => mode.value = AuthMode.codeLogin,
            child: const Text('验证码登录'),
          ),
        if (mode.value != AuthMode.passwordLogin)
          TextButton(
            onPressed: () => mode.value = AuthMode.passwordLogin,
            child: const Text('密码登录'),
          ),
        if (mode.value != AuthMode.register)
          TextButton(
            onPressed: () => mode.value = AuthMode.register,
            child: const Text('注册新账号'),
          ),
      ],
    );
  }
}
