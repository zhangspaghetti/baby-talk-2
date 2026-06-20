import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/features/ritual_room/data/datasources/mock_interaction_api.dart';
import 'package:mobile_v2/features/ritual_room/data/mappers/interaction_mapper.dart';
import 'package:mobile_v2/features/ritual_room/data/repositories/interaction_repository_impl.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/advance_result.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/product_snapshot.dart';

import '../../../../fixtures/interaction_test_fixtures.dart';
import '../../../../helpers/interaction_test_doubles.dart';

void main() {
  const mapper = InteractionMapper();

  test(
    'getSnapshot maps the transport response to complete product truth',
    () async {
      final snapshot = interactionSnapshot(revision: 3);
      final api = FakeInteractionApi(
        advanceResponse: mapper.resultFromDomain(AdvanceApplied(snapshot)),
        snapshotResponse: mapper.snapshotFromDomain(snapshot),
      );
      final repository = InteractionRepositoryImpl(api: api, mapper: mapper);

      final actual = await repository.getSnapshot(interactionId);

      expect(api.snapshotCalls, 1);
      expect(api.lastInteractionId, interactionId);
      expectProductSnapshotEquals(actual, snapshot);
    },
  );

  test('all five channels use one conversion-only repository method', () async {
    final snapshot = interactionSnapshot(revision: 1);
    final api = FakeInteractionApi(
      advanceResponse: mapper.resultFromDomain(AdvanceApplied(snapshot)),
      snapshotResponse: mapper.snapshotFromDomain(snapshot),
    );
    final repository = InteractionRepositoryImpl(api: api, mapper: mapper);

    for (final input in interactionInputs) {
      final result = await repository.advance(
        interactionId: interactionId,
        expectedRevision: 0,
        input: input,
      );

      expect(result, isA<AdvanceApplied>());
      expect(api.lastInteractionId, interactionId);
      expect(api.lastRequest!.expectedRevision, 0);
      expect(
        mapper.inputToDomain(api.lastRequest!.input).canonicalContent,
        input.canonicalContent,
      );
    }

    expect(api.advanceCalls, interactionInputs.length);
  });

  test(
    'returns every domain result code and latest snapshot unchanged',
    () async {
      final snapshot = interactionSnapshot(revision: 4);
      final api = FakeInteractionApi(
        advanceResponse: mapper.resultFromDomain(AdvanceApplied(snapshot)),
        snapshotResponse: mapper.snapshotFromDomain(snapshot),
      );
      final repository = InteractionRepositoryImpl(api: api, mapper: mapper);
      final results = <AdvanceResult>[
        AdvanceApplied(snapshot),
        AdvanceDuplicateIgnored(snapshot),
        for (final code in AdvanceErrorCode.values)
          AdvanceRejected(
            code: code,
            latestSnapshot:
                code == AdvanceErrorCode.revisionConflict ||
                    code == AdvanceErrorCode.eventIdConflict
                ? snapshot
                : null,
          ),
      ];

      for (final expected in results) {
        api.advanceResponse = mapper.resultFromDomain(expected);

        final actual = await repository.advance(
          interactionId: interactionId,
          expectedRevision: 0,
          input: interactionInputs.first,
        );

        expect(actual.status, expected.status);
        expect(actual.snapshot?.revision, expected.snapshot?.revision);
        if (expected case AdvanceRejected(:final code, :final latestSnapshot)) {
          final rejected = actual as AdvanceRejected;
          expect(rejected.code, code);
          expect(rejected.latestSnapshot?.revision, latestSnapshot?.revision);
        }
      }
    },
  );

  test(
    'adapter execution equals direct engine execution for all five channels',
    () async {
      final direct = InteractionEngineHarness();
      final adapted = InteractionEngineHarness();
      final directInitial = await direct.engine.initialize(ritualRoomId);
      final adaptedInitial = await adapted.engine.initialize(ritualRoomId);
      final repository = InteractionRepositoryImpl(
        api: MockInteractionApi(engine: adapted.engine, mapper: mapper),
        mapper: mapper,
      );
      var directRevision = directInitial.revision;
      var adaptedRevision = adaptedInitial.revision;

      for (final input in interactionInputs) {
        final directResult = await direct.engine.advance(
          interactionId: interactionId,
          expectedRevision: directRevision,
          input: input,
        );
        final adaptedResult = await repository.advance(
          interactionId: interactionId,
          expectedRevision: adaptedRevision,
          input: input,
        );

        expect(directResult, isA<AdvanceApplied>());
        expect(adaptedResult, isA<AdvanceApplied>());
        final directSnapshot = (directResult as AdvanceApplied).snapshot;
        final adaptedSnapshot = (adaptedResult as AdvanceApplied).snapshot;
        expectProductSnapshotEquals(adaptedSnapshot, directSnapshot);
        directRevision = directSnapshot.revision;
        adaptedRevision = adaptedSnapshot.revision;
      }
    },
  );
}

void expectProductSnapshotEquals(
  ProductSnapshot actual,
  ProductSnapshot expected,
) {
  expect(actual.schemaVersion, expected.schemaVersion);
  expect(actual.revision, expected.revision);
  expect(actual.interactionId, expected.interactionId);
  expect(actual.ritualRoomId, expected.ritualRoomId);
  expect(actual.anchor, expected.anchor);
  expect(
    actual.normalizedContext.semanticSignals,
    expected.normalizedContext.semanticSignals,
  );
  expect(
    actual.normalizedContext.intentEstimate,
    expected.normalizedContext.intentEstimate,
  );
  expect(
    actual.normalizedContext.momentHypothesis,
    expected.normalizedContext.momentHypothesis,
  );
  expect(
    actual.normalizedContext.contextFrame,
    expected.normalizedContext.contextFrame,
  );
  expect(
    actual.normalizedContext.confidence,
    expected.normalizedContext.confidence,
  );
  expect(
    actual.normalizedContext.eventSummary,
    expected.normalizedContext.eventSummary,
  );
  expect(actual.memory.summary, expected.memory.summary);
  expect(actual.memory.eventLog, expected.memory.eventLog);
  expect(actual.memory.signalWeights, expected.memory.signalWeights);
  expect(actual.memory.interactionTrend, expected.memory.interactionTrend);
  expect(actual.memory.contextStability, expected.memory.contextStability);
  expect(actual.memory.narrative, expected.memory.narrative);
  expect(actual.strategy.primary, expected.strategy.primary);
  expect(actual.strategy.modifiers, expected.strategy.modifiers);
  expect(actual.strategy.confidence, expected.strategy.confidence);
  expect(actual.strategy.rationale, expected.strategy.rationale);
  expect(actual.strategy.pressureLevel, expected.strategy.pressureLevel);
  expect(actual.strategy.recommendedTone, expected.strategy.recommendedTone);
  expect(actual.strategy.interactionHint, expected.strategy.interactionHint);
  expect(actual.utterance.primary, expected.utterance.primary);
  expect(actual.utterance.zhHelper, expected.utterance.zhHelper);
  expect(actual.utterance.tone, expected.utterance.tone);
  expect(actual.utterance.clarityLevel, expected.utterance.clarityLevel);
  expect(actual.utterance.contextFit, expected.utterance.contextFit);
  expect(actual.utterance.alternatives, expected.utterance.alternatives);
  expect(actual.metadata.lastEventId, expected.metadata.lastEventId);
  expect(actual.metadata.updatedAt, expected.metadata.updatedAt);
}
