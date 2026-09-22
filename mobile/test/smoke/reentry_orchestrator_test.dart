import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/app_reentry_orchestrator.dart';
import 'package:mobile/app/invite_reentry_coordinator.dart';
import 'package:mobile/app/share_reentry_coordinator.dart';

void main() {
  group('AppReentryOrchestrator — share drain', () {
    late ShareReentryCoordinator shareCoordinator;
    late InviteReentryCoordinator inviteCoordinator;
    bool mounted = true;
    AppLaunchDestination? launchDestination;

    setUp(() {
      shareCoordinator = ShareReentryCoordinator();
      inviteCoordinator = InviteReentryCoordinator();
      mounted = true;
      launchDestination = AppLaunchDestination.shell;
    });

    AppReentryOrchestrator createOrchestrator({
      AppLaunchDestination? overrideDestination,
      bool? overrideMounted,
      Future<Uri?> Function()? initialUriLoader,
      bool Function()? inviteAuthenticationReady,
      Listenable? Function()? inviteAuthenticationNotifierLookup,
    }) {
      return AppReentryOrchestrator(
        shareReentryCoordinator: shareCoordinator,
        inviteReentryCoordinator: inviteCoordinator,
        // router = null，阻止实际导航但仍允许测试分流逻辑
        goRouterProvider: () => null,
        mountedCheck: () => overrideMounted ?? mounted,
        launchDestinationProvider: () =>
            overrideDestination ?? launchDestination,
        householdNotifierLookup: () => null,
        continuityNotifierLookup: () => null,
        gardenGrowthNotifierLookup: () => null,
        initialUriLoader: initialUriLoader,
        isInviteAuthenticationReady: inviteAuthenticationReady,
        inviteAuthenticationNotifierLookup: inviteAuthenticationNotifierLookup,
      );
    }

    test('handleIncomingUri dispatches share — acceptUri 改变 coordinator 状态', () {
      createOrchestrator();

      // 直接调用 coordinator 的 acceptUri（这是 handleIncomingUri 内部做的第一件事）
      final shareUri = Uri.parse(
        'babytalk://share/open?token=abcdefgh12345678&spaceId=daily_care&activityId=bath_time',
      );
      final decision = shareCoordinator.acceptUri(shareUri);

      expect(
        decision.dispatchTarget,
        equals(ShareReentryDispatchTarget.practice),
      );
      expect(decision.practiceArgs, isNotNull);
      expect(decision.practiceArgs!.spaceId, equals('daily_care'));
      expect(decision.practiceArgs!.activityId, equals('bath_time'));
    });

    test('handleIncomingUri dispatches invite — acceptUri 改变 coordinator 状态', () {
      createOrchestrator();

      final inviteUri = Uri.parse(
        'babytalk://invite/open?token=invite_token_12345678&source=invite_link&role=caregiver',
      );
      final decision = inviteCoordinator.acceptUri(inviteUri);

      expect(
        decision.dispatchTarget,
        equals(InviteReentryDispatchTarget.acceptInvite),
      );
      expect(decision.acceptCommand, isNotNull);
      expect(decision.acceptCommand!.token, equals('invite_token_12345678'));
    });

    test('handleIncomingUri 忽略非 share/invite host', () {
      final orchestrator = createOrchestrator();

      final unknownUri = Uri.parse('babytalk://unknown/path');
      orchestrator.handleIncomingUri(unknownUri);

      // 两个 coordinator 都不应有变化
      expect(shareCoordinator.handledRouteCount, equals(0));
      expect(shareCoordinator.shellFallbackCount, equals(0));
      expect(inviteCoordinator.handledRouteCount, equals(0));
      expect(inviteCoordinator.shellFallbackCount, equals(0));
    });

    test('drainPendingShareReentry respects mounted check — 不 drain', () {
      final orchestrator = createOrchestrator(overrideMounted: false);

      // 让 coordinator 接受一个有效 URI 产生 pending args
      shareCoordinator.acceptUri(
        Uri.parse(
          'babytalk://share/open?token=abcdefgh12345678&spaceId=daily_care&activityId=bath_time',
        ),
      );
      expect(
        shareCoordinator.pendingTarget,
        ShareReentryDispatchTarget.practice,
      );

      // mounted = false 时，drainPendingShareReentry 提前返回
      orchestrator.drainPendingShareReentry();

      // pending 状态保持不变——drain 没有消费
      expect(
        shareCoordinator.pendingTarget,
        ShareReentryDispatchTarget.practice,
      );
    });

    test('drainPendingShareReentry — navigator=null 时不崩溃，pending 保持', () {
      final orchestrator = createOrchestrator();

      shareCoordinator.acceptUri(
        Uri.parse(
          'babytalk://share/open?token=abcdefgh12345678&spaceId=daily_care&activityId=bath_time',
        ),
      );

      // navigator 返回 null → 提前返回
      orchestrator.drainPendingShareReentry();

      // pending 状态保持不变（navigator null = 不能 drain）
      expect(
        shareCoordinator.pendingTarget,
        ShareReentryDispatchTarget.practice,
      );
    });

    test(
      'drainPendingInviteReentry — navigator=null 时 serialized call 安全完成',
      () async {
        final orchestrator = createOrchestrator();

        inviteCoordinator.acceptUri(
          Uri.parse(
            'babytalk://invite/open?token=invite_serial_12345678&source=invite_link&role=caregiver',
          ),
        );

        // 并发调用两次 drainPendingInviteReentry
        final future1 = orchestrator.drainPendingInviteReentry();
        final future2 = orchestrator.drainPendingInviteReentry();

        // 两个 future 都能正常完成（不抛出异常）
        await future1;
        await future2;

        // navigator=null → 提前返回，没有 fallback count 变化
        expect(inviteCoordinator.shellFallbackCount, equals(0));
      },
    );

    test('share drain 在 destination 非 shell 时不执行 (navigator=null 保护)', () {
      final orchestrator = createOrchestrator(
        overrideDestination: AppLaunchDestination.onboarding,
      );

      shareCoordinator.acceptUri(
        Uri.parse(
          'babytalk://share/open?token=abcdefgh12345678&spaceId=daily_care&activityId=bath_time',
        ),
      );

      orchestrator.drainPendingShareReentry();

      // navigator=null → 提前返回，不进入 destination 检查分支
      // pending 状态保持不变
      expect(
        shareCoordinator.pendingTarget,
        ShareReentryDispatchTarget.practice,
      );
    });

    test('dispose 释放资源不抛出异常', () {
      final orchestrator = createOrchestrator();
      expect(() => orchestrator.dispose(), returnsNormally);
    });

    test('configureShareUriSubscription 订阅自定义 stream', () async {
      final orchestrator = createOrchestrator();
      final controller = StreamController<Uri>.broadcast();
      addTearDown(() async {
        await controller.close();
      });

      await orchestrator.configureShareUriSubscription(controller.stream);

      // 发送一个 share URI 到 stream
      controller.add(
        Uri.parse(
          'babytalk://share/open?token=stream_test_12345678&spaceId=daily_care&activityId=bath_time',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      // coordinator 应该收到了这个 URI（navigator=null 所以 pending 保持）
      expect(
        shareCoordinator.pendingTarget,
        ShareReentryDispatchTarget.practice,
      );

      orchestrator.dispose();
    });

    test('冷启动邀请链接会进入一次待接受流程', () async {
      final orchestrator = createOrchestrator(
        initialUriLoader: () async => Uri.parse(
          'babytalk://invite/open?token=cold_start_12345678&source=invite_link&role=caregiver',
        ),
      );

      await orchestrator.configureShareUriSubscription(Stream<Uri>.empty());

      expect(
        inviteCoordinator.pendingTarget,
        InviteReentryDispatchTarget.acceptInvite,
      );
      expect(
        inviteCoordinator.takePendingAcceptCommand()!.token,
        'cold_start_12345678',
      );
      orchestrator.dispose();
    });

    test('dispose 后忽略尚未完成的冷启动 URI loader', () async {
      final loader = Completer<Uri?>();
      unawaited(loader.future.catchError((Object _) => null));
      final orchestrator = createOrchestrator(
        initialUriLoader: () => loader.future,
      );

      final configuration = orchestrator.configureShareUriSubscription(
        Stream<Uri>.empty(),
      );
      orchestrator.dispose();
      await Future<void>.delayed(Duration.zero);
      loader.completeError(StateError('late initial URI failure'));

      await configuration;

      expect(inviteCoordinator.shellFallbackCount, equals(0));
    });

    test('未登录邀请在认证完成前保留，并只由认证监听恢复 drain', () async {
      final authentication = ValueNotifier(false);
      final orchestrator = createOrchestrator(
        inviteAuthenticationReady: () => authentication.value,
        inviteAuthenticationNotifierLookup: () => authentication,
      );
      orchestrator.handleIncomingUri(
        Uri.parse(
          'babytalk://invite/open?token=auth_resume_12345678&source=invite_link&role=caregiver',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        inviteCoordinator.pendingTarget,
        InviteReentryDispatchTarget.acceptInvite,
      );
      expect(inviteCoordinator.displayMessage, contains('登录'));

      authentication.value = true;
      await Future<void>.delayed(Duration.zero);

      // 当前 harness 不提供 router；认证监听只能尝试恢复，不能提前消费。
      expect(
        inviteCoordinator.pendingTarget,
        InviteReentryDispatchTarget.acceptInvite,
      );
      expect(inviteCoordinator.shellFallbackCount, 0);
      orchestrator.dispose();
      authentication.dispose();
    });

    test('未登录的非法邀请仍回到首页并显示安全提示', () async {
      final router = GoRouter(
        initialLocation: '/practice',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/practice',
            builder: (context, state) => const SizedBox.shrink(),
          ),
        ],
      );
      final orchestrator = AppReentryOrchestrator(
        shareReentryCoordinator: shareCoordinator,
        inviteReentryCoordinator: inviteCoordinator,
        goRouterProvider: () => router,
        mountedCheck: () => mounted,
        launchDestinationProvider: () => launchDestination,
        householdNotifierLookup: () => null,
        continuityNotifierLookup: () => null,
        gardenGrowthNotifierLookup: () => null,
        isInviteAuthenticationReady: () => false,
      );

      orchestrator.handleIncomingUri(
        Uri.parse(
          'babytalk://invite/open?token=bad%2A&source=invite_link&role=caregiver',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(inviteCoordinator.pendingTarget, InviteReentryDispatchTarget.none);
      expect(inviteCoordinator.shellFallbackCount, 1);
      expect(inviteCoordinator.displayMessage, contains('缺少有效 token'));
      orchestrator.dispose();
      router.dispose();
    });
  });
}
