# REFACTOR-021 AccountSession Generated Output Migration

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4 generated-code blocker reduction
Created: 2026-05-19
Status: completed

## Summary

REFACTOR-021 expands the strict generated-code migration by one Freezed owner: `AccountSession`. The task moves the generated output from the feature-local source directory to `mobile/lib/generated/features/account/domain/models/account_session.freezed.dart` and adds a focused canary test to prove copy/token helper behavior remains unchanged.

This task does not change runtime behavior, data shape, or account session validation. It also does not approve a generated-code hard gate.

## Migrated Owner

| Generator | Owner Source | Old Output | New Output |
|---|---|---|---|
| Freezed | `mobile/lib/features/account/domain/models/account_session.dart` | `mobile/lib/features/account/domain/models/account_session.freezed.dart` | `mobile/lib/generated/features/account/domain/models/account_session.freezed.dart` |

## Build Configuration

`mobile/build.yaml` now includes `account_session.dart` in the scoped Freezed generation list alongside the original R003 household canary owner. json_serializable and riverpod_generator remain disabled for this scoped generated-code migration path.

## Verification

| Command | Result |
|---|---|
| `runTests mobile/test/generated/generated_code_canary_test.dart` before migration | Passed; 3 tests |
| `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; generated AccountSession output under `lib/generated/` |
| Re-run `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; `0 outputs (0 actions)` |
| `runTests mobile/test/generated/generated_code_canary_test.dart` after migration | Passed; 3 tests |
| `flutter analyze` | Passed; no issues found |
| Account tests via `runTests` | Passed; 17 tests |
| Full `runTests` | Passed; 266 tests |
| `flutter test` | Passed; `01:10 +228: All tests passed!` |

## Generated File Counts

| Location | Freezed | Isar/source_gen `.g.dart` |
|---|---:|---:|
| `mobile/lib/generated/**` | 2 | 1 |
| Remaining co-located under `mobile/lib/features/**` | 9 | 1 |

## Residual Risks

- The known analyzer/SDK compatibility warning remains during scoped build_runner generation.
- Remaining generated-code migration is incomplete.
- No hard generated-code gate is introduced in this task.

## Standard Git Commit Message

```text
refactor(mobile): migrate account session generated output
```