# Stage R2 Planning Report

Version: Flutter AI Software Factory v1.0.0  
Stage: R2 - Refactor Planning  
Project: Baby Talk 2 mobile Flutter app  
Created: 2026-05-18  
Status: approved for REFACTOR-001/002 execution

## Summary

R2 planning artifacts have been generated after all red R1 decisions were confirmed. Human approval on 2026-05-18 authorizes REFACTOR-001 and REFACTOR-002 only. Later R3 implementation remains blocked until each task artifact and allowed file set is approved.

## Confirmed Inputs

| Input | Status |
|---|---|
| R0 project onboarding | Complete |
| R1 read-only audit | Complete |
| Riverpod + GoRouter canonical target | Confirmed |
| Bearer JWT authenticated client/interceptor | Confirmed |
| Mentor/AI login + consent gate | Confirmed |
| Local sensitive data governance | Confirmed |
| Strict generated-code migration to `lib/generated/` | Confirmed |

## Generated R2 Artifacts

| Artifact | Purpose |
|---|---|
| `overall-refactor-plan.md` | R2 scope, phase map, confirmed red decisions, and approval gate |
| `phase-1-plan.md` | Baselines, report-only gates, generated-code canary, characterization tests |
| `phase-2-plan.md` | Core architecture seams and high-risk migration boundaries |
| `phase-3-plan.md` | UI/design/i18n/a11y cleanup with behavior preservation |
| `phase-4-plan.md` | Verification and production-readiness report plan |
| `risks-and-mitigations.md` | R2-specific risk register and mitigations |
| `success-metrics.md` | Quality, coverage, security, import, generated, and performance gates |
| `refactor-task-index.md` | Ordered R3 task queue across Phase 1-4 |
| `refactor-task-001..005` | First detailed task artifacts using the refactor task template |

## Approval Status

1. `overall-refactor-plan.md` approved for REFACTOR-001/002 execution.
2. Phase 1 task ordering approved through REFACTOR-002.
3. REFACTOR-001 and REFACTOR-002 may proceed.
4. Later tasks remain blocked.
5. Unresolved yellow decisions remain deferred to their phase gates.

## Verification

This R2 planning pass changed governance and planning artifacts only. No files under `mobile/lib`, `mobile/test`, `mobile/integration_test`, `mobile/pubspec.yaml`, or `mobile/analysis_options.yaml` were intentionally modified.