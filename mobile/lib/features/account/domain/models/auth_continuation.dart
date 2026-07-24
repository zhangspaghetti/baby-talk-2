enum AuthContinuationIntent { saveOnboardingMemory }

final class AuthContinuation {
  AuthContinuation({
    required this.schemaVersion,
    required this.intent,
    required this.correlationId,
    required this.createdAt,
    required this.expiresAt,
  }) : assert(schemaVersion == currentSchemaVersion),
       assert(correlationId != ''),
       assert(expiresAt.isAfter(createdAt));

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final AuthContinuationIntent intent;
  final String correlationId;
  final DateTime createdAt;
  final DateTime expiresAt;

  Map<String, Object> toJsonMap() {
    return <String, Object>{
      'schemaVersion': schemaVersion,
      'intent': _intentToWireValue(intent),
      'correlationId': correlationId,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'expiresAt': expiresAt.toUtc().toIso8601String(),
    };
  }

  factory AuthContinuation.fromJsonMap(Map<String, dynamic> json) {
    final schemaVersion = _requiredInt(json, 'schemaVersion');
    if (schemaVersion != currentSchemaVersion) {
      throw FormatException('Unsupported auth continuation schema: $schemaVersion');
    }
    final createdAt = _requiredDateTime(json, 'createdAt');
    final expiresAt = _requiredDateTime(json, 'expiresAt');
    final correlationId = _requiredString(json, 'correlationId');
    if (!expiresAt.isAfter(createdAt)) {
      throw const FormatException('Auth continuation expiry must be after creation.');
    }
    return AuthContinuation(
      schemaVersion: schemaVersion,
      intent: _intentFromWireValue(_requiredString(json, 'intent')),
      correlationId: correlationId,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AuthContinuation &&
        schemaVersion == other.schemaVersion &&
        intent == other.intent &&
        correlationId == other.correlationId &&
        createdAt == other.createdAt &&
        expiresAt == other.expiresAt;
  }

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    intent,
    correlationId,
    createdAt,
    expiresAt,
  );
}

String _intentToWireValue(AuthContinuationIntent intent) {
  return switch (intent) {
    AuthContinuationIntent.saveOnboardingMemory => 'save_onboarding_memory',
  };
}

AuthContinuationIntent _intentFromWireValue(String value) {
  return switch (value) {
    'save_onboarding_memory' => AuthContinuationIntent.saveOnboardingMemory,
    _ => throw FormatException('Unknown auth continuation intent: $value'),
  };
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Auth continuation `$key` must be a non-empty string.');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw FormatException('Auth continuation `$key` must be an integer.');
  }
  return value;
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  try {
    return DateTime.parse(value).toUtc();
  } on FormatException {
    throw FormatException('Auth continuation `$key` must be ISO-8601.');
  }
}
