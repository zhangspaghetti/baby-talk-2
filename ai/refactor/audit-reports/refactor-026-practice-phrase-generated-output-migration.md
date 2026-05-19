# REFACTOR-026 Practice Phrase Generated Output Migration

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4 generated-code blocker reduction
Created: 2026-05-19
Status: completed

## Summary

REFACTOR-026 moves `PracticePhrase.freezed.dart` into `mobile/lib/generated/features/practice/domain/models/`. The task preserves practice phrase field values, copy semantics, and `audioPlayerAsset` normalization for both `assets/...` and already-relative asset paths.

This task does not change runtime behavior, user-visible copy, catalog semantics, audio asset lookup behavior, or generated-code hard-gate policy.

## Migrated Owner

| Generator | Owner Source | Old Output | New Output |
|---|---|---|---|
| Freezed | `mobile/lib/features/practice/domain/models/practice_phrase.dart` | `mobile/lib/features/practice/domain/models/practice_phrase.freezed.dart` | `mobile/lib/generated/features/practice/domain/models/practice_phrase.freezed.dart` |

## Build Configuration

`mobile/build.yaml` now includes `practice_phrase.dart` in the scoped Freezed generation list. json_serializable and riverpod_generator remain disabled for this scoped migration path.

## Verification

| Command | Result |
|---|---|
| `runTests mobile/test/generated/generated_code_canary_test.dart` before migration | Passed; 7 tests |
| `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; generated practice phrase Freezed output under `lib/generated/` |
| Re-run `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; `0 outputs (0 actions)` |
| `runTests mobile/test/generated/generated_code_canary_test.dart` after migration | Passed; 7 tests |
| `flutter test test/features/practice` | Passed; 27 tests |
| `flutter analyze` | Passed; no issues found |
| `flutter test` | Passed; `01:09 +232: All tests passed!` |

## Generated File Counts

| Location | Freezed | Isar/source_gen `.g.dart` |
|---|---:|---:|
| `mobile/lib/generated/**` | 6 | 2 |
| Remaining co-located under `mobile/lib/features/**` | 5 | 0 |

## Residual Risks

- Remaining generated-code migration is now limited to 5 Freezed outputs.
- No hard generated-code gate is introduced in this task.

## Standard Git Commit Message

```text
refactor(mobile): migrate practice phrase generated output
```