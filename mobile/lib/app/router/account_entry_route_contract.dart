enum AccountEntryResult { signedIn }

enum AccountEntryOrigin {
  settings,
  onboardingContinuation,
  customSceneContinuation;

  static AccountEntryOrigin fromRouteExtra(Object? value) {
    return value is AccountEntryOrigin ? value : AccountEntryOrigin.settings;
  }
}

AccountEntryOrigin accountEntryOriginFromRouteExtra(Object? value) {
  return AccountEntryOrigin.fromRouteExtra(value);
}
