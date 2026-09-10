import 'package:mobile/features/care_entry/contract/onboarding_care_turn_continuation.dart';
import 'package:mobile/features/practice/presentation/practice_route_args.dart';

OnboardingCareTurnRouteArgs onboardingCareTurnRouteArgs(
  OnboardingCareTurnHandoff handoff,
) {
  return OnboardingCareTurnRouteArgs(
    completionId: handoff.completionId,
    spaceId: handoff.spaceId,
    activityId: handoff.activityId,
    entryTitle: handoff.entryTitle,
    utteranceId: handoff.utteranceId,
    english: handoff.english,
    chinese: handoff.chinese,
    source: handoff.source,
  );
}
