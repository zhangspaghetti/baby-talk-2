# Refactor Task: REFACTOR-020 Local Sensitive Data Clearance Orchestrator

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4
Created: 2026-05-19
Status: completed

## Objective

Implement the approved report-producing local sensitive data clearance orchestrator as a core-only, test-first service without wiring it into logout, consent withdrawal, account deletion, onboarding reset, or device erasure.

## Scope

- Add core lifecycle models, authorization evidence, target results, and a registry orchestrator.
- Use callback-based clearance steps so `core` does not import feature internals.
- Add tests for continuing after failures, rejecting unapproved destructive triggers, and recording policy skips.
- Update R4 governance artifacts to mark HDR-R4-001 option 1 as confirmed.

## Legacy Code Location

- Existing deletion primitives remain in their existing stores/repositories.
- New code is isolated in `mobile/lib/core/local_data_lifecycle/`.

## Original Functionality Description

Before this task, each sensitive local store had its own primitive, but there was no single contract that could attempt all approved targets, preserve partial-failure evidence, or reject destructive requests without Staff+ authorization. Existing user flows did not call a unified lifecycle service.

## Refactoring Approach

1. Write a failing test against the missing orchestrator interface.
2. Add a core-only registry implementation that accepts `LocalSensitiveDataClearanceStep` callbacks.
3. Keep trigger policy and destructive authorization checks inside the orchestrator.
4. Add focused tests for failure continuation, governance rejection, and policy-scope evidence.
5. Prove no existing production flow imports or calls the new orchestrator.

## Forbidden Changes

- Do not wire the orchestrator into logout, consent withdrawal, account deletion, onboarding reset, or device erasure.
- Do not call real deletion primitives from production code in this task.
- Do not delete or migrate user data.
- Do not convert report-only scanners into hard CI gates.
- Do not edit generated Dart files.

## Acceptance Criteria

- [x] Orchestrator attempts every selected target even if a middle target fails.
- [x] Per-target results capture target, primitive name, status, timestamps, error type, and sanitized message.
- [x] All-target destructive requests without Staff+ authorization return `rejectedByGovernance` and attempt no steps.
- [x] Session-only policy attempts account local snapshot and records other registered targets as skipped by policy.
- [x] Core implementation does not import feature code.
- [x] Existing user flows do not call the orchestrator.

## Regression Test Requirements

- [x] Focused orchestrator tests pass.
- [x] `flutter analyze` passes after artifact updates.
- [x] `flutter test` passes after artifact updates.

## Verification Evidence

| Command | Result |
|---|---|
| `flutter test test/core/local_data_lifecycle/local_sensitive_data_clearance_orchestrator_test.dart` before implementation | RED; library and types missing |
| `flutter test test/core/local_data_lifecycle/local_sensitive_data_clearance_orchestrator_test.dart` after implementation | Passed; 3 tests |
| Static search in `mobile/lib/**` | Only `mobile/lib/core/local_data_lifecycle/local_sensitive_data_clearance.dart` references the new clearance types; no production flow wiring |
| `git diff --check -- ai mobile/lib mobile/test` | Passed; only line-ending warnings for existing CRLF normalization |
| `flutter analyze` | Passed; no issues found |
| `flutter test` | Passed; `01:15 +227: All tests passed!` |

## Residual Risks

- The orchestrator is not wired to real stores yet; this task creates the contract and safety semantics only.
- Practice and mentor deletion use close/delete semantics that require provider invalidation before any future production wiring.
- Destructive user-visible flow wiring still requires a separate red-level confirmation with UX copy, retry/recovery behavior, and target-platform verification.
- Backup exclusion/encryption proof remains open.

## Standard Git Commit Message

```text
refactor(mobile): add local data clearance orchestrator
```