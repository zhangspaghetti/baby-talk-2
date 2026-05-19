# Daily Decision Summary

Date: 2026-05-19  
Project: Baby Talk 2 mobile Flutter rescue  
Stage: R4 Phase 4 in progress
Status: red decisions confirmed; REFACTOR-003 generated-code strict migration canary complete; REFACTOR-006 Bearer JWT header task complete; REFACTOR-007 Mentor/AI fail-closed consent gate complete; REFACTOR-008 route contract pilot complete; REFACTOR-009 account repository contract seam complete; REFACTOR-010 practice repository characterization harness complete; REFACTOR-011 feature boundary report-only scan complete; REFACTOR-012 AsyncValue low-risk pilot complete; REFACTOR-013 local sensitive data lifecycle report-only scan complete; REFACTOR-014 token/i18n behavior-preserving cleanup pilot complete; REFACTOR-015 shared component extraction pilot complete; REFACTOR-016 accessibility semantics and localization pilot complete; REFACTOR-017 verification report suite complete; REFACTOR-017A integration blocker stabilization complete; REFACTOR-018 legacy deletion candidate audit complete; production readiness and deletion remain blocked

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

No new open REFACTOR-003 implementation decision was added because the user selected the generated-code canary and the task remained narrowly scoped. R003 moved one Freezed output and one Isar output into `mobile/lib/generated/`; remaining co-located generated outputs are 10 Freezed files and 1 Isar/source_gen `.g.dart` file. REFACTOR-017A restored local focused integration evidence for S01, S02, S03, and S06 and reran `flutter analyze` successfully. Production readiness remains blocked by 66.54% coverage versus the 80% target, missing critical UI coverage slice, incomplete sensitive lifecycle enforcement, absent performance benchmarks, remaining generated-code migration/hard-gate work, target-platform/CI replay, and pending final human release confirmation. The next task should be explicitly selected: raise or except coverage, add the installation ID delete primitive, create performance benchmarks, expand generated-code migration in small batches, replay integration evidence on target CI/platforms, or plan a narrowly scoped follow-up migration. Yellow design/lint decisions should be resolved before broader cleanup or before converting report-only gates into hard CI failures.
