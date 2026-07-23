import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/domain/models/onboarding_flow_models.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

void main() {
  test(
    'flow snapshot round-trips the stable event identity without phrase copy',
    () {
      final snapshot = OnboardingFlowSnapshot(
        step: OnboardingFlowStep.careTurn,
        ageBucket: OnboardingAgeBucket.oneToTwo,
        selectedSceneIds: const ['bath_time', 'bedtime'],
        supportGoal: OnboardingSupportGoal.moreNatural,
        selectedSpaceId: 'family_rhythm',
        selectedActivityId: 'bedtime',
        starterPhraseId: 'bedtime_dim_the_lights',
        pendingLocalEventId: 'evt_onboarding_fixed',
        selectedReaction: BabyReactionType.hesitant,
        traceEventKey: null,
        updatedAt: DateTime.utc(2026, 7, 23, 12),
      );

      final restored = OnboardingFlowSnapshot.fromJsonMap(snapshot.toJsonMap());
      expect(restored, snapshot);
      expect(snapshot.toJsonMap().values, isNot(contains('Dim the lights.')));
    },
  );

  test('invalid flow wire reaction fails closed', () {
    final json = OnboardingFlowSnapshot(
      step: OnboardingFlowStep.careTurn,
      ageBucket: OnboardingAgeBucket.oneToTwo,
      selectedSceneIds: const ['bath_time'],
      supportGoal: OnboardingSupportGoal.moreNatural,
      selectedSpaceId: 'daily_care',
      selectedActivityId: 'bath_time',
      starterPhraseId: 'bath_time_warm_water',
      pendingLocalEventId: 'evt_onboarding_fixed',
      selectedReaction: BabyReactionType.hesitant,
      updatedAt: DateTime.utc(2026, 7, 23, 12),
    ).toJsonMap()..['selectedReaction'] = 'calm';

    expect(
      () => OnboardingFlowSnapshot.fromJsonMap(json),
      throwsFormatException,
    );
  });
}
