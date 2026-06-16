# Phase 41: mobile-v2-runnable-vertical-slice - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-16T21:23:32.2293570+08:00
**Phase:** 41-mobile-v2-runnable-vertical-slice
**Areas discussed:** First Ritual Seed, Local Fixture Truth, Four-Surface Flow, Practice + Garden Moment

---

## First Ritual Seed

| Option | Description | Selected |
|--------|-------------|----------|
| `Shoes on` | vNext architecture example; frequent, short, action-bound, no baby response needed. | yes |
| Other micro-ritual | Could choose diaper, bath, sleep, or another routine. | |

**User's choice:** Use `Shoes on` as the first micro-ritual.
**Notes:** The user selected it because it comes from the vNext architecture doc, is high-frequency, short, action-bound, needs no baby response, supports entry -> room support -> memory prompt, and is unlikely to become teaching/testing.

---

## Local Fixture Truth

| Option | Description | Selected |
|--------|-------------|----------|
| One Ritual Room as truth | Fixture centers on one active Ritual Room with Context Seed, Joinability, fake Governor decision, and active Garden Memory state. | yes |
| Phrase/activity progress | Old-style product truth around phrase IDs, activity paths, progression, completion, streak, and growth. | |
| Multi-room runtime | Multiple rooms rendered and organized in Phase 41. | |

**User's choice:** Use a single-room fixture centered on `shoes_on_room_v1`.
**Notes:** The fixture may be structurally future-compatible but renders only one room. Include fake Context Seed, Joinability hypothesis, `allow_activation`, active Garden Memory state, and weak-signal-free parent prompt opportunity. Exclude phrase/activity/progress/streak/growth/reward semantics.

---

## Four-Surface Flow

| Option | Description | Selected |
|--------|-------------|----------|
| Ritual Room lenses | First Entry, Today Orientation, Room Support, and Memory Lens are semantic lenses over one room. | yes |
| Literal old surfaces | Onboarding -> Home -> Practice -> Garden as old mobile page structure or required lifecycle. | |
| Bottom navigation | Multi-surface app organization from the start. | |

**User's choice:** Lock the higher-level schematic that Phase 41 is about `Ritual Room`, not old surfaces.
**Notes:** First Entry creates/opens the first room; Today Orientation shows the current active room and why one tiny sound is enough; Room Support helps the parent say the sound; Memory Lens gently reviews the same room. No bottom navigation in Phase 41.

---

## Practice + Garden Moment

| Option | Description | Selected |
|--------|-------------|----------|
| Low-pressure support and memory prompt | Help the parent say one sound naturally once, then ask a gentle active-state memory question. | yes |
| Training/completion flow | Completion CTA, daily task language, phrase counts, next phrase, check-in success, or child-learning check. | |
| Full Garden transitions | Implement production state transitions from prompt options. | |

**User's choice:** Room Support should feel like "help me say this naturally once"; Memory Lens should ask one low-pressure parent-confirmation prompt.
**Notes:** Room Support shows `Shoes on.`, `穿鞋啦。`, action binding, no-response reassurance, and secondary variants. CTAs should be `我知道怎么说了`, `先这样就好`, or `看看这个声音怎么留在家里`. Memory Lens prompt: `这句最近有没有更容易从嘴边冒出来？` with options `有一点，更顺口了`, `还没有，先慢慢来`, `今天先放一边`. In Phase 41, responses can update a local placeholder only.

---

## the agent's Discretion

- Exact file names, class names, route implementation, state holder, widget layout, and test organization.
- Local visual response behavior after Memory Lens option selection, as long as it remains placeholder-only and low-pressure.
- Visual implementation details, provided old mobile assets are re-derived and not imported as runtime truth.

## Deferred Ideas

- Bottom navigation.
- Multi-room organization.
- Future room activation flows beyond first entry.
- Full Garden Memory transition mechanics.
- Backend, AI, real Strategy Pack, real Strategy Graph, production Runtime Agent, and production transfer metrics.
