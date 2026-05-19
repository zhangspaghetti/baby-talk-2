# Local Sensitive Data Clearance Orchestrator Interface

Version: Flutter AI Software Factory v1.0.0  
Stage: R4 / Phase 4  
Created: 2026-05-19  
Status: option 1 approved and implemented core-only in REFACTOR-020; no destructive flow wiring approved

## Decision Boundary

This artifact proposes one security-oriented Flutter interface for coordinating sensitive local data deletion evidence across the currently covered primitives:

- `AccountLocalStore.deleteIfExists()`
- `OnboardingSnapshotStore.deleteIfExists()`
- `HouseholdLocalStore.deleteIfExists()`
- `PracticeRepository.close(deleteFromDisk: true)` or a practice lifecycle adapter around the same primitive
- `MentorRepository.close(deleteFromDisk: true)` or a mentor lifecycle adapter around the same primitive
- `InstallationIdService.deleteIfExists()`

It does not approve wiring the interface into logout, consent withdrawal, account deletion, onboarding reset, or any user-visible destructive flow. Any destructive production trigger remains a Staff+ red-level decision and requires explicit human confirmation before implementation.

## REFACTOR-020 Implementation Note

REFACTOR-020 implements the core-only registry shape in `mobile/lib/core/local_data_lifecycle/local_sensitive_data_clearance.dart`. It uses callback steps and focused tests only. It does not import feature code and is not referenced by existing production flows.

## Recommended Shape

Expose one orchestration port that always attempts every target selected by the trigger policy and returns a signed-style evidence report instead of failing fast.

```dart
abstract interface class LocalSensitiveDataClearanceOrchestrator {
  Future<LocalSensitiveDataClearanceReport> clear(
    LocalSensitiveDataClearanceRequest request,
  );
}

final class LocalSensitiveDataClearanceRequest {
  const LocalSensitiveDataClearanceRequest({
    required this.trigger,
    required this.authorization,
    required this.correlationId,
    required this.requestedAt,
    this.includeTargets = LocalSensitiveDataTargetSet.policyDefault,
  });

  final LocalSensitiveDataClearanceTrigger trigger;
  final LocalSensitiveDataClearanceAuthorization authorization;
  final String correlationId;
  final DateTime requestedAt;
  final LocalSensitiveDataTargetSet includeTargets;
}

enum LocalSensitiveDataClearanceTrigger {
  logoutSessionOnly,
  consentWithdrawalConfirmed,
  accountDeletionConfirmed,
  deviceEraseConfirmed,
  staffPlusVerificationOnly,
}

sealed class LocalSensitiveDataClearanceAuthorization {
  const LocalSensitiveDataClearanceAuthorization();
}

final class ReportOnlyAuthorization
    extends LocalSensitiveDataClearanceAuthorization {
  const ReportOnlyAuthorization({required this.reason});

  final String reason;
}

final class StaffPlusDestructiveAuthorization
    extends LocalSensitiveDataClearanceAuthorization {
  const StaffPlusDestructiveAuthorization({
    required this.decisionId,
    required this.approvedBy,
    required this.approvedAt,
    required this.confirmationText,
  });

  final String decisionId;
  final String approvedBy;
  final DateTime approvedAt;
  final String confirmationText;
}

enum LocalSensitiveDataTarget {
  accountLocalSnapshot,
  onboardingSnapshot,
  householdSnapshot,
  practiceInteractionEvents,
  mentorFactEvents,
  installationId,
}

final class LocalSensitiveDataTargetSet {
  const LocalSensitiveDataTargetSet.policyDefault()
      : explicitTargets = null;

  const LocalSensitiveDataTargetSet.explicit(this.explicitTargets);

  final Set<LocalSensitiveDataTarget>? explicitTargets;
}
```

The orchestrator owns the mapping from trigger to target set. Callers should not directly call the six delete primitives because that would hide partial failures and scatter governance decisions.

## Internal Step Contract

Each sensitive store is registered as a step. The concrete adapters can live near composition code, but the behavior contract should be common and testable.

