import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/advance_result.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/context_memory.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/input_event.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/normalized_input.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/product_snapshot.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/strategy_decision.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/utterance.dart';

void main() {
  group('InputEvent', () {
    test('exposes five distinct typed raw event variants', () {
      final occurredAt = DateTime.parse('2026-06-19T08:30:00+08:00');
      final events = <InputEvent>[
        InputEvent.reactionSelection(
          eventId: 'reaction-1',
          occurredAt: occurredAt,
          selected: 'not_ready_yet',
        ),
        InputEvent.voiceObservation(
          eventId: 'voice-1',
          occurredAt: occurredAt,
          transcript: 'the shared action is hard to enter',
        ),
        InputEvent.freeText(
          eventId: 'text-1',
          occurredAt: occurredAt,
          text: 'attention moved away from the shoes',
        ),
        InputEvent.futureSignal(
          eventId: 'signal-1',
          occurredAt: occurredAt,
          signal: 'caregiver_paused',
          value: 'true',
        ),
        InputEvent.strategyPreference(
          eventId: 'strategy-1',
          occurredAt: occurredAt,
          preference: 'reduce_options',
        ),
      ];

      expect(
        events.map((event) => event.type).toSet(),
        equals(InputEventType.values.toSet()),
      );
      expect(
        events.map((event) => event.payload.runtimeType).toSet(),
        hasLength(5),
      );
      expect(events.every((event) => event.occurredAt.isUtc), isTrue);
    });

    test('canonical content is stable and represents UTC event content', () {
      final local = InputEvent.voiceObservation(
        eventId: 'voice-1',
        occurredAt: DateTime.parse('2026-06-19T08:30:00+08:00'),
        transcript: 'shared action paused',
      );
      final utc = InputEvent.voiceObservation(
        eventId: 'voice-1',
        occurredAt: DateTime.parse('2026-06-19T00:30:00Z'),
        transcript: 'shared action paused',
      );

      expect(local.canonicalContent, utc.canonicalContent);
      expect(local.canonicalContent, contains('2026-06-19T00:30:00.000Z'));
      expect(local.canonicalContent, contains('voice_observation'));
      expect(local.canonicalContent, contains('shared action paused'));
    });
  });

  group('ProductSnapshot', () {
    test('initial snapshot separates schema version from revision', () {
      final snapshot = _initialSnapshot();

      expect(ProductSnapshot.currentSchemaVersion, 1);
      expect(snapshot.schemaVersion, 1);
      expect(snapshot.revision, 0);
      expect(snapshot.interactionId, 'interaction-1');
      expect(snapshot.ritualRoomId, 'shoes_on_room_v1');
      expect(snapshot.anchor, 'Shoes on.');
      expect(snapshot.utterance.primary, isNotEmpty);
      expect(snapshot.metadata.lastEventId, isNull);
      expect(snapshot.metadata.updatedAt.isUtc, isTrue);
    });

    test('exposed collections are immutable', () {
      final snapshot = _initialSnapshot();

      expect(
        () => snapshot.normalizedContext.semanticSignals.add('raw_signal'),
        throwsUnsupportedError,
      );
      expect(
        () => snapshot.normalizedContext.contextFrame['new'] = 'value',
        throwsUnsupportedError,
      );
      expect(
        () => snapshot.memory.eventLog.add('verbatim observation'),
        throwsUnsupportedError,
      );
      expect(
        () => snapshot.memory.signalWeights['avoidance'] = 0.9,
        throwsUnsupportedError,
      );
      expect(
        () => snapshot.strategy.modifiers.add(StrategyModifier.increaseClarity),
        throwsUnsupportedError,
      );
      expect(
        () => snapshot.utterance.alternatives.add('another line'),
        throwsUnsupportedError,
      );
    });

    test(
      'product truth source excludes raw, replay, receipt, and UI state',
      () {
        final source = File(
          'lib/features/ritual_room/domain/models/product_snapshot.dart',
        ).readAsStringSync();
        const forbidden = <String>[
          'rawTranscript',
          'rawFreeText',
          'InputEvent',
          'ConsistencyState',
          'ReplayJournal',
          'processedEvents',
          'receipt',
          'isLoading',
          'isSubmitting',
          'navigation',
        ];

        for (final term in forbidden) {
          expect(
            source,
            isNot(contains(term)),
            reason: 'ProductSnapshot leaked $term',
          );
        }
      },
    );
  });

  group('AdvanceResult', () {
    test('covers both successful result variants', () {
      final snapshot = _initialSnapshot();
      final results = <AdvanceResult>[
        AdvanceApplied(snapshot),
        AdvanceDuplicateIgnored(snapshot),
      ];

      expect(results.map((result) => result.status).toSet(), {
        AdvanceStatus.applied,
        AdvanceStatus.duplicateIgnored,
      });
      expect(results.every((result) => result.snapshot == snapshot), isTrue);
    });

    test(
      'covers every locked rejection code and latest snapshot conflicts',
      () {
        final snapshot = _initialSnapshot();

        expect(AdvanceErrorCode.values.toSet(), {
          AdvanceErrorCode.interactionNotFound,
          AdvanceErrorCode.revisionConflict,
          AdvanceErrorCode.eventIdConflict,
          AdvanceErrorCode.unsupportedSchemaVersion,
          AdvanceErrorCode.invalidInput,
          AdvanceErrorCode.pipelineFailed,
        });

        final revisionConflict = AdvanceRejected(
          code: AdvanceErrorCode.revisionConflict,
          latestSnapshot: snapshot,
        );
        final eventIdConflict = AdvanceRejected(
          code: AdvanceErrorCode.eventIdConflict,
          latestSnapshot: snapshot,
        );
        final notFound = const AdvanceRejected(
          code: AdvanceErrorCode.interactionNotFound,
        );

        expect(revisionConflict.latestSnapshot, same(snapshot));
        expect(eventIdConflict.latestSnapshot, same(snapshot));
        expect(notFound.latestSnapshot, isNull);
        expect(revisionConflict.status, AdvanceStatus.rejected);
      },
    );
  });
}

