---
phase: 41-mobile-v2-runnable-vertical-slice
reviewed: 2026-06-20T22:40:01Z
depth: standard
files_reviewed: 85
files_reviewed_list:
  - mobile_v2/AGENTS.md
  - mobile_v2/assets/fixtures/ritual_rooms/shoes_on.json
  - mobile_v2/CODING_STANDARDS.md
  - mobile_v2/lib/app/baby_talk_app.dart
  - mobile_v2/lib/app/input/event_id_generator.dart
  - mobile_v2/lib/app/input/interaction_input_factory.dart
  - mobile_v2/lib/app/providers/interaction_engine_providers.dart
  - mobile_v2/lib/app/providers/ritual_room_capability_provider.dart
  - mobile_v2/lib/app/providers/ritual_room_data_providers.dart
  - mobile_v2/lib/app/providers/ritual_room_session_provider.dart
  - mobile_v2/lib/app/theme/baby_talk_theme.dart
  - mobile_v2/lib/features/ritual_room/data/datasources/interaction_api.dart
  - mobile_v2/lib/features/ritual_room/data/datasources/mock_interaction_api.dart
  - mobile_v2/lib/features/ritual_room/data/datasources/mock_ritual_content_api.dart
  - mobile_v2/lib/features/ritual_room/data/datasources/ritual_content_api.dart
  - mobile_v2/lib/features/ritual_room/data/dto/interaction_advance_request.dart
  - mobile_v2/lib/features/ritual_room/data/dto/interaction_input_dto.dart
  - mobile_v2/lib/features/ritual_room/data/dto/interaction_result_response.dart
  - mobile_v2/lib/features/ritual_room/data/dto/interaction_snapshot_response.dart
  - mobile_v2/lib/features/ritual_room/data/dto/ritual_room_response.dart
  - mobile_v2/lib/features/ritual_room/data/mappers/interaction_mapper.dart
  - mobile_v2/lib/features/ritual_room/data/mappers/ritual_room_mapper.dart
  - mobile_v2/lib/features/ritual_room/data/repositories/interaction_repository_impl.dart
  - mobile_v2/lib/features/ritual_room/data/repositories/ritual_room_repository_impl.dart
  - mobile_v2/lib/features/ritual_room/domain/engine/interaction_engine_port.dart
  - mobile_v2/lib/features/ritual_room/domain/engine/interaction_engine.dart
  - mobile_v2/lib/features/ritual_room/domain/engine/normalize_engine.dart
  - mobile_v2/lib/features/ritual_room/domain/engine/state_accumulator.dart
  - mobile_v2/lib/features/ritual_room/domain/engine/strategy_engine.dart
  - mobile_v2/lib/features/ritual_room/domain/engine/utterance_engine.dart
  - mobile_v2/lib/features/ritual_room/domain/models/advance_result.dart
  - mobile_v2/lib/features/ritual_room/domain/models/input_event.dart
  - mobile_v2/lib/features/ritual_room/domain/models/product_snapshot.dart
  - mobile_v2/lib/features/ritual_room/domain/models/ritual_room_content.dart
  - mobile_v2/lib/features/ritual_room/domain/repositories/interaction_repository.dart
  - mobile_v2/lib/features/ritual_room/domain/repositories/ritual_room_repository.dart
  - mobile_v2/lib/features/ritual_room/domain/runtime/consistency_state.dart
  - mobile_v2/lib/features/ritual_room/domain/runtime/input_fingerprint.dart
  - mobile_v2/lib/features/ritual_room/domain/runtime/interaction_clock.dart
  - mobile_v2/lib/features/ritual_room/domain/runtime/interaction_id_generator.dart
  - mobile_v2/lib/features/ritual_room/domain/runtime/interaction_runtime_state.dart
  - mobile_v2/lib/features/ritual_room/domain/runtime/interaction_runtime_store.dart
  - mobile_v2/lib/features/ritual_room/domain/runtime/interaction_seed_source.dart
  - mobile_v2/lib/features/ritual_room/domain/runtime/interaction_session_initializer.dart
  - mobile_v2/lib/features/ritual_room/domain/runtime/replay_journal.dart
  - mobile_v2/lib/features/ritual_room/domain/runtime/ritual_room_interaction_seed_source.dart
  - mobile_v2/lib/features/ritual_room/presentation/capability/interaction_capability_mask.dart
  - mobile_v2/lib/features/ritual_room/presentation/screens/ritual_room_screen.dart
  - mobile_v2/lib/features/ritual_room/presentation/state/ritual_room_ui_state.dart
  - mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_action_cue.dart
  - mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_context_input_tray.dart
  - mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_current_utterance.dart
  - mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_identity_header.dart
  - mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_listen_control.dart
  - mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_reassurance.dart
  - mobile_v2/lib/features/ritual_room/presentation/widgets/ritual_submitting_indicator.dart
  - mobile_v2/lib/main.dart
  - mobile_v2/pubspec.lock
  - mobile_v2/pubspec.yaml
  - mobile_v2/test/app/providers/interaction_engine_providers_test.dart
  - mobile_v2/test/app/providers/ritual_room_capability_provider_test.dart
  - mobile_v2/test/app/providers/ritual_room_session_provider_test.dart
  - mobile_v2/test/features/ritual_room/data/datasources/mock_interaction_api_test.dart
  - mobile_v2/test/features/ritual_room/data/datasources/mock_ritual_content_api_test.dart
  - mobile_v2/test/features/ritual_room/data/mappers/interaction_mapper_test.dart
  - mobile_v2/test/features/ritual_room/data/mappers/ritual_room_mapper_test.dart
  - mobile_v2/test/features/ritual_room/data/repositories/interaction_repository_test.dart
  - mobile_v2/test/features/ritual_room/data/repositories/ritual_room_repository_test.dart
  - mobile_v2/test/features/ritual_room/domain/engine/interaction_engine_atomicity_test.dart
  - mobile_v2/test/features/ritual_room/domain/engine/interaction_engine_replay_test.dart
  - mobile_v2/test/features/ritual_room/domain/engine/interaction_engine_test.dart
  - mobile_v2/test/features/ritual_room/domain/engine/normalize_engine_test.dart
  - mobile_v2/test/features/ritual_room/domain/engine/state_accumulator_test.dart
  - mobile_v2/test/features/ritual_room/domain/engine/strategy_engine_test.dart
  - mobile_v2/test/features/ritual_room/domain/engine/utterance_engine_test.dart
  - mobile_v2/test/features/ritual_room/domain/models/interaction_contract_test.dart
  - mobile_v2/test/features/ritual_room/domain/runtime/input_fingerprint_test.dart
  - mobile_v2/test/features/ritual_room/domain/runtime/interaction_runtime_test.dart
  - mobile_v2/test/features/ritual_room/interaction_engine_contract_test.dart
  - mobile_v2/test/features/ritual_room/presentation/ritual_room_accessibility_test.dart
  - mobile_v2/test/features/ritual_room/presentation/screens/ritual_room_screen_test.dart
  - mobile_v2/test/features/ritual_room/presentation/state/ritual_room_ui_state_test.dart
  - mobile_v2/test/features/ritual_room/presentation/widgets/ritual_room_support_widgets_test.dart
  - mobile_v2/test/fixtures/interaction_test_fixtures.dart
  - mobile_v2/test/helpers/interaction_test_doubles.dart
