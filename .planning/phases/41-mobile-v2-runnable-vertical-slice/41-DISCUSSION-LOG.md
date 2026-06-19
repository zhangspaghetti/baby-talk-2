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

---

## 2026-06-17 Product Correction Supersession

The user later revised the Phase 41 product judgment:

- Per-ritual First Entry is canceled; entry belongs to a future Ritual List / collection surface.
- Today Orientation is folded into Room Support copy.
- Room Support is the core Phase 41 surface.
- Ritual Room now includes action-bound family TPR: anchor phrase + optional phrase set + action / TPR cues.
- `Shoes on.` is the anchor phrase, not the only line.
- At that point Phase 41 used a backend-shaped `MockRitualApi` for `shoes_on`;
  ritual-specific content was not hardcoded in widgets/controllers. The later
  2026-06-19 correction supersedes the broad reaction prohibition: neutral
  context input is now required, while child-performance tracking remains
  forbidden.
- Memory Lens, if present, appears only after the parent exits/rests.

See `41-SCHEMATIC-DESIGN.md` for the controlling design gate.
## 2026-06-18 D.4.3 UX Correction

- The D.4.2 prototype was not approved because its 30-35% identity header and
  three equal action rows still resembled a content-detail page followed by
  three audio lessons.
- D.4.3 limits the header to about 22-26%, removes the intro and `日常动作`,
  and makes the first English utterance the first strong visual focus.
- The body uses `现在可以这样说` and `连起来听`.
- `拿起鞋时`, `穿第一只时`, and `穿好后` are time anchors inside one
  continuous family talk sheet, not numbered lesson steps or cards.
- Each action moment emphasizes one minimum complete utterance and visually
  demotes optional continuations using authored semantic line breaks.
- Audio controls are at least 48x48, use one control per action moment, expose
  play/pause state, and have no progress bar.
- Reassurance is
  `不用每句都说，跟着当下的动作说一句就够了。`
- `先这样就好` is a quiet text action, not a completion CTA.
- The D.4.3 ImageGen preview was generated and iterated in the active Codex
  thread. It remains pending user approval and is not an execution target.

## 2026-06-18 Mobile V2 Engineering Authority

- `mobile_v2/AGENTS.md` is the executor auto-discovery entry.
- `mobile_v2/CODING_STANDARDS.md` is the complete Flutter application standard,
  including architecture, feature-first artifact organization, state ownership,
  API/repository boundaries, UI, accessibility, i18n, assets/audio, privacy,
  observability, performance, testing, dependencies, CI, and release rules.
- Every Phase 41 task explicitly lists both files in `<read_first>`.
- Durable feature ownership is `features/ritual_room`; historical
  `first_micro_ritual` naming is forbidden.
- Demo content flows through
  `MockRitualContentApi -> RitualRoomResponse -> RitualRoomMapper ->
  RitualRoomRepositoryImpl -> RitualRoomContent -> RitualRoomController -> UI`.
- Presentation code must not import DTOs, the mock data source, mapper
  implementation, or fixture JSON.

## 2026-06-19 Interaction Engine Correction

- The user clarified that the product is a long-term Interaction Engine, not a
  Phase 1 reaction-to-sentence utility.
- Durable inputs include reaction selection, voice observation, free text,
  future signals, and strategy preference.
- Interaction state accumulates and strategy can evolve across turns.
- UI is a thin, low-cognitive-load projection; hiding a capability is allowed,
  deleting it from the architecture is not.
- Phase 41 UI visibly exposes only neutral reaction selection and updates the
  current utterance in place.
- The Phase 41 engine executes normalized reaction, voice transcript, free text,
  future signal, and strategy preference channels. Microphone/STT acquisition,
  signal producers, and additional controls are UI/input-adapter scope only.
- `RitualContentApi` remains responsible for room bootstrap.
  `RitualInteractionApi` owns contextual turn advancement.
- Reaction/context input is not child-performance tracking and must never score
  compliance, correctness, learning, or completion.
- `41-INTERACTION-ENGINE-CONTRACT.md` is the controlling architecture document.

## 2026-06-19 Capability-complete Clarification

- Phase 41 is system-capability complete and presentation restricted.
- UI-hidden never means engine-disabled.
- Every normalized input channel must map to a transport request, advance the
  mock engine, and return a revised snapshot.
- Per-channel and mixed-channel tests are required.
- Future UI evolution opens controls/adapters over the stable contract; it does
  not add missing engine channels or redesign the engine.
