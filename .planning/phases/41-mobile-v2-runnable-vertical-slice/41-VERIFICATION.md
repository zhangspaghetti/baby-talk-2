---
phase: 41-mobile-v2-runnable-vertical-slice
verified: 2026-06-21T02:02:27Z
status: gaps_found
score: 10/12 must-haves verified
overrides_applied: 0
gaps:
  - truth: "Repeated reaction submissions preserve the authoritative successful snapshot and do not surface a false conflict."
    status: failed
    reason: "The notifier accepts submit while already submitting, both requests use the same expected revision, and operation-epoch handling discards the earlier completion. A later revision-conflict response can therefore replace a successful result with recoverable failure."
    artifacts:
      - path: "mobile_v2/lib/app/providers/ritual_room_session_provider.dart"
        issue: "_usableSession includes RitualRoomSubmitting; every submit increments _operationEpoch, so concurrent taps are admitted and only the newest completion may update UI state."
      - path: "mobile_v2/lib/features/ritual_room/presentation/screens/ritual_room_screen.dart"
        issue: "Reaction controls remain active while RitualRoomSubmitting is rendered."
    missing:
      - "Reject or coalesce submit while a request is pending."
      - "Disable reaction controls during submission."
      - "Add a controlled-completer regression test proving two rapid taps cause one repository call and retain the applied snapshot."
  - truth: "A recoverable retry reuses the same immutable InputEvent and eventId so a lost response resolves through duplicate_ignored."
    status: failed
    reason: "The notifier does not retain the pending event and BabyTalkApp creates a new event for every reaction gesture. The existing screen test explicitly expects different event IDs, contradicting the approved Interaction Engine contract."
    artifacts:
      - path: "mobile_v2/lib/app/baby_talk_app.dart"
        issue: "onReactionSelected always calls InteractionInputFactory.reaction(), generating a new event before submit."
      - path: "mobile_v2/lib/app/providers/ritual_room_session_provider.dart"
        issue: "No pending InputEvent is retained and no retry command resubmits the same event."
      - path: "mobile_v2/test/features/ritual_room/presentation/screens/ritual_room_screen_test.dart"
        issue: "Lines 123-124 assert that retry event IDs differ."
    missing:
      - "Retain the failed immutable event as transient notifier-owned retry state."
      - "Expose a retry command that resubmits that exact event and clears it only after an authoritative result."
      - "Test commit-succeeded/response-lost behavior and assert duplicate_ignored with the same eventId."
---

# Phase 41: mobile_v2 Runnable Ritual Room Vertical Slice Verification Report

**Phase Goal:** Build a runnable Flutter `mobile_v2` Ritual Interaction Engine slice with repository-backed room content, five input channels, atomic engine authority, thin adapters, one Riverpod session notifier, and a reaction-only ProductSnapshot UI projection.
**Verified:** 2026-06-21T02:02:27Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Approved D.4.5/static assets, package configuration, five-channel models, schema 1/revision 0, and exhaustive results exist. | ✓ VERIFIED | Both PNG assets and `shoes_on.json` exist; pubspec registers both asset roots; model artifacts pass plan verification. |
| 2 | Four separate pure modules accept all five channels and produce normalized context, accumulated memory, strategy, and one utterance. | ✓ VERIFIED | `NormalizeEngine -> StateAccumulator -> StrategyEngine -> UtteranceEngine` is wired through `InteractionEngine`; mixed-channel contract evidence reaches revision 5. Future-signal value handling has a warning below. |
| 3 | ProductSnapshot + ConsistencyState are committed atomically and ReplayJournal is evidence-only/directly replayable. | ✓ VERIFIED | `runExclusive` stages one aggregate commit; engine constructs snapshot, receipt, and transition before one `commit(nextState)` call. |
| 4 | InteractionEngine owns lifecycle, revision, idempotency, conflict order, pipeline execution, and atomic writes. | ✓ VERIFIED | Current engine checks receipt/fingerprint before expected revision, serializes per interaction, and returns latest snapshots for conflicts. |
| 5 | Stable room content flows only through fixture → API → DTO → mapper → repository → domain. | ✓ VERIFIED | `MockRitualContentApi` asynchronously reads `shoes_on.json`; repository maps DTO to `RitualRoomContent`; presentation consumes domain values. |
| 6 | Five-channel DTO/API/repository adapters are thin and preserve engine result semantics. | ✓ VERIFIED | Mapper is exhaustive; MockInteractionApi delegates to the port; repository maps request/result without owning lifecycle. |
| 7 | Riverpod composition resolves one engine/store, one session notifier, an overridable input factory, and reaction-only presentation capability. | ✓ VERIFIED | Exactly one `NotifierProvider` exists; engine port and initializer resolve the same engine; semantic source scan passes. |
| 8 | RitualRoomSessionNotifier is the sole mutable product-session owner and UI state carries whole room/snapshot values. | ✓ VERIFIED | State union contains whole `RitualRoomContent`/`ProductSnapshot` plus transient status/problem; no parallel controller or ViewModel exists. |
| 9 | The D.4.5 UI is a direct, repository-fed, reaction-only projection with stable identity and in-place snapshot replacement. | ✓ VERIFIED | App opens one screen; widgets render one utterance/action/listen control, reaction tray/sheet, reassurance, pending state, and quiet exit. |
| 10 | R058/R059/R060/R063/R064/R065 scope and safety boundaries remain enforced. | ✓ VERIFIED | Independent semantic firewall and Activation Governor verifier both pass with zero violations; no old-mobile import, hidden-channel control, scoring, lesson, or production Garden transition was found. |
| 11 | Repeated reaction submissions cannot discard a successful response or surface a false conflict. | ✗ FAILED | Submitting state remains actionable; notifier admits a second request at the same revision and epoch logic discards the earlier completion. |
| 12 | Recoverable retry reuses the same immutable event/idempotency key. | ✗ FAILED | Contract requires same event/eventId; app generates a fresh event and the test asserts IDs differ. |

