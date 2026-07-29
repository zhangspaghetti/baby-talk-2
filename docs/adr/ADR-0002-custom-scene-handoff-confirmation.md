# ADR-0002: Confirm custom-scene handoff from an interactive Care Turn

Date: 2026-07-28
Status: Accepted

Custom-scene handoff remains durable until the Care Turn destination resolves the matching generated bundle, establishes its controller snapshot, and makes the starter utterance interactive. `GoRouter.push()` only starts navigation and its completion only observes page exit, so neither can acknowledge handoff; an explicit matching confirmation makes recovery, retries, and cleanup safe across process loss.

## Considered Options

- Treat navigation start or `push()` completion as confirmation.
- Delete the durable intent after registry registration.

Both options lose recoverability when navigation or destination initialization fails.

## Decision

Only a matching handoff confirmation can complete a successful handoff. Before that confirmation, an explicit user abandonment action with a second user confirmation may cancel the durable intent without treating the handoff as successful.

## Consequences

Ready-for-Handoff UI retries navigation with its existing durable intent and never generates or registers content again. A matching confirmation completes successful handoff and removes the intent. Before confirmation, explicit user abandonment is a separate cancellation path; it removes the intent only after a second user confirmation.
