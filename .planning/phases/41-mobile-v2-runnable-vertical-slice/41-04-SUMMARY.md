---
phase: 41-mobile-v2-runnable-vertical-slice
plan: "04"
subsystem: mobile-domain
tags: [flutter, dart, tdd, interaction-engine, idempotency, atomicity, replay]
requires:
  - phase: 41-mobile-v2-runnable-vertical-slice
    plan: "02"
    provides: deterministic Normalize, Accumulate, Strategy, and Utterance modules
  - phase: 41-mobile-v2-runnable-vertical-slice
    plan: "03"
    provides: fingerprints, receipts, replay evidence, runtime aggregate, and exclusive store
provides:
  - Sole InteractionEngine lifecycle and consistency authority
  - Snapshot/advance public port without initialization
  - Literal duplicate, event-ID, and revision conflict precedence
  - One-clock-read atomic snapshot, receipt, and transition commit
  - Direct replay proof without module, clock, or ID re-execution
affects: [41-07, 41-08, interaction-api, interaction-session-controller]
tech-stack:
  added: []
  patterns: [single authority shell, serialized aggregate commit, duplicate-before-revision, evidence-only replay]
key-files:
  created:
    - mobile_v2/lib/features/ritual_room/domain/engine/interaction_engine.dart
    - mobile_v2/lib/features/ritual_room/domain/engine/interaction_engine_port.dart
    - mobile_v2/test/features/ritual_room/domain/engine/interaction_engine_test.dart
    - mobile_v2/test/features/ritual_room/domain/engine/interaction_engine_atomicity_test.dart
    - mobile_v2/test/features/ritual_room/domain/engine/interaction_engine_replay_test.dart
  modified: []
key-decisions:
  - "Keep initialize on the internal InteractionSessionInitializer seam while the public InteractionEnginePort exposes only getSnapshot and advance."
  - "Hold the per-interaction exclusive operation across the complete pipeline, then commit one prepared immutable aggregate."
  - "Validate schema and input before pipeline execution while preserving receipt checks before expected-revision conflicts."
patterns-established:
  - "InteractionEngine alone creates sessions, computes acceptance, advances revision, reads transition time, and writes runtime truth/evidence."
  - "Replay consumes TransitionRecord outputs from the recorded revision-zero snapshot and never invokes live dependencies."
requirements-completed: [R060, R067]
duration: 10 min
completed: 2026-06-20
---

# Phase 41 Plan 04: Interaction Engine Authority Summary

**Pure-Dart InteractionEngine authority with literal conflict ordering, serialized one-clock atomic commits, raw non-retention, and dependency-free direct replay**

## Performance

- **Duration:** 10 min
- **Started:** 2026-06-20T10:13:00Z
- **Completed:** 2026-06-20T10:23:00Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added the only lifecycle and consistency authority over initialization, snapshot reads, idempotency, optimistic concurrency, pipeline execution, revision advancement, receipts, transition evidence, and aggregate commits.
- Kept initialization out of `InteractionEnginePort`; unknown snapshot reads remain side-effect free and never create sessions.
- Proved duplicate-before-revision behavior, including a delayed duplicate retry returning the latest snapshot after later revisions.
- Proved pipeline failures and competing same-revision requests cannot leak partial state; exactly one concurrent request commits.
- Proved all five input channels execute through the full pipeline without retaining raw voice/free-text sentinels or diagnostic child semantics.
- Proved replay reproduces complete product semantics from recorded outputs with zero replay-time module, clock, or ID calls.

## TDD Cycle

### RED

- **Commit:** `83a4f5c`
- Added three authority-focused suites covering lifecycle boundaries, all rejection codes, literal conflict precedence, one-clock atomicity, failure isolation, concurrency, privacy, mixed-channel evolution, and direct replay.
- The required RED command exited nonzero because `InteractionEngine` and `InteractionEnginePort` did not exist.

### GREEN

- **Commit:** `af46a4e`
- Implemented `InteractionEnginePort` with `getSnapshot` and `advance` only.
- Implemented `InteractionEngine` as both the public port and internal session initializer.
- Prepared the next snapshot, receipt state, and transition journal before one store commit and one successful-transition clock read.
- All focused engine/runtime tests and package-wide gates passed.

