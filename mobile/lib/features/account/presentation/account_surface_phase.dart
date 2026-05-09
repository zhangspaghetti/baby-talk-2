import 'package:mobile/features/account/presentation/account_view_model.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';

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

/// Resolves the current account surface phase from the view model state.
///
/// [onboardingSnapshot] is optional. When provided (e.g. from
/// `AccountStatusCard`), the `localOnly` phase can be reached when
/// `viewModel.isLocalOnly` is true. When omitted (e.g. from
/// `AccountEntryScreen`), the function falls through to `signedOut`.
AccountSurfacePhase resolveAccountPhase(
  AccountViewModel viewModel, {
  OnboardingSnapshot? onboardingSnapshot,
}) {
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
  if (viewModel.isLocalOnly && onboardingSnapshot != null) {
    return AccountSurfacePhase.localOnly;
  }
  return AccountSurfacePhase.signedOut;
}
