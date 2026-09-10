import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy M1 onboarding orchestration stays contracted', () {
    const retiredFiles = <String>[
      'lib/app/uat/m1_onboarding_uat_config.dart',
      'lib/app/uat/m1_onboarding_response_loss_harness.dart',
      'lib/features/onboarding/data/local/onboarding_flow_store.dart',
      'lib/features/onboarding/domain/models/onboarding_flow_models.dart',
      'lib/features/onboarding/presentation/onboarding_flow_notifier.dart',
      'lib/features/onboarding/presentation/screens/onboarding_flow_screen.dart',
      'lib/features/onboarding/presentation/widgets/onboarding_design_widgets.dart',
      'lib/features/onboarding/presentation/widgets/onboarding_flow_shell.dart',
      'lib/features/onboarding/presentation/widgets/onboarding_selection_steps.dart',
      'lib/features/onboarding/presentation/widgets/onboarding_trace_step.dart',
      'lib/features/onboarding/presentation/widgets/scene_button.dart',
    ];
    for (final path in retiredFiles) {
      expect(File(path).existsSync(), isFalse, reason: path);
    }

    const retiredSymbols = <String>[
      'OnboardingFlowNotifier',
      'OnboardingFlowScreen',
      'OnboardingFlowSnapshot',
      'OnboardingFlowStore',
      'M1OnboardingUatConfig',
      'M1OnboardingResponseLossHarness',
    ];
    final productionSource = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');
    for (final symbol in retiredSymbols) {
      expect(productionSource, isNot(contains(symbol)), reason: symbol);
    }
  });
}
