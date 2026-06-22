import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/features/ritual_room/data/dto/interaction_advance_request.dart';
import 'package:mobile_v2/features/ritual_room/data/dto/interaction_input_dto.dart';
import 'package:mobile_v2/features/ritual_room/data/dto/interaction_result_response.dart';
import 'package:mobile_v2/features/ritual_room/data/dto/interaction_snapshot_response.dart';
import 'package:mobile_v2/features/ritual_room/data/mappers/interaction_mapper.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/advance_result.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/context_memory.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/input_event.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/normalized_input.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/product_snapshot.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/strategy_decision.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/active_utterance.dart';

void main() {
  const mapper = InteractionMapper();

  group('InteractionInputDto', () {
    final timestamp = DateTime.parse('2026-06-20T08:30:00+08:00');
    final cases =
        <({String wireType, InputEvent event, Map<String, Object?> payload})>[
          (
            wireType: 'reaction_selection',
            event: InputEvent.reactionSelection(
              eventId: 'evt-reaction',
              occurredAt: timestamp,
              selected: 'not_ready_yet',
            ),
            payload: const {'selected': 'not_ready_yet'},
          ),
          (
            wireType: 'voice_observation',
            event: InputEvent.voiceObservation(
              eventId: 'evt-voice',
              occurredAt: timestamp,
              transcript: '  wants to try independently  ',
            ),
            payload: const {'transcript': '  wants to try independently  '},
          ),
          (
            wireType: 'free_text',
            event: InputEvent.freeText(
              eventId: 'evt-text',
              occurredAt: timestamp,
              text: 'moved away from the shoes',
            ),
            payload: const {'text': 'moved away from the shoes'},
          ),
          (
            wireType: 'future_signal',
            event: InputEvent.futureSignal(
              eventId: 'evt-signal',
              occurredAt: timestamp,
              signal: 'shared_action',
              value: 'available',
            ),
            payload: const {'signal': 'shared_action', 'value': 'available'},
          ),
          (
            wireType: 'strategy_preference',
            event: InputEvent.strategyPreference(
              eventId: 'evt-preference',
              occurredAt: timestamp,
              preference: 'reduce_options',
            ),
            payload: const {'preference': 'reduce_options'},
          ),
        ];

    for (final testCase in cases) {
      test('R067 round-trips ${testCase.wireType} losslessly', () {
        final dto = mapper.inputFromDomain(testCase.event);
        final json = dto.toJson();
        final roundTripped = mapper.inputToDomain(
          InteractionInputDto.fromJson(json),
        );

        expect(json['type'], testCase.wireType);
        expect(json['eventId'], testCase.event.eventId);
        expect(json['timestamp'], testCase.event.occurredAt.toIso8601String());
        expect(json['payload'], testCase.payload);
        expect(roundTripped.canonicalContent, testCase.event.canonicalContent);
      });
    }

    test(
      'expectedRevision belongs to the request, never the input payload',
      () {
        final input = mapper.inputFromDomain(cases.first.event);
        final request = InteractionAdvanceRequest(
          expectedRevision: 7,
          input: input,
        );
        final json = request.toJson();

        expect(json['expectedRevision'], 7);
        expect(json['input'], input.toJson());
        expect(input.toJson(), isNot(contains('expectedRevision')));
        expect(
          (input.toJson()['payload']! as Map<String, Object?>),
          isNot(contains('expectedRevision')),
        );
      },
    );

    test('R060 strategy preference remains evidence, not a decision', () {
      final dto = mapper.inputFromDomain(cases.last.event);
      final domain = mapper.inputToDomain(dto);

      expect(domain.payload, isA<StrategyPreferencePayload>());
      expect(domain.payload, isNot(isA<StrategyDecision>()));
      expect(dto.toJson().toString(), isNot(contains('StrategyDecision')));
      expect(dto.toJson().toString(), isNot(contains('primary')));
    });

    test('rejects malformed required input members', () {
      final valid = mapper.inputFromDomain(cases.first.event).toJson();

      expect(
        () => InteractionInputDto.fromJson({...valid}..remove('eventId')),
        throwsFormatException,
      );
      expect(
        () => InteractionInputDto.fromJson({...valid, 'timestamp': 42}),
        throwsFormatException,
      );
      expect(
        () => InteractionInputDto.fromJson({
          ...valid,
          'payload': <String, Object?>{},
        }),
        throwsFormatException,
      );
      expect(
        () =>
            InteractionInputDto.fromJson({...valid, 'type': 'unknown_channel'}),
        throwsFormatException,
      );
    });
  });

  group('InteractionSnapshotResponse', () {
    test('schema 1 ignores unknown optional fields and maps product truth', () {
      final json = _snapshotJson()
        ..['future_optional_field'] = {'ignored': true}
        ..['metadata'] = {
          ...(_snapshotJson()['metadata']! as Map<String, Object?>),
          'future_metadata_field': 'ignored',
        };

      final response = InteractionSnapshotResponse.fromJson(json);
      final snapshot = mapper.snapshotToDomain(response);

      expect(snapshot.schemaVersion, ProductSnapshot.currentSchemaVersion);
      expect(snapshot.revision, 3);
      expect(snapshot.interactionId, 'interaction-1');
      expect(
        snapshot.normalizedContext.momentHypothesis,
        contains('uncertain'),
      );
      expect(snapshot.strategy.primary, PressurePolicy.lowPressure);
      expect(snapshot.activeUtterance.primary, "Let's pause by the shoes.");
      expect(response.toJson(), isNot(contains('future_optional_field')));
    });

    test('missing required schema-1 fields fail parsing', () {
      expect(
        () => InteractionSnapshotResponse.fromJson(
          _snapshotJson()..remove('utterance'),
        ),
        throwsFormatException,
      );
      expect(
        () => InteractionSnapshotResponse.fromJson({
          ..._snapshotJson(),
          'revision': '3',
        }),
        throwsFormatException,
      );
    });

    test('schema other than 1 maps to explicit unsupported-schema failure', () {
      final response = InteractionSnapshotResponse.fromJson({
        ..._snapshotJson(),
        'schemaVersion': 2,
      });

      expect(
        () => mapper.snapshotToDomain(response),
        throwsA(
          isA<UnsupportedInteractionSchemaException>().having(
            (error) => error.schemaVersion,
            'schemaVersion',
            2,
          ),
        ),
      );
    });
  });

  group('InteractionResultResponse', () {
    test('maps applied and duplicate results with their product snapshots', () {
      final snapshot = _snapshot();

      for (final result in <AdvanceResult>[
        AdvanceApplied(snapshot),
        AdvanceDuplicateIgnored(snapshot),
      ]) {
        final response = mapper.resultFromDomain(result);
        final roundTripped = mapper.resultToDomain(
          InteractionResultResponse.fromJson(response.toJson()),
        );

        expect(roundTripped.status, result.status);
        expect(roundTripped.snapshot!.revision, snapshot.revision);
      }
    });

    test(
      'maps every rejection code and conflict latestSnapshot explicitly',
      () {
        for (final code in AdvanceErrorCode.values) {
          final hasLatestSnapshot =
              code == AdvanceErrorCode.revisionConflict ||
              code == AdvanceErrorCode.eventIdConflict;
          final result = AdvanceRejected(
            code: code,
            latestSnapshot: hasLatestSnapshot ? _snapshot() : null,
          );

          final response = mapper.resultFromDomain(result);
          final roundTripped =
              mapper.resultToDomain(
                    InteractionResultResponse.fromJson(response.toJson()),
                  )
                  as AdvanceRejected;

          expect(response.error, code.wireName);
          expect(roundTripped.code, code);
          expect(
            roundTripped.latestSnapshot?.revision,
            hasLatestSnapshot ? 3 : null,
          );
        }
      },
    );

    test('conflict results cannot cross transport without latestSnapshot', () {
      for (final code in const [
        AdvanceErrorCode.revisionConflict,
        AdvanceErrorCode.eventIdConflict,
      ]) {
        expect(
          () => mapper.resultFromDomain(AdvanceRejected(code: code)),
          throwsFormatException,
        );
      }
    });

    test('T-41-06-02 serializes product results without engine evidence', () {
      final responses = <InteractionResultResponse>[
        mapper.resultFromDomain(AdvanceApplied(_snapshot())),
        mapper.resultFromDomain(
          AdvanceRejected(
            code: AdvanceErrorCode.revisionConflict,
            latestSnapshot: _snapshot(),
          ),
        ),
      ];
      const forbidden = <String>[
        'processedEvents',
        'inputFingerprint',
        'ConsistencyState',
        'ReplayJournal',
        'TransitionRecord',
      ];

      for (final response in responses) {
        final serialized = jsonEncode(response.toJson());
        expect(
          response.toJson().keys,
          everyElement(
            isIn(<String>['status', 'error', 'snapshot', 'latestSnapshot']),
          ),
        );
        for (final term in forbidden) {
          expect(
            serialized,
            isNot(contains(term)),
            reason: 'transport result leaked private engine evidence: $term',
          );
        }
      }
    });
  });
}

