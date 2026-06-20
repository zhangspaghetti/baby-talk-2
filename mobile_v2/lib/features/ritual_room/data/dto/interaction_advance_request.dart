import 'interaction_input_dto.dart';

/// Request envelope keeps optimistic concurrency separate from raw input.
final class InteractionAdvanceRequest {
  const InteractionAdvanceRequest({
    required this.expectedRevision,
    required this.input,
  });

  factory InteractionAdvanceRequest.fromJson(Map<String, Object?> json) =>
      InteractionAdvanceRequest(
        expectedRevision: _requiredNonNegativeInt(json, 'expectedRevision'),
        input: InteractionInputDto.fromJson(_requiredMap(json, 'input')),
      );

  final int expectedRevision;
  final InteractionInputDto input;

  Map<String, Object?> toJson() => {
    'expectedRevision': expectedRevision,
    'input': input.toJson(),
  };
}

int _requiredNonNegativeInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int || value < 0) {
    throw FormatException('$key must be a non-negative integer');
  }
  return value;
}

Map<String, Object?> _requiredMap(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! Map) {
    throw FormatException('$key must be an object');
  }
  return value.map((mapKey, mapValue) => MapEntry(mapKey.toString(), mapValue));
}
