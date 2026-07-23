import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile/features/onboarding/domain/models/stage_match.dart';

part '../../../../generated/features/onboarding/domain/models/onboarding_snapshot.freezed.dart';

enum OnboardingConsentState { localOnly }

extension OnboardingConsentStateWire on OnboardingConsentState {
  String get wireValue {
    switch (this) {
      case OnboardingConsentState.localOnly:
        return 'local_only';
    }
  }
}

OnboardingConsentState parseOnboardingConsentState(String value) {
  switch (value.trim()) {
    case 'local_only':
      return OnboardingConsentState.localOnly;
    default:
      throw FormatException('未知 onboarding consentState: $value');
  }
}

@freezed
class OnboardingSnapshot with _$OnboardingSnapshot {
  const OnboardingSnapshot._();

  const factory OnboardingSnapshot({
    @Default(1) int schemaVersion,
    required String childDisplayName,
    required OnboardingAgeBucket ageBucket,
    required int approxMonths,
    required String currentStage,
    required String starterSpaceId,
    required String starterActivityId,
    required String starterPhraseId,
    @Default(<String>[]) List<String> selectedSceneIds,
    @Default(OnboardingSupportGoal.firstWords)
    OnboardingSupportGoal supportGoal,
    String? firstTraceEventKey,
    required OnboardingConsentState consentState,
    DateTime? birthDate,
    DateTime? completedAt,
  }) = _OnboardingSnapshot;

  /// Raw deserialization without validation. Use [fromJsonValidated] for
  /// deserialization with full validation (checks StageMatch, approxMonths > 0).
  factory OnboardingSnapshot.fromJson(Map<String, dynamic> json) {
    return OnboardingSnapshot(
      schemaVersion: _readOptionalInt(json, 'schemaVersion') ?? 1,
      childDisplayName: json['childDisplayName'] as String,
      ageBucket: parseOnboardingAgeBucket(json['ageBucket'] as String),
      approxMonths: json['approxMonths'] as int,
      currentStage: json['currentStage'] as String,
      starterSpaceId: json['starterSpaceId'] as String,
      starterActivityId: json['starterActivityId'] as String,
      starterPhraseId: json['starterPhraseId'] as String,
      selectedSceneIds: _readOptionalStringList(json, 'selectedSceneIds'),
      supportGoal: _readOptionalSupportGoal(json),
      firstTraceEventKey: _readOptionalString(json, 'firstTraceEventKey'),
      consentState: parseOnboardingConsentState(json['consentState'] as String),
      birthDate: _readOptionalDateTime(json, 'birthDate'),
      completedAt: _readOptionalDateTime(json, 'completedAt'),
    );
  }

  /// Deserialization with full validation: checks StageMatchCatalog and
  /// approxMonths > 0. Throws [FormatException] on invalid data.
  factory OnboardingSnapshot.fromJsonValidated(Map<String, dynamic> json) {
    final ageBucket = parseOnboardingAgeBucket(
      _readRequiredString(json, 'ageBucket'),
    );
    final currentStage = _readRequiredString(json, 'currentStage');
    if (StageMatchCatalog.maybeForStageId(currentStage) == null) {
      throw FormatException('未知 currentStage: $currentStage');
    }

    final approxMonths = _readRequiredInt(json, 'approxMonths');
    if (approxMonths <= 0) {
      throw FormatException('approxMonths 必须大于 0，收到: $approxMonths');
    }

    return OnboardingSnapshot(
      schemaVersion: _readOptionalInt(json, 'schemaVersion') ?? 1,
      childDisplayName: _readRequiredString(json, 'childDisplayName'),
      ageBucket: ageBucket,
      approxMonths: approxMonths,
      currentStage: currentStage,
      starterSpaceId: _readRequiredString(json, 'starterSpaceId'),
      starterActivityId: _readRequiredString(json, 'starterActivityId'),
      starterPhraseId: _readRequiredString(json, 'starterPhraseId'),
      selectedSceneIds: _readOptionalStringList(json, 'selectedSceneIds'),
      supportGoal: _readOptionalSupportGoal(json),
      firstTraceEventKey: _readOptionalString(json, 'firstTraceEventKey'),
      consentState: parseOnboardingConsentState(
        _readRequiredString(json, 'consentState'),
      ),
      birthDate: _readOptionalDateTime(json, 'birthDate'),
      completedAt: _readOptionalDateTime(json, 'completedAt'),
    );
  }

  /// Backwards-compatible alias for [fromJsonValidated].
  factory OnboardingSnapshot.fromJsonMap(Map<String, dynamic> json) {
    return OnboardingSnapshot.fromJsonValidated(json);
  }

  bool get isCompleted {
    final legacyCoreComplete =
        childDisplayName.trim().isNotEmpty &&
        currentStage.trim().isNotEmpty &&
        starterSpaceId.trim().isNotEmpty &&
        starterActivityId.trim().isNotEmpty &&
        starterPhraseId.trim().isNotEmpty &&
        completedAt != null;
    if (!legacyCoreComplete) return false;
    if (schemaVersion < 2) return true;
    return firstTraceEventKey?.trim().isNotEmpty ?? false;
  }

  Map<String, Object?> toJsonMap() {
    return {
      'schemaVersion': schemaVersion,
      'childDisplayName': childDisplayName,
      'ageBucket': ageBucket.wireValue,
      'approxMonths': approxMonths,
      'currentStage': currentStage,
      'starterSpaceId': starterSpaceId,
      'starterActivityId': starterActivityId,
      'starterPhraseId': starterPhraseId,
      'selectedSceneIds': selectedSceneIds,
      'supportGoal': supportGoal.wireValue,
      'firstTraceEventKey': firstTraceEventKey,
      'completedAt': completedAt?.toUtc().toIso8601String(),
      'consentState': consentState.wireValue,
      'birthDate': birthDate?.toUtc().toIso8601String(),
    };
  }

  // --- Validation helpers ---

  static String _readRequiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String) {
      throw FormatException('字段 `$key` 缺失或不是字符串。');
    }
    return value;
  }

  static int _readRequiredInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    throw FormatException('字段 `$key` 缺失或不是整数。');
  }

  static int? _readOptionalInt(Map<String, dynamic> json, String key) {
    if (!json.containsKey(key) || json[key] == null) return null;
    return _readRequiredInt(json, key);
  }

  static String? _readOptionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('字段 `$key` 不是字符串。');
    }
    return value;
  }

  static List<String> _readOptionalStringList(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value == null) return const <String>[];
    if (value is! List || value.any((item) => item is! String)) {
      throw FormatException('字段 `$key` 不是字符串列表。');
    }
    return List<String>.unmodifiable(value.cast<String>());
  }

  static OnboardingSupportGoal _readOptionalSupportGoal(
    Map<String, dynamic> json,
  ) {
    final value = json['supportGoal'];
    if (value == null) return OnboardingSupportGoal.firstWords;
    if (value is! String) {
      throw const FormatException('字段 `supportGoal` 缺失或不是字符串。');
    }
    return parseOnboardingSupportGoal(value);
  }

  static DateTime? _readOptionalDateTime(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('字段 `$key` 不是合法时间字符串。');
    }
    return DateTime.parse(value).toUtc();
  }
}
