# Refactor Task: REFACTOR-018 Legacy Deletion Candidate Audit

Version: Flutter AI Software Factory v1.0.0
Stage: R4 / Phase 4
Created: 2026-05-19
Status: completed

## Objective

Audit legacy deletion candidates after REFACTOR-017 without deleting, moving, or rewriting runtime code. The output is a candidate matrix, blocker list, and required proof plan for any future deletion work.

## Scope

- Review R017 production-readiness blockers before considering any deletion candidate.
- Refresh report-only feature-boundary and sensitive-lifecycle scanner evidence.
- Classify legacy surfaces as immediate deletion, candidate after blockers, migration-only, or retain.
- Record required tests, contracts, human gates, and non-goals.
- Update governance artifacts to show REFACTOR-018 completion state.

## Allowed Files

- `ai/context/refactor/refactor-tasks/refactor-task-018-legacy-deletion-candidate-audit.md`
- `ai/context/refactor/refactor-tasks/refactor-task-index.md`
- `ai/context/daily-decision-summary.md`
- `ai/context/refactor/audit-reports/refactor-018-legacy-deletion-candidate-audit.md`

## Forbidden Changes

- Do not modify mobile production code or tests.
- Do not delete, move, rename, or archive legacy files.
- Do not change routes, API payloads, persisted data shape, product copy, generated files, or visual behavior.
- Do not convert report-only scanners into hard CI failures.
- Do not claim production readiness or legacy deletion approval.

## Acceptance Criteria

- [x] Legacy deletion candidate audit exists.
- [x] Audit states whether any file or surface is safe to delete immediately.
- [x] Candidate matrix includes blockers and required replacement proof.
- [x] R017 production-readiness blockers are reflected.
- [x] Feature-boundary and sensitive-lifecycle report-only scanners are refreshed.
- [x] Task index and daily summary reflect R018 completion.

## Regression Test Requirements

- [x] `dart tool/verify_refactor_011_feature_boundaries.dart` runs successfully in report-only mode.
- [x] `dart tool/verify_refactor_013_sensitive_lifecycle.dart` runs successfully in report-only mode.
- [x] No mobile production/test file is changed by R018.
- [x] R017 same-day `flutter analyze`, `flutter test`, and `flutter test --coverage` evidence remains the latest runtime regression baseline.

## Evidence Summary

| Check | Result |
|---|---|
| REFACTOR-011 feature boundary scanner | Passed in report-only mode; `total_cross_feature_imports=99`, `legacy_bridge=69`, `forbidden_candidate=30` |
| REFACTOR-013 sensitive lifecycle scanner | Passed in report-only mode; `total_sensitive_surfaces=6`, `covered_delete_primitive=5`, `missing_delete_primitive=1` |
| Immediate deletion candidates | None |
| Production readiness | Not approved by R017; release and deletion remain blocked |

## Completion Decision

REFACTOR-018 is complete as a report-only audit. It authorizes no deletion. Every listed candidate requires replacement evidence, green integration gates or approved exceptions, and explicit human confirmation before any future removal task.

## Authorizations

- Human selected `进入 REFACTOR-018` after REFACTOR-017 completion on 2026-05-19.

## Dependencies

- REFACTOR-017 verification report suite completed in commit `c41c59c`.
- R017 production-readiness blockers remain active.