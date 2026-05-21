# REFACTOR-024 Local Mentor Suggestion Generated Output Migration

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4 generated-code blocker reduction
Created: 2026-05-19
Status: completed

## Summary

REFACTOR-024 moves `LocalMentorSuggestion.freezed.dart` into `mobile/lib/generated/features/mentor/domain/models/`. The task preserves local mentor suggestion validation, safe fallback detection, copy semantics, and visible/redacted map output.

This task does not change runtime behavior, visible user copy, map shapes, or generated-code hard-gate policy.

## Migrated Owner

| Generator | Owner Source | Old Output | New Output |
|---|---|---|---|
| Freezed | `mobile/lib/features/mentor/domain/models/local_mentor_suggestion.dart` | `mobile/lib/features/mentor/domain/models/local_mentor_suggestion.freezed.dart` | `mobile/lib/generated/features/mentor/domain/models/local_mentor_suggestion.freezed.dart` |

## Build Configuration

`mobile/build.yaml` now includes `local_mentor_suggestion.dart` in the scoped Freezed generation list. json_serializable and riverpod_generator remain disabled for this scoped migration path.

## Verification

| Command | Result |
|---|---|
| `runTests mobile/test/generated/generated_code_canary_test.dart` before migration | Passed; 6 tests |
| `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; generated local mentor suggestion Freezed output under `lib/generated/` |
| Re-run `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; `0 outputs (0 actions)` |
| `runTests mobile/test/generated/generated_code_canary_test.dart` after migration | Passed; 6 tests |
| `flutter analyze` | Passed; no issues found |
| Mentor focused tests via `runTests` | Passed; 43 tests |
| Full `runTests` | Passed; 269 tests |
| `flutter test` | Passed; `01:11 +231: All tests passed!` |

## Generated File Counts

| Location | Freezed | Isar/source_gen `.g.dart` |
|---|---:|---:|
| `mobile/lib/generated/**` | 4 | 2 |
| Remaining co-located under `mobile/lib/features/**` | 7 | 0 |

## Residual Risks

- Remaining generated-code migration is now limited to 7 Freezed outputs.
- No hard generated-code gate is introduced in this task.

## Standard Git Commit Message

```text
refactor(mobile): migrate mentor suggestion generated output
```