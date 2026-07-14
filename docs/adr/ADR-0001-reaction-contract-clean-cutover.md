# ADR-0001: Reaction Contract Clean Cutover

Date: 2026-06-29
Status: Accepted, Option D direction approved on 2026-06-30

## Context

The Care Path design contract defines the baby reaction prompt as context for the next parent support utterance, not as a score:

```text
宝宝现在怎么了？
```

Approved product reactions:

```text
配合 / 犹豫 / 不想 / 没反应 / 其他
```

Canonical wire values:

```text
cooperating / hesitant / resisting / no_response / other
```

Current implementation still uses the older four-value practice contract:

```text
calm / engaged / imitated / needs_break
```

The project is still in development. There are no production users, no published legacy clients, and no online historical data that must remain compatible with the old contract. Keeping both contracts alive would add a permanent compatibility surface before there is a production compatibility need.

## Decision

Use Option D: clean cutover to the new five-value reaction contract before Today, Scene, or One-utterance UI implementation starts.

```text
mobile UI/domain
  writes only: cooperating / hesitant / resisting / no_response / other
        │
        ▼
mobile local storage + sync queue
  reads only new contract after one-time dev/test migration or reset
        │
        ▼
backend /api/v1/sync/events
  validates only new five values
        │
        ▼
interaction_events.reaction_type
  DB constraint allows only new five values
```

Required cutover rules:

1. Mobile is new-read/new-write only. It must use only `cooperating`, `hesitant`, `resisting`, `no_response`, and `other`.
2. Backend validation accepts only the new five values.
3. Database constraint and migration must be updated to the new five values.
4. `calm`, `engaged`, `imitated`, and `needs_break` are no longer part of the formal reaction contract.
5. Existing development or test data may be handled only by one-time migration or development reset:

```text
calm / engaged / imitated -> cooperating
needs_break               -> resisting
```

6. Any repository fixture, local Isar seed, backend test row, sync fixture, or other test/dev artifact that still contains old reaction values must be migrated or reset before strict new-only parsing is enabled.
7. Unknown or invalid reaction wire values must never silently fall back to `other`. Backend must reject them. Mobile tests must fail fast. `other` means the user explicitly selected "其他"; it is not an error bucket.
8. The new five values must never be permanently compressed back into the old four values.
9. The ADR chooses clean cutover because the project has no production users, no released legacy client, and no online historical data that must be preserved under the old wire contract.
10. Today, Scene, and One-utterance UI implementation remains blocked until this ADR's clean-cutover implementation plan is ready to execute.

## Rationale

Clean cutover is simpler and lower maintenance than dual-accept compatibility in this stage.

Dual-accept would require the backend, database, mobile parser, bootstrap restore, tests, analytics, and future projections to understand two official reaction vocabularies. That cost is useful when protecting real users or released clients. It is not useful before launch.

The five-value contract also better matches the product semantics. `cooperating`, `hesitant`, `resisting`, `no_response`, and `other` describe the baby's current joinability and context for the next parent support utterance. The old values were tied to the earlier practice/progress framing.

## Consequences

Implementation must update these areas together:

- Mobile reaction domain model, parser, local entity mapping, generated files, UI labels, and tests.
- Sync upload payloads and bootstrap import parsing.
- Backend `ALLOWED_REACTION_TYPES`.
- Database migration that replaces or updates `chk_interaction_events_reaction_type`.
- Backend service/web tests that currently assert old values.
- Any growth, garden, household, mentor, or analytics logic that branches on old reaction values.
- Repository fixtures, local Isar seeds, backend test rows, sync fixtures, and test/dev data setup that currently contain old values.
- Strict parser and validation tests proving invalid values reject or fail fast instead of mapping to `other`.

Development data has two allowed paths:

- Run a one-time migration from old values to new values using the mapping above.
- Reset the development database/local Isar store when preserving data has no value.

After that migration or reset, strict new-only parsing is allowed. Before that migration or reset, enabling strict parsing is expected to surface failures in tests and local development data, not silently hide them.

## Not In Scope

- Dual-accept compatibility for released clients.
- Permanent old-to-new or new-to-old lossy translation in normal runtime.
- UI implementation for Today, Scene, or One-utterance screens before ADR approval.
- Backend-wide event-sourcing rewrite.
- New reaction analytics semantics beyond preserving the raw five-value contract.

## Approval Gate

This ADR must be approved before implementation work starts on:

- Today path current-node surface.
- Scene browse surface.
- One-utterance turn loop.
- Garden trace projection that consumes the new reactions.

Approval of this ADR permits implementation of the clean cutover. It does not approve a compatibility shim that keeps the old four values as a formal contract.
