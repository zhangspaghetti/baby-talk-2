import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/features/ritual_room/data/datasources/mock_interaction_api.dart';
import 'package:mobile_v2/features/ritual_room/data/mappers/interaction_mapper.dart';
import 'package:mobile_v2/features/ritual_room/data/repositories/interaction_repository_impl.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/advance_result.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/input_event.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/product_snapshot.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_runtime_state.dart';

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

      final repositoryResult = await repository.getSnapshot(interactionId);

      expect(api.snapshotCalls, 1);
      expect(api.lastInteractionId, interactionId);
      expectProductSnapshotEquals(repositoryResult, snapshot);
      expect(repositoryResult.activeUtterance.actionCue, '宝宝停下来时');
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

  test(
    'adapter execution equals direct engine for every result path',
    () async {
      await _expectUnknownInteractionParity(mapper);
      await _expectRevisionAndInvalidParity(mapper);
      await _expectDuplicateAndEventIdParity(mapper);
      await _expectUnsupportedSchemaParity(mapper);
      await _expectPipelineFailureParity(mapper);
    },
  );
}

Future<void> _expectUnknownInteractionParity(InteractionMapper mapper) async {
  final direct = InteractionEngineHarness();
  final adapted = InteractionEngineHarness();

  await _expectAdvanceParity(
    direct: () => direct.engine.advance(
      interactionId: 'missing-interaction',
      expectedRevision: 0,
      input: interactionInputs.first,
    ),
    adapted: () => _repository(adapted, mapper).advance(
      interactionId: 'missing-interaction',
      expectedRevision: 0,
      input: interactionInputs.first,
    ),
  );
}

Future<void> _expectRevisionAndInvalidParity(InteractionMapper mapper) async {
  final direct = InteractionEngineHarness();
  final adapted = InteractionEngineHarness();
  await direct.engine.initialize(ritualRoomId);
  await adapted.engine.initialize(ritualRoomId);

  await _expectAdvanceParity(
    direct: () => direct.engine.advance(
      interactionId: interactionId,
      expectedRevision: 1,
      input: interactionInputs.first,
    ),
    adapted: () => _repository(adapted, mapper).advance(
      interactionId: interactionId,
      expectedRevision: 1,
      input: interactionInputs.first,
    ),
  );

  await _expectAdvanceParity(
    direct: () => direct.engine.advance(
      interactionId: interactionId,
      expectedRevision: -1,
      input: interactionInputs.first,
    ),
    adapted: () => _repository(adapted, mapper).advance(
      interactionId: interactionId,
      expectedRevision: -1,
      input: interactionInputs.first,
    ),
  );
}

Future<void> _expectDuplicateAndEventIdParity(InteractionMapper mapper) async {
  final direct = InteractionEngineHarness();
  final adapted = InteractionEngineHarness();
  await direct.engine.initialize(ritualRoomId);
  await adapted.engine.initialize(ritualRoomId);
  final original = interactionInputs.first;

  await direct.engine.advance(
    interactionId: interactionId,
    expectedRevision: 0,
    input: original,
  );
  await _repository(
    adapted,
    mapper,
  ).advance(interactionId: interactionId, expectedRevision: 0, input: original);

  await _expectAdvanceParity(
    direct: () => direct.engine.advance(
      interactionId: interactionId,
      expectedRevision: 0,
      input: original,
    ),
    adapted: () => _repository(adapted, mapper).advance(
      interactionId: interactionId,
      expectedRevision: 0,
      input: original,
    ),
  );

  final changedReuse = InputEvent.reactionSelection(
    eventId: original.eventId,
    occurredAt: original.occurredAt,
    selected: 'joining_action',
  );
  await _expectAdvanceParity(
    direct: () => direct.engine.advance(
      interactionId: interactionId,
      expectedRevision: 1,
      input: changedReuse,
    ),
    adapted: () => _repository(adapted, mapper).advance(
      interactionId: interactionId,
      expectedRevision: 1,
      input: changedReuse,
    ),
  );
}