ProductSnapshot _initialSnapshot() => ProductSnapshot.initial(
  interactionId: 'interaction-1',
  ritualRoomId: 'shoes_on_room_v1',
  anchor: 'Shoes on.',
  normalizedContext: NormalizedInput(
    semanticSignals: ['shared_action'],
    intentEstimate: 'engage',
    momentHypothesis: 'the shared action is open to enter',
    contextFrame: {
      'actionContext': 'putting shoes on',
      'interactionType': 'caregiver_shared_action_support',
    },
    confidence: 0.8,
    eventSummary: 'the shared shoe routine is available',
  ),
  memory: ContextMemory(
    summary: 'the interaction has just started',
    eventLog: ['interaction initialized'],
    signalWeights: {'shared_action': 1.0},
    interactionTrend: 'stable',
    contextStability: 1.0,
    narrative: 'caregiver and child are at the shoe routine',
  ),
  strategy: StrategyDecision(
    primary: PressurePolicy.lowPressure,
    modifiers: [
      StrategyModifier.continueInteraction,
      StrategyModifier.maintain,
    ],
    confidence: 0.9,
    rationale: 'begin with one warm shared action',
    pressureLevel: 20,
    recommendedTone: 'soft',
    interactionHint:
        'offer one small shared action without requiring a response',
  ),
  utterance: Utterance(
    primary: "Let's put your shoes on.",
    zhHelper: '我们来穿鞋吧。',
    tone: 'soft',
    clarityLevel: 'high',
    contextFit: 'when beginning the shared shoe routine',
    alternatives: [],
  ),
  updatedAt: DateTime.utc(2026, 6, 19),
);
