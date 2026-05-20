# Daily Decision Summary

Date: 2026-05-20
Project: Baby Talk 2 mobile Flutter rescue  
Stage: R4 production-readiness closure in progress
Status: 2026-05-20 Strict Mode continuation requested; R0/R1/R2/R3 and approved R4 task queue through REFACTOR-035 are now recorded. REFACTOR-035 completed the garden/growth combined screen coverage slice and raised global LCOV from 73.91% to 75.32%. Production readiness remains blocked by global coverage below the 80% target or missing approved exception, incomplete real-store lifecycle wiring approval, absent backup/encryption proof, absent performance benchmarks, target-platform/CI replay, and pending final human release confirmation.

## Pending Decisions

| ID | Level | Topic | Recommended Decision | Required Human Confirmation |
|---|---|---|---|---|
| HDR-R0-004 | Yellow | Analyzer/lint hardening | Add Phase 1 lint/custom scans only after current `flutter analyze` and coverage baselines are known | Confirm lint hardening should be planned as Phase 1, not R0 |
| HDR-R0-005 | Yellow | Design token/i18n cleanup | Treat token and i18n cleanup as behavior-preserving only; no product copy rewrites without approval | Confirm copy/design changes require separate approval |
| HDR-R1-006 | Yellow | Design token scale | Preserve existing visual values first, then decide 16 vs 24 radius and spacing scale | Confirm design-token normalization rules during R2 |
| HDR-R4-001 | Red | Local sensitive data clearance orchestrator | Confirmed option 1: implement report-producing orchestrator test-first with no destructive flow wiring | Separate confirmation still required before any logout, consent withdrawal, account deletion, onboarding reset, or device-erasure wiring |
| HDR-R4-002 | Red | Next production-readiness track | Confirmed coverage track; continue coverage toward 80% unless a formal coverage exception is approved | Further track change requires confirmation |

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
| HDR-R4-001 | Local sensitive data clearance orchestrator option 1 approved | Core-only test-first implementation allowed; destructive flow wiring remains unapproved |
| HDR-R4-002 | Continue R4 production-readiness closure through coverage-first work | User requested "continue coverage to 80%" and REFACTOR-035 was executed as the first widget regression slice |

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

HDR-R4-002 selected the coverage-first track. REFACTOR-035 is complete and global LCOV is now 75.32%, still below the 80% target. Recommended next coverage slice: `account_repository.dart` or `home_screen.dart`; avoid using generated l10n coverage as the primary next slice unless generated localization files are explicitly included in the gate policy.
