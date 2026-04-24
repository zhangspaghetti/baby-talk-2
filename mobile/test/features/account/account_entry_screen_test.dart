import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/data/services/account_external_link_opener.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/account/presentation/account_view_model.dart';
import 'package:mobile/features/account/presentation/screens/account_entry_screen.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('home 账号卡片在 local-only 时不显示升级 CTA，并能打开账号页面', (
    WidgetTester tester,
  ) async {
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
    expect(find.byKey(const Key('home-account-upgrade-button')), findsNothing);
    expect(find.text('仍是 local-only 档案模式'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-account-open-entry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account-entry-surface')), findsOneWidget);
    expect(find.byKey(const Key('account-status-local-only')), findsOneWidget);
    expect(find.text('先保留同意前本地档案'), findsOneWidget);
  });

  testWidgets('home 账号卡片在 version-blocked 时展示立即升级 CTA 并传递真实链接', (
    WidgetTester tester,
  ) async {
    const upgradeUrl =
        'https://download.example.com/upgrade?channel=stable&source=version_gate';
    final repository = FakeAccountRepository(
      currentSnapshot: _versionBlockedSnapshot(upgradeUrl: upgradeUrl),
    );
    final opener = FakeAccountExternalLinkOpener();

    await _pumpStatusCard(
      tester,
      repository: repository,
      onboardingSnapshot: _buildSnapshot(),
      opener: opener,
    );

    expect(
      find.byKey(const Key('home-account-upgrade-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home-account-upgrade-hint')), findsOneWidget);
    expect(find.text('立即升级'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-account-upgrade-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(opener.openedUrls, [upgradeUrl]);
    expect(find.textContaining('已打开升级页面'), findsOneWidget);
  });

  testWidgets('version-blocked 且缺失 upgradeUrl 时展示禁用 CTA 与可见说明', (
    WidgetTester tester,
  ) async {
    final repository = FakeAccountRepository(
      currentSnapshot: _versionBlockedSnapshot(
        lastVisibleError: '当前版本过旧，最低需要 9.9.9。 升级入口暂未配置，请稍后重试或联系支持。',
      ),
    );

    await _pumpEntryScreen(tester, repository: repository);

    expect(
      find.byKey(const Key('account-status-upgrade-required-426')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('account-upgrade-button')), findsOneWidget);
    expect(find.text('升级入口暂不可用'), findsOneWidget);
    expect(find.text('升级入口暂未配置，请稍后重试或联系支持。'), findsWidgets);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('account-upgrade-button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('launcher 打开失败时会保留升级按钮并显示明确失败消息', (WidgetTester tester) async {
    const upgradeUrl =
        'https://download.example.com/upgrade?channel=stable&source=version_gate';
    final repository = FakeAccountRepository(
      currentSnapshot: _versionBlockedSnapshot(upgradeUrl: upgradeUrl),
    );
    final opener = FakeAccountExternalLinkOpener(
      error: const AccountExternalLinkException(
        kind: AccountExternalLinkFailureKind.launchFailed,
        message: '打开升级页面失败，请稍后重试。',
      ),
    );

    await _pumpEntryScreen(tester, repository: repository, opener: opener);

    final upgradeButton = find.byKey(const Key('account-upgrade-button'));
    await tester.dragUntilVisible(
      upgradeButton,
      find.byType(ListView),
      const Offset(0, -200),
    );
    final button = tester.widget<FilledButton>(upgradeButton);
    expect(button.onPressed, isNotNull);
    button.onPressed!.call();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(opener.openedUrls, [upgradeUrl]);
    expect(find.byKey(const Key('account-upgrade-button')), findsOneWidget);
    expect(find.text('打开升级页面失败，请稍后重试。'), findsOneWidget);
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
    final submitButton = find.byKey(const Key('account-submit-button'));
    await tester.dragUntilVisible(
      submitButton,
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(repository.saveCalls, 0);
    expect(find.text('请输入 11 位手机号。'), findsOneWidget);
    expect(find.text('请输入 6 位验证码。'), findsOneWidget);
    expect(find.text('手机号或验证码格式不正确，未发起真实登录。'), findsOneWidget);
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
    final submitButton = find.byKey(const Key('account-submit-button'));
    await tester.dragUntilVisible(
      submitButton,
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(submitButton);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.saveCalls, 1);
    expect(
      find.byKey(const Key('account-status-signed-in-pending-sync')),
      findsOneWidget,
    );
    expect(find.textContaining('138****8000'), findsWidgets);
    expect(find.textContaining('待同步 3'), findsOneWidget);
    expect(find.textContaining('登录已完成：仍有 3 条待同步事件。'), findsOneWidget);
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
  AccountExternalLinkOpener? opener,
}) async {
  await _setTallViewport(tester);

  final viewModel = AccountViewModel(
    repository: repository,
    linkOpener: opener ?? FakeAccountExternalLinkOpener(),
  );
  addTearDown(viewModel.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider<AccountViewModel>.value(
      value: viewModel,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AccountEntryScreen(),
      ),
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
  AccountExternalLinkOpener? opener,
}) async {
  await _setWideViewport(tester);

  final viewModel = AccountViewModel(
    repository: repository,
    linkOpener: opener ?? FakeAccountExternalLinkOpener(),
  );
  addTearDown(viewModel.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider<AccountViewModel>.value(
      value: viewModel,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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

Future<void> _setTallViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1200, 2200);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pump();
}

Future<void> _setWideViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1200, 1400);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pump();
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

AccountLocalSnapshot _versionBlockedSnapshot({
  String? upgradeUrl,
  String? lastVisibleError,
}) {
  return AccountLocalSnapshot(
    consentState: AccountConsentState.acceptedPendingSync,
    session: AccountSession(
      accountId: 'acct-blocked',
      sessionId: 'sess-blocked',
      maskedPhoneNumber: '138****8000',
      createdAt: DateTime.utc(2026, 4, 9, 1),
    ),
    challenge: AccountChallengePlaceholder(
      maskedPhoneNumber: '138****8000',
      codeLength: 6,
      issuedAt: DateTime.utc(2026, 4, 9, 1),
    ),
    pendingSyncCount: 2,
    syncedCount: 4,
    failedCount: 0,
    lastSyncPhase: 'bootstrap_failed_upgrade_required_426',
    lastVisibleError: lastVisibleError ?? '当前版本过旧，最低需要 9.9.9。',
    upgradeUrl: upgradeUrl,
    lastSyncAt: DateTime.utc(2026, 4, 9, 1, 5),
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

  @override
  final String consentVersion = 'pipl-v1';

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
  Future<AccountLocalSnapshot> signIn({
    required String phoneNumber,
    required String verificationCode,
  }) {
    return savePlaceholderSession(
      phoneNumber: phoneNumber,
      verificationCode: verificationCode,
    );
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
  Future<AccountLocalSnapshot> refreshRuntimeState({
    required AccountRuntimeTrigger trigger,
    AccountLocalSnapshot? seedSnapshot,
    bool forceBootstrap = false,
  }) async {
    return seedSnapshot ?? currentSnapshot;
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

  @override
  Future<AccountLocalSnapshot> revokeConsent({
    String reason = 'user_requested',
  }) async {
    currentSnapshot = currentSnapshot.copyWith(
      consentState: AccountConsentState.revoked,
      lastSyncPhase: 'consent_revoked',
      lastVisibleError: '同意已撤回；重新登录并再次同意后才能继续同步。',
      clearUpgradeUrl: true,
      lastSyncAt: DateTime.utc(2026, 4, 9, 1, 30),
    );
    return currentSnapshot;
  }

  @override
  Future<AccountLocalSnapshot> deleteAccount({
    String reason = 'forget_me',
  }) async {
    currentSnapshot = currentSnapshot.copyWith(
      consentState: AccountConsentState.deleted,
      clearSession: true,
      clearChallenge: true,
      lastSyncPhase: 'account_deleted',
      lastVisibleError: '账号已删除；如需重新同步，请重新注册。',
      clearUpgradeUrl: true,
      lastSyncAt: DateTime.utc(2026, 4, 9, 1, 31),
    );
    return currentSnapshot;
  }

  @override
  Future<AccountSession> persistRefreshedSession(
    AccountSession refreshedSession,
  ) async {
    currentSnapshot = currentSnapshot.copyWith(session: refreshedSession);
    return refreshedSession;
  }

  @override
  Future<void> close() async {}
}

class FakeAccountExternalLinkOpener implements AccountExternalLinkOpener {
  FakeAccountExternalLinkOpener({this.error});

  final AccountExternalLinkException? error;
  final List<String> openedUrls = <String>[];

  @override
  Future<void> openUpgradeUrl(String url) async {
    openedUrls.add(url);
    if (error != null) {
      throw error!;
    }
  }
}
