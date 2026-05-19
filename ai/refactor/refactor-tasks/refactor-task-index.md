# Refactor Task Queue

Version: Flutter AI Software Factory v1.0.0  
Stage: R2 Planning  
Created: 2026-05-18  
Status: approved through REFACTOR-032 generated code hard gate; production readiness remains blocked

## Ordering Rules

- Run tasks in priority order unless a task is explicitly blocked.
- Each task must use the dedicated refactor task template before implementation.
- A task may not start without its regression or characterization test requirement.
- High-risk tasks remain blocked until their entry criteria are satisfied.

## Queue

| Order | ID | Phase | Status | Task | Depends On |
|---:|---|---:|---|---|---|
| 1 | REFACTOR-001 | 1 | done | Sync decisions and governance baseline | none |
| 2 | REFACTOR-002 | 1 | done | Capture analyze/test/coverage baseline and report-only scans | REFACTOR-001 |
| 2.1 | REFACTOR-002A | 1 | done | Recover red mobile test baseline from stale CI handoff assertion | REFACTOR-002 |
| 3 | REFACTOR-003 | 1 | done | Generated strict migration canary | REFACTOR-002, build config approval |
| 4 | REFACTOR-004 | 1 | done | App boot, router, and provider characterization tests | REFACTOR-002 |
| 5 | REFACTOR-005 | 1 | done | Auth and mentor consent characterization tests | REFACTOR-002 |
| 6 | REFACTOR-006 | 2 | done | Single Bearer JWT authenticated client/interceptor | REFACTOR-005 |
| 7 | REFACTOR-007 | 2 | done | Mentor/AI fail-closed consent gate | REFACTOR-005, REFACTOR-006 |
| 8 | REFACTOR-008 | 2 | done | Route contract inventory and GoRouter canonicalization pilot | REFACTOR-004 |
| 9 | REFACTOR-009 | 2 | done | Repository/usecase contract map and account adapter seam | REFACTOR-004 |
| 10 | REFACTOR-010 | 2 | done | Practice repository characterization harness | REFACTOR-002 |
| 11 | REFACTOR-011 | 2 | done | Feature boundary matrix and report-only import scan | REFACTOR-002 |
| 12 | REFACTOR-012 | 2 | done | AsyncValue low-risk pilot | REFACTOR-004 |
| 13 | REFACTOR-013 | 2 | done | Local sensitive data lifecycle plan and tests | REFACTOR-005 |
| 14 | REFACTOR-014 | 3 | done | Token/i18n behavior-preserving cleanup pilot | Phase 2 stability, yellow design decisions |
| 15 | REFACTOR-015 | 3 | done | Shared component extraction pilot | REFACTOR-014 |
| 16 | REFACTOR-016 | 3 | done | Accessibility semantics and localization pilot | REFACTOR-014, REFACTOR-015 |
| 17 | REFACTOR-017 | 4 | done | Verification report suite | Phase 1-3 completed tasks |
| 17.1 | REFACTOR-017A | 4 | done | Integration blocker stabilization | REFACTOR-017 |
| 18 | REFACTOR-018 | 4 | done | Legacy deletion candidate audit | REFACTOR-017 |
| 19 | REFACTOR-019 | 4 | done | Installation ID delete primitive and lifecycle scanner closure | REFACTOR-013, REFACTOR-017 |
| 20 | REFACTOR-020 | 4 | done | Core-only local sensitive data clearance orchestrator | REFACTOR-019, HDR-R4-001 option 1 |
| 21 | REFACTOR-021 | 4 | done | AccountSession generated output migration | REFACTOR-003, HDR-R1-005 |
| 22 | REFACTOR-022 | 4 | done | Practice interaction generated output migration | REFACTOR-003, REFACTOR-021, HDR-R1-005 |
| 23 | REFACTOR-023 | 4 | done | Share draft generated output migration | REFACTOR-003, REFACTOR-021, REFACTOR-022, HDR-R1-005 |
| 24 | REFACTOR-024 | 4 | done | Local mentor suggestion generated output migration | REFACTOR-003, REFACTOR-023, HDR-R1-005 |
| 25 | REFACTOR-025 | 4 | done | Mentor fact event generated output migration | REFACTOR-003, REFACTOR-024, HDR-R1-005 |
| 26 | REFACTOR-026 | 4 | done | Practice phrase generated output migration | REFACTOR-003, REFACTOR-025, HDR-R1-005 |
| 27 | REFACTOR-027 | 4 | done | Interaction event payload generated output migration | REFACTOR-003, REFACTOR-026, HDR-R1-005 |
| 28 | REFACTOR-028 | 4 | done | Practice continuity generated output migration | REFACTOR-003, REFACTOR-027, HDR-R1-005 |
| 29 | REFACTOR-029 | 4 | done | Practice activity catalog generated output migration | REFACTOR-003, REFACTOR-028, HDR-R1-005 |
| 30 | REFACTOR-030 | 4 | done | Garden growth generated output migration | REFACTOR-003, REFACTOR-029, HDR-R1-005 |
| 31 | REFACTOR-031 | 4 | done | Onboarding generated output migration | REFACTOR-003, REFACTOR-030, HDR-R1-005 |
| 32 | REFACTOR-032 | 4 | done | Generated code hard gate | REFACTOR-003, REFACTOR-031, HDR-R1-005 |
| 33 | REFACTOR-033 | 4 | done | Critical UI coverage slice | REFACTOR-032, coverage blocker selection |
| 34 | REFACTOR-034 | 4 | done | Global coverage stabilization and household UI slice | REFACTOR-033, coverage blocker selection |

## First Implementation Candidate

Human approval on 2026-05-18 allowed REFACTOR-001 and REFACTOR-002. Both are complete. Follow-up human approvals selected baseline failure handling, REFACTOR-004, REFACTOR-005, REFACTOR-006, REFACTOR-007, REFACTOR-008, REFACTOR-009, REFACTOR-010, REFACTOR-011, REFACTOR-012, REFACTOR-013, REFACTOR-014, REFACTOR-015, REFACTOR-016, REFACTOR-017, REFACTOR-018, the REFACTOR-003 generated-code canary backfill, REFACTOR-017A integration blocker stabilization, REFACTOR-019 installation ID lifecycle primitive, REFACTOR-020 core-only clearance orchestrator, REFACTOR-021 AccountSession generated output migration, REFACTOR-022 practice interaction generated output migration, REFACTOR-023 share draft generated output migration, REFACTOR-024 local mentor suggestion generated output migration, REFACTOR-025 mentor fact event generated output migration, REFACTOR-026 practice phrase generated output migration, REFACTOR-027 interaction event payload generated output migration, REFACTOR-028 practice continuity generated output migration, REFACTOR-029 practice activity catalog generated output migration, REFACTOR-030 garden growth generated output migration, REFACTOR-031 onboarding generated output migration, REFACTOR-032 generated code hard gate, REFACTOR-033 critical UI coverage slice, and REFACTOR-034 global coverage stabilization. REFACTOR-002A through REFACTOR-034 are complete. No immediate legacy deletion is approved. The next task should be explicitly selected by a human: continue global coverage work toward 80% or approve an exception, destructive lifecycle wiring with UX confirmation, performance benchmark gate, target-platform/CI replay of the integration evidence, or a narrowly scoped approved follow-up migration.