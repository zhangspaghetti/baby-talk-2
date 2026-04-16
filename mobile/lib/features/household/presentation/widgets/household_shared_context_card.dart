import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/domain/models/household_role.dart';
import 'package:mobile/features/household/domain/models/household_shared_context.dart';
import 'package:mobile/features/household/presentation/household_view_model.dart';

class HouseholdSharedContextCard extends StatelessWidget {
  const HouseholdSharedContextCard({
    super.key,
    required this.surfaceKeyPrefix,
    this.viewModel,
    this.title = '共享照护',
    this.compact = false,
    this.retryReason,
  });

  final String surfaceKeyPrefix;
  final HouseholdViewModel? viewModel;
  final String title;
  final bool compact;
  final String? retryReason;

  @override
  Widget build(BuildContext context) {
    if (viewModel == null) {
      return _HouseholdCardShell(
        surfaceKeyPrefix: surfaceKeyPrefix,
        title: title,
        compact: compact,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRoleChip(
              context,
              key: Key('$surfaceKeyPrefix-household-role-chip'),
              label: '共享未接通',
              backgroundColor: AppTheme.warningSoft,
              foregroundColor: AppTheme.warning,
            ),
            const SizedBox(height: 12),
            Text(
              'household provider 缺失',
              key: Key('$surfaceKeyPrefix-household-provider-missing'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '共享档案、角色和最近 continuity 已退回安全空态，不会回退到错误默认 activity。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    final snapshot = viewModel!.snapshot;
    final sharedContext = snapshot.sharedContext;
    final role = snapshot.role;
    final roleStyle = _roleStyle(role);
    final theme = Theme.of(context);
    final visibleMessage = _visibleMessage(viewModel!, snapshot);
    final hasVisibleMessage =
        visibleMessage != null && visibleMessage.isNotEmpty;

    return _HouseholdCardShell(
      surfaceKeyPrefix: surfaceKeyPrefix,
      title: title,
      compact: compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildRoleChip(
                context,
                key: Key('$surfaceKeyPrefix-household-role-chip'),
                label: roleStyle.label,
                backgroundColor: roleStyle.backgroundColor,
                foregroundColor: roleStyle.foregroundColor,
              ),
              _buildRoleChip(
                context,
                key: Key('$surfaceKeyPrefix-household-phase-chip'),
                label: 'phase · ${snapshot.lastPhase}',
                backgroundColor: AppTheme.bgSunken,
                foregroundColor: AppTheme.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _headlineFor(snapshot),
            key: Key('$surfaceKeyPrefix-household-headline'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _roleNoteFor(snapshot),
            key: Key('$surfaceKeyPrefix-household-role-note'),
            style: theme.textTheme.bodyMedium,
          ),
          if (snapshot.lastAcceptedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              '最近接受：${_formatDateTime(snapshot.lastAcceptedAt!)}',
              key: Key('$surfaceKeyPrefix-household-accepted-at'),
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (hasVisibleMessage) ...[
            const SizedBox(height: 12),
            _HouseholdBanner(
              key: Key('$surfaceKeyPrefix-household-error-banner'),
              message: visibleMessage,
              backgroundColor: _bannerBackgroundFor(snapshot),
              foregroundColor: _bannerForegroundFor(snapshot),
            ),
          ],
          if (sharedContext != null) ...[
            const SizedBox(height: 14),
            _HouseholdSummaryBlock(
              surfaceKeyPrefix: surfaceKeyPrefix,
              sharedContext: sharedContext,
            ),
          ] else ...[
            const SizedBox(height: 14),
            Container(
              key: Key('$surfaceKeyPrefix-household-empty-state'),
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.bgSunken,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _emptyStateMessage(snapshot),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
          if (_shouldShowRetry(viewModel!, snapshot)) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  key: Key('$surfaceKeyPrefix-household-retry-button'),
                  onPressed: viewModel!.isBusy
                      ? null
                      : () => _handleRetry(viewModel!, surfaceKeyPrefix),
                  child: Text(
                    viewModel!.isBusy
                        ? '处理中…'
                        : _retryLabelFor(viewModel!, snapshot),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleRetry(
    HouseholdViewModel viewModel,
    String surfaceKeyPrefix,
  ) async {
    final shouldRetryLastAction =
        viewModel.lastActionKind == HouseholdActionKind.acceptInvite ||
        viewModel.lastActionKind == HouseholdActionKind.refreshSharedContext;
    if (shouldRetryLastAction) {
      await viewModel.retryLastAction();
      return;
    }
    await viewModel.refreshSharedContext(
      reason: retryReason ?? '${surfaceKeyPrefix}_manual_refresh',
    );
  }

  bool _shouldShowRetry(
    HouseholdViewModel viewModel,
    HouseholdLocalSnapshot snapshot,
  ) {
    if (viewModel.isBusy) {
      return true;
    }
    if (snapshot.lastVisibleError != null &&
        snapshot.lastVisibleError!.trim().isNotEmpty) {
      return true;
    }
    if (!snapshot.hasSharedContext &&
        snapshot.role != HouseholdRole.primaryCaregiver) {
      return true;
    }
    return false;
  }

  String _retryLabelFor(
    HouseholdViewModel viewModel,
    HouseholdLocalSnapshot snapshot,
  ) {
    if (viewModel.isBusy) {
      return '处理中…';
    }
    switch (viewModel.lastActionKind) {
      case HouseholdActionKind.acceptInvite:
        return '重试接受邀请';
      case HouseholdActionKind.refreshSharedContext:
        return '重试共享同步';
      case HouseholdActionKind.createInvite:
      case HouseholdActionKind.none:
        if (snapshot.lastVisibleError != null) {
          return '重试共享同步';
        }
        return '刷新共享上下文';
    }
  }

  String _headlineFor(HouseholdLocalSnapshot snapshot) {
    if (snapshot.sharedContext != null) {
      return '共享宝宝档案已接通';
    }
    if (_isUnavailablePhase(snapshot.lastPhase)) {
      return '共享上下文暂不可用';
    }
    if (snapshot.role == HouseholdRole.primaryCaregiver) {
      return '等待次照护者加入';
    }
    if (snapshot.role == HouseholdRole.caregiver) {
      return '共享上下文正在准备';
    }
    return '共享照护尚未接通';
  }

  String _roleNoteFor(HouseholdLocalSnapshot snapshot) {
    switch (snapshot.role) {
      case HouseholdRole.primaryCaregiver:
        return '你当前是主照护者，可以管理邀请，并查看共享宝宝档案与回流状态。';
      case HouseholdRole.caregiver:
        return snapshot.sharedContext == null
            ? '你当前是次照护者；邀请接受成功后，这里会显示共享宝宝档案、最近 continuity 与花园摘要。'
            : '你当前是次照护者；这里展示的是共享宝宝档案与最近 continuity / 花园上下文。';
      case null:
        return '角色尚未同步；共享档案会继续停留在安全 fallback，不会把错误参数写进练习入口。';
    }
  }

  String _emptyStateMessage(HouseholdLocalSnapshot snapshot) {
    if (snapshot.lastVisibleError != null &&
        snapshot.lastVisibleError!.trim().isNotEmpty) {
      if (_isUnavailablePhase(snapshot.lastPhase)) {
        return '共享上下文暂不可用；当前不会把缺字段或坏 route args 写进 Practice/Garden。';
      }
      return snapshot.lastVisibleError!;
    }
    if (snapshot.role == HouseholdRole.primaryCaregiver) {
      return '生成邀请并等待次照护者接受后，这里会出现共享宝宝档案摘要。';
    }
    if (snapshot.role == HouseholdRole.caregiver) {
      return '接受邀请后，如果共享上下文尚未刷新完成，这里会保留只读等待态。';
    }
    return 'household 尚未初始化；当前保持显式 disabled 状态。';
  }

  String? _visibleMessage(
    HouseholdViewModel viewModel,
    HouseholdLocalSnapshot snapshot,
  ) {
    final snapshotMessage = snapshot.lastVisibleError?.trim();
    final viewModelMessage = viewModel.message?.trim();
    if (snapshotMessage != null && snapshotMessage.isNotEmpty) {
      return snapshotMessage;
    }
    if (viewModelMessage != null && viewModelMessage.isNotEmpty) {
      switch (viewModel.lastActionKind) {
        case HouseholdActionKind.acceptInvite:
        case HouseholdActionKind.refreshSharedContext:
          return viewModelMessage;
        case HouseholdActionKind.createInvite:
        case HouseholdActionKind.none:
          return null;
      }
    }
    return null;
  }

  bool _isUnavailablePhase(String lastPhase) {
    return lastPhase.contains('malformed') ||
        lastPhase.contains('timeout') ||
        lastPhase.contains('offline') ||
        lastPhase.contains('unavailable') ||
        lastPhase.contains('shared_context_unavailable') ||
        lastPhase.contains('role_not_allowed') ||
        lastPhase.contains('invalid_session') ||
        lastPhase.contains('consent_required') ||
        lastPhase.contains('already_used') ||
        lastPhase.contains('expired') ||
        lastPhase.contains('revoked');
  }

  Color _bannerBackgroundFor(HouseholdLocalSnapshot snapshot) {
    if (_isUnavailablePhase(snapshot.lastPhase)) {
      return snapshot.lastPhase.contains('malformed')
          ? AppTheme.errorSoft
          : AppTheme.warningSoft;
    }
    return AppTheme.infoSoft;
  }

  Color _bannerForegroundFor(HouseholdLocalSnapshot snapshot) {
    if (_isUnavailablePhase(snapshot.lastPhase)) {
      return snapshot.lastPhase.contains('malformed')
          ? AppTheme.error
          : AppTheme.warning;
    }
    return AppTheme.info;
  }
}

class _HouseholdSummaryBlock extends StatelessWidget {
  const _HouseholdSummaryBlock({
    required this.surfaceKeyPrefix,
    required this.sharedContext,
  });

  final String surfaceKeyPrefix;
  final HouseholdSharedContext sharedContext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryRow(
          label: '共享宝宝档案',
          text: sharedContext.babyProfileSummary,
          valueKey: Key('$surfaceKeyPrefix-household-profile-summary'),
        ),
        const SizedBox(height: 12),
        _SummaryRow(
          label: '最近 continuity',
          text: sharedContext.continuitySummary,
          valueKey: Key('$surfaceKeyPrefix-household-continuity-summary'),
        ),
        const SizedBox(height: 12),
        _SummaryRow(
          label: '花园上下文',
          text: sharedContext.gardenSummary,
          valueKey: Key('$surfaceKeyPrefix-household-garden-summary'),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.text,
    required this.valueKey,
  });

  final String label;
  final String text;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgSunken,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          Text(
            text,
            key: valueKey,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HouseholdCardShell extends StatelessWidget {
  const _HouseholdCardShell({
    required this.surfaceKeyPrefix,
    required this.title,
    required this.compact,
    required this.child,
  });

  final String surfaceKeyPrefix;
  final String title;
  final bool compact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('$surfaceKeyPrefix-household-shared-context-card'),
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
          Text(title, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _HouseholdBanner extends StatelessWidget {
  const _HouseholdBanner({
    super.key,
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String message;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RoleStyle {
  const _RoleStyle({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
}

_RoleStyle _roleStyle(HouseholdRole? role) {
  switch (role) {
    case HouseholdRole.primaryCaregiver:
      return const _RoleStyle(
        label: '主照护者',
        backgroundColor: AppTheme.bgAccentSoft,
        foregroundColor: AppTheme.accentDark,
      );
    case HouseholdRole.caregiver:
      return const _RoleStyle(
        label: '次照护者',
        backgroundColor: AppTheme.englishSoft,
        foregroundColor: AppTheme.english,
      );
    case null:
      return const _RoleStyle(
        label: '角色待同步',
        backgroundColor: AppTheme.bgSunken,
        foregroundColor: AppTheme.textSecondary,
      );
  }
}

Widget _buildRoleChip(
  BuildContext context, {
  required Key key,
  required String label,
  required Color backgroundColor,
  required Color foregroundColor,
}) {
  return Container(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: foregroundColor),
    ),
  );
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute';
}
