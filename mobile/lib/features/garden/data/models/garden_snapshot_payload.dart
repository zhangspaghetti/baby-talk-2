// Deserialization models for the `/api/v1/garden/snapshot` response.

class GardenSnapshotPayload {
  const GardenSnapshotPayload({
    required this.generatedAt,
    required this.knownEvents,
    required this.coveredSpaceCount,
    required this.currentStreakDays,
    required this.milestones,
    required this.pendingEventKeys,
  });

  final DateTime generatedAt;
  final int knownEvents;
  final int coveredSpaceCount;
  final int currentStreakDays;
  final List<MilestonePayload> milestones;
  final List<String> pendingEventKeys;

  factory GardenSnapshotPayload.fromJson(Map<String, dynamic> json) {
    return GardenSnapshotPayload(
      generatedAt:
          _readDateTime(json, 'generatedAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      knownEvents: _readInt(json, 'knownEvents'),
      coveredSpaceCount: _readInt(json, 'coveredSpaceCount'),
      currentStreakDays: _readInt(json, 'currentStreakDays'),
      milestones: (json['milestones'] as List<dynamic>?)
              ?.map((e) => MilestonePayload.fromJson(e as Map<String, dynamic>))
              .toList(growable: false) ??
          const [],
      pendingEventKeys: _readStringList(json, 'pendingEventKeys'),
    );
  }
}

class MilestonePayload {
  const MilestonePayload({
    required this.id,
    required this.title,
    required this.sortOrder,
    this.achievedAt,
    this.remainingHint,
  });

  final String id;
  final String title;
  final int sortOrder;
  final DateTime? achievedAt;
  final String? remainingHint;

  factory MilestonePayload.fromJson(Map<String, dynamic> json) {
    return MilestonePayload(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      sortOrder: _readInt(json, 'sortOrder'),
      achievedAt: _readDateTime(json, 'achievedAt'),
      remainingHint: json['remainingHint'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

int _readInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

DateTime? _readDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

List<String> _readStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) return const [];
  final result = <String>[];
  for (final item in value) {
    if (item is String && item.trim().isNotEmpty) {
      result.add(item);
    }
  }
  return result;
}
