import 'package:mobile/features/account/presentation/auth_continuation_coordinator.dart';

enum AccountEntryPostSignInAction { showSuccessToast, returnSignedInResult }

Future<AccountEntryPostSignInAction> resolveAccountEntryPostSignInAction(
  AuthContinuationCoordinator coordinator,
) async {
  final pending = await coordinator.readPending();
  return pending == null
      ? AccountEntryPostSignInAction.showSuccessToast
      : AccountEntryPostSignInAction.returnSignedInResult;
}
