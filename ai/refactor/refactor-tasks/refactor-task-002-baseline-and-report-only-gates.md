---
id: REFACTOR-002
title: Baseline And Report-Only Gates
status: done
priority: high
phase: 1
assignee: AI
created: 2026-05-18
estimated: 1d
---

## Goal

Capture current verification baselines and add report-only governance scans before enabling hard CI gates.

## Legacy Code Location

Logical legacy surface: current `mobile/lib/app`, `mobile/lib/core`, `mobile/lib/features`, and `mobile/lib/l10n`.

## Original Functionality Description

The app currently boots, routes, stores local state, renders localized UI, and runs existing unit/widget/integration tests. This task only measures the current state.

## Refactoring Approach

1. Run `flutter analyze`, `flutter test`, and `flutter test --coverage` from `mobile/` when dependencies are available.
2. Generate report-only scans for generated file placement, cross-feature imports, direct infra imports, file size, UI literals, and hardcoded text.
3. Store outputs as audit artifacts.
4. Do not convert old violations into hard CI failures yet.

## Target Location

`ai/refactor/audit-reports/` and future enforcement docs under `ai/enforcement/`

## Allowed Changes

- New report artifacts under `ai/refactor/audit-reports/`
- New report-only scan documentation under `ai/enforcement/`

## Forbidden Changes

- Production Flutter source changes.
- Hard CI failure for existing legacy violations.
- Dependency upgrades.

## Acceptance Criteria

- [x] Analyze/test/coverage baseline is captured or environment blockers are documented.
- [x] Report-only scans are documented.
- [x] Existing CI behavior is not made stricter without approval.
- [x] All changed files are documentation or report artifacts.

## Regression Test Requirements

- [x] Run current test suite if local Flutter environment is available.
- [x] If tests cannot run, document the blocker and do not claim green CI.

## Completion Evidence

- Baseline report: `ai/refactor/audit-reports/phase-1-baseline-and-report-only-gates.md`
- `flutter analyze`: exit 0.
- `flutter test`: exit 1, one existing tool test failure recorded.
- `flutter test --coverage`: exit 1, same existing tool test failure recorded.
- Line coverage from generated `lcov.info`: 63.99%.

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|-----|--------|-----|---------|
| Hard gates make legacy debt block all work | High | Medium | Keep scans report-only first |

## Review Checklist

- [ ] No behavior changes.
- [ ] Baseline commands and outputs are recorded.
- [ ] Future hardening path is staged.

## Known Decisions

- Lint hardening is planned for Phase 1, not R0.

## Authorizations

- AI may run read-only verification commands.

## Dependencies

- REFACTOR-001.