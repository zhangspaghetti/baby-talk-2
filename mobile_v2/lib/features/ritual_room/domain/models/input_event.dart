import 'dart:convert';

/// Every raw input channel supported by Interaction Engine v1.
enum InputEventType {
  reactionSelection('reaction_selection'),
  voiceObservation('voice_observation'),
  freeText('free_text'),
  futureSignal('future_signal'),
  strategyPreference('strategy_preference');

  const InputEventType(this.wireName);

  final String wireName;
}

sealed class InputEventPayload {
  const InputEventPayload();

  Map<String, Object?> get canonicalFields;
}

final class ReactionSelectionPayload extends InputEventPayload {
  const ReactionSelectionPayload({required this.selected});

  final String selected;

  @override
  Map<String, Object?> get canonicalFields => {'selected': selected};
}

final class VoiceObservationPayload extends InputEventPayload {
  const VoiceObservationPayload({required this.transcript});

  final String transcript;

  @override
  Map<String, Object?> get canonicalFields => {'transcript': transcript};
}

final class FreeTextPayload extends InputEventPayload {
  const FreeTextPayload({required this.text});

  final String text;

  @override
  Map<String, Object?> get canonicalFields => {'text': text};
}

final class FutureSignalPayload extends InputEventPayload {
  const FutureSignalPayload({required this.signal, required this.value});

  final String signal;
  final String value;

  @override
  Map<String, Object?> get canonicalFields => {
    'signal': signal,
    'value': value,
  };
}

final class StrategyPreferencePayload extends InputEventPayload {
  const StrategyPreferencePayload({required this.preference});

  final String preference;

  @override
  Map<String, Object?> get canonicalFields => {'preference': preference};
}

/// Ephemeral raw input envelope. Product snapshots never retain this object.
final class InputEvent {
  InputEvent._({
    required this.eventId,
    required this.type,
    required DateTime occurredAt,
    required this.payload,
  }) : occurredAt = occurredAt.toUtc();

  factory InputEvent.reactionSelection({
    required String eventId,
    required DateTime occurredAt,
    required String selected,
  }) => InputEvent._(
    eventId: eventId,
    type: InputEventType.reactionSelection,
    occurredAt: occurredAt,
    payload: ReactionSelectionPayload(selected: selected),
  );

  factory InputEvent.voiceObservation({
    required String eventId,
    required DateTime occurredAt,
    required String transcript,
  }) => InputEvent._(
    eventId: eventId,
    type: InputEventType.voiceObservation,
    occurredAt: occurredAt,
    payload: VoiceObservationPayload(transcript: transcript),
  );

  factory InputEvent.freeText({
    required String eventId,
    required DateTime occurredAt,
    required String text,
  }) => InputEvent._(
    eventId: eventId,
    type: InputEventType.freeText,
    occurredAt: occurredAt,
    payload: FreeTextPayload(text: text),
  );

  factory InputEvent.futureSignal({
    required String eventId,
    required DateTime occurredAt,
    required String signal,
    required String value,
  }) => InputEvent._(
    eventId: eventId,
    type: InputEventType.futureSignal,
    occurredAt: occurredAt,
    payload: FutureSignalPayload(signal: signal, value: value),
  );

  factory InputEvent.strategyPreference({
    required String eventId,
    required DateTime occurredAt,
    required String preference,
  }) => InputEvent._(
    eventId: eventId,
    type: InputEventType.strategyPreference,
    occurredAt: occurredAt,
    payload: StrategyPreferencePayload(preference: preference),
  );

  final String eventId;
  final InputEventType type;
  final DateTime occurredAt;
  final InputEventPayload payload;

  /// Stable complete event content used by the future fingerprint boundary.
  String get canonicalContent => jsonEncode({
    'eventId': eventId,
    'type': type.wireName,
    'timestamp': occurredAt.toIso8601String(),
    'payload': payload.canonicalFields,
  });
}
