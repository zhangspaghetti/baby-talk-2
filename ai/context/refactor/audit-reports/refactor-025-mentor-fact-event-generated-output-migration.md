# REFACTOR-025 Mentor Fact Event Generated Output Migration

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4 generated-code blocker reduction
Created: 2026-05-19
Status: completed

## Summary

REFACTOR-025 moves `MentorFactEvent.freezed.dart` into `mobile/lib/generated/features/mentor/domain/models/`. The task preserves mentor telemetry validation, event-key derivation, wire-value parsing, copy semantics, redacted metadata output, visible metadata output, and Isar entity conversion behavior.

This task does not change runtime behavior, user-visible copy, telemetry map shapes, or generated-code hard-gate policy.

## Migrated Owner

| Generator | Owner Source | Old Output | New Output |
|---|---|---|---|
| Freezed | `mobile/lib/features/mentor/domain/models/mentor_fact_event.dart` | `mobile/lib/features/mentor/domain/models/mentor_fact_event.freezed.dart` | `mobile/lib/generated/features/mentor/domain/models/mentor_fact_event.freezed.dart` |

## Build Configuration

`mobile/build.yaml` now includes `mentor_fact_event.dart` in the scoped Freezed generation list. json_serializable and riverpod_generator remain disabled for this scoped migration path.

## Verification

| Command | Result |
|---|---|
| `runTests mobile/test/generated/generated_code_canary_test.dart` before migration | Passed; 6 tests |
| `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; generated mentor fact event Freezed output under `lib/generated/` |
| Re-run `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; `0 outputs (0 actions)` |
| `runTests mobile/test/generated/generated_code_canary_test.dart` after migration | Passed; 6 tests |
| `flutter test test/features/mentor` | Passed; 39 tests |
| `flutter analyze` | Passed; no issues found |
| `flutter test` | Passed; `01:03 +231: All tests passed!` |

## Generated File Counts

| Location | Freezed | Isar/source_gen `.g.dart` |
|---|---:|---:|
| `mobile/lib/generated/**` | 5 | 2 |
| Remaining co-located under `mobile/lib/features/**` | 6 | 0 |

## Residual Risks

- Remaining generated-code migration is now limited to 6 Freezed outputs.
- No hard generated-code gate is introduced in this task.

## Standard Git Commit Message

```text
refactor(mobile): migrate mentor fact generated output
```