```dart
abstract interface class LocalSensitiveDataClearanceStep {
  LocalSensitiveDataTarget get target;
  String get primitiveName;

  Future<void> clear();
}
```

Adapters should be thin:

```dart
LocalSensitiveDataClearanceStep(
  target: LocalSensitiveDataTarget.accountLocalSnapshot,
  primitiveName: 'AccountLocalStore.deleteIfExists',
  clear: accountLocalStore.deleteIfExists,
);

LocalSensitiveDataClearanceStep(
  target: LocalSensitiveDataTarget.practiceInteractionEvents,
  primitiveName: 'PracticeRepository.close(deleteFromDisk: true)',
  clear: () => practiceRepository.close(deleteFromDisk: true),
);
```

The important security property is that the orchestrator drives every selected step in a deterministic order, catches each step's failure, records it, and continues to the next step.

## Trigger Model

| Trigger | Default targets | Authorization | Production wiring status |
|---|---|---|---|
| `logoutSessionOnly` | `accountLocalSnapshot` only | Non-destructive authorization is enough after separate approval | Not wired by this design |
| `consentWithdrawalConfirmed` | Account/session plus governance-approved shared-context targets only | Staff+ confirmation if it erases child, household, practice, mentor, or installation data | Not wired by this design |
| `accountDeletionConfirmed` | All six targets | `StaffPlusDestructiveAuthorization` with decision ID and confirmation text | Not wired by this design |
| `deviceEraseConfirmed` | All six targets | `StaffPlusDestructiveAuthorization` with decision ID and confirmation text | Not wired by this design |
| `staffPlusVerificationOnly` | Explicit test/verification target set | `ReportOnlyAuthorization` or test authorization | Allowed for contract tests and report-only scanners |

The production orchestrator should reject any all-target destructive trigger unless the request includes a Staff+ destructive authorization. Rejection is evidence too: it returns a report with `overallStatus: rejectedByGovernance` and no step attempts.

## Report and Error Semantics

```dart
final class LocalSensitiveDataClearanceReport {
  const LocalSensitiveDataClearanceReport({
    required this.correlationId,
    required this.trigger,
    required this.requestedAt,
    required this.startedAt,
    required this.finishedAt,
    required this.overallStatus,
    required this.authorizationEvidence,
    required this.results,
  });

  final String correlationId;
  final LocalSensitiveDataClearanceTrigger trigger;
  final DateTime requestedAt;
  final DateTime startedAt;
  final DateTime finishedAt;
  final LocalSensitiveDataClearanceOverallStatus overallStatus;
  final LocalSensitiveDataAuthorizationEvidence authorizationEvidence;
  final List<LocalSensitiveDataTargetResult> results;

  bool get hasFailures => results.any((result) => result.status.isFailure);
}

enum LocalSensitiveDataClearanceOverallStatus {
  completed,
  completedWithFailures,
  rejectedByGovernance,
}

final class LocalSensitiveDataTargetResult {
  const LocalSensitiveDataTargetResult({
    required this.target,
    required this.primitiveName,
    required this.status,
    required this.startedAt,
    required this.finishedAt,
    this.errorType,
    this.sanitizedErrorMessage,
  });

  final LocalSensitiveDataTarget target;
  final String primitiveName;
  final LocalSensitiveDataTargetStatus status;
  final DateTime startedAt;
  final DateTime finishedAt;
  final String? errorType;
  final String? sanitizedErrorMessage;
}

enum LocalSensitiveDataTargetStatus {
  attemptedAndSucceeded,
  attemptedAndFailed,
  skippedByPolicy,
  skippedByGovernanceRejection,
}
```

Deletion failures are not thrown as the primary result because a thrown aggregate exception can hide which stores were already cleared. Instead:

- Invalid destructive authorization returns `rejectedByGovernance` and attempts no destructive steps.
- Per-target deletion failures become `attemptedAndFailed` entries with sanitized error type/message.
- The orchestrator continues after each per-target failure.
- `overallStatus` is `completedWithFailures` if at least one selected target failed.
- Only programmer/configuration errors before any step is selected, such as duplicate target registration or an unknown trigger policy, may throw during development. Production construction should fail closed.

