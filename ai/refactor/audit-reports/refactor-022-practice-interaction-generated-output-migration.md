# REFACTOR-022 Practice Interaction Generated Output Migration

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4 generated-code blocker reduction
Created: 2026-05-19
Status: completed

## Summary

REFACTOR-022 moves the remaining co-located Isar/source_gen output, `InteractionEventEntity.g.dart`, into `mobile/lib/generated/features/practice/data/local/`. The task preserves practice event persistence behavior and adds canary coverage for schema availability and payload-to-entity mapping.

This task does not change runtime behavior, Isar schema semantics, persisted data shapes, or generated-code hard-gate policy.

## Migrated Owner

| Generator | Owner Source | Old Output | New Output |
|---|---|---|---|
| Isar/source_gen | `mobile/lib/features/practice/data/local/interaction_event_entity.dart` | `mobile/lib/features/practice/data/local/interaction_event_entity.g.dart` | `mobile/lib/generated/features/practice/data/local/interaction_event_entity.g.dart` |

## Build Configuration

`mobile/build.yaml` now includes `interaction_event_entity.dart` in the scoped Isar generation list alongside the original R003 mentor canary owner. The source_gen combining builder continues to route selected `.g.dart` output into `lib/generated/`. json_serializable and riverpod_generator remain disabled for this scoped migration path.

## Verification

| Command | Result |
|---|---|
| `runTests mobile/test/generated/generated_code_canary_test.dart` before migration | Passed; 4 tests |
| `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; generated practice `.g.dart` under `lib/generated/` |
| Re-run `flutter pub run build_runner build --delete-conflicting-outputs` | Passed; `0 outputs (0 actions)` |
| `runTests mobile/test/generated/generated_code_canary_test.dart` after migration | Passed; 4 tests |
| `flutter analyze` | Passed; no issues found |
| Practice focused tests via `runTests` | Passed; 35 tests |
| Full `runTests` | Passed; 267 tests |
| `flutter test` | Passed; `01:12 +229: All tests passed!` |

## Generated File Counts

| Location | Freezed | Isar/source_gen `.g.dart` |
|---|---:|---:|
| `mobile/lib/generated/**` | 2 | 2 |
| Remaining co-located under `mobile/lib/features/**` | 9 | 0 |

## Residual Risks

- The known analyzer/SDK compatibility warning remains during scoped build_runner generation.
- Remaining generated-code migration is now limited to 9 Freezed outputs.
- No hard generated-code gate is introduced in this task.

## Standard Git Commit Message

```text
refactor(mobile): migrate practice interaction generated output
```