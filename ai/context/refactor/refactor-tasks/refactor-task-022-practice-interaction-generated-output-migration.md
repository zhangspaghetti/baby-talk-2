# Refactor Task: REFACTOR-022 Practice Interaction Generated Output Migration

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4 generated-code blocker reduction
Created: 2026-05-19
Status: completed

## Objective

Continue strict generated-code isolation by moving the remaining co-located Isar/source_gen output, `InteractionEventEntity.g.dart`, into `mobile/lib/generated/` without changing practice persistence behavior.

## Scope

- Add a focused generated-code canary test for `InteractionEventEntity` schema and payload mapping behavior.
- Update `InteractionEventEntity` to point its `part` directive at `lib/generated/features/practice/data/local/interaction_event_entity.g.dart`.
- Extend the scoped `mobile/build.yaml` `isar_generator` include list with the practice entity owner only.
- Regenerate output with build_runner and delete the old co-located `.g.dart` file.
- Keep json_serializable and riverpod_generator disabled in the scoped canary configuration.

## Legacy Code Location

- Old generated output: `mobile/lib/features/practice/data/local/interaction_event_entity.g.dart`
- New generated output: `mobile/lib/generated/features/practice/data/local/interaction_event_entity.g.dart`
- Owner source: `mobile/lib/features/practice/data/local/interaction_event_entity.dart`

## Original Functionality Description

`InteractionEventEntity` is the Isar persistence entity for practice interaction events. It must preserve collection schema availability, unique indexes, event-key mapping, fact-map output, and sync metadata persistence behavior used by practice repository tests.

## Refactoring Approach

1. Add a focused canary test that reads `InteractionEventEntitySchema` and validates `fromPayload` mapping.
2. Run the canary before migration to capture existing behavior.
3. Change only the owner source `part` path and scoped Isar generation include list.
4. Run build_runner to generate the new output under `lib/generated/`.
5. Delete the old co-located `.g.dart` output.
6. Run analyzer, focused generated/practice tests, and full Flutter tests.

## Forbidden Changes

- Do not change Isar fields, indexes, collection IDs, schema name, event-key mapping, or persisted map shapes.
- Do not expand generation to unrelated Isar or Freezed owners in this task.
- Do not enable unrestricted json_serializable or riverpod generation.
- Do not hand-edit generated Dart output.
- Do not introduce a generated-code hard gate yet.

## Acceptance Criteria

- [x] `InteractionEventEntity` generated output lives under `mobile/lib/generated/`.
- [x] Old co-located `interaction_event_entity.g.dart` is removed.
- [x] Existing and new generated outputs do not coexist for this owner.
- [x] build_runner can reproduce the output with zero subsequent actions.
- [x] Practice persistence tests pass.
- [x] Full Flutter tests pass.

## Verification Evidence

| Command | Result |
|---|---|
| `runTests mobile/test/generated/generated_code_canary_test.dart` before migration | Passed; 4 tests |
| `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; generated practice `.g.dart` output, with existing analyzer-version warning |
| Re-run `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; `0 outputs (0 actions)` |
| `runTests mobile/test/generated/generated_code_canary_test.dart` after migration | Passed; 4 tests |
| `flutter analyze` | Passed; no issues found |
| Practice focused tests via `runTests` | Passed; 35 tests |
| Full `runTests` | Passed; 267 tests |
| `flutter test` | Passed; `01:12 +229: All tests passed!` |

## Generated File Counts After Task

| Location | Freezed | Isar/source_gen `.g.dart` |
|---|---:|---:|
| `mobile/lib/generated/**` | 2 | 2 |
| Remaining co-located under `mobile/lib/features/**` | 9 | 0 |

## Residual Risks

- `build_runner` still reports the known analyzer/SDK compatibility warning; it did not fail this scoped generation.
- The remaining generated-code migration now consists of 9 co-located Freezed outputs.
- A generated-code placement hard gate is still not approved.

## Standard Git Commit Message

```text
refactor(mobile): migrate practice interaction generated output
```