## Usage Example

Future account deletion wiring, after explicit Staff+ approval, would look like this:

```dart
final report = await localSensitiveDataClearanceOrchestrator.clear(
  LocalSensitiveDataClearanceRequest(
    trigger: LocalSensitiveDataClearanceTrigger.accountDeletionConfirmed,
    authorization: StaffPlusDestructiveAuthorization(
      decisionId: 'HDR-R4-LOCAL-DATA-ERASURE-001',
      approvedBy: 'human-reviewer-id',
      approvedAt: approvedAt,
      confirmationText: 'ERASE LOCAL CHILD DATA',
    ),
    correlationId: accountDeletionCorrelationId,
    requestedAt: clock.now().toUtc(),
  ),
);

if (report.hasFailures) {
  securityAuditSink.recordLocalClearanceFailure(report);
  // Caller must show a fail-closed recovery state or retry affordance.
  return AccountDeletionLocalClearanceResult.needsManualResolution(report);
}

securityAuditSink.recordLocalClearanceSuccess(report);
return AccountDeletionLocalClearanceResult.cleared(report);
```

Until that human gate exists, production logout/account-delete/consent-withdrawal flows should not call this interface.

## Test-First Contract

Before implementation, add tests that fail against the missing orchestrator and prove the security semantics:

1. `clear_attempts_all_selected_targets_when_middle_step_fails`: fake six steps; make practice fail; assert account, onboarding, household, mentor, and installation still run.
2. `clear_returns_completed_with_failures_and_sanitized_evidence`: assert raw exception objects are not exposed, but target, primitive name, error type, and sanitized message are present.
3. `clear_rejects_all_target_destructive_trigger_without_staff_plus_authorization`: assert no step was attempted and the report is `rejectedByGovernance`.
4. `clear_records_skipped_targets_when_policy_scope_is_limited`: assert logout/session-only policy does not silently omit child/practice stores; it records them as skipped or excludes them according to the chosen report policy.
5. `clear_is_deterministic_for_a_fixed_target_registry`: assert result ordering is stable so audit diffs and screenshots are meaningful.
6. `clear_does_not_wire_existing_user_flows`: characterization test or static scanner assertion that logout, consent withdrawal, and account deletion do not call the new orchestrator until the explicit approval artifact exists.

## Audit Evidence Produced

The report gives security and privacy reviewers evidence that is currently missing from scattered primitive calls:

- Which trigger requested local clearance.
- Which Staff+ decision authorized the destructive attempt.
- Which targets were selected, attempted, skipped by policy, or skipped by governance rejection.
- Which concrete primitive was used for each target.
- Start/finish timestamps for the aggregate run and each target.
- Stable correlation ID that can link app logs, backend account deletion, and support events without logging child data.
- Sanitized failure evidence that supports retry/manual resolution without leaking local file paths, tokens, child profile values, or stack traces to user-visible surfaces.

## Tradeoffs

This shape favors evidence and safety over caller convenience. It introduces more types than a simple `deleteAllLocalData()` method, but it prevents three common security failures: fail-fast partial erasure, unapproved destructive flow wiring, and unauditable direct primitive calls.

The orchestrator cannot prove physical disk erasure, platform backup exclusion, or encryption posture. It only proves that every registered app-level delete primitive was attempted and records what happened. Backup exclusion/encryption remains a separate lifecycle requirement.

The `close(deleteFromDisk: true)` primitives are stateful; repositories that already closed may return early. The implementation task should either construct lifecycle-specific adapters around lower-level local data sources or add tests proving closed repositories still produce acceptable evidence. That risk should be resolved before any account deletion or device-erasure flow is wired.

The interface deliberately keeps trigger-to-target policy inside the orchestrator. That makes callers harder to misuse, but policy changes require Staff+ review and tests instead of ad hoc call-site edits. That is the intended governance cost for child-sensitive local data.