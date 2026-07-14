# Phase 41 — Interaction Engine v1 Contract

**Status:** approved system architecture contract
**Updated:** 2026-06-19
**Scope:** Engine-first Interaction Runtime OS, capability-complete Phase 41
reference implementation, and Phase 42-compatible replacement seams

## 1. System Definition

Baby Talk is not a phrase lookup tool and not a reaction-to-sentence API.

```text
Interaction Engine
  = evolving product state
  + ephemeral multi-channel input
  + context accumulation
  + strategy selection
  + immediately speakable language
```

Interaction Engine v1 is a continuously evolving decision system for
real-world caregiver communication guidance.

The engine owns lifecycle, consistency, and state transitions. Flutter, mock
transport, future Spring transport, and future LLM-backed module
implementations are consumers or replaceable implementations of this contract;
none of them defines the domain.

## 2. Locked Architecture

The runtime uses a deterministic authority shell around replaceable stateless
pipeline modules:

```text
Raw InputEvent
  -> InteractionEngine authority checks
  -> NormalizeEngine
  -> StateAccumulator
  -> StrategyEngine
  -> UtteranceEngine
  -> atomic runtime commit
  -> ProductSnapshot emit
```

### 2.1 InteractionEngine is the only authority

`InteractionEngine` exclusively owns:

- `initialize` and `advance` lifecycle operations
- interaction identity
- `schemaVersion`
- monotonic `revision`
- `eventId` idempotency
- `expectedRevision` concurrency checks
- runtime-state reads and writes
- conflict resolution
- atomic commit of product state, consistency state, and transition evidence

No other module may increment revision, write a snapshot, append a journal
record, or decide whether an event is accepted.

### 2.2 Pipeline modules

The stable runtime names are:

- `NormalizeEngine`
- `StateAccumulator`
- `StrategyEngine`
- `UtteranceEngine`

There are no `V2` suffixes in code or API contracts. Earlier “v2” language
describes design history only.

Every module:

- is a pure-Dart domain contract with no Flutter dependency
- is stateless from the runtime's perspective
- receives immutable input and returns immutable output
- does not own lifecycle, revision, idempotency, or persistence
- cannot directly modify `ProductSnapshot`
- cannot write `ConsistencyState`
- cannot append `ReplayJournal`
- cannot depend on UI state

Phase 41 implementations are deterministic and rule-based. A future LLM may
exist only inside a replaceable Normalize, Strategy, or Utterance
implementation. It may not become the authority shell or directly mutate
runtime state. “Pure” at this boundary means no domain-state side effects or
ownership; a future provider-backed implementation may perform external
inference I/O, but its only domain-visible effect is its immutable return value.

## 3. Version Model

The system has two independent version axes.

### 3.1 `schemaVersion`

- Interaction Engine v1 uses `schemaVersion = 1`.
- It identifies the `ProductSnapshot` structure and semantics.
- It changes only for a breaking snapshot or engine-contract change.
- It never changes because an interaction advances.
- Backend adapters, LLM integrations, decoders, migrations, and replay tooling
  must check it before interpreting a snapshot.

Compatible improvements within schema version 1 must be additive, provide safe
defaults, preserve existing field meaning, and tolerate unknown optional
fields. Removing a required field, changing a field's meaning, or making old
snapshots unsafe to interpret requires a new schema version and an explicit
migration boundary.

### 3.2 `revision`

- Each interaction starts at `revision = 0`.
- Each successfully applied event increments revision exactly once.
- Revision is strictly monotonic within one interaction.
- Duplicate events, rejected events, reads, and failed pipeline executions do
  not increment revision.
- UI rendering, optimistic concurrency, debugging, and transition history use
  revision.

`schemaVersion` must never be used as runtime state, and `revision` must never
be used as a schema compatibility signal.

## 4. Runtime State Model

```text
InteractionRuntimeState
├─ ProductSnapshot
├─ ConsistencyState
└─ ReplayJournal
```

`ProductSnapshot + ConsistencyState` is current runtime truth.
`ReplayJournal` is historical transition evidence only.

