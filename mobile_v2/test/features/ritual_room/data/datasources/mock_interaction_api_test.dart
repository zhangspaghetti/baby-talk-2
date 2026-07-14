import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/features/ritual_room/data/datasources/mock_interaction_api.dart';
import 'package:mobile_v2/features/ritual_room/data/mappers/interaction_mapper.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/advance_result.dart';
import 'package:mobile_v2/features/ritual_room/domain/runtime/interaction_session_initializer.dart';

import '../../../../fixtures/interaction_test_fixtures.dart';
import '../../../../helpers/interaction_test_doubles.dart';

void main() {
  const mapper = InteractionMapper();

  test(
    'getSnapshot delegates exactly once without initializer capability',
    () async {
      final snapshot = interactionSnapshot();
      final engine = FakeInteractionEnginePort(
        advanceResult: AdvanceApplied(snapshot),
        snapshot: snapshot,
      );
      final api = MockInteractionApi(engine: engine, mapper: mapper);

      final response = await api.getSnapshot(interactionId);

      expect(engine.snapshotCalls, 1);
      expect(engine.advanceCalls, 0);
      expect(engine.lastInteractionId, interactionId);
      expect(engine, isNot(isA<InteractionSessionInitializer>()));
      expect(mapper.snapshotToDomain(response).interactionId, interactionId);
    },
  );

  test('advance delegates unchanged domain input exactly once', () async {
    final snapshot = interactionSnapshot(revision: 1);
    final engine = FakeInteractionEnginePort(
      advanceResult: AdvanceApplied(snapshot),
    );
    final api = MockInteractionApi(engine: engine, mapper: mapper);
    final request = interactionRequest();

    final response = await api.advance(
      interactionId: interactionId,
      request: request,
    );

    expect(engine.advanceCalls, 1);
    expect(engine.snapshotCalls, 0);
    expect(engine.lastInteractionId, interactionId);
    expect(engine.lastExpectedRevision, request.expectedRevision);
    expect(
      engine.lastInput!.canonicalContent,
      interactionInputs.first.canonicalContent,
    );
    expect(response.status, AdvanceStatus.applied.wireName);
    expect(response.snapshot!.revision, 1);
  });

  test(
    'maps applied, duplicate, and every rejection without adding policy',
    () async {
      final snapshot = interactionSnapshot(revision: 2);
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

      for (final result in results) {
        final engine = FakeInteractionEnginePort(advanceResult: result);
        final api = MockInteractionApi(engine: engine, mapper: mapper);

        final response = await api.advance(
          interactionId: interactionId,
          request: interactionRequest(),
        );
        final roundTripped = mapper.resultToDomain(response);

        expect(roundTripped.status, result.status);
        expect(roundTripped.snapshot?.revision, result.snapshot?.revision);
        if (result case AdvanceRejected(:final code)) {
          expect((roundTripped as AdvanceRejected).code, code);
        }
        expect(engine.advanceCalls, 1);
      }
    },
  );
}
