---
phase: 41-mobile-v2-runnable-vertical-slice
plan: "12"
subsystem: mobile-reaction-reconciliation
tags: [flutter, riverpod, idempotency, single-flight, accessibility, tdd]
requires:
  - phase: 41-mobile-v2-runnable-vertical-slice
    plans: ["09", "10", "11"]
    provides: sole session Notifier, projection widgets, and runnable app shell
provides:
  - Single-flight reaction admission before InputEvent and event-ID allocation
  - Explicit post-dispatch unknown-outcome classification and exact immutable command replay
  - Command-free submitting and reconciliation UI states with locked reaction controls
  - Live lock propagation into already-open additional-reaction modal routes
  - Real-engine commit-succeeded/response-lost duplicate reconciliation proof
affects: [42-mobile-v2-low-pressure-interaction-schematic, mobile-v2-runtime]
tech-stack:
  added: []
  patterns: [notifier-private idempotency envelope, explicit unknown-outcome state, live modal control projection]
key-files:
  created:
    - mobile_v2/lib/features/ritual_room/domain/repositories/interaction_outcome_unknown_exception.dart
  modified:
    - mobile_v2/lib/app/providers/ritual_room_session_provider.dart
    - mobile_v2/lib/features/ritual_room/presentation/state/ritual_room_ui_state.dart
    - mobile_v2/lib/app/baby_talk_app.dart
    - mobile_v2/lib/features/ritual_room/presentation/screens/ritual_room_screen.dart
    - mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_context_input_tray.dart
    - mobile_v2/test/app/providers/ritual_room_session_provider_test.dart
    - mobile_v2/test/features/ritual_room/presentation/state/ritual_room_ui_state_test.dart
    - mobile_v2/test/features/ritual_room/presentation/screens/ritual_room_screen_test.dart
    - mobile_v2/test/features/ritual_room/presentation/ritual_room_accessibility_test.dart
key-decisions:
  - "Mint reaction InputEvents only inside RitualRoomSessionNotifier after the single-flight guard accepts the intent."
  - "Reserve same-event replay for explicit post-dispatch unknown outcomes; every authoritative result and non-unknown exception clears retry capability."
  - "Keep the retained InputEvent, interactionId, and expectedRevision private while projecting only selected reaction and retrying status to UI."
  - "Use a tray-owned live projection so an already-open modal route locks immediately at dispatch time and updates visually after the parent frame."
patterns-established:
  - "Unknown-outcome reconciliation replays the same immutable command without regeneration or revision rebasing."
  - "Snapshot-advancing controls lock independently from playback and quiet exit."
requirements-completed: [R060, R067]
duration: 13min
completed: 2026-06-21
---

# Phase 41 Plan 12: Reaction Reconciliation Gap Closure Summary

**Notifier-owned single-flight admission and exact unknown-outcome replay now prevent duplicate reaction events while preserving authoritative engine snapshots and command-blind UI state.**

## Performance

- **Duration:** 13 min
- **Started:** 2026-06-21T06:35:55Z
- **Completed:** 2026-06-21T06:48:07Z
- **Tasks:** 3
- **Files modified:** 10

## Accomplishments

- Added a typed post-dispatch unknown-outcome exception and one notifier-private immutable command envelope.
- Guarded reaction intent before event creation, making repeated submitting/unknown/retrying taps complete no-ops with no queued work.
- Replayed the same InputEvent object, event ID, interaction ID, and old expected revision against the real engine; receipt-before-revision returned `duplicate_ignored` and revision 1.
- Cleared retry capability for applied, duplicate, every rejected result, and every non-unknown exception; later deliberate reactions receive new event IDs.
- Locked inline reactions, the more-reactions launcher, and already-open modal choices while retaining selected semantics, current utterance, playback, and quiet exit.
- Proved room switch, explicit reload, and provider disposal abandon local retry without replacement submission.

## TDD Execution

### RED

- **Commit:** `1752ed7`
- Added provider, state, screen, modal-lifecycle, and accessibility regressions before production changes.
- Both RED commands failed non-zero on missing reconciliation symbols including `RitualRoomUnknownOutcome`, `selectedReaction`, and `onRetryPendingEvent`.

