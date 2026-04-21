import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/invite_reentry_coordinator.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/features/account/data/local/account_local_store.dart';
import 'package:mobile/features/account/data/repositories/account_repository.dart';
import 'package:mobile/features/account/domain/models/account_consent_state.dart';
import 'package:mobile/features/account/presentation/account_view_model.dart';
import 'package:mobile/features/account/presentation/screens/account_entry_screen.dart';
import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/data/repositories/household_repository.dart';
import 'package:mobile/features/household/domain/models/household_invite_link.dart';
import 'package:mobile/features/household/domain/models/household_role.dart';
import 'package:mobile/features/household/domain/models/household_shared_context.dart';
import 'package:mobile/features/household/presentation/household_view_model.dart';
import 'package:mobile/features/household/presentation/widgets/household_invite_card.dart';
import 'package:mobile/features/household/presentation/widgets/household_shared_context_card.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('主照护者 surface 显示共享摘要与 invite CTA，并能看到真实 invite link', (
    tester,
  ) async {
    final householdRepository = _FakeHouseholdRepository(
      loadSnapshotResult: HouseholdLocalSnapshot(
        householdId: 'household_1',
        role: HouseholdRole.primaryCaregiver,
        sharedContext: _sharedContext(
          practiceArgs: const PracticeRouteArgs(
            spaceId: 'family_rhythm',
            activityId: 'feeding_time',
          ),
        ),
        lastPhase: 'shared_context_ready',
        lastAcceptedAt: DateTime.utc(2026, 4, 16, 12),
      ),
      createInviteResult: HouseholdCreateInviteResult(
        snapshot: HouseholdLocalSnapshot(
          householdId: 'household_1',
          role: HouseholdRole.primaryCaregiver,
          sharedContext: _sharedContext(
            practiceArgs: const PracticeRouteArgs(
              spaceId: 'family_rhythm',
              activityId: 'feeding_time',
            ),
          ),
          lastPhase: 'create_invite_created',
          lastAcceptedAt: DateTime.utc(2026, 4, 16, 12),
        ),
        inviteLink: HouseholdInviteLink(
          householdId: 'household_1',
          token: 'invite_token_1234',
          inviteUrl: 'https://invite.example.com/invite/invite_token_1234',
          role: HouseholdRole.caregiver,
          source: 'shell_drawer',
          expiresAt: DateTime.utc(2026, 4, 20, 12),
        ),
        message: '邀请链接已创建。',
      ),
    );
    final householdViewModel = HouseholdViewModel(
      repository: householdRepository,
    );
    addTearDown(householdViewModel.dispose);
    await householdViewModel.initialize();

    await tester.pumpWidget(_buildSurfaceHarness(householdViewModel));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shell-household-role-chip')), findsOneWidget);
    expect(find.text('主照护者'), findsWidgets);
    expect(
      find.byKey(const Key('shell-household-profile-summary')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('shell-household-create-invite')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(
      find.byKey(const Key('shell-household-create-invite')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('shell-household-create-invite')));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('shell-household-invite-url')),
      120,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.byKey(const Key('shell-household-invite-url')), findsOneWidget);
    expect(find.textContaining('invite.example.com/invite'), findsOneWidget);
    expect(find.textContaining('邀请链接已创建'), findsOneWidget);
  });

  testWidgets('次照护者 surface 显示只读角色说明且 invite CTA 禁用', (tester) async {
    final householdViewModel = HouseholdViewModel(
      repository: _FakeHouseholdRepository(
        loadSnapshotResult: HouseholdLocalSnapshot(
          householdId: 'household_1',
          role: HouseholdRole.caregiver,
          sharedContext: _sharedContext(),
          lastPhase: 'shared_context_ready',
          lastAcceptedAt: DateTime.utc(2026, 4, 16, 12),
        ),
      ),
    );
    addTearDown(householdViewModel.dispose);
    await householdViewModel.initialize();

    await tester.pumpWidget(_buildSurfaceHarness(householdViewModel));
    await tester.pumpAndSettle();

    expect(find.text('次照护者'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const Key('shell-household-invite-readonly')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const Key('shell-household-invite-readonly')),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('shell-household-create-invite')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('account surface 会保留 accept 失败并允许 retry 恢复共享摘要', (tester) async {
    final repository = _FakeHouseholdRepository(
      acceptQueue: <HouseholdInviteAcceptResult>[
        const HouseholdInviteAcceptResult(
          snapshot: HouseholdLocalSnapshot(
            role: HouseholdRole.caregiver,
            lastPhase: 'accept_invite_role_not_allowed',
            lastVisibleError: '当前角色不能执行这个邀请动作。',
          ),
          message: '当前角色不能执行这个邀请动作。',
        ),
        HouseholdInviteAcceptResult(
          snapshot: HouseholdLocalSnapshot(
            householdId: 'household_1',
            role: HouseholdRole.caregiver,
            sharedContext: _sharedContext(),
            lastPhase: 'accept_ready',
            lastAcceptedAt: DateTime.utc(2026, 4, 16, 12),
          ),
          practiceArgs: const PracticeRouteArgs(
            spaceId: 'daily_care',
            activityId: 'bath_time',
            shareToken: 'invite_token_1234',
            entrySource: PracticeRouteEntrySource.inviteReentry,
          ),
          message: '邀请已接受，正在进入共享练习。',
        ),
      ],
    );
    final householdViewModel = HouseholdViewModel(repository: repository);
    final accountViewModel = AccountViewModel(
      repository: _FakeAccountRepository(),
    );
    addTearDown(householdViewModel.dispose);
    addTearDown(accountViewModel.dispose);

    await householdViewModel.acceptInviteFromReentry(
      const InviteReentryAcceptCommand(
        token: 'invite_token_1234',
        source: 'invite_link',
        roleHint: HouseholdRole.caregiver,
      ),
    );
    await accountViewModel.initialize();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AccountViewModel>.value(
            value: accountViewModel,
          ),
          ChangeNotifierProvider<HouseholdViewModel>.value(
            value: householdViewModel,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const AccountEntryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('account-household-error-banner')),
      findsOneWidget,
    );
    expect(find.textContaining('当前角色不能执行这个邀请动作'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const Key('account-household-retry-button')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(
      find.byKey(const Key('account-household-retry-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-household-retry-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('account-household-profile-summary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('account-household-continuity-summary')),
      findsOneWidget,
    );
    expect(find.textContaining('共享宝宝档案已接通'), findsWidgets);
  });

  testWidgets('provider 缺失时 account surface 显示显式 disabled fallback', (
    tester,
  ) async {
    final accountViewModel = AccountViewModel(
      repository: _FakeAccountRepository(),
    );
    addTearDown(accountViewModel.dispose);
    await accountViewModel.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider<AccountViewModel>.value(
        value: accountViewModel,
        child: MaterialApp(
          theme: AppTheme.build(),
          home: const AccountEntryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('account-household-provider-missing')),
      findsOneWidget,
    );
    expect(find.textContaining('安全空态'), findsWidgets);
  });

  testWidgets('共享 nextStep 缺失时 surface 保持安全禁用态', (tester) async {
    final householdViewModel = HouseholdViewModel(
      repository: _FakeHouseholdRepository(
        loadSnapshotResult: HouseholdLocalSnapshot(
          householdId: 'household_1',
          role: HouseholdRole.caregiver,
          sharedContext: HouseholdSharedContext(
            babyProfileSummary: '共享宝宝档案：家庭已同步 2 条互动。',
            continuitySummary: '最近 continuity：先继续共享 activity。',
            gardenSummary: '花园上下文：共享花圃正在缓慢生长。',
            practiceArgs: const PracticeRouteArgs(
              spaceId: 'daily_care',
              activityId: 'bath_time',
            ),
            actor: const HouseholdSharedActor(
              role: 'caregiver',
              source: 'sync_event',
              result: 'needs_break',
            ),
            latestInteractionAt: DateTime.utc(2026, 4, 16, 11, 50),
            updatedAt: DateTime.utc(2026, 4, 16, 12),
          ),
          lastPhase: 'shared_context_ready',
          lastAcceptedAt: DateTime.utc(2026, 4, 16, 12),
        ),
      ),
    );
    addTearDown(householdViewModel.dispose);
    await householdViewModel.initialize();

    await tester.pumpWidget(_buildSurfaceHarness(householdViewModel));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('shell-household-next-step-disabled')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const Key('shell-household-next-step-disabled')),
      findsOneWidget,
    );
    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('shell-household-next-step-button')),
    );
    expect(button.onPressed, isNull);
  });
}