ProductSnapshot _snapshot() => ProductSnapshot(
  schemaVersion: ProductSnapshot.currentSchemaVersion,
  revision: 3,
  interactionId: 'interaction-1',
  ritualRoomId: 'shoes_on_room_v1',
  anchor: 'putting_shoes_on',
  normalizedContext: NormalizedInput(
    semanticSignals: const ['uncertain'],
    intentEstimate: 'observe',
    momentHypothesis: 'the current shared-action moment remains uncertain',
    contextFrame: const {
      'actionContext': 'putting shoes on',
      'sourceModality': 'reaction_selection',
    },
    confidence: 0.45,
    eventSummary: 'the current interaction evidence is uncertain',
  ),
  memory: ContextMemory(
    summary: 'the current interaction evidence is uncertain',
    eventLog: const ['the current interaction evidence is uncertain'],
    signalWeights: const {'uncertain': 1},
    interactionTrend: 'uncertain',
    contextStability: 0.5,
    narrative: 'The routine contains mixed current-interaction evidence.',
  ),
  strategy: StrategyDecision(
    primary: PressurePolicy.lowPressure,
    modifiers: const [StrategyModifier.pause, StrategyModifier.simplify],
    confidence: 0.8,
    rationale: 'current evidence remains uncertain',
    pressureLevel: 20,
    recommendedTone: 'soft',
    interactionHint: 'pause and offer one shared action',
  ),
  activeUtterance: const ActiveUtterance(
    displayId: 'shoes_on_pause_v1',
    primary: "Let's pause by the shoes.",
    zhSupport: '我们先在鞋子旁边等等。',
    audioAssetId: 'rr_shoes_002',
    contextLabel: 'uncertain',
  ),
  metadata: ProductSnapshotMetadata(
    lastEventId: 'evt-reaction',
    updatedAt: DateTime.parse('2026-06-20T00:30:00Z'),
  ),
);

