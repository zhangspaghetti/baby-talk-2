import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/share_reentry_coordinator.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';

void main() {
  group('ShareReentryParser', () {
    test('合法 share link 会映射到既有 PracticeRouteArgs seam', () {
      final decision = ShareReentryParser.parse(
        Uri.parse(
          'babytalk://share/open?token=share_token_1234&spaceId=daily_care&activityId=bath_time',
        ),
      );

      expect(decision.dispatchTarget, ShareReentryDispatchTarget.practice);
      expect(decision.shouldRouteToPractice, isTrue);
      expect(decision.message, 'share re-entry ready');
      expect(decision.practiceArgs, isNotNull);
      expect(decision.practiceArgs!.spaceId, 'daily_care');
      expect(decision.practiceArgs!.activityId, 'bath_time');
      expect(decision.practiceArgs!.shareToken, 'share_token_1234');
      expect(
        decision.practiceArgs!.entrySource,
        PracticeRouteEntrySource.shareReentry,
      );
    });

    test('非法 scheme / token / 缺 scope 时只会落到 shell fallback', () {
      final wrongScheme = ShareReentryParser.parse(
        Uri.parse(
          'https://share.example.com/share/open?token=share_token_1234&spaceId=daily_care&activityId=bath_time',
        ),
      );
      expect(
        wrongScheme.dispatchTarget,
        ShareReentryDispatchTarget.shellFallback,
      );
      expect(wrongScheme.practiceArgs, isNull);
      expect(wrongScheme.message, contains('babytalk://share/open'));

      final malformedToken = ShareReentryParser.parse(
        Uri.parse(
          'babytalk://share/open?token=bad*&spaceId=daily_care&activityId=bath_time',
        ),
      );
      expect(
        malformedToken.dispatchTarget,
        ShareReentryDispatchTarget.shellFallback,
      );
      expect(malformedToken.message, contains('有效 token'));

      final missingScope = ShareReentryParser.parse(
        Uri.parse('babytalk://share/open?token=share_token_1234&spaceId='),
      );
      expect(
        missingScope.dispatchTarget,
        ShareReentryDispatchTarget.shellFallback,
      );
      expect(missingScope.message, contains('练习范围'));
    });
  });

  group('ShareReentryCoordinator', () {
    test('acceptUri + markHandled 会记录最后一次安全回流范围', () {
      final coordinator = ShareReentryCoordinator();
      final uri = Uri.parse(
        'babytalk://share/open?token=share_token_1234&spaceId=daily_care&activityId=bath_time',
      );

      final decision = coordinator.acceptUri(uri);
      expect(decision.dispatchTarget, ShareReentryDispatchTarget.practice);
      expect(coordinator.pendingTarget, ShareReentryDispatchTarget.practice);

      final args = coordinator.takePendingPracticeArgs();
      expect(args, isNotNull);
      expect(args!.scopeLabel, 'daily_care/bath_time');
      expect(coordinator.pendingTarget, ShareReentryDispatchTarget.none);

      coordinator.markHandled(args: args);
      expect(coordinator.handledRouteCount, 1);
      expect(coordinator.lastHandledLink, uri);
      expect(coordinator.lastHandledScopeLabel, 'daily_care/bath_time');
      expect(coordinator.lastErrorSurface, isNull);
      expect(coordinator.displayMessage, isNull);
    });

    test('非法 link 会触发 shell fallback，重复 link 会被忽略', () {
      final coordinator = ShareReentryCoordinator();
      final invalidUri = Uri.parse(
        'babytalk://share/open?token=share_token_1234&spaceId=daily_care',
      );

      final invalidDecision = coordinator.acceptUri(invalidUri);
      expect(
        invalidDecision.dispatchTarget,
        ShareReentryDispatchTarget.shellFallback,
      );
      expect(coordinator.pendingTarget, ShareReentryDispatchTarget.shellFallback);
      expect(coordinator.lastErrorSurface, contains('练习范围'));
      expect(coordinator.displayMessage, contains('练习范围'));
      expect(coordinator.takePendingShellFallback(), isTrue);

      coordinator.markFallback(message: '分享链接不可用，已停留在首页安全入口。');
      expect(coordinator.shellFallbackCount, 1);
      expect(coordinator.lastErrorSurface, contains('首页安全入口'));

      final validUri = Uri.parse(
        'babytalk://share/open?token=share_token_1234&spaceId=daily_care&activityId=bath_time',
      );
      final firstDecision = coordinator.acceptUri(validUri);
      expect(firstDecision.dispatchTarget, ShareReentryDispatchTarget.practice);
      final args = coordinator.takePendingPracticeArgs();
      coordinator.markHandled(args: args!);

      final duplicateDecision = coordinator.acceptUri(validUri);
      expect(duplicateDecision.dispatchTarget, ShareReentryDispatchTarget.none);
      expect(duplicateDecision.message, contains('重复分享链接'));
      expect(coordinator.handledRouteCount, 1);
      expect(coordinator.pendingTarget, ShareReentryDispatchTarget.none);
    });
  });
}