### REFACTOR

- No separate refactor commit was needed. The minimal authority shell remained clear after formatting, analysis, source-boundary scans, and full package verification.

## Task Commits

1. **Task 1 RED: Specify sole authority, conflict order, atomicity, and replay integration** - `83a4f5c` (test)
2. **Task 2 GREEN/REFACTOR: Implement InteractionEngine as the only authority** - `af46a4e` (feat)

## Files Created

- `mobile_v2/lib/features/ritual_room/domain/engine/interaction_engine_port.dart` - Replaceable snapshot/advance boundary with no initialization method.
- `mobile_v2/lib/features/ritual_room/domain/engine/interaction_engine.dart` - Sole lifecycle, conflict, pipeline, timestamp, and aggregate-commit authority.
- `mobile_v2/test/features/ritual_room/domain/engine/interaction_engine_test.dart` - Lifecycle, conflict precedence, five-channel evolution, invalid/schema failures, and raw non-retention.
- `mobile_v2/test/features/ritual_room/domain/engine/interaction_engine_atomicity_test.dart` - Before/after counters for success, rejection, pipeline failure, and concurrent same-revision requests.
- `mobile_v2/test/features/ritual_room/domain/engine/interaction_engine_replay_test.dart` - Complete product-semantic replay equality and zero live-dependency calls.

## Decisions Made

- `getSnapshot` uses the same per-interaction exclusive store boundary as advance, but never commits or initializes.
- Unsupported schema and structurally invalid domain events fail before module execution; known event receipts still determine duplicate/event-ID outcomes before expected revision is checked.
- The transition timestamp is obtained only after all four module outputs are ready and is shared by the snapshot metadata and transition record.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test Bug] Narrowed the privacy vocabulary assertion**
- **Found during:** Task 2 GREEN verification
- **Issue:** The initial regex treated the approved term `joinability` as if it contained the forbidden standalone child-evaluation term `ability`.
- **Fix:** Changed the assertion to match `ability` and `trait` only as whole words.
- **Files modified:** `mobile_v2/test/features/ritual_room/domain/engine/interaction_engine_test.dart`
- **Verification:** Focused 34-test engine/runtime suite and full 65-test package suite passed.
- **Committed in:** `af46a4e`

---

**Total deviations:** 1 auto-fixed bug.
**Impact on plan:** The correction removed a false positive without weakening the non-diagnostic privacy contract.

## Issues Encountered

- The sandboxed Flutter RED run timed out because the SDK cache was outside the writable workspace. The direct Flutter SDK command completed with approved cache access and captured the required missing-symbol RED evidence.

## Verification

- Expected RED proof - pass; Flutter exited nonzero and named missing `InteractionEngine` and `InteractionEnginePort`.
- Focused domain engine/runtime suite - pass, 34/34 tests.
- Package format gate - pass, 49 files unchanged.
- `flutter analyze --no-pub` - pass, no issues.
- `flutter test --no-pub` - pass, 65/65 tests.
- `dart run tool/verify_mobile_v2_semantic_firewall.dart` - pass, 0 violations.
- `dart run tool/verify_activation_governor_contract.dart` - pass, 0 violations.
- Public-port initializer scan - pass.
- Domain Flutter/Riverpod import scan - pass.
- Authority stub and decision-path scans - pass.
- TDD ancestry - `83a4f5c` precedes `af46a4e`; both production authority files were absent before RED.

## Known Stubs

None.

## Threat Flags

None - event spoofing, concurrent tampering, failed-pipeline disclosure, and module/journal authority threats are covered by the plan threat register and passing mitigations.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 41-07 can place the API-shaped adapter over `InteractionEnginePort` without receiving lifecycle authority.
- Plan 41-08 can initialize through the internal session seam and render only returned product snapshots.
- No blocker remains.

## Self-Check: PASSED

- All five created plan files exist.
- RED commit `83a4f5c` and GREEN commit `af46a4e` exist in order.
- Focused, package-level, semantic, analyzer, privacy, atomicity, and replay gates pass.

---
*Phase: 41-mobile-v2-runnable-vertical-slice*
*Completed: 2026-06-20*
