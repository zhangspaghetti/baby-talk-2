import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/domain/models/household_invite_link.dart';
import 'package:mobile/features/household/domain/models/household_role.dart';
import 'package:mobile/features/household/domain/models/household_shared_context.dart';
import 'package:mobile/features/household/presentation/household_notifier.dart';
import 'package:mobile/features/household/presentation/household_invite_link_actions.dart';
import 'package:mobile/features/household/presentation/widgets/household_invite_card.dart';
import 'package:mobile/features/household/presentation/widgets/household_shared_context_card.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';
import 'package:mobile/l10n/app_localizations.dart';

void main() {
  test('household shared context helpers keep labels and safe args stable', () {
    final ready = _sharedContext();
    final missingNextStep = _sharedContext(nextStep: _invalidNextStep());

    expect(resolveHouseholdSharedNextStepArgs(ready)?.scopeLabel, 'home/song');
    expect(resolveHouseholdSharedNextStepArgs(missingNextStep), isNull);
    expect(isHouseholdSharedProjectionNewer(ready, null), isTrue);
    expect(
      isHouseholdSharedProjectionNewer(
        ready,
        ready.latestInteractionAt.add(const Duration(minutes: 1)),
      ),
      isFalse,
    );
    expect(householdActorRoleLabel('primary_caregiver'), '主照护者');
    expect(householdActorRoleLabel('caregiver'), '次照护者');
    expect(householdActorRoleLabel('unknown'), '家庭成员');
    expect(householdActorSourceLabel('sync_event'), '同步回流');
    expect(householdActorSourceLabel('manual'), '共享同步');
    expect(householdActorResultLabel('cooperating'), '配合');
    expect(householdActorResultLabel('hesitant'), '犹豫');
    expect(householdActorResultLabel('resisting'), '不想');
    expect(householdActorResultLabel('no_response'), '没反应');
    expect(householdActorResultLabel('other'), '其他');
    expect(householdActorResultLabel('unknown'), '已记录反馈');
    expect(householdNextStepReasonLabel('latest_activity'), '继续刚完成的 activity');
    expect(householdNextStepReasonLabel('top_activity'), '先接上当前最该继续的 activity');
    expect(householdNextStepReasonLabel('other'), '共享下一步已整理好');
    expect(householdSharedAttributionHeadline(ready), '次照护者刚完成一次共享练习');
    expect(householdSharedAttributionDetail(ready), contains('同步回流'));
    expect(householdSharedNextStepDetail(ready), contains('home/song'));
    expect(
      householdSharedUnavailableNextStepMessage(missingNextStep),
      contains('缺少安全入口'),
    );
  });

  testWidgets('shared context card renders missing, ready, and retry states', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      const HouseholdSharedContextCard(surfaceKeyPrefix: 'missing'),
    );

    expect(
      find.byKey(const Key('missing-household-shared-context-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('missing-household-provider-missing')),
      findsOneWidget,
    );

    final readyNotifier = _HouseholdNotifierStub(
      snapshot: HouseholdLocalSnapshot(
        householdId: 'household_1',
        role: HouseholdRole.caregiver,
        sharedContext: _sharedContext(),
        lastPhase: 'shared_context_ready',
        lastAcceptedAt: DateTime.utc(2026, 5, 19, 8, 30),
      ),
    );
    await _pumpApp(
      tester,
      HouseholdSharedContextCard(
        surfaceKeyPrefix: 'ready',
        notifier: readyNotifier,
      ),
    );

    expect(find.byKey(const Key('ready-household-role-chip')), findsOneWidget);
    expect(
      find.byKey(const Key('ready-household-attribution-headline')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('ready-household-next-step-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('ready-household-profile-summary')),
      findsOneWidget,
    );
    expect(find.textContaining('共享宝宝档案'), findsWidgets);

    final revokedNotifier = _HouseholdNotifierStub(
      snapshot: HouseholdLocalSnapshot(
        lastPhase: 'revoke_invite_invalid_session',
        lastVisibleError: '请先登录并完成同意。',
        pendingClearHouseholdScopeFingerprint: List<String>.filled(
          64,
          'a',
        ).join(),
      ),
    );
    await _pumpApp(
      tester,
      HouseholdSharedContextCard(
        surfaceKeyPrefix: 'revoked',
        notifier: revokedNotifier,
      ),
    );
    expect(
      find.byKey(const Key('revoked-household-empty-state')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('revoked-household-role-chip')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('revoked-household-attribution-headline')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('revoked-household-profile-summary')),
      findsNothing,
    );

    final retryNotifier = _HouseholdNotifierStub(
      snapshot: const HouseholdLocalSnapshot(
        role: HouseholdRole.caregiver,
        lastPhase: 'shared_context_unavailable',
        lastVisibleError: '共享上下文暂时不可用。',
      ),
      lastActionKind: HouseholdActionKind.refreshSharedContext,
      message: '稍后再试。',
    );
    await _pumpApp(
      tester,
      HouseholdSharedContextCard(
        surfaceKeyPrefix: 'retry',
        notifier: retryNotifier,
      ),
    );

    expect(
      find.byKey(const Key('retry-household-error-banner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('retry-household-empty-state')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('retry-household-retry-button')));
    await tester.pump();
    expect(retryNotifier.retryCount, 1);

    final refreshNotifier = _HouseholdNotifierStub(
      snapshot: const HouseholdLocalSnapshot(
        role: HouseholdRole.caregiver,
        lastPhase: 'idle',
      ),
    );
    await _pumpApp(
      tester,
      HouseholdSharedContextCard(
        surfaceKeyPrefix: 'refresh',
        notifier: refreshNotifier,
        retryReason: 'manual_widget_retry',
      ),
    );

    await tester.tap(find.byKey(const Key('refresh-household-retry-button')));
    await tester.pump();
    expect(refreshNotifier.refreshCount, 1);
    expect(refreshNotifier.lastRefreshReason, 'manual_widget_retry');
  });

  testWidgets('shared practice overlay covers ready and disabled states', (
    tester,
  ) async {
    var openCount = 0;
    await _pumpApp(
      tester,
      HouseholdSharedPracticeOverlayCard(
        surfaceKeyPrefix: 'overlay-ready',
        sharedContext: _sharedContext(),
        onPressed: () {
          openCount += 1;
        },
      ),
    );

    expect(find.byKey(const Key('overlay-ready-card')), findsOneWidget);
    expect(find.byKey(const Key('overlay-ready-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('overlay-ready-button')));
    await tester.pump();
    expect(openCount, 1);

    await _pumpApp(
      tester,
      HouseholdSharedPracticeOverlayCard(
        surfaceKeyPrefix: 'overlay-disabled',
        sharedContext: _sharedContext(nextStep: _invalidNextStep()),
      ),
    );

    expect(
      find.byKey(const Key('overlay-disabled-disabled-banner')),
      findsOneWidget,
    );
    expect(find.textContaining('缺少安全入口'), findsOneWidget);
  });

  testWidgets(
    'invite card covers missing, primary, caregiver, and retry states',
    (tester) async {
      await _pumpApp(
        tester,
        const HouseholdInviteCard(surfaceKeyPrefix: 'invite-missing'),
      );

      expect(
        find.byKey(const Key('invite-missing-household-invite-missing')),
        findsOneWidget,
      );

      final primaryNotifier = _HouseholdNotifierStub(
        snapshot: const HouseholdLocalSnapshot(
          householdId: 'household_1',
          role: HouseholdRole.primaryCaregiver,
          lastPhase: 'create_invite_created',
          lastVisibleError: '邀请链接已创建。',
        ),
        lastActionKind: HouseholdActionKind.createInvite,
        lastCreatedInvite: _inviteLink(),
      );
      await _pumpApp(
        tester,
        HouseholdInviteCard(
          surfaceKeyPrefix: 'invite-primary',
          notifier: primaryNotifier,
          inviteSource: 'coverage_test',
        ),
      );

      expect(
        find.byKey(const Key('invite-primary-household-invite-url')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('invite-primary-household-invite-meta')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('invite-primary-household-invite-trust-panel')),
        findsOneWidget,
      );
      expect(find.textContaining('次照护者可查看共享宝宝档案摘要'), findsOneWidget);
      expect(find.textContaining('不会包含手机号、设备标识'), findsOneWidget);
      expect(find.textContaining('有效期至'), findsOneWidget);

      final inviteActions = _RecordingInviteLinkActions();
      await _pumpApp(
        tester,
        HouseholdInviteCard(
          surfaceKeyPrefix: 'invite-actions',
          notifier: primaryNotifier,
          inviteLinkActions: inviteActions,
        ),
      );
      await tester.tap(
        find.byKey(const Key('invite-actions-household-invite-copy')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('invite-actions-household-invite-share')),
      );
      await tester.pump();
      expect(inviteActions.copiedUrls, [
        'https://invite.example.com/invite/invite_token_123',
      ]);
      expect(inviteActions.sharedUrls, [
        'https://invite.example.com/invite/invite_token_123',
      ]);

      await _pumpApp(
        tester,
        HouseholdInviteCard(
          surfaceKeyPrefix: 'invite-primary',
          notifier: primaryNotifier,
          inviteSource: 'coverage_test',
        ),
      );
      await tester.tap(
        find.byKey(const Key('invite-primary-household-create-invite')),
      );
      await tester.pump();
      expect(primaryNotifier.createInviteCount, 1);
      expect(primaryNotifier.lastCreateInviteSource, 'coverage_test');

      final caregiverNotifier = _HouseholdNotifierStub(
        snapshot: const HouseholdLocalSnapshot(
          householdId: 'household_1',
          role: HouseholdRole.caregiver,
          lastPhase: 'create_invite_timeout',
          lastVisibleError: '邀请服务暂时不可用。',
        ),
        lastActionKind: HouseholdActionKind.createInvite,
      );
      await _pumpApp(
        tester,
        HouseholdInviteCard(
          surfaceKeyPrefix: 'invite-caregiver',
          notifier: caregiverNotifier,
        ),
      );

      expect(
        find.byKey(const Key('invite-caregiver-household-invite-readonly')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('invite-caregiver-household-invite-retry')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('invite-caregiver-household-invite-retry')),
      );
      await tester.pump();
      expect(caregiverNotifier.retryCount, 1);

      final busyNotifier = _HouseholdNotifierStub(
        snapshot: const HouseholdLocalSnapshot(
          householdId: 'household_1',
          role: HouseholdRole.primaryCaregiver,
          lastPhase: 'idle',
        ),
        isBusy: true,
        lastActionKind: HouseholdActionKind.createInvite,
      );
      await _pumpApp(
        tester,
        HouseholdInviteCard(
          surfaceKeyPrefix: 'invite-busy',
          notifier: busyNotifier,
        ),
      );

      expect(find.text('创建中…'), findsOneWidget);
    },
  );
}

Future<void> _pumpApp(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.build(),
      home: Scaffold(
        body: SafeArea(child: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pump();
}

HouseholdSharedContext _sharedContext({HouseholdSharedNextStep? nextStep}) {
  return HouseholdSharedContext(
    babyProfileSummary: '共享宝宝档案：15 个月，喜欢音乐互动。',
    continuitySummary: '最近 continuity：home/song。',
    gardenSummary: '花园上下文：home/song 已经发芽。',
    practiceArgs: const PracticeRouteArgs(spaceId: 'home', activityId: 'song'),
    actor: const HouseholdSharedActor(
      role: 'caregiver',
      source: 'sync_event',
      result: 'cooperating',
    ),
    nextStep:
        nextStep ??
        const HouseholdSharedNextStep(
          spaceId: 'home',
          activityId: 'song',
          reason: 'latest_activity',
        ),
    latestInteractionAt: DateTime.utc(2026, 5, 19, 8),
    updatedAt: DateTime.utc(2026, 5, 19, 8, 10),
  );
}

HouseholdSharedNextStep _invalidNextStep() {
  return const HouseholdSharedNextStep(
    spaceId: ' ',
    activityId: ' ',
    reason: 'broken',
  );
}

HouseholdInviteLink _inviteLink() {
  return HouseholdInviteLink(
    householdId: 'household_1',
    token: 'invite_token_123',
    inviteUrl: 'https://invite.example.com/invite/invite_token_123',
    role: HouseholdRole.caregiver,
    source: 'coverage_test',
    expiresAt: DateTime.utc(2026, 5, 20, 8),
  );
}

class _HouseholdNotifierStub {
  _HouseholdNotifierStub({
    required this.snapshot,
    this.isBusy = false,
    this.message,
    this.lastActionKind = HouseholdActionKind.none,
    this.lastCreatedInvite,
  });

  final HouseholdLocalSnapshot snapshot;
  final bool isBusy;
  final String? message;
  final HouseholdActionKind lastActionKind;
  final HouseholdInviteLink? lastCreatedInvite;
  int createInviteCount = 0;
  int retryCount = 0;
  int refreshCount = 0;
  String? lastCreateInviteSource;
  String? lastRefreshReason;

  Future<void> createInvite({String source = 'household_settings'}) async {
    createInviteCount += 1;
    lastCreateInviteSource = source;
  }

  Future<bool> retryLastAction() async {
    retryCount += 1;
    return true;
  }

  Future<HouseholdLocalSnapshot> refreshSharedContext({
    String reason = 'manual_refresh',
  }) async {
    refreshCount += 1;
    lastRefreshReason = reason;
    return snapshot;
  }
}

class _RecordingInviteLinkActions implements HouseholdInviteLinkActions {
  final List<String> copiedUrls = [];
  final List<String> sharedUrls = [];

  @override
  Future<void> copy(String inviteUrl) async => copiedUrls.add(inviteUrl);

  @override
  Future<void> share(String inviteUrl) async => sharedUrls.add(inviteUrl);
}
