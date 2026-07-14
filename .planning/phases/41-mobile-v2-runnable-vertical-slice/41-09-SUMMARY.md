---
phase: 41-mobile-v2-runnable-vertical-slice
plan: "09"
subsystem: mobile-session-state
tags: [flutter, riverpod, notifier, tdd, immutable-state, stale-operation-guard]
requires:
  - phase: 41-mobile-v2-runnable-vertical-slice
    plan: "08"
    provides: read-only Riverpod composition, sole engine authority, repositories, initializer, and five-channel input seams
provides:
  - One mutable RitualRoomSessionNotifier for Ritual Room product-session orchestration
  - Whole-snapshot immutable UI state variants for idle, loading, ready, submitting, recoverable failure, and load failure
  - Epoch and disposal guards preventing stale asynchronous state replacement
  - Unified submit path for all five InputEvent variants with authoritative conflict snapshot recovery
affects: [41-10, 41-11, ritual-room-ui, interaction-session]
tech-stack:
  added: []
  patterns: [single mutable Notifier authority, whole-snapshot replacement, operation epoch invalidation, non-retaining raw input]
key-files:
  created:
    - mobile_v2/lib/app/providers/ritual_room_session_provider.dart
    - mobile_v2/lib/features/ritual_room/presentation/state/ritual_room_ui_state.dart
  modified:
    - mobile_v2/test/app/providers/ritual_room_session_provider_test.dart
    - mobile_v2/test/features/ritual_room/presentation/state/ritual_room_ui_state_test.dart
key-decisions:
  - "Use one operation epoch across room opens and submissions so a newer operation or disposal invalidates every older asynchronous completion."
  - "Keep RitualRoomUiState limited to complete RitualRoomContent and ProductSnapshot references plus transient problem or cause data."
  - "Treat Applied, DuplicateIgnored, and conflict latestSnapshot results as whole authoritative snapshot replacements while preserving the last usable snapshot for other failures."
patterns-established:
  - "Ritual Room presentation state never duplicates revision, context, memory, strategy, utterance, schema version, or raw InputEvent data."
  - "All reaction, voice, free-text, future-signal, and strategy-preference inputs enter one submit(InputEvent) command."
requirements-completed: [R060, R067]
duration: 1h 2m
completed: 2026-06-20
---

# Phase 41 Plan 09: Ritual Room Session Notifier Summary

**One Riverpod Notifier now owns transient Ritual Room orchestration while preserving complete engine snapshots, all five input channels, and stale-operation safety.**

## Performance

- **Duration:** 1h 2m
- **Started:** 2026-06-20T17:09:03Z
- **Completed:** 2026-06-20T18:10:50Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added the sole mutable `NotifierProvider<RitualRoomSessionNotifier, RitualRoomUiState>` under `mobile_v2/lib/app/providers`.
- Added six explicit immutable UI-state variants carrying only whole room/snapshot references and transient failure data.
- Implemented content load followed by one internal session initialization, same-room deduplication, current-revision submission, whole-snapshot replacement, and conflict recovery.
- Prevented stale room loads, stale submissions, and disposed operations from updating state through a shared operation epoch.
- Proved all five typed input variants use the same non-retaining `submit(InputEvent)` command.

## TDD Execution

### RED

- **Commit:** `c604914`
- Preserved and committed the stalled executor's existing lifecycle and state-shape tests without deleting or recreating them.
- Direct Flutter execution exited 1 because `ritual_room_session_provider.dart`, `ritual_room_ui_state.dart`, `ritualRoomSessionProvider`, and `RitualRoomUiState` symbols were missing.

### GREEN

- **Commit:** `78ec082`
- Implemented the minimal state union and sole Notifier required by the tests.
- Focused session/state tests passed 14/14; the complete package passed 100/100.

### REFACTOR

- No separate refactor commit was needed. The implementation remained limited to the two planned production files, and package formatting changed zero files after GREEN.

## Task Commits

1. **Task 1 RED: Specify whole-snapshot state and sole-Notifier lifecycle** — `c604914` (test)
2. **Task 2 GREEN/REFACTOR: Implement one whole-snapshot session Notifier** — `78ec082` (feat)

## Files Created/Modified

