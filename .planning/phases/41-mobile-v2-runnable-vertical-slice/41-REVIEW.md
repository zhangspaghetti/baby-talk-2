---
phase: 41-mobile-v2-runnable-vertical-slice
reviewed: 2026-06-21T09:19:19Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - mobile_v2/lib/app/baby_talk_app.dart
  - mobile_v2/lib/app/providers/ritual_room_session_provider.dart
  - mobile_v2/lib/features/ritual_room/domain/repositories/interaction_outcome_unknown_exception.dart
  - mobile_v2/lib/features/ritual_room/presentation/screens/ritual_room_screen.dart
  - mobile_v2/lib/features/ritual_room/presentation/state/ritual_room_ui_state.dart
  - mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_context_input_tray.dart
  - mobile_v2/test/app/providers/ritual_room_session_provider_test.dart
  - mobile_v2/test/features/ritual_room/presentation/ritual_room_accessibility_test.dart
  - mobile_v2/test/features/ritual_room/presentation/screens/ritual_room_screen_test.dart
  - mobile_v2/test/features/ritual_room/presentation/state/ritual_room_ui_state_test.dart
findings:
  critical: 0
  warning: 8
  info: 0
  total: 8
status: issues_found
---

# Phase 41: Code Review Report

**Reviewed:** 2026-06-21T09:19:19Z
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Plan 41-12 genuinely closes both prior reaction-lifecycle criticals. Reaction admission now occurs before event allocation, one notifier-private command enforces single flight, explicit unknown outcomes retain that exact command, and retry replays the same `InputEvent`, event ID, interaction ID, and expected revision. Submitting, unknown-outcome, and retrying projections also lock reaction controls, including an already-open additional-choice sheet.

No critical issue remains. All six prior warnings are still present. Two new presentation warnings were found: a selected reaction from the additional-choice sheet becomes invisible after the sheet closes, and the new reconciliation UI copy bypasses localization. Independent supplied verification reports formatter and analyzer clean, 122 tests passing, both semantic verifiers passing, and all five Plan 41-12 key links verified; those checks do not invalidate the source-level findings below.

## Narrative Findings (AI reviewer)

## Resolved Prior Critical Findings

### CR-01: Repeated taps no longer discard a successful response

**Status:** RESOLVED
**Evidence:** `mobile_v2/lib/app/providers/ritual_room_session_provider.dart:76-92,135-151,210-218`; `mobile_v2/lib/features/ritual_room/presentation/screens/ritual_room_screen.dart:137-148,208-216`

`RitualRoomSubmitting` is no longer a usable submission state, `_pendingCommand` blocks repeated admission before the input factory is called, and the UI disables all reaction-producing controls. Rapid taps therefore allocate and dispatch only one command.

### CR-02: Unknown-outcome retry now reuses the original idempotency command

**Status:** RESOLVED
**Evidence:** `mobile_v2/lib/app/providers/ritual_room_session_provider.dart:111-132,154-205,228-240`

Only `InteractionOutcomeUnknownException` preserves `_pendingCommand`. `retryPendingEvent` replays the retained immutable envelope without regenerating or rebasing it, while every authoritative result and non-unknown exception clears retry capability.

## Warnings

### WR-01: Future-signal values are fingerprinted but ignored by normalization

**Classification:** WARNING
**File:** `mobile_v2/lib/features/ritual_room/domain/engine/normalize_engine.dart:24,93-107`

**Issue:** `FutureSignalPayload` contains both `signal` and `value`, but normalization passes only `signal`. Opposite values such as `shared_action=available` and `shared_action=absent` therefore produce identical semantic output despite having different accepted event content and fingerprints.

**Fix:** Pass both fields into `_fromFutureSignal`, explicitly map supported signal/value combinations, and reject or conservatively normalize unsupported combinations. Add opposite-value tests.

### WR-02: “More choices” copy still bypasses the content boundary

**Classification:** WARNING
**File:** `mobile_v2/lib/features/ritual_room/presentation/screens/ritual_room_screen.dart:208-216`

**Issue:** `更多情况` remains hardcoded in the screen. It cannot be substituted through the fixture/API/repository/domain path, so room-specific content and payload-substitution tests cannot control all visible ritual copy.

