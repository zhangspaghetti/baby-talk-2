enum CustomSceneFailureKind {
  authenticationRequired,
  profileUnavailable,
  householdAccessRequired,
  sharedProfileUnavailable,
  presetSceneUnavailable,
  invalidDraft,
  requestConflict,
  requestTerminal,
  generationInProgress,
  rateLimited,
  unavailable,
  timeout,
  network,
  malformedResponse,
  rejected,
  unexpected,
}

enum CustomSceneRecoveryAction { householdStatus, babyProfile }

extension CustomSceneRecoveryActionWire on CustomSceneRecoveryAction {
  String get wireValue => switch (this) {
    CustomSceneRecoveryAction.householdStatus => 'household_status',
    CustomSceneRecoveryAction.babyProfile => 'baby_profile',
  };
}

class CustomSceneFailure implements Exception {
  const CustomSceneFailure({
    required this.kind,
    required this.retryable,
    this.generatedContentId,
    this.requiresNewClientRequestId = false,
  });

  final CustomSceneFailureKind kind;
  final bool retryable;
  final String? generatedContentId;
  final bool requiresNewClientRequestId;

  CustomSceneRecoveryAction? get recoveryAction => switch (kind) {
    CustomSceneFailureKind.householdAccessRequired ||
    CustomSceneFailureKind.sharedProfileUnavailable =>
      CustomSceneRecoveryAction.householdStatus,
    CustomSceneFailureKind.profileUnavailable =>
      CustomSceneRecoveryAction.babyProfile,
    _ => null,
  };

  @override
  String toString() {
    return 'CustomSceneFailure(kind: $kind, retryable: $retryable, '
        'requiresNewClientRequestId: $requiresNewClientRequestId)';
  }
}
