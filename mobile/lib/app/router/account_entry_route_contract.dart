enum AccountEntryResult { signedIn }

enum AccountEntryOrigin { settings, onboardingContinuation }

AccountEntryOrigin accountEntryOriginFromRouteExtra(Object? value) {
  return value is AccountEntryOrigin ? value : AccountEntryOrigin.settings;
}