### GREEN

- **Commit:** `a12535c`
- Added explicit unknown-outcome classification, private command retention, single-flight reaction admission, exact replay, and command-free public reconciliation states.
- Focused provider/state suite passed 19 tests.

### GREEN/REFACTOR

- **Commit:** `97ce6d8`
- Made `BabyTalkApp` intent-only, added unknown-outcome UI, and converted the reaction tray to a lifecycle-safe live modal projection.
- Focused closure suite passed 38 tests; full package passed 122 tests.

## Task Commits

1. **Task 1 RED: Specify single-flight admission, exact reconciliation, and locked UI behavior** — `1752ed7` (test)
2. **Task 2 GREEN: Implement explicit unknown-outcome classification and notifier-private command replay** — `a12535c` (feat)
3. **Task 3 GREEN/REFACTOR: Wire intent-only app callbacks, lock reaction controls, and run closure gates** — `97ce6d8` (feat)

## Files Created/Modified

- `mobile_v2/lib/features/ritual_room/domain/repositories/interaction_outcome_unknown_exception.dart` — Explicit post-dispatch uncertainty reasons and exception.
- `mobile_v2/lib/app/providers/ritual_room_session_provider.dart` — Admission guard, private command envelope, authoritative clearing, retry, reload, and lifecycle invalidation.
- `mobile_v2/lib/features/ritual_room/presentation/state/ritual_room_ui_state.dart` — Selected reaction on submitting and command-free unknown-outcome state.
- `mobile_v2/lib/app/baby_talk_app.dart` — Reaction/retry/reload intent wiring without InputEvent or factory access.
- `mobile_v2/lib/features/ritual_room/presentation/screens/ritual_room_screen.dart` — Locked reconciliation projection, exact unknown copy, and accessible retry action.
- `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_context_input_tray.dart` — Stateful live projection shared with already-open modal choices.
- `mobile_v2/test/app/providers/ritual_room_session_provider_test.dart` — Controlled fast-tap, real-engine lost-response, clearing, repeated retry, and lifecycle regressions.
- `mobile_v2/test/features/ritual_room/presentation/state/ritual_room_ui_state_test.dart` — Public state ownership and command-blind source firewall.
- `mobile_v2/test/features/ritual_room/presentation/screens/ritual_room_screen_test.dart` — Intent ownership, locked controls, selected semantics, and modal listener lifecycle.
- `mobile_v2/test/features/ritual_room/presentation/ritual_room_accessibility_test.dart` — Unknown-outcome semantic reachability and 48x48 retry target.

## Decisions Made

- Kept `submit(InputEvent)` as the existing five-channel programmatic seam while making `submitReaction(String)` the only UI reaction entry.
- Retained at most one command with exactly InputEvent, interactionId, expectedRevision, and optional selected reaction; no public getter was added.
- Published modal visual changes after the parent frame to respect Flutter build rules, while mutating the live projection immediately so stale callbacks cannot emit or dismiss the sheet.
- Left `InteractionEngine` unchanged and retained its receipt-before-revision ordering as the reconciliation authority.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test Bug] Corrected exact-replay call indexing**
- **Found during:** Task 2 GREEN
- **Issue:** The RED test correctly recorded two repository calls but used `List.single` when asserting the original expected revision.
- **Fix:** Asserted against `calls.first` while preserving all exact-envelope checks.
- **Files modified:** `mobile_v2/test/app/providers/ritual_room_session_provider_test.dart`
- **Verification:** Focused provider/state suite passed 19/19.
- **Committed in:** `a12535c`

**2. [Rule 1 - Lifecycle Bug] Deferred modal listener notification until after parent build**
- **Found during:** Task 3 GREEN/REFACTOR
- **Issue:** Synchronously notifying the modal route's `ValueListenableBuilder` from `didUpdateWidget` triggered Flutter's `markNeedsBuild during build` assertion.
- **Fix:** Mutated the current projection synchronously for tap-time safety, then published a new projection after the frame for visual/semantic rebuilding; sheet close now rebuilds the launcher and deferred disposal waits for listener detachment.
- **Files modified:** `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_context_input_tray.dart`, `mobile_v2/test/features/ritual_room/presentation/screens/ritual_room_screen_test.dart`
- **Verification:** Focused already-open-sheet regression and full 122-test suite passed with no Flutter exception.
- **Committed in:** `97ce6d8`

