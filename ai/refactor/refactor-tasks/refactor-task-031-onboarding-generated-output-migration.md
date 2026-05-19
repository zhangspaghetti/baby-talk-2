# REFACTOR-031 Onboarding Generated Output Migration

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4 generated-code blocker reduction
Created: 2026-05-19
Status: completed

## Goal

Move the final co-located Freezed output for `OnboardingSnapshot` from `mobile/lib/features/` into `mobile/lib/generated/` without changing onboarding behavior.

## Scope

In scope:

- Add a generated-code canary for `OnboardingSnapshot` copy semantics, completion state, and wire JSON mapping.
- Update the owner source `part` directive.
- Add `onboarding_snapshot.dart` to the scoped Freezed build config.
- Regenerate output under `mobile/lib/generated/`.
- Delete the old co-located `onboarding_snapshot.freezed.dart`.
- Update governance artifacts and commit with a conventional commit message.

Out of scope:

- Onboarding UX or copy changes.
- Stage matching behavior changes.
- JSON schema changes.
- Generated-code hard-gate introduction.
- Broad cleanup outside this owner.

## Regression Requirements

- [x] `OnboardingSnapshot` generated output lives under `mobile/lib/generated/`.
- [x] Old co-located `onboarding_snapshot.freezed.dart` is removed.
- [x] No co-located Freezed outputs remain under `mobile/lib/features/`.
- [x] build_runner can reproduce the output with zero subsequent actions.
- [x] Generated-code canary tests pass.
- [x] Onboarding focused tests pass.
- [x] Full Flutter tests pass.

## Verification Log

| Command | Result |
|---|---|
| `runTests mobile/test/generated/generated_code_canary_test.dart` before migration | Passed; targeted onboarding canary |
| `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; generated onboarding Freezed output under `lib/generated/` |
| Re-run `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; `0 outputs (0 actions)` |
| `runTests mobile/test/generated/generated_code_canary_test.dart` after migration | Passed; 10 tests |
| `flutter test test/features/onboarding` | Passed; 11 tests |
| `flutter analyze` | Passed; no issues found |
| `flutter test` | Passed; `01:04 +235: All tests passed!` |

## Generated Output Counts

| Location | Freezed | Isar/source_gen `.g.dart` |
|---|---:|---:|
| `mobile/lib/generated/**` | 11 | 2 |
| Remaining co-located under `mobile/lib/features/**` | 0 | 0 |

## Risks

- `OnboardingSnapshot` has manual validation and JSON wire mapping, so the canary must cover both copy semantics and validated JSON round-trip.
- This task leaves the generated-code hard gate as a separate governance decision.

## Standard Git Commit Message

```text
refactor(mobile): migrate onboarding generated output
```