Future<void> _expectUnsupportedSchemaParity(InteractionMapper mapper) async {
  for (final schemaVersion in const [1, 3]) {
    final direct = InteractionEngineHarness();
    final adapted = InteractionEngineHarness();
    final unsupported = interactionSnapshot();
    final unsupportedSnapshot = ProductSnapshot(
      schemaVersion: schemaVersion,
      revision: unsupported.revision,
      interactionId: 'unsupported-interaction-$schemaVersion',
      ritualRoomId: unsupported.ritualRoomId,
      anchor: unsupported.anchor,
      normalizedContext: unsupported.normalizedContext,
      memory: unsupported.memory,
      strategy: unsupported.strategy,
      activeUtterance: unsupported.activeUtterance,
      metadata: unsupported.metadata,
    );
    direct.store.add(InteractionRuntimeState.initial(unsupportedSnapshot));
    adapted.store.add(InteractionRuntimeState.initial(unsupportedSnapshot));

    await _expectAdvanceParity(
      direct: () => direct.engine.advance(
        interactionId: unsupportedSnapshot.interactionId,
        expectedRevision: 0,
        input: interactionInputs.first,
      ),
      adapted: () => _repository(adapted, mapper).advance(
        interactionId: unsupportedSnapshot.interactionId,
        expectedRevision: 0,
        input: interactionInputs.first,
      ),
    );
  }
}

Future<void> _expectPipelineFailureParity(InteractionMapper mapper) async {
  final direct = InteractionEngineHarness(failPipeline: true);
  final adapted = InteractionEngineHarness(failPipeline: true);
  await direct.engine.initialize(ritualRoomId);
  await adapted.engine.initialize(ritualRoomId);

  await _expectAdvanceParity(
    direct: () => direct.engine.advance(
      interactionId: interactionId,
      expectedRevision: 0,
      input: interactionInputs.first,
    ),
    adapted: () => _repository(adapted, mapper).advance(
      interactionId: interactionId,
      expectedRevision: 0,
      input: interactionInputs.first,
    ),
  );
}

InteractionRepositoryImpl _repository(
  InteractionEngineHarness harness,
  InteractionMapper mapper,
) => InteractionRepositoryImpl(
  api: MockInteractionApi(engine: harness.engine, mapper: mapper),
  mapper: mapper,
);

Future<void> _expectAdvanceParity({
  required Future<AdvanceResult> Function() direct,
  required Future<AdvanceResult> Function() adapted,
}) async {
  final directResult = await direct();
  final adaptedResult = await adapted();

  expect(adaptedResult.status, directResult.status);
  switch ((directResult, adaptedResult)) {
    case (
      AdvanceApplied(snapshot: final directSnapshot),
      AdvanceApplied(snapshot: final adaptedSnapshot),
    ):
      expectProductSnapshotEquals(adaptedSnapshot, directSnapshot);
    case (
      AdvanceDuplicateIgnored(snapshot: final directSnapshot),
      AdvanceDuplicateIgnored(snapshot: final adaptedSnapshot),
    ):
      expectProductSnapshotEquals(adaptedSnapshot, directSnapshot);
    case (
      AdvanceRejected(
        code: final directCode,
        latestSnapshot: final directSnapshot,
      ),
      AdvanceRejected(
        code: final adaptedCode,
        latestSnapshot: final adaptedSnapshot,
      ),
    ):
      expect(adaptedCode, directCode);
      if (directCode == AdvanceErrorCode.unsupportedSchemaVersion) {
        expect(adaptedSnapshot, isNull);
        return;
      }
      expect(adaptedSnapshot == null, directSnapshot == null);
      if (directSnapshot != null && adaptedSnapshot != null) {
        expectProductSnapshotEquals(adaptedSnapshot, directSnapshot);
      }
    default:
      fail('adapter changed the direct engine result variant');
  }
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
  expect(actual.activeUtterance.displayId, expected.activeUtterance.displayId);
  expect(actual.activeUtterance.primary, expected.activeUtterance.primary);
  expect(actual.activeUtterance.zhSupport, expected.activeUtterance.zhSupport);
  expect(actual.activeUtterance.actionCue, expected.activeUtterance.actionCue);
  expect(
    actual.activeUtterance.audioAssetId,
    expected.activeUtterance.audioAssetId,
  );
  expect(
    actual.activeUtterance.contextLabel,
    expected.activeUtterance.contextLabel,
  );
  expect(
    actual.activeUtterance.gentleSupport,
    expected.activeUtterance.gentleSupport,
  );
  expect(actual.metadata.lastEventId, expected.metadata.lastEventId);
  expect(actual.metadata.updatedAt, expected.metadata.updatedAt);
}
