import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/context_memory.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/normalized_input.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/product_snapshot.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/strategy_decision.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/active_utterance.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/consistency_state.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_runtime_state.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_runtime_store.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/replay_journal.dart';

void main() {
  group('runtime truth and evidence', () {
    test('receipt fields are limited to private idempotency evidence', () {
      const receipt = ConsistencyReceipt(
        eventId: 'event-1',
        inputFingerprint: 'sha256:fingerprint',
        appliedRevision: 1,
      );
      final state = ConsistencyState.empty().record(receipt);

      expect(receipt.toJson().keys.toSet(), {
        'eventId',
        'inputFingerprint',
        'appliedRevision',
      });
      expect(state.findByEventId('event-1'), same(receipt));
      expect(state.receipts, hasLength(1));
      expect(() => state.receipts.add(receipt), throwsUnsupportedError);
    });

    test(
      'runtime state keeps product truth separate from append-only evidence',
      () {
        final initial = _snapshot();
        final transition = _transition(
          eventId: 'event-1',
          fromRevision: 0,
          toRevision: 1,
        );
        final receipt = ConsistencyReceipt(
          eventId: transition.eventId,
          inputFingerprint: 'sha256:fingerprint',
          appliedRevision: transition.toRevision,
        );
        final runtime = InteractionRuntimeState.initial(initial).commit(
          currentSnapshot: _apply(initial, transition),
          consistencyState: ConsistencyState.empty().record(receipt),
          replayJournal: ReplayJournal.empty().append(transition),
        );

        expect(runtime.initialSnapshot.revision, 0);
        expect(runtime.currentSnapshot.revision, 1);
        expect(runtime.consistencyState.receipts, hasLength(1));
        expect(runtime.replayJournal.records, hasLength(1));
        expect(runtime.initialSnapshot, same(initial));
      },
    );

    test(
      'transition records contain derived outputs and exclude raw payloads',
      () {
        const rawVoice = 'RAW_VOICE_SENTINEL_41_03';
        const rawFreeText = 'RAW_FREE_TEXT_SENTINEL_41_03';
        final transition = _transition(
          eventId: 'event-1',
          fromRevision: 0,
          toRevision: 1,
        );
        final runtime = InteractionRuntimeState.initial(_snapshot()).commit(
          currentSnapshot: _apply(_snapshot(), transition),
          consistencyState: ConsistencyState.empty().record(
            ConsistencyReceipt(
              eventId: transition.eventId,
              inputFingerprint: 'sha256:derived-only',
              appliedRevision: transition.toRevision,
            ),
          ),
          replayJournal: ReplayJournal.empty().append(transition),
        );
        final runtimeJson = runtime.toJson();
        final runtimeDump = jsonEncode(runtimeJson);
        final initialSnapshotJson =
            runtimeJson['initialSnapshot']! as Map<String, Object?>;
        final currentSnapshotJson =
            runtimeJson['currentSnapshot']! as Map<String, Object?>;
        final initialUtteranceJson =
            initialSnapshotJson['activeUtterance']! as Map<String, Object?>;
        final currentUtteranceJson =
            currentSnapshotJson['activeUtterance']! as Map<String, Object?>;
        final replayJournalJson =
            runtimeJson['replayJournal']! as List<Map<String, Object>>;
        final replayRecordJson = replayJournalJson.single;
        final replayUtteranceJson =
            replayRecordJson['activeUtterance']! as Map<String, Object?>;

        expect(replayRecordJson.keys.toSet(), {
          'eventId',
          'fromRevision',
          'toRevision',
          'occurredAt',
          'normalizedInput',
          'updatedContextMemory',
          'strategyDecision',
          'activeUtterance',
        });
        expect(
          initialUtteranceJson['actionCue'],
          runtime.initialSnapshot.activeUtterance.actionCue,
        );
        expect(
          currentUtteranceJson['actionCue'],
          runtime.currentSnapshot.activeUtterance.actionCue,
        );
        expect(
          replayUtteranceJson['actionCue'],
          transition.activeUtterance.actionCue,
        );
        expect(runtimeDump, isNot(contains(rawVoice)));
        expect(runtimeDump, isNot(contains(rawFreeText)));
        expect(runtimeDump, isNot(contains('transcript')));
        expect(runtimeDump, isNot(contains('freeText')));
      },
    );

    test(
      'direct replay applies recorded outputs without callback execution',
      () {
        final initial = _snapshot();
        final first = _transition(
          eventId: 'event-1',
          fromRevision: 0,
          toRevision: 1,
        );
        final second = _transition(
          eventId: 'event-2',
          fromRevision: 1,
          toRevision: 2,
          occurredAt: DateTime.utc(2026, 6, 20, 4, 32),
          signal: 'shared_action',
        );
        final journal = ReplayJournal.empty().append(first).append(second);
        var callbackCalls = 0;

        final replayed = journal.replayFrom(initial);

        expect(callbackCalls, 0);
        expect(replayed.revision, 2);
        expect(replayed.metadata.lastEventId, second.eventId);
        expect(replayed.metadata.updatedAt, second.occurredAt);
        _expectNormalized(replayed.normalizedContext, second.normalizedInput);
        _expectMemory(replayed.memory, second.updatedContextMemory);
        _expectStrategy(replayed.strategy, second.strategyDecision);
        _expectActiveUtterance(
          replayed.activeUtterance,
          second.activeUtterance,
        );
        expect(journal.records, hasLength(2));
        expect(() => journal.records.clear(), throwsUnsupportedError);
      },
    );
  });

  group('InMemoryInteractionRuntimeStore', () {
    test(
      'same-interaction operations serialize while different interactions proceed',
      () async {
        final store = InMemoryInteractionRuntimeStore();
        store.add(
          InteractionRuntimeState.initial(_snapshot(interactionId: 'one')),
        );
        store.add(
          InteractionRuntimeState.initial(_snapshot(interactionId: 'two')),
        );
        final releaseFirst = Completer<void>();
        final firstEntered = Completer<void>();
        final secondEntered = Completer<void>();
        final otherEntered = Completer<void>();

        final first = store.runExclusive<void>('one', (current, commit) async {
          firstEntered.complete();
          await releaseFirst.future;
        });
        await firstEntered.future;
        final second = store.runExclusive<void>('one', (current, commit) async {
          secondEntered.complete();
        });
        final other = store.runExclusive<void>('two', (current, commit) async {
          otherEntered.complete();
        });

        await otherEntered.future;
        expect(secondEntered.isCompleted, isFalse);
        releaseFirst.complete();
        await Future.wait([first, second, other]);
        expect(secondEntered.isCompleted, isTrue);
      },
    );

    test('only one explicit commit replaces the immutable aggregate', () async {
      final store = InMemoryInteractionRuntimeStore();
      final initial = InteractionRuntimeState.initial(_snapshot());
      store.add(initial);

      await store.runExclusive<void>('interaction-1', (current, commit) async {
        expect(current, same(initial));
      });
      expect(store.read('interaction-1'), same(initial));

      final replacement = initial.commit(
        currentSnapshot: _snapshot(revision: 1),
        consistencyState: initial.consistencyState,
        replayJournal: initial.replayJournal,
      );
      await store.runExclusive<void>('interaction-1', (current, commit) async {
        commit(replacement);
        expect(() => commit(initial), throwsStateError);
      });

      expect(store.read('interaction-1'), same(replacement));
    });
  });
}

