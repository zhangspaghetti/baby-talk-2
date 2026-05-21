# R0 To R5 Refactor Timeline

Version: Flutter AI Software Factory v1.0.0  
Created: 2026-05-16  
Updated: 2026-05-20
Status: active

## Current Position

R0, R1, R2, R3, and the completed R4 task queue through REFACTOR-041 are already recorded. The current continuation point is R4 production-readiness closure: global LCOV now meets the 80% target at 80.29%, a local full performance profile has passed, the real-store local-sensitive-data lifecycle registry is verified, backup-exclusion posture is implemented locally with Android build proof, mobile R4 no-regression release gates are wired into CI, HDR-R4-003 option 3 approved account deletion/device erasure wiring, local individual target replay for S02/S03/S06 passes, iOS backup XCTest proof source exists, approved target/profile performance replay remains pending, live CI evidence remains pending, and final release confirmation is not authorized.

The 2026-05-20 restart request is treated as a Strict Mode continuation, not a reset. No source tree move to `mobile/lib/legacy/` and no large-scale rewrite is authorized. Future work must continue one approved refactor task at a time with regression evidence and a dedicated commit.

## Estimated Timeline

Original total estimate: 4-6 weeks after R0 approval. Remaining estimate from the current continuation point: 1-2 weeks for R4 production-readiness closure, then ongoing R5 governance.

| Stage | Estimate | Work Products | Human Gate |
|---|---:|---|---|
| R0 Project Onboarding | complete | Governance charter, project assessment, hotspot inventory, decision summary | Confirmed |
| R1 Full Audit | complete | Full code audit, architecture issues, design-system issues, security issues, performance issues, technical-debt assessment, risks and mitigations | Confirmed |
| R2 Refactor Planning | complete | Overall plan, phase plans, success metrics, prioritized refactor task queue | Confirmed task queue through REFACTOR-034 |
| R3 Incremental Execution | complete for approved queue | One small behavior-preserving refactor task at a time, with regression tests | No broad rewrite or full legacy move approved |
| R4 Full Verification | 1-2 weeks remaining | Coverage closure met, local full performance profile captured, real-store lifecycle registry verified, backup-exclusion posture implemented locally, R4 no-regression gates wired into CI, approved account deletion lifecycle wiring, iOS backup XCTest proof source, local target replay, target/profile performance replay, live CI, final verification reports | Final readiness confirmation required |
| R5 Continuous Governance | Ongoing after R4 | Weekly quality reports, monthly architecture drift checks, quarterly debt cleanup | Governance cadence approval |

## Execution Rules For R3

- One module or behavior seam per task.
- Regression test first.
- No task should change behavior, route paths, API payloads, persisted data shape, or user-visible product requirements.
- Prefer low-risk seams first: widgets with tests, pure helpers, token replacement behind visual snapshots.
- Defer high-risk core flows until characterization tests exist.
- Do not delete legacy code until replacement is live and verified.
