import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_v2/features/ritual_room/domain/engine/normalize_engine.dart';
import 'package:mobile_v2/features/ritual_room/domain/models/input_event.dart';

void main() {
  group('RuleBasedNormalizeEngine', () {
    final occurredAt = DateTime.utc(2026, 6, 20);

    test(
      'normalizes equivalent reaction, voice, and text observations',
      () async {
        final engine = RuleBasedNormalizeEngine();
        final rawVoice = 'The child ran away from the shoes.';
        final rawText = 'Attention moved away from the shoe routine.';

        final reaction = await engine.normalize(
          InputEvent.reactionSelection(
            eventId: 'reaction-1',
            occurredAt: occurredAt,
            selected: 'running_away',
          ),
        );
        final voice = await engine.normalize(
          InputEvent.voiceObservation(
            eventId: 'voice-1',
            occurredAt: occurredAt,
            transcript: rawVoice,
          ),
        );
        final text = await engine.normalize(
          InputEvent.freeText(
            eventId: 'text-1',
            occurredAt: occurredAt,
            text: rawText,
          ),
        );

        expect(
          reaction.semanticSignals,
          containsAll(['avoidance', 'low_joinability']),
        );
        expect(voice.semanticSignals, reaction.semanticSignals);
        expect(text.semanticSignals, reaction.semanticSignals);
        expect(voice.eventSummary, isNot(rawVoice));
        expect(text.eventSummary, isNot(rawText));
        expect(voice.eventSummary, isNot(contains('child')));
        expect(text.eventSummary, isNot(contains('Attention moved away')));
      },
    );

    test('normalizes future signals as evidence', () async {
      final normalized = await RuleBasedNormalizeEngine().normalize(
        InputEvent.futureSignal(
          eventId: 'signal-1',
          occurredAt: occurredAt,
          signal: 'shared_action',
          value: 'present',
        ),
      );

      expect(normalized.semanticSignals, contains('shared_action'));
      expect(normalized.contextFrame['sourceModality'], 'future_signal');
      expect(normalized.eventSummary, isNot(contains('present')));
    });

    test('normalizes strategy preference without selecting policy', () async {
      final normalized = await RuleBasedNormalizeEngine().normalize(
        InputEvent.strategyPreference(
          eventId: 'preference-1',
          occurredAt: occurredAt,
          preference: 'reduce_options',
        ),
      );

      expect(
        normalized.semanticSignals,
        contains('strategy_preference_reduce_options'),
      );
      expect(normalized.intentEstimate, 'preference');
      expect(normalized.contextFrame['sourceModality'], 'strategy_preference');
      expect(normalized.eventSummary, isNot(contains('low_pressure')));
    });

    test(
      'keeps observations separate from non-diagnostic interpretation',
      () async {
        final normalized = await RuleBasedNormalizeEngine().normalize(
          InputEvent.reactionSelection(
            eventId: 'reaction-2',
            occurredAt: occurredAt,
            selected: 'joining_action',
          ),
        );
        final semanticText = [
          ...normalized.semanticSignals,
          normalized.intentEstimate,
          normalized.momentHypothesis,
          normalized.eventSummary,
          ...normalized.contextFrame.values,
        ].join(' ').toLowerCase();

        expect(normalized.contextFrame['sourceModality'], 'reaction_selection');
        expect(normalized.semanticSignals, contains('shared_action'));
        expect(
          semanticText,
          isNot(matches(RegExp(r'lesson|score|correct|diagnos|ability|trait'))),
        );
      },
    );
  });
}
