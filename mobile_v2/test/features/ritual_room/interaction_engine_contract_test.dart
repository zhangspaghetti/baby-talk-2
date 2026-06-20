import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/features/ritual_room/data/datasources/mock_interaction_api.dart';
import 'package:mobile_v2/features/ritual_room/data/mappers/interaction_mapper.dart';
import 'package:mobile_v2/features/ritual_room/data/repositories/interaction_repository_impl.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/advance_result.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/input_event.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/product_snapshot.dart';

import '../../fixtures/interaction_test_fixtures.dart';
import '../../helpers/interaction_test_doubles.dart';

void main() {
  test(
    'R060/R067 engine evolves revision 0 to 5, resolves conflicts, preserves privacy, and replays directly',
    () async {
      const rawVoice = 'RAW_VOICE_41_11 attention moved away';
      const rawText = 'RAW_TEXT_41_11 the shared action needs a pause';
      final harness = InteractionEngineHarness();
      final initial = await harness.engine.initialize(ritualRoomId);
      final inputs = <InputEvent>[
        InputEvent.reactionSelection(
          eventId: 'event-1',
          occurredAt: DateTime.utc(2026, 6, 21, 8),
          selected: 'not_ready',
        ),
        InputEvent.voiceObservation(
          eventId: 'event-2',
          occurredAt: DateTime.utc(2026, 6, 21, 8, 1),
          transcript: rawVoice,
        ),
        InputEvent.freeText(
          eventId: 'event-3',
          occurredAt: DateTime.utc(2026, 6, 21, 8, 2),
          text: rawText,
        ),
        InputEvent.futureSignal(
          eventId: 'event-4',
          occurredAt: DateTime.utc(2026, 6, 21, 8, 3),
          signal: 'shared_action',
          value: 'available',
        ),
        InputEvent.strategyPreference(
          eventId: 'event-5',
          occurredAt: DateTime.utc(2026, 6, 21, 8, 4),
          preference: 'reduce_options',
        ),
      ];

      expect(initial.revision, 0);
      ProductSnapshot latest = initial;
      for (final input in inputs) {
        final beforeClock = harness.clock.calls;
        final result = await harness.engine.advance(
          interactionId: initial.interactionId,
          expectedRevision: latest.revision,
          input: input,
        );
        latest = (result as AdvanceApplied).snapshot;
        expect(harness.clock.calls, beforeClock + 1, reason: 'one-clock-read');
      }

      final duplicate = await harness.engine.advance(
        interactionId: initial.interactionId,
        expectedRevision: 0,
        input: inputs.first,
      );
      final eventIdConflict = await harness.engine.advance(
        interactionId: initial.interactionId,
        expectedRevision: 5,
        input: InputEvent.reactionSelection(
          eventId: 'event-1',
          occurredAt: inputs.first.occurredAt,
          selected: 'self',
        ),
      );
      final revisionConflict = await harness.engine.advance(
        interactionId: initial.interactionId,
        expectedRevision: 0,
        input: InputEvent.reactionSelection(
          eventId: 'event-6',
          occurredAt: DateTime.utc(2026, 6, 21, 8, 5),
          selected: 'self',
        ),
      );
      final notFound = await harness.engine.advance(
        interactionId: 'missing-interaction',
        expectedRevision: 0,
        input: inputs.first,
      );
      final runtime = harness.store.debugState(initial.interactionId)!;
      final semanticDump = jsonEncode(runtime.toJson()).toLowerCase();
      final replayed = runtime.replayJournal.replayFrom(
        runtime.initialSnapshot,
      );

      expect(latest.revision, 5);
      expect(latest.normalizedContext.semanticSignals, isNotEmpty);
      expect(
        latest.memory.eventLog,
        isNotEmpty,
        reason: 'mixed-channel evolution',
      );
      expect(duplicate, isA<AdvanceDuplicateIgnored>());
      expect(duplicate.snapshot!.revision, 5, reason: 'duplicate_ignored');
      expect(
        (eventIdConflict as AdvanceRejected).code,
        AdvanceErrorCode.eventIdConflict,
        reason: 'event_id_conflict',
      );
      expect(eventIdConflict.latestSnapshot!.revision, 5);
      expect(
        (revisionConflict as AdvanceRejected).code,
        AdvanceErrorCode.revisionConflict,
        reason: 'revision_conflict',
      );
      expect(revisionConflict.latestSnapshot!.revision, 5);
      expect(
        (notFound as AdvanceRejected).code,
        AdvanceErrorCode.interactionNotFound,
        reason: 'interaction_not_found',
      );
      expect(runtime.consistencyState.receipts, hasLength(5));
      expect(runtime.replayJournal.records, hasLength(5));
      expect(semanticDump, isNot(contains(rawVoice.toLowerCase())));
      expect(semanticDump, isNot(contains(rawText.toLowerCase())));
      _expectSnapshotEquals(replayed, latest);
    },
  );

  test(
    'R060 pipeline failure is atomic and reads no transition clock',
    () async {
      final harness = InteractionEngineHarness(failPipeline: true);
      final initial = await harness.engine.initialize(ritualRoomId);
      final clockBefore = harness.clock.calls;

      final result = await harness.engine.advance(
        interactionId: initial.interactionId,
        expectedRevision: 0,
        input: interactionInputs.first,
      );
      final runtime = harness.store.debugState(initial.interactionId)!;

      expect((result as AdvanceRejected).code, AdvanceErrorCode.pipelineFailed);
      expect(runtime.snapshot.revision, 0);
      expect(runtime.consistencyState.receipts, isEmpty);
      expect(runtime.replayJournal.records, isEmpty);
      expect(harness.clock.calls, clockBefore);
    },
  );

  test(
    'R067 adapter parity matches direct engine for all five channels',
    () async {
      final direct = InteractionEngineHarness();
      final adapted = InteractionEngineHarness();
      final mapper = const InteractionMapper();
      final repository = InteractionRepositoryImpl(
        api: MockInteractionApi(engine: adapted.engine, mapper: mapper),
        mapper: mapper,
      );
      final directInitial = await direct.engine.initialize(ritualRoomId);
      final adaptedInitial = await adapted.engine.initialize(ritualRoomId);

      ProductSnapshot directSnapshot = directInitial;
      ProductSnapshot adaptedSnapshot = adaptedInitial;
      for (final input in interactionInputs) {
        final directResult = await direct.engine.advance(
          interactionId: directInitial.interactionId,
          expectedRevision: directSnapshot.revision,
          input: input,
        );
        final adaptedResult = await repository.advance(
          interactionId: adaptedInitial.interactionId,
          expectedRevision: adaptedSnapshot.revision,
          input: input,
        );
        directSnapshot = (directResult as AdvanceApplied).snapshot;
        adaptedSnapshot = (adaptedResult as AdvanceApplied).snapshot;
        _expectProductSemanticsEqual(directSnapshot, adaptedSnapshot);
      }
    },
  );
}

