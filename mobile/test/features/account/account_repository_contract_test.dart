import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository_contract.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/account/presentation/account_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'REFACTOR-009: AccountNotifier only requires the account repository contract',
    () async {
      final repository = _ContractOnlyAccountRepository(
        currentSnapshot: AccountLocalSnapshot.signedOut,
      );
      final notifier = AccountNotifier(repository: repository);
      addTearDown(notifier.dispose);

      await notifier.reload();

      expect(repository.loadCalls, 1);
      expect(notifier.snapshot.consentState, AccountConsentState.signedOut);

      notifier.updatePhoneNumber('138 0013 8000');
      notifier.updateVerificationCode('123456');

      final signedIn = await notifier.submitSignIn();

      expect(signedIn, isTrue);
      expect(repository.signInCalls, 1);
      expect(notifier.isSignedIn, isTrue);
      expect(notifier.snapshot.lastSyncPhase, 'contract_sign_in');

      await notifier.refreshRuntimeState(
        trigger: AccountRuntimeTrigger.manualRetry,
      );

      expect(repository.lastRuntimeTrigger, AccountRuntimeTrigger.manualRetry);
    },
  );
}

class _ContractOnlyAccountRepository implements AccountRepositoryContract {
  _ContractOnlyAccountRepository({required this.currentSnapshot});

  AccountLocalSnapshot currentSnapshot;
  int loadCalls = 0;
  int signInCalls = 0;
  AccountRuntimeTrigger? lastRuntimeTrigger;

  @override
  Future<AccountLocalSnapshot> loadSnapshot() async {
    loadCalls += 1;
    return currentSnapshot;
  }

  @override
  Future<AccountLocalSnapshot> signIn({
    required String phoneNumber,
    required String verificationCode,
  }) async {
    signInCalls += 1;
    currentSnapshot = AccountLocalSnapshot(
      consentState: AccountConsentState.acceptedPendingSync,
      session: AccountSession(
        accountId: 'contract-account',
        sessionId: 'contract-session',
        maskedPhoneNumber: '138****8000',
        createdAt: DateTime.utc(2026, 5, 18, 12),
        accessToken: 'access-live',
        refreshToken: 'refresh-live',
        accessTokenExpiresAt: DateTime.utc(2026, 5, 18, 12, 15),
        refreshTokenExpiresAt: DateTime.utc(2026, 5, 25, 12),
      ),
      lastSyncPhase: 'contract_sign_in',
      lastSyncAt: DateTime.utc(2026, 5, 18, 12),
    );
    return currentSnapshot;
  }

  @override
  Future<AccountLocalSnapshot> refreshRuntimeState({
    required AccountRuntimeTrigger trigger,
    AccountLocalSnapshot? seedSnapshot,
    bool forceBootstrap = false,
  }) async {
    lastRuntimeTrigger = trigger;
    return seedSnapshot ?? currentSnapshot;
  }

  @override
  Future<AccountLocalSnapshot> clearPlaceholderSession({
    bool revertToLocalOnly = false,
  }) async {
    currentSnapshot = revertToLocalOnly
        ? AccountLocalSnapshot.localOnly
        : AccountLocalSnapshot.signedOut;
    return currentSnapshot;
  }

  @override
  Future<AccountLocalSnapshot> revokeConsent({
    String reason = 'user_requested',
  }) async {
    currentSnapshot = AccountLocalSnapshot(
      consentState: AccountConsentState.revoked,
      lastSyncPhase: 'contract_revoked',
    );
    return currentSnapshot;
  }

  @override
  Future<AccountLocalSnapshot> deleteAccount({
    String reason = 'forget_me',
  }) async {
    currentSnapshot = AccountLocalSnapshot(
      consentState: AccountConsentState.deleted,
      lastSyncPhase: 'contract_deleted',
    );
    return currentSnapshot;
  }

  @override
  Future<void> close() async {}
}