**Fix:** Add a `moreChoicesLabel` field through the fixture, DTO, mapper, and `RitualRoomContent`, then pass `room.moreChoicesLabel` to the tray.

### WR-03: Snapshot decoding still accepts semantically invalid numeric values

**Classification:** WARNING
**File:** `mobile_v2/lib/features/ritual_room/data/dto/interaction_snapshot_response.dart:78-86,117-124,155-164,271-277`

**Issue:** Confidence and context-stability values are checked only for finiteness, and pressure is checked only for non-negativity. Values such as confidence `-4`, stability `2`, or an unbounded pressure level enter domain truth. `NormalizedInput`, `ContextMemory`, and `StrategyDecision` also enforce no range invariants.

**Fix:** Validate confidence and stability as `0..1`, define and enforce the pressure range, and enforce the same invariants in domain constructors or factories.

### WR-04: Capability sets remain externally mutable

**Classification:** WARNING
**File:** `mobile_v2/lib/features/ritual_room/presentation/capability/interaction_capability_mask.dart:11-16,29-34`

**Issue:** Both constructors retain caller-provided `Set` instances directly. Mutating the original set after construction silently changes engine declarations or visible presentation policy, violating the immutable-boundary standard.

**Fix:** Defensively copy with `Set.unmodifiable`, or use an immutable enum bitmask/value object. Add a mutation-resistance test.

### WR-05: Room bootstrap still reads stable content twice

**Classification:** WARNING
**File:** `mobile_v2/lib/app/providers/ritual_room_session_provider.dart:45-55`

**Related:** `mobile_v2/lib/features/ritual_room/domain/runtime/ritual_room_interaction_seed_source.dart:16-19`; `mobile_v2/lib/app/providers/interaction_engine_providers.dart:38-41,64-84`

**Issue:** `openRoom` loads `RitualRoomContent`, then the production initializer reaches the same repository again through `RitualRoomInteractionSeedSource`. A mutable or remote source can pair room metadata from one version with a bootstrap snapshot from another.

**Fix:** Initialize from the already loaded immutable room content, or introduce a request-scoped content snapshot/cache shared by both consumers. Add a production-provider-graph test with different consecutive repository responses.

### WR-06: Broad engine catches still erase diagnostics and invariant failures

**Classification:** WARNING
**File:** `mobile_v2/lib/features/ritual_room/domain/engine/interaction_engine.dart:120-188`

**Issue:** `on Object` converts every exception and `Error`, including programming or invariant failures during receipt, journal, and commit construction, into `pipeline_failed` without preserving safe diagnostic context. Defects become indistinguishable from expected pipeline failures.

**Fix:** Catch documented pipeline exception types, report sanitized operation and correlation details through a diagnostics boundary, and allow unexpected `Error` or invariant failures to surface in development and tests.

### WR-07: Additional-choice selections disappear during reconciliation

**Classification:** WARNING
**File:** `mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_context_input_tray.dart:55,74-80,100-116,263-270`

**Related:** `mobile_v2/lib/features/ritual_room/presentation/screens/ritual_room_screen.dart:144-148,208-216`

**Issue:** The selected ID is retained, but only the first two inline choices expose `Semantics.selected`. Choosing an item at index 2 or later closes the sheet immediately; during submitting or unknown-outcome states, the disabled `更多情况` launcher exposes neither the selected label nor selected semantics. The user and screen reader cannot tell which additional reaction is pending or being retried.

**Fix:** Resolve the selected ID to its label and project it on the launcher or a persistent selected-reaction status with `selected: true`. Add submitting, unknown-outcome, and retrying tests using a choice from `choices.skip(2)`.

### WR-08: New reconciliation copy bypasses localization

**Classification:** WARNING
**File:** `mobile_v2/lib/features/ritual_room/presentation/screens/ritual_room_screen.dart:168-192`

**Issue:** The newly added unknown-outcome message and retry label are embedded Chinese strings in the widget. This violates the mandatory localization standard and prevents locale substitution or translation testing.

**Fix:** Move reconciliation message and retry-action text into Flutter localization resources and reference localized values from the screen. Add a locale-substitution widget test.

---

_Reviewed: 2026-06-21T09:19:19Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
