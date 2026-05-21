# REFACTOR-030 Garden Growth Generated Output Migration

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4 generated-code blocker reduction
Created: 2026-05-19
Status: completed

## Summary

REFACTOR-030 moves `GardenGrowthSnapshot.freezed.dart` into `mobile/lib/generated/features/practice/domain/models/`. The task preserves garden projection fields, patch/flower/milestone/latest-impact derived getters, issue detection, primary space/activity selection, and copy semantics.

This task does not change runtime behavior, garden projection semantics, stage labels, user-visible copy, share behavior, or generated-code hard-gate policy.

## Migrated Owner

| Generator | Owner Source | Old Output | New Output |
|---|---|---|---|
| Freezed | `mobile/lib/features/practice/domain/models/garden_growth_snapshot.dart` | `mobile/lib/features/practice/domain/models/garden_growth_snapshot.freezed.dart` | `mobile/lib/generated/features/practice/domain/models/garden_growth_snapshot.freezed.dart` |

## Build Configuration

`mobile/build.yaml` now includes `garden_growth_snapshot.dart` in the scoped Freezed generation list. json_serializable and riverpod_generator remain disabled for this scoped migration path.

## Verification

| Command | Result |
|---|---|
| `runTests mobile/test/generated/generated_code_canary_test.dart` before migration | Passed; 9 tests |
| `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; generated garden growth Freezed output under `lib/generated/` |
| Re-run `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; `0 outputs (0 actions)` |
| `runTests mobile/test/generated/generated_code_canary_test.dart` after migration | Passed; 9 tests |
| `flutter test test/features/practice` | Passed; 27 tests |
| `flutter analyze` | Passed; no issues found |
| `flutter test` | Passed; `01:09 +234: All tests passed!` |

## Generated File Counts

| Location | Freezed | Isar/source_gen `.g.dart` |
|---|---:|---:|
| `mobile/lib/generated/**` | 10 | 2 |
| Remaining co-located under `mobile/lib/features/**` | 1 | 0 |

## Residual Risks

- Remaining generated-code migration is now limited to 1 Freezed output.
- No hard generated-code gate is introduced in this task.

## Standard Git Commit Message

```text
refactor(mobile): migrate garden growth generated output
```