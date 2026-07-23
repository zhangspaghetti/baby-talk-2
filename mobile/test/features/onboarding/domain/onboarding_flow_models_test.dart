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

  test('flow snapshot defensively freezes selected scene IDs', () {
    final constructorInput = <String>['bath_time'];
    final snapshot = OnboardingFlowSnapshot(
      selectedSceneIds: constructorInput,
      updatedAt: DateTime.utc(2026, 7, 23, 12),
    );
    constructorInput.add('bedtime');

    expect(snapshot.selectedSceneIds, <String>['bath_time']);
    expect(
      () => snapshot.selectedSceneIds.add('meal_time'),
      throwsUnsupportedError,
    );

    final copyInput = <String>['bedtime'];
    final copied = snapshot.copyWith(selectedSceneIds: copyInput);
    copyInput.add('meal_time');

    expect(copied.selectedSceneIds, <String>['bedtime']);
    expect(
      () => copied.selectedSceneIds.add('bath_time'),
      throwsUnsupportedError,
    );

    final serialized = snapshot.toJsonMap();
    final serializedSceneIds = serialized['selectedSceneIds'] as List<String>;
    expect(() => serializedSceneIds.add('meal_time'), throwsUnsupportedError);
    expect(snapshot.selectedSceneIds, <String>['bath_time']);

    final jsonSceneIds = List<String>.from(
      serialized['selectedSceneIds'] as List<String>,
    );
    final json = <String, dynamic>{
      ...serialized,
      'selectedSceneIds': jsonSceneIds,
    };
    final restored = OnboardingFlowSnapshot.fromJsonMap(json);
    jsonSceneIds.add('meal_time');

    expect(restored.selectedSceneIds, <String>['bath_time']);
    expect(
      () => restored.selectedSceneIds.add('bedtime'),
      throwsUnsupportedError,
    );
  });

  test('unsupported flow schema versions fail closed', () {
    final snapshot = OnboardingFlowSnapshot.initial(
      DateTime.utc(2026, 7, 23, 12),
    );

    for (final schemaVersion in <int>[0, -1, 2]) {
      final json = snapshot.toJsonMap()..['schemaVersion'] = schemaVersion;

      expect(
        () => OnboardingFlowSnapshot.fromJsonMap(json),
        throwsFormatException,
      );
    }
  });
}
