# Phase 41 Reaction Submission and Reconciliation Design

**Date:** 2026-06-21  
**Status:** Approved for gap planning  
**Source:** `.planning/phases/41-mobile-v2-runnable-vertical-slice/41-VERIFICATION.md`

## Scope

This design closes only the two blocking Phase 41 verification gaps:

1. Rapid repeated reaction taps can create concurrent same-revision submissions and allow a later conflict to hide an earlier successful result.
2. Recovery after an unknown request outcome creates a new event instead of replaying the original immutable command.

The following verification warnings remain out of scope:

- future-signal value normalization
- hardcoded visible copy
- snapshot numeric ranges
- mutable capability sets
- duplicate room-content reads
- broad engine exception handling

Handling non-unknown repository exceptions in the notifier is required only to protect the same-event retry contract. It does not resolve the separate broad-catch warning.

## Core Contract

Reaction submission is single-flight for one Ritual Room stream.

```text
Only the notifier may mint reaction InputEvents,
and only after the single-flight guard accepts the tap.
```

Same-event retry is an unknown-outcome reconciliation mechanism, not a generic recoverable-error mechanism.

```text
same eventId retry = resolve idempotency uncertainty
new eventId submit = user makes a new authoritative attempt
```

An unknown outcome exists only when the request may have reached the engine but the client did not receive an authoritative result. Any returned `AdvanceResult` is authoritative, including `AdvanceApplied`, `AdvanceDuplicateIgnored`, and every `AdvanceRejected` variant.

## Ownership and Boundaries

`BabyTalkApp` owns gesture wiring only:

- `submitReaction(reaction)`
- room load/reload
- `retryPendingEvent()`

It must not:

- create or inspect `InputEvent`
- call `InteractionInputFactory`
- allocate or inspect `eventId`
- supply `interactionId` or `expectedRevision`
- access the pending command envelope

`RitualRoomSessionNotifier` owns:

- single-flight admission
- reaction `InputEvent` creation after admission
- event ID allocation through the injected factory
- command-envelope retention
- repository submission
- authoritative-result handling
- unknown-outcome reconciliation
- exact-command retry

The notifier privately retains at most one active snapshot-advancing command for the current Ritual Room stream:

```text
InputEvent + interactionId + expectedRevision
```

The command envelope must never enter public UI state.

## Submission Ordering

The initial submission sequence is fixed:

```text
guard accepted
=> create InputEvent / eventId
=> capture interactionId + expectedRevision
=> save active command envelope
=> enter submitting state
=> call repository
```

Saving the complete envelope before the repository call guarantees that an `InteractionOutcomeUnknownException` can preserve and replay the original request.

While a command is submitting, awaiting reconciliation, or being retried:

- new reaction taps are no-ops
- repeated retry taps are no-ops
- no event is created
- no event ID is allocated
- no command is queued, merged, replaced, or automatically submitted later

Reaction input is not a desired-state update and must not be queued. Automatically submitting a delayed reaction could create a stale or ghost interaction advancement.

## Unknown-Outcome Classification

The data boundary must use an explicit exception:

```dart
final class InteractionOutcomeUnknownException implements Exception {
  const InteractionOutcomeUnknownException({
    required this.reason,
    this.cause,
  });

  final InteractionOutcomeUnknownReason reason;
  final Object? cause;
}

enum InteractionOutcomeUnknownReason {
  timeoutAfterDispatch,
  responseLostAfterDispatch,
  connectionClosedAfterDispatch,
}
```

Only `InteractionOutcomeUnknownException` may preserve the command for same-event retry.

It is valid only when:

1. the request crossed the data boundary and may have reached the engine; and
2. the client received no authoritative result.

Examples include timeout after dispatch, response loss after dispatch, or connection closure after dispatch.

It must not classify:

- event-factory failures
- client validation failures
- serialization failures before dispatch
- unsupported input
- mapper or repository programming defects
- requests known not to have been dispatched
- an engine-returned `AdvanceRejected`
- an authoritative engine pipeline failure
- any API response that can be mapped to an authoritative result

All other exceptions clear the active command and enter ordinary failure handling. They do not permit same-event retry.

## State Model

`RitualRoomSubmitting` adds the selected reaction so the UI preserves immediate feedback while controls are locked.

`RitualRoomUnknownOutcome` is a distinct reconciliation state, not a recoverable-failure flag. It carries only:

- room content
- the last authoritative snapshot
- selected reaction
- `isRetrying`

It must not carry:

- `InputEvent`
- `eventId`
- `interactionId`
- `expectedRevision`
- the private command envelope

The UI can request `retryPendingEvent()` but cannot supply or inspect the event being replayed.

## State Transitions