Map<String, Object?> _snapshotJson() => {
  'schemaVersion': 1,
  'revision': 3,
  'interactionId': 'interaction-1',
  'ritualRoomId': 'shoes_on_room_v1',
  'anchor': 'putting_shoes_on',
  'normalizedContext': {
    'semanticSignals': ['uncertain'],
    'intentEstimate': 'observe',
    'momentHypothesis': 'the current shared-action moment remains uncertain',
    'contextFrame': {
      'actionContext': 'putting shoes on',
      'sourceModality': 'reaction_selection',
    },
    'confidence': 0.45,
    'eventSummary': 'the current interaction evidence is uncertain',
  },
  'memory': {
    'summary': 'the current interaction evidence is uncertain',
    'eventLog': ['the current interaction evidence is uncertain'],
    'signalWeights': {'uncertain': 1.0},
    'interactionTrend': 'uncertain',
    'contextStability': 0.5,
    'narrative': 'The routine contains mixed current-interaction evidence.',
  },
  'strategy': {
    'primary': 'low_pressure',
    'modifiers': ['pause', 'simplify'],
    'confidence': 0.8,
    'rationale': 'current evidence remains uncertain',
    'pressureLevel': 20,
    'recommendedTone': 'soft',
    'interactionHint': 'pause and offer one shared action',
  },
  'utterance': {
    'primary': "Let's pause by the shoes.",
    'zhHelper': '我们先在鞋子旁边等等。',
    'tone': 'soft',
    'clarityLevel': 'simple',
    'contextFit': 'uncertain',
    'alternatives': <String>[],
  },
  'metadata': {
    'lastEventId': 'evt-reaction',
    'updatedAt': '2026-06-20T00:30:00Z',
  },
};
