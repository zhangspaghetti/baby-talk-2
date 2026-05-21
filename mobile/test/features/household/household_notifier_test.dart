import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/invite_reentry_coordinator.dart';
import 'package:mobile/features/household/data/local/household_local_store.dart';
import 'package:mobile/features/household/data/repositories/household_repository.dart';
import 'package:mobile/features/household/domain/models/household_invite_link.dart';
import 'package:mobile/features/household/domain/models/household_role.dart';
import 'package:mobile/features/household/domain/models/household_shared_context.dart';
import 'package:mobile/features/household/presentation/household_notifier.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HouseholdNotifier', () {
    test('createInvite 成功后会暴露 invite link 与可见 message', () async {
      final repository = _FakeHouseholdRepository()
        ..createInviteResult = HouseholdCreateInviteResult(
          snapshot: const HouseholdLocalSnapshot(
            householdId: 'household_1',
            role: HouseholdRole.primaryCaregiver,
            lastPhase: 'create_invite_created',
          ),
          inviteLink: HouseholdInviteLink(
            householdId: 'household_1',
            token: 'invite_token_1234',
            inviteUrl: 'https://invite.example.com/invite/invite_token_1234',
            role: HouseholdRole.caregiver,
            source: 'household_settings',
            expiresAt: DateTime.utc(2026, 4, 19, 12),
          ),
          message: '邀请链接已创建。',
        );
      final notifier = HouseholdNotifier(repository: repository);
      addTearDown(notifier.dispose);

      final result = await notifier.createInvite();

      expect(result.isSuccess, isTrue);
      expect(notifier.snapshot.householdId, 'household_1');
      expect(notifier.snapshot.role, HouseholdRole.primaryCaregiver);
      expect(notifier.lastCreatedInvite?.token, 'invite_token_1234');
      expect(notifier.message, '邀请链接已创建。');
      expect(notifier.isBusy, isFalse);
      expect(notifier.lastActionKind, HouseholdActionKind.createInvite);
    });

    test(
      'acceptInvite 失败后 retryLastAction 会复用最近 invite command 并恢复 practice seam',
      () async {
        final repository = _FakeHouseholdRepository();
        repository.acceptQueue.add(
          const HouseholdInviteAcceptResult(
            snapshot: HouseholdLocalSnapshot(
              lastPhase: 'accept_invite_timeout',
              lastVisibleError: '请求超时，已停留在安全 fallback。',
            ),
            message: '请求超时，已停留在安全 fallback。',
          ),
        );
        repository.acceptQueue.add(
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
        );
        final notifier = HouseholdNotifier(repository: repository);
        addTearDown(notifier.dispose);
        const command = InviteReentryAcceptCommand(
          token: 'invite_token_1234',
          source: 'invite_link',
          roleHint: HouseholdRole.caregiver,
        );

        final first = await notifier.acceptInviteFromReentry(command);
        expect(first.shouldRouteToPractice, isFalse);
        expect(notifier.snapshot.lastPhase, 'accept_invite_timeout');
        expect(notifier.message, contains('安全 fallback'));

        final retried = await notifier.retryLastAction();
        expect(retried, isTrue);
        expect(notifier.snapshot.lastPhase, 'accept_ready');
        expect(notifier.snapshot.householdId, 'household_1');
        expect(notifier.message, contains('共享练习'));
        expect(repository.lastAcceptedToken, 'invite_token_1234');
        expect(repository.acceptCallCount, 2);
      },
    );

    test('refreshSharedContext 会暴露 isBusy 并保护重复触发', () async {
      final repository = _FakeHouseholdRepository();
      repository.refreshCompleter = Completer<HouseholdLocalSnapshot>();
      final notifier = HouseholdNotifier(repository: repository);
      addTearDown(notifier.dispose);

      final firstFuture = notifier.refreshSharedContext(
        reason: 'manual_refresh',
      );
      final secondFuture = notifier.refreshSharedContext(
        reason: 'manual_refresh',
      );
      await Future<void>.delayed(Duration.zero);

      expect(notifier.isBusy, isTrue);
      expect(notifier.message, contains('刷新共享上下文'));
      expect(repository.refreshCallCount, 1);

      repository.refreshCompleter!.complete(
        HouseholdLocalSnapshot(
          householdId: 'household_1',
          role: HouseholdRole.caregiver,
          sharedContext: _sharedContext(),
          lastPhase: 'shared_context_ready',
          lastAcceptedAt: DateTime.utc(2026, 4, 16, 12),
        ),
      );
      final first = await firstFuture;
      final second = await secondFuture;

      expect(first.householdId, 'household_1');
      expect(second.householdId, 'household_1');
      expect(notifier.isBusy, isFalse);
      expect(notifier.snapshot.lastPhase, 'shared_context_ready');
      expect(repository.refreshCallCount, 1);
      expect(notifier.lastActionKind, HouseholdActionKind.refreshSharedContext);
    });
  });
}

class _FakeHouseholdRepository implements HouseholdRepository {
  HouseholdLocalSnapshot loadSnapshotResult = HouseholdLocalSnapshot.empty;
  HouseholdCreateInviteResult? createInviteResult;
  final List<HouseholdInviteAcceptResult> acceptQueue =
      <HouseholdInviteAcceptResult>[];
  HouseholdLocalSnapshot refreshResult = HouseholdLocalSnapshot.empty;
  Completer<HouseholdLocalSnapshot>? refreshCompleter;
  int refreshCallCount = 0;
  int acceptCallCount = 0;
  String? lastAcceptedToken;

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
    acceptCallCount += 1;
    lastAcceptedToken = token;
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
  Future<void> deleteLocalSnapshotForLifecycle() async {}

  @override
  Future<HouseholdLocalSnapshot> loadSnapshot() async {
    return loadSnapshotResult;
  }

  @override
  Future<HouseholdLocalSnapshot> refreshSharedContext({
    String reason = 'manual_refresh',
  }) {
    refreshCallCount += 1;
    final completer = refreshCompleter;
    if (completer != null) {
      return completer.future;
    }
    return Future<HouseholdLocalSnapshot>.value(refreshResult);
  }
}

HouseholdSharedContext _sharedContext() {
  return HouseholdSharedContext(
    babyProfileSummary: '共享宝宝档案：家庭已同步 2 条互动。',
    continuitySummary: '最近 continuity：daily_care/bath_time。',
    gardenSummary: '花园上下文：daily_care/bath_time 已累计 2 条互动。',
    practiceArgs: const PracticeRouteArgs(
      spaceId: 'daily_care',
      activityId: 'bath_time',
    ),
    latestInteractionAt: DateTime.utc(2026, 4, 16, 11, 50),
    updatedAt: DateTime.utc(2026, 4, 16, 12),
  );
}
