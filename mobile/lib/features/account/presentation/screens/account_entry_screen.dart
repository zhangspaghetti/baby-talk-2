import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/app/widgets/app_haptics.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/presentation/account_notifier.dart';
import 'package:mobile/features/account/presentation/account_surface_phase.dart';
import 'package:mobile/features/household/presentation/widgets/household_invite_card.dart';
import 'package:mobile/features/household/presentation/widgets/household_shared_context_card.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/l10n/app_localizations.dart';

Future<void> openAccountEntryScreen(BuildContext context) {
  return GoRouter.of(context).push('/account');
}

String _accountBodyForPhase(
  AppLocalizations l,
  AccountSurfacePhase phase,
  OnboardingSnapshot? snapshot,
  AccountNotifier notifier,
) {
  switch (phase) {
    case AccountSurfacePhase.loading:
      return l.accountShellNote;
    case AccountSurfacePhase.localOnly:
      final name = snapshot?.childDisplayName.trim();
      final prefix = name == null || name.isEmpty
          ? l.accountCurrentProfile
          : l.accountProfileName(name);
      return l.accountLocalOnlyNote(prefix);
    case AccountSurfacePhase.signedOut:
      return l.accountEntryNote;
    case AccountSurfacePhase.signedInPendingSync:
      return l.accountPendingSync(notifier.snapshot.pendingSyncCount);
    case AccountSurfacePhase.signedInSynced:
      return l.accountAlignedNote;
    case AccountSurfacePhase.signedInFailed:
      return l.accountSyncIncomplete;
    case AccountSurfacePhase.revoked:
      return l.accountRevokedNote;
    case AccountSurfacePhase.deleted:
      return l.accountDeletedNote;
    case AccountSurfacePhase.versionBlocked:
      return notifier.canOpenUpgradePage
          ? l.accountUpgradeNote
          : l.accountUpgradeUnavailable;
    case AccountSurfacePhase.error:
      return l.accountReadFailedPrimary;
  }
}

Future<void> _confirmAccountDeletion(
  BuildContext context,
  WidgetRef ref,
) async {
  final l = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        key: const Key('account-delete-confirm-dialog'),
        title: Text(l.accountDeleteConfirmTitle),
        content: Text(l.accountDeleteConfirmBody),
        actions: [
          TextButton(
            key: const Key('account-delete-cancel-button'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.accountLifecycleCancel),
          ),
          FilledButton(
            key: const Key('account-delete-confirm-button'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.accountDeleteConfirmAction),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) {
    return;
  }
  await ref.read(accountNotifierProvider.notifier).deleteAccount();
}

Future<bool> _confirmLifecycleAction(
  BuildContext context, {
  required String title,
  required String content,
  required String confirmLabel,
  required Key dialogKey,
  required Key cancelKey,
  required Key confirmKey,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        key: dialogKey,
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            key: cancelKey,
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.accountLifecycleCancel),
          ),
          FilledButton(
            key: confirmKey,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );

  return confirmed == true;
}

