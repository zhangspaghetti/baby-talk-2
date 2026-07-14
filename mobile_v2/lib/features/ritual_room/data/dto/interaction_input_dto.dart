import 'dart:collection';

/// Transport representation of one ephemeral interaction input.
final class InteractionInputDto {
  InteractionInputDto({
    required this.eventId,
    required this.type,
    required DateTime timestamp,
    required Map<String, Object?> payload,
  }) : timestamp = timestamp.toUtc(),
       payload = UnmodifiableMapView(Map.of(payload));

  factory InteractionInputDto.fromJson(Map<String, Object?> json) {
    final type = _requiredString(json, 'type');
    final payload = _requiredMap(json, 'payload');
    _validatePayload(type, payload);
    return InteractionInputDto(
      eventId: _requiredString(json, 'eventId'),
      type: type,
      timestamp: _requiredTimestamp(json, 'timestamp'),
      payload: payload,
    );
  }

  final String eventId;
  final String type;
  final DateTime timestamp;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => {
    'eventId': eventId,
    'type': type,
    'timestamp': timestamp.toIso8601String(),
    'payload': Map<String, Object?>.of(payload),
  };
}

void _validatePayload(String type, Map<String, Object?> payload) {
  switch (type) {
    case 'reaction_selection':
      _requiredString(payload, 'selected');
    case 'voice_observation':
      _requiredString(payload, 'transcript');
    case 'free_text':
      _requiredString(payload, 'text');
    case 'future_signal':
      _requiredString(payload, 'signal');
      _requiredString(payload, 'value');
    case 'strategy_preference':
      _requiredString(payload, 'preference');
    default:
      throw FormatException('unsupported input type: $type');
  }
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}

DateTime _requiredTimestamp(Map<String, Object?> json, String key) {
  final value = _requiredString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('$key must be an ISO-8601 timestamp');
  }
  return parsed.toUtc();
}

Map<String, Object?> _requiredMap(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! Map) {
    throw FormatException('$key must be an object');
  }
  return value.map((mapKey, mapValue) => MapEntry(mapKey.toString(), mapValue));
}
