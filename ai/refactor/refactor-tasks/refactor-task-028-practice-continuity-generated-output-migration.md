# Refactor Task: REFACTOR-028 Practice Continuity Generated Output Migration

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4 generated-code blocker reduction
Created: 2026-05-19
Status: completed

## Objective

Continue strict generated-code isolation by moving `PracticeContinuitySnapshot.freezed.dart` into `mobile/lib/generated/` without changing practice continuity recommendation behavior.

## Scope

- Add a focused generated-code canary for `PracticeContinuitySnapshot.copyWith`, warning detection, fallback reason exposure, and cadence empty-state behavior.
- Update `PracticeContinuitySnapshot` to point its `part` directive at `lib/generated/features/practice/domain/models/practice_continuity_snapshot.freezed.dart`.
- Extend the scoped `mobile/build.yaml` Freezed include list with the practice continuity owner only.
- Regenerate output with build_runner and delete the old co-located Freezed file.
- Keep json_serializable and riverpod_generator disabled in the scoped canary configuration.

## Legacy Code Location

- Old generated output: `mobile/lib/features/practice/domain/models/practice_continuity_snapshot.freezed.dart`
- New generated output: `mobile/lib/generated/features/practice/domain/models/practice_continuity_snapshot.freezed.dart`
- Owner source: `mobile/lib/features/practice/domain/models/practice_continuity_snapshot.dart`

## Original Functionality Description

`PracticeContinuitySnapshot` carries the recommended next practice activity, recent/starter fallbacks, cadence summary, warning state, and fallback reason used by the home, garden, mentor, and share surfaces. It must preserve copy semantics and derived getters.

## Refactoring Approach

1. Add focused canary assertions for generated copy behavior and derived getters.
2. Run the generated-code canary before migration to capture existing behavior.
3. Change only the owner source `part` path and scoped Freezed generation include list.
4. Run build_runner to generate the new output under `lib/generated/`.
5. Delete the old co-located Freezed output.
6. Run analyzer, focused generated/practice tests, and full Flutter tests.

## Forbidden Changes

- Do not change continuity recommendation fields, reason labels, cadence semantics, warning behavior, or fallback behavior.
- Do not expand generation to unrelated Freezed owners in this task.
- Do not enable unrestricted json_serializable or riverpod generation.
- Do not hand-edit generated Dart output.
- Do not introduce a generated-code hard gate yet.

## Acceptance Criteria

- [x] `PracticeContinuitySnapshot` generated output lives under `mobile/lib/generated/`.
- [x] Old co-located `practice_continuity_snapshot.freezed.dart` is removed.
- [x] Existing and new generated outputs do not coexist for this owner.
- [x] build_runner can reproduce the output with zero subsequent actions.
- [x] Generated-code canary tests pass.
- [x] Practice focused tests pass.
- [x] Full Flutter tests pass.

## Verification Evidence

| Command | Result |
|---|---|
| `runTests mobile/test/generated/generated_code_canary_test.dart` before migration | Passed; 8 tests |
| `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; generated practice continuity Freezed output under `lib/generated/` |
| Re-run `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; `0 outputs (0 actions)` |
| `runTests mobile/test/generated/generated_code_canary_test.dart` after migration | Passed; 8 tests |
| `flutter test test/features/practice` | Passed; 27 tests |
| `flutter analyze` | Passed; no issues found |
| `flutter test` | Passed; `01:08 +233: All tests passed!` |

## Generated File Counts After Task

| Location | Freezed | Isar/source_gen `.g.dart` |
|---|---:|---:|
| `mobile/lib/generated/**` | 8 | 2 |
| Remaining co-located under `mobile/lib/features/**` | 3 | 0 |

## Residual Risks

- The remaining generated-code migration now consists of 3 co-located Freezed outputs.
- A generated-code placement hard gate is still not approved.

## Standard Git Commit Message

```text
refactor(mobile): migrate practice continuity generated output
```