import 'package:flutter/foundation.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';
import 'package:mobile/features/practice/domain/models/interaction_event_payload.dart';

enum OnboardingFlowStep {
  welcome,
  age,
  scenePreferences,
  supportGoal,
  currentMoment,
  careTurn,
  trace,
  accountInvitation,
  completing,
}

extension OnboardingFlowStepWire on OnboardingFlowStep {
  String get wireValue => switch (this) {
    OnboardingFlowStep.welcome => 'welcome',
    OnboardingFlowStep.age => 'age',
    OnboardingFlowStep.scenePreferences => 'scene_preferences',
    OnboardingFlowStep.supportGoal => 'support_goal',
    OnboardingFlowStep.currentMoment => 'current_moment',
    OnboardingFlowStep.careTurn => 'care_turn',
    OnboardingFlowStep.trace => 'trace',
    OnboardingFlowStep.accountInvitation => 'account_invitation',
    OnboardingFlowStep.completing => 'completing',
  };
}

OnboardingFlowStep parseOnboardingFlowStep(String value) => switch (value
    .trim()) {
  'welcome' => OnboardingFlowStep.welcome,
  'age' => OnboardingFlowStep.age,
  'scene_preferences' => OnboardingFlowStep.scenePreferences,
  'support_goal' => OnboardingFlowStep.supportGoal,
  'current_moment' => OnboardingFlowStep.currentMoment,
  'care_turn' => OnboardingFlowStep.careTurn,
  'trace' => OnboardingFlowStep.trace,
  'account_invitation' => OnboardingFlowStep.accountInvitation,
  'completing' => OnboardingFlowStep.completing,
  final unknown => throw FormatException('未知 onboarding flow step: $unknown'),
};

class OnboardingMomentChoice {
  const OnboardingMomentChoice({
    required this.spaceId,
    required this.activityId,
    required this.spaceTitle,
    required this.title,
    required this.summary,
  });

  final String spaceId;
  final String activityId;
  final String spaceTitle;
  final String title;
  final String summary;
}

class OnboardingFlowSnapshot {
  static const int currentSchemaVersion = 1;

  OnboardingFlowSnapshot({
    int schemaVersion = currentSchemaVersion,
    this.step = OnboardingFlowStep.welcome,
    this.ageBucket,
    List<String> selectedSceneIds = const <String>[],
    this.supportGoal,
    this.selectedSpaceId,
    this.selectedActivityId,
    this.starterPhraseId,
    this.pendingLocalEventId,
    this.selectedReaction,
    this.traceEventKey,
    this.gardenTraceDegraded = false,
    required this.updatedAt,
  }) : schemaVersion = _validateSchemaVersion(schemaVersion),
       selectedSceneIds = List<String>.unmodifiable(selectedSceneIds);

  final int schemaVersion;
  final OnboardingFlowStep step;
  final OnboardingAgeBucket? ageBucket;
  final List<String> selectedSceneIds;
  final OnboardingSupportGoal? supportGoal;
  final String? selectedSpaceId;
  final String? selectedActivityId;
  final String? starterPhraseId;
  final String? pendingLocalEventId;
  final BabyReactionType? selectedReaction;
  final String? traceEventKey;
  final bool gardenTraceDegraded;
  final DateTime updatedAt;

  bool get hasSelectedMoment =>
      selectedSpaceId?.trim().isNotEmpty == true &&
      selectedActivityId?.trim().isNotEmpty == true;

  bool get hasConfirmedTrace => traceEventKey?.trim().isNotEmpty == true;

  factory OnboardingFlowSnapshot.initial(DateTime now) =>
      OnboardingFlowSnapshot(updatedAt: now.toUtc());

  static const Object _notProvided = Object();

  static int _validateSchemaVersion(int value) {
    if (value != currentSchemaVersion) {
      throw FormatException('不支持的 onboarding flow schemaVersion: $value');
    }
    return value;
  }