- `mobile_v2/lib/app/providers/ritual_room_session_provider.dart` — Sole mutable session Notifier, provider declaration, lifecycle commands, result handling, and stale-operation guards.
- `mobile_v2/lib/features/ritual_room/presentation/state/ritual_room_ui_state.dart` — Whole-room/whole-snapshot immutable state union and transient problem model.
- `mobile_v2/test/app/providers/ritual_room_session_provider_test.dart` — ProviderContainer lifecycle, conflict, failure, stale/disposal, five-channel, and source-count coverage.
- `mobile_v2/test/features/ritual_room/presentation/state/ritual_room_ui_state_test.dart` — State variant, complete snapshot, and forbidden-field source contracts.

## Decisions Made

- A single monotonically increasing epoch invalidates both open and submit operations; no parallel cancellation/controller authority was introduced.
- Same-room opens return once a non-idle, non-load-failure room operation/state exists, preventing duplicate initialization.
- Recoverable failures retain a complete usable snapshot. Conflict responses prefer `latestSnapshot`; failures without one preserve the prior snapshot.
- Raw input is passed directly to the repository call and is never stored in Notifier fields or UI state.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Removed an invalid null-aware test access**
- **Found during:** Task 2 full-package analyzer verification
- **Issue:** The preserved test cast state to `RitualRoomReady`, whose snapshot is non-null, but then used `snapshot?.ritualRoomId`; analyzer reported `invalid_null_aware_operator`.
- **Fix:** Replaced the null-aware access with direct `snapshot.ritualRoomId` access.
- **Files modified:** `mobile_v2/test/app/providers/ritual_room_session_provider_test.dart`
- **Verification:** `flutter analyze --no-pub` reports no issues; full tests pass 100/100.
- **Committed in:** `78ec082`

---

**Total deviations:** 1 auto-fixed blocking analyzer issue.
**Impact on plan:** Test semantics are unchanged; the correction only aligns the assertion with the non-null state contract.

## Issues Encountered

- Git metadata writes required managed approval for `.git/index.lock`; both commits used normal hooks and no `--no-verify` bypass.
- The semantic verifier initially ran from `mobile_v2` and correctly failed closed because it expects the repository root. Re-running its canonical command from the repository root passed with 48 runtime files and zero violations.

## Verification

- Expected RED proof — pass; direct Flutter output named both missing production files and missing session/state symbols.
- Focused session/state suite — pass, 14/14.
- `C:\software\flutter\bin\flutter.bat test --no-pub` — pass, 100/100.
- `dart format --output=none --set-exit-if-changed .` — pass, 73 files and zero changes.
- `flutter analyze --no-pub` — pass, no issues.
- Exactly-one `NotifierProvider` source gate — pass, count 1.
- Forbidden ProductSnapshot-fragment and raw-InputEvent field scan — pass.
- `dart run tool/verify_mobile_v2_semantic_firewall.dart` — pass, 48 runtime files and zero violations.
- `dart run tool/verify_activation_governor_contract.dart` — pass, 5 contract cases and zero violations.
- TDD ancestry — pass; RED `c604914` precedes GREEN `78ec082`.

## Known Stubs

None.

## Threat Model Results

- **T-41-09-01 Tampering:** Applied, duplicate, and conflict outcomes replace the complete snapshot; no field-level product mutation exists.
- **T-41-09-02 Information Disclosure:** UI state and Notifier fields retain no raw `InputEvent`.
- **T-41-09-03 Denial of Service:** Operation epochs and disposal invalidation reject stale asynchronous completion.
- **T-41-09-04 Elevation of Privilege:** Source verification confirms exactly one mutable `NotifierProvider` and no parallel controller or ViewModel.

## User Setup Required

None.

## Next Phase Readiness

- Plan 41-10 can project the session state into the approved reaction-only Ritual Room UI while retaining all five programmatic input channels.
- No blockers remain.

## Self-Check: PASSED

- All four planned production/test artifacts and this summary exist on disk.
- RED `c604914` and GREEN `78ec082` exist in the required order.
- All task acceptance criteria and plan-level verification gates passed.

---
*Phase: 41-mobile-v2-runnable-vertical-slice*
*Completed: 2026-06-20*
