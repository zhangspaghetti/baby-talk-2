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

  testWidgets('care turn exposes next support before entering the real trace', (
    tester,
  ) async {
    await harness.pumpAtStep(tester, OnboardingFlowStep.careTurn);

    await tester.tap(find.byKey(const Key('care-turn-said-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-reaction-hesitant')));
    await tester.pump();
    await tester.pump();

    expect(harness.notifier.step, OnboardingFlowStep.careTurn);
    expect(find.byKey(const Key('care-turn-next-support')), findsOneWidget);
    expect(
      find.text(harness.notifier.careTurn!.nextSupportUtterance!.english),
      findsOneWidget,
    );
    expect(find.byKey(const Key('care-turn-trace-continue')), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('care-turn-trace-continue')),
    );
    await tester.tap(find.byKey(const Key('care-turn-trace-continue')));
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
    _expectSemanticButton(
      tester,
      find.byKey(const Key('care-turn-listen-once')),
      label: '听一下',
    );
  });

  testWidgets('reaction retry reuses the original local event ID', (
    tester,
  ) async {
    await harness.pumpAtStep(tester, OnboardingFlowStep.careTurn);
    harness.failNextReactionWrite();

    await tester.tap(find.byKey(const Key('care-turn-said-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-reaction-hesitant')));
    await tester.pump();

    expect(find.byKey(const Key('care-turn-retry-reaction')), findsOneWidget);
    await tester.tap(find.byKey(const Key('care-turn-retry-reaction')));
    await tester.pumpAndSettle();

    expect(harness.receivedReactionLocalEventIds, <String?>[
      'evt_onboarding_screen',
      'evt_onboarding_screen',
    ]);
  });

  testWidgets(
    'trace persistence failure exposes a save retry instead of continue',
    (tester) async {
      await harness.pumpAtStep(tester, OnboardingFlowStep.careTurn);
      harness.failNextConfirmedTracePersistence();

      await tester.tap(find.byKey(const Key('care-turn-said-button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('care-reaction-hesitant')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('care-turn-retry-trace-persistence')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('care-turn-trace-continue')), findsNothing);

      final retryFinder = find.byKey(
        const Key('care-turn-retry-trace-persistence'),
      );
      await tester.ensureVisible(retryFinder);
      await tester.tap(retryFinder);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('care-turn-trace-continue')), findsOneWidget);
    },
  );

  testWidgets(
    'starter phrase persistence failure recovers without restarting onboarding',
    (tester) async {
      await harness.pumpAtStep(tester, OnboardingFlowStep.currentMoment);
      harness.failNextStarterPhrasePersistence();
      final moment = harness.notifier.availableMoments.first;

      await tester.tap(
        find.byKey(
          Key('onboarding-moment-${moment.spaceId}-${moment.activityId}'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('care-turn-retry-starter-phrase-persistence')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('care-turn-choose-another-moment')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('care-reaction-hesitant')), findsNothing);

      await tester.tap(
        find.byKey(const Key('care-turn-retry-starter-phrase-persistence')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('care-turn-said-button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('care-reaction-hesitant')));
      await tester.pumpAndSettle();

      expect(harness.receivedReactionLocalEventIds, <String?>[
        'evt_onboarding_screen',
      ]);
    },
  );

  testWidgets('unavailable moment can return to moment selection', (
    tester,
  ) async {
    await harness.pumpAtStep(tester, OnboardingFlowStep.currentMoment);
    harness.failNextMomentLoad();
    final moment = harness.notifier.availableMoments.first;

    await tester.tap(
      find.byKey(
        Key('onboarding-moment-${moment.spaceId}-${moment.activityId}'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('care-turn-choose-another-moment')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('care-turn-choose-another-moment')));
    await tester.pumpAndSettle();

    expect(harness.notifier.step, OnboardingFlowStep.currentMoment);
  });

  testWidgets('all M1 actions expose named semantic buttons in flow order', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await harness.pumpAtStep(tester, OnboardingFlowStep.age);
    for (final suffix in <String>['0-6', '7-12', '1-2', '2-3']) {
      _expectSemanticButton(tester, find.byKey(Key('onboarding-age-$suffix')));
    }
    await tester.tap(find.byKey(const Key('onboarding-age-1-2')));
    await tester.tap(find.byKey(const Key('onboarding-primary-action')));
    await tester.pumpAndSettle();

    for (final moment in harness.notifier.availableMoments) {
      _expectSemanticButton(
        tester,
        find.byKey(Key('onboarding-scene-${moment.activityId}')),
      );
    }
    final firstMoment = harness.notifier.availableMoments.first;
    await tester.tap(
      find.byKey(Key('onboarding-scene-${firstMoment.activityId}')),
    );
    await tester.tap(find.byKey(const Key('onboarding-primary-action')));
    await tester.pumpAndSettle();

    for (final suffix in <String>[
      'first-words',
      'more-natural',
      'daily-habit',
    ]) {
      _expectSemanticButton(tester, find.byKey(Key('onboarding-goal-$suffix')));
    }
    await tester.tap(find.byKey(const Key('onboarding-goal-more-natural')));
    await tester.tap(find.byKey(const Key('onboarding-primary-action')));
    await tester.pumpAndSettle();

    final momentFinder = find.byKey(
      Key('onboarding-moment-${firstMoment.spaceId}-${firstMoment.activityId}'),
    );
    await tester.ensureVisible(momentFinder);
    await tester.tap(momentFinder);
    await tester.pumpAndSettle();

    _expectSemanticButton(
      tester,
      find.byKey(const Key('care-turn-listen-once')),
      label: '听一下',
    );
    _expectSemanticButton(
      tester,
      find.byKey(const Key('care-turn-said-button')),
      label: '我说了',
    );
    expect(find.byType(Image), findsNothing);

    await tester.tap(find.byKey(const Key('care-turn-said-button')));
    await tester.pump();
    final reactionKeys = <Key>[
      const Key('care-reaction-cooperating'),
      const Key('care-reaction-hesitant'),
      const Key('care-reaction-resisting'),
      const Key('care-reaction-no_response'),
      const Key('care-reaction-other'),
    ];
    final reactionLabels = <String>['配合', '犹豫', '不想', '没反应', '其他'];
    for (var index = 0; index < reactionKeys.length; index++) {
      _expectSemanticButton(
        tester,
        find.byKey(reactionKeys[index]),
        label: reactionLabels[index],
      );
    }
    final reactionRow = tester.widget<Wrap>(find.byType(Wrap));
    expect(
      reactionRow.children.map((child) => child.key).toList(),
      reactionKeys,
    );

    await tester.tap(find.byKey(const Key('care-reaction-hesitant')));
    await tester.pump();
    await tester.pump();
    final nextEnglish =
        harness.notifier.careTurn!.nextSupportUtterance!.english;
    expect(find.bySemanticsLabel(nextEnglish), findsOneWidget);
    _expectSemanticButton(
      tester,
      find.byKey(const Key('care-turn-trace-continue')),
      label: '继续',
    );
    await tester.ensureVisible(
      find.byKey(const Key('care-turn-trace-continue')),
    );
    await tester.tap(find.byKey(const Key('care-turn-trace-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-primary-action')));
    await tester.pumpAndSettle();

    _expectSemanticButton(
      tester,
      find.byKey(const Key('onboarding-primary-action')),
      label: '保存并继续',
    );
    _expectSemanticButton(
      tester,
      find.byKey(const Key('onboarding-secondary-action')),
      label: '暂时不用',
    );
    semantics.dispose();
  });

  testWidgets('signed-in account save completes without opening account', (
    tester,
  ) async {
    await harness.pumpAtStep(tester, OnboardingFlowStep.accountInvitation);

    await tester.tap(find.byKey(const Key('onboarding-primary-action')));
    await tester.pumpAndSettle();

    expect(harness.accountRoutePushCount, 0);
    expect(harness.shellNavigationCount, 1);
  });

  testWidgets('temporary local choice completes without opening account', (
    tester,
  ) async {
    await harness.pumpAtStep(tester, OnboardingFlowStep.accountInvitation);

    await tester.tap(find.byKey(const Key('onboarding-secondary-action')));
    await tester.pumpAndSettle();

    expect(harness.accountRoutePushCount, 0);
    expect(harness.shellNavigationCount, 1);
  });

  testWidgets(
    'pending account save disables both exits and opens one account route',
    (tester) async {
      await harness.dispose();
      harness = await OnboardingFlowScreenHarness.create(signedIn: false);
      await harness.pumpAtStep(tester, OnboardingFlowStep.accountInvitation);
      final writeGate = harness.holdNextContinuationWrite();

      await tester.tap(find.byKey(const Key('onboarding-primary-action')));
      await tester.tap(find.byKey(const Key('onboarding-primary-action')));
      await tester.pump();

      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('onboarding-primary-action')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const Key('onboarding-secondary-action')),
            )
            .onPressed,
        isNull,
      );
      expect(harness.continuationWriteCount, 1);

      writeGate.complete();
      await tester.pumpAndSettle();

      expect(harness.accountRoutePushCount, 1);
      expect(
        harness.accountEntryOrigin,
        AccountEntryOrigin.onboardingContinuation,
      );
      expect(harness.shellNavigationCount, 0);
    },
  );

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

    await tester.ensureVisible(
      find.byKey(const Key('onboarding-primary-action')),
    );

    expect(find.byKey(const Key('onboarding-primary-action')), findsOneWidget);
  });

  testWidgets('reduced motion still exposes the next-support transition', (
    tester,
  ) async {
    await harness.pumpAtStep(
      tester,
      OnboardingFlowStep.careTurn,
      disableAnimations: true,
    );

    await tester.tap(find.byKey(const Key('care-turn-said-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('care-reaction-hesitant')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('care-turn-next-support')), findsOneWidget);
    expect(find.byKey(const Key('care-turn-trace-continue')), findsOneWidget);
  });
}

void _expectSemanticButton(
  WidgetTester tester,
  Finder finder, {
  String? label,
}) {
  final semantics = tester.getSemantics(finder);
  expect(semantics.flagsCollection.isButton, isTrue);
  expect(semantics.label.trim(), isNotEmpty);
  if (label != null) {
    expect(semantics.label, contains(label));
  }
}
