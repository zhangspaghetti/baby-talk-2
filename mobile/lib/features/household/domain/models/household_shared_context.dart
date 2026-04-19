import 'package:mobile/features/practice/presentation/practice_route_args.dart';

class HouseholdSharedContext {
  const HouseholdSharedContext({
    required this.babyProfileSummary,
    required this.continuitySummary,
    required this.gardenSummary,
    required this.practiceArgs,
    required this.latestInteractionAt,
    required this.updatedAt,
    this.actor,
    this.nextStep,
  });

  final String babyProfileSummary;
  final String continuitySummary;
  final String gardenSummary;
  final PracticeRouteArgs practiceArgs;
  final DateTime latestInteractionAt;
  final DateTime updatedAt;
  final HouseholdSharedActor? actor;
  final HouseholdSharedNextStep? nextStep;

  Map<String, Object?> toJsonMap() {
    return <String, Object?>{
      'babyProfileSummary': babyProfileSummary,
      'continuitySummary': continuitySummary,
      'gardenSummary': gardenSummary,
      'practice': <String, Object?>{
        'spaceId': practiceArgs.spaceId,
        'activityId': practiceArgs.activityId,
      },
      if (actor != null) 'actor': actor!.toJsonMap(),
      if (nextStep != null) 'nextStep': nextStep!.toJsonMap(),
      'latestInteractionAt': latestInteractionAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory HouseholdSharedContext.fromJsonMap(Map<String, dynamic> json) {
    final nextStep = HouseholdSharedNextStep.maybeFromJsonMap(
      _readOptionalObjectMap(json, 'nextStep'),
    );
    final practiceArgs = _readPracticeArgs(json, nextStep);
    if (practiceArgs == null) {
      throw const FormatException('shared context 缺少有效 practice route args。');
    }
    return HouseholdSharedContext(
      babyProfileSummary: _readRequiredString(json, 'babyProfileSummary'),
      continuitySummary: _readRequiredString(json, 'continuitySummary'),
      gardenSummary: _readRequiredString(json, 'gardenSummary'),
      practiceArgs: practiceArgs,
      actor: HouseholdSharedActor.maybeFromJsonMap(
        _readOptionalObjectMap(json, 'actor'),
      ),
      nextStep: nextStep,
      latestInteractionAt: _readRequiredDateTime(json, 'latestInteractionAt'),
      updatedAt: _readRequiredDateTime(json, 'updatedAt'),
    );
  }
}

class HouseholdSharedActor {
  const HouseholdSharedActor({
    required this.role,
    required this.source,
    required this.result,
  });

  final String role;
  final String source;
  final String result;

  Map<String, Object?> toJsonMap() {
    return <String, Object?>{
      'role': role,
      'source': source,
      'result': result,
    };
  }

  static HouseholdSharedActor? maybeFromJsonMap(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    final role = _readLenientOptionalString(json, 'role');
    final source = _readLenientOptionalString(json, 'source');
    final result = _readLenientOptionalString(json, 'result');
    if (role == null || source == null || result == null) {
      return null;
    }
    return HouseholdSharedActor(role: role, source: source, result: result);
  }
}

class HouseholdSharedNextStep {
  const HouseholdSharedNextStep({
    required this.spaceId,
    required this.activityId,
    this.reason,
  });

  final String spaceId;
  final String activityId;
  final String? reason;

  PracticeRouteArgs toPracticeArgs() {
    return PracticeRouteArgs(spaceId: spaceId, activityId: activityId);
  }

  Map<String, Object?> toJsonMap() {
    return <String, Object?>{
      'spaceId': spaceId,
      'activityId': activityId,
      if (reason != null) 'reason': reason,
    };
  }

  static HouseholdSharedNextStep? maybeFromJsonMap(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    final spaceId = _readLenientOptionalString(json, 'spaceId');
    final activityId = _readLenientOptionalString(json, 'activityId');
    if (spaceId == null || activityId == null) {
      return null;
    }
    return HouseholdSharedNextStep(
      spaceId: spaceId,
      activityId: activityId,
      reason: _readLenientOptionalString(json, 'reason'),
    );
  }
}

PracticeRouteArgs? _readPracticeArgs(
  Map<String, dynamic> json,
  HouseholdSharedNextStep? nextStep,
) {
  final practiceJson = _readOptionalObjectMap(json, 'practice');
  final practiceArgs = PracticeRouteArgs.maybeCreate(
    spaceId: _readLenientOptionalString(practiceJson, 'spaceId'),
    activityId: _readLenientOptionalString(practiceJson, 'activityId'),
  );
  if (practiceArgs != null) {
    return practiceArgs;
  }
  return nextStep?.toPracticeArgs();
}

String _readRequiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('字段 `$key` 缺失或不是非空字符串。');
  }
  return value.trim();
}

String? _readLenientOptionalString(Map<String, dynamic>? json, String key) {
  if (json == null) {
    return null;
  }
  final value = json[key];
  if (value is! String) {
    return null;
  }
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }
  return normalized;
}

DateTime _readRequiredDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('字段 `$key` 缺失或不是合法时间字符串。');
  }
  return DateTime.parse(value).toUtc();
}

Map<String, dynamic>? _readOptionalObjectMap(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! Map) {
    return null;
  }
  try {
    // Dart promotes value to Map after is! guard
    return value.cast<String, dynamic>();
  } on Object {
    return null;
  }
}
