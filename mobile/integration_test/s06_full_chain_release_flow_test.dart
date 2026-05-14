import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/features/mentor/domain/models/mentor_fact_event.dart';

import 'support/full_chain_test_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'fresh install 会从真实 app 入口串起 onboarding 到 mentor blocked fallback 全链路 proof',
    (WidgetTester tester) async {
      final harness = await FullChainTestHarness.create();
      addTearDown(() async {
        await harness.disposeMountedApp(tester);
        await harness.dispose();
      });

      await harness.pumpApp(tester);
      await FullChainTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('onboarding-local-only-banner')),
        reason: 'fresh install onboarding banner',
      );

      expect(find.byKey(const Key('boot-route-onboarding')), findsOneWidget);
      expect(find.byKey(const Key('boot-route-shell')), findsNothing);

      await harness.completeOnboarding(tester);
      expect(find.byKey(const Key('shell-ready')), findsOneWidget);
      expect(find.text('${harness.childDisplayName} 的首页'), findsOneWidget);

      await harness.completeStarterPractice(tester);
      expect(find.byKey(const Key('recent-result-summary')), findsOneWidget);
      expect(find.textContaining('All clean. · 宝宝放松'), findsOneWidget);
      expect(find.textContaining('3 条本地记录'), findsOneWidget);
      // Garden items are below recent-result-summary; scroll down to build them.
      await FullChainTestHarness.scrollHomeTo(
        tester,
        find.byKey(const Key('home-garden-mini-entry')),
      );
      expect(find.byKey(const Key('home-garden-mini-entry')), findsOneWidget);
      await FullChainTestHarness.scrollHomeTo(
        tester,
        find.byKey(const Key('home-growth-summary')),
      );
      expect(find.byKey(const Key('home-growth-summary')), findsOneWidget);
      await FullChainTestHarness.waitForGardenProjectionReady(tester);

      await harness.switchShellTab(
        tester,
        label: '花园',
        readyKey: const Key('shell-tab-garden'),
      );
      await FullChainTestHarness.waitForGardenProjectionReady(tester);
      expect(find.byKey(const Key('garden-hero-card')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('garden-patch-daily_care')),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pump();
      await FullChainTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('garden-patch-daily_care')),
        timeout: const Duration(seconds: 30),
        reason: 'garden patch after practice',
      );
      expect(find.byKey(const Key('garden-patch-daily_care')), findsOneWidget);
      expect(find.textContaining('3 次练习事件'), findsOneWidget);

      await harness.switchShellTab(
        tester,
        label: '成长',
        readyKey: const Key('shell-tab-growth'),
      );
      await FullChainTestHarness.waitForGardenProjectionReady(tester);
      expect(find.byKey(const Key('growth-latest-impact')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('growth-space-daily_care')),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pump();
      await FullChainTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('growth-space-daily_care')),
        timeout: const Duration(seconds: 12),
        reason: 'growth projection after practice',
      );
      expect(find.byKey(const Key('growth-space-daily_care')), findsOneWidget);

      await harness.signInAndSync(tester);
      expect(
        find.byKey(const Key('account-status-signed-in-synced')),
        findsOneWidget,
      );
      expect(find.textContaining('登录已完成'), findsWidgets);
      expect(harness.backend.bootstrapCount, greaterThanOrEqualTo(1));
      expect(harness.backend.storedEventCount(harness.installationId), 3);
      expect(find.byKey(const Key('account-close-button')), findsOneWidget);
      // Close button may be below viewport after sign-in adds status widgets.
      await tester.ensureVisible(find.byKey(const Key('account-close-button')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(
        find.byKey(const Key('account-close-button')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      await harness.switchToHomeTab(tester);
      await FullChainTestHarness.scrollHomeToTop(tester);
      // HomeTodaySceneCard fills most of the viewport; HomeRecentResultCard is
      // below the fold.  Scroll down to bring it into view, then wait for it.
      await FullChainTestHarness.scrollHomeTo(
        tester,
        find.byKey(const Key('home-local-only-banner')),
        reason: 'home-local-only-banner',
      );
      await tester.pump();
      await FullChainTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('recent-result-summary')),
        timeout: const Duration(seconds: 30),
        reason: 'recent-result-summary after sign-in sync',
      );
      expect(find.byKey(const Key('recent-result-summary')), findsOneWidget);
      expect(find.textContaining('已同步 3'), findsWidgets);

      final mentorNotifier = await harness.submitMentorPrompt(
        tester,
        prompt: '宝宝一直哭，我可以体罚他吗？ [blocked]',
      );
      expect(find.byKey(const Key('mentor-panel-sheet')), findsOneWidget);
      expect(find.byKey(const Key('mentor-chat-banner')), findsOneWidget);
      expect(
        find.byKey(const Key('mentor-chat-response-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mentor-chat-response-text')),
        findsOneWidget,
      );
      expect(find.textContaining('安全降级'), findsWidgets);
      expect(find.textContaining('code · blocked_fallback'), findsWidgets);
      expect(find.textContaining('phase · blocked_fallback'), findsOneWidget);
      expect(find.textContaining('本地回应'), findsOneWidget);
      expect(mentorNotifier.chatResponseCode, 'blocked_fallback');
      expect(mentorNotifier.chatResponsePhase, 'blocked_fallback');
      expect(mentorNotifier.chatFallbackUsed, isTrue);
      expect(mentorNotifier.chatCorrelationId, isNotEmpty);
      expect(
        harness.backend.mentorRequestsForInstallation(harness.installationId),
        1,
      );

      final syncInspection = await harness.inspectSyncQueue();
      expect(syncInspection.installationId, harness.installationId);
      expect(syncInspection.summary.pendingCount, 0);
      expect(syncInspection.summary.syncedCount, 3);
      expect(syncInspection.summary.failedCount, 0);
      expect(syncInspection.summary.lastSyncPhase, 'batch_ack_applied');

      final mentorFacts = await mentorNotifier.listFactHistory();
      expect(
        mentorFacts.map((fact) => fact.eventType),
        containsAll([
          MentorFactType.panelOpened,
          MentorFactType.chatRequested,
          MentorFactType.chatResponseDelivered,
        ]),
      );
      final deliveredFacts = mentorFacts
          .where(
            (fact) => fact.eventType == MentorFactType.chatResponseDelivered,
          )
          .toList(growable: false);
      expect(deliveredFacts, isNotEmpty);
      expect(deliveredFacts.last.phase, 'blocked_fallback');
      expect(deliveredFacts.last.visibleStatus, 'blocked_fallback');
      expect(deliveredFacts.last.correlationId, isNotEmpty);
    },
  );

  testWidgets(
    'malformed completed snapshot 会停在 boot failure surface，而不是直接跳过 onboarding',
    (WidgetTester tester) async {
      final harness = await FullChainTestHarness.create();
      addTearDown(() async {
        await harness.disposeMountedApp(tester);
        await harness.dispose();
      });

      await harness.pumpApp(
        tester,
        completedSnapshotLoader: () async {
          throw const FormatException('malformed onboarding snapshot');
        },
      );
      await FullChainTestHarness.pumpUntilFound(
        tester,
        find.byKey(const Key('boot-route-gate-failed')),
        timeout: const Duration(seconds: 12),
        reason: 'boot route gate failure',
      );

      expect(find.byKey(const Key('boot-route-gate-failed')), findsOneWidget);
      expect(find.byKey(const Key('boot-route-shell')), findsNothing);
      expect(
        find.byKey(const Key('onboarding-local-only-banner')),
        findsNothing,
      );
      expect(find.textContaining('本地档案读取失败'), findsOneWidget);
    },
  );

  testWidgets('Mentor timeout 会显示可见 banner 与 phase，而不是让聊天流程 hang 住', (
    WidgetTester tester,
  ) async {
    final harness = await FullChainTestHarness.create();
    addTearDown(() async {
      await harness.disposeMountedApp(tester);
      await harness.dispose();
    });

    await harness.pumpApp(tester);
    await harness.completeOnboarding(tester);

    final mentorNotifier = await harness.submitMentorPrompt(
      tester,
      prompt: '宝宝一直哭，我现在该怎么开口？ [timeout]',
    );

    expect(find.byKey(const Key('mentor-chat-banner')), findsOneWidget);
    expect(find.byKey(const Key('mentor-chat-response-card')), findsNothing);
    expect(find.textContaining('超时'), findsWidgets);
    expect(find.textContaining('code · timeout'), findsOneWidget);
    expect(find.textContaining('phase · provider_timeout'), findsOneWidget);
    expect(mentorNotifier.chatResponseText, isNull);
    expect(mentorNotifier.chatResponseCode, 'timeout');
    expect(mentorNotifier.chatResponsePhase, 'provider_timeout');
    expect(mentorNotifier.chatCorrelationId, isNotEmpty);

    await harness.disposeMountedApp(tester);
    final failedFacts = await harness.readMentorFacts(
      eventType: MentorFactType.chatFailed,
    );
    expect(failedFacts, isNotEmpty);
    expect(failedFacts.last.phase, 'provider_timeout');
    expect(failedFacts.last.visibleStatus, 'timeout');
    expect(failedFacts.last.retryable, isTrue);
  });
}
