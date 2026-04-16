import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/domain/models/household_role.dart';
import 'package:mobile/features/household/presentation/household_view_model.dart';

class HouseholdInviteCard extends StatelessWidget {
  const HouseholdInviteCard({
    super.key,
    required this.surfaceKeyPrefix,
    this.viewModel,
    this.inviteSource = 'household_surface',
    this.compact = false,
  });

  final String surfaceKeyPrefix;
  final HouseholdViewModel? viewModel;
  final String inviteSource;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (viewModel == null) {
      return _InviteCardShell(
        surfaceKeyPrefix: surfaceKeyPrefix,
        compact: compact,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'household provider 缺失',
              key: Key('$surfaceKeyPrefix-household-invite-missing'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('邀请入口已显式禁用，不会假装创建成功。', style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    final snapshot = viewModel!.snapshot;
    final isPrimary = snapshot.role == HouseholdRole.primaryCaregiver;
    final visibleMessage = _visibleMessage(viewModel!, snapshot);
    final invite = viewModel!.lastCreatedInvite;
    final showRetry = _shouldShowRetry(viewModel!, snapshot);

    return _InviteCardShell(
      surfaceKeyPrefix: surfaceKeyPrefix,
      compact: compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _headlineFor(snapshot),
            key: Key('$surfaceKeyPrefix-household-invite-headline'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _bodyFor(snapshot),
            key: Key('$surfaceKeyPrefix-household-invite-body'),
            style: theme.textTheme.bodyMedium,
          ),
          if (visibleMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              key: Key('$surfaceKeyPrefix-household-invite-message'),
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _messageBackground(snapshot),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                visibleMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _messageForeground(snapshot),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (invite != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.bgSunken,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('最新邀请链接', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 8),
                  SelectableText(
                    invite.inviteUrl,
                    key: Key('$surfaceKeyPrefix-household-invite-url'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '角色：${invite.role.label} · 到期：${_formatDateTime(invite.expiresAt)}',
                    key: Key('$surfaceKeyPrefix-household-invite-meta'),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                key: Key('$surfaceKeyPrefix-household-create-invite'),
                onPressed: !isPrimary || viewModel!.isBusy
                    ? null
                    : () => viewModel!.createInvite(source: inviteSource),
                child: Text(
                  viewModel!.isBusy &&
                          viewModel!.lastActionKind ==
                              HouseholdActionKind.createInvite
                      ? '创建中…'
                      : (invite == null ? '生成照护邀请' : '重新生成邀请'),
                ),
              ),
              if (showRetry)
                OutlinedButton(
                  key: Key('$surfaceKeyPrefix-household-invite-retry'),
                  onPressed: viewModel!.isBusy
                      ? null
                      : () => viewModel!.retryLastAction(),
                  child: const Text('重试邀请'),
                ),
            ],
          ),
          if (!isPrimary) ...[
            const SizedBox(height: 12),
            Text(
              '当前角色只读：由主照护者发起邀请，你可以继续查看共享档案。',
              key: Key('$surfaceKeyPrefix-household-invite-readonly'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _shouldShowRetry(
    HouseholdViewModel viewModel,
    HouseholdLocalSnapshot snapshot,
  ) {
    final error = snapshot.lastVisibleError?.trim();
    if (error == null || error.isEmpty) {
      return false;
    }
    if (snapshot.lastPhase.startsWith('create_invite_')) {
      return true;
    }
    return viewModel.lastActionKind == HouseholdActionKind.createInvite;
  }

  String _headlineFor(HouseholdLocalSnapshot snapshot) {
    switch (snapshot.role) {
      case HouseholdRole.primaryCaregiver:
        return '邀请次照护者加入';
      case HouseholdRole.caregiver:
        return '邀请由主照护者管理';
      case null:
        return '邀请权限待同步';
    }
  }

  String _bodyFor(HouseholdLocalSnapshot snapshot) {
    switch (snapshot.role) {
      case HouseholdRole.primaryCaregiver:
        return '生成真实 invite link 后，次照护者可通过链接接受邀请并看到共享宝宝档案摘要。';
      case HouseholdRole.caregiver:
        return '你当前是次照护者，只读查看共享照护内容；如需新增成员，请让主照护者操作。';
      case null:
        return '角色或权限尚未准备好；邀请入口保持禁用，并在失败时保留明确文案。';
    }
  }

  String? _visibleMessage(
    HouseholdViewModel viewModel,
    HouseholdLocalSnapshot snapshot,
  ) {
    final snapshotMessage = snapshot.lastVisibleError?.trim();
    if (snapshot.lastPhase.startsWith('create_invite_') &&
        snapshotMessage != null &&
        snapshotMessage.isNotEmpty) {
      return snapshotMessage;
    }
    final message = viewModel.message?.trim();
    if (viewModel.lastActionKind == HouseholdActionKind.createInvite &&
        message != null &&
        message.isNotEmpty) {
      return message;
    }
    return null;
  }

  Color _messageBackground(HouseholdLocalSnapshot snapshot) {
    if (snapshot.lastVisibleError != null &&
        snapshot.lastVisibleError!.trim().isNotEmpty) {
      return snapshot.lastPhase.contains('created')
          ? AppTheme.infoSoft
          : AppTheme.warningSoft;
    }
    return AppTheme.infoSoft;
  }

  Color _messageForeground(HouseholdLocalSnapshot snapshot) {
    if (snapshot.lastVisibleError != null &&
        snapshot.lastVisibleError!.trim().isNotEmpty) {
      return snapshot.lastPhase.contains('created')
          ? AppTheme.info
          : AppTheme.warning;
    }
    return AppTheme.info;
  }
}

class _InviteCardShell extends StatelessWidget {
  const _InviteCardShell({
    required this.surfaceKeyPrefix,
    required this.compact,
    required this.child,
  });

  final String surfaceKeyPrefix;
  final bool compact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('$surfaceKeyPrefix-household-invite-card'),
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
          Text('照护邀请', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute';
}
