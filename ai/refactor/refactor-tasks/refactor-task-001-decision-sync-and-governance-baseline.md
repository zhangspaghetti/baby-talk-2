---
id: REFACTOR-001
title: Decision Sync And Governance Baseline
status: done
priority: high
phase: 1
assignee: AI
created: 2026-05-18
estimated: 0.5d
---

## Goal

Synchronize confirmed red decisions across governance artifacts and prepare Phase 1 baseline work without modifying runtime Flutter source.

## Legacy Code Location

Not applicable. This is a governance task.

## Original Functionality Description

No app behavior is changed. Existing Flutter app behavior, routes, storage, API calls, and UI remain untouched.

## Refactoring Approach

1. Update daily decision summary and human decision index.
2. Confirm R2 plan references the current decisions.
3. Record unresolved yellow decisions for Phase 3 or lint hardening.
4. Verify no runtime Flutter source files were modified.

## Target Location

`ai/context/` and `ai/refactor/migration-plans/`

## Allowed Changes

- `ai/context/daily-decision-summary.md`
- `ai/context/human-decision-index.md`
- `ai/context/authorization-records.md`
- `ai/refactor/migration-plans/*.md`

## Forbidden Changes

- Any file under `mobile/lib/`
- Any file under `mobile/test/`
- Any product behavior, route, API, or storage change

## Acceptance Criteria

- [x] Red decisions are marked confirmed.
- [x] Yellow decisions remain visible and scoped.
- [x] R2 plans reference confirmed decisions.
- [x] Git status confirms no runtime Flutter source was touched by this task.

## Regression Test Requirements

- [x] No runtime tests required because no runtime source changes are allowed.
- [x] Worktree status check required.

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|-----|--------|-----|---------|
| Governance artifacts drift from user decisions | Medium | High | Update all decision indexes in one task |

## Review Checklist

- [ ] Refactor does not change app behavior.
- [ ] Decision artifacts are internally consistent.
- [ ] R2 remains blocked from implementation until plan approval.

## Known Decisions

- Riverpod + GoRouter target.
- Bearer JWT auth source.
- Mentor/AI login + consent gate.
- Sensitive local data policy.
- Strict generated-code migration to `lib/generated/`.

## Authorizations

- AI may update governance and planning artifacts.

## Dependencies

- None.