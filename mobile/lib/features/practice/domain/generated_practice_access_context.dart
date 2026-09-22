import 'package:mobile/features/scene_generation/domain/scene_generation_source.dart';

/// Why a current generated-content access context cannot authorize reads.
///
/// The distinction between an explicit signed-out/consent state and a failed
/// local read is intentional: both fail closed, but only the former may drive
/// a destructive lifecycle transition.
enum GeneratedPracticeAccessDeniedReason {
  accountReadUnavailable,
  signedOut,
  consentRequired,
  consentRevoked,
  accountDeleted,
  householdReadUnavailable,
  pendingHouseholdClear,
}

/// Snapshot of the current privacy boundary used for every generated-content
/// read. A scope-less custom record is the explicit legacy/standalone escape
/// hatch; preset records always require a matching household fingerprint.
class GeneratedPracticeAccessContext {
  const GeneratedPracticeAccessContext({
    required this.accountContext,
    required this.accountReadSucceeded,
    required this.consentAccepted,
    required this.householdScopeReadSucceeded,
    this.householdScopeFingerprint,
    this.pendingClearHouseholdScopeFingerprint,
    this.deniedReason,
  });

  const GeneratedPracticeAccessContext.accepted({
    required String accountContext,
    String? householdScopeFingerprint,
    String? pendingClearHouseholdScopeFingerprint,
  }) : this(
         accountContext: accountContext,
         accountReadSucceeded: true,
         consentAccepted: true,
         householdScopeReadSucceeded: true,
         householdScopeFingerprint: householdScopeFingerprint,
         pendingClearHouseholdScopeFingerprint:
             pendingClearHouseholdScopeFingerprint,
       );

  const GeneratedPracticeAccessContext.denied({
    String? accountContext,
    required GeneratedPracticeAccessDeniedReason reason,
  }) : this(
         accountContext: accountContext,
         accountReadSucceeded:
             reason !=
             GeneratedPracticeAccessDeniedReason.accountReadUnavailable,
         consentAccepted: false,
         householdScopeReadSucceeded:
             reason !=
             GeneratedPracticeAccessDeniedReason.householdReadUnavailable,
         deniedReason: reason,
       );

  const GeneratedPracticeAccessContext.accountReadUnavailable()
    : this.denied(
        reason: GeneratedPracticeAccessDeniedReason.accountReadUnavailable,
      );

  const GeneratedPracticeAccessContext.householdReadUnavailable({
    String? accountContext,
  }) : this.denied(
         accountContext: accountContext,
         reason: GeneratedPracticeAccessDeniedReason.householdReadUnavailable,
       );

  final String? accountContext;
  final bool accountReadSucceeded;
  final bool consentAccepted;
  final bool householdScopeReadSucceeded;
  final String? householdScopeFingerprint;
  final String? pendingClearHouseholdScopeFingerprint;
  final GeneratedPracticeAccessDeniedReason? deniedReason;

  bool get canRead =>
      accountReadSucceeded &&
      consentAccepted &&
      householdScopeReadSucceeded &&
      accountContext != null &&
      accountContext!.trim().isNotEmpty;

  bool get canRegister =>
      canRead && pendingClearHouseholdScopeFingerprint == null;

  /// Returns whether one stored bundle belongs to this current access scope.
  bool canReadStoredContent({
    required String recordAccountContext,
    required String? recordHouseholdScopeFingerprint,
    required SceneGenerationSourceType inputSource,
  }) {
    if (!canRead || accountContext?.trim() != recordAccountContext.trim()) {
      return false;
    }

    // Null-scope custom records are retained for legacy/standalone history.
    // A preset without a scope is never safe to expose.
    if (recordHouseholdScopeFingerprint == null) {
      return inputSource == SceneGenerationSourceType.custom;
    }
    final currentScope = householdScopeFingerprint;
    if (currentScope == null ||
        recordHouseholdScopeFingerprint != currentScope ||
        recordHouseholdScopeFingerprint ==
            pendingClearHouseholdScopeFingerprint) {
      return false;
    }
    return true;
  }
}

typedef GeneratedPracticeCurrentAccessContextLoader =
    Future<GeneratedPracticeAccessContext> Function();

typedef GeneratedPracticeAccessContextLoader =
    GeneratedPracticeCurrentAccessContextLoader;
