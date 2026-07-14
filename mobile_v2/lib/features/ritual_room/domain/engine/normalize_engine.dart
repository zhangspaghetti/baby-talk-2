import '../models/input_event.dart';
import '../models/normalized_input.dart';

abstract interface class NormalizeEngine {
  Future<NormalizedInput> normalize(InputEvent event);
}

final class RuleBasedNormalizeEngine implements NormalizeEngine {
  @override
  Future<NormalizedInput> normalize(InputEvent event) async {
    final result = switch (event.payload) {
      ReactionSelectionPayload(:final selected) => _fromObservation(
        selected,
        sourceModality: event.type.wireName,
      ),
      VoiceObservationPayload(:final transcript) => _fromObservation(
        transcript,
        sourceModality: event.type.wireName,
      ),
      FreeTextPayload(:final text) => _fromObservation(
        text,
        sourceModality: event.type.wireName,
      ),
      FutureSignalPayload(:final signal) => _fromFutureSignal(signal),
      StrategyPreferencePayload(:final preference) => _fromStrategyPreference(
        preference,
      ),
    };

    return result;
  }

  NormalizedInput _fromObservation(
    String observation, {
    required String sourceModality,
  }) {
    final canonical = observation.trim().toLowerCase().replaceAll(' ', '_');
    final isHardToEnter =
        canonical.contains('running_away') ||
        canonical.contains('ran_away') ||
        canonical.contains('moved_away') ||
        canonical.contains('not_ready') ||
        canonical.contains('hard_to_enter');
    final isIndependent =
        canonical.contains('trying_independently') ||
        canonical.contains('independent');
    final isShared =
        canonical.contains('joining_action') ||
        canonical.contains('shared_action') ||
        canonical.contains('together');

    if (isHardToEnter) {
      return _input(
        signals: const ['avoidance', 'low_joinability'],
        intent: 'resist',
        hypothesis: 'the shared action is currently hard to enter',
        sourceModality: sourceModality,
        confidence: 0.78,
        summary: 'the shared routine is currently difficult to enter',
      );
    }
    if (isIndependent) {
      return _input(
        signals: const ['independent_attempt', 'shared_action'],
        intent: 'engage',
        hypothesis: 'the shared action is open through an independent attempt',
        sourceModality: sourceModality,
        confidence: 0.76,
        summary: 'an independent attempt opened the shared routine',
      );
    }
    if (isShared) {
      return _input(
        signals: const ['shared_action'],
        intent: 'engage',
        hypothesis: 'the shared action is open to enter',
        sourceModality: sourceModality,
        confidence: 0.82,
        summary: 'the shared routine is available',
      );
    }

    return _input(
      signals: const ['uncertain'],
      intent: 'observe',
      hypothesis: 'the current shared-action moment remains uncertain',
      sourceModality: sourceModality,
      confidence: 0.45,
      summary: 'the current interaction evidence is uncertain',
    );
  }

  NormalizedInput _fromFutureSignal(String signal) {
    final canonical = _canonicalToken(signal);
    final signals = canonical.isEmpty ? const ['uncertain'] : [canonical];
    return _input(
      signals: signals,
      intent: 'observe',
      hypothesis: canonical == 'shared_action'
          ? 'the shared action is open to enter'
          : 'new interaction evidence is available',
      sourceModality: InputEventType.futureSignal.wireName,
      confidence: 0.7,
      summary: canonical == 'shared_action'
          ? 'the shared routine is available'
          : 'a future interaction signal was observed',
    );
  }

  NormalizedInput _fromStrategyPreference(String preference) {
    final canonical = _canonicalToken(preference);
    return _input(
      signals: ['strategy_preference_$canonical'],
      intent: 'preference',
      hypothesis: 'the caregiver supplied a language-policy preference',
      sourceModality: InputEventType.strategyPreference.wireName,
      confidence: 0.75,
      summary: 'a caregiver language preference is available as evidence',
    );
  }

  NormalizedInput _input({
    required List<String> signals,
    required String intent,
    required String hypothesis,
    required String sourceModality,
    required double confidence,
    required String summary,
  }) => NormalizedInput(
    semanticSignals: signals,
    intentEstimate: intent,
    momentHypothesis: hypothesis,
    contextFrame: {
      'actionContext': 'putting shoes on',
      'interactionType': 'caregiver_shared_action_support',
      'sourceModality': sourceModality,
    },
    confidence: confidence,
    eventSummary: summary,
  );

  String _canonicalToken(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '_')
      .replaceAll(RegExp('^_+|_+\$'), '');
}
