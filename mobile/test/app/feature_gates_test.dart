import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/feature_gates.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';
import 'package:mobile/features/practice/domain/models/practice_activity_catalog.dart';
import 'package:mobile/features/practice/data/repositories/practice_repository.dart';

import '../features/practice/practice_repository_characterization_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(ensurePracticeRepositoryHarnessIsarInitialized);

  test('existing Care activity bypasses a missing onboarding marker', () async {
    final harness = await PracticeRepositoryCharacterizationHarness.create();
    addTearDown(harness.dispose);
    await harness.repository.recordReaction(
      spaceId: 'daily_care',
      activityId: 'bath_time',
      phraseId: 'bath_time_warm_water',
      reactionType: BabyReactionType.cooperating,
      localEventId: 'existing-care-without-onboarding-marker',
      clientTimestamp: DateTime.utc(2026, 8, 14, 8),
    );

    final gates = await FeatureGates.resolve(
      practiceRepository: harness.repository,
      completedSnapshot: null,
      primarySpaceId: 'daily_care',
      primaryActivityId: 'bath_time',
    );

    expect(gates.hasExistingCareActivity, isTrue);
    expect(gates.continuitySeed, isNotNull);
  });

  test(
    'activity-read failure is not treated as an empty installation',
    () async {
      await expectLater(
        FeatureGates.resolve(
          practiceRepository: _FailingActivityCatalogRepository(),
          completedSnapshot: null,
          primarySpaceId: 'daily_care',
          primaryActivityId: 'bath_time',
        ),
        throwsA(anything),
      );
    },
  );
}

final class _FailingActivityCatalogRepository implements PracticeRepository {
  @override
  Future<PracticeActivityCatalog> getActivityCatalog() async {
    throw StateError('simulated activity catalog read failure');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
