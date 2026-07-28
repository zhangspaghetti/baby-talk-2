enum CustomSceneEntrySource { today, scene }

class CustomSceneRequestIdentity {
  CustomSceneRequestIdentity({required String clientRequestId})
    : clientRequestId = _required(clientRequestId, 'clientRequestId');

  final String clientRequestId;

  static String _required(String value, String fieldName) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, fieldName, '不能为空。');
    }
    return normalized;
  }
}

class CustomSceneDraft {
  CustomSceneDraft({
    required String text,
    required this.entrySource,
    required this.requestIdentity,
  }) : text = _required(text, 'text');

  final String text;
  final CustomSceneEntrySource entrySource;
  final CustomSceneRequestIdentity requestIdentity;

  static String _required(String value, String fieldName) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, fieldName, '不能为空。');
    }
    return normalized;
  }
}

/// Server-supported profile context. This type stays mobile-owned: no backend
/// DTO reaches application or presentation code.
class CustomSceneProfileContext {
  CustomSceneProfileContext({
    required String ageRange,
    required String parentGoal,
    required String locale,
    String? babyProfileId,
  }) : ageRange = _required(ageRange, 'ageRange'),
       parentGoal = _required(parentGoal, 'parentGoal'),
       locale = _required(locale, 'locale'),
       babyProfileId = _optional(babyProfileId);

  final String ageRange;
  final String parentGoal;
  final String locale;
  final String? babyProfileId;

  static String _required(String value, String fieldName) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, fieldName, '不能为空。');
    }
    return normalized;
  }

  static String? _optional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
