import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers/repository_providers.dart';
import 'package:mobile/features/onboarding/data/services/scene_phrase_service.dart';
import 'package:mobile/features/onboarding/presentation/onboarding_session_notifier.dart';
import 'package:mobile/features/onboarding/presentation/screens/onboarding_name_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

void main() {
  Widget buildSubject(OnboardingSessionNotifier notifier) {
    return ProviderScope(
      overrides: [onboardingSessionProvider.overrideWith((ref) => notifier)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const OnboardingNameScreen(),
      ),
    );
  }

  testWidgets('shows optional name input and save button', (tester) async {
    final notifier = OnboardingSessionNotifier(
      phraseService: ScenePhraseService(),
    );
    await tester.pumpWidget(buildSubject(notifier));

    expect(find.byType(TextField), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('保存'), findsOneWidget);
  });

  testWidgets('save button is available when name is empty', (tester) async {
    final notifier = OnboardingSessionNotifier(
      phraseService: ScenePhraseService(),
    );
    await tester.pumpWidget(buildSubject(notifier));

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('onboarding-name-next')), findsOneWidget);
  });
}
