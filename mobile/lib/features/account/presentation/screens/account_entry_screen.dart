import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/account/presentation/account_view_model.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:provider/provider.dart';

Future<void> openAccountEntryScreen(BuildContext context) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const AccountEntryScreen()));
}

enum AccountSurfacePhase {
  loading,
  localOnly,
  signedOut,
  signedInPendingSync,
  error,
}

class AccountStatusCard extends StatelessWidget {
  const AccountStatusCard({
    super.key,
    required this.scopeKeyPrefix,
    this.onboardingSnapshot,
    this.compact = false,
  });

  final String scopeKeyPrefix;
  final OnboardingSnapshot? onboardingSnapshot;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = context.watch<AccountViewModel>();
    final phase = _resolvePhase(viewModel);
    final title = _titleForPhase(phase, viewModel);
    final body = _bodyForPhase(phase, onboardingSnapshot, viewModel);
    final chips = _buildChips(viewModel);

    return Container(
      key: Key('$scopeKeyPrefix-account-card'),
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 18),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(compact ? 20 : 24),
        border: Border.all(color: AppTheme.outlineSoft),
        boxShadow: AppTheme.warmShadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('账号与同步', style: theme.textTheme.labelMedium),
          const SizedBox(height: 10),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodyMedium),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
          ],
          if (viewModel.submissionMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              viewModel.submissionMessage!,
              key: Key('$scopeKeyPrefix-account-message'),
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                key: Key('$scopeKeyPrefix-account-open-entry'),
                onPressed: phase == AccountSurfacePhase.loading
                    ? null
                    : () => openAccountEntryScreen(context),
                child: Text(
                  phase == AccountSurfacePhase.signedInPendingSync
                      ? '查看账号状态'
                      : '注册 / 登录',
                ),
              ),
              if (phase == AccountSurfacePhase.error)
                OutlinedButton(
                  key: Key('$scopeKeyPrefix-account-retry-load'),
                  onPressed: viewModel.reload,
                  child: const Text('重试读取'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  AccountSurfacePhase _resolvePhase(AccountViewModel viewModel) {
    if (viewModel.isLoading && !viewModel.hasLoaded) {
      return AccountSurfacePhase.loading;
    }
    if (viewModel.loadErrorMessage != null) {
      return AccountSurfacePhase.error;
    }
    if (viewModel.isSignedInPendingSync) {
      return AccountSurfacePhase.signedInPendingSync;
    }
    if (viewModel.isSignedOut || onboardingSnapshot == null) {
      return AccountSurfacePhase.signedOut;
    }
    return AccountSurfacePhase.localOnly;
  }

  String _titleForPhase(AccountSurfacePhase phase, AccountViewModel viewModel) {
    switch (phase) {
      case AccountSurfacePhase.loading:
        return '正在读取账号状态';
      case AccountSurfacePhase.localOnly:
        return '仍是 local-only 档案模式';
      case AccountSurfacePhase.signedOut:
        return '当前未登录账号';
      case AccountSurfacePhase.signedInPendingSync:
        return '已登录 ${viewModel.maskedPhoneNumber}';
      case AccountSurfacePhase.error:
        return '账号状态暂时不可读';
    }
  }

  String _bodyForPhase(
    AccountSurfacePhase phase,
    OnboardingSnapshot? snapshot,
    AccountViewModel viewModel,
  ) {
    switch (phase) {
      case AccountSurfacePhase.loading:
        return 'Shell 可继续进入，稍后会在这里显示 consent、待同步数量和最近状态。';
      case AccountSurfacePhase.localOnly:
        final name = snapshot?.childDisplayName.trim();
        final prefix = name == null || name.isEmpty ? '当前档案' : '$name 的档案';
        return '$prefix 仍只保存在本机；现在可以先继续练习，稍后再补账号与同意。';
      case AccountSurfacePhase.signedOut:
        return '账号入口已挂到真实 shell/home；完成登录前不会把手机号、验证码或 token 混进 onboarding / practice 状态。';
      case AccountSurfacePhase.signedInPendingSync:
        final pending = viewModel.snapshot.pendingSyncCount;
        if (pending > 0) {
          return '已进入待同步占位态，当前还有 $pending 条 append-only 练习事件等待后续切片上传。';
        }
        return '已进入待同步占位态；当前没有待上传事件，下一次练习会继续累积到独立 sync seam。';
      case AccountSurfacePhase.error:
        return viewModel.loadErrorMessage ??
            '账号状态读取失败，但 onboarding / practice 路由不会因此崩溃。';
    }
  }

  List<Widget> _buildChips(AccountViewModel viewModel) {
    final chips = <Widget>[];
    chips.add(
      Chip(
        key: Key('$scopeKeyPrefix-account-pending-chip'),
        label: Text('待同步 ${viewModel.snapshot.pendingSyncCount}'),
      ),
    );
    chips.add(
      Chip(
        key: Key('$scopeKeyPrefix-account-synced-chip'),
        label: Text('已同步 ${viewModel.snapshot.syncedCount}'),
      ),
    );
    chips.add(
      Chip(
        key: Key('$scopeKeyPrefix-account-failed-chip'),
        label: Text('失败 ${viewModel.snapshot.failedCount}'),
      ),
    );
    if (viewModel.snapshot.lastSyncPhase.trim().isNotEmpty) {
      chips.add(
        Chip(
          key: Key('$scopeKeyPrefix-account-phase-chip'),
          label: Text('phase · ${viewModel.snapshot.lastSyncPhase}'),
        ),
      );
    }
    return chips;
  }
}

class AccountEntryScreen extends StatefulWidget {
  const AccountEntryScreen({super.key});

  @override
  State<AccountEntryScreen> createState() => _AccountEntryScreenState();
}

class _AccountEntryScreenState extends State<AccountEntryScreen> {
  late final TextEditingController _phoneController;
  late final TextEditingController _codeController;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _codeController = TextEditingController();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = context.watch<AccountViewModel>();
    final phase = _resolvePhase(viewModel);

    if (_phoneController.text != viewModel.phoneNumber) {
      _phoneController.value = TextEditingValue(
        text: viewModel.phoneNumber,
        selection: TextSelection.collapsed(
          offset: viewModel.phoneNumber.length,
        ),
      );
    }
    if (_codeController.text != viewModel.verificationCode) {
      _codeController.value = TextEditingValue(
        text: viewModel.verificationCode,
        selection: TextSelection.collapsed(
          offset: viewModel.verificationCode.length,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('账号入口')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                Container(
                  key: const Key('account-entry-surface'),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.outlineSoft),
                    boxShadow: AppTheme.warmShadowSm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('S03 账号与同意骨架', style: theme.textTheme.labelMedium),
                      const SizedBox(height: 12),
                      Text(
                        _headlineForPhase(phase, viewModel),
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        viewModel.primaryHint,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        key: Key('account-status-${_phaseKey(phase)}'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _phaseBackground(phase),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _statusText(phase, viewModel),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _phaseForeground(phase),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (viewModel.loadErrorMessage != null) ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          key: const Key('account-load-retry'),
                          onPressed: viewModel.reload,
                          child: const Text('重试读取账号状态'),
                        ),
                      ],
                      const SizedBox(height: 20),
                      TextField(
                        key: const Key('account-phone-field'),
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: '手机号',
                          hintText: '13800138000',
                          errorText: viewModel.phoneError,
                        ),
                        onChanged: viewModel.updatePhoneNumber,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('account-code-field'),
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '验证码',
                          hintText: '6 位数字',
                          errorText: viewModel.verificationCodeError,
                        ),
                        onChanged: viewModel.updateVerificationCode,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '当前表单只保留占位登录骨架：会校验格式、mask 手机号，并把状态落到独立 account store；不会写回 onboarding snapshot，也不会污染 practice view model。',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (viewModel.submissionMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          viewModel.submissionMessage!,
                          key: const Key('account-submit-message'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton(
                            key: const Key('account-submit-button'),
                            onPressed: viewModel.isSubmitting
                                ? null
                                : () async {
                                    final succeeded = await context
                                        .read<AccountViewModel>()
                                        .submitPlaceholderSignIn();
                                    if (!context.mounted || !succeeded) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('账号占位状态已保存，可返回首页查看。'),
                                      ),
                                    );
                                  },
                            child: Text(
                              viewModel.isSubmitting ? '保存中…' : '保存占位登录',
                            ),
                          ),
                          OutlinedButton(
                            key: const Key('account-clear-button'),
                            onPressed: viewModel.isSubmitting
                                ? null
                                : () => context
                                      .read<AccountViewModel>()
                                      .clearPlaceholderSession(),
                            child: const Text('清理为未登录'),
                          ),
                          OutlinedButton(
                            key: const Key('account-local-only-button'),
                            onPressed: viewModel.isSubmitting
                                ? null
                                : () => context
                                      .read<AccountViewModel>()
                                      .clearPlaceholderSession(
                                        revertToLocalOnly: true,
                                      ),
                            child: const Text('回到 local-only'),
                          ),
                          OutlinedButton(
                            key: const Key('account-close-button'),
                            onPressed: () => Navigator.of(context).maybePop(),
                            child: const Text('关闭'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  AccountSurfacePhase _resolvePhase(AccountViewModel viewModel) {
    if (viewModel.isLoading && !viewModel.hasLoaded) {
      return AccountSurfacePhase.loading;
    }
    if (viewModel.loadErrorMessage != null) {
      return AccountSurfacePhase.error;
    }
    if (viewModel.isSignedInPendingSync) {
      return AccountSurfacePhase.signedInPendingSync;
    }
    if (viewModel.isSignedOut) {
      return AccountSurfacePhase.signedOut;
    }
    return AccountSurfacePhase.localOnly;
  }

  String _headlineForPhase(
    AccountSurfacePhase phase,
    AccountViewModel viewModel,
  ) {
    switch (phase) {
      case AccountSurfacePhase.loading:
        return '正在准备账号状态';
      case AccountSurfacePhase.localOnly:
        return '先保留同意前本地档案';
      case AccountSurfacePhase.signedOut:
        return '账号入口已可见，但你还没有登录';
      case AccountSurfacePhase.signedInPendingSync:
        return '已用 ${viewModel.maskedPhoneNumber} 进入待同步占位态';
      case AccountSurfacePhase.error:
        return '账号状态读取失败，但当前 shell 仍可继续使用';
    }
  }

  String _statusText(AccountSurfacePhase phase, AccountViewModel viewModel) {
    switch (phase) {
      case AccountSurfacePhase.loading:
        return 'loading';
      case AccountSurfacePhase.localOnly:
        return 'local-only';
      case AccountSurfacePhase.signedOut:
        return 'signed-out';
      case AccountSurfacePhase.signedInPendingSync:
        return 'signed-in-pending-sync · 待同步 ${viewModel.snapshot.pendingSyncCount}';
      case AccountSurfacePhase.error:
        return 'error';
    }
  }

  String _phaseKey(AccountSurfacePhase phase) {
    switch (phase) {
      case AccountSurfacePhase.loading:
        return 'loading';
      case AccountSurfacePhase.localOnly:
        return 'local-only';
      case AccountSurfacePhase.signedOut:
        return 'signed-out';
      case AccountSurfacePhase.signedInPendingSync:
        return 'signed-in-pending-sync';
      case AccountSurfacePhase.error:
        return 'error';
    }
  }

  Color _phaseBackground(AccountSurfacePhase phase) {
    switch (phase) {
      case AccountSurfacePhase.loading:
        return AppTheme.bgSunken;
      case AccountSurfacePhase.localOnly:
        return AppTheme.infoSoft;
      case AccountSurfacePhase.signedOut:
        return AppTheme.warningSoft;
      case AccountSurfacePhase.signedInPendingSync:
        return AppTheme.englishSoft;
      case AccountSurfacePhase.error:
        return AppTheme.errorSoft;
    }
  }

  Color _phaseForeground(AccountSurfacePhase phase) {
    switch (phase) {
      case AccountSurfacePhase.loading:
        return AppTheme.textSecondary;
      case AccountSurfacePhase.localOnly:
        return AppTheme.info;
      case AccountSurfacePhase.signedOut:
        return AppTheme.warning;
      case AccountSurfacePhase.signedInPendingSync:
        return AppTheme.english;
      case AccountSurfacePhase.error:
        return AppTheme.error;
    }
  }
}
