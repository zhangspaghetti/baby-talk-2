import 'interaction_snapshot_response.dart';

/// Transport result exposes only status/error and product snapshots.
final class InteractionResultResponse {
  const InteractionResultResponse({
    required this.status,
    this.error,
    this.snapshot,
    this.latestSnapshot,
  });

  factory InteractionResultResponse.fromJson(Map<String, Object?> json) =>
      InteractionResultResponse(
        status: _requiredString(json, 'status'),
        error: _optionalString(json, 'error'),
        snapshot: _optionalSnapshot(json, 'snapshot'),
        latestSnapshot: _optionalSnapshot(json, 'latestSnapshot'),
      );

  final String status;
  final String? error;
  final InteractionSnapshotResponse? snapshot;
  final InteractionSnapshotResponse? latestSnapshot;

  Map<String, Object?> toJson() => {
    'status': status,
    'error': error,
    'snapshot': snapshot?.toJson(),
    'latestSnapshot': latestSnapshot?.toJson(),
  };
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be null or a non-empty string');
  }
  return value;
}

InteractionSnapshotResponse? _optionalSnapshot(
  Map<String, Object?> json,
  String key,
) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! Map) {
    throw FormatException('$key must be null or an object');
  }
  return InteractionSnapshotResponse.fromJson(
    value.map((mapKey, mapValue) => MapEntry(mapKey.toString(), mapValue)),
  );
}