TransitionRecord _transition({
  required String eventId,
  required int fromRevision,
  required int toRevision,
  DateTime? occurredAt,
  String signal = 'low_joinability',
}) => TransitionRecord(
  eventId: eventId,
  fromRevision: fromRevision,
  toRevision: toRevision,
  occurredAt: occurredAt ?? DateTime.utc(2026, 6, 20, 4, 31),
  normalizedInput: _normalized(signal),
  updatedContextMemory: _memory(signal),
  strategyDecision: _strategy(signal),
  activeUtterance: _activeUtterance(signal),
);

ProductSnapshot _apply(ProductSnapshot initial, TransitionRecord transition) =>
    ProductSnapshot(
      schemaVersion: initial.schemaVersion,
      revision: transition.toRevision,
      interactionId: initial.interactionId,
      ritualRoomId: initial.ritualRoomId,
      anchor: initial.anchor,
      normalizedContext: transition.normalizedInput,
      memory: transition.updatedContextMemory,
      strategy: transition.strategyDecision,
      activeUtterance: transition.activeUtterance,
      metadata: ProductSnapshotMetadata(
        lastEventId: transition.eventId,
        updatedAt: transition.occurredAt,
      ),
    );

ProductSnapshot _snapshot({
  String interactionId = 'interaction-1',
  int revision = 0,
}) => ProductSnapshot(
  schemaVersion: ProductSnapshot.currentSchemaVersion,
  revision: revision,
  interactionId: interactionId,
  ritualRoomId: 'shoes_on_room_v1',
  anchor: 'Shoes on.',
  normalizedContext: _normalized('shared_action'),
  memory: _memory('shared_action'),
  strategy: _strategy('shared_action'),
  activeUtterance: _activeUtterance('shared_action'),
  metadata: ProductSnapshotMetadata(
    lastEventId: revision == 0 ? null : 'event-$revision',
    updatedAt: DateTime.utc(2026, 6, 20, 4, 30 + revision),
  ),
);

