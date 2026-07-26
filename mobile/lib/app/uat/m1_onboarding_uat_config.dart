import 'package:flutter/foundation.dart';

enum M1OnboardingReactionResponseMode {
  normal,
  recordSuccess,
  responseLostOnce,
}

/// Compile-time gate for the M1 Android fault-injection harness.
///
/// Release builds always resolve this gate to false, even if a caller supplies
/// the UAT dart define. There is intentionally no route, preference, or
/// product UI control for this mode.
class M1OnboardingUatConfig {
  const M1OnboardingUatConfig._({
    required this.uatRequested,
    required this.isReleaseBuild,
    required this.mode,
  });

  static const _uatRequested = bool.fromEnvironment('BABY_TALK_UAT');
  static const _modeWireValue = String.fromEnvironment(
    'M1_UAT_REACTION_RESPONSE_MODE',
    defaultValue: 'normal',
  );

  final bool uatRequested;
  final bool isReleaseBuild;
  final M1OnboardingReactionResponseMode mode;

  bool get isEnabled =>
      uatRequested &&
      !isReleaseBuild &&
      mode != M1OnboardingReactionResponseMode.normal;

  bool get isResponseLossEnabled =>
      isEnabled && mode == M1OnboardingReactionResponseMode.responseLostOnce;

  static M1OnboardingUatConfig fromDartDefines() {
    return M1OnboardingUatConfig._(
      uatRequested: _uatRequested,
      isReleaseBuild: kReleaseMode,
      mode: _modeFromWireValue(_modeWireValue),
    );
  }

  @visibleForTesting
  static M1OnboardingUatConfig forTesting({
    required bool uatRequested,
    required bool isReleaseBuild,
    required String modeWireValue,
  }) {
    return M1OnboardingUatConfig._(
      uatRequested: uatRequested,
      isReleaseBuild: isReleaseBuild,
      mode: _modeFromWireValue(modeWireValue),
    );
  }

  static M1OnboardingReactionResponseMode _modeFromWireValue(String value) {
    return switch (value.trim().toLowerCase()) {
      'record_success' => M1OnboardingReactionResponseMode.recordSuccess,
      'response_lost_once' => M1OnboardingReactionResponseMode.responseLostOnce,
      _ => M1OnboardingReactionResponseMode.normal,
    };
  }
}
