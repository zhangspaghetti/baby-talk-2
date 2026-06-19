---
phase: 41
slug: mobile-v2-runnable-vertical-slice
status: draft
shadcn_initialized: false
preset: none
created: 2026-06-16
---

# Phase 41 — UI Design Contract

> Visual and interaction contract for Phase 41: mobile_v2 runnable Ritual Room vertical slice.

## 2026-06-19 Interaction Engine Override

This UI is a thin projection of
`41-INTERACTION-ENGINE-CONTRACT.md`. The current reaction-choice UI is a
fallback exposure level, not the terminal product capability.

- Keep Ritual identity and `Shoes on.` stable.
- Make the current complete caregiver utterance the unique output focus.
- Let the parent submit neutral context without leaving the screen.
- Update the utterance in place from the repository-owned interaction snapshot.
- Use progressive disclosure for additional reaction choices and future input
  channels.
- Preserve voice, free-text, future-signal, and strategy capabilities in the
  capability-complete engine while Phase 41 hides their controls.
- Do not render a microphone, free-text field, or strategy tray in this minimal
  projection. The underlying normalized channels must already work end to end
  through the engine/repository contract.
- Do not label contextual input as child performance, compliance, correctness,
  or learning evidence.

### 2026-06-17 Historical Product Correction

This UI contract is controlled by `41-SCHEMATIC-DESIGN.md` wherever older sections describe a four-screen First Entry -> Today Orientation -> Room Support -> Memory Lens flow.

The corrected Phase 41 UI is one `Ritual Room Support` surface for `出门小声音 / 出门穿鞋 / Shoes on.`. D.4.3 uses a short ritual identity header followed by a dominant continuous family talk sheet. It must include a parent-child line illustration, ritual title, Chinese helper, complete caregiver utterances, action / TPR cues, low-pressure audio affordances, reassurance, and quiet exit `先这样就好`.

There is no per-ritual First Entry page in Phase 41. Today Orientation is folded into Room Support copy. Memory Lens, if present, appears only after `先这样就好` and remains optional; Phase 41 does not implement full memory tracking.

Do not use `下一句`, child-performance tracking, child task/performance wording,
lesson progression, checklist/progress UI, or garden/growth/leaf imagery.
Neutral reaction/context selection is allowed and must drive an in-place
utterance update. Short fragments such as `One shoe.` or `Tap tap.` may be
secondary rhythm language, but must not be the primary content the parent is
expected to expand.

### Content Data Contract

All ritual-specific visible content comes through the injected
`RitualContentApi`/`RitualRoomRepository` bootstrap path. Contextual responses
come through `RitualInteractionApi`/`RitualInteractionRepository`. Phase 41
uses mock implementations of both and maps transport DTOs into immutable domain
models. Widgets consume domain models and controller state; they never import
DTOs, mock sources, or fixtures.

The mock response owns:

- room name and routine label
- illustration asset reference and approved status
- ritual title, context label, and Chinese helper
- reassurance copy
- action-list heading/supporting copy
- ordered action beats with complete caregiver utterances and Chinese helpers
- low-pressure context choices
- current context label and current utterance suggestion
- interaction ID, revision, accumulated context summary, and internal strategy
  metadata
- audio availability/reference for the title and each action beat
- quiet exit label
- optional Memory Lens prompt/options if implemented

Widgets may own generic system-state chrome such as a loading indicator or retry mechanism, but they must not duplicate ritual content literals. Widget tests must inject alternate mock content and verify that the UI changes.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none |
| Preset | not applicable — Flutter mobile_v2 phase, no shadcn/components.json |
| Component library | Flutter Material 3 primitives only; no third-party UI kit |
| Icon library | Flutter Material Icons only, line-style where possible |
| Font | Chinese/UI body: PingFang SC -> Noto Sans SC -> Microsoft YaHei -> system sans; English ritual sound: Fraunces-style display if bundled locally, otherwise system serif fallback; no google_fonts package |

