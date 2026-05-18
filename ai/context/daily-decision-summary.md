# Daily Decision Summary

Date: 2026-05-19  
Project: Baby Talk 2 mobile Flutter rescue  
Stage: R3 Phase 3 in progress
Status: red decisions confirmed; REFACTOR-006 Bearer JWT header task complete; REFACTOR-007 Mentor/AI fail-closed consent gate complete; REFACTOR-008 route contract pilot complete; REFACTOR-009 account repository contract seam complete; REFACTOR-010 practice repository characterization harness complete; REFACTOR-011 feature boundary report-only scan complete; REFACTOR-012 AsyncValue low-risk pilot complete; REFACTOR-013 local sensitive data lifecycle report-only scan complete; REFACTOR-014 token/i18n behavior-preserving cleanup pilot complete; REFACTOR-015 shared component extraction pilot complete; REFACTOR-016 accessibility semantics and localization pilot complete

## Pending Decisions

| ID | Level | Topic | Recommended Decision | Required Human Confirmation |
|---|---|---|---|---|
| HDR-R0-004 | Yellow | Analyzer/lint hardening | Add Phase 1 lint/custom scans only after current `flutter analyze` and coverage baselines are known | Confirm lint hardening should be planned as Phase 1, not R0 |
| HDR-R0-005 | Yellow | Design token/i18n cleanup | Treat token and i18n cleanup as behavior-preserving only; no product copy rewrites without approval | Confirm copy/design changes require separate approval |
| HDR-R1-006 | Yellow | Design token scale | Preserve existing visual values first, then decide 16 vs 24 radius and spacing scale | Confirm design-token normalization rules during R2 |

## Confirmed Decisions

| ID | Decision | Evidence |
|---|---|---|
| AR-R0-001 | Strict Mode selected | Project is large, user-facing, long-lived, and has multiple debt categories |
| AR-R0-002 | R0 is artifact-only | User requires incremental refactor, CI green, and no behavior change |
| HDR-R0-001 | Approved deferring full physical `lib/legacy/` migration | Logical legacy classification during R0 and later one-tested-module-at-a-time migration |
| HDR-R0-002 | Approved full read-only R1 audit scope | Audit covered `mobile/lib`, `mobile/test`, and `mobile/integration_test` before implementation |
| HDR-R0-003 | Approved architecture-safety-first R2 priority | Regression baseline, app composition, DI, practice repository, routing, and state truth before UI cleanup |
| HDR-R1-001 | Riverpod + GoRouter is the canonical app composition target | Old Provider/router surfaces are temporary compatibility layers only |
| HDR-R1-002 | Bearer JWT is the canonical mobile auth source | Protected API calls must use one authenticated client/interceptor |
| HDR-R1-003 | Mentor/AI network calls require parent login and accepted consent | Unauthenticated/unconsented users must remain local-only |
| HDR-R1-004 | Local child, household, practice, mentor, and installation data is sensitive | R2/R3 must define encryption/secure storage, backup exclusion, and deletion lifecycle |
| HDR-R1-005 | Generated code must be strictly migrated to `lib/generated/` | No project exception for co-located Dart `part` outputs is approved |

## R1 Report Artifacts

| Report | Path |
|---|---|
| Full code audit | `ai/refactor/audit-reports/full-code-audit-report.md` |
| Architecture issues | `ai/refactor/audit-reports/architecture-issues.md` |
| Design-system issues | `ai/refactor/audit-reports/design-system-issues.md` |
| Security issues | `ai/refactor/audit-reports/security-issues.md` |
| Performance issues | `ai/refactor/audit-reports/performance-issues.md` |
| Technical-debt assessment | `ai/refactor/audit-reports/technical-debt-assessment.md` |
| Risks and mitigations | `ai/refactor/audit-reports/risks-and-mitigations.md` |
| Test/regression baseline | `ai/refactor/audit-reports/test-regression-baseline.md` |

## Questions To User

No new open REFACTOR-016 decision was added. REFACTOR-017 is the next blocked Phase 4 verification task and requires Phase 1-3 completion evidence before execution. Yellow design/lint decisions should be resolved before broader cleanup or before converting report-only gates into hard CI failures.
