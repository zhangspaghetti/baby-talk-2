# R0 To R5 Refactor Timeline

Version: Flutter AI Software Factory v1.0.0  
Created: 2026-05-16  
Updated: 2026-05-18  
Status: active

## Current Position

R0 is complete. R1 read-only audit is complete. The red R1 decisions in `ai/context/daily-decision-summary.md` are confirmed, so R2 planning is authorized. No R3 implementation is authorized until the R2 plan and refactor task queue are approved.

## Estimated Timeline

Total estimate: 4-6 weeks after R0 approval.

| Stage | Estimate | Work Products | Human Gate |
|---|---:|---|---|
| R0 Project Onboarding | complete | Governance charter, project assessment, hotspot inventory, decision summary | Confirmed |
| R1 Full Audit | complete | Full code audit, architecture issues, design-system issues, security issues, performance issues, technical-debt assessment, risks and mitigations | Confirm red decisions before R2 |
| R2 Refactor Planning | 2-3 days | Overall plan, phase plans, success metrics, prioritized refactor task queue | Confirm priority and scope before R3 |
| R3 Incremental Execution | 4-6 weeks | One small behavior-preserving refactor task at a time, with regression tests | Confirm red decisions before core-flow changes |
| R4 Full Verification | 3-5 days | Functional, test, security, performance, compatibility, engineering verification reports | Final readiness confirmation |
| R5 Continuous Governance | Ongoing | Weekly quality reports, monthly architecture drift checks, quarterly debt cleanup | Governance cadence approval |

## Execution Rules For R3

- One module or behavior seam per task.
- Regression test first.
- No task should change behavior, route paths, API payloads, persisted data shape, or user-visible product requirements.
- Prefer low-risk seams first: widgets with tests, pure helpers, token replacement behind visual snapshots.
- Defer high-risk core flows until characterization tests exist.
- Do not delete legacy code until replacement is live and verified.
