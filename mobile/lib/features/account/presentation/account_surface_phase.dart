import 'package:mobile/features/account/presentation/account_notifier.dart';
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

/// Resolves the current account surface phase from the notifier state.
///
/// Accepts [AccountNotifier] which mirrors the [AccountViewModel] API.
///
/// [onboardingSnapshot] is optional. When provided (e.g. from
/// `AccountStatusCard`), the `localOnly` phase can be reached when
/// `notifier.isLocalOnly` is true. When omitted (e.g. from
/// `AccountEntryScreen`), the function falls through to `signedOut`.
AccountSurfacePhase resolveAccountPhase(
  AccountNotifier notifier, {
  OnboardingSnapshot? onboardingSnapshot,
}) {
  if (notifier.isLoading && !notifier.hasLoaded) {
    return AccountSurfacePhase.loading;
  }
  if (notifier.loadErrorMessage != null) {
    return AccountSurfacePhase.error;
  }
  if (notifier.isDeleted) {
    return AccountSurfacePhase.deleted;
  }
  if (notifier.isRevoked) {
    return AccountSurfacePhase.revoked;
  }
  if (notifier.isVersionBlocked) {
    return AccountSurfacePhase.versionBlocked;
  }
  if (notifier.isSignedIn && notifier.hasSyncFailure) {
    return AccountSurfacePhase.signedInFailed;
  }
  if (notifier.isSignedIn && notifier.hasPendingSync) {
    return AccountSurfacePhase.signedInPendingSync;
  }
  if (notifier.isSignedIn) {
    return AccountSurfacePhase.signedInSynced;
  }
  if (notifier.isSignedOut) {
    return AccountSurfacePhase.signedOut;
  }
  if (notifier.isLocalOnly && onboardingSnapshot != null) {
    return AccountSurfacePhase.localOnly;
  }
  return AccountSurfacePhase.signedOut;
}
