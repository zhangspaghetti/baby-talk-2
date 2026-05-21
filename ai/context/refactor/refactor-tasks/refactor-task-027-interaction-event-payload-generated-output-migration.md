# Refactor Task: REFACTOR-027 Interaction Event Payload Generated Output Migration

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4 generated-code blocker reduction
Created: 2026-05-19
Status: completed

## Objective

Continue strict generated-code isolation by moving `InteractionEventPayload.freezed.dart` into `mobile/lib/generated/` without changing practice interaction event behavior.

## Scope

- Extend the existing generated-code canary with `InteractionEventPayload.copyWith`, `InteractionEventUploadRecord.copyWith`, and sync metadata assertions.
- Update `InteractionEventPayload` to point its `part` directive at `lib/generated/features/practice/domain/models/interaction_event_payload.freezed.dart`.
- Extend the scoped `mobile/build.yaml` Freezed include list with the interaction event payload owner only.
- Regenerate output with build_runner and delete the old co-located Freezed file.
- Keep json_serializable and riverpod_generator disabled in the scoped canary configuration.

## Legacy Code Location

- Old generated output: `mobile/lib/features/practice/domain/models/interaction_event_payload.freezed.dart`
- New generated output: `mobile/lib/generated/features/practice/domain/models/interaction_event_payload.freezed.dart`
- Owner source: `mobile/lib/features/practice/domain/models/interaction_event_payload.dart`

## Original Functionality Description

`InteractionEventPayload` and `InteractionEventUploadRecord` represent append-only practice interaction facts and upload records. They must preserve validation, event key derivation, wire-value parsing, upload record projection, fact map output, sync metadata output, and copy semantics.

## Refactoring Approach

1. Add focused canary assertions for generated copy behavior and metadata maps.
2. Run the generated-code canary before migration to capture existing behavior.
3. Change only the owner source `part` path and scoped Freezed generation include list.
4. Run build_runner to generate the new output under `lib/generated/`.
5. Delete the old co-located Freezed output.
6. Run analyzer, focused generated/practice tests, and full Flutter tests.

## Forbidden Changes

- Do not change interaction event fields, validation, event-key derivation, wire values, sync metadata semantics, or persisted map shapes.
- Do not expand generation to unrelated Freezed owners in this task.
- Do not enable unrestricted json_serializable or riverpod generation.
- Do not hand-edit generated Dart output.
- Do not introduce a generated-code hard gate yet.

## Acceptance Criteria

- [x] `InteractionEventPayload` generated output lives under `mobile/lib/generated/`.
- [x] Old co-located `interaction_event_payload.freezed.dart` is removed.
- [x] Existing and new generated outputs do not coexist for this owner.
- [x] build_runner can reproduce the output with zero subsequent actions.
- [x] Generated-code canary tests pass.
- [x] Practice focused tests pass.
- [x] Full Flutter tests pass.

## Verification Evidence

| Command | Result |
|---|---|
| `runTests mobile/test/generated/generated_code_canary_test.dart` before migration | Passed; 7 tests |
| `flutter pub run build_runner clean` | Passed; cache clean required because first build did not emit the migrated output |
| `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; generated interaction event payload Freezed output under `lib/generated/` |
| Re-run `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; `0 outputs (0 actions)` |
| `runTests mobile/test/generated/generated_code_canary_test.dart` after migration | Passed; 7 tests |
| `flutter test test/features/practice` | Passed; 27 tests |
| `flutter analyze` | Passed; no issues found |
| `flutter test` | Passed; `01:08 +232: All tests passed!` |

## Generated File Counts After Task

| Location | Freezed | Isar/source_gen `.g.dart` |
|---|---:|---:|
| `mobile/lib/generated/**` | 7 | 2 |
| Remaining co-located under `mobile/lib/features/**` | 4 | 0 |

## Residual Risks

- The remaining generated-code migration now consists of 4 co-located Freezed outputs.
- A generated-code placement hard gate is still not approved.

## Standard Git Commit Message

```text
refactor(mobile): migrate interaction event generated output
```