void _expectSnapshotEquals(ProductSnapshot actual, ProductSnapshot expected) {
  expect(actual.interactionId, expected.interactionId);
  expect(actual.ritualRoomId, expected.ritualRoomId);
  expect(actual.schemaVersion, expected.schemaVersion);
  expect(actual.revision, expected.revision);
  expect(actual.anchor, expected.anchor);
  expect(
    actual.normalizedContext.eventSummary,
    expected.normalizedContext.eventSummary,
  );
  expect(actual.memory.summary, expected.memory.summary);
  expect(actual.strategy.primary, expected.strategy.primary);
  expect(actual.utterance.primary, expected.utterance.primary);
  expect(actual.metadata.lastEventId, expected.metadata.lastEventId);
  expect(actual.metadata.updatedAt, expected.metadata.updatedAt);
}

void _expectProductSemanticsEqual(
  ProductSnapshot direct,
  ProductSnapshot adapted,
) {
  expect(adapted.schemaVersion, direct.schemaVersion);
  expect(adapted.revision, direct.revision);
  expect(adapted.ritualRoomId, direct.ritualRoomId);
  expect(adapted.anchor, direct.anchor);
  expect(
    adapted.normalizedContext.semanticSignals,
    direct.normalizedContext.semanticSignals,
  );
  expect(
    adapted.normalizedContext.eventSummary,
    direct.normalizedContext.eventSummary,
  );
  expect(adapted.memory.summary, direct.memory.summary);
  expect(adapted.memory.eventLog, direct.memory.eventLog);
  expect(adapted.strategy.primary, direct.strategy.primary);
  expect(adapted.strategy.modifiers, direct.strategy.modifiers);
  expect(adapted.utterance.primary, direct.utterance.primary);
  expect(adapted.utterance.zhHelper, direct.utterance.zhHelper);
}
