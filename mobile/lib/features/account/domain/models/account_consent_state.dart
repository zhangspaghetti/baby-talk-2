enum AccountConsentState { localOnly, signedOut, acceptedPendingSync, revoked }

extension AccountConsentStateWire on AccountConsentState {
  String get wireValue {
    switch (this) {
      case AccountConsentState.localOnly:
        return 'local_only';
      case AccountConsentState.signedOut:
        return 'signed_out';
      case AccountConsentState.acceptedPendingSync:
        return 'accepted_pending_sync';
      case AccountConsentState.revoked:
        return 'revoked';
    }
  }
}

AccountConsentState parseAccountConsentState(String value) {
  switch (value.trim()) {
    case 'local_only':
      return AccountConsentState.localOnly;
    case 'signed_out':
      return AccountConsentState.signedOut;
    case 'accepted_pending_sync':
      return AccountConsentState.acceptedPendingSync;
    case 'revoked':
      return AccountConsentState.revoked;
    default:
      throw FormatException('未知 account consentState: $value');
  }
}
