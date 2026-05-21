# REFACTOR-020 Local Sensitive Data Clearance Orchestrator

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4
Created: 2026-05-19
Status: completed

## Summary

REFACTOR-020 implements the approved option 1 from HDR-R4-001: a test-first local sensitive data clearance orchestrator with no production destructive flow wiring. The orchestrator is a core-only registry that accepts deletion callbacks, attempts every selected target, records partial failures, rejects unapproved destructive triggers, and returns report evidence instead of failing fast.

## Changes

- Added `mobile/lib/core/local_data_lifecycle/local_sensitive_data_clearance.dart`.
- Added focused tests under `mobile/test/core/local_data_lifecycle/`.
- Confirmed by static search that no existing logout, consent withdrawal, account deletion, onboarding reset, or device-erasure flow imports/calls the orchestrator.
- Updated governance and decision artifacts for HDR-R4-001.

## Implemented Safety Semantics

| Behavior | Evidence |
|---|---|
| Continue after middle-step failure | Focused test makes `practiceInteractionEvents` fail and proves later mentor/installation steps still run |
| Preserve partial-failure evidence | Report includes target, primitive name, failure status, error type, sanitized message, and timestamps |
| Reject destructive trigger without Staff+ authorization | `accountDeletionConfirmed` with report-only authorization attempts no steps and returns `rejectedByGovernance` |
| Record limited policy scope | `logoutSessionOnly` attempts only account snapshot and marks other registered targets as `skippedByPolicy` |
| Preserve runtime behavior | No production flow references the new core orchestrator |

## Verification

| Command | Result |
|---|---|
| `flutter test test/core/local_data_lifecycle/local_sensitive_data_clearance_orchestrator_test.dart` before implementation | Failed as expected; missing library/types |
| `flutter test test/core/local_data_lifecycle/local_sensitive_data_clearance_orchestrator_test.dart` after implementation | Passed; 3 tests |
| Static search `LocalSensitiveDataClearance|local_sensitive_data_clearance` in `mobile/lib/**` | Only core implementation references found; no flow wiring |
| `git diff --check -- ai mobile/lib mobile/test` | Passed; only line-ending warnings for existing CRLF normalization |
| `flutter analyze` | Passed; no issues found |
| `flutter test` | Passed; `01:15 +227: All tests passed!` |

## Residual Risks

- This is not an approval to erase user data in existing flows.
- Future production wiring must decide provider invalidation/reopen behavior for practice and mentor stores.
- Destructive UX copy, retry behavior, support escalation, target-platform replay, backup/encryption proof, and release confirmation remain open.

## Standard Git Commit Message

```text
refactor(mobile): add local data clearance orchestrator
```