Source: `DESIGN.md`, `mobile_v2/pubspec.yaml`, `41-CONTEXT.md`.

`mobile_v2` must re-derive the Warm Paper Kindness design direction locally. Old `mobile/` widgets and theme files are reference-only; do not import old mobile product/domain/presentation code into `mobile_v2/lib`.

---

## Spacing Scale

Declared values (must be multiples of 4):

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4px | Icon gaps, dense inline text/icon gaps |
| sm | 8px | Compact label/body spacing, chip inner gaps |
| md | 16px | Default element spacing and card internal groups |
| lg | 24px | Section padding and spacing between lens sections |
| xl | 32px | Major breaks between room header, content, and CTA group |
| 2xl | 48px | Empty/deferred state vertical breathing room |
| 3xl | 64px | Page-level spacing only; avoid in dense phone screens |

Exceptions: Touch targets are minimum 48x48px. The quiet exit uses at least a
48px invisible hit area and is not a filled primary CTA. Per-moment audio
affordances are minimum 48x48px; the `连起来听` control may use 56x56px when
needed for hierarchy, but must not dominate the utterances. Page horizontal
padding is 20px on normal phones and 16px on narrow phones. Existing old-mobile
12px/20px constants may be used only when re-derived as layout implementation
details; the phase contract remains the 4/8/16/24/32/48/64 scale.

---

## Typography

Use exactly these 4 sizes and 2 weights in Phase 41 runtime UI: 400 regular and 600 semibold. Do not introduce score-like numeric hierarchy or oversized dashboard numerals.

| Role | Size | Weight | Line Height |
|------|------|--------|-------------|
| Body | 15px | 400 | 1.6 |
| Label | 13px | 600 | 1.4 |
| Heading | 20px | 600 | 1.3 |
| Display | 30px | 600 | 1.2 |

Typography rules:

- `Display` is reserved for the ritual title `Shoes on.` only.
- Chinese helper copy uses Body or Heading, never Display.
- Complete action-beat utterances use Heading or Body and receive most of the main list's visual attention.
- Long utterances wrap naturally to multiple lines; they must never truncate or collide with playback controls.
- Labels are for lens names, state chips, and secondary CTA text only.
- Do not use negative letter spacing or viewport-scaled font sizes.

---

## Color

| Role | Value | Usage |
|------|-------|-------|
| Dominant (60%) | #FFF8F0 | App background and page canvas |
| Secondary (30%) | #FFFCF7 | Room surface, cards, sheets, CTA group background |
| Accent (10%) | #FF8C42 | Primary CTA only, one active lens indicator, one focus/selected border per screen |
| Destructive | #B36B5E | Destructive actions only; Phase 41 has no destructive action |

Accent reserved for the primary audio affordance, small focus states, and restrained support emphasis. `先这样就好` must be low-emphasis and should not look like a submit/complete button. Never use accent for scores, counts, reward marks, progress bars, decorative blobs, or all icons.

Additional semantic color contract:

- English ritual sound: #3B8577, used only for `Shoes on.` and small playback-related emphasis.
- English soft surface: #D4E8E3, used only as a restrained inline backing for the fixed sound or audio hint, never as a full-screen background.
- Text primary: #2D2926.
- Text secondary: #6B5E57.
- Text muted: #8A7D76.
- Outline: #D8CFC8.
- Soft warning/resting state: #FFF5D9 background with #6B5E57 text; do not make `今天先放一边` look like failure.

---

## Copywriting Contract

| Element | Copy |
|---------|------|
| Primary quiet exit | 先这样就好 |
| Empty state heading | 出门小声音暂时没准备好 |
| Empty state body | 先回到 Ritual 列表，等这个小声音准备好再打开。 |
| Error state | 这个小声音暂时没准备好。稍后再打开一次。 |
| Destructive confirmation | none — Phase 41 has no destructive action; `今天先放一边` is a soft rest option and must not require confirmation |

