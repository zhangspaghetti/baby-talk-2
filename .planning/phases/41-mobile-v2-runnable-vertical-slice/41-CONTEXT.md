# Phase 41: mobile-v2-runnable-vertical-slice - Context

**Gathered:** 2026-06-16T21:23:32.2293570+08:00
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 41 builds a runnable Flutter `mobile_v2` vertical slice around one persistent `Ritual Room`: `shoes_on_room_v1`. The phase must demonstrate the first family sound through First Entry, Today Orientation, Ritual Room Support, and Memory Lens, using local fixture/fake data only.

The core object is not Onboarding, Home, Practice, Garden, phrase card, activity, or practice session. Those old surfaces are reinterpreted only as semantic lenses over the same Ritual Room. This phase must prove the product loop can run without old phrase/activity/completion/streak/Garden-growth semantics.

Phase 41 must close with runnable product construction evidence: Flutter app entrypoint, page/state flow, local fixture, widget/golden/smoke tests, and passing Phase 39 semantic firewall plus Phase 40 Activation Governor / Garden Memory verifier guards. Backend, AI, real Strategy Pack, real Strategy Graph, production Runtime Agent, production transfer metrics, bottom navigation, multi-room organization, and full Garden Memory transition mechanics are out of scope.

</domain>

<decisions>
## Implementation Decisions

### Ritual Room Schematic
- **D-01:** Phase 41's core product object is a `Ritual Room`: a persistent context space for one family sound.
- **D-02:** `Ritual Room` is not a phrase card, activity, one-off practice session, or four-step task flow.
- **D-03:** Old Onboarding, Home, Practice, and Garden must not be reproduced as old mobile page structure. In Phase 41 they are semantic lenses over one Ritual Room.
- **D-04:** The four Phase 41 lenses are First Entry, Today Orientation, Room Support, and Memory Lens.
- **D-05:** Do not design a required lifecycle where every future ritual room must pass through Onboarding -> Home -> Practice -> Garden. Future rituals should come through activation, not onboarding.
- **D-06:** Phase 41 can implement a simple guided path: First Entry -> Today Orientation -> Ritual Room Support -> Memory Lens.
- **D-07:** Do not add bottom navigation in Phase 41. Use a minimal route stack or single guided vertical slice. Bottom navigation and multi-room organization belong after the first room feels right.

### First Ritual Seed
- **D-08:** Use `Shoes on` as the first micro-ritual because it comes from the vNext architecture doc example, is frequent, short, action-bound, does not need a baby response, demonstrates entry/support/memory well, and is less likely to become teaching/testing.
- **D-09:** The Phase 41 fixture locks these values:
  - `ritualRoomId`: `shoes_on_room_v1`
  - `roomName`: `出门小声音`
  - `fixedSound`: `Shoes on.`
  - `routineAnchor`: `出门穿鞋`
  - `actionBinding`: `拿鞋、套脚、轻拍鞋`
  - `toneHint`: `short, warm, action-bound`
  - `childNoResponseRule`: `宝宝不用跟读、回答或看 app；父母继续穿鞋动作即可`
  - `softVariant`: `One shoe. Two shoes.` / `Tap tap.`
  - `doNotUseWhen`: `宝宝强烈抗拒、父母说出口很别扭、当下太赶`
  - `initialState`: `active` only because fake Governor returns `allow_activation`
- **D-10:** The slice must not imply the baby needs to repeat, answer, look at the app, or prove learning.

### Local Fixture Truth
- **D-11:** Local fixture truth centers on one active Ritual Room, not phrase/activity progress.
- **D-12:** Include exactly one rendered active room for Phase 41, while allowing a future-compatible collection shape internally if useful.
- **D-13:** The fixture should include:
  - one active Ritual Room
  - one fake Context Seed: parent preparing shoes / child near door
  - one fake Joinability hypothesis: `action_bound` + `routine_ready`
  - one fake Governor decision: `allow_activation`
  - one Garden Memory state: `active`
  - one weak-signal-free parent prompt opportunity
- **D-14:** Do not include `phraseId` as product truth, `activityId` / path / space as product progression, `completedPhraseCount`, `nextPhraseId`, streak, growth stage, reward, unlock, fertilizer, or progress semantics.
- **D-15:** The fixture may be structurally multi-ready, but the runnable slice must render a single room only.

### Lens Flow
- **D-16:** First Entry replaces old Onboarding. It is only used to create/open the first Ritual Room.
- **D-17:** Today Orientation replaces old Home dashboard. It orients the parent to the current active room and why one tiny sound is enough for today.
- **D-18:** Room Support replaces old Practice. It is support mode inside the Ritual Room and helps the parent say the fixed sound with action binding and no-response reassurance.
- **D-19:** Memory Lens replaces old Garden result screen. It gently reviews the same room and asks whether the sound is becoming easier, should rest, or belongs to family life.
- **D-20:** Today Orientation before Room Support should show the active room `出门小声音`, state that today's job is small, and use a CTA to enter support mode.
- **D-21:** Today Orientation after Room Support must not say complete or success. Acceptable framing: `这个小声音已经在你们的出门 routine 里了。想先看看花园记忆吗？`
- **D-22:** After Room Support, CTAs may point to memory prompt, rest, or back to the room, but must not imply completion or scoring.

