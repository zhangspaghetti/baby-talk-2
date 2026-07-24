import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/account/domain/models/auth_continuation.dart';
import 'package:mobile/features/account/presentation/account_entry_post_sign_in.dart';

void main() {
  test('pending loader returns signed-in result action once', () async {
    var loads = 0;
    final pending = AuthContinuation(
      schemaVersion: 1,
      intent: AuthContinuationIntent.saveOnboardingMemory,
      correlationId: 'account_entry_post_sign_in',
      createdAt: DateTime.utc(2026, 7, 23, 12),
      expiresAt: DateTime.utc(2026, 7, 23, 12, 15),
    );

    expect(
      await resolveAccountEntryPostSignInAction(() async {
        loads += 1;
        return pending;
      }),
      AccountEntryPostSignInAction.returnSignedInResult,
    );
    expect(loads, 1);
  });

  test('empty loader keeps account entry open for success toast', () async {
    expect(
      await resolveAccountEntryPostSignInAction(() async => null),
      AccountEntryPostSignInAction.showSuccessToast,
    );
  });
}
