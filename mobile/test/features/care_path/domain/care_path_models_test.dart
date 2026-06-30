import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/care_path/domain/models/care_path_models.dart';
import 'package:mobile/features/practice/domain/models/garden_growth_snapshot.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

void main() {
  group('CarePathNodeState', () {
    test('exposes planned values in order', () {
      expect(
        CarePathNodeState.values,
        equals(<CarePathNodeState>[
          CarePathNodeState.current,
          CarePathNodeState.nearby,
          CarePathNodeState.doneToday,
          CarePathNodeState.unavailable,
        ]),
      );
    });
  });

  group('CareTurnPhase', () {
    test('exposes planned values in order', () {
      expect(
        CareTurnPhase.values,
        equals(<CareTurnPhase>[
          CareTurnPhase.idle,
          CareTurnPhase.loading,
          CareTurnPhase.utteranceReady,
          CareTurnPhase.reactionPrompt,
          CareTurnPhase.savingTrace,
          CareTurnPhase.nextSupportReady,
          CareTurnPhase.heldWithFallback,
          CareTurnPhase.error,
        ]),
      );
    });
  });

  group('CareMoment', () {
    test('supports equality and copyWith', () {
      const original = CareMoment(
        spaceId: 'space-1',
        activityId: 'activity-1',
        spaceTitle: 'Kitchen',
        title: 'Breakfast prep',
        sceneTag: 'meal',
        careActionLabel: 'Offer spoon',
        coachTip: 'Pause and wait.',
        nodeState: CarePathNodeState.current,
      );

      const same = CareMoment(
        spaceId: 'space-1',
        activityId: 'activity-1',
        spaceTitle: 'Kitchen',
        title: 'Breakfast prep',
        sceneTag: 'meal',
        careActionLabel: 'Offer spoon',
        coachTip: 'Pause and wait.',
        nodeState: CarePathNodeState.current,
      );

      expect(original, same);
      expect(original.hashCode, same.hashCode);

      final updated = original.copyWith(
        title: 'Breakfast cleanup',
        nodeState: CarePathNodeState.doneToday,
      );

      expect(updated.title, 'Breakfast cleanup');
      expect(updated.nodeState, CarePathNodeState.doneToday);
      expect(updated.spaceId, original.spaceId);
    });
  });

  group('CareUtterance', () {
    test('supports equality and copyWith including nullable audioAsset', () {
      const original = CareUtterance(
        phraseId: 'phrase-1',
        english: 'Open wide',
        chinese: '张嘴哦',
        pronunciation: 'zhang zui o',
        audioAsset: 'assets/audio/open_wide.mp3',
        whenToSay: 'Before the spoon reaches the mouth.',
        isFallback: false,
      );

      const same = CareUtterance(
        phraseId: 'phrase-1',
        english: 'Open wide',
        chinese: '张嘴哦',
        pronunciation: 'zhang zui o',
        audioAsset: 'assets/audio/open_wide.mp3',
        whenToSay: 'Before the spoon reaches the mouth.',
        isFallback: false,
      );

      expect(original, same);
      expect(original.hashCode, same.hashCode);

      final updated = original.copyWith(audioAsset: null, isFallback: true);

      expect(updated.audioAsset, isNull);
      expect(updated.isFallback, isTrue);
      expect(updated.english, original.english);
    });
  });

  group('CareTurnSnapshot', () {
    test('supports equality, copyWith, reaction reuse, and garden impact', () {
      const moment = CareMoment(
        spaceId: 'space-1',
        activityId: 'activity-1',
        spaceTitle: 'Kitchen',
        title: 'Breakfast prep',
        sceneTag: 'meal',
        careActionLabel: 'Offer spoon',
        coachTip: 'Pause and wait.',
        nodeState: CarePathNodeState.current,
      );
      const utterance = CareUtterance(
        phraseId: 'phrase-1',
        english: 'Open wide',
        chinese: '张嘴哦',
        pronunciation: 'zhang zui o',
        audioAsset: null,
        whenToSay: 'Before the spoon reaches the mouth.',
        isFallback: false,
      );
      final impact = LatestPracticeImpact(
        eventKey: 'installation:event-1',
        occurredAt: DateTime.utc(2026, 6, 30, 8),
        spaceId: 'space-1',
        spaceTitle: 'Kitchen',
        activityId: 'activity-1',
        activityTitle: 'Breakfast prep',
        phraseId: 'phrase-1',
        phraseTitle: 'Open wide',
        reactionType: BabyReactionType.cooperating,
        previousPatchStage: GardenPatchStage.quiet,
        currentPatchStage: GardenPatchStage.tended,
        previousFlowerStage: GardenFlowerStage.seed,
        currentFlowerStage: GardenFlowerStage.sprout,
        headline: 'Nice progress',
        detail: 'The baby cooperated during breakfast.',
      );

      final snapshot = CareTurnSnapshot(
        moment: moment,
        currentUtterance: utterance,
        selectedReaction: BabyReactionType.cooperating,
        nextSupportUtterance: null,
        phase: CareTurnPhase.nextSupportReady,
        traceEventKey: 'installation:event-1',
        latestGardenImpact: impact,
        message: 'Saved.',
      );

      final sameSnapshot = CareTurnSnapshot(
        moment: moment,
        currentUtterance: utterance,
        selectedReaction: BabyReactionType.cooperating,
        nextSupportUtterance: null,
        phase: CareTurnPhase.nextSupportReady,
        traceEventKey: 'installation:event-1',
        latestGardenImpact: impact,
        message: 'Saved.',
      );

      expect(snapshot, sameSnapshot);
      expect(snapshot.hashCode, sameSnapshot.hashCode);
      expect(snapshot.selectedReaction, BabyReactionType.cooperating);
      expect(snapshot.latestGardenImpact, same(impact));

      final cleared = snapshot.copyWith(
        selectedReaction: null,
        latestGardenImpact: null,
        message: null,
      );

      expect(cleared.selectedReaction, isNull);
      expect(cleared.latestGardenImpact, isNull);
      expect(cleared.message, isNull);
      expect(cleared.moment, same(moment));
      expect(cleared.currentUtterance, same(utterance));
    });
  });

  test('source does not introduce CareReactionType', () {
    final source = File(
      'lib/features/care_path/domain/models/care_path_models.dart',
    ).readAsStringSync();

    expect(source.contains('CareReactionType'), isFalse);
  });
}