### Room Support
- **D-23:** Room Support should feel like "help me say this naturally once", not training.
- **D-24:** Room Support should show:
  - fixed sound: `Shoes on.`
  - Chinese helper: `穿鞋啦。`
  - action binding: `套鞋/轻轻拍拍鞋的时候说`
  - no-response reassurance: `宝宝不用跟读，也不用回应。你继续穿鞋就好。`
  - optional soft variant, visually secondary
- **D-25:** Acceptable Room Support CTAs include `我知道怎么说了`, `先这样就好`, and `看看这个声音怎么留在家里`.
- **D-26:** Avoid `完成练习`, `今日任务`, `说了 1/3`, `继续下一句`, `打卡成功`, and `宝宝学会了吗`.

### Memory Lens
- **D-27:** Phase 41 Memory Lens should ask one low-pressure parent-confirmation prompt, not record completion.
- **D-28:** Use active-state memory prompt only in Phase 41. Full Garden Memory transition mechanics are later work.
- **D-29:** Suggested prompt: `这句最近有没有更容易从嘴边冒出来？`
- **D-30:** Suggested options:
  - `有一点，更顺口了`
  - `还没有，先慢慢来`
  - `今天先放一边`
- **D-31:** These options may update a local visual placeholder or show a gentle response in Phase 41, but must not implement full production state transitions.

### Acceptance and Proof
- **D-32:** The runnable app must demonstrate one Ritual Room through First Entry, Today Orientation, Room Support, and Memory Lens.
- **D-33:** The implementation must not reproduce old Onboarding/Home/Practice/Garden semantics.
- **D-34:** The implementation must not use completion, streak, score, growth, phrase progression, or activity dashboard language.
- **D-35:** Acceptance must include runnable Flutter app evidence, widget/golden/smoke tests for the lens path, and passing Phase 39 semantic firewall plus Phase 40 Activation Governor / Garden Memory verifier guards.

### the agent's Discretion
- Planner/executor may choose exact file names, class names, route mechanics, local state holder, widget structure, and test layout as long as the Ritual Room decisions above remain the product truth.
- Planner/executor may choose the visual composition and copy refinements within the locked tone: parent-facing, warm, low-pressure, action-bound, and non-scoring.
- Planner/executor may re-derive selected warm visual/audio interaction patterns from old `mobile/`, but must not import old mobile product/domain/data/presentation code into `mobile_v2/lib`.
- Planner/executor may decide whether the local Memory Lens option response is a visual placeholder, banner, or local in-memory field, as long as it is not production Garden Memory transition truth.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 41 Scope
- `.planning/ROADMAP.md` — Phase 41 construction rule, goal, plan bullets, and explicit exclusion of backend, AI, real Strategy Pack/Graph/Runtime, and real transfer metrics.
- `.planning/PROJECT.md` — current M010 construction-first state and project-level product promise.
- `.planning/REQUIREMENTS.md` — active R058, R059, R060, R063, R064, and R065 requirements that Phase 41 must satisfy.
- `.planning/STATE.md` — current focus and Phase 41 restart context.

### Prior Phase Contracts
- `.planning/phases/39-vnext-family-english-micro-ritual/39-SPEC.md` — locked vNext product thesis, micro-ritual unit, supersession boundaries, and old semantic exclusions.
- `.planning/phases/39-vnext-family-english-micro-ritual/39-CONTEXT.md` — mobile_v2 boundary, surface rewrite order, semantic firewall, and reuse policy.
- `.planning/phases/39-vnext-family-english-micro-ritual/39-SUPERSESSION-PROOF.md` — proof that old phrase/activity/completion/streak/Garden-growth semantics are deprecated or reference-only.
- `.planning/phases/40-activation-governor-garden-memory/40-SPEC.md` — locked Activation Governor and Garden Memory requirements, boundaries, and verifier failure modes.
- `.planning/phases/40-activation-governor-garden-memory/40-CONTEXT.md` — Activation Governor authority seams, Garden Memory parent-confirmation rules, weak-signal limits, and decision/state matrix.
- `.planning/phases/40-activation-governor-garden-memory/40-ACTIVATION-GOVERNOR-CONTRACT-PROOF.md` — Phase 40 proof artifact for the authority and memory contract.

### vNext Product Source
- `docs/Baby_Talk_Product_Architecture_Spec_vNext.md` — canonical source for `Shoes on`, Family English Micro-ritual fields, Context Seed / Joinability, Activation Governor, Garden Memory, and Parent-confirmed Micro-ritual Transfer.
- `.planning/research/questions.md` — open research prompts around low-shame Garden confirmation and conservative activation; useful for keeping Phase 41 Memory Lens low-pressure.

