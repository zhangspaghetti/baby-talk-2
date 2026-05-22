# Refactor Task Queue

Version: Flutter AI Software Factory v1.0.0  
Stage: R2 Planning  
Created: 2026-05-18  
Status: approved queue complete through REFACTOR-048; global coverage gate met; local full performance profile captured; real-store lifecycle registry verified; backup-exclusion posture implemented; R4 release-gate policy active; approved account deletion lifecycle wiring added; production readiness remains blocked by remaining target and release gates

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
| 35 | REFACTOR-035 | 4 | done | Garden growth combined screen coverage continuation | REFACTOR-034, HDR-R4-002 |
| 36 | REFACTOR-036 | 4 | done | Account, practice session, and home coverage closure | REFACTOR-035, coverage blocker selection |
| 37 | REFACTOR-037 | 4 | done | R4 performance baseline harness | REFACTOR-036, performance blocker selection |
| 38 | REFACTOR-038 | 4 | done | Real-store lifecycle clearance registry | REFACTOR-020, lifecycle blocker selection |
| 39 | REFACTOR-039 | 4 | done | Local sensitive data backup posture | REFACTOR-038, backup/encryption blocker selection |
| 40 | REFACTOR-040 | 4 | done | R4 release gate policy and replay | REFACTOR-039, next R4 gates selection |
| 41 | REFACTOR-041 | 4 | done | Destructive lifecycle target proof and replay | REFACTOR-040, HDR-R4-003 option 3 |
| 42 | REFACTOR-042 | 5 | done | Onboarding product-grade redesign and activation mini-scene | Stage 3.1 Slice 2, human product-design selection |
| 43 | REFACTOR-043 | 5 | done | Practice C3 product polish | REFACTOR-042 |
| 44 | REFACTOR-044 | 5 | done | Garden continuation copy polish | REFACTOR-043 |
| 45 | REFACTOR-045 | 5 | done | Home/Garden copy leak audit | REFACTOR-044 |
| 46 | REFACTOR-046 | 5 | done | Discover/Share/Mentor copy leak audit | REFACTOR-045 |
| 47 | REFACTOR-047 | 5 | done | App-wide product copy scan | REFACTOR-046 |
| 48 | REFACTOR-048 | 5 | done | Growth preview sheet polish | REFACTOR-047 |

## First Implementation Candidate

Human approval on 2026-05-18 allowed REFACTOR-001 and REFACTOR-002. Both are complete. Follow-up human approvals selected baseline failure handling, REFACTOR-004, REFACTOR-005, REFACTOR-006, REFACTOR-007, REFACTOR-008, REFACTOR-009, REFACTOR-010, REFACTOR-011, REFACTOR-012, REFACTOR-013, REFACTOR-014, REFACTOR-015, REFACTOR-016, REFACTOR-017, REFACTOR-018, the REFACTOR-003 generated-code canary backfill, REFACTOR-017A integration blocker stabilization, REFACTOR-019 installation ID lifecycle primitive, REFACTOR-020 core-only clearance orchestrator, REFACTOR-021 AccountSession generated output migration, REFACTOR-022 practice interaction generated output migration, REFACTOR-023 share draft generated output migration, REFACTOR-024 local mentor suggestion generated output migration, REFACTOR-025 mentor fact event generated output migration, REFACTOR-026 practice phrase generated output migration, REFACTOR-027 interaction event payload generated output migration, REFACTOR-028 practice continuity generated output migration, REFACTOR-029 practice activity catalog generated output migration, REFACTOR-030 garden growth generated output migration, REFACTOR-031 onboarding generated output migration, REFACTOR-032 generated code hard gate, REFACTOR-033 critical UI coverage slice, REFACTOR-034 global coverage stabilization, REFACTOR-035 garden growth combined screen coverage, REFACTOR-036 account/practice/home coverage closure, REFACTOR-037 R4 performance baseline harness, REFACTOR-038 real-store lifecycle clearance registry, REFACTOR-039 local sensitive data backup posture, REFACTOR-040 R4 release gate policy/replay, REFACTOR-041 destructive lifecycle target proof/replay, REFACTOR-042 onboarding activation, REFACTOR-043 practice C3 product polish, REFACTOR-044 Garden continuation copy polish, REFACTOR-045 Home/Garden copy leak audit, REFACTOR-046 Discover/Share/Mentor copy leak audit, REFACTOR-047 app-wide product copy scan, and REFACTOR-048 Growth preview sheet polish. REFACTOR-002A through REFACTOR-048 are complete. No immediate legacy deletion is approved. Global LCOV is now 80.29%, meeting the 80% target; a local full performance profile, lifecycle real-store registry, backup-exclusion posture, URL allowlist, no-regression hard-gate policy, and approved account deletion lifecycle wiring exist, but live CI, macOS/iOS runtime backup proof execution, approved target/profile performance measurements, and final release gates remain open.