| Current state | Operation or result | Next state | Active command |
|---|---|---|---|
| Ready or authoritative failure | accepted `submitReaction` | Submitting | Create and retain |
| Submitting | new reaction | Unchanged, no-op | Retain |
| Submitting | Applied or DuplicateIgnored | Ready with returned snapshot | Clear |
| Submitting | authoritative Rejected | RecoverableFailure with latest authoritative snapshot when present | Clear |
| Submitting | `InteractionOutcomeUnknownException` | UnknownOutcome | Retain |
| Submitting | any other exception | RecoverableFailure | Clear |
| UnknownOutcome | new reaction | Unchanged, no-op | Retain |
| UnknownOutcome | `retryPendingEvent` | UnknownOutcome with `isRetrying=true` | Replay unchanged |
| Retrying | reaction or repeated retry | Unchanged, no-op | Retain |
| Retrying | another unknown outcome | UnknownOutcome with `isRetrying=false` | Retain |
| Retrying | any authoritative result | Ready or RecoverableFailure | Clear |
| Retrying | any non-unknown exception | RecoverableFailure | Clear |

Any authoritative `AdvanceResult` clears the active command. This includes revision conflict, pipeline failure represented as `AdvanceRejected`, duplicate ignored, and successful application.

For `AdvanceRejected.revisionConflict`, the notifier adopts the returned latest authoritative snapshot. If the user still wants to express that reaction, a later deliberate tap creates a new event against the new revision.

## Exact Retry Semantics

Unknown-outcome retry replays the original command envelope exactly:

```text
same InputEvent
same eventId
same interactionId
same expectedRevision
```

Retry must not rebase the original event onto the UI's current revision.

The engine's existing order remains required:

1. find and compare the idempotency receipt
2. return `AdvanceDuplicateIgnored` for an identical processed event
3. reject conflicting reuse of an event ID
4. validate `expectedRevision`
5. apply or reject the new event authoritatively

Receipt-before-revision permits an exact retry carrying the old expected revision to reconcile successfully after the first request committed but its response was lost.

## UI Behavior

Submitting, UnknownOutcome, and retrying states lock every reaction-producing control:

- inline reaction buttons are disabled
- the “更多情况” entry is disabled
- any open additional-choice action cannot create a reaction
- the selected reaction remains visibly selected

The lock is scoped to snapshot-advancing input for the current Ritual Room stream. It is not a global screen freeze:

- the current phrase remains readable
- playback remains available
- quiet exit remains available

UnknownOutcome shows:

```text
刚才这次没有确认成功，可以再试一次
```

It also shows a dedicated retry action. The retry action calls `retryPendingEvent()` and is disabled while retrying.

## Lifecycle Boundaries

Room switch, reload, or notifier disposal clears the local active command and does not submit a replacement event.

```text
Clearing the local command abandons local retry capability.
It does not prove that the engine did not commit the original event.
```

After reload, any committed result must be reflected through the newly loaded authoritative snapshot. The client must not silently retry the abandoned event with either its old envelope or a newly minted one.

## Test Design

Implementation follows a red-green-refactor sequence.

### Single-flight notifier regression

Use a controlled completer to keep the first repository call in flight. Invoke `submitReaction` twice before completing it.

Required assertions:

```text
factory called once
eventId allocated once
repository.advance called once
no queued reaction
no second event
second call is a complete no-op
authoritative applied snapshot is retained
```

### Unknown-outcome exact replay

The first repository call records the complete command and throws `InteractionOutcomeUnknownException`. Retry returns `AdvanceDuplicateIgnored`.

Required assertions:

```text
state becomes RitualRoomUnknownOutcome
same InputEvent is replayed
same eventId is replayed
same interactionId is replayed
same expectedRevision is replayed
no new eventId is allocated
returned authoritative snapshot becomes Ready
private command is cleared
```

### Authoritative and non-unknown outcomes

Tests must prove:

- `AdvanceRejected.revisionConflict` clears the command and adopts its latest snapshot
- authoritative `pipelineFailed` clears the command
- every other authoritative `AdvanceResult` clears the command
- every non-unknown exception clears the command
- a later deliberate reaction after those outcomes creates a new event ID
- a repeated unknown outcome retains the exact command for a later retry

### UI and widget behavior

Tests must prove:

- Submitting, UnknownOutcome, and retrying disable every reaction choice and the additional-choice entry
- selected reaction remains observable
- UnknownOutcome copy and retry action are visible
- retry is disabled while retrying
- playback and quiet exit remain usable
- UI state exposes no command-envelope fields
- the obsolete expectation that retry creates a different event ID is removed

### Lifecycle and ownership boundaries

Tests or source assertions must prove:

- reload, room switch, and dispose clear local retry capability
- none of those lifecycle operations creates a replacement event
- `BabyTalkApp` neither constructs `InputEvent` nor calls the input factory
- public UI state contains no `InputEvent`, `eventId`, `interactionId`, or `expectedRevision`
- receipt lookup remains before expected-revision validation in the engine

## Verification

The gap closes only when all of the following pass:

- focused notifier/provider tests
- focused Ritual Room screen and widget tests
- Phase 41 interaction-engine contract tests
- `flutter analyze --no-pub`
- the complete `mobile_v2` Flutter test suite
- `dart run tool/verify_mobile_v2_semantic_firewall.dart`
- `dart run tool/verify_activation_governor_contract.dart`

## Acceptance Contract

```text
This gap closure is accepted only when tests prove that ignored taps create no event,
unknown outcomes replay the exact original command,
and no UI or app layer can access the private command envelope.
```
