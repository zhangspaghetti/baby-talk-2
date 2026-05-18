# REFACTOR-013 Local Sensitive Data Lifecycle Plan and Tests

Version: Flutter AI Software Factory v1.0.0  
Stage: R3 / Phase 2  
Created: 2026-05-18  
Status: completed

## Summary

REFACTOR-013 established a report-only baseline for local sensitive data lifecycle coverage. It documents sensitive local data surfaces, scans the current mobile source for deletion primitives, and keeps known gaps visible without changing runtime deletion behavior.

## Changes

- Added `ai/architecture/local-sensitive-data-lifecycle.md` with lifecycle triggers, surface classifications, current storage, deletion primitives, target protection, and known gaps.
- Added `tool/verify_refactor_013_sensitive_lifecycle.dart` to scan expected local sensitive data surfaces and render a report-only status.
- Added root and mobile wrapper tests for scanner behavior and the current installation ID delete/reset gap.
- Updated governance records to mark REFACTOR-013 complete and move the next blocked task to REFACTOR-014.

## Scan Baseline

| Metric | Value |
|---|---:|
| Sensitive local surfaces | 6 |
| Covered delete primitives | 5 |
| Missing delete primitives | 1 |
| Missing source files | 0 |
| Missing documentation rows | 0 |

The current missing delete primitive is `installation_id`, backed by `mobile/lib/core/device/installation_id_service.dart`. This service can create and read the stable identifier, but it does not yet expose a delete/reset primitive.

## Verification

| Command | Result |
|---|---|
| `dart tool/verify_refactor_013_sensitive_lifecycle.dart` | Passed; report-only success marker printed |
| Focused scanner tests | Passed; 3 tests |
| `flutter analyze` | Passed; no issues found |
| `flutter test` | Passed; 218 tests |
| `flutter test --coverage` | Passed; 218 tests |
| LCOV summary | `LH=7136 LF=10760 Coverage=66.32%` |

## Residual Risks

- `InstallationIdService` still needs a delete/reset primitive before hard lifecycle enforcement.
- Account deletion, consent withdrawal, and logout do not yet coordinate all sensitive local stores through one lifecycle service.
- JSON and Isar stores still need backup exclusion or encrypted storage migration before backup/encryption policy can be enforced.
- The existing onboarding tap warning around `onboarding-name-continue` remains nonfatal during full test runs.

## Non-Goals Confirmed

- No production storage migration was performed.
- No local user data deletion behavior was changed.
- No report-only lifecycle gap was converted into a hard CI failure.