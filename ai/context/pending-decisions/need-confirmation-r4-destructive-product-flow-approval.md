# Need Confirmation: R4 Destructive Product-Flow Approval

ID: HDR-R4-003  
Level: Red  
Stage: R4  
Status: confirmed; option 3 approved  
Created: 2026-05-20
Confirmed: 2026-05-20

## Current Task

Decide whether R4 may wire the verified local sensitive data clearance registry into real product flows such as logout, consent withdrawal, account deletion, onboarding reset, or device erasure.

## Problem

REFACTOR-020, REFACTOR-038, REFACTOR-039, and REFACTOR-040 provide a core orchestrator, real-store registry, backup-exclusion posture, and a hard gate that prevents unapproved feature-level destructive wiring. They do not approve product UX, retry behavior, support escalation, target replay, or actual destructive flow integration.

## Decision Level

Red: this controls destructive handling of child profile data, household context, practice history, mentor facts, account session material, and installation identifiers.

## Existing Evidence

- `ai/architecture/local-sensitive-data-lifecycle.md` defines trigger-specific expectations and says hard enforcement needs account delete and consent withdrawal proof.
- `ai/refactor/audit-reports/refactor-020-local-sensitive-data-clearance-orchestrator.md` approved only core-only report-producing orchestration.
- `ai/refactor/audit-reports/refactor-038-real-store-lifecycle-clearance-registry.md` maps all six targets to real delete/close primitives.
- `ai/refactor/audit-reports/refactor-039-local-sensitive-data-backup-posture.md` implements backup exclusion locally but leaves iOS target proof open.
- `ai/refactor/audit-reports/refactor-040-r4-release-gate-policy-and-replay.md` adds a hard gate preventing unapproved feature-level destructive wiring.

## Options

| Option | Meaning | Risk |
|---|---|---|
| 1. Keep destructive product-flow wiring blocked | Continue using the core registry only in tests/Staff+ verification and keep the R40 hard gate active | Lowest data-loss risk; R4 release remains blocked on lifecycle completion |
| 2. Approve consent-withdrawal wiring only | Wire a narrow confirmed consent-withdrawal flow that clears account, household, and mentor context while preserving child/practice local-only data | Medium risk; requires UX copy, retry/error behavior, support guidance, and target replay before implementation |
| 3. Approve account deletion/device erasure wiring | Wire full destructive local erasure across all six targets after explicit user confirmation | Highest risk; requires two-step UX, audit/report retention decision, retry/recovery design, iOS proof, and target replay |

## Recommendation

Choose option 1 until iOS backup runtime proof, target-platform replay, destructive UX copy, retry behavior, and support escalation are documented. The current R40 hard gate prevents accidental wiring while allowing non-destructive R4 evidence to keep improving.

## Required Confirmation

Confirm which option is approved before any production feature flow is allowed to call the real-store local sensitive data clearance registry.

## Confirmed Decision

The user approved option 3: account deletion/device erasure wiring. REFACTOR-041 is therefore allowed to wire the existing account deletion product-flow entry to the verified real-store local sensitive data clearance registry, with a second confirmation dialog and Staff+ destructive authorization evidence tied to HDR-R4-003.

This confirmation does not approve final production release. Target replay, iOS runtime proof, performance evidence, live CI, and final release approval remain separate R4 gates.