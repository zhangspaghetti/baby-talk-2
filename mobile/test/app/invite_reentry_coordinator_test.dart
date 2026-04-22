import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/invite_reentry_coordinator.dart';
import 'package:mobile/features/household/domain/models/household_role.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';

void main() {
  group('InviteReentryParser', () {
    test('合法 invite link 会映射到 household accept seam', () {
      final decision = InviteReentryParser.parse(
        Uri.parse(
          'babytalk://invite/open?token=invite_token_1234&source=invite_link&role=caregiver',
        ),
      );

      expect(decision.dispatchTarget, InviteReentryDispatchTarget.acceptInvite);
      expect(decision.shouldAcceptInvite, isTrue);
      expect(decision.message, 'invite re-entry ready');
      expect(decision.acceptCommand, isNotNull);
      expect(decision.acceptCommand!.token, 'invite_token_1234');
      expect(decision.acceptCommand!.source, 'invite_link');
      expect(decision.acceptCommand!.roleHint, HouseholdRole.caregiver);
    });

    test('非法 scheme / token / role / query 时只会落到 shell fallback', () {
      final wrongScheme = InviteReentryParser.parse(
        Uri.parse(
          'https://invite.example.com/open?token=invite_token_1234&source=invite_link&role=caregiver',
        ),
      );
      expect(
        wrongScheme.dispatchTarget,
        InviteReentryDispatchTarget.shellFallback,
      );
      expect(wrongScheme.acceptCommand, isNull);
      expect(wrongScheme.message, contains('babytalk://invite/open'));

      final malformedToken = InviteReentryParser.parse(
        Uri.parse(
          'babytalk://invite/open?token=bad*&source=invite_link&role=caregiver',
        ),
      );
      expect(
        malformedToken.dispatchTarget,
        InviteReentryDispatchTarget.shellFallback,
      );
      expect(malformedToken.message, contains('有效 token'));

      final missingRole = InviteReentryParser.parse(
        Uri.parse(
          'babytalk://invite/open?token=invite_token_1234&source=invite_link',
        ),
      );
      expect(
        missingRole.dispatchTarget,
        InviteReentryDispatchTarget.shellFallback,
      );
      expect(missingRole.message, contains('角色信息'));

      final extraQuery = InviteReentryParser.parse(
        Uri.parse(
          'babytalk://invite/open?token=invite_token_1234&source=invite_link&role=caregiver&spaceId=daily_care',
        ),
      );
      expect(
        extraQuery.dispatchTarget,
        InviteReentryDispatchTarget.shellFallback,
      );
      expect(extraQuery.message, contains('不受支持的参数'));
    });
  });

  group('InviteReentryCoordinator', () {
    test('acceptUri + markHandled 会记录最后一次安全回流范围', () {
      final coordinator = InviteReentryCoordinator();
      final uri = Uri.parse(
        'babytalk://invite/open?token=invite_token_1234&source=invite_link&role=caregiver',
      );

      final decision = coordinator.acceptUri(uri);
      expect(decision.dispatchTarget, InviteReentryDispatchTarget.acceptInvite);
      expect(
        coordinator.pendingTarget,
        InviteReentryDispatchTarget.acceptInvite,
      );

      final command = coordinator.takePendingAcceptCommand();
      expect(command, isNotNull);
      expect(command!.token, 'invite_token_1234');
      expect(coordinator.pendingTarget, InviteReentryDispatchTarget.none);

      final routedArgs = PracticeRouteArgs(
        spaceId: 'daily_care',
        activityId: 'bath_time',
        shareToken: command.token,
        entrySource: PracticeRouteEntrySource.inviteReentry,
      );
      coordinator.markHandled(args: routedArgs);
      expect(coordinator.handledRouteCount, 1);
      expect(coordinator.lastHandledLink, uri.replace(fragment: ''));
      expect(coordinator.lastHandledScopeLabel, 'daily_care/bath_time');
      expect(coordinator.lastErrorSurface, isNull);
      expect(coordinator.displayMessage, isNull);
    });

    test('非法 link 会触发 shell fallback，重复 link 会被忽略', () {
      final coordinator = InviteReentryCoordinator();
      final invalidUri = Uri.parse(
        'babytalk://invite/open?token=invite_token_1234&source=invite_link',
      );

      final invalidDecision = coordinator.acceptUri(invalidUri);
      expect(
        invalidDecision.dispatchTarget,
        InviteReentryDispatchTarget.shellFallback,
      );
      expect(
        coordinator.pendingTarget,
        InviteReentryDispatchTarget.shellFallback,
      );
      expect(coordinator.lastErrorSurface, contains('角色信息'));
      expect(coordinator.displayMessage, contains('角色信息'));
      expect(coordinator.takePendingShellFallback(), isTrue);

      coordinator.markFallback(message: '邀请链接不可用，已停留在首页安全入口。');
      expect(coordinator.shellFallbackCount, 1);
      expect(coordinator.lastErrorSurface, contains('首页安全入口'));

      final validUri = Uri.parse(
        'babytalk://invite/open?token=invite_token_1234&source=invite_link&role=caregiver',
      );
      final firstDecision = coordinator.acceptUri(validUri);
      expect(
        firstDecision.dispatchTarget,
        InviteReentryDispatchTarget.acceptInvite,
      );
      final command = coordinator.takePendingAcceptCommand();
      coordinator.markHandled(
        args: PracticeRouteArgs(
          spaceId: 'daily_care',
          activityId: 'bath_time',
          shareToken: command!.token,
          entrySource: PracticeRouteEntrySource.inviteReentry,
        ),
      );

      final duplicateDecision = coordinator.acceptUri(validUri);
      expect(
        duplicateDecision.dispatchTarget,
        InviteReentryDispatchTarget.none,
      );
      expect(duplicateDecision.message, contains('重复照护邀请链接'));
      expect(coordinator.handledRouteCount, 1);
      expect(coordinator.pendingTarget, InviteReentryDispatchTarget.none);
    });
  });
}
