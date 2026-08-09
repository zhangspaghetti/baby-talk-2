class GeneratedCareTurnResumeMarker {
  GeneratedCareTurnResumeMarker({
    required String generatedContentId,
    required DateTime confirmedAt,
  }) : generatedContentId = _required(generatedContentId),
       confirmedAt = confirmedAt.toUtc();

  final String generatedContentId;
  final DateTime confirmedAt;

  static String _required(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'generatedContentId', '不能为空。');
    }
    return normalized;
  }
}

abstract interface class GeneratedCareTurnResumeStore {
  Future<void> write({
    required String accountContext,
    required String generatedContentId,
    required DateTime confirmedAt,
  });

  Future<GeneratedCareTurnResumeMarker?> readForAccount(String accountContext);

  Future<void> clearMatching({
    required String accountContext,
    required String generatedContentId,
  });

  Future<void> clearForAccount(String accountContext);

  Future<void> clearForLifecycle();
}
