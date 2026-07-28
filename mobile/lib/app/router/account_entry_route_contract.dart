enum AccountEntryResult { signedIn }

enum AccountEntryOrigin {
  settings,
  onboardingContinuation,
  customSceneContinuation,
}

AccountEntryOrigin accountEntryOriginFromRouteExtra(Object? value) {
  return value is AccountEntryOrigin ? value : AccountEntryOrigin.settings;
}
