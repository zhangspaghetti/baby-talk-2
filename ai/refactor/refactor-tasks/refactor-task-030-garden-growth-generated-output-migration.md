# Refactor Task: REFACTOR-030 Garden Growth Generated Output Migration

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4 generated-code blocker reduction
Created: 2026-05-19
Status: completed

## Objective

Continue strict generated-code isolation by moving `GardenGrowthSnapshot.freezed.dart` into `mobile/lib/generated/` without changing garden growth projection behavior.

## Scope

- Extend the generated-code canary with garden flower, patch, milestone, latest impact, and growth snapshot assertions.
- Update `GardenGrowthSnapshot` to point its `part` directive at `lib/generated/features/practice/domain/models/garden_growth_snapshot.freezed.dart`.
- Extend the scoped `mobile/build.yaml` Freezed include list with the garden growth owner only.
- Regenerate output with build_runner and delete the old co-located Freezed file.
- Keep json_serializable and riverpod_generator disabled in the scoped canary configuration.

## Legacy Code Location

- Old generated output: `mobile/lib/features/practice/domain/models/garden_growth_snapshot.freezed.dart`
- New generated output: `mobile/lib/generated/features/practice/domain/models/garden_growth_snapshot.freezed.dart`
- Owner source: `mobile/lib/features/practice/domain/models/garden_growth_snapshot.dart`

## Original Functionality Description

`GardenGrowthSnapshot` and related garden projection models represent garden patches, flowers, diary entries, milestones, latest practice impact, and projection warnings. They must preserve copy semantics and derived getters used by garden, shell, share, and mentor surfaces.

## Refactoring Approach

1. Add focused canary assertions for garden projection copy behavior and derived getters.
2. Run the generated-code canary before migration to capture existing behavior.
3. Change only the owner source `part` path and scoped Freezed generation include list.
4. Run build_runner to generate the new output under `lib/generated/`.
5. Delete the old co-located Freezed output.
6. Run analyzer, focused generated/practice tests, and full Flutter tests.

## Forbidden Changes

- Do not change garden projection fields, stage labels, issue detection, primary activity selection, milestone semantics, or latest-impact stage-change semantics.
- Do not expand generation to unrelated Freezed owners in this task.
- Do not enable unrestricted json_serializable or riverpod generation.
- Do not hand-edit generated Dart output.
- Do not introduce a generated-code hard gate yet.

## Acceptance Criteria

- [x] `GardenGrowthSnapshot` generated output lives under `mobile/lib/generated/`.
- [x] Old co-located `garden_growth_snapshot.freezed.dart` is removed.
- [x] Existing and new generated outputs do not coexist for this owner.
- [x] build_runner can reproduce the output with zero subsequent actions.
- [x] Generated-code canary tests pass.
- [x] Practice focused tests pass.
- [x] Full Flutter tests pass.

## Verification Evidence

| Command | Result |
|---|---|
| `runTests mobile/test/generated/generated_code_canary_test.dart` before migration | Passed; 9 tests |
| `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; generated garden growth Freezed output under `lib/generated/` |
| Re-run `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; `0 outputs (0 actions)` |
| `runTests mobile/test/generated/generated_code_canary_test.dart` after migration | Passed; 9 tests |
| `flutter test test/features/practice` | Passed; 27 tests |
| `flutter analyze` | Passed; no issues found |
| `flutter test` | Passed; `01:09 +234: All tests passed!` |

## Generated File Counts After Task

| Location | Freezed | Isar/source_gen `.g.dart` |
|---|---:|---:|
| `mobile/lib/generated/**` | 10 | 2 |
| Remaining co-located under `mobile/lib/features/**` | 1 | 0 |

## Residual Risks

- The remaining generated-code migration now consists of 1 co-located Freezed output.
- A generated-code placement hard gate is still not approved.

## Standard Git Commit Message

```text
refactor(mobile): migrate garden growth generated output
```