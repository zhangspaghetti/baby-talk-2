# Need Confirmation: R4 Next Production-Readiness Track

ID: HDR-R4-002  
Level: Red  
Stage: R4  
Created: 2026-05-20  
Status: confirmed for coverage-first track

## Current Task

Select the next approved R4 production-readiness track for the Flutter mobile rescue continuation.

## Problem Description

The approved refactor task queue is complete through REFACTOR-034, but production readiness is still blocked. Continuing without an explicit next-track decision would risk scope drift, behavior changes, or untraceable governance work.

## Decision Level

Red: this controls R4 scope, production-readiness criteria, and whether privacy-sensitive destructive lifecycle work or release verification can proceed.

## Existing Information

- `ai/context/daily-decision-summary.md` records REFACTOR-001 through REFACTOR-034 as complete.
- `ai/context/refactor/refactor-tasks/refactor-task-index.md` says the next task must be selected by a human and now contains draft REFACTOR-035 as the recommended coverage slice.
- `ai/context/refactor/migration-plans/r0-to-r5-timeline.md` records the remaining R4 blockers.
- `ai/context/pending-decisions/need-confirmation-r4-local-sensitive-data-clearance-orchestrator.md` confirms only core-only orchestrator implementation; destructive flow wiring remains unapproved.

## Options

1. Continue global coverage work toward the 80% target.
2. Approve a documented coverage exception and focus on other R4 gates.
3. Design and approve one real destructive lifecycle wiring path with UX confirmation, retry behavior, and target-platform tests.
4. Create performance benchmark gates and baseline reports.
5. Replay integration and verification evidence on target CI/platforms.
6. Plan a narrowly scoped follow-up migration task.

## Recommendation

Choose option 1 first unless there is a business reason to accept a coverage exception. Coverage work is the least product-behavior-invasive R4 blocker and preserves the current incremental, CI-green trajectory. After coverage reaches 80% or a formal exception is approved, proceed to performance benchmark and target-platform replay before any destructive lifecycle wiring.

## Risk Assessment

| Option | Risk |
|---|---|
| Continue coverage | Low behavior risk; may take multiple focused slices and exposes existing untested seams |
| Coverage exception | Faster, but weakens the R4 production-readiness claim unless explicitly bounded |
| Destructive lifecycle wiring | Highest privacy and data-loss risk; requires UX, support, retry, and platform proof |
| Performance benchmark | Low behavior risk, but may surface separate optimization tasks |
| Target CI/platform replay | Low code risk, but may reveal environment or emulator instability |
| Follow-up migration | Depends on scope; must stay below the one-module, behavior-preserving threshold |

## Required Confirmation

Human selected the coverage-first track on 2026-05-20 by requesting: "continue coverage to 80%, starting from REFACTOR-035 widget regression tests." REFACTOR-035 is complete. A separate confirmation is still required before switching away from coverage-first work to destructive lifecycle wiring, release readiness, or coverage exception approval.