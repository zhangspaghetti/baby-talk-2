import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/router/account_entry_route_contract.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/core/local_data_lifecycle/local_sensitive_data_clearance.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/local/auth_continuation_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/data/services/account_external_link_opener.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/domain/models/account_session.dart';
import 'package:mobile/features/account/presentation/account_notifier.dart';
import 'package:mobile/features/account/presentation/screens/account_entry_screen.dart';
import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/data/repositories/household_repository.dart';
import 'package:mobile/features/household/domain/models/household_role.dart';
import 'package:mobile/features/household/presentation/household_notifier.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_snapshot.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/l10n/app_localizations.dart';

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
    expect(find.text('仍是本机档案模式'), findsOneWidget);
    expect(find.textContaining('local-only'), findsNothing);

    await tester.tap(find.byKey(const Key('home-account-open-entry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account-entry-surface')), findsOneWidget);
    expect(find.byKey(const Key('account-status-signed-out')), findsOneWidget);
    expect(find.text('账号入口已可见，但你还没有登录'), findsOneWidget);
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
    expect(
      find.byKey(const Key('home-account-sync-chip-guidance')),
      findsNothing,
    );
    expect(find.text('立即升级'), findsOneWidget);
    expect(find.text('升级等待期间，本机练习记录仍会保留，你可以继续在本机使用。'), findsNothing);
    expect(find.text('服务端已拒绝当前版本；请先安装新版本，再返回这里继续同步。'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-account-upgrade-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(opener.openedUrls, [upgradeUrl]);
    expect(find.textContaining('已打开升级页面'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-account-open-entry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account-entry-surface')), findsOneWidget);
    expect(find.text('服务端已拒绝当前版本；请先安装新版本，再返回这里继续同步。'), findsOneWidget);
    expect(find.byKey(const Key('account-upgrade-hint')), findsOneWidget);
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
    expect(
      find.byKey(const Key('account-upgrade-reassurance')),
      findsOneWidget,
    );
    expect(find.text('升级入口暂未配置，请稍后重试或联系支持。'), findsWidgets);
    expect(find.text('升级等待期间，本机练习记录仍会保留，你可以继续在本机使用。'), findsWidgets);

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
    expect(
      find.byKey(const Key('account-upgrade-reassurance')),
      findsOneWidget,
    );
    expect(find.text('打开升级页面失败，请稍后重试。'), findsOneWidget);
  });

  testWidgets('非法手机号和验证码会在 UI 层直接拦截，不写入本地账号状态', (WidgetTester tester) async {
    final repository = FakeAccountRepository(
      currentSnapshot: AccountLocalSnapshot.localOnly,
    );

    await _pumpEntryScreen(tester, repository: repository);

    expect(find.byKey(const Key('account-sign-in-trust-note')), findsOneWidget);
    expect(
      find.text('登录只会接入账号同步，不会清空本机练习记录；如果出错，你仍会停留在账号页并可继续当前练习。'),
      findsOneWidget,
    );

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
    expect(find.byKey(const Key('account-status-signed-out')), findsOneWidget);
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
    expect(find.byKey(const Key('account-upgrade-reassurance')), findsNothing);
    expect(
      find.byKey(const Key('account-status-consent-revoked')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('account-status-account-deleted')),
      findsNothing,
    );
    expect(find.textContaining('登录已完成：仍有 3 条练习记录待同步。'), findsOneWidget);
    expect(find.text('登录已完成；你现在可以返回首页查看最近恢复结果，待同步记录也会继续尝试上传。'), findsOneWidget);
    expect(find.text('仍有 3 条练习记录待同步，打开应用、回到首页或手动重试时会继续尝试。'), findsOneWidget);
    expect(find.textContaining('待同步事件'), findsNothing);
  });

  testWidgets('onboarding 来源在 continuation I/O 失败后仍只返回一次 signed-in 结果', (
    WidgetTester tester,
  ) async {
    final repository = FakeAccountRepository(
      currentSnapshot: AccountLocalSnapshot.localOnly,
    );
    final continuationStore = AuthContinuationStore(
      directoryResolver: () async {
        throw const FileSystemException('continuation unavailable');
      },
    );

    await _pumpAccountOriginRouter(
      tester,
      repository: repository,
      continuationStore: continuationStore,
    );
    await tester.tap(find.byKey(const Key('onboarding-account-launch')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('account-phone-field')),
      '13800138000',
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
    await tester.pumpAndSettle();

    expect(repository.saveCalls, 1);
    expect(
      find.byKey(const Key('onboarding-account-returned')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('account-entry-surface')), findsNothing);
  });

  testWidgets('账号状态读取失败时暴露 error 态，并允许重试恢复', (WidgetTester tester) async {
    final repository = FakeAccountRepository(
      currentSnapshot: AccountLocalSnapshot.signedOut,
      loadError: 'disk denied',
    );

    await _pumpEntryScreen(tester, repository: repository);

    expect(find.byKey(const Key('account-status-error')), findsOneWidget);
    expect(find.byKey(const Key('account-load-retry')), findsOneWidget);
    expect(
      find.byKey(const Key('account-read-retry-guidance')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('account-last-error')), findsNothing);
    expect(find.byKey(const Key('account-submit-message')), findsNothing);
    expect(find.textContaining('账号状态暂时不可读'), findsWidgets);
    expect(
      find.byKey(const Key('account-status-signed-in-pending-sync')),
      findsNothing,
    );
    expect(find.text('重试只会重新读取账号状态，不会改动本机练习记录。'), findsOneWidget);

    repository.loadError = null;
    repository.currentSnapshot = AccountLocalSnapshot.signedOut;
    await tester.tap(find.byKey(const Key('account-load-retry')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account-status-signed-out')), findsOneWidget);
    expect(find.text('账号入口已可见，但你还没有登录'), findsOneWidget);
  });

  testWidgets('账号页将状态、恢复、家庭、管理和高风险动作分区展示', (WidgetTester tester) async {
    final repository = FakeAccountRepository(
      currentSnapshot: _signedInSnapshot(),
    );

    await _pumpEntryScreen(tester, repository: repository);

    expect(
      find.byKey(const Key('account-current-status-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('account-primary-action-section')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('account-recovery-section')), findsOneWidget);
    expect(
      find.byKey(const Key('account-family-context-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('account-device-erase-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('account-management-section')), findsOneWidget);
    expect(
      find.byKey(const Key('account-danger-zone-section')),
      findsOneWidget,
    );
    expect(find.textContaining('本机记录仍会保留'), findsOneWidget);
    expect(find.byKey(const Key('account-submit-button')), findsNothing);
  });

  testWidgets('账号恢复和生命周期动作保持各自原有 handler', (WidgetTester tester) async {
    final retryRepository = FakeAccountRepository(
      currentSnapshot: _signedInSnapshot(),
    );
    await _pumpEntryScreen(tester, repository: retryRepository);
    await _pressButton(
      tester,
      find.byKey(const Key('account-sync-retry-button')),
    );
    expect(
      retryRepository.lastRefreshTrigger,
      AccountRuntimeTrigger.manualRetry,
    );

    final revokeRepository = FakeAccountRepository(
      currentSnapshot: _signedInSnapshot(),
    );
    final revokeClearanceRequests = <LocalSensitiveDataClearanceTrigger>[];
    await _pumpEntryScreen(
      tester,
      repository: revokeRepository,
      localDataClearanceRunner:
          ({
            required trigger,
            required correlationId,
            required requestedAt,
          }) async {
            revokeClearanceRequests.add(trigger);
            return LocalSensitiveDataClearanceReport(
              correlationId: correlationId,
              trigger: trigger,
              requestedAt: requestedAt,
              startedAt: requestedAt,
              finishedAt: requestedAt,
              overallStatus: LocalSensitiveDataClearanceOverallStatus.completed,
              authorizationEvidence:
                  LocalSensitiveDataAuthorizationEvidence.from(
                    const ReportOnlyAuthorization(reason: 'widget test'),
                  ),
              results: const <LocalSensitiveDataTargetResult>[],
            );
          },
    );
    await _pressButton(tester, find.byKey(const Key('account-revoke-button')));
    expect(
      find.byKey(const Key('account-revoke-confirm-dialog')),
      findsOneWidget,
    );
    expect(revokeRepository.revokeCalls, 0);
    expect(revokeRepository.deleteCalls, 0);
    expect(
      find.byKey(const Key('account-delete-confirm-dialog')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('account-revoke-cancel-button')));
    await tester.pumpAndSettle();
    expect(revokeRepository.revokeCalls, 0);

    await _pressButton(tester, find.byKey(const Key('account-revoke-button')));
    await tester.tap(find.byKey(const Key('account-revoke-confirm-button')));
    await tester.pumpAndSettle();
    expect(revokeRepository.revokeCalls, 1);
    expect(revokeClearanceRequests, [
      LocalSensitiveDataClearanceTrigger.consentWithdrawalConfirmed,
    ]);
    expect(
      find.byKey(const Key('account-status-consent-revoked')),
      findsOneWidget,
    );

    final logoutRepository = FakeAccountRepository(
      currentSnapshot: _signedInSnapshot(),
    );
    await _pumpEntryScreen(tester, repository: logoutRepository);
    await _pressButton(tester, find.byKey(const Key('account-clear-button')));
    expect(
      find.byKey(const Key('account-clear-confirm-dialog')),
      findsOneWidget,
    );
    expect(logoutRepository.clearCalls, 0);
    await tester.tap(find.byKey(const Key('account-clear-cancel-button')));
    await tester.pumpAndSettle();
    expect(logoutRepository.clearCalls, 0);

    await _pressButton(tester, find.byKey(const Key('account-clear-button')));
    await tester.tap(find.byKey(const Key('account-clear-confirm-button')));
    await tester.pumpAndSettle();
    expect(logoutRepository.clearCalls, 1);
    expect(logoutRepository.lastClearRevertToLocalOnly, isFalse);
    expect(logoutRepository.revokeCalls, 0);
    expect(logoutRepository.deleteCalls, 0);

    final localRepository = FakeAccountRepository(
      currentSnapshot: _signedInSnapshot(),
    );
    await _pumpEntryScreen(tester, repository: localRepository);
    await _pressButton(
      tester,
      find.byKey(const Key('account-local-only-button')),
    );
    expect(
      find.byKey(const Key('account-local-only-confirm-dialog')),
      findsOneWidget,
    );
    expect(localRepository.clearCalls, 0);
    await tester.tap(find.byKey(const Key('account-local-only-cancel-button')));
    await tester.pumpAndSettle();
    expect(localRepository.clearCalls, 0);

    await _pressButton(
      tester,
      find.byKey(const Key('account-local-only-button')),
    );
    await tester.tap(
      find.byKey(const Key('account-local-only-confirm-button')),
    );
    await tester.pumpAndSettle();
    expect(localRepository.clearCalls, 1);
    expect(localRepository.lastClearRevertToLocalOnly, isTrue);
    expect(localRepository.revokeCalls, 0);
    expect(localRepository.deleteCalls, 0);

    final closeRepository = FakeAccountRepository(
      currentSnapshot: _signedInSnapshot(),
    );
    await _pumpEntryScreen(tester, repository: closeRepository);
    closeRepository.lastRefreshTrigger = null;
    await _pressButton(tester, find.byKey(const Key('account-close-button')));
    expect(closeRepository.clearCalls, 0);
    expect(closeRepository.revokeCalls, 0);
    expect(closeRepository.deleteCalls, 0);
    expect(closeRepository.lastRefreshTrigger, isNull);
  });

  testWidgets('删除账号需要二次确认，并在确认后触发本机敏感数据清理', (WidgetTester tester) async {
    final repository = FakeAccountRepository(
      currentSnapshot: _signedInSnapshot(),
    );
    final clearanceRequests = <LocalSensitiveDataClearanceTrigger>[];

    await _pumpEntryScreen(
      tester,
      repository: repository,
      localDataClearanceRunner:
          ({
            required trigger,
            required correlationId,
            required requestedAt,
          }) async {
            clearanceRequests.add(trigger);
            return LocalSensitiveDataClearanceReport(
              correlationId: correlationId,
              trigger: trigger,
              requestedAt: requestedAt,
              startedAt: requestedAt,
              finishedAt: requestedAt,
              overallStatus: LocalSensitiveDataClearanceOverallStatus.completed,
              authorizationEvidence:
                  LocalSensitiveDataAuthorizationEvidence.from(
                    const ReportOnlyAuthorization(reason: 'widget test'),
                  ),
              results: const <LocalSensitiveDataTargetResult>[],
            );
          },
    );

    final deleteButton = find.byKey(const Key('account-delete-button'));
    await tester.dragUntilVisible(
      deleteButton,
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('account-delete-confirm-dialog')),
      findsOneWidget,
    );
    expect(find.text('确认删除账号？'), findsOneWidget);
    expect(
      find.text('删除后会清理本机账号、宝宝资料、家庭上下文、练习记录、导师事实和设备标识。此操作不可撤销。'),
      findsOneWidget,
    );
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('确认删除'), findsOneWidget);
    expect(clearanceRequests, isEmpty);

    await tester.tap(find.byKey(const Key('account-delete-cancel-button')));
    await tester.pumpAndSettle();

    expect(clearanceRequests, isEmpty);
    expect(repository.deleteCalls, 0);

    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('account-delete-confirm-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(clearanceRequests, [
      LocalSensitiveDataClearanceTrigger.accountDeletionConfirmed,
    ]);
    expect(repository.deleteCalls, 1);
    expect(
      find.byKey(const Key('account-status-account-deleted')),
      findsOneWidget,
    );
    expect(find.text('账号已删除；本机敏感数据已清理。'), findsOneWidget);
  });
}

Future<void> _pressButton(WidgetTester tester, Finder finder) async {
  final button = tester.widget<ButtonStyleButton>(finder);
  expect(button.onPressed, isNotNull);
  button.onPressed!.call();
  await tester.idle();
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _pumpEntryScreen(
  WidgetTester tester, {
  required FakeAccountRepository repository,
  AccountExternalLinkOpener? opener,
  AccountLocalSensitiveDataClearanceRunner? localDataClearanceRunner,
}) async {
  await _setTallViewport(tester);

  final notifier = AccountNotifier(
    repository: repository,
    linkOpener: opener ?? FakeAccountExternalLinkOpener(),
    localDataClearanceRunner: localDataClearanceRunner,
  );

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        accountNotifierProvider.overrideWith((ref) => notifier),
        householdRepositoryProvider.overrideWith(
          (ref) async => _FakeHouseholdRepository(),
        ),
        householdNotifierProvider.overrideWith(
          (ref) => HouseholdNotifier(repository: _FakeHouseholdRepository()),
        ),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          initialLocation: '/account',
          routes: [
            GoRoute(
              path: '/account',
              builder: (context, state) => const AccountEntryScreen(),
            ),
          ],
        ),
      ),
    ),
  );

  await notifier.initialize();
  await _settleAccountNotifier(tester, notifier);
}

Future<void> _pumpAccountOriginRouter(
  WidgetTester tester, {
  required FakeAccountRepository repository,
  required AuthContinuationStore continuationStore,
}) async {
  await _setTallViewport(tester);
  final notifier = AccountNotifier(repository: repository);
  final router = GoRouter(
    initialLocation: '/launcher',
    routes: <RouteBase>[
      GoRoute(
        path: '/launcher',
        builder: (context, state) => const _OnboardingAccountLauncher(),
      ),
      GoRoute(
        path: '/account',
        builder: (context, state) => AccountEntryScreen(
          origin:
              state.extra as AccountEntryOrigin? ?? AccountEntryOrigin.settings,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        accountNotifierProvider.overrideWith((ref) => notifier),
        authContinuationStoreProvider.overrideWithValue(continuationStore),
        householdRepositoryProvider.overrideWith(
          (ref) async => _FakeHouseholdRepository(),
        ),
        householdNotifierProvider.overrideWith(
          (ref) => HouseholdNotifier(repository: _FakeHouseholdRepository()),
        ),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await notifier.initialize();
  await _settleAccountNotifier(tester, notifier);
}

class _OnboardingAccountLauncher extends StatefulWidget {
  const _OnboardingAccountLauncher();

  @override
  State<_OnboardingAccountLauncher> createState() =>
      _OnboardingAccountLauncherState();
}

class _OnboardingAccountLauncherState
    extends State<_OnboardingAccountLauncher> {
  Object? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FilledButton(
        key: _result == AccountEntryResult.signedIn
            ? const Key('onboarding-account-returned')
            : const Key('onboarding-account-launch'),
        onPressed: () async {
          final result = await context.push<Object?>(
            '/account',
            extra: AccountEntryOrigin.onboardingContinuation,
          );
          if (!mounted) {
            return;
          }
          setState(() {
            _result = result;
          });
        },
        child: _result == AccountEntryResult.signedIn
            ? const Text('onboarding signed-in returned')
            : const Text('open account'),
      ),
    );
  }
}

Future<void> _pumpStatusCard(
  WidgetTester tester, {
  required FakeAccountRepository repository,
  required OnboardingSnapshot onboardingSnapshot,
  AccountExternalLinkOpener? opener,
}) async {
  await _setWideViewport(tester);

  final notifier = AccountNotifier(
    repository: repository,
    linkOpener: opener ?? FakeAccountExternalLinkOpener(),
  );

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        accountNotifierProvider.overrideWith((ref) => notifier),
        householdRepositoryProvider.overrideWith(
          (ref) async => _FakeHouseholdRepository(),
        ),
        householdNotifierProvider.overrideWith(
          (ref) => HouseholdNotifier(repository: _FakeHouseholdRepository()),
        ),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: AccountStatusCard(
                  scopeKeyPrefix: 'home',
                  onboardingSnapshot: onboardingSnapshot,
                ),
              ),
            ),
            GoRoute(
              path: '/account',
              builder: (context, state) => const AccountEntryScreen(),
            ),
          ],
        ),
      ),
    ),
  );

  await notifier.initialize();
  await _settleAccountNotifier(tester, notifier);
}