Lens copy that is locked for this phase:

| Lens | Required Copy / Contract |
|------|--------------------------|
| Ritual Room Support | Title: `Shoes on.` Helper: `穿鞋啦。` Context: `出门穿鞋`. Body heading: `现在可以这样说`. Play-all: `连起来听`. Action moments: `拿起鞋时` -> emphasized `Let's put your shoes on.` -> `拿起鞋，就说这一句。`; `穿第一只时` -> emphasized `Let's put this shoe on first.` + secondary `Now let's put the other one on.` -> `第一只穿好，再接第二句。`; `穿好后` -> emphasized `Your shoes are on.` + secondary `All done. Let's go.` -> `穿好后，顺口收尾。`. Reassurance: `不用每句都说，跟着当下的动作说一句就够了。` Quiet exit: `先这样就好`. |
| Optional Memory Lens | Only after the parent exits/rests. Prompt: `这句最近有没有更容易从嘴边冒出来？` Options: `有一点，更顺口了`, `还没有，先慢慢来`, `今天先放一边`. Optional and not full memory tracking. |

The static Room Support row above is bootstrap/fallback copy, not the complete
runtime interaction. Current context labels and revised utterances are
API-owned and must be rendered from `RitualInteractionSnapshot`.

Forbidden copy:

- `下一句`
- `孩子有没有照做？`
- `做对了`
- `完成动作`
- child reaction framed as compliance, correctness, learning, or performance
- `完成练习`
- `今日任务`
- `说了 1/3`
- `继续下一句`
- `打卡成功`
- `宝宝学会了吗`
- `进度`
- `积分`
- `连胜`
- `解锁`
- `成长值`
- `AI生成`
- `模型`
- `置信度`

---

## Interaction Contract

Phase 41 is a single support surface over one persistent Ritual Room, not a tabbed app shell and not a four-step flow.

| Surface | Interaction |
|---------|-------------|
| Ritual Room Support | Parent sees stable Ritual identity, one current speakable utterance, and low-pressure contextual choices. Selecting context submits through the controller and updates the utterance in place. Default action-bound language remains available without creating lesson progression. Phase 41 renders no microphone, free-text field, signal control, or strategy tray because this is a UI-restricted projection; all normalized channels are already executable through the engine contract. No progress bar, scoring, child-performance tracking, or completion animation. |
| Optional Memory Lens | May appear only after `先这样就好`. Parent may choose one low-pressure option. Selection may update a local visual placeholder or gentle response, but must not implement production Garden Memory transitions. |

Navigation:

- Initial runnable surface is `Ritual Room Support` for `shoes_on_room_v1`.
- A future Ritual List / collection surface may open the room directly; Phase 41 does not build per-ritual First Entry.
- Memory Lens may be a post-exit optional surface only.
- No bottom navigation, no drawer, no global mentor FAB, no multi-room switcher.
- Back navigation may return to the previous lens without erasing the room.
- All primary actions must be reachable with one thumb near the lower safe area.

Motion:

- Button press feedback may scale to 0.96 for 150ms ease-out and must respect reduced motion.
- Lens transitions use short 150-250ms fade/slide only.
- Do not add celebration animations, confetti, reward growth, or decorative floating blobs.

---

## Component Contract

Implement the smallest local component vocabulary needed for this phase:

| Component | Contract |
|-----------|----------|
| RitualRoomScreen | One scrollable warm Material screen with compact identity header and a dominant unframed action-list surface; no dashboard and no nested cards. |
| RitualIllustration | Approved static parent-child line illustration for `shoes_on`, showing caregiver helping toddler put on shoes. No photo-real style, no plant/leaf/garden/growth imagery, no classroom objects. |
| RitualIdentityHeader | Places a 96-112dp approved illustration beside `Shoes on.`, `出门穿鞋`, and `穿鞋啦。` in about 22-26% of the viewport. It contains no intro paragraph and no `日常动作` label. |
| RitualActionBeatList | Occupies most of the screen and renders exactly three unnumbered action moments as one continuous talk sheet. It uses light spacing and optional hairline separators, not cards or equal lesson rows. One minimum utterance is emphasized per moment; continuations are secondary and use authored semantic line breaks. |
| RitualListenControl | Uses a filled circular play/pause affordance for `连起来听` and each action moment. All hit targets are at least 48x48; utterance text is also tappable. No microphone, waveform recording, progress bar, scoring, or child-response capture. |
| RitualReassurance | Shows `不用每句都说，跟着当下的动作说一句就够了。` as concrete parent-facing permission copy. |
| RitualCurrentUtterance | Renders the latest snapshot-owned context label, complete English utterance, Chinese helper, and one audio affordance as the primary output focus. |
| RitualContextInputTray | Shows a small set of neutral reaction choices inline and additional choices in a bottom sheet; dispatches typed context input without page navigation or child-performance semantics. |
| MemoryOptionGroup | Three 48px-min touch options, visually equal weight; selected option uses one accent border and soft surface response. |
| GentleResponse | Optional local placeholder after Memory Lens selection; copy must be narrative and low-pressure, not a status transition proof. |

Surface rules:

- Prefer one primary room surface per lens. Do not build a dashboard of cards.
- Use icons sparingly: door/shoe/play icons are acceptable if rendered as simple Material line icons. Leaf, sprout, plant, garden, star, medal, trophy, badge, and checkmark marks are forbidden.
- No child-targeted cartoon classroom visuals, badges, rewards, streak marks, or grid of illustrated lessons.

---

## Accessibility And Layout

| Requirement | Contract |
|-------------|----------|
| Orientation | Portrait-first only. |
| Width | Constrain content to max 430px and center on wider test viewports. |
| Touch | All tappable controls use a minimum 48x48px hit area. The quiet exit remains text-like; `连起来听` may use 56x56px for hierarchy. |
| Contrast | Text and CTA colors must meet WCAG AA against assigned surfaces. |
| Semantics | CTA, playback, and Memory Lens options must have explicit semantic labels. |
| Text scale | Support Flutter text scaling up to 1.3 without clipped buttons or overlapping copy. |
| Safe area | Primary CTA group respects bottom safe area. |
| Empty/error | Empty and error states must keep the room recoverable; no blank screen. |

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| shadcn official | none | not applicable — Flutter mobile phase — 2026-06-16 |
| third-party registries | none | not applicable — no registry blocks declared — 2026-06-16 |

---

## Source Decisions Used

| Source | Decisions Used |
|--------|----------------|
| `41-CONTEXT.md` | Ritual Room core object, `shoes_on_room_v1`, mock API content ownership, no bottom nav, no completion/streak/score/Garden-growth semantics, Room Support copy, optional Memory Lens prompt/options. |
| `REQUIREMENTS.md` | R058/R059/R060/R063/R064/R065: family micro-ritual first, Context Seed/Joinability boundary, conservative activation, parent-confirmed low-pressure Garden Memory. |
| `ROADMAP.md` | Runnable Flutter vertical slice acceptance, injected backend-shaped mock API, no deployed backend/AI generation/real Pack/Graph/Runtime/metrics. |
| `DESIGN.md` | Warm Paper Kindness palette, restrained accent use, parent-first tone, no classroom/game/scoring language, Flutter mobile typography and spacing direction. |
| Repo scan | `mobile_v2` is minimal Flutter package; old `mobile/` app theme/widgets are reference-only; no `components.json` or shadcn setup. |

---

## Checker Sign-Off

- [ ] Dimension 1 Copywriting: PASS
- [ ] Dimension 2 Visuals: PASS
- [ ] Dimension 3 Color: PASS
- [ ] Dimension 4 Typography: PASS
- [ ] Dimension 5 Spacing: PASS
- [ ] Dimension 6 Registry Safety: PASS

**Approval:** pending