**Score:** 10/12 truths verified

### Required Artifacts

All 36 PLAN-frontmatter artifacts exist and pass the automated existence/substance checks. The following goal-critical artifacts were also inspected for behavior and wiring:

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `interaction_engine.dart` | Sole authority and atomic transition | ✓ VERIFIED | Full pipeline and one aggregate commit are substantive and wired. |
| `interaction_runtime_store.dart` | Serialized per-interaction store | ✓ VERIFIED | Queues operations and publishes only committed aggregate state. |
| `mock_ritual_content_api.dart` / repository | Real asset-backed content flow | ✓ VERIFIED | Loads JSON asset and maps it to domain content. |
| Interaction DTO/mapper/API/repository chain | Five-channel transport seam | ✓ VERIFIED | Exhaustive mapping and engine delegation found. |
| `ritual_room_session_provider.dart` | Sole safe session orchestrator | ✗ PARTIAL | Single owner and whole-snapshot state are correct; repeated submit and retry semantics are not. |
| `ritual_room_screen.dart` | Restricted reaction-only projection | ✗ PARTIAL | Projection is wired, but reaction controls remain enabled during submission. |
| `baby_talk_app.dart` | App composition and typed event dispatch | ✗ PARTIAL | Correct provider composition; retry creates a new idempotency key. |

### Key Link Verification

All 23 PLAN-frontmatter pattern links were found. Behavioral tracing exposed two broken semantics beyond pattern matching:

| From | To | Via | Status | Details |
|---|---|---|---|---|
| JSON asset | RitualRoomScreen | content API → mapper → repository → notifier | ✓ WIRED | Domain content reaches visible UI. |
| Reaction UI | InteractionEngine | factory → notifier → repository → API → engine | ✓ WIRED | Normal single submission advances the authoritative snapshot. |
| Five input variants | ProductSnapshot revision 5 | factory/DTO/mapper/repository/engine | ✓ WIRED | Hidden channels remain executable. |
| Submitting UI | Session notifier | second reaction callback | ✗ UNSAFE | No pending guard; stale/conflicting concurrent result can win UI state. |
| Recoverable retry | ConsistencyState duplicate receipt | same InputEvent/eventId | ✗ NOT WIRED | Retry creates a new event, bypassing intended idempotent duplicate handling. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| RitualRoomScreen | `room` | JSON asset through content repository | Yes | ✓ FLOWING |
| RitualRoomScreen | `snapshot` | InteractionEngine through API/repository/notifier | Yes | ✓ FLOWING |
| InteractionEngine | normalized/memory/strategy/utterance | Five typed InputEvents through four modules | Yes | ✓ FLOWING |
| Retry path | failed `InputEvent` | Not retained | No | ✗ DISCONNECTED |

### Behavioral Spot-Checks

| Behavior | Command/evidence | Result | Status |
|---|---|---|---|
| Semantic firewall | `dart run tool/verify_mobile_v2_semantic_firewall.dart` | 59 runtime files, 0 violations | ✓ PASS |
| Activation/Garden contract | `dart run tool/verify_activation_governor_contract.dart` | 5 cases, 0 violations | ✓ PASS |
| Full Flutter suite | Fresh orchestrator evidence immediately before verification | 113/113 passed | ✓ PASS |
| Focused Flutter rerun | Serial screen test after parallel lock cleanup | Timed out without test result; source/full-suite evidence used instead | ? INCONCLUSIVE |
| Retry key behavior | Existing screen test lines 123-124 | Explicitly expects different event IDs | ✗ FAIL |
| Repeated-tap behavior | Notifier/screen call-path trace | Second pending submit is admitted at same revision; earlier completion becomes stale | ✗ FAIL |

### Probe Execution

No phase probe scripts were declared or found. Step 7c is not applicable.