Widget _buildSurfaceHarness(HouseholdViewModel householdViewModel) {
  return MaterialApp(
    theme: AppTheme.build(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: AnimatedBuilder(
        animation: householdViewModel,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              HouseholdSharedContextCard(
                surfaceKeyPrefix: 'shell',
                viewModel: householdViewModel,
                title: '共享家庭档案',
              ),
              const SizedBox(height: 16),
              HouseholdInviteCard(
                surfaceKeyPrefix: 'shell',
                viewModel: householdViewModel,
                inviteSource: 'shell_drawer',
              ),
            ],
          );
        },
      ),
    ),
  );
}

HouseholdSharedContext _sharedContext({
  PracticeRouteArgs practiceArgs = const PracticeRouteArgs(
    spaceId: 'daily_care',
    activityId: 'bath_time',
  ),
}) {
  return HouseholdSharedContext(
    babyProfileSummary: '共享宝宝档案：已同步 2 条互动。',
    continuitySummary: '最近 continuity：先继续洗澡时间的句子。',
    gardenSummary: '花园上下文：日常照护花圃正在生长。',
    practiceArgs: practiceArgs,
    actor: const HouseholdSharedActor(
      role: 'caregiver',
      source: 'sync_event',
      result: 'needs_break',
    ),
    nextStep: HouseholdSharedNextStep(
      spaceId: practiceArgs.spaceId,
      activityId: practiceArgs.activityId,
      reason: 'top_activity',
    ),
    latestInteractionAt: DateTime.utc(2026, 4, 16, 11, 50),
    updatedAt: DateTime.utc(2026, 4, 16, 12),
  );
}

