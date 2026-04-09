import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/account/presentation/account_view_model.dart';
import 'package:mobile/features/account/presentation/screens/account_entry_screen.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('home 账号卡片暴露真实入口，并能打开账号页面', (WidgetTester tester) async {
    final repository = FakeAccountRepository(
      currentSnapshot: AccountLocalSnapshot.localOnly,
    );

    await _pumpStatusCard(
      tester,
      repository: repository,
      onboardingSnapshot: _buildSnapshot(),
    );

    expect(find.byKey(const Key('home-account-card')), findsOneWidget);
    expect(find.byKey(const Key('home-account-open-entry')), findsOneWidget);
    expect(find.text('仍是 local-only 档案模式'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-account-open-entry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account-entry-surface')), findsOneWidget);
    expect(find.byKey(const Key('account-status-local-only')), findsOneWidget);
    expect(find.text('先保留同意前本地档案'), findsOneWidget);
  });

  testWidgets('非法手机号和验证码会在 UI 层直接拦截，不写入本地账号状态', (WidgetTester tester) async {
    final repository = FakeAccountRepository(
      currentSnapshot: AccountLocalSnapshot.localOnly,
    );

    await _pumpEntryScreen(tester, repository: repository);

    await tester.enterText(
      find.byKey(const Key('account-phone-field')),
      '13800',
    );
    await tester.enterText(find.byKey(const Key('account-code-field')), '12');
    await tester.tap(find.byKey(const Key('account-submit-button')));
    await tester.pumpAndSettle();

    expect(repository.saveCalls, 0);
    expect(find.text('请输入 11 位手机号。'), findsOneWidget);
    expect(find.text('请输入 6 位验证码。'), findsOneWidget);
    expect(find.text('手机号或验证码格式不正确，未写入任何本地账号状态。'), findsOneWidget);
    expect(find.byKey(const Key('account-status-local-only')), findsOneWidget);
  });

  testWidgets('占位登录成功后会进入 signed-in-pending-sync 状态并显示脱敏手机号', (
    WidgetTester tester,
  ) async {
    final repository = FakeAccountRepository(
      currentSnapshot: AccountLocalSnapshot.localOnly,
      pendingSyncCount: 3,
      syncedCount: 1,
    );

    await _pumpEntryScreen(tester, repository: repository);

    await tester.enterText(
      find.byKey(const Key('account-phone-field')),
      '138 0013 8000',
    );
    await tester.enterText(
      find.byKey(const Key('account-code-field')),
      '123456',
    );
    await tester.tap(find.byKey(const Key('account-submit-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.saveCalls, 1);
    expect(
      find.byKey(const Key('account-status-signed-in-pending-sync')),
      findsOneWidget,
    );
    expect(find.textContaining('138****8000'), findsWidgets);
    expect(find.textContaining('待同步 3'), findsOneWidget);
    expect(find.textContaining('账号占位状态已保存，可返回首页查看。'), findsOneWidget);
  });

  testWidgets('账号状态读取失败时暴露 error 态，并允许重试恢复', (WidgetTester tester) async {
    final repository = FakeAccountRepository(
      currentSnapshot: AccountLocalSnapshot.signedOut,
      loadError: 'disk denied',
    );

    await _pumpEntryScreen(tester, repository: repository);

    expect(find.byKey(const Key('account-status-error')), findsOneWidget);
    expect(find.byKey(const Key('account-load-retry')), findsOneWidget);
    expect(find.textContaining('账号状态读取失败'), findsWidgets);

    repository.loadError = null;
    repository.currentSnapshot = AccountLocalSnapshot.signedOut;
    await tester.tap(find.byKey(const Key('account-load-retry')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account-status-signed-out')), findsOneWidget);
    expect(find.text('账号入口已可见，但你还没有登录'), findsOneWidget);
  });
}

Future<void> _pumpEntryScreen(
  WidgetTester tester, {
  required FakeAccountRepository repository,
}) async {
  final viewModel = AccountViewModel(repository: repository);
  addTearDown(viewModel.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider<AccountViewModel>.value(
      value: viewModel,
      child: MaterialApp(home: const AccountEntryScreen()),
    ),
  );

  viewModel.initialize();
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _pumpStatusCard(
  WidgetTester tester, {
  required FakeAccountRepository repository,
  required OnboardingSnapshot onboardingSnapshot,
}) async {
  final viewModel = AccountViewModel(repository: repository);
  addTearDown(viewModel.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider<AccountViewModel>.value(
      value: viewModel,
      child: MaterialApp(
        home: Scaffold(
          body: AccountStatusCard(
            scopeKeyPrefix: 'home',
            onboardingSnapshot: onboardingSnapshot,
          ),
        ),
      ),
    ),
  );

  viewModel.initialize();
  await tester.pump();
  await tester.pumpAndSettle();
}

OnboardingSnapshot _buildSnapshot() {
  return OnboardingSnapshot(
    childDisplayName: '米米',
    ageBucket: OnboardingAgeBucket.twelveToEighteen,
    approxMonths: 15,
    currentStage: 'gesture_plus_words',
    starterSpaceId: 'daily_care',
    starterActivityId: 'bath_time',
    starterPhraseId: 'bath_time_warm_water',
    consentState: OnboardingConsentState.localOnly,
    completedAt: DateTime.utc(2026, 4, 8, 8),
  );
}

class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository({
    required this.currentSnapshot,
    this.loadError,
    this.pendingSyncCount = 0,
    this.syncedCount = 0,
    this.failedCount = 0,
  });

  AccountLocalSnapshot currentSnapshot;
  Object? loadError;
  final int pendingSyncCount;
  final int syncedCount;
  final int failedCount;

  int loadCalls = 0;
  int saveCalls = 0;
  int clearCalls = 0;

  @override
  Future<AccountLocalSnapshot> loadSnapshot() async {
    loadCalls += 1;
    final error = loadError;
    if (error != null) {
      throw Exception(error);
    }
    return currentSnapshot;
  }

  @override
  Future<AccountLocalSnapshot> savePlaceholderSession({
    required String phoneNumber,
    required String verificationCode,
  }) async {
    saveCalls += 1;
    final now = DateTime.utc(2026, 4, 9, 1, saveCalls);
    currentSnapshot = AccountLocalSnapshot(
      consentState: AccountConsentState.acceptedPendingSync,
      session: AccountSession(
        accountId: 'acct-$saveCalls',
        sessionId: 'sess-$saveCalls',
        maskedPhoneNumber: '138****8000',
        createdAt: now,
      ),
      challenge: AccountChallengePlaceholder(
        maskedPhoneNumber: '138****8000',
        codeLength: verificationCode.length,
        issuedAt: now,
      ),
      pendingSyncCount: pendingSyncCount,
      syncedCount: syncedCount,
      failedCount: failedCount,
      lastSyncPhase: pendingSyncCount > 0
          ? 'pending_local_upload'
          : 'awaiting_first_sync',
      lastSyncAt: now,
    );
    return currentSnapshot;
  }

  @override
  Future<AccountLocalSnapshot> clearPlaceholderSession({
    bool revertToLocalOnly = false,
  }) async {
    clearCalls += 1;
    currentSnapshot = revertToLocalOnly
        ? AccountLocalSnapshot.localOnly
        : AccountLocalSnapshot.signedOut;
    return currentSnapshot;
  }
}
