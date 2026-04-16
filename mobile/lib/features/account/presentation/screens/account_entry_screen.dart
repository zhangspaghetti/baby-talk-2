import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
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
  signedInSynced,
  signedInFailed,
  revoked,
  deleted,
  versionBlocked,
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
          if (viewModel.snapshot.lastVisibleError != null &&
              viewModel.snapshot.lastVisibleError!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              key: Key('$scopeKeyPrefix-account-banner'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _bannerBackgroundForPhase(phase),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                viewModel.snapshot.lastVisibleError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _bannerForegroundForPhase(phase),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
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
          if (phase == AccountSurfacePhase.versionBlocked &&
              viewModel.upgradeActionHint != null) ...[
            const SizedBox(height: 12),
            Text(
              viewModel.upgradeActionHint!,
              key: Key('$scopeKeyPrefix-account-upgrade-hint'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                key: Key('$scopeKeyPrefix-account-open-entry'),
                onPressed: phase == AccountSurfacePhase.loading || viewModel.isBusy
                    ? null
                    : () => openAccountEntryScreen(context),
                child: Text(
                  viewModel.isSignedIn ? '查看账号状态' : '注册 / 登录',
                ),
              ),
              if (phase == AccountSurfacePhase.versionBlocked)
                FilledButton(
                  key: Key('$scopeKeyPrefix-account-upgrade-button'),
                  onPressed: viewModel.canOpenUpgradePage
                      ? viewModel.openUpgradePage
                      : null,
                  child: Text(viewModel.upgradeActionLabel),
                ),
              if (phase == AccountSurfacePhase.error)
                OutlinedButton(
                  key: Key('$scopeKeyPrefix-account-retry-load'),
                  onPressed: viewModel.reload,
                  child: const Text('重试读取'),
                ),
              if (viewModel.isSignedIn ||
                  phase == AccountSurfacePhase.versionBlocked ||
                  phase == AccountSurfacePhase.signedInFailed ||
                  phase == AccountSurfacePhase.revoked)
                OutlinedButton(
                  key: Key('$scopeKeyPrefix-account-retry-sync'),
                  onPressed: viewModel.isBusy
                      ? null
                      : () => viewModel.refreshRuntimeState(
                            trigger: AccountRuntimeTrigger.manualRetry,
                          ),
                  child: const Text('重试同步'),
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
    if (viewModel.isDeleted) {
      return AccountSurfacePhase.deleted;
    }
    if (viewModel.isRevoked) {
      return AccountSurfacePhase.revoked;
    }
    if (viewModel.isVersionBlocked) {
      return AccountSurfacePhase.versionBlocked;
    }
    if (viewModel.isSignedIn && viewModel.hasSyncFailure) {
      return AccountSurfacePhase.signedInFailed;
    }
    if (viewModel.isSignedIn && viewModel.hasPendingSync) {
      return AccountSurfacePhase.signedInPendingSync;
    }
    if (viewModel.isSignedIn) {
      return AccountSurfacePhase.signedInSynced;
    }
    if (viewModel.isLocalOnly && onboardingSnapshot != null) {
      return AccountSurfacePhase.localOnly;
    }
    return AccountSurfacePhase.signedOut;
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
      case AccountSurfacePhase.signedInSynced:
        return '已登录 ${viewModel.maskedPhoneNumber}';
      case AccountSurfacePhase.signedInFailed:
        return '同步仍需重试';
      case AccountSurfacePhase.revoked:
        return '同意已撤回';
      case AccountSurfacePhase.deleted:
        return '账号已删除';
      case AccountSurfacePhase.versionBlocked:
        return '当前版本需要升级';
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
        return '账号入口已挂到真实 shell/home；登录前不会把手机号、验证码或 session 混进 onboarding / practice 状态。';
      case AccountSurfacePhase.signedInPendingSync:
        return '仍有 ${viewModel.snapshot.pendingSyncCount} 条 append-only 练习事件待同步，前台会在启动、回首页、回前台和手动重试时继续尝试。';
      case AccountSurfacePhase.signedInSynced:
        return '最近状态已对齐；重登时会先 bootstrap，再恢复 recent result 与继续练习位置。';
      case AccountSurfacePhase.signedInFailed:
        return '最近一次同步没有完成，但本地 pending 事件仍保留，可继续练习并稍后重试。';
      case AccountSurfacePhase.revoked:
        return '撤回后不会再上传或恢复远端数据；重新登录并再次同意后才会继续同步。';
      case AccountSurfacePhase.deleted:
        return '删除后远端账号不可恢复；本机仍可继续 guest/local-only 使用。';
      case AccountSurfacePhase.versionBlocked:
        return viewModel.canOpenUpgradePage
            ? '服务端已拒绝当前版本；请先打开升级页面安装新版本，再返回重试同步。'
            : '服务端已拒绝当前版本；当前会保留升级受阻提示，但升级入口暂不可用。';
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
    final lastSyncAt = viewModel.snapshot.lastSyncAt;
    if (lastSyncAt != null) {
      final local = lastSyncAt.toLocal();
      final hour = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      chips.add(
        Chip(
          key: Key('$scopeKeyPrefix-account-time-chip'),
          label: Text('最近 $hour:$minute'),
        ),
      );
    }
    return chips;
  }

  Color _bannerBackgroundForPhase(AccountSurfacePhase phase) {
    switch (phase) {
      case AccountSurfacePhase.versionBlocked:
        return AppTheme.warningSoft;
      case AccountSurfacePhase.deleted:
      case AccountSurfacePhase.error:
        return AppTheme.errorSoft;
      case AccountSurfacePhase.revoked:
      case AccountSurfacePhase.signedInFailed:
        return AppTheme.warningSoft;
      default:
        return AppTheme.infoSoft;
    }
  }

  Color _bannerForegroundForPhase(AccountSurfacePhase phase) {
    switch (phase) {
      case AccountSurfacePhase.versionBlocked:
      case AccountSurfacePhase.revoked:
      case AccountSurfacePhase.signedInFailed:
        return AppTheme.warning;
      case AccountSurfacePhase.deleted:
      case AccountSurfacePhase.error:
        return AppTheme.error;
      default:
        return AppTheme.info;
    }
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
                      Text('S03 账号 / 同意 / 同步闭环', style: theme.textTheme.labelMedium),
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
                          hintText: '开发 stub 默认 246810',
                          errorText: viewModel.verificationCodeError,
                        ),
                        onChanged: viewModel.updateVerificationCode,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '真实登录会调用 challenge → verify → consent accept → bootstrap → batch sync；错误会留在独立 account/sync seam 中，不回写 onboarding snapshot，也不让 PracticeSessionViewModel 直接发请求。',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (viewModel.snapshot.lastVisibleError != null &&
                          viewModel.snapshot.lastVisibleError!.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          '最近错误：${viewModel.snapshot.lastVisibleError!}',
                          key: const Key('account-last-error'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _phaseForeground(phase),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (viewModel.submissionMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          viewModel.submissionMessage!,
                          key: const Key('account-submit-message'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      if (phase == AccountSurfacePhase.versionBlocked &&
                          viewModel.upgradeActionHint != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          viewModel.upgradeActionHint!,
                          key: const Key('account-upgrade-hint'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton(
                            key: const Key('account-submit-button'),
                            onPressed: viewModel.isBusy
                                ? null
                                : () async {
                                    final succeeded = await context
                                        .read<AccountViewModel>()
                                        .submitSignIn();
                                    if (!context.mounted || !succeeded) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('登录已完成，可返回首页查看最近恢复结果。'),
                                      ),
                                    );
                                  },
                            child: Text(
                              viewModel.isBusy ? '处理中…' : '登录并同意',
                            ),
                          ),
                          if (phase == AccountSurfacePhase.versionBlocked)
                            FilledButton(
                              key: const Key('account-upgrade-button'),
                              onPressed: viewModel.canOpenUpgradePage
                                  ? () => context
                                        .read<AccountViewModel>()
                                        .openUpgradePage()
                                  : null,
                              child: Text(viewModel.upgradeActionLabel),
                            ),
                          OutlinedButton(
                            key: const Key('account-sync-retry-button'),
                            onPressed: viewModel.isBusy
                                ? null
                                : () => context
                                      .read<AccountViewModel>()
                                      .refreshRuntimeState(
                                        trigger: AccountRuntimeTrigger.manualRetry,
                                      ),
                            child: const Text('重试同步'),
                          ),
                          OutlinedButton(
                            key: const Key('account-revoke-button'),
                            onPressed: viewModel.isBusy || !viewModel.isSignedIn
                                ? null
                                : () => context.read<AccountViewModel>().revokeConsent(),
                            child: const Text('撤回同意'),
                          ),
                          OutlinedButton(
                            key: const Key('account-delete-button'),
                            onPressed: viewModel.isBusy || !viewModel.isSignedIn
                                ? null
                                : () => context.read<AccountViewModel>().deleteAccount(),
                            child: const Text('删除账号'),
                          ),
                          OutlinedButton(
                            key: const Key('account-clear-button'),
                            onPressed: viewModel.isBusy
                                ? null
                                : () => context.read<AccountViewModel>().clearSession(),
                            child: const Text('退出为未登录'),
                          ),
                          OutlinedButton(
                            key: const Key('account-local-only-button'),
                            onPressed: viewModel.isBusy
                                ? null
                                : () => context
                                      .read<AccountViewModel>()
                                      .clearSession(revertToLocalOnly: true),
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
    if (viewModel.isDeleted) {
      return AccountSurfacePhase.deleted;
    }
    if (viewModel.isRevoked) {
      return AccountSurfacePhase.revoked;
    }
    if (viewModel.isVersionBlocked) {
      return AccountSurfacePhase.versionBlocked;
    }
    if (viewModel.isSignedIn && viewModel.hasSyncFailure) {
      return AccountSurfacePhase.signedInFailed;
    }
    if (viewModel.isSignedIn && viewModel.hasPendingSync) {
      return AccountSurfacePhase.signedInPendingSync;
    }
    if (viewModel.isSignedIn) {
      return AccountSurfacePhase.signedInSynced;
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
        return '已用 ${viewModel.maskedPhoneNumber} 登录，仍有待同步事件';
      case AccountSurfacePhase.signedInSynced:
        return '已用 ${viewModel.maskedPhoneNumber} 登录并完成最近一次对齐';
      case AccountSurfacePhase.signedInFailed:
        return '登录已完成，但最近同步仍需重试';
      case AccountSurfacePhase.revoked:
        return '同意已撤回';
      case AccountSurfacePhase.deleted:
        return '账号已删除';
      case AccountSurfacePhase.versionBlocked:
        return '当前版本需要升级';
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
      case AccountSurfacePhase.signedInSynced:
        return 'signed-in-synced';
      case AccountSurfacePhase.signedInFailed:
        return 'signed-in-retry-needed';
      case AccountSurfacePhase.revoked:
        return 'consent-revoked';
      case AccountSurfacePhase.deleted:
        return 'account-deleted';
      case AccountSurfacePhase.versionBlocked:
        return 'upgrade-required-426';
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
      case AccountSurfacePhase.signedInSynced:
        return 'signed-in-synced';
      case AccountSurfacePhase.signedInFailed:
        return 'signed-in-retry-needed';
      case AccountSurfacePhase.revoked:
        return 'consent-revoked';
      case AccountSurfacePhase.deleted:
        return 'account-deleted';
      case AccountSurfacePhase.versionBlocked:
        return 'upgrade-required-426';
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
      case AccountSurfacePhase.signedInSynced:
        return AppTheme.englishSoft;
      case AccountSurfacePhase.signedInFailed:
      case AccountSurfacePhase.revoked:
      case AccountSurfacePhase.versionBlocked:
        return AppTheme.warningSoft;
      case AccountSurfacePhase.deleted:
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
      case AccountSurfacePhase.signedInSynced:
        return AppTheme.english;
      case AccountSurfacePhase.signedInFailed:
      case AccountSurfacePhase.revoked:
      case AccountSurfacePhase.versionBlocked:
        return AppTheme.warning;
      case AccountSurfacePhase.deleted:
      case AccountSurfacePhase.error:
        return AppTheme.error;
    }
  }
}
