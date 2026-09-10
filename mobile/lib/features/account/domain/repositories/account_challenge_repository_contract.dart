import 'package:mobile/features/account/domain/models/account_sign_in_challenge.dart';

abstract interface class AccountChallengeRepositoryContract {
  Future<AccountSignInChallenge> requestSignInChallenge({
    required String phoneNumber,
    required AccountChallengePurpose purpose,
  });

  Future<AccountSignInCompletion> completeSignIn({
    required String phoneNumber,
    required String verificationCode,
    required AccountSignInChallenge challenge,
  });
}