NormalizedInput _normalized(String signal) => NormalizedInput(
  semanticSignals: [signal],
  intentEstimate: signal == 'shared_action' ? 'engage' : 'resist',
  momentHypothesis: signal == 'shared_action'
      ? 'the shared action is open to enter'
      : 'the shared action is currently hard to enter',
  contextFrame: const {
    'actionContext': 'putting shoes on',
    'interactionType': 'caregiver_shared_action_support',
    'sourceModality': 'derived_evidence',
  },
  confidence: 0.8,
  eventSummary: signal == 'shared_action'
      ? 'the shared routine is available'
      : 'the shared routine is currently difficult to enter',
);

ContextMemory _memory(String signal) => ContextMemory(
  summary: 'interaction-local $signal evidence',
  eventLog: ['compressed $signal evidence'],
  signalWeights: {signal: 1},
  interactionTrend: signal == 'shared_action'
      ? 'increasing_joinability'
      : 'decreasing_joinability',
  contextStability: 0.8,
  narrative: 'the current shared routine has $signal evidence',
);

StrategyDecision _strategy(String signal) => StrategyDecision(
  primary: PressurePolicy.lowPressure,
  modifiers: signal == 'shared_action'
      ? const [StrategyModifier.continueInteraction, StrategyModifier.maintain]
      : const [StrategyModifier.simplify, StrategyModifier.reduceOptions],
  confidence: 0.82,
  rationale: 'current interaction evidence selects low pressure',
  pressureLevel: 20,
  recommendedTone: 'soft',
  interactionHint: 'offer one small shared action',
);

ActiveUtterance _activeUtterance(String signal) => ActiveUtterance(
  displayId: signal == 'shared_action'
      ? 'shoes_on_ready_v1'
      : 'shoes_on_revised_wait_v1',
  primary: signal == 'shared_action'
      ? 'Let’s put your shoes on.'
      : "Let's try one shoe together.",
  zhSupport: signal == 'shared_action' ? '我们来穿鞋吧。' : '我们先一起试一只鞋。',
  actionCue: 'shared action moment',
  audioAssetId: signal == 'shared_action' ? 'rr_shoes_001' : 'rr_shoes_002',
);

void _expectNormalized(NormalizedInput actual, NormalizedInput expected) {
  expect(actual.semanticSignals, expected.semanticSignals);
  expect(actual.intentEstimate, expected.intentEstimate);
  expect(actual.momentHypothesis, expected.momentHypothesis);
  expect(actual.contextFrame, expected.contextFrame);
  expect(actual.confidence, expected.confidence);
  expect(actual.eventSummary, expected.eventSummary);
}

void _expectMemory(ContextMemory actual, ContextMemory expected) {
  expect(actual.summary, expected.summary);
  expect(actual.eventLog, expected.eventLog);
  expect(actual.signalWeights, expected.signalWeights);
  expect(actual.interactionTrend, expected.interactionTrend);
  expect(actual.contextStability, expected.contextStability);
  expect(actual.narrative, expected.narrative);
}

void _expectStrategy(StrategyDecision actual, StrategyDecision expected) {
  expect(actual.primary, expected.primary);
  expect(actual.modifiers, expected.modifiers);
  expect(actual.confidence, expected.confidence);
  expect(actual.rationale, expected.rationale);
  expect(actual.pressureLevel, expected.pressureLevel);
  expect(actual.recommendedTone, expected.recommendedTone);
  expect(actual.interactionHint, expected.interactionHint);
}

void _expectActiveUtterance(ActiveUtterance actual, ActiveUtterance expected) {
  expect(actual.displayId, expected.displayId);
  expect(actual.primary, expected.primary);
  expect(actual.zhSupport, expected.zhSupport);
  expect(actual.actionCue, expected.actionCue);
  expect(actual.audioAssetId, expected.audioAssetId);
}