Future<void> _confirmRevokeConsent(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l,
) async {
  final confirmed = await _confirmLifecycleAction(
    context,
    title: l.accountRevokeConfirmTitle,
    content: l.accountRevokeConfirmBody,
    confirmLabel: l.accountRevokeConfirmAction,
    dialogKey: const Key('account-revoke-confirm-dialog'),
    cancelKey: const Key('account-revoke-cancel-button'),
    confirmKey: const Key('account-revoke-confirm-button'),
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  await ref.read(accountNotifierProvider.notifier).revokeConsent();
}

Future<void> _confirmLogout(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l,
) async {
  final confirmed = await _confirmLifecycleAction(
    context,
    title: l.accountClearConfirmTitle,
    content: l.accountClearConfirmBody,
    confirmLabel: l.accountClearConfirmAction,
    dialogKey: const Key('account-clear-confirm-dialog'),
    cancelKey: const Key('account-clear-cancel-button'),
    confirmKey: const Key('account-clear-confirm-button'),
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  await ref.read(accountNotifierProvider.notifier).clearSession();
}

Future<void> _confirmReturnToLocalOnly(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l,
) async {
  final confirmed = await _confirmLifecycleAction(
    context,
    title: l.accountLocalOnlyConfirmTitle,
    content: l.accountLocalOnlyConfirmBody,
    confirmLabel: l.accountLocalOnlyConfirmAction,
    dialogKey: const Key('account-local-only-confirm-dialog'),
    cancelKey: const Key('account-local-only-cancel-button'),
    confirmKey: const Key('account-local-only-confirm-button'),
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  await ref
      .read(accountNotifierProvider.notifier)
      .clearSession(revertToLocalOnly: true);
}

class AccountStatusCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);
    final notifier = ref.watch(accountNotifierProvider);
    final phase = resolveAccountPhase(
      notifier,
      onboardingSnapshot: onboardingSnapshot,
    );
    final title = _titleForPhase(l, phase, notifier);
    final body = _bodyForPhase(l, phase, onboardingSnapshot, notifier);
    final chips = _buildChips(l, notifier);
    final hasLastVisibleError =
        notifier.snapshot.lastVisibleError != null &&
        notifier.snapshot.lastVisibleError!.trim().isNotEmpty &&
        phase != AccountSurfacePhase.error;
    final hasUpgradeHelper =
        phase == AccountSurfacePhase.versionBlocked &&
        notifier.upgradeActionHint != null;
    final showChipGuidance =
        chips.isNotEmpty &&
        !hasUpgradeHelper &&
        phase != AccountSurfacePhase.error;
    final showSubmissionMessage =
        notifier.submissionMessage != null &&
        phase != AccountSurfacePhase.error;

    return Container(
      key: Key('$scopeKeyPrefix-account-card'),
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
          Text(l.accountTitle, style: theme.textTheme.labelMedium),
          const SizedBox(height: 10),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodyMedium),
          if (hasLastVisibleError) ...[
            const SizedBox(height: 12),
            Container(
              key: Key('$scopeKeyPrefix-account-banner'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _bannerBackgroundForPhase(phase, colors),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                notifier.snapshot.lastVisibleError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _bannerForegroundForPhase(phase, colors),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
          ],
          if (showChipGuidance) ...[
            const SizedBox(height: 8),
            Text(
              _chipGuidanceForPhase(l, phase),
              key: Key('$scopeKeyPrefix-account-sync-chip-guidance'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
          if (showSubmissionMessage) ...[
            const SizedBox(height: 12),
            Text(
              notifier.submissionMessage!,
              key: Key('$scopeKeyPrefix-account-message'),
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (phase == AccountSurfacePhase.versionBlocked &&
              notifier.upgradeActionHint != null) ...[
            const SizedBox(height: 12),
            Text(
              notifier.upgradeActionHint!,
              key: Key('$scopeKeyPrefix-account-upgrade-hint'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
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
                onPressed:
                    phase == AccountSurfacePhase.loading || notifier.isBusy
                    ? null
                    : () => openAccountEntryScreen(context),
                child: Text(
                  notifier.isSignedIn
                      ? l.accountViewStatus
                      : l.accountRegisterLogin,
                ),
              ),
              if (phase == AccountSurfacePhase.versionBlocked)
                FilledButton(
                  key: Key('$scopeKeyPrefix-account-upgrade-button'),
                  onPressed: notifier.canOpenUpgradePage
                      ? notifier.openUpgradePage
                      : null,
                  child: Text(notifier.upgradeActionLabel),
                ),
              if (phase == AccountSurfacePhase.error)
                OutlinedButton(
                  key: Key('$scopeKeyPrefix-account-retry-load'),
                  onPressed: notifier.reload,
                  child: Text(l.accountRetryRead),
                ),
              if (notifier.isSignedIn ||
                  phase == AccountSurfacePhase.versionBlocked ||
                  phase == AccountSurfacePhase.signedInFailed ||
                  phase == AccountSurfacePhase.revoked)
                OutlinedButton(
                  key: Key('$scopeKeyPrefix-account-retry-sync'),
                  onPressed: notifier.isBusy
                      ? null
                      : () => notifier.refreshRuntimeState(
                          trigger: AccountRuntimeTrigger.manualRetry,
                        ),
                  child: Text(l.accountRetrySync),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _titleForPhase(
    AppLocalizations l,
    AccountSurfacePhase phase,
    AccountNotifier notifier,
  ) {
    switch (phase) {
      case AccountSurfacePhase.loading:
        return l.accountReading;
      case AccountSurfacePhase.localOnly:
        return l.accountLocalOnly;
      case AccountSurfacePhase.signedOut:
        return l.accountNotLoggedIn;
      case AccountSurfacePhase.signedInPendingSync:
        return l.accountSignedIn(notifier.maskedPhoneNumber);
      case AccountSurfacePhase.signedInSynced:
        return l.accountSignedIn(notifier.maskedPhoneNumber);
      case AccountSurfacePhase.signedInFailed:
        return l.accountSyncRetryNeeded;
      case AccountSurfacePhase.revoked:
        return l.accountConsentRevoked;
      case AccountSurfacePhase.deleted:
        return l.accountDeleted;
      case AccountSurfacePhase.versionBlocked:
        return l.accountUpgradeNeeded;
      case AccountSurfacePhase.error:
        return l.accountStatusUnreadable;
    }
  }

  String _bodyForPhase(
    AppLocalizations l,
    AccountSurfacePhase phase,
    OnboardingSnapshot? snapshot,
    AccountNotifier notifier,
  ) {
    return _accountBodyForPhase(l, phase, snapshot, notifier);
  }

  List<Widget> _buildChips(AppLocalizations l, AccountNotifier notifier) {
    final chips = <Widget>[];
    chips.add(
      Chip(
        key: Key('$scopeKeyPrefix-account-pending-chip'),
        label: Text(
          l.accountPendingSyncCount(notifier.snapshot.pendingSyncCount),
        ),
      ),
    );
    chips.add(
      Chip(
        key: Key('$scopeKeyPrefix-account-synced-chip'),
        label: Text(l.accountSyncedCount(notifier.snapshot.syncedCount)),
      ),
    );
    chips.add(
      Chip(
        key: Key('$scopeKeyPrefix-account-failed-chip'),
        label: Text(l.accountFailedCount(notifier.snapshot.failedCount)),
      ),
    );
    if (notifier.snapshot.lastSyncPhase.trim().isNotEmpty) {
      chips.add(
        Chip(
          key: Key('$scopeKeyPrefix-account-phase-chip'),
          label: Text(l.accountSyncPhaseUpdated),
        ),
      );
    }
    final lastSyncAt = notifier.snapshot.lastSyncAt;
    if (lastSyncAt != null) {
      final local = lastSyncAt.toLocal();
      final hour = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      chips.add(
        Chip(
          key: Key('$scopeKeyPrefix-account-time-chip'),
          label: Text(l.accountRecentTime('$hour:$minute')),
        ),
      );
    }
    return chips;
  }

  String _chipGuidanceForPhase(AppLocalizations l, AccountSurfacePhase phase) {
    switch (phase) {
      case AccountSurfacePhase.revoked:
      case AccountSurfacePhase.deleted:
        return l.accountLifecycleChipGuidance;
      case AccountSurfacePhase.error:
        return l.accountReadErrorChipGuidance;
      default:
        return l.accountSyncChipGuidance;
    }
  }

  Color _bannerBackgroundForPhase(
    AccountSurfacePhase phase,
    BabyTalkColors colors,
  ) {
    switch (phase) {
      case AccountSurfacePhase.versionBlocked:
        return colors.warningSoft;
      case AccountSurfacePhase.deleted:
      case AccountSurfacePhase.error:
        return colors.errorSoft;
      case AccountSurfacePhase.revoked:
      case AccountSurfacePhase.signedInFailed:
        return colors.warningSoft;
      default:
        return colors.infoSoft;
    }
  }

  Color _bannerForegroundForPhase(
    AccountSurfacePhase phase,
    BabyTalkColors colors,
  ) {
    switch (phase) {
      case AccountSurfacePhase.versionBlocked:
      case AccountSurfacePhase.revoked:
      case AccountSurfacePhase.signedInFailed:
        return colors.warning;
      case AccountSurfacePhase.deleted:
      case AccountSurfacePhase.error:
        return colors.error;
      default:
        return colors.info;
    }
  }
}

class _AccountEntrySection extends StatelessWidget {
  const _AccountEntrySection({
    super.key,
    required this.title,
    required this.child,
    this.eyebrow,
    this.description,
  });

  final String title;
  final String? eyebrow;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(title, style: theme.textTheme.titleMedium),
        if (description != null) ...[
          const SizedBox(height: 8),
          Text(
            description!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

class AccountEntryScreen extends HookConsumerWidget {
  const AccountEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phoneController = useTextEditingController();
    final codeController = useTextEditingController();

    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);
    final notifier = ref.watch(accountNotifierProvider);
    final householdNotifier = ref.watch(householdNotifierProvider);
    final phase = resolveAccountPhase(notifier);
    final helperBody = _accountBodyForPhase(l, phase, null, notifier);
    final showSubmissionMessage =
        notifier.submissionMessage != null &&
        phase != AccountSurfacePhase.error;
    final showSignInForm =
        !notifier.isSignedIn || phase == AccountSurfacePhase.revoked;

    if (phoneController.text != notifier.phoneNumber) {
      phoneController.value = TextEditingValue(
        text: notifier.phoneNumber,
        selection: TextSelection.collapsed(offset: notifier.phoneNumber.length),
      );
    }
    if (codeController.text != notifier.verificationCode) {
      codeController.value = TextEditingValue(
        text: notifier.verificationCode,
        selection: TextSelection.collapsed(
          offset: notifier.verificationCode.length,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.accountEntryTitle)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayoutConstants.maxContentWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                Container(
                  key: const Key('account-entry-surface'),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colors.bgSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.outlineSoft),
                    boxShadow: colors.warmShadowSm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AccountEntrySection(
                        key: const Key('account-current-status-section'),
                        title: l.accountCurrentStatusSectionTitle,
                        eyebrow: l.accountEntryS03Label,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _headlineForPhase(l, phase, notifier),
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            Text(helperBody, style: theme.textTheme.bodyMedium),
                            const SizedBox(height: 16),
                            Container(
                              key: Key('account-status-${_phaseKey(phase)}'),
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _phaseBackground(phase, colors),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                _statusText(l, phase, notifier),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: _phaseForeground(phase, colors),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (notifier.loadErrorMessage != null) ...[
                              const SizedBox(height: 12),
                              OutlinedButton(
                                key: const Key('account-load-retry'),
                                onPressed: notifier.reload,
                                child: Text(l.accountRetryReadStatus),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l.accountReadRetryGuidance,
                                key: const Key('account-read-retry-guidance'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                            if (phase != AccountSurfacePhase.error &&
                                notifier.snapshot.lastVisibleError != null &&
                                notifier.snapshot.lastVisibleError!
                                    .trim()
                                    .isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                l.accountLastError(
                                  notifier.snapshot.lastVisibleError!,
                                ),
                                key: const Key('account-last-error'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: _phaseForeground(phase, colors),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            if (showSubmissionMessage) ...[
                              const SizedBox(height: 12),
                              Text(
                                notifier.submissionMessage!,
                                key: const Key('account-submit-message'),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                            if (phase == AccountSurfacePhase.versionBlocked &&
                                notifier.upgradeActionHint != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                notifier.upgradeActionHint!,
                                key: const Key('account-upgrade-hint'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l.accountUpgradeReassurance,
                                key: const Key('account-upgrade-reassurance'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _AccountEntrySection(
                        key: const Key('account-primary-action-section'),
                        title: l.accountPrimaryActionSectionTitle,
                        description: showSignInForm
                            ? l.accountPrimaryActionSectionHint
                            : l.accountPrimaryActionSignedInHint,
                        child: showSignInForm
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    key: const Key('account-phone-field'),
                                    controller: phoneController,
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      labelText: l.accountPhoneLabel,
                                      hintText: kDebugMode
                                          ? '13800138000'
                                          : null,
                                      errorText: notifier.phoneError,
                                    ),
                                    onChanged: notifier.updatePhoneNumber,
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    key: const Key('account-code-field'),
                                    controller: codeController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: l.accountCodeLabel,
                                      hintText: l.accountDevStub,
                                      errorText: notifier.verificationCodeError,
                                    ),
                                    onChanged: notifier.updateVerificationCode,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    l.accountRealLoginNote,
                                    key: const Key(
                                      'account-sign-in-trust-note',
                                    ),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton(
                                    key: const Key('account-submit-button'),
                                    onPressed: notifier.isBusy
                                        ? null
                                        : () async {
                                            AppHaptics.lightTap();
                                            final succeeded = await ref
                                                .read(
                                                  accountNotifierProvider
                                                      .notifier,
                                                )
                                                .submitSignIn();
                                            if (!context.mounted ||
                                                !succeeded) {
                                              return;
                                            }
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  l.accountEntrySubmitMessage,
                                                ),
                                              ),
                                            );
                                          },
                                    child: Text(
                                      notifier.isBusy
                                          ? l.processing
                                          : l.accountLoginConsent,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                l.accountPrimaryActionSignedInBody,
                                style: theme.textTheme.bodyMedium,
                              ),
                      ),
                      const SizedBox(height: 24),
                      _AccountEntrySection(
                        key: const Key('account-recovery-section'),
                        title: l.accountRecoverySectionTitle,
                        description: l.accountRecoverySectionHint,
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            if (phase == AccountSurfacePhase.versionBlocked)
                              FilledButton(
                                key: const Key('account-upgrade-button'),
                                onPressed: notifier.canOpenUpgradePage
                                    ? () {
                                        AppHaptics.lightTap();
                                        ref
                                            .read(
                                              accountNotifierProvider.notifier,
                                            )
                                            .openUpgradePage();
                                      }
                                    : null,
                                child: Text(notifier.upgradeActionLabel),
                              ),
                            OutlinedButton(
                              key: const Key('account-sync-retry-button'),
                              onPressed: notifier.isBusy
                                  ? null
                                  : () {
                                      AppHaptics.lightTap();
                                      ref
                                          .read(
                                            accountNotifierProvider.notifier,
                                          )
                                          .refreshRuntimeState(
                                            trigger: AccountRuntimeTrigger
                                                .manualRetry,
                                          );
                                    },
                              child: Text(l.accountRetrySync),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _AccountEntrySection(
                        key: const Key('account-family-context-section'),
                        title: l.accountFamilyContextSectionTitle,
                        description: l.accountFamilyContextSectionHint,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            HouseholdSharedContextCard(
                              surfaceKeyPrefix: 'account',
                              notifier: householdNotifier,
                              title: l.sharedAttributionNextStep,
                              retryReason: 'account_entry_manual_refresh',
                            ),
                            const SizedBox(height: 16),
                            HouseholdInviteCard(
                              surfaceKeyPrefix: 'account',
                              notifier: householdNotifier,
                              inviteSource: 'account_entry',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _AccountEntrySection(
                        key: const Key('account-management-section'),
                        title: l.accountManagementSectionTitle,
                        description: l.accountManagementSectionHint,
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            OutlinedButton(
                              key: const Key('account-clear-button'),
                              onPressed: notifier.isBusy
                                  ? null
                                  : () async {
                                      AppHaptics.lightTap();
                                      await _confirmLogout(context, ref, l);
                                    },
                              child: Text(l.accountLogout),
                            ),
                            OutlinedButton(
                              key: const Key('account-local-only-button'),
                              onPressed: notifier.isBusy
                                  ? null
                                  : () async {
                                      AppHaptics.lightTap();
                                      await _confirmReturnToLocalOnly(
                                        context,
                                        ref,
                                        l,
                                      );
                                    },
                              child: Text(l.accountBackToLocal),
                            ),
                            OutlinedButton(
                              key: const Key('account-close-button'),
                              onPressed: () => Navigator.of(context).maybePop(),
                              child: Text(l.close),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _AccountEntrySection(
                        key: const Key('account-danger-zone-section'),
                        title: l.accountDangerZoneSectionTitle,
                        description: l.accountDangerZoneSectionHint,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.accountDangerZoneRetentionNote,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                OutlinedButton(
                                  key: const Key('account-revoke-button'),
                                  onPressed:
                                      notifier.isBusy || !notifier.isSignedIn
                                      ? null
                                      : () async {
                                          AppHaptics.lightTap();
                                          await _confirmRevokeConsent(
                                            context,
                                            ref,
                                            l,
                                          );
                                        },
                                  child: Text(l.accountRevokeConsent),
                                ),
                                OutlinedButton(
                                  key: const Key('account-delete-button'),
                                  onPressed:
                                      notifier.isBusy || !notifier.isSignedIn
                                      ? null
                                      : () async {
                                          AppHaptics.lightTap();
                                          await _confirmAccountDeletion(
                                            context,
                                            ref,
                                          );
                                        },
                                  child: Text(l.accountDeleteAccount),
                                ),
                              ],
                            ),
                          ],
                        ),
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

  String _headlineForPhase(
    AppLocalizations l,
    AccountSurfacePhase phase,
    AccountNotifier notifier,
  ) {
    switch (phase) {
      case AccountSurfacePhase.loading:
        return l.accountEntryLoading;
      case AccountSurfacePhase.localOnly:
        return l.accountEntryPreparingProfile;
      case AccountSurfacePhase.signedOut:
        return l.accountEntryVisibleNotLoggedIn;
      case AccountSurfacePhase.signedInPendingSync:
        return l.accountSignedInPending(notifier.maskedPhoneNumber);
      case AccountSurfacePhase.signedInSynced:
        return l.accountEntrySignedInSynced(notifier.maskedPhoneNumber);
      case AccountSurfacePhase.signedInFailed:
        return l.accountSignedInSyncRetry;
      case AccountSurfacePhase.revoked:
        return l.accountConsentRevoked;
      case AccountSurfacePhase.deleted:
        return l.accountDeleted;
      case AccountSurfacePhase.versionBlocked:
        return l.accountUpgradeNeeded;
      case AccountSurfacePhase.error:
        return l.accountEntryReadFailedShell;
    }
  }

  String _statusText(
    AppLocalizations l,
    AccountSurfacePhase phase,
    AccountNotifier notifier,
  ) {
    switch (phase) {
      case AccountSurfacePhase.loading:
        return l.accountReading;
      case AccountSurfacePhase.localOnly:
        return l.accountLocalOnly;
      case AccountSurfacePhase.signedOut:
        return l.accountNotLoggedIn;
      case AccountSurfacePhase.signedInPendingSync:
        return l.accountSignedInPendingSyncStatus(
          notifier.snapshot.pendingSyncCount,
        );
      case AccountSurfacePhase.signedInSynced:
        return l.accountEntrySignedInSynced(notifier.maskedPhoneNumber);
      case AccountSurfacePhase.signedInFailed:
        return l.accountSyncRetryNeeded;
      case AccountSurfacePhase.revoked:
        return l.accountConsentRevoked;
      case AccountSurfacePhase.deleted:
        return l.accountDeleted;
      case AccountSurfacePhase.versionBlocked:
        return l.accountUpgradeNeeded;
      case AccountSurfacePhase.error:
        return l.accountStatusUnreadable;
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

  Color _phaseBackground(AccountSurfacePhase phase, BabyTalkColors colors) {
    switch (phase) {
      case AccountSurfacePhase.loading:
        return colors.bgSunken;
      case AccountSurfacePhase.localOnly:
        return colors.infoSoft;
      case AccountSurfacePhase.signedOut:
        return colors.warningSoft;
      case AccountSurfacePhase.signedInPendingSync:
      case AccountSurfacePhase.signedInSynced:
        return colors.englishSoft;
      case AccountSurfacePhase.signedInFailed:
      case AccountSurfacePhase.revoked:
      case AccountSurfacePhase.versionBlocked:
        return colors.warningSoft;
      case AccountSurfacePhase.deleted:
      case AccountSurfacePhase.error:
        return colors.errorSoft;
    }
  }

  Color _phaseForeground(AccountSurfacePhase phase, BabyTalkColors colors) {
    switch (phase) {
      case AccountSurfacePhase.loading:
        return colors.textSecondary;
      case AccountSurfacePhase.localOnly:
        return colors.info;
      case AccountSurfacePhase.signedOut:
        return colors.warning;
      case AccountSurfacePhase.signedInPendingSync:
      case AccountSurfacePhase.signedInSynced:
        return colors.english;
      case AccountSurfacePhase.signedInFailed:
      case AccountSurfacePhase.revoked:
      case AccountSurfacePhase.versionBlocked:
        return colors.warning;
      case AccountSurfacePhase.deleted:
      case AccountSurfacePhase.error:
        return colors.error;
    }
  }
}
