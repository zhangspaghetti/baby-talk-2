import 'package:flutter/foundation.dart';
import 'package:mobile/app/uat/m1_onboarding_uat_config.dart';
import 'package:mobile/features/care_path/data/repositories/care_path_repository.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

/// Debug/profile-only post-write response-loss injector for M1 UAT.
///
/// It observes a completed [PracticeRepository.recordReaction] call through
/// [CarePathRepository], records only redacted proof, then drops the first
/// response when explicitly requested by compile-time UAT defines.
class M1OnboardingResponseLossHarness {
  M1OnboardingResponseLossHarness._({
    required PracticeRepository practiceRepository,
    required M1OnboardingUatConfig config,
  }) : _practiceRepository = practiceRepository,
       _config = config;

  final PracticeRepository _practiceRepository;
  final M1OnboardingUatConfig _config;
  var _hasDroppedResponse = false;

  static M1OnboardingResponseLossHarness? fromDartDefines({
    required PracticeRepository practiceRepository,
  }) {
    final config = M1OnboardingUatConfig.fromDartDefines();
    if (!config.isEnabled) {
      return null;
    }
    return M1OnboardingResponseLossHarness._(
      practiceRepository: practiceRepository,
      config: config,
    );
  }

  Future<void> afterReactionRecorded(InteractionEventPayload event) async {
    final inspection = await _practiceRepository.inspectEventLog(
      spaceId: event.spaceId,
      activityId: event.activityId,
    );
    debugPrint(
      'm1_uat_unknown_outcome '
      'stage=interaction_written '
      'pendingLocalEventId=stable '
      'interactionEventCount=${inspection.validEvents.length} '
      'mode=${_config.mode.name}',
    );
    if (!_config.isResponseLossEnabled || _hasDroppedResponse) {
      return;
    }
    _hasDroppedResponse = true;
    debugPrint(
      'm1_uat_unknown_outcome '
      'stage=response_lost_once '
      'pendingLocalEventId=stable',
    );
    throw const CarePathResponseLostException();
  }
}
