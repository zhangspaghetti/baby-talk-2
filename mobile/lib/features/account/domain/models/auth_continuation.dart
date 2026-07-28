import 'package:mobile/features/custom_scene/domain/custom_scene_draft.dart';

enum AuthContinuationIntent { saveOnboardingMemory, generateCustomScene }

class AuthContinuationCustomScenePayload {
  AuthContinuationCustomScenePayload({
    required String draftId,
    required this.entrySource,
    required String clientRequestId,
    String? expectedAccountContext,
  }) : draftId = _requiredStringValue(draftId, 'draftId'),
       clientRequestId = _requiredStringValue(
         clientRequestId,
         'clientRequestId',
       ),
       expectedAccountContext = _optionalStringValue(expectedAccountContext);

  final String draftId;
  final CustomSceneEntrySource entrySource;
  final String clientRequestId;
  final String? expectedAccountContext;

  AuthContinuationCustomScenePayload copyWith({
    String? expectedAccountContext,
  }) {
    return AuthContinuationCustomScenePayload(
      draftId: draftId,
      entrySource: entrySource,
      clientRequestId: clientRequestId,
      expectedAccountContext:
          expectedAccountContext ?? this.expectedAccountContext,
    );
  }

  Map<String, Object?> toJsonMap() {
    return <String, Object?>{
      'draftId': draftId,
      'entrySource': entrySource.wireValue,
      'clientRequestId': clientRequestId,
      'expectedAccountContext': expectedAccountContext,
    };
  }

  factory AuthContinuationCustomScenePayload.fromJsonMap(
    Map<String, dynamic> json,
  ) {
    _requireExactKeys(json, const <String>{
      'draftId',
      'entrySource',
      'clientRequestId',
      'expectedAccountContext',
    });
    return AuthContinuationCustomScenePayload(
      draftId: _requiredString(json, 'draftId'),
      entrySource: parseCustomSceneEntrySource(
        _requiredString(json, 'entrySource'),
      ),
      clientRequestId: _requiredString(json, 'clientRequestId'),
      expectedAccountContext: _optionalString(json, 'expectedAccountContext'),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AuthContinuationCustomScenePayload &&
        draftId == other.draftId &&
        entrySource == other.entrySource &&
        clientRequestId == other.clientRequestId &&
        expectedAccountContext == other.expectedAccountContext;
  }

  @override
  int get hashCode => Object.hash(
    draftId,
    entrySource,
    clientRequestId,
    expectedAccountContext,
  );
}

final class AuthContinuation {
  AuthContinuation({
    required this.schemaVersion,
    required this.intent,
    required this.correlationId,
    required this.createdAt,
    required this.expiresAt,
    this.customScene,
  }) : assert(schemaVersion == currentSchemaVersion),
       assert(correlationId != ''),
       assert(expiresAt.isAfter(createdAt)),
       assert(
         (intent == AuthContinuationIntent.generateCustomScene) ==
             (customScene != null),
       );

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final AuthContinuationIntent intent;
  final String correlationId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final AuthContinuationCustomScenePayload? customScene;

  Map<String, Object> toJsonMap() {
    return <String, Object>{
      'schemaVersion': schemaVersion,
      'intent': _intentToWireValue(intent),
      'correlationId': correlationId,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'expiresAt': expiresAt.toUtc().toIso8601String(),
      if (customScene != null) 'customScene': customScene!.toJsonMap(),
    };
  }

  factory AuthContinuation.fromJsonMap(Map<String, dynamic> json) {
    final schemaVersion = _requiredInt(json, 'schemaVersion');
    if (schemaVersion != currentSchemaVersion) {
      throw FormatException(
        'Unsupported auth continuation schema: $schemaVersion',
      );
    }
    final createdAt = _requiredDateTime(json, 'createdAt');
    final expiresAt = _requiredDateTime(json, 'expiresAt');
    final correlationId = _requiredString(json, 'correlationId');
    if (!expiresAt.isAfter(createdAt)) {
      throw const FormatException(
        'Auth continuation expiry must be after creation.',
      );
    }
    final intent = _intentFromWireValue(_requiredString(json, 'intent'));
    final customSceneJson = json['customScene'];
    final AuthContinuationCustomScenePayload? customScene;
    if (intent == AuthContinuationIntent.generateCustomScene) {
      if (customSceneJson is! Map<String, dynamic>) {
        throw const FormatException(
          'Custom scene continuation payload is required.',
        );
      }
      customScene = AuthContinuationCustomScenePayload.fromJsonMap(
        customSceneJson,
      );
    } else {
      if (customSceneJson != null) {
        throw const FormatException(
          'Onboarding continuation cannot contain custom scene payload.',
        );
      }
      customScene = null;
    }
    return AuthContinuation(
      schemaVersion: schemaVersion,
      intent: intent,
      correlationId: correlationId,
      createdAt: createdAt,
      expiresAt: expiresAt,
      customScene: customScene,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AuthContinuation &&
        schemaVersion == other.schemaVersion &&
        intent == other.intent &&
        correlationId == other.correlationId &&
        createdAt == other.createdAt &&
        expiresAt == other.expiresAt &&
        customScene == other.customScene;
  }

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    intent,
    correlationId,
    createdAt,
    expiresAt,
    customScene,
  );
}

String _intentToWireValue(AuthContinuationIntent intent) {
  return switch (intent) {
    AuthContinuationIntent.saveOnboardingMemory => 'save_onboarding_memory',
    AuthContinuationIntent.generateCustomScene => 'generate_custom_scene',
  };
}

AuthContinuationIntent _intentFromWireValue(String value) {
  return switch (value) {
    'save_onboarding_memory' => AuthContinuationIntent.saveOnboardingMemory,
    'generate_custom_scene' => AuthContinuationIntent.generateCustomScene,
    _ => throw FormatException('Unknown auth continuation intent: $value'),
  };
}

void _requireExactKeys(Map<String, dynamic> json, Set<String> expected) {
  final actual = json.keys.toSet();
  if (actual.length != expected.length || !actual.containsAll(expected)) {
    throw const FormatException(
      'Custom scene continuation payload fields are invalid.',
    );
  }
}

String _requiredStringValue(String value, String fieldName) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, fieldName, '不能为空。');
  }
  return normalized;
}

String? _optionalStringValue(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('Auth continuation `$key` must be a string.');
  }
  return _optionalStringValue(value);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException(
      'Auth continuation `$key` must be a non-empty string.',
    );
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
