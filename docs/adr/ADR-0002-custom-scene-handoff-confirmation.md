# Confirm custom-scene handoff from an interactive Care Turn

Custom-scene handoff remains durable until the Care Turn destination resolves the matching generated bundle, establishes its controller snapshot, and makes the starter utterance interactive. `GoRouter.push()` only starts navigation and its completion only observes page exit, so neither can acknowledge handoff; an explicit matching confirmation makes recovery, retries, and cleanup safe across process loss.

## Considered Options

- Treat navigation start or `push()` completion as confirmation.
- Delete the durable intent after registry registration.

Both options lose recoverability when navigation or destination initialization fails.

## Consequences

Ready-for-Handoff UI retries navigation with its existing durable intent and never generates or registers content again. Only a matching confirmation, or explicit user abandonment after confirmation, can remove that intent.
