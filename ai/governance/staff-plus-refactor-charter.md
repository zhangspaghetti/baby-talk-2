# Staff+ Legacy Refactor Charter

Version: Flutter AI Software Factory v1.0.0  
Mode: Strict Mode / Mode B Legacy Refactor  
Project: Baby Talk 2 mobile Flutter app  
Created: 2026-05-16  
Updated: 2026-05-19
Status: active; R4 verification in progress; production readiness blocked

## Startup Confirmation

The Flutter legacy rescue is started at Stage R0: Project Onboarding and Initialization.

This stage is limited to governance, evidence gathering, baseline reporting, and decision registration. No production Flutter behavior will be changed during R0.

## Non-Negotiables

- Incremental refactor only. No big-bang rewrite.
- Existing functionality, routes, data formats, and user-visible behavior must not change during refactor tasks.
- Every refactor task must have regression evidence before implementation.
- CI must remain green after every code change.
- All decisions must be stored as artifacts, not only in chat or agent memory.
- Red-level decisions require human confirmation before implementation.
- AI may autonomously create documentation and run read-only analysis, but may not move or delete source code without explicit approval.

## Operating Mode

Strict Mode is selected because the project is a large, user-facing, long-lived Flutter application with known architecture, UX, state, i18n, accessibility, and repository-boundary debt.

Required review perspectives for later stages:

- Product governance
- UX architecture
- UI/design-system governance
- Software architecture
- Security and privacy
- Test and regression analysis
- Performance baseline
- Code review
- Reality check
- Orchestration and decision aggregation

## Legacy Isolation Policy

The v1.0.0 workflow says original code should be moved to `lib/legacy/` during Stage R0. For this repository, that physical move is deferred as a red-level decision because the app already has a functioning `app/core/features/l10n` structure and 127 tracked Dart files. Moving all code at once would create high import churn and may violate the user's no-behavior-change and CI-green constraints.

For R0, existing code is classified as the legacy surface logically. Physical migration to `lib/legacy/` may only happen later as small, test-backed refactor tasks, one module at a time.

## Stage Timeline

| Stage | Duration | Purpose | Exit Artifact |
|---|---:|---|---|
| R0 | 1-2 days | Project onboarding, governance setup, baseline inventory | `ai/refactor/audit-reports/refactor-project-assessment.md` |
| R1 | 3-5 days | Full architecture, code, design, security, performance, and engineering audit | `ai/refactor/audit-reports/full-code-audit-report.md` |
| R2 | 2-3 days | Prioritized migration plan and refactor task queue | `ai/refactor/migration-plans/overall-refactor-plan.md` |
| R3 | 4-6 weeks | Incremental refactor execution, one task/module at a time | Completed refactor task artifacts |
| R4 | 3-5 days | Full validation and production-readiness verification | `ai/refactor/verification-reports/overall-production-readiness-report.md` |
| R5 | Ongoing | Continuous governance to prevent debt regression | Weekly/monthly governance reports |

## Current R0 Acceptance Criteria

- [x] Strict Mode selected and recorded.
- [x] R0 no-code-change boundary recorded.
- [x] Flutter app inventory started.
- [x] Initial hotspots recorded with file paths.
- [x] Daily decision summary created.
- [x] Human confirmation received for red-level Stage R0 decisions.
- [x] R1 audit tasks approved.

## Current R1 Acceptance Criteria

- [x] Full read-only code audit completed.
- [x] Architecture issues report generated.
- [x] Design-system issues report generated.
- [x] Security issues report generated.
- [x] Performance issues report generated.
- [x] Technical-debt assessment generated.
- [x] Risks and mitigations report generated.
- [x] R1 red decisions registered in `ai/context/pending-decisions/`.
- [x] Daily decision summary updated.
- [ ] Human confirmation received for red-level R1 decisions.

## Current Position

R0, R1, R2, and the approved R3/R4 refactor tasks through REFACTOR-019 are complete. The project remains in R4 verification and is not production-ready.

## Current Blocker

Production readiness remains blocked by coverage below target, missing critical UI coverage measurement, incomplete unified lifecycle enforcement, missing performance benchmarks, target-platform/CI replay, remaining generated-code and hard-gate work, and final human release confirmation. Legacy deletion remains blocked.
