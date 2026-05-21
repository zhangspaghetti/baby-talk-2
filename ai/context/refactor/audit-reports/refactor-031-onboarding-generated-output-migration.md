# REFACTOR-031 Onboarding Generated Output Migration

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4 generated-code blocker reduction
Created: 2026-05-19
Status: completed

## Summary

REFACTOR-031 moves `OnboardingSnapshot.freezed.dart` into `mobile/lib/generated/features/onboarding/domain/models/`. This completes the current co-located generated-output migration: no Freezed or Isar/source_gen `.g.dart` outputs remain under `mobile/lib/features/`.

This task preserves onboarding snapshot copy semantics, completion detection, age-bucket wire mapping, consent-state wire mapping, and validated JSON round-trip behavior.

## Migrated Owner

| Generator | Owner Source | Old Output | New Output |
|---|---|---|---|
| Freezed | `mobile/lib/features/onboarding/domain/models/onboarding_snapshot.dart` | `mobile/lib/features/onboarding/domain/models/onboarding_snapshot.freezed.dart` | `mobile/lib/generated/features/onboarding/domain/models/onboarding_snapshot.freezed.dart` |

## Build Configuration

`mobile/build.yaml` now includes `onboarding_snapshot.dart` in the scoped Freezed generation list. json_serializable and riverpod_generator remain disabled for this scoped migration path.

## Verification

| Command | Result |
|---|---|
| `runTests mobile/test/generated/generated_code_canary_test.dart` before migration | Passed; targeted onboarding canary |
| `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; generated onboarding Freezed output under `lib/generated/` |
| Re-run `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; `0 outputs (0 actions)` |
| `runTests mobile/test/generated/generated_code_canary_test.dart` after migration | Passed; 10 tests |
| `flutter test test/features/onboarding` | Passed; 11 tests |
| `flutter analyze` | Passed; no issues found |
| `flutter test` | Passed; `01:04 +235: All tests passed!` |

## Generated File Counts

| Location | Freezed | Isar/source_gen `.g.dart` |
|---|---:|---:|
| `mobile/lib/generated/**` | 11 | 2 |
| Remaining co-located under `mobile/lib/features/**` | 0 | 0 |

## Residual Risks

- No generated-code hard gate is introduced in this task.
- Production readiness remains blocked by coverage, lifecycle wiring, backup/encryption proof, performance benchmark, target-platform/CI replay, and final human release confirmation items tracked elsewhere.

## Standard Git Commit Message

```text
refactor(mobile): migrate onboarding generated output
```