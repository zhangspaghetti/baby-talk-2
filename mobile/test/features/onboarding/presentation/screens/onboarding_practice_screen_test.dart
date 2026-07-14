import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/features/onboarding/data/services/scene_phrase_service.dart';
import 'package:mobile/features/onboarding/domain/models/practice_scene.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_session_notifier.dart';
import 'package:mobile/features/onboarding/presentation/screens/onboarding_practice_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'onboarding practice fits 390x844dp at 1.3x in phrase and reaction states',
    (tester) async {
      _setViewport(tester, const Size(390, 844), textScale: 1.3);
      final notifier = OnboardingSessionNotifier(
        phraseService: ScenePhraseService(),
      )..selectScene(PracticeScene.bath);

      await tester.pumpWidget(_buildSubject(notifier));
      await tester.pump();

      _expectNoFlutterException(tester);
      await _expectVisibleOrScrollable(tester, find.textContaining('我 说 了'));
      expect(find.text('I love bath time with you.'), findsOneWidget);
      expect(find.text('我喜欢和你一起洗澡。'), findsOneWidget);

      await tester.tap(find.textContaining('我 说 了'));
      await tester.pump();

      _expectNoFlutterException(tester);
      for (final finder in [
        find.textContaining('我 说 了'),
        find.text('开心回应'),
        find.text('玩水了'),
        find.text('没反应也没关系'),
      ]) {
        await _expectVisibleOrScrollable(tester, finder);
      }
    },
  );
}

Widget _buildSubject(OnboardingSessionNotifier notifier) {
  return ProviderScope(
    overrides: [onboardingSessionProvider.overrideWith((ref) => notifier)],
    child: MaterialApp(
      theme: AppTheme.build(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const OnboardingPracticeScreen(),
    ),
  );
}

void _setViewport(WidgetTester tester, Size size, {double textScale = 1.0}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  tester.binding.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.binding.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> _expectVisibleOrScrollable(
  WidgetTester tester,
  Finder finder,
) async {
  expect(finder, findsAtLeastNWidgets(1));
  await tester.ensureVisible(finder.first);
  await tester.pump();
  expect(finder, findsAtLeastNWidgets(1));
}

void _expectNoFlutterException(WidgetTester tester) {
  final exception = tester.takeException();
  expect(
    exception,
    isNull,
    reason: exception is FlutterError ? exception.toStringDeep() : '$exception',
  );
}
