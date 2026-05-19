# Refactor Task: REFACTOR-019 Installation ID Delete Primitive

Version: Flutter AI Software Factory v1.0.0  
Stage: R4 / Phase 4  
Created: 2026-05-19  
Status: done, commit pending

## Objective

Close the REFACTOR-013/R017 local sensitive lifecycle gap for the stable installation identifier by adding an explicit deletion primitive to `InstallationIdService` without wiring it into account deletion, logout, consent withdrawal, or any user-visible flow.

## Scope

- Add a public `InstallationIdService.deleteIfExists()` primitive.
- Add focused behavior tests proving the primitive deletes the persisted ID and is idempotent when no ID exists.
- Re-run the REFACTOR-013 lifecycle scanner and update R4 security/engineering evidence.

## Legacy Code Location

- `mobile/lib/core/device/installation_id_service.dart`

## Original Functionality Description

`InstallationIdService` resolves an app support file, returns an existing non-empty ID, or creates a new ID with the injected/default generator. Before this task, callers could read or create the ID but had no explicit way to remove it for lifecycle enforcement.

## Refactoring Approach

1. Write a failing public-interface test for deleting the stored ID and regenerating a new one.
2. Add the smallest service method that deletes the backing file if present.
3. Prove the scanner now classifies all six sensitive surfaces as covered by delete primitives.
4. Keep destructive account/device-erasure orchestration out of scope.

## Forbidden Changes

- Do not wire installation ID deletion into logout, consent withdrawal, account deletion, onboarding reset, or any UI flow.
- Do not delete or migrate existing user data in runtime flows.
- Do not convert the lifecycle scanner from report-only into a hard CI failure.
- Do not change installation ID generation format, file name, storage directory, or network behavior.
- Do not edit generated Dart files.

## Acceptance Criteria

- [x] `InstallationIdService.deleteIfExists()` exists and deletes only the installation ID file.
- [x] Deleting an existing ID makes `readExisting()` return `null`.
- [x] `getOrCreate()` can generate a new ID after deletion.
- [x] Deleting when no ID exists is safe and idempotent.
- [x] REFACTOR-013 scanner reports `covered_delete_primitive=6` and `missing_delete_primitive=0`.
- [x] `flutter analyze` remains green.
- [x] `flutter test` remains green.

## Regression Test Requirements

- [x] Focused installation ID lifecycle test passes.
- [x] Full mobile unit/widget/smoke suite passes.
- [x] Sensitive lifecycle scanner reports the installation ID primitive as covered.

## Verification Evidence

| Command | Result |
|---|---|
| `flutter test test/core/device/installation_id_service_test.dart` before implementation | Red; compile failed because `deleteIfExists` was missing |
| `flutter test test/core/device/installation_id_service_test.dart` after implementation | Pass; 2 tests |
| `dart tool/verify_refactor_013_sensitive_lifecycle.dart` | Pass; 6 surfaces, 6 covered delete primitives, 0 missing delete primitives |
| `flutter analyze` | Pass; no issues found |
| `flutter test` | Pass; 224 tests |
| `flutter test --coverage` | Attempted, but stopped after stalling at `practice_repository_characterization_test.dart`; no coverage pass claimed |

## Residual Risks

- The delete primitive is not yet orchestrated by a unified local data lifecycle service.
- Account deletion, consent withdrawal, and destructive device-erasure flows still need separately approved wiring and UX confirmation.
- Backup exclusion/encryption posture for JSON and Isar stores remains unresolved.
- Phase 4 coverage, performance, target-platform replay, generated-code hard gates, and final release confirmation remain blocked.

## Standard Git Commit Message

```text
refactor(mobile): add installation id delete primitive
```