### 4.1 ProductSnapshot

`ProductSnapshot` is the only product-semantic truth and the only interaction
state the UI may render.

```json
{
  "interactionId": "uuid",
  "ritualRoomId": "shoes_on",
  "schemaVersion": 1,
  "revision": 3,
  "anchor": "Shoes on.",
  "context": {
    "actionContext": "putting shoes on",
    "momentHypothesis": "shared action is currently hard to enter",
    "normalizedSignals": [
      "avoidance",
      "low_joinability"
    ]
  },
  "memory": {
    "eventSummary": "the shared shoe routine is currently difficult to enter",
    "eventLogCompressed": [
      "the shared action did not begin",
      "attention moved away from the shoe routine"
    ],
    "signalAggregation": {
      "avoidance": 0.72,
      "low_joinability": 0.65,
      "shared_action": 0.15
    },
    "interactionTrend": "decreasing_joinability",
    "contextStability": 0.68,
    "interactionNarrative": "the routine became harder to join after attention moved away"
  },
  "strategy": {
    "primary": "low_pressure",
    "modifiers": [
      "simplify",
      "reduce_options"
    ],
    "confidence": 0.82,
    "rationale": "current signals indicate low joinability",
    "pressureLevel": 25,
    "recommendedTone": "soft",
    "interactionHint": "offer one small shared action without requiring a response"
  },
  "utterance": {
    "primary": "Let’s just try one shoe together first.",
    "zhHelper": "可以先一起试着穿一只鞋。",
    "tone": "soft",
    "clarityLevel": "high",
    "contextFit": "when the shared action is currently hard to enter",
    "alternatives": []
  },
  "meta": {
    "lastEventId": "last_event_uuid",
    "updatedAt": 1234567890
  }
}
```

The snapshot must contain:

- stable interaction and ritual identity
- schema version and current revision
- stable ritual anchor
- current normalized context
- compressed interaction-local memory
- current strategy decision
- exactly one primary immediately speakable utterance
- observation-only metadata

The snapshot must not contain:

- raw audio
- raw voice transcript
- raw free text
- raw input payloads
- UI controls, selection state, loading flags, or navigation state
- child ability, compliance, quality, correctness, learning, or performance
  scores
- long-term child traits or developmental inference
- pipeline intermediate objects that are not part of current product semantics
- idempotency receipts or replay infrastructure

`meta.lastEventId` is for observation and debugging only. It must not be used
for idempotency or conflict decisions.

### 4.2 ConsistencyState

`ConsistencyState` is engine-internal runtime correctness state. It is not
product state and is not exposed to Flutter, LLM prompts, or the public
snapshot response.

```json
{
  "processedEvents": [
    {
      "eventId": "uuid",
      "inputFingerprint": "sha256:...",
      "appliedRevision": 3
    }
  ]
}
```

Each receipt may contain only:

- `eventId`
- canonical `inputFingerprint`
- `appliedRevision`

It must not contain raw payload, transcript, free text, or audio. Phase 41
retains every receipt for the in-memory interaction lifetime and destroys them
with the interaction. Future persistence and retention policy are separate
design work and cannot alter the ProductSnapshot contract.

### 4.3 ReplayJournal

`ReplayJournal` is append-only transition evidence for deterministic historical
replay, debugging, and analysis. It is not a third state owner and does not
participate in current strategy or state decisions.

Each successful transition records:

```json
{
  "eventId": "uuid",
  "fromRevision": 2,
  "toRevision": 3,
  "occurredAt": 1234567890,
  "normalizedInput": {},
  "updatedContextMemory": {},
  "strategyDecision": {},
  "utterance": {}
}
```

A `TransitionRecord` contains:

- `eventId`
- `fromRevision`
- `toRevision`
- `occurredAt`
- `NormalizedInput`
- `UpdatedContextMemory`
- `StrategyDecision`
- `Utterance`

It never contains raw voice, raw free text, a verbatim transcript, or another
raw payload.

