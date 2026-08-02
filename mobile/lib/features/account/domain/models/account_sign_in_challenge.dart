enum AccountChallengePurpose { login, register }

class AccountSignInChallenge {
  const AccountSignInChallenge({
    required this.challengeId,
    required this.maskedPhoneNumber,
    required this.codeLength,
    required this.purpose,
    required this.expiresAt,
  });

  final String challengeId;
  final String maskedPhoneNumber;
  final int codeLength;
  final AccountChallengePurpose purpose;
  final DateTime expiresAt;

  bool get isExpired => !expiresAt.isAfter(DateTime.now().toUtc());
}

enum AccountSignInCompletionStatus { authenticated, rejected }

class AccountSignInCompletion {
  const AccountSignInCompletion._({required this.status, this.userMessage});

  const AccountSignInCompletion.authenticated()
    : this._(status: AccountSignInCompletionStatus.authenticated);

  const AccountSignInCompletion.rejected({required String userMessage})
    : this._(
        status: AccountSignInCompletionStatus.rejected,
        userMessage: userMessage,
      );

  final AccountSignInCompletionStatus status;
  final String? userMessage;

  bool get isAuthenticated =>
      status == AccountSignInCompletionStatus.authenticated;
}
