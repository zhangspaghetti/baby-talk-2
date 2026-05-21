# REFACTOR-029 Practice Activity Catalog Generated Output Migration

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4 generated-code blocker reduction
Created: 2026-05-19
Status: completed

## Summary

REFACTOR-029 moves `PracticeActivityCatalog.freezed.dart` into `mobile/lib/generated/features/practice/domain/models/`. The task preserves catalog summary fields, activity lookup behavior, issue detection, started activity counting, recent-result summary behavior, and copy semantics.

This task does not change runtime behavior, practice catalog projection semantics, user-visible copy, continuity behavior, or generated-code hard-gate policy.

## Migrated Owner

| Generator | Owner Source | Old Output | New Output |
|---|---|---|---|
| Freezed | `mobile/lib/features/practice/domain/models/practice_activity_catalog.dart` | `mobile/lib/features/practice/domain/models/practice_activity_catalog.freezed.dart` | `mobile/lib/generated/features/practice/domain/models/practice_activity_catalog.freezed.dart` |

## Build Configuration

`mobile/build.yaml` now includes `practice_activity_catalog.dart` in the scoped Freezed generation list. json_serializable and riverpod_generator remain disabled for this scoped migration path.

## Verification

| Command | Result |
|---|---|
| `runTests mobile/test/generated/generated_code_canary_test.dart` before migration | Passed; 8 tests |
| `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; generated practice catalog Freezed output under `lib/generated/` |
| Re-run `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; `0 outputs (0 actions)` |
| `runTests mobile/test/generated/generated_code_canary_test.dart` after migration | Passed; 8 tests |
| `flutter test test/features/practice` | Passed; 27 tests |
| `flutter analyze` | Passed; no issues found |
| `flutter test` | Passed; `01:08 +233: All tests passed!` |

## Generated File Counts

| Location | Freezed | Isar/source_gen `.g.dart` |
|---|---:|---:|
| `mobile/lib/generated/**` | 9 | 2 |
| Remaining co-located under `mobile/lib/features/**` | 2 | 0 |

## Residual Risks

- Remaining generated-code migration is now limited to 2 Freezed outputs.
- No hard generated-code gate is introduced in this task.

## Standard Git Commit Message

```text
refactor(mobile): migrate practice catalog generated output
```