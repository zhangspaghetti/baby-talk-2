import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/e2e_test_harness.dart';

const _isE2e = bool.fromEnvironment('BABY_TALK_E2E', defaultValue: false);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real backend carries V4 onboarding through a Today Care Turn', (
    tester,
  ) async {
    if (!_isE2e) {
      markTestSkipped(
        'Compile with --dart-define=BABY_TALK_E2E=true to enable.',
      );
      return;
    }

    final harness = await E2eTestHarness.create(
      practiceDbName: 'e2e_full_flow',
    );
    addTearDown(harness.dispose);

    await harness.pumpApp(tester);
    await E2eTestHarness.pumpUntilFound(
      tester,
      find.byKey(const Key('care-entry-grid')),
      reason: 'V4 care-entry grid',
    );
    await harness.completeOnboarding(tester);
    expect(find.byKey(const Key('shell-ready')), findsOneWidget);
    await E2eTestHarness.pumpUntilFound(
      tester,
      find.byKey(const Key('home-today-care-node-card')),
      reason: 'Today Care Path after onboarding',
    );

    await harness.completeStarterPractice(tester);
    expect(find.byKey(const Key('home-today-care-node-card')), findsOneWidget);
  });
}