findings:
  critical: 2
  warning: 6
  info: 0
  total: 8
status: issues_found
---

# Phase 41: Code Review Report

**Reviewed:** 2026-06-20T22:40:01Z  
**Depth:** standard  
**Files Reviewed:** 85  
**Status:** issues_found

## Summary

The engine authority and immutable runtime structures are generally separated as intended, but the presentation/session boundary does not safely handle repeated submissions or retries. Two defects can produce false conflict errors or violate the event-id idempotency contract. Additional gaps exist in future-signal normalization, content ownership, transport validation, immutable capability configuration, double-fetch consistency, and exception handling.

`flutter analyze --no-pub` passed. Focused Flutter tests did not complete within 120 seconds in two attempts; both runs stalled before reporting test results and left a Dart process running.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Repeated taps discard a successful response and surface a false conflict

**Classification:** BLOCKER  
**File:** `mobile_v2/lib/app/providers/ritual_room_session_provider.dart:66-101`  
**Related:** `mobile_v2/lib/features/ritual_room/presentation/screens/ritual_room_screen.dart:157-163`

**Issue:** `submit` accepts `RitualRoomSubmitting` as a usable session, and the reaction controls remain enabled while a request is pending. Two quick taps therefore submit different events with the same `expectedRevision`. The engine correctly applies one and rejects the other with `revision_conflict`, but `_operationEpoch` causes the notifier to discard the first successful completion. The second completion then wins and places the UI in `RitualRoomRecoverableFailure`, even though the interaction advanced successfully.

**Fix:** Reject or coalesce submission while `state is RitualRoomSubmitting`, and disable all reaction controls during submission. Add a regression test that starts two submissions before the first completes and verifies only one repository call and one applied snapshot.

### CR-02: Recoverable retry creates a new event instead of reusing the idempotency key

**Classification:** BLOCKER  
**File:** `mobile_v2/lib/app/baby_talk_app.dart:43-47`  
**Related:** `mobile_v2/lib/app/providers/ritual_room_session_provider.dart:66-111`, `mobile_v2/test/features/ritual_room/presentation/screens/ritual_room_screen_test.dart:102-124`