class _FakeHouseholdRepository implements HouseholdRepository {
  _FakeHouseholdRepository({
    this.loadSnapshotResult = HouseholdLocalSnapshot.empty,
    this.createInviteResult,
    List<HouseholdInviteAcceptResult>? acceptQueue,
  // ignore: unused_element_parameter
    this.refreshResult = HouseholdLocalSnapshot.empty,
  }) : acceptQueue = acceptQueue ?? <HouseholdInviteAcceptResult>[];

  HouseholdLocalSnapshot loadSnapshotResult;
  HouseholdCreateInviteResult? createInviteResult;
  final List<HouseholdInviteAcceptResult> acceptQueue;
  HouseholdLocalSnapshot refreshResult;

  @override
  Future<HouseholdCreateInviteResult> createInvite({
    HouseholdRole role = HouseholdRole.caregiver,
    String source = 'household_settings',
  }) async {
    return createInviteResult ??
        const HouseholdCreateInviteResult(
          snapshot: HouseholdLocalSnapshot(
            lastPhase: 'create_invite_unavailable',
            lastVisibleError: '邀请服务暂时不可用，请稍后重试。',
          ),
          message: '邀请服务暂时不可用，请稍后重试。',
        );
  }

  @override
  Future<HouseholdInviteAcceptResult> acceptInvite({
    required String token,
    required String source,
  }) async {
    if (acceptQueue.isEmpty) {
      return const HouseholdInviteAcceptResult(
        snapshot: HouseholdLocalSnapshot(
          lastPhase: 'accept_invite_unavailable',
          lastVisibleError: '邀请服务暂时不可用，请稍后重试。',
        ),
        message: '邀请服务暂时不可用，请稍后重试。',
      );
    }
    return acceptQueue.removeAt(0);
  }

  @override
  Future<void> close() async {}

  @override
  Future<HouseholdLocalSnapshot> loadSnapshot() async => loadSnapshotResult;

  @override
  Future<HouseholdLocalSnapshot> refreshSharedContext({
    String reason = 'manual_refresh',
  }) async {
    return refreshResult;
  }
}

class _FakeAccountRepository implements AccountRepository {
  @override
  final String consentVersion = 'pipl-v1';

  @override
  Future<AccountLocalSnapshot> loadSnapshot() async {
    return AccountLocalSnapshot(
      consentState: AccountConsentState.signedOut,
      lastSyncPhase: 'signed_out',
    );
  }

  @override
  Future<AccountLocalSnapshot> signIn({
    required String phoneNumber,
    required String verificationCode,
  }) async {
    return AccountLocalSnapshot.signedOut;
  }

  @override
  Future<AccountLocalSnapshot> savePlaceholderSession({
    required String phoneNumber,
    required String verificationCode,
  }) async {
    return AccountLocalSnapshot.signedOut;
  }

  @override
  Future<AccountLocalSnapshot> refreshRuntimeState({
    required AccountRuntimeTrigger trigger,
    AccountLocalSnapshot? seedSnapshot,
    bool forceBootstrap = false,
  }) async {
    return seedSnapshot ?? AccountLocalSnapshot.signedOut;
  }

  @override
  Future<AccountLocalSnapshot> clearPlaceholderSession({
    bool revertToLocalOnly = false,
  }) async {
    return revertToLocalOnly
        ? AccountLocalSnapshot.localOnly
        : AccountLocalSnapshot.signedOut;
  }

  @override
  Future<AccountLocalSnapshot> revokeConsent({
    String reason = 'user_requested',
  }) async {
    return AccountLocalSnapshot.signedOut;
  }

  @override
  Future<AccountLocalSnapshot> deleteAccount({
    String reason = 'forget_me',
  }) async {
    return AccountLocalSnapshot.signedOut;
  }

  @override
  Future<void> close() async {}
}