### Runtime Boundary and Verifier Guards
- `mobile_v2/pubspec.yaml` — current independent Flutter package boundary.
- `mobile_v2/lib/vnext_semantic_boundary.dart` — current vNext semantic anchor file; Phase 41 expands this into a runnable app.
- `mobile_v2/reference_assets/README.md` — quarantine rule for copied wording/audio/design samples.
- `mobile_v2/legacy_reference/README.md` — quarantine rule for old mobile snippets.
- `tool/verify_mobile_v2_semantic_firewall.dart` — Phase 39 guard that must pass after adding runtime code.
- `test/tool/verify_mobile_v2_semantic_firewall_test.dart` — semantic firewall root tests.
- `test/features/vnext/mobile_v2_surface_contract_test.dart` — old-surface semantic rejection fixtures.
- `tool/verify_activation_governor_contract.dart` — Phase 40 guard that must pass after adding runtime code.
- `test/tool/verify_activation_governor_contract_test.dart` — Activation Governor / Garden Memory contract tests.
- `test/features/vnext/activation_governor_contract_surface_test.dart` — surface activation-intent and Garden pressure-copy rejection fixtures.

### Reference-Only Old Mobile Patterns
- `mobile/lib/app/theme/app_theme.dart` — warm tone, colors, typography, and shadows may be re-derived into `mobile_v2`; do not import directly into runtime truth.
- `mobile/lib/app/widgets/app_audio_button.dart` — audio-button interaction pattern may inform Room Support; do not import directly.
- `mobile/lib/features/practice/presentation/widgets/phrase_card.dart` — reference-only pronunciation/playback layout material; phrase/completion semantics are forbidden.
- `mobile/lib/features/practice/presentation/widgets/activation_frame.dart` — reference-only warm framing pattern; old activation framing must be re-derived around Ritual Room support.
- `mobile/lib/main.dart` — reference-only Flutter app entrypoint pattern; old app wiring and providers are not vNext truth.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `mobile_v2/pubspec.yaml` gives a minimal independent Flutter package with no product dependencies beyond Flutter.
- `mobile_v2/lib/vnext_semantic_boundary.dart` is the current runtime boundary anchor and can be expanded into app/domain/widget code.
- `tool/verify_mobile_v2_semantic_firewall.dart` and `tool/verify_activation_governor_contract.dart` are mandatory guards for Phase 41 runtime code.
- Old `mobile/` theme, audio button, phrase card, and activation frame files are useful visual/interaction references only; copied material must be semantically rebuilt inside `mobile_v2`.

### Established Patterns
- vNext active runtime truth lives under `mobile_v2/lib`; old `mobile/` remains readable reference only.
- Runtime code must avoid old terms and old product meanings even when implementing familiar-looking surfaces.
- Existing proof style favors repo-owned Dart verifier CLIs plus focused test fixtures over docs-only acceptance.
- The current package is intentionally sparse, so Phase 41 should add the smallest runnable shell rather than porting the old mobile app.

### Integration Points
- Add a Flutter app entrypoint under `mobile_v2/lib` and tests under `mobile_v2/test` and/or root vNext test paths.
- Ensure any runtime copy mentioning activation intent either consumes the fake Governor `allow_activation` decision explicitly or avoids action-now activation language.
- Keep reference/quarantine paths out of `mobile_v2/lib` imports.
- Verification should include the new app flow tests plus the existing Phase 39 and Phase 40 verifier commands.

</code_context>

<specifics>
## Specific Ideas

- The dominant schematic design phrase is: "Ritual Room first; old surfaces are lenses."
- First Room: `出门小声音` / `Shoes on.`
- First Entry creates or opens `shoes_on_room_v1`; it is not a recurring onboarding model for future rooms.
- Today Orientation says one tiny sound with one action is enough for today.
- Room Support helps the parent say `Shoes on.` during the shoe action, with `穿鞋啦。` as Chinese helper and no baby-response requirement.
- Optional soft variants are `One shoe. Two shoes.` and `Tap tap.`, always secondary.
- Memory Lens prompt: `这句最近有没有更容易从嘴边冒出来？`
- Memory Lens options: `有一点，更顺口了`, `还没有，先慢慢来`, `今天先放一边`.
- The local fixture can include a fake Context Seed, Joinability hypothesis, Governor decision, and Garden Memory state, but only the single active room is rendered.

</specifics>

<deferred>
## Deferred Ideas

- Bottom navigation and multi-room organization are deferred until after the first Ritual Room works.
- Full Garden Memory transition mechanics are deferred; Phase 41 may only show local visual placeholder responses.
- Future Ritual Room activation flows are deferred; Phase 41 First Entry opens only the first room.
- Backend integration, AI, real Strategy Pack, real Strategy Graph, production Runtime Agent, and transfer metrics remain deferred to later M010 phases.
- Phase 42 owns refinement of low-pressure interaction schematic, layout rhythm, accessible touch flow, and screenshot/golden polish.
- Phase 43 owns hardening local fixture/state into replaceable adapters and a testable local state backbone.

</deferred>

---

*Phase: 41-mobile-v2-runnable-vertical-slice*
*Context gathered: 2026-06-16T21:23:32.2293570+08:00*
