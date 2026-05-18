# Refactor Task Queue

Version: Flutter AI Software Factory v1.0.0  
Stage: R2 Planning  
Created: 2026-05-18  
Status: approved through REFACTOR-010 execution

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
| 3 | REFACTOR-003 | 1 | blocked | Generated strict migration canary | REFACTOR-002, build config approval |
| 4 | REFACTOR-004 | 1 | done | App boot, router, and provider characterization tests | REFACTOR-002 |
| 5 | REFACTOR-005 | 1 | done | Auth and mentor consent characterization tests | REFACTOR-002 |
| 6 | REFACTOR-006 | 2 | done | Single Bearer JWT authenticated client/interceptor | REFACTOR-005 |
| 7 | REFACTOR-007 | 2 | done | Mentor/AI fail-closed consent gate | REFACTOR-005, REFACTOR-006 |
| 8 | REFACTOR-008 | 2 | done | Route contract inventory and GoRouter canonicalization pilot | REFACTOR-004 |
| 9 | REFACTOR-009 | 2 | done | Repository/usecase contract map and account adapter seam | REFACTOR-004 |
| 10 | REFACTOR-010 | 2 | done | Practice repository characterization harness | REFACTOR-002 |
| 11 | REFACTOR-011 | 2 | blocked | Feature boundary matrix and report-only import scan | REFACTOR-002 |
| 12 | REFACTOR-012 | 2 | blocked | AsyncValue low-risk pilot | REFACTOR-004 |
| 13 | REFACTOR-013 | 2 | blocked | Local sensitive data lifecycle plan and tests | REFACTOR-005 |
| 14 | REFACTOR-014 | 3 | blocked | Token/i18n behavior-preserving cleanup pilot | Phase 2 stability, yellow design decisions |
| 15 | REFACTOR-015 | 3 | blocked | Shared component extraction pilot | REFACTOR-014 |
| 16 | REFACTOR-016 | 3 | blocked | Accessibility semantics and localization pilot | REFACTOR-014 |
| 17 | REFACTOR-017 | 4 | blocked | Verification report suite | Phase 1-3 completed tasks |
| 18 | REFACTOR-018 | 4 | blocked | Legacy deletion candidate audit | REFACTOR-017 |

## First Implementation Candidate

Human approval on 2026-05-18 allowed REFACTOR-001 and REFACTOR-002. Both are complete. Follow-up human approvals selected baseline failure handling, REFACTOR-004, REFACTOR-005, REFACTOR-006, REFACTOR-007, REFACTOR-008, REFACTOR-009, and REFACTOR-010; REFACTOR-002A, REFACTOR-004, REFACTOR-005, REFACTOR-006, REFACTOR-007, REFACTOR-008, REFACTOR-009, and REFACTOR-010 are complete. REFACTOR-011 remains the next blocked Phase 2 task and requires separate approval before feature boundary matrix or report-only import scan work.