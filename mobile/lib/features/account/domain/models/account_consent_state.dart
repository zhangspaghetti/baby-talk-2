enum AccountConsentState {
  localOnly,
  signedOut,
  acceptedPendingSync,
  revoked,
  deleted,
}

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
      case AccountConsentState.deleted:
        return 'deleted';
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
    case 'deleted':
      return AccountConsentState.deleted;
    default:
      throw FormatException('未知 account consentState: $value');
  }
}
