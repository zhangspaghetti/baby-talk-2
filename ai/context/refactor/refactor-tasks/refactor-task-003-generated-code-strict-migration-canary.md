---
id: REFACTOR-003
title: Generated Code Strict Migration Canary
status: completed
priority: high
phase: 1
assignee: AI
created: 2026-05-18
estimated: 1-2d
---

## Goal

Prove that generated outputs can be safely moved to `mobile/lib/generated/` before attempting a wider generated-code migration.

## Legacy Code Location

Current co-located generated outputs under `mobile/lib/features/**/*.freezed.dart` and `mobile/lib/features/**/*.g.dart`.

## Original Functionality Description

Freezed, json_serializable, Isar, and Riverpod generated files currently support model equality/copying, JSON, Isar schema, and generated providers. Behavior must remain equivalent.

## Refactoring Approach

1. Inventory all generated files and their owner source files.
2. Design mirror output paths under `mobile/lib/generated/`.
3. Select one Freezed model and one Isar entity canary.
4. Update build configuration and `part` directives for the canary only.
5. Run build_runner, analyze, and targeted tests.
6. Delete old canary generated outputs only after new outputs pass verification.

## Target Location

`mobile/lib/generated/`

## Allowed Changes

- Generated-code canary source owner files approved in the task kickoff: `household_invite_link.dart` and `mentor_fact_event_entity.dart`.
- `mobile/build.yaml` if needed.
- `mobile/analysis_options.yaml` generated exclusions if needed.
- New generated output under `mobile/lib/generated/`.

## Forbidden Changes

- Business logic changes.
- Multiple feature-wide migration in the same task.
- Hand editing generated files.
- Deleting old generated files before the new canary passes.

## Acceptance Criteria

- [x] Canary generated files live under `mobile/lib/generated/`.
- [x] `build_runner build --delete-conflicting-outputs` succeeds with the scoped canary config.
- [x] `flutter analyze` succeeds.
- [x] Targeted tests pass.
- [x] Rollback path is documented.

## Regression Test Requirements

- [x] Owner model/entity tests still pass.
- [x] Freezed model behavior and Isar schema/entity behavior are unchanged.
- [x] Build output is reproducible from generation; a rerun produced `0 outputs (0 actions)`.

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|-----|--------|-----|---------|
| Dart `part` tooling cannot support desired output path | Medium | High | Canary first; stop and escalate if generator cannot comply |
| Unrestricted build_runner scans unrelated generators with analyzer incompatibilities | High | Medium | Keep R003 build config scoped to selected Freezed and Isar canaries; resolve or except unrelated generator blockers separately |

## Review Checklist

- [x] Generated migration is isolated from business refactor.
- [x] No hand-edited generated code.
- [x] Old and new generated outputs do not coexist permanently for canary owners.

## Known Decisions

- Strict generated-code isolation is required by human decision HDR-R1-005.

## Authorizations

- Human selected `进入 R003 generated canary` after REFACTOR-018 completion on 2026-05-19.

## Completion Evidence

| Evidence | Result |
|---|---|
| Canary outputs | `mobile/lib/generated/features/household/domain/models/household_invite_link.freezed.dart`; `mobile/lib/generated/features/mentor/data/local/mentor_fact_event_entity.g.dart` |
| Co-located canary outputs | Removed after successful generation |
| `flutter test` | Pass; 222 tests passed |
| `flutter test --coverage` | Pass; 222 tests passed; LCOV 66.54% |

## Dependencies

- REFACTOR-002.
- Explicit approval of canary owner files.