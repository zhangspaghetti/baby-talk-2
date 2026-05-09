import 'package:flutter/material.dart';
import 'package:mobile/app/theme/app_layout_constants.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/presentation/account_surface_phase.dart';
import 'package:mobile/features/account/presentation/account_view_model.dart';
import 'package:mobile/features/household/presentation/household_view_model.dart';
import 'package:mobile/features/household/presentation/widgets/household_invite_card.dart';
import 'package:mobile/features/household/presentation/widgets/household_shared_context_card.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:provider/provider.dart';
import 'package:mobile/l10n/app_localizations.dart';

Future<void> openAccountEntryScreen(BuildContext context) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const AccountEntryScreen()));
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
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);
    final viewModel = context.watch<AccountViewModel>();
    final phase = resolveAccountPhase(
      viewModel,
      onboardingSnapshot: onboardingSnapshot,
    );
    final title = _titleForPhase(l, phase, viewModel);
    final body = _bodyForPhase(l, phase, onboardingSnapshot, viewModel);
    final chips = _buildChips(l, viewModel);

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
          if (viewModel.snapshot.lastVisibleError != null &&
              viewModel.snapshot.lastVisibleError!.trim().isNotEmpty) ...[
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
                viewModel.snapshot.lastVisibleError!,
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
                    phase == AccountSurfacePhase.loading || viewModel.isBusy
                    ? null
                    : () => openAccountEntryScreen(context),
                child: Text(
                  viewModel.isSignedIn
                      ? l.accountViewStatus
                      : l.accountRegisterLogin,
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
                  child: Text(l.accountRetryRead),
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
    AccountViewModel viewModel,
  ) {
    switch (phase) {
      case AccountSurfacePhase.loading:
        return l.accountReading;
      case AccountSurfacePhase.localOnly:
        return l.accountLocalOnly;
      case AccountSurfacePhase.signedOut:
        return l.accountNotLoggedIn;
      case AccountSurfacePhase.signedInPendingSync:
        return l.accountSignedIn(viewModel.maskedPhoneNumber);
      case AccountSurfacePhase.signedInSynced:
        return l.accountSignedIn(viewModel.maskedPhoneNumber);
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
    AccountViewModel viewModel,
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
        return l.accountPendingSync(viewModel.snapshot.pendingSyncCount);
      case AccountSurfacePhase.signedInSynced:
        return l.accountAlignedNote;
      case AccountSurfacePhase.signedInFailed:
        return l.accountSyncIncomplete;
      case AccountSurfacePhase.revoked:
        return l.accountRevokedNote;
      case AccountSurfacePhase.deleted:
        return l.accountDeletedNote;
      case AccountSurfacePhase.versionBlocked:
        return viewModel.canOpenUpgradePage
            ? l.accountUpgradeNote
            : l.accountUpgradeUnavailable;
      case AccountSurfacePhase.error:
        return viewModel.loadErrorMessage ?? l.accountReadFailed;
    }
  }

  List<Widget> _buildChips(AppLocalizations l, AccountViewModel viewModel) {
    final chips = <Widget>[];
    chips.add(
      Chip(
        key: Key('$scopeKeyPrefix-account-pending-chip'),
        label: Text(
          l.accountPendingSyncCount(viewModel.snapshot.pendingSyncCount),
        ),
      ),
    );
    chips.add(
      Chip(
        key: Key('$scopeKeyPrefix-account-synced-chip'),
        label: Text(l.accountSyncedCount(viewModel.snapshot.syncedCount)),
      ),
    );
    chips.add(
      Chip(
        key: Key('$scopeKeyPrefix-account-failed-chip'),
        label: Text(l.accountFailedCount(viewModel.snapshot.failedCount)),
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
          label: Text(l.accountRecentTime('$hour:$minute')),
        ),
      );
    }
    return chips;
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
    final l = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final theme = Theme.of(context);
    final viewModel = context.watch<AccountViewModel>();
    final householdViewModel = context.watch<HouseholdViewModel?>();
    final phase = resolveAccountPhase(viewModel);

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
                      Text(
                        l.accountEntryS03Label,
                        style: theme.textTheme.labelMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _headlineForPhase(l, phase, viewModel),
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
                          _statusText(l, phase, viewModel),
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
                          child: Text(l.accountRetryReadStatus),
                        ),
                      ],
                      const SizedBox(height: 20),
                      TextField(
                        key: const Key('account-phone-field'),
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: l.accountPhoneLabel,
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
                          labelText: l.accountCodeLabel,
                          hintText: l.accountDevStub,
                          errorText: viewModel.verificationCodeError,
                        ),
                        onChanged: viewModel.updateVerificationCode,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l.accountRealLoginNote,
                        style: theme.textTheme.bodySmall,
                      ),
                      if (viewModel.snapshot.lastVisibleError != null &&
                          viewModel.snapshot.lastVisibleError!
                              .trim()
                              .isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          l.accountLastError(
                            viewModel.snapshot.lastVisibleError!,
                          ),
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
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      HouseholdSharedContextCard(
                        surfaceKeyPrefix: 'account',
                        viewModel: householdViewModel,
                        title: l.sharedAttributionNextStep,
                        retryReason: 'account_entry_manual_refresh',
                      ),
                      const SizedBox(height: 16),
                      HouseholdInviteCard(
                        surfaceKeyPrefix: 'account',
                        viewModel: householdViewModel,
                        inviteSource: 'account_entry',
                      ),
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
                                      SnackBar(
                                        content: Text(
                                          l.accountEntrySubmitMessage,
                                        ),
                                      ),
                                    );
                                  },
                            child: Text(
                              viewModel.isBusy
                                  ? l.processing
                                  : l.accountLoginConsent,
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
                                        trigger:
                                            AccountRuntimeTrigger.manualRetry,
                                      ),
                            child: Text(l.accountRetrySync),
                          ),
                          OutlinedButton(
                            key: const Key('account-revoke-button'),
                            onPressed: viewModel.isBusy || !viewModel.isSignedIn
                                ? null
                                : () => context
                                      .read<AccountViewModel>()
                                      .revokeConsent(),
                            child: Text(l.accountRevokeConsent),
                          ),
                          OutlinedButton(
                            key: const Key('account-delete-button'),
                            onPressed: viewModel.isBusy || !viewModel.isSignedIn
                                ? null
                                : () => context
                                      .read<AccountViewModel>()
                                      .deleteAccount(),
                            child: Text(l.accountDeleteAccount),
                          ),
                          OutlinedButton(
                            key: const Key('account-clear-button'),
                            onPressed: viewModel.isBusy
                                ? null
                                : () => context
                                      .read<AccountViewModel>()
                                      .clearSession(),
                            child: Text(l.accountLogout),
                          ),
                          OutlinedButton(
                            key: const Key('account-local-only-button'),
                            onPressed: viewModel.isBusy
                                ? null
                                : () => context
                                      .read<AccountViewModel>()
                                      .clearSession(revertToLocalOnly: true),
                            child: Text(l.accountBackToLocal),
                          ),
                          OutlinedButton(
                            key: const Key('account-close-button'),
                            onPressed: () => Navigator.of(context).maybePop(),
                            child: Text(l.close),
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

  String _headlineForPhase(
    AppLocalizations l,
    AccountSurfacePhase phase,
    AccountViewModel viewModel,
  ) {
    switch (phase) {
      case AccountSurfacePhase.loading:
        return l.accountEntryLoading;
      case AccountSurfacePhase.localOnly:
        return l.accountEntryPreparingProfile;
      case AccountSurfacePhase.signedOut:
        return l.accountEntryVisibleNotLoggedIn;
      case AccountSurfacePhase.signedInPendingSync:
        return l.accountSignedInPending(viewModel.maskedPhoneNumber);
      case AccountSurfacePhase.signedInSynced:
        return l.accountEntrySignedInSynced(viewModel.maskedPhoneNumber);
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
    AccountViewModel viewModel,
  ) {
    switch (phase) {
      case AccountSurfacePhase.loading:
        return 'loading';
      case AccountSurfacePhase.localOnly:
        return 'local-only';
      case AccountSurfacePhase.signedOut:
        return 'signed-out';
      case AccountSurfacePhase.signedInPendingSync:
        return l.accountSignedInPendingSyncStatus(
          viewModel.snapshot.pendingSyncCount,
        );
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
    final colors = context.appColors;
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

  Color _phaseForeground(AccountSurfacePhase phase) {
    final colors = context.appColors;
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