  OnboardingFlowSnapshot copyWith({
    int? schemaVersion,
    OnboardingFlowStep? step,
    Object? ageBucket = _notProvided,
    List<String>? selectedSceneIds,
    Object? supportGoal = _notProvided,
    Object? selectedSpaceId = _notProvided,
    Object? selectedActivityId = _notProvided,
    Object? starterPhraseId = _notProvided,
    Object? pendingLocalEventId = _notProvided,
    Object? selectedReaction = _notProvided,
    Object? traceEventKey = _notProvided,
    bool? gardenTraceDegraded,
    DateTime? updatedAt,
  }) {
    return OnboardingFlowSnapshot(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      step: step ?? this.step,
      ageBucket: identical(ageBucket, _notProvided)
          ? this.ageBucket
          : ageBucket as OnboardingAgeBucket?,
      selectedSceneIds: selectedSceneIds ?? this.selectedSceneIds,
      supportGoal: identical(supportGoal, _notProvided)
          ? this.supportGoal
          : supportGoal as OnboardingSupportGoal?,
      selectedSpaceId: identical(selectedSpaceId, _notProvided)
          ? this.selectedSpaceId
          : selectedSpaceId as String?,
      selectedActivityId: identical(selectedActivityId, _notProvided)
          ? this.selectedActivityId
          : selectedActivityId as String?,
      starterPhraseId: identical(starterPhraseId, _notProvided)
          ? this.starterPhraseId
          : starterPhraseId as String?,
      pendingLocalEventId: identical(pendingLocalEventId, _notProvided)
          ? this.pendingLocalEventId
          : pendingLocalEventId as String?,
      selectedReaction: identical(selectedReaction, _notProvided)
          ? this.selectedReaction
          : selectedReaction as BabyReactionType?,
      traceEventKey: identical(traceEventKey, _notProvided)
          ? this.traceEventKey
          : traceEventKey as String?,
      gardenTraceDegraded: gardenTraceDegraded ?? this.gardenTraceDegraded,
      updatedAt: (updatedAt ?? this.updatedAt).toUtc(),
    );
  }

  Map<String, Object?> toJsonMap() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'step': step.wireValue,
      'ageBucket': ageBucket?.wireValue,
      'selectedSceneIds': List<String>.unmodifiable(selectedSceneIds),
      'supportGoal': supportGoal?.wireValue,
      'selectedSpaceId': selectedSpaceId,
      'selectedActivityId': selectedActivityId,
      'starterPhraseId': starterPhraseId,
      'pendingLocalEventId': pendingLocalEventId,
      'selectedReaction': selectedReaction?.wireValue,
      'traceEventKey': traceEventKey,
      'gardenTraceDegraded': gardenTraceDegraded,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory OnboardingFlowSnapshot.fromJsonMap(Map<String, dynamic> json) {
    final ageBucket = _readOptionalString(json, 'ageBucket');
    final supportGoal = _readOptionalString(json, 'supportGoal');
    final selectedReaction = _readOptionalString(json, 'selectedReaction');
    return OnboardingFlowSnapshot(
      schemaVersion: _readOptionalInt(json, 'schemaVersion') ?? 1,
      step: parseOnboardingFlowStep(_readRequiredString(json, 'step')),
      ageBucket: ageBucket == null ? null : parseOnboardingAgeBucket(ageBucket),
      selectedSceneIds: _readOptionalStringList(json, 'selectedSceneIds'),
      supportGoal: supportGoal == null
          ? null
          : parseOnboardingSupportGoal(supportGoal),
      selectedSpaceId: _readOptionalString(json, 'selectedSpaceId'),
      selectedActivityId: _readOptionalString(json, 'selectedActivityId'),
      starterPhraseId: _readOptionalString(json, 'starterPhraseId'),
      pendingLocalEventId: _readOptionalString(json, 'pendingLocalEventId'),
      selectedReaction: selectedReaction == null
          ? null
          : parseBabyReactionType(selectedReaction),
      traceEventKey: _readOptionalString(json, 'traceEventKey'),
      gardenTraceDegraded:
          _readOptionalBool(json, 'gardenTraceDegraded') ?? false,
      updatedAt: _readRequiredDateTime(json, 'updatedAt'),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is OnboardingFlowSnapshot &&
        other.schemaVersion == schemaVersion &&
        other.step == step &&
        other.ageBucket == ageBucket &&
        listEquals(other.selectedSceneIds, selectedSceneIds) &&
        other.supportGoal == supportGoal &&
        other.selectedSpaceId == selectedSpaceId &&
        other.selectedActivityId == selectedActivityId &&
        other.starterPhraseId == starterPhraseId &&
        other.pendingLocalEventId == pendingLocalEventId &&
        other.selectedReaction == selectedReaction &&
        other.traceEventKey == traceEventKey &&
        other.gardenTraceDegraded == gardenTraceDegraded &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
    schemaVersion,
    step,
    ageBucket,
    Object.hashAll(selectedSceneIds),
    supportGoal,
    selectedSpaceId,
    selectedActivityId,
    starterPhraseId,
    pendingLocalEventId,
    selectedReaction,
    traceEventKey,
    gardenTraceDegraded,
    updatedAt,
  ]);
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
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('字段 `$key` 不是字符串。');
  }
  return value;
}

List<String> _readOptionalStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return const <String>[];
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('字段 `$key` 不是字符串列表。');
  }
  return List<String>.unmodifiable(value.cast<String>());
}

int? _readOptionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is int) return value;
  throw FormatException('字段 `$key` 不是整数。');
}

bool? _readOptionalBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is bool) return value;
  throw FormatException('字段 `$key` 不是布尔值。');
}

DateTime _readRequiredDateTime(Map<String, dynamic> json, String key) {
  final value = _readRequiredString(json, key);
  try {
    return DateTime.parse(value).toUtc();
  } on FormatException {
    throw FormatException('字段 `$key` 不是合法时间字符串。');
  }
}
