import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/local_data_lifecycle/local_sensitive_data_clearance.dart';
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

      final signedIn = await notifier.submitSignIn(acceptedConsent: true);

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

  test('account session exit operations cancel the native reminder', () async {
    final operations = <String, Future<void> Function()>{
      'logout': () async {
        final repository = _ContractOnlyAccountRepository(
          currentSnapshot: _signedInSnapshot(),
        );
        var cancellations = 0;
        final notifier = AccountNotifier(
          repository: repository,
          onAccountSessionEnded: () async => cancellations += 1,
        );
        addTearDown(notifier.dispose);
        await notifier.reload();
        await notifier.logout();
        expect(cancellations, 1);
      },
      'local-only': () async {
        final repository = _ContractOnlyAccountRepository(
          currentSnapshot: _signedInSnapshot(),
        );
        var cancellations = 0;
        final notifier = AccountNotifier(
          repository: repository,
          onAccountSessionEnded: () async => cancellations += 1,
        );
        addTearDown(notifier.dispose);
        await notifier.reload();
        await notifier.clearSession(revertToLocalOnly: true);
        expect(cancellations, 1);
      },
      'revoke': () async {
        final repository = _ContractOnlyAccountRepository(
          currentSnapshot: _signedInSnapshot(),
        );
        var cancellations = 0;
        final notifier = AccountNotifier(
          repository: repository,
          onAccountSessionEnded: () async => cancellations += 1,
        );
        addTearDown(notifier.dispose);
        await notifier.reload();
        await notifier.revokeConsent();
        expect(cancellations, 1);
      },
      'delete': () async {
        final repository = _ContractOnlyAccountRepository(
          currentSnapshot: _signedInSnapshot(),
        );
        var cancellations = 0;
        final notifier = AccountNotifier(
          repository: repository,
          onAccountSessionEnded: () async => cancellations += 1,
        );
        addTearDown(notifier.dispose);
        await notifier.reload();
        await notifier.deleteAccount();
        expect(cancellations, 1);
      },
    };

    for (final operation in operations.values) {
      await operation();
    }
  });

  test('device-local erase cancels reminder before local clearance', () async {
    final repository = _ContractOnlyAccountRepository(
      currentSnapshot: _signedInSnapshot(),
    );
    var cancellations = 0;
    final notifier = AccountNotifier(
      repository: repository,
      onAccountSessionEnded: () async => cancellations += 1,
      localDataClearanceRunner:
          ({
            required trigger,
            required correlationId,
            required requestedAt,
          }) async => _completedClearanceReport(
            trigger: trigger,
            correlationId: correlationId,
            requestedAt: requestedAt,
          ),
    );
    addTearDown(notifier.dispose);

    await notifier.reload();
    await notifier.clearRetainedLocalData();

    expect(cancellations, 1);
    expect(notifier.submissionMessage, '本机保留数据已清除；账号不会被删除。');
  });

  test('reminder cancellation failure does not block logout', () async {
    final repository = _ContractOnlyAccountRepository(
      currentSnapshot: _signedInSnapshot(),
    );
    final notifier = AccountNotifier(
      repository: repository,
      onAccountSessionEnded: () async {
        throw StateError('native reminder unavailable');
      },
    );
    addTearDown(notifier.dispose);

    await notifier.reload();
    expect(await notifier.logout(), isTrue);
    expect(notifier.isSignedOut, isTrue);
  });
}

AccountLocalSnapshot _signedInSnapshot() {
  return AccountLocalSnapshot(
    consentState: AccountConsentState.acceptedPendingSync,
    session: AccountSession(
      accountId: 'account-contract',
      sessionId: 'session-contract',
      maskedPhoneNumber: '138****8000',
      createdAt: DateTime.utc(2026, 5, 18, 12),
      accessToken: 'access-contract',
      refreshToken: 'refresh-contract',
      accessTokenExpiresAt: DateTime.utc(2026, 5, 18, 12, 15),
      refreshTokenExpiresAt: DateTime.utc(2026, 5, 25, 12),
    ),
  );
}

LocalSensitiveDataClearanceReport _completedClearanceReport({
  required LocalSensitiveDataClearanceTrigger trigger,
  required String correlationId,
  required DateTime requestedAt,
}) {
  return LocalSensitiveDataClearanceReport(
    correlationId: correlationId,
    trigger: trigger,
    requestedAt: requestedAt,
    startedAt: requestedAt,
    finishedAt: requestedAt,
    overallStatus: LocalSensitiveDataClearanceOverallStatus.completed,
    authorizationEvidence: LocalSensitiveDataAuthorizationEvidence.from(
      const ReportOnlyAuthorization(reason: 'contract test'),
    ),
    results: const <LocalSensitiveDataTargetResult>[],
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
