import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/account/presentation/screens/account_entry_screen.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_flow_models.dart';

import 'onboarding_flow_screen_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OnboardingFlowScreenHarness harness;

  setUp(() async {
    harness = await OnboardingFlowScreenHarness.create();
  });

  tearDown(() async {
    await harness.dispose();
  });

  testWidgets(
    'selection cards do not advance until the bottom CTA is pressed',
    (tester) async {
      await harness.pumpAtStep(tester, OnboardingFlowStep.age);

      await tester.tap(find.byKey(const Key('onboarding-age-1-2')));
      await tester.pump();

      expect(harness.notifier.step, OnboardingFlowStep.age);

      await tester.tap(find.byKey(const Key('onboarding-primary-action')));
      await tester.pumpAndSettle();

      expect(harness.notifier.step, OnboardingFlowStep.scenePreferences);
    },
  );

  testWidgets('scene CTA shows the approved required-selection copy', (
    tester,
  ) async {
    await harness.pumpAtStep(tester, OnboardingFlowStep.scenePreferences);

    await tester.tap(find.byKey(const Key('onboarding-primary-action')));
    await tester.pump();

    expect(find.text('至少选一个常见照护时刻。'), findsOneWidget);
  });

  testWidgets('care turn uses formal reaction keys and reaches a real trace', (
    tester,
  ) async {
    await harness.pumpAtStep(tester, OnboardingFlowStep.careTurn);

    await tester.tap(find.byKey(const Key('care-turn-said-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-reaction-hesitant')));
    await tester.pump();
    await tester.pump();

    expect(harness.notifier.step, OnboardingFlowStep.trace);
    expect(harness.notifier.flowSnapshot.traceEventKey, isNotEmpty);
    expect(harness.notifier.flowSnapshot.pendingLocalEventId, isNull);
  });

  testWidgets('audio failure keeps the said action enabled', (tester) async {
    harness.audioController.failNextPlay = true;
    await harness.pumpAtStep(tester, OnboardingFlowStep.careTurn);

    await tester.tap(find.byKey(const Key('care-turn-listen-once')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('care-turn-audio-error')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('care-turn-said-button')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'account save returns from typed account route and enters shell',
    (tester) async {
      await harness.pumpAtStep(tester, OnboardingFlowStep.accountInvitation);

      await tester.tap(find.byKey(const Key('onboarding-primary-action')));
      await tester.pumpAndSettle();

      expect(harness.accountRoutePushCount, 1);

      harness.completeAccountRoute(AccountEntryResult.signedIn);
      await tester.pumpAndSettle();

      expect(harness.shellNavigationCount, 1);
    },
  );

  testWidgets('temporary local choice completes without opening account', (
    tester,
  ) async {
    await harness.pumpAtStep(tester, OnboardingFlowStep.accountInvitation);

    await tester.tap(find.byKey(const Key('onboarding-secondary-action')));
    await tester.pumpAndSettle();

    expect(harness.accountRoutePushCount, 0);
    expect(harness.shellNavigationCount, 1);
  });

  testWidgets('1.3 text scale remains scrollable at 390 by 844', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await harness.pumpAtStep(
      tester,
      OnboardingFlowStep.scenePreferences,
      textScaler: const TextScaler.linear(1.3),
    );

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('onboarding-primary-action')), findsOneWidget);
  });
}
