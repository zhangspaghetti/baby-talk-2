# Refactor Task: REFACTOR-024 Local Mentor Suggestion Generated Output Migration

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4 generated-code blocker reduction
Created: 2026-05-19
Status: completed

## Objective

Continue strict generated-code isolation by moving `LocalMentorSuggestion.freezed.dart` into `mobile/lib/generated/` without changing local mentor suggestion behavior.

## Scope

- Add a focused generated-code canary test for `LocalMentorSuggestion.validated`, `copyWith`, safe fallback detection, and visible/redacted map output.
- Update `LocalMentorSuggestion` to point its `part` directive at `lib/generated/features/mentor/domain/models/local_mentor_suggestion.freezed.dart`.
- Extend the scoped `mobile/build.yaml` Freezed include list with the local mentor suggestion owner only.
- Regenerate output with build_runner and delete the old co-located Freezed file.
- Keep json_serializable and riverpod_generator disabled in the scoped canary configuration.

## Legacy Code Location

- Old generated output: `mobile/lib/features/mentor/domain/models/local_mentor_suggestion.freezed.dart`
- New generated output: `mobile/lib/generated/features/mentor/domain/models/local_mentor_suggestion.freezed.dart`
- Owner source: `mobile/lib/features/mentor/domain/models/local_mentor_suggestion.dart`

## Original Functionality Description

`LocalMentorSuggestion` is the local Mentor recommendation value model. It must preserve validated constructor normalization, copy semantics, safe fallback detection, wire-value mapping, visible map output, and redacted context map output.

## Refactoring Approach

1. Add a focused canary test for validated construction, `copyWith`, and map output.
2. Run the canary before migration to capture existing behavior.
3. Change only the owner source `part` path and scoped Freezed generation include list.
4. Run build_runner to generate the new output under `lib/generated/`.
5. Delete the old co-located Freezed output.
6. Run analyzer, focused generated/mentor tests, and full Flutter tests.

## Forbidden Changes

- Do not change mentor suggestion fields, validation, normalization, wire values, or visible/redacted map shapes.
- Do not expand generation to unrelated Freezed owners in this task.
- Do not enable unrestricted json_serializable or riverpod generation.
- Do not hand-edit generated Dart output.
- Do not introduce a generated-code hard gate yet.

## Acceptance Criteria

- [x] `LocalMentorSuggestion` generated output lives under `mobile/lib/generated/`.
- [x] Old co-located `local_mentor_suggestion.freezed.dart` is removed.
- [x] Existing and new generated outputs do not coexist for this owner.
- [x] build_runner can reproduce the output with zero subsequent actions.
- [x] Mentor focused tests pass.
- [x] Full Flutter tests pass.

## Verification Evidence

| Command | Result |
|---|---|
| `runTests mobile/test/generated/generated_code_canary_test.dart` before migration | Passed; 6 tests |
| `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; generated local mentor suggestion Freezed output |
| Re-run `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; `0 outputs (0 actions)` |
| `runTests mobile/test/generated/generated_code_canary_test.dart` after migration | Passed; 6 tests |
| `flutter analyze` | Passed; no issues found |
| Mentor focused tests via `runTests` | Passed; 43 tests |
| Full `runTests` | Passed; 269 tests |
| `flutter test` | Passed; `01:11 +231: All tests passed!` |

## Generated File Counts After Task

| Location | Freezed | Isar/source_gen `.g.dart` |
|---|---:|---:|
| `mobile/lib/generated/**` | 4 | 2 |
| Remaining co-located under `mobile/lib/features/**` | 7 | 0 |

## Residual Risks

- The remaining generated-code migration now consists of 7 co-located Freezed outputs.
- A generated-code placement hard gate is still not approved.

## Standard Git Commit Message

```text
refactor(mobile): migrate mentor suggestion generated output
```