**Issue:** Every retry gesture calls `InteractionInputFactory.reaction`, generating a new event ID. The notifier does not retain the failed `InputEvent`, so it cannot retry the same immutable event. This contradicts the Phase 41 contract that retries reuse the same event object and event ID. A lost response after a successful engine commit cannot be resolved as `duplicate_ignored`; the replacement event instead produces a revision conflict. The screen test explicitly asserts that retry IDs differ, codifying the incorrect behavior.

**Fix:** Keep the pending `InputEvent` as transient notifier-owned transport state, expose a retry command that resubmits that exact object, and clear it only after an authoritative result. Change the test to assert identical event IDs/content across retry attempts and cover a “commit succeeded, response failed” scenario.

## Warnings

### WR-01: Future-signal values are accepted and fingerprinted but ignored by normalization

**Classification:** WARNING  
**File:** `mobile_v2/lib/features/ritual_room/domain/engine/normalize_engine.dart:24,93-107`

**Issue:** `FutureSignalPayload` contains both `signal` and `value`, but normalization passes only `signal`. Events such as `shared_action=available` and `shared_action=absent` produce identical semantic output even though they are distinct accepted events. This makes the channel incapable of representing the evidence carried by its own contract.

**Fix:** Pass both fields into `_fromFutureSignal` and map supported signal/value combinations explicitly. Reject unsupported combinations as `invalid_input` or normalize them to a documented uncertainty result. Add opposite-value tests.

### WR-02: Visible “more choices” copy bypasses the content boundary

**Classification:** WARNING  
**File:** `mobile_v2/lib/features/ritual_room/presentation/screens/ritual_room_screen.dart:157-163`

**Issue:** `更多情况` is hardcoded in the screen while the Phase 41 content contract requires ritual-visible copy to come through the fixture/API/repository/domain path. Payload-substitution tests cannot replace this label, and future localization or room-specific wording will require presentation edits.

**Fix:** Add a `moreChoicesLabel` field to the fixture, DTO, mapper, and `RitualRoomContent`, then pass `room.moreChoicesLabel` to `RitualContextInputTray`.

### WR-03: Snapshot decoding permits semantically invalid numeric values

**Classification:** WARNING  
**File:** `mobile_v2/lib/features/ritual_room/data/dto/interaction_snapshot_response.dart:78-86,117-124,155-164`

**Issue:** The decoder checks only that confidence and stability values are finite and that pressure is non-negative. It accepts values such as confidence `-4`, context stability `2`, and pressure level `100000`, which then enter `ProductSnapshot` as valid domain truth. The domain constructors also enforce no ranges.

**Fix:** Validate confidence and stability as `0..1`, define and enforce the pressure range (for example `0..100`), and duplicate critical invariants in domain constructors/factories so invalid snapshots are hard to construct outside transport parsing.

### WR-04: Capability sets are externally mutable

**Classification:** WARNING  
**File:** `mobile_v2/lib/features/ritual_room/presentation/capability/interaction_capability_mask.dart:11-16,29-34`

**Issue:** Both public constructors retain the caller-provided `Set` directly. A caller can mutate a set after construction and silently change engine capability declarations or visible UI policy, violating the immutable-boundary standard.

**Fix:** Defensively copy with `Set.unmodifiable`, or represent capabilities with an immutable enum bitmask/value object. Add a test that mutation of the original input set cannot affect the constructed object.

### WR-05: Room bootstrap reads stable content twice and can combine different versions

**Classification:** WARNING  
**File:** `mobile_v2/lib/app/providers/ritual_room_session_provider.dart:41-56`  
**Related:** `mobile_v2/lib/features/ritual_room/domain/runtime/ritual_room_interaction_seed_source.dart:17-19`

**Issue:** `openRoom` loads `RitualRoomContent`, then the production initializer loads the same repository again through `RitualRoomInteractionSeedSource`. With a remote or mutable source, the UI can pair room metadata from response A with an anchor/bootstrap snapshot from response B. Current tests replace the initializer and therefore do not exercise the production double read.

**Fix:** Initialize the interaction from the already loaded immutable room content, or introduce a request-scoped snapshot/cache that guarantees both consumers use the same content version. Add a production-graph test whose repository returns different values on consecutive calls.

### WR-06: Broad catches erase failure diagnostics and misclassify invariant defects

**Classification:** WARNING  
**File:** `mobile_v2/lib/features/ritual_room/domain/engine/interaction_engine.dart:120-188`

**Issue:** `on Object` converts every exception and error—including programming/invariant failures in receipt, journal, or commit construction—into `pipeline_failed` without recording a safe cause. This hides defects as expected pipeline failures and prevents actionable diagnostics while the public result gives no distinction.

**Fix:** Catch documented pipeline exception types, report sanitized operation/correlation details through an injected diagnostics boundary, and allow unexpected `Error`/invariant failures to propagate in development and tests. Preserve atomic no-commit behavior.

---

_Reviewed: 2026-06-20T22:40:01Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: standard_
