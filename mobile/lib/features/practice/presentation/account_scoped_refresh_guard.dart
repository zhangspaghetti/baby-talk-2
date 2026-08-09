class AccountScopedRefreshToken {
  const AccountScopedRefreshToken._({
    required this.accountEpoch,
    required this.refreshGeneration,
  });

  final int accountEpoch;
  final int refreshGeneration;
}

/// Invalidates asynchronous projection work when its in-memory owner changes.
/// Account identities are never persisted or logged by this guard.
class AccountScopedRefreshGuard {
  String? _accountContext;
  int _accountEpoch = 0;
  int _refreshGeneration = 0;

  AccountScopedRefreshToken beginRefresh() {
    return AccountScopedRefreshToken._(
      accountEpoch: _accountEpoch,
      refreshGeneration: ++_refreshGeneration,
    );
  }

  bool owns(AccountScopedRefreshToken token) {
    return token.accountEpoch == _accountEpoch &&
        token.refreshGeneration == _refreshGeneration;
  }

  bool bindAccountContext(String? accountContext) {
    final normalized = accountContext?.trim();
    final nextContext = normalized == null || normalized.isEmpty
        ? null
        : normalized;
    if (_accountContext == nextContext) {
      return false;
    }
    _accountContext = nextContext;
    _accountEpoch += 1;
    _refreshGeneration += 1;
    return true;
  }

  void invalidate({bool clearAccountContext = false}) {
    if (clearAccountContext) {
      _accountContext = null;
    }
    _accountEpoch += 1;
    _refreshGeneration += 1;
  }
}
