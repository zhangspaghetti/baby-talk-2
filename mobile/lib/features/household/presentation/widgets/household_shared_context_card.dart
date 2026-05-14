import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/domain/models/household_role.dart';
import 'package:mobile/features/household/domain/models/household_shared_context.dart';
import 'package:mobile/features/household/presentation/household_notifier.dart'
    show HouseholdActionKind;
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/l10n/app_localizations.dart';

PracticeRouteArgs? resolveHouseholdSharedNextStepArgs(
  HouseholdSharedContext? sharedContext,
) {
  final nextStep = sharedContext?.nextStep;
  if (nextStep == null) {
    return null;
  }
  return PracticeRouteArgs.maybeCreate(
    spaceId: nextStep.spaceId,
    activityId: nextStep.activityId,
  )?.normalized();
}

bool isHouseholdSharedProjectionNewer(
  HouseholdSharedContext sharedContext,
  DateTime? localLatestAt,
) {
  if (localLatestAt == null) {
    return true;
  }
  return sharedContext.latestInteractionAt.isAfter(localLatestAt);
}

String householdActorRoleLabel(String? role) {
  switch (role?.trim()) {
    case 'primary_caregiver':
      return '主照护者';
    case 'caregiver':
      return '次照护者';
    default:
      return '家庭成员';
  }
}

String householdActorSourceLabel(String? source) {
  switch (source?.trim()) {
    case 'sync_event':
      return '同步回流';
    default:
      return '共享同步';
  }
}

String householdActorResultLabel(String? result) {
  switch (result?.trim()) {
    case 'calm':
      return '平静回应';
    case 'engaged':
      return '愿意看着你';
    case 'imitated':
      return '开始模仿';
    case 'needs_break':
      return '需要先休息';
    default:
      return '已记录反馈';
  }
}

String householdNextStepReasonLabel(String? reason) {
  switch (reason?.trim()) {
    case 'latest_activity':
      return '继续刚完成的 activity';
    case 'top_activity':
      return '先接上当前最该继续的 activity';
    default:
      return '共享下一步已整理好';
  }
}

String householdSharedAttributionHeadline(
  HouseholdSharedContext sharedContext,
) {
  final actor = sharedContext.actor;
  if (actor == null) {
    return '家庭刚完成一次共享练习';
  }
  return '${householdActorRoleLabel(actor.role)}刚完成一次共享练习';
}

String householdSharedAttributionDetail(HouseholdSharedContext sharedContext) {
  final actor = sharedContext.actor;
  final time = formatHouseholdSharedDateTime(sharedContext.latestInteractionAt);
  if (actor == null) {
    return '最近互动 $time · 归因字段缺失时仅保留脱敏共享摘要。';
  }
  return '${householdActorSourceLabel(actor.source)} · ${householdActorResultLabel(actor.result)} · 最近互动 $time';
}

String householdSharedNextStepDetail(HouseholdSharedContext sharedContext) {
  final safeArgs = resolveHouseholdSharedNextStepArgs(sharedContext);
  if (safeArgs == null) {
    return '共享下一步缺少安全 route args，入口已停留在安全禁用态。';
  }
  return '${householdNextStepReasonLabel(sharedContext.nextStep?.reason)} · ${safeArgs.scopeLabel}';
}

String householdSharedProjectionMeta(HouseholdSharedContext sharedContext) {
  return '最近互动 ${formatHouseholdSharedDateTime(sharedContext.latestInteractionAt)} · 投影刷新 ${formatHouseholdSharedDateTime(sharedContext.updatedAt)}';
}

String householdSharedUnavailableNextStepMessage(
  HouseholdSharedContext sharedContext,
) {
  return '共享上下文已刷新，但下一步缺少安全入口；当前不会回退到错误默认 activity。';
}

class HouseholdSharedPracticeOverlayCard extends StatelessWidget {
  const HouseholdSharedPracticeOverlayCard({
    super.key,
    required this.surfaceKeyPrefix,
    required this.sharedContext,
    this.buttonLabel = '进入共享下一步',
    this.onPressed,
  });

