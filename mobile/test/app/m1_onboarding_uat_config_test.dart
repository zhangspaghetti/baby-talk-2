import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/uat/m1_onboarding_uat_config.dart';

void main() {
  group('M1OnboardingUatConfig', () {
    test(
      'explicit response-lost mode is enabled only for a non-release UAT build',
      () {
        final debugConfig = M1OnboardingUatConfig.forTesting(
          uatRequested: true,
          isReleaseBuild: false,
          modeWireValue: 'response_lost_once',
        );
        final releaseConfig = M1OnboardingUatConfig.forTesting(
          uatRequested: true,
          isReleaseBuild: true,
          modeWireValue: 'response_lost_once',
        );

        expect(
          debugConfig.mode,
          M1OnboardingReactionResponseMode.responseLostOnce,
        );
        expect(debugConfig.isResponseLossEnabled, isTrue);
        expect(releaseConfig.isResponseLossEnabled, isFalse);
      },
    );

    test('normal and recorded-success modes never discard a response', () {
      final normal = M1OnboardingUatConfig.forTesting(
        uatRequested: true,
        isReleaseBuild: false,
        modeWireValue: 'normal',
      );
      final recordedSuccess = M1OnboardingUatConfig.forTesting(
        uatRequested: true,
        isReleaseBuild: false,
        modeWireValue: 'record_success',
      );

      expect(normal.isEnabled, isFalse);
      expect(recordedSuccess.isEnabled, isTrue);
      expect(recordedSuccess.isResponseLossEnabled, isFalse);
    });
  });
}