**3. [Rule 3 - Verification Command] Ran semantic verifiers from repository root**
- **Found during:** Task 3 closure gates
- **Issue:** The plan's combined PowerShell command retained `mobile_v2` as cwd for `../tool` scripts, causing the semantic verifier to infer a nested project root and fail closed on `mobile_v2/mobile_v2/lib`.
- **Fix:** Ran the unchanged canonical verifier scripts from the repository root, matching prior Phase 41 execution evidence.
- **Files modified:** None.
- **Verification:** Semantic firewall scanned 60 runtime files with zero violations; Activation Governor evaluated 5 cases with zero violations.
- **Committed in:** Not applicable — execution-only adjustment.

---

**Total deviations:** 3 auto-fixed (2 correctness/test-lifecycle bugs, 1 blocking verification invocation).
**Impact on plan:** No architecture or product scope changed. The six deferred verification warnings remain untouched and unclaimed.

## Issues Encountered

- Flutter's separate modal route cannot be synchronously notified during the parent widget's build. Immediate guard state and post-frame visual publication preserve both safety and framework lifecycle correctness.
- The verifier scripts are repository-root sensitive; root-level invocation produced the intended canonical result without changing verifier code.

## Verification

- RED open-sheet command — expected non-zero; missing reconciliation symbols identified.
- RED combined reconciliation command — expected non-zero; missing reconciliation symbols identified.
- Focused provider/state suite — pass, 19 tests.
- Focused notifier/state/screen/accessibility/engine suite — pass, 38 tests.
- Already-open reaction sheet lifecycle test — pass.
- `dart format --output=none --set-exit-if-changed lib test` — pass, 89 files and zero changes.
- `flutter analyze --no-pub` — pass, no issues.
- `flutter test --no-pub` — pass, 122 tests.
- `dart run tool/verify_mobile_v2_semantic_firewall.dart` — pass, 60 runtime files and zero violations.
- `dart run tool/verify_activation_governor_contract.dart` — pass, 5 contract cases and zero violations.
- App/UI command-blind source scans — pass.
- Receipt-before-revision source ordering — pass.
- TDD ancestry — RED `1752ed7` precedes GREEN `a12535c` and UI GREEN/REFACTOR `97ce6d8`.

## Known Stubs

- `BabyTalkApp.onListen` remains intentionally callback-only/no-op from Plan 41-11; real audio playback is outside Phase 41 and unchanged by this gap closure.
- Voice, free-text, future-signal, and strategy controls remain intentionally hidden while their engine paths stay executable.

## Threat Model Results

- **T-41-12-01 Tampering:** The immutable private command is identity/equality tested across all envelope fields.
- **T-41-12-02 Replay:** Only explicit unknown outcomes retain exact replay; real-engine retry resolves through duplicate receipt lookup.
- **T-41-12-03 Denial of Service:** Fast reaction and retry taps allocate one event and make one call per admitted attempt.
- **T-41-12-04 Information Disclosure:** BabyTalkApp, RitualRoomScreen, and public UI state expose no InputEvent or command identity.

## Threat Flags

None - no unplanned endpoint, auth path, persistence boundary, file-access behavior, or schema change was introduced.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 41's two blocking reaction-lifecycle gaps are closed with executable evidence.
- Phase 42 can add progressive-disclosure input controls without changing engine idempotency, session authority, or reconciliation contracts.
- The six non-blocking Phase 41 verification warnings remain explicitly deferred.

## Self-Check: PASSED

- All ten planned production/test artifacts exist.
- Task commits `1752ed7`, `a12535c`, and `97ce6d8` exist in order.
- Every task acceptance criterion and plan-level automated gate has fresh evidence.

---
*Phase: 41-mobile-v2-runnable-vertical-slice*
*Completed: 2026-06-21*
