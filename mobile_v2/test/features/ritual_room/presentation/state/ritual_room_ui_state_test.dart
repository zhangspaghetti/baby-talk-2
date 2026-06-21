import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/advance_result.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/ritual_room_content.dart';
import 'package:mobile_v2/features/ritual_room/presentation/state/ritual_room_ui_state.dart';

import '../../../../fixtures/interaction_test_fixtures.dart';

void main() {
  test('all variants carry only whole room and snapshot references', () {
    final room = _room();
    final snapshot = interactionSnapshot(revision: 2);
    final problem = RitualRoomProblem(
      AdvanceErrorCode.pipelineFailed,
      cause: StateError('pipeline failed'),
    );

    final states = <RitualRoomUiState>[
      const RitualRoomIdle(),
      const RitualRoomLoading(),
      RitualRoomReady(room: room, snapshot: snapshot),
      RitualRoomSubmitting(
        room: room,
        snapshot: snapshot,
        selectedReaction: 'not_ready',
      ),
      RitualRoomUnknownOutcome(
        room: room,
        snapshot: snapshot,
        selectedReaction: 'not_ready',
        isRetrying: false,
      ),
      RitualRoomRecoverableFailure(
        room: room,
        snapshot: snapshot,
        problem: problem,
      ),
      RitualRoomLoadFailure(StateError('load failed')),
    ];

    expect(states[0].snapshot, isNull);
    expect(states[1].snapshot, isNull);
    expect((states[2] as RitualRoomReady).room, same(room));
    expect(states[2].snapshot, same(snapshot));
    expect((states[3] as RitualRoomSubmitting).room, same(room));
    expect(states[3].snapshot, same(snapshot));
    expect((states[3] as RitualRoomSubmitting).selectedReaction, 'not_ready');
    expect((states[4] as RitualRoomUnknownOutcome).room, same(room));
    expect(states[4].snapshot, same(snapshot));
    expect(
      (states[4] as RitualRoomUnknownOutcome).selectedReaction,
      'not_ready',
    );
    expect((states[4] as RitualRoomUnknownOutcome).isRetrying, isFalse);
    expect((states[5] as RitualRoomRecoverableFailure).room, same(room));
    expect(states[5].snapshot, same(snapshot));
    expect((states[5] as RitualRoomRecoverableFailure).problem, same(problem));
    expect(states[6].snapshot, isNull);
  });

  test('interpreted context remains inside the complete ProductSnapshot', () {
    final snapshot = interactionSnapshot(revision: 3);
    final state = RitualRoomReady(room: _room(), snapshot: snapshot);

    expect(state.snapshot.normalizedContext, same(snapshot.normalizedContext));
    expect(state.snapshot.memory, same(snapshot.memory));
    expect(state.snapshot.strategy, same(snapshot.strategy));
    expect(state.snapshot.utterance, same(snapshot.utterance));
  });

  test(
    'public app screen and state declare no private command-envelope fields',
    () {
      final stateSource = File(
        'lib/features/ritual_room/presentation/state/ritual_room_ui_state.dart',
      ).readAsStringSync();
      final publicSource = [
        stateSource,
        File('lib/app/baby_talk_app.dart').readAsStringSync(),
        File(
          'lib/features/ritual_room/presentation/screens/ritual_room_screen.dart',
        ).readAsStringSync(),
      ].join('\n');

      for (final forbidden in [
        RegExp(r'final\s+InteractionContext\b'),
        RegExp(r'final\s+NormalizedInput\b'),
        RegExp(r'final\s+ContextMemory\b'),
        RegExp(r'final\s+StrategyDecision\b'),
        RegExp(r'final\s+Utterance\b'),
        RegExp(r'final\s+int\s+revision\b'),
        RegExp(r'final\s+int\s+schemaVersion\b'),
        RegExp(r'final\s+InputEvent\b'),
        RegExp(r'final\s+String\s+eventId\b'),
        RegExp(r'final\s+String\s+interactionId\b'),
        RegExp(r'final\s+int\s+expectedRevision\b'),
        RegExp(r'_PendingInteractionCommand'),
      ]) {
        expect(publicSource, isNot(matches(forbidden)));
      }
      expect(publicSource, isNot(contains('interactionInputFactoryProvider')));
      expect(publicSource, isNot(contains("domain/models/input_event.dart")));
      expect(stateSource, contains('RitualRoomUnknownOutcome'));
    },
  );
}

RitualRoomContent _room({String ritualRoomId = 'shoes_on_room_v1'}) =>
    RitualRoomContent(
      ritualRoomId: ritualRoomId,
      roomName: 'Shoes On',
      routineAnchor: 'getting ready to go outside',
      anchorPhrase: 'Shoes on.',
      chineseHelper: '穿鞋啦。',
      illustration: const RitualIllustration(
        assetPath: 'assets/illustrations/rituals/shoes_on/shoes_on.png',
        status: 'approved',
      ),
      bootstrapUtterance: const RitualBootstrapUtterance(
        primary: "Let's put your shoes on.",
        zhHelper: '我们来穿鞋吧。',
      ),
      actionCue: 'Hold one shoe nearby.',
      audio: const RitualAudioContent(
        available: false,
        label: 'Play',
        assetReference: null,
      ),
      reactionPrompt: 'What is happening now?',
      reactionChoices: const [
        RitualReactionChoice(id: 'joining_action', label: 'Joining'),
      ],
      pendingCopy: 'Finding the next words...',
      reassurance: 'You can keep it simple.',
      quietExit: 'Pause for now',
      governanceEvidence: const RitualGovernanceEvidence(
        contextSeedId: 'shoes-on-seed',
        joinabilityHypothesis: 'shared_action_available',
        governorDecision: 'explore',
        productionGardenStatus: 'unchanged',
      ),
    );