### Requirements Coverage

Every requirement ID declared across Plans 41-01 through 41-11 was found in `.planning/REQUIREMENTS.md`; no Phase 41 orphan requirement was found.

| Requirement | Source Plans | Description | Status | Evidence |
|---|---|---|---|---|
| R058 | 01,02,05,10,11 | Family-micro-ritual-first; exclude course/translator/check-in/infinite generation | ✓ SATISFIED | Direct single-room surface and semantic scan. |
| R059 | 01,02,05,10,11 | Stable Family English Micro-ritual unit, not phrase/activity completion | ✓ SATISFIED | Stable identity and one current utterance, no completion loop. |
| R060 | 01-11 | Observed evidence/joinability remain non-diagnostic | ✓ SATISFIED | Raw non-retention and non-diagnostic source contract verified. |
| R063 | 05,10,11 | Activation remains Governor-gated | ✓ SATISFIED | Phase 40 verifier passes; Phase 41 adds no activation authority. |
| R064 | 05,10,11 | Garden Memory is parent-confirmed, not score/check-in | ✓ SATISFIED | No production Garden transition or pressure semantics. |
| R065 | 05,10,11 | Explore and Activate remain distinct | ✓ SATISFIED | No Phase 41 activation expansion or action-now recommendation authority. |
| R067 | 01-11 | Evolving five-input engine with reaction-only UI projection | ✗ BLOCKED | Core engine/adapters pass, but end-to-end reaction lifecycle violates required event/revision/idempotency contracts on repeated tap and retry. |

### Independent Review Finding Validation

The prior review was treated as a hypothesis. All eight findings were checked against current code:

| Finding | Independent result | Severity |
|---|---|---|
| Repeated-tap stale/conflict handling | Reproduced by call-path analysis: submitting is accepted, controls stay active, both calls use the same revision, and epoch handling can discard success. | 🛑 BLOCKER |
| Retry idempotency-key reuse | Reproduced: contract requires same event; app creates a new event; test asserts different IDs. | 🛑 BLOCKER |
| Future-signal value ignored | Confirmed: normalization destructures only `signal`, not `value`. | ⚠️ WARNING |
| Hardcoded `更多情况` | Confirmed in screen instead of content DTO/domain path. | ⚠️ WARNING |
| Numeric snapshot ranges | Confirmed: finite/non-negative checks do not enforce confidence/stability `0..1` or an upper pressure bound. | ⚠️ WARNING |
| Mutable capability sets | Confirmed: constructors retain caller-owned `Set` values. | ⚠️ WARNING |
| Double room-content read | Confirmed: notifier loads room, then production seed source loads the same repository again. | ⚠️ WARNING |
| Broad engine catch | Confirmed: `on Object` converts invariant/programming failures into `pipelineFailed` without diagnostics. | ⚠️ WARNING |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| `ritual_room_session_provider.dart` | 116-123 | Submitting treated as usable input state | 🛑 Blocker | Permits concurrent same-revision submissions and false conflict UI. |
| `baby_talk_app.dart` | 43-47 | New event generated for every retry gesture | 🛑 Blocker | Breaks idempotent retry contract. |
| `ritual_room_screen.dart` | 161 | Ritual-visible copy hardcoded | ⚠️ Warning | Bypasses content substitution/localization boundary. |
| `normalize_engine.dart` | 24 | Future-signal `value` discarded | ⚠️ Warning | Distinct evidence values normalize identically. |
| `interaction_engine.dart` | 183 | Broad `on Object` catch | ⚠️ Warning | Masks invariant defects as expected pipeline failure. |

No unreferenced `TBD`, `FIXME`, or `XXX` debt markers were found in the Phase 41 runtime files.

### Human Verification Required

Visual fidelity to D.4.5 and real TalkBack/VoiceOver behavior still require device-level human verification, but they do not affect this status because the automated blocker conditions already fail the phase gate. Perform those checks after the two lifecycle gaps are fixed.

### Deferred Item Check

The blockers are not deferred. Phase 42 opens additional controls, while Phase 43 hardens later state seams; neither later phase explicitly owns fixing Phase 41's existing reaction submission/retry correctness. The Phase 41 goal itself requires preserved lifecycle, version, conflict, and replay contracts.

### Gaps Summary

The engine core, adapters, repository content flow, provider graph, restricted UI projection, and semantic boundaries are substantially implemented. The phase goal is still not achieved because the runnable reaction path does not preserve the engine's concurrency and idempotency contracts:

1. Rapid repeated taps can allow one successful commit while the UI discards that success and displays a conflict.
2. Retry creates a new event instead of replaying the failed immutable event, so a lost response cannot resolve as `duplicate_ignored`.

Passing tests do not close these gaps; one current test codifies the incorrect retry behavior and no test covers the repeated-tap race.

---

_Verified: 2026-06-21T02:02:27Z_
_Verifier: the agent (gsd-verifier)_