Future<void> _settleAccountNotifier(
  WidgetTester tester,
  AccountNotifier notifier,
) async {
  for (var attempt = 0; attempt < 8; attempt += 1) {
    await tester.idle();
    await tester.pump();
    if (!notifier.isLoading && !notifier.isBusy) {
      await tester.pumpAndSettle();
      return;
    }
  }
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
    ageBucket: OnboardingAgeBucket.oneToTwo,
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

AccountLocalSnapshot _signedInSnapshot() {
  return AccountLocalSnapshot(
    consentState: AccountConsentState.acceptedPendingSync,
    session: AccountSession(
      accountId: 'acct-signed-in',
      sessionId: 'sess-signed-in',
      maskedPhoneNumber: '138****8000',
      createdAt: DateTime.utc(2026, 4, 9, 1),
    ),
    challenge: AccountChallengePlaceholder(
      maskedPhoneNumber: '138****8000',
      codeLength: 6,
      issuedAt: DateTime.utc(2026, 4, 9, 1),
    ),
    pendingSyncCount: 0,
    syncedCount: 4,
    failedCount: 0,
    lastSyncPhase: 'synced',
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
  int revokeCalls = 0;
  int deleteCalls = 0;
  bool? lastClearRevertToLocalOnly;
  AccountRuntimeTrigger? lastRefreshTrigger;

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
    lastRefreshTrigger = trigger;
    return seedSnapshot ?? currentSnapshot;
  }

  @override
  Future<AccountLocalSnapshot> clearPlaceholderSession({
    bool revertToLocalOnly = false,
  }) async {
    clearCalls += 1;
    lastClearRevertToLocalOnly = revertToLocalOnly;
    currentSnapshot = revertToLocalOnly
        ? AccountLocalSnapshot.localOnly
        : AccountLocalSnapshot.signedOut;
    return currentSnapshot;
  }

  @override
  Future<AccountLocalSnapshot> revokeConsent({
    String reason = 'user_requested',
  }) async {
    revokeCalls += 1;
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
    deleteCalls += 1;
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
  Future<void> deleteLocalSnapshotForLifecycle() async {}

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

class _FakeHouseholdRepository implements HouseholdRepository {
  @override
  Future<HouseholdLocalSnapshot> loadSnapshot() async =>
      const HouseholdLocalSnapshot(lastPhase: 'idle');

  @override
  Future<HouseholdCreateInviteResult> createInvite({
    HouseholdRole role = HouseholdRole.caregiver,
    String source = 'account_entry',
  }) async => const HouseholdCreateInviteResult(
    snapshot: HouseholdLocalSnapshot(lastPhase: 'create_invite_unavailable'),
    message: 'unavailable',
  );

  @override
  Future<HouseholdInviteAcceptResult> acceptInvite({
    required String token,
    required String source,
  }) async => const HouseholdInviteAcceptResult(
    snapshot: HouseholdLocalSnapshot(lastPhase: 'accept_invite_unavailable'),
    message: 'unavailable',
  );

  @override
  Future<HouseholdLocalSnapshot> refreshSharedContext({
    String reason = 'manual_refresh',
  }) async => const HouseholdLocalSnapshot(lastPhase: 'idle');

  @override
  Future<HouseholdRevokeInviteResult> revokeInvite({
    required String token,
    String source = 'account_entry',
  }) async => const HouseholdRevokeInviteResult(
    snapshot: HouseholdLocalSnapshot(lastPhase: 'revoke_invite_revoked'),
    message: 'revoked',
    applied: true,
  );

  @override
  Future<void> deleteLocalSnapshotForLifecycle() async {}

  @override
  Future<void> close() async {}
}