Replay applies already-recorded transition results to the revision-0 product
snapshot. It must not call an LLM and must not rerun Normalize, StateAccumulator,
Strategy, or Utterance modules. This makes recorded module output, rather than
provider re-execution, the deterministic replay boundary.

Phase 41 stores the journal in memory and destroys it with the interaction.
Future journal persistence is independently versioned infrastructure work and
does not change ProductSnapshot schema 1.

## 5. Lifecycle Contract

### 5.1 Initialize

```text
InteractionEngine.initialize(ritualRoomId)
```

Initialization:

- creates one unique `interactionId`
- resolves the stable ritual seed and anchor through an injected pure-Dart seed
  source
- creates a schema-version-1 ProductSnapshot at revision 0
- creates empty ConsistencyState
- creates empty ReplayJournal
- stores the complete InteractionRuntimeState in the engine-owned runtime store

Interaction ID creation uses an injected `InteractionIdGenerator` so production
can guarantee uniqueness and tests can remain deterministic.

Phase 41 exposes no public initialize endpoint. The mobile composition root
invokes initialize after successful Ritual Room bootstrap.

### 5.2 Snapshot read

```http
GET /engine/snapshot/{interactionId}
```

The Phase 41 implementation is an API-shaped in-process contract, not a real
HTTP server.

Snapshot read:

- returns the current ProductSnapshot
- has no side effects
- never initializes an interaction
- never increments revision
- returns `interaction_not_found` for an unknown ID

### 5.3 Advance

```http
POST /engine/advance
```

Conceptual request:

```json
{
  "interactionId": "uuid",
  "expectedRevision": 2,
  "input": {
    "eventId": "uuid",
    "type": "reaction_selection",
    "timestamp": 1234567890,
    "payload": {
      "selected": "running_away"
    }
  }
}
```

Advance:

- only operates on an existing interaction
- requires `expectedRevision`
- applies every accepted event through the full pipeline
- atomically commits ProductSnapshot, ConsistencyState, and ReplayJournal
- returns the latest ProductSnapshot

Unknown interactions return `interaction_not_found`; implicit initialization is
forbidden.

Conceptual successful response:

```json
{
  "status": "applied",
  "snapshot": {}
}
```

Conceptual conflict response:

```json
{
  "error": {
    "code": "revision_conflict"
  },
  "latestSnapshot": {}
}
```

## 6. InputEvent Contract

The durable input envelope supports:

```text
reaction_selection
voice_observation
free_text
future_signal
strategy_preference
```

```json
{
  "eventId": "uuid",
  "type": "voice_observation",
  "timestamp": 1234567890,
  "payload": {
    "transcript": "the child ran away and does not want shoes"
  }
}
```

Raw input is ephemeral:

```text
raw InputEvent
  -> canonical fingerprint
  -> NormalizeEngine
  -> NormalizedInput
  -> raw payload discarded
```

The fingerprint is computed from a canonical encoding of the complete immutable
event content before the raw payload is discarded. A retry must reuse the same
event object and `eventId`; changing any fingerprinted event content makes it a
different event and triggers conflict when the ID is reused.

## 7. Idempotency and Concurrency

The engine evaluates an advance request in this order:

1. Resolve `interactionId`; otherwise return `interaction_not_found`.
2. Compute the canonical input fingerprint.
3. Look up the `eventId` receipt.
4. If the same ID and fingerprint exist, return `duplicate_ignored` with the
   current latest ProductSnapshot. Do not run the pipeline or increment revision.
5. If the same ID exists with a different fingerprint, return
   `event_id_conflict`. Do not run the pipeline or mutate runtime state.
6. Compare `expectedRevision` with the current ProductSnapshot revision.
7. On mismatch, return `revision_conflict` with the current latest
   ProductSnapshot. Do not run the pipeline or mutate runtime state.
8. Run the pipeline.
9. Prepare ProductSnapshot revision `n + 1`, its event receipt, and one
   TransitionRecord.
10. Commit all three runtime structures as one engine-owned atomic operation.