  final String surfaceKeyPrefix;
  final HouseholdSharedContext sharedContext;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);
    final safeArgs = resolveHouseholdSharedNextStepArgs(sharedContext);
    final effectiveOnPressed = safeArgs == null
        ? null
        : onPressed ??
              () async {
                await safeArgs.push(context);
              };

    return Container(
      key: Key('$surfaceKeyPrefix-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.bgAccentSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildRoleChip(
                context,
                key: Key('$surfaceKeyPrefix-actor-chip'),
                label: sharedContext.actor == null
                    ? l.householdSharedAttribution
                    : householdActorRoleLabel(sharedContext.actor!.role),
                backgroundColor: colors.englishSoft,
                foregroundColor: colors.english,
              ),
              _buildRoleChip(
                context,
                key: Key('$surfaceKeyPrefix-next-step-chip'),
                label: safeArgs == null
                    ? l.householdEntryPending
                    : l.householdNextStepReady,
                backgroundColor: safeArgs == null
                    ? colors.warningSoft
                    : colors.bgSurface,
                foregroundColor: safeArgs == null
                    ? colors.warning
                    : colors.accentDark,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            householdSharedAttributionHeadline(sharedContext),
            key: Key('$surfaceKeyPrefix-headline'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            householdSharedNextStepDetail(sharedContext),
            key: Key('$surfaceKeyPrefix-detail'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          Text(
            householdSharedAttributionDetail(sharedContext),
            key: Key('$surfaceKeyPrefix-attribution'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            householdSharedProjectionMeta(sharedContext),
            key: Key('$surfaceKeyPrefix-meta'),
            style: theme.textTheme.bodySmall,
          ),
          if (safeArgs == null) ...[
            const SizedBox(height: 14),
            Container(
              key: Key('$surfaceKeyPrefix-disabled-banner'),
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.warningSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                householdSharedUnavailableNextStepMessage(sharedContext),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            key: Key('$surfaceKeyPrefix-button'),
            onPressed: effectiveOnPressed,
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class HouseholdSharedContextCard extends StatelessWidget {
  const HouseholdSharedContextCard({
    super.key,
    required this.surfaceKeyPrefix,
    this.notifier,
    this.title = '共享照护',
    this.compact = false,
    this.retryReason,
  });

  final String surfaceKeyPrefix;

  /// Accepts either a [HouseholdNotifier] or [HouseholdNotifier].
  final dynamic notifier;
  final String title;
  final bool compact;
  final String? retryReason;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    if (notifier == null) {
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
              label: l.householdSharedNotConnected,
              backgroundColor: colors.warningSoft,
              foregroundColor: colors.warning,
            ),
            const SizedBox(height: 12),
            Text(
              '共享功能暂未接通',
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

    final snapshot = notifier!.snapshot;
    final sharedContext = snapshot.sharedContext;
    final role = snapshot.role;
    final roleStyle = _roleStyle(role, colors);
    final theme = Theme.of(context);
    final visibleMessage = _visibleMessage(notifier!, snapshot);
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
                backgroundColor: colors.bgSunken,
                foregroundColor: colors.textSecondary,
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
              '最近接受：${formatHouseholdSharedDateTime(snapshot.lastAcceptedAt!)}',
              key: Key('$surfaceKeyPrefix-household-accepted-at'),
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (sharedContext != null) ...[
            const SizedBox(height: 10),
            Text(
              householdSharedProjectionMeta(sharedContext),
              key: Key('$surfaceKeyPrefix-household-updated-at'),
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (hasVisibleMessage) ...[
            const SizedBox(height: 12),
            _HouseholdBanner(
              key: Key('$surfaceKeyPrefix-household-error-banner'),
              message: visibleMessage,
              backgroundColor: _bannerBackgroundFor(snapshot, colors),
              foregroundColor: _bannerForegroundFor(snapshot, colors),
            ),
          ],
          if (sharedContext != null) ...[
            const SizedBox(height: 14),
            _SharedAttributionPanel(
              surfaceKeyPrefix: surfaceKeyPrefix,
              sharedContext: sharedContext,
            ),
            const SizedBox(height: 12),
            _SharedNextStepPanel(
              surfaceKeyPrefix: surfaceKeyPrefix,
              sharedContext: sharedContext,
            ),
            const SizedBox(height: 12),
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
                color: colors.bgSunken,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _emptyStateMessage(snapshot),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
          if (_shouldShowRetry(notifier!, snapshot)) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  key: Key('$surfaceKeyPrefix-household-retry-button'),
                  onPressed: notifier!.isBusy
                      ? null
                      : () => _handleRetry(notifier!, surfaceKeyPrefix),
                  child: Text(
                    notifier!.isBusy
                        ? '处理中…'
                        : _retryLabelFor(notifier!, snapshot),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleRetry(dynamic notifier, String surfaceKeyPrefix) async {
    final shouldRetryLastAction =
        notifier.lastActionKind == HouseholdActionKind.acceptInvite ||
        notifier.lastActionKind == HouseholdActionKind.refreshSharedContext;
    if (shouldRetryLastAction) {
      await notifier.retryLastAction();
      return;
    }
    await notifier.refreshSharedContext(
      reason: retryReason ?? '${surfaceKeyPrefix}_manual_refresh',
    );
  }

  bool _shouldShowRetry(dynamic notifier, HouseholdLocalSnapshot snapshot) {
    if (notifier.isBusy) {
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

  String _retryLabelFor(dynamic notifier, HouseholdLocalSnapshot snapshot) {
    if (notifier.isBusy) {
      return '处理中…';
    }
    switch (notifier.lastActionKind) {
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
      default:
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
        return '你当前是主照护者，可以管理邀请，并查看共享宝宝档案、最近归因与下一步入口。';
      case HouseholdRole.caregiver:
        return snapshot.sharedContext == null
            ? '你当前是次照护者；邀请接受成功后，这里会显示共享宝宝档案、最近归因与下一步入口。'
            : '你当前是次照护者；这里展示的是共享宝宝档案、最近归因与下一步入口。';
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
      return '生成邀请并等待次照护者接受后，这里会出现共享宝宝档案与下一步入口。';
    }
    if (snapshot.role == HouseholdRole.caregiver) {
      return '接受邀请后，如果共享上下文尚未刷新完成，这里会保留只读等待态。';
    }
    return 'household 尚未初始化；当前保持显式 disabled 状态。';
  }

  String? _visibleMessage(dynamic notifier, HouseholdLocalSnapshot snapshot) {
    final snapshotMessage = snapshot.lastVisibleError?.trim();
    final notifierMessage = notifier.message?.trim();
    if (snapshotMessage != null && snapshotMessage.isNotEmpty) {
      return snapshotMessage;
    }
    if (notifierMessage != null && notifierMessage.isNotEmpty) {
      switch (notifier.lastActionKind) {
        case HouseholdActionKind.acceptInvite:
        case HouseholdActionKind.refreshSharedContext:
          return notifierMessage;
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

  Color _bannerBackgroundFor(
    HouseholdLocalSnapshot snapshot,
    BabyTalkColors colors,
  ) {
    if (_isUnavailablePhase(snapshot.lastPhase)) {
      return snapshot.lastPhase.contains('malformed')
          ? colors.errorSoft
          : colors.warningSoft;
    }
    return colors.infoSoft;
  }

  Color _bannerForegroundFor(
    HouseholdLocalSnapshot snapshot,
    BabyTalkColors colors,
  ) {
    if (_isUnavailablePhase(snapshot.lastPhase)) {
      return snapshot.lastPhase.contains('malformed')
          ? colors.error
          : colors.warning;
    }
    return colors.info;
  }
}

class _SharedAttributionPanel extends StatelessWidget {
  const _SharedAttributionPanel({
    required this.surfaceKeyPrefix,
    required this.sharedContext,
  });

  final String surfaceKeyPrefix;
  final HouseholdSharedContext sharedContext;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final actor = sharedContext.actor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.englishSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.householdRecentAttribution,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildRoleChip(
                context,
                key: Key('$surfaceKeyPrefix-household-actor-role-chip'),
                label: actor == null
                    ? l.householdAttributionPending
                    : householdActorRoleLabel(actor.role),
                backgroundColor: colors.bgSurface,
                foregroundColor: colors.english,
              ),
              _buildRoleChip(
                context,
                key: Key('$surfaceKeyPrefix-household-actor-result-chip'),
                label: actor == null
                    ? l.householdSafeSummary
                    : householdActorResultLabel(actor.result),
                backgroundColor: colors.bgSurface,
                foregroundColor: colors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            householdSharedAttributionHeadline(sharedContext),
            key: Key('$surfaceKeyPrefix-household-attribution-headline'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(
            householdSharedAttributionDetail(sharedContext),
            key: Key('$surfaceKeyPrefix-household-attribution-detail'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _SharedNextStepPanel extends StatelessWidget {
  const _SharedNextStepPanel({
    required this.surfaceKeyPrefix,
    required this.sharedContext,
  });

  final String surfaceKeyPrefix;
  final HouseholdSharedContext sharedContext;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final safeArgs = resolveHouseholdSharedNextStepArgs(sharedContext);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.bgSunken,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.householdSharedNextStep,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 10),
          Text(
            householdSharedNextStepDetail(sharedContext),
            key: Key('$surfaceKeyPrefix-household-next-step-detail'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: Key('$surfaceKeyPrefix-household-next-step-button'),
            onPressed: safeArgs == null
                ? null
                : () async {
                    await safeArgs.push(context);
                  },
            child: Text(
              safeArgs == null
                  ? l.householdNextStepPending
                  : l.enterSharedNextStep,
            ),
          ),
          if (safeArgs == null) ...[
            const SizedBox(height: 10),
            Text(
              householdSharedUnavailableNextStepMessage(sharedContext),
              key: Key('$surfaceKeyPrefix-household-next-step-disabled'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
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
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryRow(
          label: l.householdSharedBabyProfile,
          text: sharedContext.babyProfileSummary,
          valueKey: Key('$surfaceKeyPrefix-household-profile-summary'),
        ),
        const SizedBox(height: 12),
        _SummaryRow(
          label: l.householdRecentContinuity,
          text: sharedContext.continuitySummary,
          valueKey: Key('$surfaceKeyPrefix-household-continuity-summary'),
        ),
        const SizedBox(height: 12),
        _SummaryRow(
          label: l.householdGardenContext,
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
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineSoft),
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
              color: colors.textPrimary,
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
    final colors = context.appColors;
    return Container(
      key: Key('$surfaceKeyPrefix-household-shared-context-card'),
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 18),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(compact ? 20 : 24),
        border: Border.all(color: colors.outlineSoft),
        boxShadow: colors.warmShadowSm,
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

_RoleStyle _roleStyle(HouseholdRole? role, BabyTalkColors colors) {
  switch (role) {
    case HouseholdRole.primaryCaregiver:
      return _RoleStyle(
        label: '主照护者',
        backgroundColor: colors.bgAccentSoft,
        foregroundColor: colors.accentDark,
      );
    case HouseholdRole.caregiver:
      return _RoleStyle(
        label: '次照护者',
        backgroundColor: colors.englishSoft,
        foregroundColor: colors.english,
      );
    case null:
      return _RoleStyle(
        label: '角色待同步',
        backgroundColor: colors.bgSunken,
        foregroundColor: colors.textSecondary,
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

String formatHouseholdSharedDateTime(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute';
}
