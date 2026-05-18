---
id: REFACTOR-003
title: Generated Code Strict Migration Canary
status: blocked
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

- Generated-code canary source owner files approved in the task kickoff.
- `mobile/build.yaml` if needed.
- `mobile/analysis_options.yaml` generated exclusions if needed.
- New generated output under `mobile/lib/generated/`.

## Forbidden Changes

- Business logic changes.
- Multiple feature-wide migration in the same task.
- Hand editing generated files.
- Deleting old generated files before the new canary passes.

## Acceptance Criteria

- [ ] Canary generated files live under `mobile/lib/generated/`.
- [ ] `build_runner build --delete-conflicting-outputs` succeeds.
- [ ] `flutter analyze` succeeds or all blockers are documented.
- [ ] Targeted tests pass.
- [ ] Rollback path is documented.

## Regression Test Requirements

- [ ] Owner model/entity tests still pass.
- [ ] Serialization/schema behavior is unchanged.
- [ ] Build output is reproducible from clean generation.

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|-----|--------|-----|---------|
| Dart `part` tooling cannot support desired output path | Medium | High | Canary first; stop and escalate if generator cannot comply |

## Review Checklist

- [ ] Generated migration is isolated from business refactor.
- [ ] No hand-edited generated code.
- [ ] Old and new generated outputs do not coexist permanently.

## Known Decisions

- Strict generated-code isolation is required by human decision HDR-R1-005.

## Authorizations

- Not authorized until canary owner files and build config approach are approved.

## Dependencies

- REFACTOR-002.
- Explicit approval of canary owner files.