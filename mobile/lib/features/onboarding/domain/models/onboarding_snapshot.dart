import 'package:mobile/features/onboarding/domain/models/stage_match.dart';

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

class OnboardingSnapshot {
  const OnboardingSnapshot({
    required this.childDisplayName,
    required this.ageBucket,
    required this.approxMonths,
    required this.currentStage,
    required this.starterSpaceId,
    required this.starterActivityId,
    required this.starterPhraseId,
    required this.consentState,
    this.birthDate,
    this.completedAt,
  });

  final String childDisplayName;
  final OnboardingAgeBucket ageBucket;
  final int approxMonths;
  final String currentStage;
  final String starterSpaceId;
  final String starterActivityId;
  final String starterPhraseId;
  final OnboardingConsentState consentState;
  final DateTime? birthDate;
  final DateTime? completedAt;

  bool get isCompleted {
    return childDisplayName.trim().isNotEmpty &&
        currentStage.trim().isNotEmpty &&
        starterSpaceId.trim().isNotEmpty &&
        starterActivityId.trim().isNotEmpty &&
        starterPhraseId.trim().isNotEmpty &&
        completedAt != null;
  }

  Map<String, Object?> toJsonMap() {
    return {
      'childDisplayName': childDisplayName,
      'ageBucket': ageBucket.wireValue,
      'approxMonths': approxMonths,
      'currentStage': currentStage,
      'starterSpaceId': starterSpaceId,
      'starterActivityId': starterActivityId,
      'starterPhraseId': starterPhraseId,
      'completedAt': completedAt?.toUtc().toIso8601String(),
      'consentState': consentState.wireValue,
      'birthDate': birthDate?.toUtc().toIso8601String(),
    };
  }

  factory OnboardingSnapshot.fromJsonMap(Map<String, dynamic> json) {
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
      childDisplayName: _readRequiredString(json, 'childDisplayName'),
      ageBucket: ageBucket,
      approxMonths: approxMonths,
      currentStage: currentStage,
      starterSpaceId: _readRequiredString(json, 'starterSpaceId'),
      starterActivityId: _readRequiredString(json, 'starterActivityId'),
      starterPhraseId: _readRequiredString(json, 'starterPhraseId'),
      consentState: parseOnboardingConsentState(
        _readRequiredString(json, 'consentState'),
      ),
      birthDate: _readOptionalDateTime(json, 'birthDate'),
      completedAt: _readOptionalDateTime(json, 'completedAt'),
    );
  }

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

  static DateTime? _readOptionalDateTime(Map<String, dynamic> json, String key) {
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
