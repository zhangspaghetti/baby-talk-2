# Overall Refactor Plan

Version: Flutter AI Software Factory v1.0.0  
Stage: R2 - Refactor Planning  
Project: Baby Talk 2 mobile Flutter app  
Created: 2026-05-18  
Status: approved for REFACTOR-001/002 execution

## Goal

Rescue the Flutter mobile app through behavior-preserving, test-first, incremental refactoring. The target is a maintainable production-grade mobile architecture without changing existing user-visible behavior, route contracts, API payloads, persisted data semantics, or product requirements.

## Startup Confirmation

The refactor rescue is active in Strict Mode with Staff+ architecture governance. R0 project onboarding and R1 read-only audit are complete. R2 planning is authorized because the red R1 decisions are confirmed. R3 execution is approved for REFACTOR-001 and REFACTOR-002 only; later R3 tasks remain blocked until their task artifacts and allowed file sets are approved.

## Confirmed Red Decisions

| ID | Decision | R2/R3 Consequence |
|---|---|---|
| HDR-R1-001 | Riverpod + GoRouter is the canonical app composition target | Old Provider/router surfaces are temporary compatibility only |
| HDR-R1-002 | Bearer JWT is the canonical mobile auth source | Protected APIs use one authenticated client/interceptor |
| HDR-R1-003 | Mentor/AI network calls require parent login and accepted consent | Unauthenticated/unconsented users stay local-only and fail closed |
| HDR-R1-004 | Child, household, practice, mentor, and installation data are sensitive | R2/R3 must define storage, backup, deletion, and consent lifecycle rules |
| HDR-R1-005 | Generated code must move to `lib/generated/` | Strict generated-code migration is a high-risk Phase 1/2 task, not an exception |

## Scope

Included:

- Mobile Flutter app under `mobile/`.
- Architecture governance, test baselines, report-only gates, and CI hardening.
- App composition, router, repository/usecase, auth, consent, local-data, generated-code, design-token, i18n, a11y, and performance governance.
- Refactor tasks that preserve existing behavior and can be rolled back independently.

Excluded unless separately approved:

- Product feature changes.
- Product copy rewrites.
- Palette, spacing-density, radius, or interaction hierarchy redesigns.
- Backend API contract changes.
- Big-bang file movement or deleting old code before the replacement is live and verified.

## Phase Map

| Phase | Estimate | Primary Goal | Exit Gate |
|---|---:|---|---|
| Phase 1 | 1 week | Governance sync, baselines, report-only gates, generated-code canary, characterization tests | `flutter analyze` and `flutter test` baselines recorded; no runtime behavior changed |
| Phase 2 | 2-3 weeks | Core architecture seams: app composition, router, auth, consent, repository/usecase, feature boundaries, AsyncValue pilot | High-risk flows have characterization tests before source migration |
| Phase 3 | 1-2 weeks | UI/design-system/i18n/a11y cleanup with behavior and visual preservation | Token and localization changes preserve rendered output unless approved |
| Phase 4 | 1 week | Full verification, production readiness, legacy cleanup candidates | Coverage, security, performance, compatibility, and engineering reports generated |

## R3 Execution Rules

- One task, one behavior seam, one rollback path.
- Regression or characterization tests must exist before changing production code.
- No R3 task may exceed the approved allowed files in its task artifact.
- No task may change route paths, API payloads, persisted data shape, product copy, or visual values without a new decision artifact.
- Generated-code migration must be isolated from business refactors.
- Old Provider/router surfaces may be wrapped or bridged, but not deleted until replacement behavior is tested.
- Old violations start as report-only. Hard CI failure applies first to new violations, then expands after baselines are stable.

## Deliverables

- `phase-1-plan.md`
- `phase-2-plan.md`
- `phase-3-plan.md`
- `phase-4-plan.md`
- `risks-and-mitigations.md`
- `success-metrics.md`
- `ai/context/refactor/refactor-tasks/refactor-task-index.md`
- First detailed task artifacts under `ai/context/refactor/refactor-tasks/`

## Approval Gate

R2 planning is approved for REFACTOR-001 and REFACTOR-002. Later R3 implementation starts only after human approval of each task's allowed file set.