The complete sequence is serialized per interaction in Phase 41. A future
runtime may use a transaction or compare-and-swap, but it must provide the same
observable semantics: no two requests may successfully commit from the same
revision, and event absence plus expected revision must be revalidated by the
atomic commit boundary. Pipeline work that completes after another request has
won the commit must be discarded and resolved as the appropriate conflict; its
outputs must not leak into runtime state or the journal.

The duplicate check precedes revision checking so a delayed retry of an already
applied event remains safely idempotent even after later events have advanced
the interaction.

### 7.1 Result contract

Successful transport responses use:

```text
applied
duplicate_ignored
```

Rejected transport results use:

```text
interaction_not_found
revision_conflict
event_id_conflict
unsupported_schema_version
invalid_input
pipeline_failed
```

`revision_conflict` and `event_id_conflict` include the latest ProductSnapshot
when the interaction exists. Flutter replaces its local product snapshot with
the engine snapshot; last-write-from-engine wins.

Failures never partially execute, never append a receipt or journal record, and
never increment revision.

## 8. NormalizeEngine Contract

`NormalizeEngine` transforms one ephemeral raw event into modality-agnostic
semantic input.

```json
{
  "semanticSignals": [
    "avoidance",
    "low_joinability"
  ],
  "intentEstimate": "resist",
  "momentHypothesis": "shared action is currently hard to enter",
  "contextFrame": {
    "actionContext": "putting shoes on",
    "interactionType": "caregiver_shared_action_support"
  },
  "confidence": 0.78,
  "eventSummary": "attention moved away from the shared shoe routine"
}
```

Responsibilities:

- cross-modal semantic equivalence
- duplicate/noise reduction
- interaction-local signal extraction
- intent estimation
- context framing
- irreversible, non-verbatim event summarization

It must not generate strategy, language, or child evaluation. `eventSummary`
must be a compressed semantic representation, not disguised raw storage.

## 9. StateAccumulator Contract

`StateAccumulator` receives:

```text
NormalizedInput
+ previous ContextMemory
+ current ProductSnapshot summary
```

It returns immutable `UpdatedContextMemory` containing:

- compressed summary
- compressed event log
- decay-based signal aggregation
- interaction trend
- context stability
- a short interaction narrative

Revision is monotonic; semantic state is not. Interaction state may improve,
regress, oscillate, or become uncertain. New evidence is combined through
decay-based aggregation rather than forced convergence or overwrite.

Signal weights express only evidence strength inside the current interaction.
They are not child scores and must never be aggregated across interactions into
a child profile.

## 10. StrategyEngine Contract

`StrategyEngine` is a stateless policy evaluator.

Input:

```text
NormalizedContext
+ ContextMemory
+ current ProductSnapshot summary
```

Output:

```json
{
  "primary": "low_pressure",
  "modifiers": [
    "simplify",
    "reduce_options"
  ],
  "confidence": 0.82,
  "rationale": "current signals indicate low joinability",
  "pressureLevel": 25,
  "recommendedTone": "soft",
  "interactionHint": "offer one small shared action without requiring a response"
}
```

The strategy space is multi-axis:

- pressure: `low_pressure | neutral | structured_guidance`
- interaction intent: `continue | simplify | redirect | pause`
- cognitive load: `reduce_options | maintain | increase_clarity`

`primary` expresses the selected pressure policy. `modifiers` contain the
selected interaction-intent and cognitive-load policies. `pressureLevel`
describes the proposed language pressure, not the child.

StrategyEngine decides what should happen next. It does not generate the final
utterance, access event IDs, inspect UI state, or write runtime state.

## 11. UtteranceEngine Contract

`UtteranceEngine` realizes the strategy as caregiver language.

Input:

```text
StrategyDecision
+ NormalizedContext
+ stable anchor
+ ContextMemory summary
```

Output:

```json
{
  "primary": "Let’s just try one shoe together first.",
  "zhHelper": "可以先一起试着穿一只鞋。",
  "tone": "soft",
  "clarityLevel": "high",
  "contextFit": "when the shared action is currently hard to enter",
  "alternatives": []
}
```

Rules:

- exactly one primary utterance is always present
- preserve ritual and anchor meaning
- introduce no new task or context
- map strategy to language without changing the strategy
- control sentence length, syntactic complexity, emotional pressure, and
  directive strength
- produce immediately speakable, low-cognitive-load caregiver language
- avoid behavioral judgment, correctness, compliance, and corrective tone
- do not generate a multi-step dialogue

UtteranceEngine decides how to say the selected policy. It does not decide what
the policy is.

## 12. Safety Semantics

The system models interaction joinability: how easy the current shared action
is to enter. It does not model child cooperation or compliance.

Required vocabulary:

- `shared_action`, not `cooperation`
- `low_joinability`, not `low_cooperation`
- `engage`, not `comply`
- `decreasing_joinability`, not `decreasing_cooperation`
- `momentHypothesis`, not `childStateHypothesis`
- `interactionTrend`, not `behavioralTrend`
- `eventSummary`, not `rawSummary`

All signals:

- describe only the current interaction
- remain non-diagnostic and non-evaluative
- cannot express child ability, quality, performance, or developmental status
- cannot become long-term child traits

Forbidden:

- behavioral trait modeling
- developmental inference
- child compliance or learning scores
- cross-interaction child-state aggregation
- raw transcript or free-text retention

## 13. Capability Model and UI Mask

Engine capability and UI exposure are separate contracts.

The engine capability catalog for Phase 41 is:

```json
{
  "reaction_selection": true,
  "voice_observation": true,
  "free_text": true,
  "future_signal": true,
  "strategy_preference": true
}
```

The Phase 41 UI capability mask is:

```json
{
  "reaction_selection": true,
  "voice_observation": false,
  "free_text": false,
  "future_signal": false,
  "strategy_control": false
}
```

`strategy_control` is the presentation affordance that emits a
`strategy_preference` InputEvent.

The mask is injected at the composition root and controls only which input
adapters/widgets are rendered. It does not alter engine support, repository
support, DTO variants, tests, or ProductSnapshot semantics.

The Flutter UI may:

- render ProductSnapshot
- display only capability-mask-allowed controls
- send typed InputEvents
- show transient transport state such as loading/submitting/error
- replace its ProductSnapshot with the latest engine result

Transient loading and error state may exist in a presentation controller, but
it is not product truth and must never duplicate or derive interaction context,
memory, strategy, utterance, or revision.

The UI must not:

- infer strategy
- accumulate context
- generate utterances
- increment revision
- edit snapshot fields
- define supported engine capabilities

## 14. Adapter Boundaries

Phase 41 uses:

```text
Flutter presentation
  -> InteractionRepository
  -> MockInteractionApi
  -> InteractionEngine
```

`MockInteractionApi`:

- implements the stable API-shaped transport contract
- maps request DTOs to engine-domain requests
- calls `snapshot` or `advance`
- maps engine results to response DTOs
- contains no normalization, accumulation, strategy, utterance, revision, or
  idempotency logic

`InteractionRepository`:

- maps domain InputEvent to request DTO
- maps response DTO to domain ProductSnapshot/result
- hides local mock versus future remote transport
- contains no engine business logic

The future Spring backend is a transport/deployment implementation behind the
same contract. API DTOs are transport contracts, not domain definitions.
Changing transport must not force Flutter presentation or engine semantics to
change.

## 15. Clock and Determinism

InteractionEngine receives an injected `Clock`.

- A successful new transition obtains `occurredAt`/`updatedAt` once.
- The same timestamp is committed to ProductSnapshot and TransitionRecord.
- Duplicate and rejected events do not generate a new transition time.
- Replay uses the recorded timestamp and does not query the clock.

InteractionEngine also receives an injected `InteractionIdGenerator`; replay
starts from the recorded revision-0 snapshot and therefore does not generate a
new ID.

Phase 41's deterministic rule implementations must produce the same outputs for
the same revision-0 snapshot and ordered accepted events.

Future LLM-assisted implementations record their final normalized, memory,
strategy, and utterance outputs in TransitionRecord. Replay applies those
recorded outputs and never recontacts a provider.

