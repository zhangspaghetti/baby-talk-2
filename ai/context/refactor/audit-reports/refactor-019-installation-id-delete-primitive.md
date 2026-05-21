# REFACTOR-019 Installation ID Delete Primitive

Version: Flutter AI Software Factory v1.0.0  
Stage: R4 / Phase 4  
Created: 2026-05-19  
Status: completed, commit pending

## Summary

REFACTOR-019 closes the narrow local sensitive lifecycle gap identified by REFACTOR-013 and REFACTOR-017: the stable installation identifier now has an explicit delete primitive. The change is intentionally behavior-preserving because no existing logout, consent, account deletion, onboarding, routing, or network flow calls the primitive yet.

## Changes

- Added `InstallationIdService.deleteIfExists()` to remove the persisted installation ID file when present.
- Added focused tests for deleting an existing ID, regenerating after deletion, and idempotent deletion when no ID exists.
- Updated lifecycle/security/engineering artifacts to reflect scanner closure from `5 covered / 1 missing` to `6 covered / 0 missing`.

## Scanner Result

| Metric | Value |
|---|---:|
| Sensitive local surfaces | 6 |
| Covered delete primitives | 6 |
| Missing delete primitives | 0 |
| Missing source files | 0 |
| Missing documentation rows | 0 |

## Verification

| Command | Result |
|---|---|
| `flutter test test/core/device/installation_id_service_test.dart` before implementation | Failed as expected; `deleteIfExists` missing |
| `flutter test test/core/device/installation_id_service_test.dart` after implementation | Passed; 2 tests |
| `dart tool/verify_refactor_013_sensitive_lifecycle.dart` | Passed; `covered_delete_primitive=6`, `missing_delete_primitive=0` |
| `flutter analyze` | Passed; no issues found |
| `flutter test` | Passed; 224 tests |
| `flutter test --coverage` | Attempted, stalled at `practice_repository_characterization_test.dart`, then stopped; no coverage result claimed |

## Residual Risks

- This task only adds the primitive; it does not approve destructive data-erasure behavior.
- A unified lifecycle service is still required before account deletion or consent withdrawal can prove every local sensitive store is cleared together.
- Backup exclusion/encryption proof remains open.
- Production readiness remains blocked by coverage, critical UI coverage measurement, performance benchmarks, target-platform/CI replay, hard gate readiness, and final human release confirmation.

## Standard Git Commit Message

```text
refactor(mobile): add installation id delete primitive
```