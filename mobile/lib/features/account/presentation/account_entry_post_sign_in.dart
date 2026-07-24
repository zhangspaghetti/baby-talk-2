import 'package:mobile/features/account/domain/models/auth_continuation.dart';

enum AccountEntryPostSignInAction { showSuccessToast, returnSignedInResult }

typedef AuthContinuationLoader = Future<AuthContinuation?> Function();

Future<AccountEntryPostSignInAction> resolveAccountEntryPostSignInAction(
  AuthContinuationLoader loadPending,
) async {
  final pending = await loadPending();
  return pending == null
      ? AccountEntryPostSignInAction.showSuccessToast
      : AccountEntryPostSignInAction.returnSignedInResult;
}
