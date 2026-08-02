import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/router/account_entry_route_contract.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository_contract.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_sign_in_challenge.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/account/domain/repositories/account_challenge_repository_contract.dart';
import 'package:mobile/features/account/presentation/account_notifier.dart';
import 'package:mobile/features/auth/presentation/screens/auth_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:pinput/pinput.dart';

void main() {
  testWidgets('register mode exposes its verification-code action', (
    tester,
  ) async {
    final repository = _ChallengeAccountRepository();
    final notifier = AccountNotifier(
      repository: repository,
      challengeRepository: repository,
    );
    addTearDown(notifier.dispose);
    await _pumpAuth(tester, notifier: notifier, home: const AuthScreen());

    expect(find.text('密码登录'), findsNothing);
    expect(find.text('忘记密码'), findsNothing);
    expect(find.textContaining('重置密码'), findsNothing);
    await tester.tap(find.text('注册').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth-contact-field')), findsOneWidget);
    expect(find.text('发送注册验证码'), findsOneWidget);
    expect(find.text('密码登录'), findsNothing);
    expect(find.text('忘记密码'), findsNothing);
    expect(find.textContaining('重置密码'), findsNothing);
    expect(find.textContaining('设置注册密码'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('auth-contact-field')),
      '13800138000',
    );
    await tester.tap(find.text('发送注册验证码'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('模拟验证通过'));
    await tester.pumpAndSettle();
    expect(repository.requestedPurposes, [AccountChallengePurpose.register]);
    expect(find.text('设置密码'), findsNothing);
    expect(find.byType(Checkbox), findsOneWidget);
  });

  testWidgets('send creates one challenge and submit reuses it', (
    tester,
  ) async {
    final repository = _ChallengeAccountRepository();
    final notifier = AccountNotifier(
      repository: repository,
      challengeRepository: repository,
    );
    addTearDown(notifier.dispose);
    AccountEntryResult? returnedResult;

    await _pumpAuth(
      tester,
      notifier: notifier,
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () async {
              returnedResult = await Navigator.of(context)
                  .push<AccountEntryResult>(
                    MaterialPageRoute(
                      builder: (_) => const AuthScreen(
                        origin: AccountEntryOrigin.customSceneContinuation,
                      ),
                    ),
                  );
            },
            child: const Text('open auth'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open auth'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('auth-contact-field')),
      '13800138000',
    );
    await tester.tap(find.text('获取验证码'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('模拟验证通过'));
    await tester.pumpAndSettle();

    expect(repository.challengeCalls, 1);
    expect(find.byKey(const Key('auth-code-field')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('auth-code-field')), '246810');
    await tester.tap(find.byKey(const Key('auth-submit-button')));
    await tester.pumpAndSettle();

    expect(repository.challengeCalls, 1);
    expect(repository.completeCalls, 1);
    expect(repository.completedChallengeId, 'challenge_once');
    expect(returnedResult, AccountEntryResult.signedIn);
    expect(notifier.snapshot.session?.sessionId, 'session_mock');
    expect(
      notifier.snapshot.consentState,
      AccountConsentState.acceptedPendingSync,
    );
    expect(notifier.snapshot.lastSyncPhase, 'sync_idle_no_pending');
  });

  test(
    'challenge purpose, reuse, forced resend and expiry are explicit',
    () async {
      final repository = _ChallengeAccountRepository();
      final notifier = AccountNotifier(
        repository: repository,
        challengeRepository: repository,
      );
      addTearDown(notifier.dispose);
      notifier.updatePhoneNumber('13800138000');

      expect(
        await notifier.requestSignInChallenge(
          purpose: AccountChallengePurpose.login,
        ),
        isTrue,
      );
      expect(
        await notifier.requestSignInChallenge(
          purpose: AccountChallengePurpose.login,
        ),
        isTrue,
      );
      expect(repository.challengeCalls, 1);
      expect(repository.requestedPurposes, [AccountChallengePurpose.login]);

      expect(
        await notifier.requestSignInChallenge(
          purpose: AccountChallengePurpose.login,
          forceRefresh: true,
        ),
        isTrue,
      );
      expect(repository.challengeCalls, 2);
      expect(notifier.signInChallenge?.challengeId, 'challenge_2');

      repository.issueExpiredChallenge = true;
      expect(
        await notifier.requestSignInChallenge(
          purpose: AccountChallengePurpose.register,
          forceRefresh: true,
        ),
        isTrue,
      );
      notifier.updateVerificationCode('246810');
      expect(
        await notifier.submitChallengeSignIn(
          purpose: AccountChallengePurpose.register,
        ),
        isFalse,
      );
      expect(repository.completeCalls, 0);
      expect(notifier.submissionMessage, '验证码已过期，请重新发送。');
    },
  );

  test('async challenge errors expose stable redacted copy', () async {
    final repository = _ChallengeAccountRepository()
      ..requestError = StateError(
        'phone=13800138000 token=secret verificationCode=246810',
      );
    final notifier = AccountNotifier(
      repository: repository,
      challengeRepository: repository,
    );
    addTearDown(notifier.dispose);
    notifier.updatePhoneNumber('13800138000');

    expect(
      await notifier.requestSignInChallenge(
        purpose: AccountChallengePurpose.login,
      ),
      isFalse,
    );
    expect(notifier.submissionMessage, '发送验证码失败，请稍后重试。');
    expect(notifier.submissionMessage, isNot(contains('13800138000')));
    expect(notifier.submissionMessage, isNot(contains('secret')));
  });

  test('busy challenge request rejects concurrent duplicate', () async {
    final repository = _ChallengeAccountRepository();
    final gate = Completer<AccountSignInChallenge>();
    var calls = 0;
    repository.requestOverride = ({required phoneNumber, required purpose}) {
      calls += 1;
      return gate.future;
    };
    final notifier = AccountNotifier(
      repository: repository,
      challengeRepository: repository,
    );
    addTearDown(notifier.dispose);
    notifier.updatePhoneNumber('13800138000');

    final first = notifier.requestSignInChallenge(
      purpose: AccountChallengePurpose.login,
    );
    expect(
      await notifier.requestSignInChallenge(
        purpose: AccountChallengePurpose.login,
      ),
      isFalse,
    );
    expect(calls, 1);
    gate.complete(
      AccountSignInChallenge(
        challengeId: 'challenge_concurrent',
        maskedPhoneNumber: '138****8000',
        codeLength: 6,
        purpose: AccountChallengePurpose.login,
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      ),
    );
    expect(await first, isTrue);
    expect(calls, 1);
  });

  test(
    'clearing mode while request is in flight ignores stale result',
    () async {
      final repository = _ChallengeAccountRepository();
      final gate = Completer<AccountSignInChallenge>();
      repository.requestOverride = ({required phoneNumber, required purpose}) =>
          gate.future;
      final notifier = AccountNotifier(
        repository: repository,
        challengeRepository: repository,
      );
      addTearDown(notifier.dispose);
      notifier.updatePhoneNumber('13800138000');

      final pending = notifier.requestSignInChallenge(
        purpose: AccountChallengePurpose.login,
      );
      notifier.clearSignInChallenge();
      gate.complete(
        AccountSignInChallenge(
          challengeId: 'stale_login_challenge',
          maskedPhoneNumber: '138****8000',
          codeLength: 6,
          purpose: AccountChallengePurpose.login,
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
        ),
      );

      expect(await pending, isFalse);
      expect(notifier.hasSignInChallenge, isFalse);
      expect(notifier.submissionMessage, isNot(contains('验证码已发送')));
    },
  );

  test('double request has one transport call and one final message', () async {
    final repository = _ChallengeAccountRepository();
    final gate = Completer<AccountSignInChallenge>();
    var calls = 0;
    repository.requestOverride = ({required phoneNumber, required purpose}) {
      calls += 1;
      return gate.future;
    };
    final notifier = AccountNotifier(
      repository: repository,
      challengeRepository: repository,
    );
    addTearDown(notifier.dispose);
    notifier.updatePhoneNumber('13800138000');

    final first = notifier.requestSignInChallenge(
      purpose: AccountChallengePurpose.login,
    );
    final second = notifier.requestSignInChallenge(
      purpose: AccountChallengePurpose.login,
    );
    expect(await second, isFalse);
    gate.complete(
      AccountSignInChallenge(
        challengeId: 'single_challenge',
        maskedPhoneNumber: '138****8000',
        codeLength: 6,
        purpose: AccountChallengePurpose.login,
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      ),
    );
    expect(await first, isTrue);
    expect(calls, 1);
    expect(notifier.submissionMessage, '验证码已发送至 138****8000');
  });

  test(
    'challenge invalidation does not clear a global operation busy state',
    () async {
      final repository = _ChallengeAccountRepository();
      final refreshGate = Completer<AccountLocalSnapshot>();
      repository.refreshOverride =
          ({required trigger, seedSnapshot, forceBootstrap = false}) =>
              refreshGate.future;
      final notifier = AccountNotifier(
        repository: repository,
        challengeRepository: repository,
      );
      addTearDown(notifier.dispose);

      final refresh = notifier.refreshRuntimeState(
        trigger: AccountRuntimeTrigger.manualRetry,
      );
      await Future<void>.delayed(Duration.zero);
      expect(notifier.isBusy, isTrue);

      notifier.updatePhoneNumber('13800138000');
      notifier.clearSignInChallenge();

      expect(notifier.isBusy, isTrue);
      refreshGate.complete(AccountLocalSnapshot.signedOut);
      await refresh;
      expect(notifier.isBusy, isFalse);
    },
  );

  test(
    'stale challenge finally does not clear a newer challenge busy state',
    () async {
      final repository = _ChallengeAccountRepository();
      final firstGate = Completer<AccountSignInChallenge>();
      final secondGate = Completer<AccountSignInChallenge>();
      var calls = 0;
      repository.requestOverride = ({required phoneNumber, required purpose}) {
        calls += 1;
        return calls == 1 ? firstGate.future : secondGate.future;
      };
      final notifier = AccountNotifier(
        repository: repository,
        challengeRepository: repository,
      );
      addTearDown(notifier.dispose);

      notifier.updatePhoneNumber('13800138000');
      final first = notifier.requestSignInChallenge(
        purpose: AccountChallengePurpose.login,
      );
      notifier.updatePhoneNumber('13900139000');
      final second = notifier.requestSignInChallenge(
        purpose: AccountChallengePurpose.login,
      );

      firstGate.complete(
        _challenge(
          id: 'stale_challenge',
          purpose: AccountChallengePurpose.login,
        ),
      );
      expect(await first, isFalse);
      expect(notifier.isBusy, isTrue);

      secondGate.complete(
        _challenge(
          id: 'current_challenge',
          purpose: AccountChallengePurpose.login,
        ),
      );
      expect(await second, isTrue);
      expect(notifier.isBusy, isFalse);
      expect(notifier.signInChallenge?.challengeId, 'current_challenge');
    },
  );

  test('stale snapshot load cannot complete an invalidated sign in', () async {
    final repository = _ChallengeAccountRepository();
    final loadGate = Completer<AccountLocalSnapshot>();
    repository.loadOverride = () => loadGate.future;
    final notifier = AccountNotifier(
      repository: repository,
      challengeRepository: repository,
    );
    addTearDown(notifier.dispose);
    notifier.updatePhoneNumber('13800138000');
    expect(
      await notifier.requestSignInChallenge(
        purpose: AccountChallengePurpose.login,
      ),
      isTrue,
    );
    notifier.updateVerificationCode('246810');

    final pending = notifier.submitChallengeSignIn(
      purpose: AccountChallengePurpose.login,
    );
    await Future<void>.delayed(Duration.zero);
    notifier.clearSignInChallenge();
    loadGate.complete(_signedInSnapshot());

    expect(await pending, isFalse);
    expect(notifier.snapshot.session, isNull);
    expect(notifier.hasSignInChallenge, isFalse);
  });

  testWidgets(
    'captcha submit disables modal actions and double tap sends once',
    (tester) async {
      final repository = _ChallengeAccountRepository();
      final requestGate = Completer<AccountSignInChallenge>();
      var calls = 0;
      repository.requestOverride = ({required phoneNumber, required purpose}) {
        calls += 1;
        return requestGate.future;
      };
      final notifier = AccountNotifier(
        repository: repository,
        challengeRepository: repository,
      );
      addTearDown(notifier.dispose);
      await _pumpAuth(tester, notifier: notifier, home: const AuthScreen());
      await tester.enterText(
        find.byKey(const Key('auth-contact-field')),
        '13800138000',
      );
      await tester.tap(find.text('获取验证码'));
      await tester.pumpAndSettle();

      final passButton = find.text('模拟验证通过');
      await tester.tap(passButton);
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '模拟验证通过'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '取消'))
            .onPressed,
        isNull,
      );
      await tester.tap(passButton, warnIfMissed: false);
      await tester.pump();
      expect(calls, 1);

      requestGate.complete(
        _challenge(
          id: 'captcha_single_request',
          purpose: AccountChallengePurpose.login,
        ),
      );
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(find.text('发送验证码失败，请稍后重试。'), findsNothing);
      expect(notifier.signInChallenge?.challengeId, 'captcha_single_request');
    },
  );

  testWidgets(
    'rejected verification with old session stays on continuation and keeps challenge',
    (tester) async {
      final repository = _ChallengeAccountRepository()
        ..completionOverride = const AccountSignInCompletion.rejected(
          userMessage: '验证码错误或已过期，请重新获取。',
        );
      final notifier = AccountNotifier(
        repository: repository,
        challengeRepository: repository,
      );
      addTearDown(notifier.dispose);
      AccountEntryResult? returnedResult;

      await _pumpAuth(
        tester,
        notifier: notifier,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                returnedResult = await Navigator.of(context)
                    .push<AccountEntryResult>(
                      MaterialPageRoute(
                        builder: (_) => const AuthScreen(
                          origin: AccountEntryOrigin.customSceneContinuation,
                        ),
                      ),
                    );
              },
              child: const Text('open rejected auth'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open rejected auth'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('auth-contact-field')),
        '13800138000',
      );
      await tester.tap(find.text('获取验证码'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('模拟验证通过'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('auth-code-field')),
        '000000',
      );
      await tester.tap(find.byKey(const Key('auth-submit-button')));
      await tester.pump();

      expect(returnedResult, isNull);
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(notifier.hasSignInChallenge, isTrue);
      expect(find.text('验证码错误或已过期，请重新获取。'), findsOneWidget);
    },
  );

  testWidgets(
    'mode switch clears challenge and successful resend restarts timer',
    (tester) async {
      final repository = _ChallengeAccountRepository();
      final notifier = AccountNotifier(
        repository: repository,
        challengeRepository: repository,
      );
      addTearDown(notifier.dispose);
      await _pumpAuth(tester, notifier: notifier, home: const AuthScreen());
      await tester.enterText(
        find.byKey(const Key('auth-contact-field')),
        '13800138000',
      );
      await tester.tap(find.text('获取验证码'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('模拟验证通过'));
      await tester.pumpAndSettle();

      expect(repository.challengeCalls, 1);
      expect(find.text('59s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 59));
      await tester.pump();
      expect(find.text('重新发送'), findsOneWidget);
      await tester.tap(find.text('重新发送'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('模拟验证通过'));
      await tester.pumpAndSettle();

      expect(repository.challengeCalls, 2);
      expect(find.text('59s'), findsOneWidget);

      await tester.tap(find.text('注册').first);
      await tester.pumpAndSettle();
      expect(notifier.hasSignInChallenge, isFalse);
      expect(find.text('发送注册验证码'), findsOneWidget);
    },
  );

  testWidgets('editing phone clears challenge and returns to send-code UI', (
    tester,
  ) async {
    final repository = _ChallengeAccountRepository();
    final notifier = AccountNotifier(
      repository: repository,
      challengeRepository: repository,
    );
    addTearDown(notifier.dispose);
    await _pumpAuth(tester, notifier: notifier, home: const AuthScreen());
    await tester.enterText(
      find.byKey(const Key('auth-contact-field')),
      '13800138000',
    );
    await tester.tap(find.text('获取验证码'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('模拟验证通过'));
    await tester.pumpAndSettle();
    expect(notifier.hasSignInChallenge, isTrue);
    expect(find.byKey(const Key('auth-code-field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('auth-contact-field')),
      '13900139000',
    );
    await tester.pump();

    expect(notifier.hasSignInChallenge, isFalse);
    expect(find.byKey(const Key('auth-code-field')), findsNothing);
    expect(find.text('获取验证码'), findsOneWidget);
    expect(find.text('59s'), findsNothing);
    expect(find.textContaining('验证码已发送至'), findsNothing);
  });

  testWidgets(
    'editing a challenged phone clears pinput while same phone preserves it',
    (tester) async {
      final repository = _ChallengeAccountRepository();
      final notifier = AccountNotifier(
        repository: repository,
        challengeRepository: repository,
      );
      addTearDown(notifier.dispose);
      await _pumpAuth(tester, notifier: notifier, home: const AuthScreen());
      await tester.enterText(
        find.byKey(const Key('auth-contact-field')),
        '13800138000',
      );
      await tester.tap(find.text('获取验证码'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('模拟验证通过'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('auth-code-field')),
        '246810',
      );
      final codeController = tester
          .widget<Pinput>(find.byKey(const Key('auth-code-field')))
          .controller!;

      await tester.enterText(
        find.byKey(const Key('auth-contact-field')),
        '13800138000',
      );
      await tester.pump();
      expect(notifier.hasSignInChallenge, isTrue);
      expect(codeController.text, '246810');

      await tester.enterText(
        find.byKey(const Key('auth-contact-field')),
        '13900139000',
      );
      await tester.pump();

      expect(notifier.hasSignInChallenge, isFalse);
      expect(codeController.text, isEmpty);
      expect(find.byKey(const Key('auth-code-field')), findsNothing);
      expect(find.text('获取验证码'), findsOneWidget);
      expect(find.text('59s'), findsNothing);
      expect(find.textContaining('验证码已发送至'), findsNothing);
    },
  );
}

Future<void> _pumpAuth(
  WidgetTester tester, {
  required AccountNotifier notifier,
  required Widget home,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 2200);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [accountNotifierProvider.overrideWith((ref) => notifier)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _ChallengeAccountRepository
    implements AccountRepositoryContract, AccountChallengeRepositoryContract {
  int challengeCalls = 0;
  int completeCalls = 0;
  String? completedChallengeId;
  final List<AccountChallengePurpose> requestedPurposes = [];
  bool issueExpiredChallenge = false;
  Object? requestError;
  AccountSignInCompletion? completionOverride;
  AccountLocalSnapshot currentSnapshot = AccountLocalSnapshot.signedOut;
  Future<AccountSignInChallenge> Function({
    required String phoneNumber,
    required AccountChallengePurpose purpose,
  })?
  requestOverride;
  Future<AccountLocalSnapshot> Function()? loadOverride;
  Future<AccountLocalSnapshot> Function({
    required AccountRuntimeTrigger trigger,
    AccountLocalSnapshot? seedSnapshot,
    bool forceBootstrap,
  })?
  refreshOverride;

  @override
  Future<AccountSignInChallenge> requestSignInChallenge({
    required String phoneNumber,
    required AccountChallengePurpose purpose,
  }) async {
    final override = requestOverride;
    if (override != null) {
      return override(phoneNumber: phoneNumber, purpose: purpose);
    }
    final error = requestError;
    if (error != null) {
      throw error;
    }
    challengeCalls += 1;
    requestedPurposes.add(purpose);
    return AccountSignInChallenge(
      challengeId: challengeCalls == 1
          ? 'challenge_once'
          : 'challenge_$challengeCalls',
      maskedPhoneNumber: '138****8000',
      codeLength: 6,
      purpose: purpose,
      expiresAt: issueExpiredChallenge
          ? DateTime.utc(2020)
          : DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );
  }

  @override
  Future<AccountSignInCompletion> completeSignIn({
    required String phoneNumber,
    required String verificationCode,
    required AccountSignInChallenge challenge,
  }) async {
    completeCalls += 1;
    completedChallengeId = challenge.challengeId;
    final completion =
        completionOverride ?? const AccountSignInCompletion.authenticated();
    if (completion.isAuthenticated) {
      currentSnapshot = _signedInSnapshot();
    }
    return completion;
  }

  @override
  Future<AccountLocalSnapshot> loadSnapshot() async {
    final override = loadOverride;
    return override == null ? currentSnapshot : override();
  }

  @override
  Future<AccountLocalSnapshot> signIn({
    required String phoneNumber,
    required String verificationCode,
  }) async => throw StateError('legacy signIn must not be used');

  @override
  Future<AccountLocalSnapshot> refreshRuntimeState({
    required AccountRuntimeTrigger trigger,
    AccountLocalSnapshot? seedSnapshot,
    bool forceBootstrap = false,
  }) async {
    final override = refreshOverride;
    if (override != null) {
      return override(
        trigger: trigger,
        seedSnapshot: seedSnapshot,
        forceBootstrap: forceBootstrap,
      );
    }
    return seedSnapshot ?? AccountLocalSnapshot.signedOut;
  }

  @override
  Future<AccountLocalSnapshot> clearPlaceholderSession({
    bool revertToLocalOnly = false,
  }) async => AccountLocalSnapshot.signedOut;

  @override
  Future<AccountLocalSnapshot> revokeConsent({
    String reason = 'user_requested',
  }) async => AccountLocalSnapshot.signedOut;

  @override
  Future<AccountLocalSnapshot> deleteAccount({
    String reason = 'forget_me',
  }) async => AccountLocalSnapshot.signedOut;

  @override
  Future<void> close() async {}
}

AccountSignInChallenge _challenge({
  required String id,
  required AccountChallengePurpose purpose,
}) {
  return AccountSignInChallenge(
    challengeId: id,
    maskedPhoneNumber: '138****8000',
    codeLength: 6,
    purpose: purpose,
    expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
  );
}

AccountLocalSnapshot _signedInSnapshot() {
  return AccountLocalSnapshot(
    consentState: AccountConsentState.acceptedPendingSync,
    session: AccountSession(
      accountId: 'account_mock',
      sessionId: 'session_mock',
      maskedPhoneNumber: '138****8000',
      createdAt: DateTime.utc(2026, 8, 2, 8),
    ),
    pendingSyncCount: 0,
    syncedCount: 0,
    failedCount: 0,
    lastSyncPhase: 'sync_idle_no_pending',
    lastSyncAt: DateTime.utc(2026, 8, 2, 8, 1),
  );
}
