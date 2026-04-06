import 'package:baby_talk_mobile/data/app_api_client.dart';
import 'package:baby_talk_mobile/screens/scene_coaching_screen.dart';
import 'package:baby_talk_mobile/state/app_state.dart';
import 'package:baby_talk_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:baby_talk_mobile/app.dart';

void main() {
  testWidgets('completes onboarding and lands in app shell', (tester) async {
    await tester.pumpWidget(
      const BabyTalkApp(apiClient: DisabledBabyTalkApiClient()),
    );

    expect(find.text('先把第一句说出来'), findsOneWidget);

    await _completeOnboarding(tester);

    expect(find.text('花园速览'), findsOneWidget);
    expect(find.text('小明妈妈，早上好'), findsOneWidget);
    expect(find.text('阶段 2: 日常对话 · 8个月'), findsOneWidget);
  });

  testWidgets('opens mentor sheet after onboarding', (tester) async {
    await tester.pumpWidget(
      const BabyTalkApp(apiClient: DisabledBabyTalkApiClient()),
    );

    await _completeOnboarding(tester);

    expect(find.text('花园速览'), findsOneWidget);
    expect(find.byKey(const Key('mentor-fab')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mentor-fab')));
    await tester.pumpAndSettle();

    expect(find.text('小禾老师'), findsOneWidget);
    expect(find.text('马上要洗澡了，先练两句轻快的短语'), findsOneWidget);
  });

  testWidgets('finishes a practice reaction and shows celebration', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) =>
            BabyTalkAppState(apiClient: const DisabledBabyTalkApiClient()),
        child: MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const SceneCoachingScreen(activityId: 'walk'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SceneCoachingScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('scene-reaction-babbled')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('celebration-screen')), findsOneWidget);
    expect(find.text('去看看花园'), findsOneWidget);
  });
}

Future<void> _completeOnboarding(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('onboarding-start-button')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('onboarding-next-button')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('onboarding-next-button')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('onboarding-next-button')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('onboarding-finish-button')));
  await tester.pumpAndSettle();
}