## 16. Phase 41 Reference Implementation

Phase 41 must implement:

- pure-Dart InteractionEngine authority shell
- pure-Dart immutable ProductSnapshot and pipeline contracts
- in-memory InteractionRuntimeState store
- deterministic NormalizeEngine
- deterministic StateAccumulator
- deterministic StrategyEngine
- deterministic UtteranceEngine
- internal initialize lifecycle
- API-shaped snapshot and advance operations
- event fingerprinting and receipts
- revision conflict handling
- in-memory ReplayJournal
- MockInteractionApi transport adapter
- InteractionRepository transport/domain adapter
- full engine capability catalog
- Phase 41 reaction-only UI mask

Phase 41 must test:

- revision-0 initialization
- every InputEvent channel
- mixed-channel sequential evolution
- monotonic successful revisions
- duplicate event retry after later revisions
- event ID conflict
- revision conflict and latest-snapshot overwrite
- interaction not found
- pipeline failure atomicity
- raw-input non-retention
- decay-based non-monotonic semantic evolution
- deterministic journal replay without pipeline re-execution
- adapter parity with direct engine execution
- capability completeness independent of UI mask

Phase 41 does not implement:

- public initialization endpoint
- Spring Boot engine endpoint
- persistence
- microphone capture or STT
- visible free-text entry
- future-signal producers
- visible strategy controls
- LLM calls
- cross-session memory
- cross-interaction child profiling

## 17. Phase 42 Direction — Design Only

Phase 42 may:

- add an LLM-assisted NormalizeEngine implementation
- add an LLM-assisted StrategyEngine implementation
- add an LLM-assisted UtteranceEngine implementation
- add voice-observation acquisition and normalization
- add interaction-local multi-turn memory compression
- refine strategy evolution behind the unchanged StrategyDecision contract
- use deterministic fallback implementations

Phase 42 must not replace InteractionEngine authority with an LLM. It must keep:

- schema version 1 unless a genuine breaking change is approved
- the same lifecycle
- the same event and revision semantics
- the same ProductSnapshot contract
- the same ConsistencyState rules
- the same ReplayJournal rules
- Phase 41 capabilities independently executable

Phase 41 has no dependency on Phase 42 implementations.

## 18. Target Pure-Dart Boundary

The implementation plan should introduce a focused structure equivalent to:

```text
lib/features/ritual_room/
├─ domain/
│  ├─ engine/
│  │  ├─ interaction_engine.dart
│  │  ├─ normalize_engine.dart
│  │  ├─ state_accumulator.dart
│  │  ├─ strategy_engine.dart
│  │  └─ utterance_engine.dart
│  ├─ models/
│  │  ├─ input_event.dart
│  │  ├─ normalized_input.dart
│  │  ├─ context_memory.dart
│  │  ├─ strategy_decision.dart
│  │  ├─ utterance.dart
│  │  └─ product_snapshot.dart
│  └─ runtime/
│     ├─ interaction_runtime_state.dart
│     ├─ consistency_state.dart
│     ├─ replay_journal.dart
│     └─ interaction_clock.dart
└─ data/
   ├─ datasources/
   │  ├─ interaction_api.dart
   │  └─ mock_interaction_api.dart
   ├─ dto/
   ├─ mappers/
   └─ repositories/
      └─ interaction_repository_impl.dart
```

Exact file grouping may be adjusted during implementation planning, but these
dependency directions are fixed:

```text
presentation -> domain repository contract
data adapter -> domain engine contract
domain engine -> pure Dart only
domain engine -X-> Flutter
adapter -X-> business decisions
pipeline module -X-> runtime writes
```

## 19. Final Definition

Interaction Engine v1 is:

> A snapshot-driven interaction runtime with one deterministic authority layer,
> pluggable stateless semantic modules, interaction-local compressed memory,
> strict idempotency and optimistic concurrency, and recorded transition
> evidence that allows transport and LLM implementations to evolve without
> taking ownership of lifecycle or product truth.
