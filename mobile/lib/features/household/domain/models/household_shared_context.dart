import 'package:mobile/features/practice/presentation/practice_route_args.dart';

class HouseholdSharedContext {
  const HouseholdSharedContext({
    required this.babyProfileSummary,
    required this.continuitySummary,
    required this.gardenSummary,
    required this.practiceArgs,
    required this.latestInteractionAt,
    required this.updatedAt,
  });

  final String babyProfileSummary;
  final String continuitySummary;
  final String gardenSummary;
  final PracticeRouteArgs practiceArgs;
  final DateTime latestInteractionAt;
  final DateTime updatedAt;

  Map<String, Object?> toJsonMap() {
    return <String, Object?>{
      'babyProfileSummary': babyProfileSummary,
      'continuitySummary': continuitySummary,
      'gardenSummary': gardenSummary,
      'practice': <String, Object?>{
        'spaceId': practiceArgs.spaceId,
        'activityId': practiceArgs.activityId,
      },
      'latestInteractionAt': latestInteractionAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory HouseholdSharedContext.fromJsonMap(Map<String, dynamic> json) {
    final practiceJson = _readRequiredMap(json, 'practice');
    final practiceArgs = PracticeRouteArgs.maybeCreate(
      spaceId: _readOptionalString(practiceJson, 'spaceId'),
      activityId: _readOptionalString(practiceJson, 'activityId'),
    );
    if (practiceArgs == null) {
      throw const FormatException('shared context 缺少有效 practice route args。');
    }
    return HouseholdSharedContext(
      babyProfileSummary: _readRequiredString(json, 'babyProfileSummary'),
      continuitySummary: _readRequiredString(json, 'continuitySummary'),
      gardenSummary: _readRequiredString(json, 'gardenSummary'),
      practiceArgs: practiceArgs,
      latestInteractionAt: _readRequiredDateTime(json, 'latestInteractionAt'),
      updatedAt: _readRequiredDateTime(json, 'updatedAt'),
    );
  }
}

String _readRequiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('字段 `$key` 缺失或不是非空字符串。');
  }
  return value;
}

String? _readOptionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('字段 `$key` 不是字符串。');
  }
  return value;
}

DateTime _readRequiredDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('字段 `$key` 缺失或不是合法时间字符串。');
  }
  return DateTime.parse(value).toUtc();
}

Map<String, dynamic> _readRequiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map<String, dynamic>) {
    throw FormatException('字段 `$key` 不是对象。');
  }
  return value;
}
