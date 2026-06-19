# Phase 41: mobile_v2 Runnable Interaction Engine Vertical Slice - Research

## 2026-06-19 Locked Supersession

This file began as 2026-06-16 research and contains historical material. For execution, the later locked authorities below take precedence over every conflicting statement, recommendation, example, path, diagram, test map, and security classification in this file:

1. `.planning/phases/41-mobile-v2-runnable-vertical-slice/41-INTERACTION-ENGINE-CONTRACT.md`
2. `docs/superpowers/plans/2026-06-19-interaction-engine-v1.md`
3. `docs/superpowers/plans/2026-06-19-interaction-engine-flutter-riverpod.md`

The current `41-CONTEXT.md`, `41-SCHEMATIC-DESIGN.md`, `41-PATTERNS.md`, `41-UI-SPEC.md`, `mobile_v2/AGENTS.md`, and `mobile_v2/CODING_STANDARDS.md` remain binding where they do not conflict with those three later authorities.

The following older conclusions are historical and superseded, not executable instructions: no-new-package; no-Riverpod/plain-controller; no repository or adapter layer; `first_micro_ritual` feature paths; First Entry -> Today Orientation -> Room Support -> Memory Lens as a required four-screen flow; static content-only or reaction-to-sentence behavior; and V6-N-A/no-cryptography reasoning that would forbid `crypto` for non-secret SHA-256 fingerprints. Current Phase 41 uses the `ritual_room` feature, a direct D.4.5 Room Support projection, pure-Dart `InteractionEngine` authority, thin DTO/API/repository adapters, and a later Riverpod composition/session plan.

Dependency order is locked: Plan 41-01 installs only `crypto:^3.0.7`; the first Riverpod plan, 41-08, later installs `flutter_riverpod:^3.3.0`, updates the lockfile and Riverpod-specific coding standards, creates `riverpod_smoke_test.dart`, and proves the smoke test before provider implementation.

**Researched:** 2026-06-16; locked supersession applied 2026-06-19
**Domain:** Flutter `mobile_v2` runnable Interaction Engine vertical slice with vNext semantic/activation guardrails
**Confidence:** HIGH for the locked 2026-06-19 authorities; historical sections below are context only.

## Current Interaction Engine Direction

Current planning separates room bootstrap from interaction advance, permits neutral contextual reaction selection, accumulates interaction revision, and requires executable engine handling for reaction, normalized voice observation, free text, future signal, and strategy preference. Only the Phase 41 UI exposure is restricted. `InteractionEngine` is the sole lifecycle/consistency authority; DTO, mock API, repository, Riverpod providers, and the one session Notifier are adapters/projections.

### 2026-06-17 Historical Product Correction

This research artifact predates the TPR / action-bound language correction. Treat any older reference to First Entry, Today Orientation, a four-lens tap-through flow, or `One shoe. Two shoes.` as superseded by `41-SCHEMATIC-DESIGN.md`.

The current Phase 41 product truth is one mock-API-backed `shoes_on` `Ritual Room Support` surface with anchor phrase, full phrase set, action / TPR cues, approved static line illustration metadata, low-pressure audio affordance, no-response reassurance, and quiet exit `先这样就好`.

All ritual-specific content must come through an injected `RitualContentApi`.
Current plans implement `MockRitualContentApi`, transport DTOs, a mapper,
repository, immutable domain models, loading/error states, and
payload-substitution tests. A deployed backend and AI generation remain deferred.

<user_constraints>
## Historical User Constraints Snapshot

This section preserves the 2026-06-16 discussion snapshot for traceability. It is historical, not a current locked-decision source. Any First Entry, Today Orientation, four-lens/four-screen, local-controller, or Memory Lens requirement below is superseded by the 2026-06-19 Locked Supersession and the current `41-CONTEXT.md`; retain only non-conflicting product semantics such as ritual-first, low-pressure, non-scoring, and fake-Governor evidence.

### Historical Decisions (Superseded Where Conflicting)

#### Ritual Room Schematic
- **D-01:** Phase 41's core product object is a `Ritual Room`: a persistent context space for one family sound.
- **D-02:** `Ritual Room` is not a phrase card, activity, one-off practice session, or four-step task flow.
- **D-03:** Old Onboarding, Home, Practice, and Garden must not be reproduced as old mobile page structure. In Phase 41 they are semantic lenses over one Ritual Room.
- **D-04:** The four Phase 41 lenses are First Entry, Today Orientation, Room Support, and Memory Lens.
- **D-05:** Do not design a required lifecycle where every future ritual room must pass through Onboarding -> Home -> Practice -> Garden. Future rituals should come through activation, not onboarding.
- **D-06:** Phase 41 can implement a simple guided path: First Entry -> Today Orientation -> Ritual Room Support -> Memory Lens.
- **D-07:** Do not add bottom navigation in Phase 41. Use a minimal route stack or single guided vertical slice. Bottom navigation and multi-room organization belong after the first room feels right.

#### First Ritual Seed
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

#### Local Fixture Truth
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

#### Lens Flow
- **D-16:** First Entry replaces old Onboarding. It is only used to create/open the first Ritual Room.
- **D-17:** Today Orientation replaces old Home dashboard. It orients the parent to the current active room and why one tiny sound is enough for today.
- **D-18:** Room Support replaces old Practice. It is support mode inside the Ritual Room and helps the parent say the fixed sound with action binding and no-response reassurance.
- **D-19:** Memory Lens replaces old Garden result screen. It gently reviews the same room and asks whether the sound is becoming easier, should rest, or belongs to family life.
- **D-20:** Today Orientation before Room Support should show the active room `出门小声音`, state that today's job is small, and use a CTA to enter support mode.
- **D-21:** Today Orientation after Room Support must not say complete or success. Acceptable framing: `这个小声音已经在你们的出门 routine 里了。想先看看花园记忆吗？`
- **D-22:** After Room Support, CTAs may point to memory prompt, rest, or back to the room, but must not imply completion or scoring.

#### Room Support
- **D-23:** Room Support should feel like "help me say this naturally once", not training.
- **D-24:** Room Support should show:
  - fixed sound: `Shoes on.`
  - Chinese helper: `穿鞋啦。`
  - action binding: `套鞋/轻轻拍拍鞋的时候说`
  - no-response reassurance: `宝宝不用跟读，也不用回应。你继续穿鞋就好。`
  - optional soft variant, visually secondary
- **D-25:** Acceptable Room Support CTAs include `我知道怎么说了`, `先这样就好`, and `看看这个声音怎么留在家里`.
- **D-26:** Avoid `完成练习`, `今日任务`, `说了 1/3`, `继续下一句`, `打卡成功`, and `宝宝学会了吗`.

#### Memory Lens
- **D-27:** Phase 41 Memory Lens should ask one low-pressure parent-confirmation prompt, not record completion.
- **D-28:** Use active-state memory prompt only in Phase 41. Full Garden Memory transition mechanics are later work.
- **D-29:** Suggested prompt: `这句最近有没有更容易从嘴边冒出来？`
- **D-30:** Suggested options:
  - `有一点，更顺口了`
  - `还没有，先慢慢来`
  - `今天先放一边`
- **D-31:** These options may update a local visual placeholder or show a gentle response in Phase 41, but must not implement full production state transitions.

#### Acceptance and Proof
- **D-32:** The runnable app must demonstrate one Ritual Room through First Entry, Today Orientation, Room Support, and Memory Lens.
- **D-33:** The implementation must not reproduce old Onboarding/Home/Practice/Garden semantics.
- **D-34:** The implementation must not use completion, streak, score, growth, phrase progression, or activity dashboard language.
- **D-35:** Acceptance must include runnable Flutter app evidence, widget/golden/smoke tests for the lens path, and passing Phase 39 semantic firewall plus Phase 40 Activation Governor / Garden Memory verifier guards.

### Historical Discretion Notes

- Historical note: file names, route mechanics, and a local state holder were once discretionary. Current file ownership, `ritual_room` paths, InteractionEngine authority, Riverpod composition, and one-Notifier rules are now locked by the 2026-06-19 authorities.
- Planner/executor may choose the visual composition and copy refinements within the locked tone: parent-facing, warm, low-pressure, action-bound, and non-scoring.
- Planner/executor may re-derive selected warm visual/audio interaction patterns from old `mobile/`, but must not import old mobile product/domain/data/presentation code into `mobile_v2/lib`.
- Planner/executor may decide whether the local Memory Lens option response is a visual placeholder, banner, or local in-memory field, as long as it is not production Garden Memory transition truth.

### Historical Deferred Ideas Snapshot (not current execution authority)

- Bottom navigation and multi-room organization are deferred until after the first Ritual Room works.
- Full Garden Memory transition mechanics are deferred; Phase 41 may only show local visual placeholder responses.
- Historical note: First Entry activation flow is superseded; Phase 41 starts directly on Room Support and future Ritual List/activation flows remain deferred.
- Backend integration, AI, real Strategy Pack, real Strategy Graph, production Runtime Agent, and transfer metrics remain deferred to later M010 phases.
- Phase 42 owns refinement of low-pressure interaction schematic, layout rhythm, accessible touch flow, and screenshot/golden polish.
- Historical note, superseded: DTO/API/repository adapters and the testable Riverpod state backbone moved into Phase 41; Phase 43 must not be used to defer them.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| R058 | Baby Talk v1 must be Family-micro-ritual-first and exclude course, translator, check-in, and infinite-generation routes. [VERIFIED: REQUIREMENTS.md] | Plan one Ritual Room loop, not content volume, lessons, or task completion. [VERIFIED: 41-CONTEXT.md] |
| R059 | The core product unit is Family English Micro-ritual, not Phrase, Path, Pack, or activity completion. [VERIFIED: REQUIREMENTS.md] | Use a local `RitualRoom` fixture with `fixedSound`, `routineAnchor`, `actionBinding`, `toneHint`, `childNoResponseRule`, `softVariant`, and `doNotUseWhen`; avoid old phrase/activity/progress identifiers. [VERIFIED: docs/Baby_Talk_Product_Architecture_Spec_vNext.md + 41-CONTEXT.md] |
| R060 | Observed Moment must be Context Seed evidence and Interpreted Moment must be joinability hypothesis, not diagnosis or automatic task trigger. [VERIFIED: REQUIREMENTS.md] | Fixture should carry fake Context Seed and Joinability hypothesis only as explanatory local evidence; it must not auto-create tasks or diagnose the child. [VERIFIED: 41-CONTEXT.md] |
| R063 | Activation Governor gates activation between candidates and Runtime responses. [VERIFIED: REQUIREMENTS.md] | The slice may start with active state only because the fake Governor decision is explicitly `allow_activation`; no other surface may imply ungoverned activation. [VERIFIED: 41-CONTEXT.md + tool/verify_activation_governor_contract.dart] |
| R064 | Garden Memory is parent-confirmed family micro-ritual memory, not completion, check-in, or system scoring. [VERIFIED: REQUIREMENTS.md] | Memory Lens should ask one low-pressure prompt and update only a local placeholder or gentle response, not production transfer state. [VERIFIED: 41-CONTEXT.md] |
| R065 | Explore and Activate must remain distinct; expert content can be open, but active micro-rituals are conservative. [VERIFIED: REQUIREMENTS.md] | Phase 41 should not add Explore, Pack, Runtime, or activation recommendations beyond the single fake-governed active room. [VERIFIED: ROADMAP.md + 41-CONTEXT.md] |
| R067 | Ritual Room must be a five-channel evolving Interaction Engine, not a fixed page or reaction lookup. [VERIFIED: REQUIREMENTS.md] | Execute all five channels through domain, DTO, mapper, mock API, repository, snapshot evolution, providers/session, and tests while exposing reaction controls only. [VERIFIED: locked 2026-06-19 authorities] |
</phase_requirements>

## Summary

Phase 41 is a runnable Flutter vertical slice inside the independent `mobile_v2` package, not a port of old `mobile/` surfaces. It starts directly on one D.4.5 `shoes_on_room_v1` Room Support projection while preserving the ritual-first, low-pressure, non-scoring product semantics and fake Governor `allow_activation` evidence.

**Current recommendation:** Build the locked pure-Dart `InteractionEngine` and immutable runtime contracts first, install only `crypto:^3.0.7` in the core plan, add thin DTO/mock API/repository adapters, then install and smoke-test `flutter_riverpod:^3.3.0` in Plan 41-08 for app composition and one whole-ProductSnapshot session Notifier. The UI exposes reaction selection only while all five channels remain executable. Final gates include focused/full `mobile_v2` tests, the Phase 39 semantic firewall, and the Phase 40 Activation Governor verifier.

## Project Constraints (from AGENTS.md)

- BabyTalk 2 is a monorepo with Flutter mobile, Spring Boot backend, and React admin-web. [VERIFIED: AGENTS.md]
- Existing stack is Flutter/Riverpod, Spring Boot 3.4.4/Java 17, React 18/Vite 5/AntD 5. [VERIFIED: AGENTS.md]
- Flutter development conventions live under `mobile/lib/`; `mobile_v2/` is a separate vNext package boundary from Phase 39. [VERIFIED: AGENTS.md + mobile_v2/pubspec.yaml]
- Existing project anti-patterns include duplicate truth stores, localStorage token, frontend-held admin permissions, and large overloaded files; Phase 41 should avoid adding duplicate Ritual Room truth across ViewModel/controller/fixture layers. [VERIFIED: AGENTS.md]
- Project commands list old mobile commands (`cd mobile && flutter test`), but the repo-root `flutter.cmd` delegates to `mobile/`, so Phase 41 `mobile_v2` validation should run from `mobile_v2/` or direct Flutter SDK path, not through the root wrapper. [VERIFIED: AGENTS.md + flutter.cmd]
- Project instruction says use `/browse` for web browsing and never `mcp__claude-in-chrome__*`; no Chrome tooling was used. Flutter framework docs were queried through Context7 per GSD documentation lookup rules. [VERIFIED: AGENTS.md + research-documentation-lookup.md]
- No project-local `.codex/skills/` or `.agents/skills/` directories were found. [VERIFIED: shell check]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Runnable `mobile_v2` app shell | Mobile Client | Tooling / Tests | One root `ProviderScope` opens the direct D.4.5 Room Support screen. |
| Interaction authority | Pure-Dart Domain | In-memory Runtime | `InteractionEngine` alone owns initialize/advance, consistency, atomic commit, and replay. |
| Stable ritual content | Data Adapter | Local Fixture | `MockRitualContentApi -> mapper -> RitualRoomRepository` supplies `shoes_on` content independently of interaction authority. |
| Interaction transport | Data Adapter | Pure-Dart Domain | Strict five-channel DTOs, mapper, mock API, and repository delegate to `InteractionEnginePort` without policy or state mutation. |
| Riverpod composition | App Composition | Presentation | Plan 41-08 installs Riverpod; read-only providers compose dependencies and one later Notifier projects whole snapshots plus transient UI state. |
| Room Support projection | Presentation | Domain Snapshot | D.4.5 renders one current utterance/action cue/listen affordance, reaction-only controls, preserved submitting state, retry, reassurance, and quiet exit. |
| Semantic firewall | Tooling / CI | Mobile Client | Existing verifier rejects old phrase/activity/completion/streak/Garden semantics and forbidden imports. |
| Activation/Garden guard | Tooling / CI | Mobile Client | Existing verifier preserves Governor authority and rejects pressure semantics. |
| Deployed backend/LLM/persistence | Deferred | — | Explicitly out of Phase 41; in-process mock boundaries are required, not forbidden. |

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Flutter SDK | 3.41.6 stable from `C:\software\flutter\bin\cache\flutter.version.json` | Build and test the runnable `mobile_v2` Flutter app. | `mobile_v2` is an independent Flutter package and the official docs use `MaterialApp` as the minimal app root pattern. [VERIFIED: mobile_v2/pubspec.yaml + shell output] [CITED: https://docs.flutter.dev/learn/pathway/tutorial/create-an-app] |
| Dart SDK | 3.11.4 stable | Pure Dart verifier execution and Flutter SDK language runtime. | Existing verifiers are Dart tools and local SDK version matches `mobile_v2` SDK constraint. [VERIFIED: shell output + mobile_v2/pubspec.yaml] |
| Flutter Material | SDK dependency | `MaterialApp`, `Scaffold`, Material icons, buttons, semantics, and warm UI primitives. | `mobile_v2` already has `flutter: uses-material-design: true`; Phase 41 UI-SPEC allows Flutter Material 3 primitives only. [VERIFIED: mobile_v2/pubspec.yaml + 41-UI-SPEC.md] [CITED: https://docs.flutter.dev/tools/pubspec] |
| `flutter_test` | SDK dependency | Widget tests for tap-through lens flow and accessibility guideline checks. | Flutter official docs require `flutter_test` under `dev_dependencies` for widget tests, and `mobile_v2` already declares it. [VERIFIED: mobile_v2/pubspec.yaml] [CITED: https://docs.flutter.dev/cookbook/testing/widget/introduction] |
| Existing Phase 39 verifier | current repo file | Guard old semantic leakage in `mobile_v2/lib`. | Phase 41 must pass semantic firewall after adding runtime code. [VERIFIED: 41-CONTEXT.md + tool/verify_mobile_v2_semantic_firewall.dart] |
| Existing Phase 40 verifier | current repo file | Guard activation-intent and Garden Memory pressure-copy violations. | Phase 41 must pass Activation Governor / Garden Memory guardrails. [VERIFIED: 41-CONTEXT.md + tool/verify_activation_governor_contract.dart] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| `dart:io` | Dart standard library | Existing verifier tooling uses it for source scans. | Use only in verifier/tool code, not app UI. [VERIFIED: tool/verify_mobile_v2_semantic_firewall.dart] |
| Old `mobile` theme/widgets | current repo files | Visual/audio interaction reference only. | Re-derive warm tone, play button affordance, and activation framing locally; do not import old product/domain/presentation code. [VERIFIED: mobile/lib/app/widgets/app_audio_button.dart + mobile/lib/features/practice/presentation/widgets/phrase_card.dart + 41-CONTEXT.md] |
| `rg` | available | Research-time source discovery. | Useful for planner/executor audits; final enforcement should be Dart verifiers, not ad hoc grep. [VERIFIED: shell output] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Riverpod with code generation or GoRouter | `flutter_riverpod:^3.3.0` without codegen, installed in Plan 41-08 | Riverpod is locked for composition/session orchestration; `riverpod_generator`, `build_runner`, hooks, Freezed, and routing expansion remain out of scope. |
| Porting old `mobile` `PhraseCard` | Re-derived `FixedSoundDisplay` + optional `AudioPlayControl` | Old widget imports phrase model, completion state, reaction chips, and `phraseId`; only the visual/play affordance is safe as reference. [VERIFIED: mobile/lib/features/practice/presentation/widgets/phrase_card.dart] |
| Root `flutter.cmd` | `cd mobile_v2 && flutter test` or direct SDK Flutter from `mobile_v2` | Root wrapper delegates into old `mobile/`, so it is wrong for `mobile_v2` package tests. [VERIFIED: flutter.cmd] |
| Golden-heavy UI proof | Focused widget/smoke tests first | Phase 42 owns screenshot/golden polish; Phase 41 needs runnable flow proof. [VERIFIED: ROADMAP.md + 41-CONTEXT.md] |

**Installation order:** Plan 41-01 installs only audited `crypto:^3.0.7`. Plan 41-08 later installs audited `flutter_riverpod:^3.3.0`, updates the lockfile and Riverpod-specific coding standards, creates the smoke test, and proves it before provider implementation. No code generation, networking, persistence, or additional UI package is approved.

## Package Legitimacy Audit

Identity and policy details were retrieved from official package/project sources on 2026-06-19. Mutable download totals and publication-age claims are intentionally omitted.

| Package / owner plan | Official URL | Publisher / project | Source repository | License | Purpose and constraints | Verdict | Retrieved |
|---|---|---|---|---|---|---|---|
| `crypto` `^3.0.7` / core Plan 41-01 | `https://pub.dev/packages/crypto` | `dart.dev` / Dart core packages | `https://github.com/dart-lang/core/tree/main/pkgs/crypto` | BSD-3-Clause | Canonical SHA-256 event fingerprints only; no secrets, encryption, credentials, or raw-input retention | [VERIFIED] | 2026-06-19 |
| `flutter_riverpod` `^3.3.0` / later Plan 41-08 | `https://pub.dev/packages/flutter_riverpod` | Riverpod / `rrousselGit/riverpod` | `https://github.com/rrousselGit/riverpod` | MIT | App composition and one transient session Notifier only; no codegen, hooks, Freezed, StateNotifier compatibility layer, domain/data imports, or second product-state authority | [VERIFIED] | 2026-06-19 |

Both identities are approved for their named plans. Any different package, source, version family, generator, networking, or persistence dependency requires a new legitimacy audit before installation.

## Architecture Patterns

The active architecture is defined by the three locked 2026-06-19 authorities. The former local-fixture -> four-lens controller diagram, `first_micro_ritual/` structure, and four-screen widget-flow example have been removed because they conflict with execution.

### Active System Architecture

```text
shoes_on.json -> MockRitualContentApi -> mapper -> RitualRoomRepository
                                             |
raw InputEvent -> InteractionEngine authority + private runtime store
                     | atomic ProductSnapshot result
                     v
              DTO <-> MockInteractionApi <-> InteractionRepository
                                             |
Plan 41-08 ProviderScope/read-only providers + input factory + CapabilityMask
                                             |
one RitualRoomSessionNotifier carrying whole ProductSnapshot + transient UI
                                             |
direct D.4.5 Ritual Room Support screen (reaction controls visible only)
```

### Active Project Structure

Production code uses `mobile_v2/lib/features/ritual_room/{domain,data,presentation}` plus `mobile_v2/lib/app/providers` and `mobile_v2/lib/app/input`. Tests mirror those paths under `mobile_v2/test`. Do not create `first_micro_ritual/`, lens-controller, First Entry, Today Orientation, or four-screen flow files.

### Pattern 1: Separate stable content from interaction authority

`RitualRoomRepository` owns stable `shoes_on` content. `InteractionEngine` owns lifecycle, revision, consistency, replay, strategy, and utterance evolution. Neither may absorb the other responsibility.

### Pattern 2: Keep adapters and Riverpod thin

DTOs, mappers, MockInteractionApi, and InteractionRepository adapt every result without deriving policy or mutating snapshots. Riverpod is installed only in Plan 41-08, remains in app composition/bootstrap, and exposes one later mutable session Notifier.

### Pattern 3: Test the direct Room Support loop and all hidden engine channels

Widget tests start directly on Room Support and cover loading, ready, submitting-with-last-snapshot, revised result, retry, payload substitution, layout, and accessibility. Domain/data tests execute reaction, voice transcript, free text, future signal, and strategy preference even though only reaction controls are visible.

### Anti-Patterns to Avoid

- **Old surface reproduction:** Do not rebuild Onboarding/Home/Practice/Garden or the historical First Entry/Today Orientation/Memory Lens chain; Phase 41 opens direct Room Support.
- **Progress language:** Do not use completion, score, streak, growth, unlock, reward, `phraseId`, `activityId`, `completedPhraseCount`, or `nextPhraseId` in runtime truth. [VERIFIED: 41-CONTEXT.md + tool/verify_mobile_v2_semantic_firewall.dart]
- **Ungoverned activation copy:** Copy such as “今天试试这个声音” can trigger Phase 40 verifier unless it is tied to an explicit Governor decision; use locked safer copy from UI-SPEC. [VERIFIED: tool/verify_activation_governor_contract.dart + 41-UI-SPEC.md]
- **Production Garden transition:** Memory option selection may update only a local placeholder response, not `familiar`, `resting`, or `belongs_to_family` truth. [VERIFIED: 41-CONTEXT.md + 40-SPEC.md]
- **Root wrapper for `mobile_v2`:** Do not use repo-root `flutter.cmd` for `mobile_v2` package tests because it changes directory to old `mobile/`. [VERIFIED: flutter.cmd]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Navigation shell | Bottom nav, drawer, global mentor FAB, multi-room switcher, four-screen route chain | Direct D.4.5 Room Support screen | Phase 41 is one screen with multiple interaction states. |
| State architecture | ViewModel + Notifier dual truth, generated Riverpod, or local lens controller | Plan 41-08 read-only providers plus one later whole-ProductSnapshot session Notifier | Riverpod is required but must remain composition/transient UI orchestration, never a second domain authority. |
| Data source | Deployed backend/AI/real Pack/Graph/Runtime or widget literals | Required local fixture plus Mock APIs, DTO mappers, repositories, and pure-Dart engine | In-process adapter boundaries are Phase 41 scope; deployed integrations are not. |
| Audio engine | TTS/audio playback implementation | Optional button stub or no-op local callback | Acceptance needs support UI, not real audio. [VERIFIED: 41-UI-SPEC.md] |
| Garden state machine | Production transfer transitions or Memory Lens result flow | Fake Governor/Garden evidence in content plus no production transition UI | Phase 41 direct Room Support must remain non-scoring and transition-free. |
| Semantic scanning | Ad hoc grep-only proof | Existing Phase 39/40 Dart verifiers | Repo already owns fail-closed verifiers for this boundary. [VERIFIED: tool/verify_mobile_v2_semantic_firewall.dart + tool/verify_activation_governor_contract.dart] |

**Key insight:** the implementation is technically small; the planning risk is semantic regression into old task/progress/scoring product truth. [VERIFIED: 41-CONTEXT.md + Phase 39/40 verifiers]

## Common Pitfalls

### Pitfall 1: The CTA Trips the Activation Verifier
**What goes wrong:** Runtime copy says “今天试试这个声音” or similar activation intent without explicit Governor-decision language, causing Phase 40 source scan failures. [VERIFIED: tool/verify_activation_governor_contract.dart]
**Why it happens:** The UI-SPEC has a `试试这句小声音` CTA while the verifier patterns include action-now Chinese activation examples. [VERIFIED: 41-UI-SPEC.md + tool/verify_activation_governor_contract.dart]
**How to avoid:** Keep fake Governor `allow_activation` explicit in nearby code/copy naming or choose copy that does not match the banned activation-intent patterns; run the verifier after copy changes. [VERIFIED: tool/verify_activation_governor_contract.dart]
**Warning signs:** Source scan reports `activation_intent` or `source_scan` in `mobile_v2/lib`. [VERIFIED: tool/verify_activation_governor_contract.dart]

### Pitfall 2: Old Phrase Card Shape Leaks Into vNext
**What goes wrong:** A re-derived Room Support widget accidentally carries `phraseId`, completion phase, reaction chip, or “saved” state. [VERIFIED: mobile/lib/features/practice/presentation/widgets/phrase_card.dart]
**Why it happens:** Old phrase card has useful display/playback visuals mixed with forbidden product semantics. [VERIFIED: mobile/lib/features/practice/presentation/widgets/phrase_card.dart]
**How to avoid:** Build a fresh `FixedSoundDisplay` and optional `AudioPlayControl`; copy no model imports or keys tied to phrase IDs. [VERIFIED: 41-CONTEXT.md]
**Warning signs:** Phase 39 verifier reports banned runtime terms under `mobile_v2/lib`. [VERIFIED: tool/verify_mobile_v2_semantic_firewall.dart]

### Pitfall 3: Garden/result semantics leak into Room Support
**What goes wrong:** The direct Room Support screen frames reaction or quiet exit as completion, success, score, progress, growth, or state promotion.
**Why it happens:** Old Garden/result-screen semantics and common app patterns push toward visible achievement feedback.
**How to avoid:** Keep reaction choices neutral, retain fake Governor/Garden evidence in the content boundary only, and implement no Memory Lens route or production transition state.
**Warning signs:** Copy includes `完成`, `进度`, `积分`, `连胜`, `解锁`, `成长值`, `reward`, or `score`, or navigation opens a result screen.

### Pitfall 4: Mistaking required adapter boundaries for deferred infrastructure
**What goes wrong:** An executor omits DTOs, Mock APIs, repositories, InteractionEngine runtime contracts, or Riverpod composition because older research called them later work.
**Why it happens:** The 2026-06-16 scope predates the locked Interaction Engine and Flutter/Riverpod plans.
**How to avoid:** Implement the required in-process engine, DTO/API/repository, and Riverpod boundaries exactly as planned; defer only deployed networking, persistence, credentials, production Pack/Graph/Runtime, and multi-room infrastructure.
**Warning signs:** Direct fixture-to-widget flow, a local lens controller, repository-free transport, or Riverpod postponed beyond Plan 41-08.

## Code Examples

### Minimal Flutter App Root
```dart
// Source: Flutter official create-an-app docs. [CITED: https://docs.flutter.dev/learn/pathway/tutorial/create-an-app]
class BabyTalkV2App extends StatelessWidget {
  const BabyTalkV2App({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: FirstMicroRitualSlice(),
    );
  }
}
```

### Accessibility Guideline Test
```dart
// Source: Flutter accessibility testing docs. [CITED: https://docs.flutter.dev/ui/accessibility/accessibility-testing]
testWidgets('first micro-ritual slice follows core accessibility guidelines',
    (tester) async {
  final handle = tester.ensureSemantics();
  await tester.pumpWidget(const BabyTalkV2App());

  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

  handle.dispose();
});
```

### Existing Mobile Wrapper Pattern
```dart
// Source: mobile/test/tool/verify_activation_governor_contract_test.dart. [VERIFIED: repo file]
import '../../../test/tool/verify_activation_governor_contract_test.dart'
    as root_test;

void main() => root_test.main();
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Phrase/activity/completion/streak/Garden growth product loop | Family English Micro-ritual with conservative activation and parent-confirmed memory | M010 restart, Phase 39/40 | Phase 41 must prove the new loop in a runnable app, not old surface parity. [VERIFIED: 39-SPEC.md + 40-SPEC.md + ROADMAP.md] |
| Home/Practice/Garden or four sequential lenses | Direct D.4.5 Room Support projection with multiple states | 2026-06-19 locked UI/context correction | Tests start on one screen; First Entry and Today Orientation are absent. |
| Static fixture/controller slice | Pure-Dart InteractionEngine plus thin adapters and one Riverpod session projection | 2026-06-19 locked engine plans | All five channels execute; only reaction controls are visible. |
| Real Pack/Graph/LLM/persistence before UI | Local deterministic engine and in-process Mock APIs first | 2026-06-19 locked scope | Production services remain deferred while required adapter contracts ship now. |

**Deprecated/outdated:** old `mobile/` product semantics; old phrase-completion Garden growth; old bottom navigation/multi-surface app shell for this phase; docs-only acceptance for Phase 41. [VERIFIED: 39-SPEC.md + 41-CONTEXT.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Historical plain-controller guidance is superseded; Plan 41-08 installs Riverpod and Plan 41-09 creates the sole mutable session Notifier. [LOCKED] | Locked Supersession / Architecture Patterns | Execution must not substitute a StatefulWidget/local lens controller as product state authority. |
| A2 | Real audio playback is not required because UI-SPEC marks AudioPlayControl optional and Phase 41 acceptance centers on support flow. [ASSUMED] | Don't Hand-Roll | Medium; if user expects audible `Shoes on.`, planner must add asset/TTS scope and package checks. |
| A3 | Flutter CLI timeouts are environment/tool-cache issues, not evidence that Flutter is unavailable. [ASSUMED] | Environment Availability | Medium; executor must prove command health before claiming validation. |

## Open Questions (RESOLVED)

1. **Should Room Support include a real sound playback asset in Phase 41?**
   - What we know: AudioPlayControl is optional and can use a speaker/play icon; no package or asset is declared in `mobile_v2`. [VERIFIED: 41-UI-SPEC.md + mobile_v2/pubspec.yaml]
   - Resolution: Phase 41 uses no real audio asset and no audio playback package. `AudioPlayControl` is a Material-only placeholder/affordance with a semantics label only, unless later phases explicitly add assets and package verification. [RESOLVED: 41-UI-SPEC.md + mobile_v2/pubspec.yaml]
   - Recommendation: Plan a no-op/placeholder playback button with semantics label only; do not add an audio asset task or package/asset verification in Phase 41. [VERIFIED: 41-UI-SPEC.md]

2. **Should widget tests live only in `mobile_v2/test` or also root `test/features/vnext`?**
   - What we know: Phase 41 context allows `mobile_v2/test` and/or root vNext paths; existing semantic guard tests live at root and mobile wrapper paths. [VERIFIED: 41-CONTEXT.md + repo file list]
   - Resolution: Phase 41 app/widget tests live under `mobile_v2/test`. Existing root tests remain verifier-contract tests and should not be duplicated for the runnable slice. [RESOLVED: mobile_v2/pubspec.yaml + existing test layout]
   - Recommendation: Put app/widget flow tests in `mobile_v2/test` and keep verifier contract tests in existing root paths. [VERIFIED: mobile_v2/pubspec.yaml + existing test layout]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Flutter SDK | `mobile_v2` app/test execution | found but CLI command timed out | cache reports 3.41.6 stable | Resolve SDK/cache/telemetry issue; run from `mobile_v2/` with direct SDK path. [VERIFIED: shell output] |
| Dart SDK direct executable | verifier tooling | yes | 3.11.4 stable | None needed for version read; verifier execution was blocked via `dart run` telemetry in sandbox. [VERIFIED: shell output] |
| `mobile_v2` package | Phase 41 runtime | yes | `0.0.1`, SDK `^3.11.4` | None. [VERIFIED: mobile_v2/pubspec.yaml] |
| `flutter_test` | widget/smoke/accessibility tests | declared | SDK dependency | None. [VERIFIED: mobile_v2/pubspec.yaml] |
| `gsd-tools` shim | phase metadata/research-plan | yes | local `gsd-tools.cjs`; no `--version` flag | Invoke through `node C:\Users\zhang\.codex\gsd-core\bin\gsd-tools.cjs`. [VERIFIED: shell output] |
| Research cache store | GSD digest caching | blocked by sandbox | writes under `C:\Users\zhang\.gsd\research-cache` | Not required for artifact; note cache persistence failed. [VERIFIED: shell output] |

**Planned dependencies:** `crypto:^3.0.7` is installed by Plan 41-01; `flutter_riverpod:^3.3.0` is intentionally absent until Plan 41-08 installs it and passes `riverpod_smoke_test.dart`.

**Command-health dependency:** Flutter/Dart CLI execution still requires the Plan 41-01 command-health proof and direct SDK fallback map before implementation claims validation success.

## Validation Architecture

`41-VALIDATION.md` is the active per-task command and requirement map. It supersedes the historical `first_micro_ritual` test names, four-screen tap-through checks, and Wave 0 app-shell gaps formerly listed here.

### Active test layers

1. Immutable InputEvent/ProductSnapshot/AdvanceResult contracts.
2. Four deterministic pipeline modules.
3. Fingerprint, consistency, replay, direct replay, and serialized runtime store.
4. InteractionEngine lifecycle/conflict/atomicity/concurrency/privacy authority.
5. Stable content DTO/API/repository path.
6. Five-channel transport DTO/mapper path.
7. Thin InteractionEnginePort API/repository adapters and parity.
8. Plan 41-08 Riverpod dependency/smoke, read-only providers, input factory, and CapabilityMask isolation.
9. One whole-ProductSnapshot session Notifier.
10. Direct D.4.5 widgets/app, accessibility, semantic firewall, Activation Governor verifier, and final proof artifacts.

### Active requirement mapping

| Requirement | Mechanical proof |
|---|---|
| R058/R059 | ritual-first content and widget semantics; no course/phrase/progress truth |
| R060 | observed-versus-interpreted engine tests, privacy scans, whole-snapshot boundaries |
| R063/R064/R065 | fake Governor evidence plus Phase 40 verifier and no production Garden transitions |
| R067 | five model/DTO/factory/repository channels, mixed revision sequence, reaction-only mask isolation |

All PLAN `<automated>` bodies are direct current-PowerShell scripts. RED gates retain captured `Start-Process` output assertions; GREEN/final gates remain fail-fast through `$LASTEXITCODE`; negative source assertions throw on matches.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | No auth/login/backend work in Phase 41. [VERIFIED: 41-CONTEXT.md] |
| V3 Session Management | no | No session state or tokens in scope. [VERIFIED: 41-CONTEXT.md] |
| V4 Access Control | yes, semantic authority boundary | Fake `allow_activation` must be explicit; app must not create new active rituals without Governor authority. [VERIFIED: 40-SPEC.md + 41-CONTEXT.md] |
| V5 Input Validation | yes | Validate fixture values and UI copy through widget tests and verifiers; reject old semantics and pressure language. [VERIFIED: tool/verify_mobile_v2_semantic_firewall.dart + tool/verify_activation_governor_contract.dart] |
| V6 Cryptography | limited | `crypto:^3.0.7` is allowed only for canonical SHA-256 fingerprints; it does not add secrets, encryption, secure storage, credentials, or raw-input retention. |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Old product semantic injection | Tampering | Phase 39 semantic firewall, no imports from old `mobile` product layers, new fixture/domain names. [VERIFIED: tool/verify_mobile_v2_semantic_firewall.dart] |
| Ungoverned activation intent | Elevation of Privilege | Phase 40 source scan and explicit fake Governor decision. [VERIFIED: tool/verify_activation_governor_contract.dart] |
| Parent shame/pressure from memory prompt | Safety / Repudiation | Low-pressure locked prompt/options and no production state promotion. [VERIFIED: 41-CONTEXT.md] |
| Child learning inference | Safety / Privacy | No baby response requirement, no scoring, no proof of learning. [VERIFIED: 41-CONTEXT.md] |
| Hidden external dependency | Supply Chain | Install only audited `crypto:^3.0.7` in Plan 41-01 and audited `flutter_riverpod:^3.3.0` in Plan 41-08; reject codegen, networking, persistence, or unreviewed packages. |

## Sources

### Primary (HIGH confidence project sources)
- `.planning/phases/41-mobile-v2-runnable-vertical-slice/41-INTERACTION-ENGINE-CONTRACT.md` - later locked engine authority, state, lifecycle, replay, privacy, capability, and adapter contract.
- `docs/superpowers/plans/2026-06-19-interaction-engine-v1.md` - later locked pure-Dart core and crypto execution order.
- `docs/superpowers/plans/2026-06-19-interaction-engine-flutter-riverpod.md` - later locked Riverpod install, smoke, composition, repository, and one-Notifier plan.
- `.planning/phases/41-mobile-v2-runnable-vertical-slice/41-CONTEXT.md` - current direct Room Support, D.4.5, fixture/content, and scope decisions.
- `.planning/phases/41-mobile-v2-runnable-vertical-slice/41-UI-SPEC.md` - design, copy, interaction, accessibility contract. [VERIFIED: file read]
- `.planning/ROADMAP.md` - construction rule and Phase 41/42/43 boundaries. [VERIFIED: file read]
- `.planning/REQUIREMENTS.md` - R058/R059/R060/R063/R064/R065 requirement text and validation state. [VERIFIED: file read]
- `docs/Baby_Talk_Product_Architecture_Spec_vNext.md` - canonical `Shoes on`, micro-ritual fields, Activation Governor, Garden Memory, and transfer metric boundaries. [VERIFIED: file read]
- `.planning/phases/39-vnext-family-english-micro-ritual/39-SPEC.md` and `39-CONTEXT.md` - mobile_v2 boundary and semantic firewall. [VERIFIED: file read]
- `.planning/phases/40-activation-governor-garden-memory/40-SPEC.md` and `40-CONTEXT.md` - Activation Governor / Garden Memory contract. [VERIFIED: file read]

### Primary (official framework docs)
- `/websites/flutter_dev` via Context7 - `MaterialApp` root app pattern, widget finders, `WidgetTester.tap`, `pump`, `pumpAndSettle`, accessibility guideline API, and pubspec dependency shape. [CITED: https://docs.flutter.dev/learn/pathway/tutorial/create-an-app] [CITED: https://docs.flutter.dev/cookbook/testing/widget/finders] [CITED: https://docs.flutter.dev/cookbook/testing/widget/tap-drag] [CITED: https://docs.flutter.dev/ui/accessibility/accessibility-testing] [CITED: https://docs.flutter.dev/tools/pubspec]

### Secondary (repo evidence)
- `mobile_v2/pubspec.yaml`, `mobile_v2/lib/vnext_semantic_boundary.dart`, `mobile_v2/reference_assets/README.md`, `mobile_v2/legacy_reference/README.md`. [VERIFIED: file read]
- `tool/verify_mobile_v2_semantic_firewall.dart` and tests under `test/tool`, `test/features/vnext`, and `mobile/test/tool`. [VERIFIED: file read]
- `tool/verify_activation_governor_contract.dart` and tests under `test/tool`, `test/features/vnext`, and `mobile/test/tool`. [VERIFIED: file read]
- Old reference-only files: `mobile/lib/app/widgets/app_audio_button.dart`, `mobile/lib/features/practice/presentation/widgets/phrase_card.dart`, `mobile/lib/features/practice/presentation/widgets/activation_frame.dart`, `mobile/lib/main.dart`. [VERIFIED: file read]

### Tertiary / Caveats
- Research-plan digests were fetched through Context7, but `research-store put` could not persist cache entries because the sandbox denied writes under `C:\Users\zhang\.gsd\research-cache`. [VERIFIED: shell output]
- Verifier execution was attempted but blocked by Dart telemetry/cache writes under the user profile, and sandbox escalation was rejected by the runtime; research records command-health risk instead of claiming verifier pass evidence. [VERIFIED: shell output]

## Metadata

**Confidence breakdown:**
- Standard stack: MEDIUM - current local `mobile_v2` package and Flutter docs are verified, but CLI execution is unhealthy in this sandbox. [VERIFIED: mobile_v2/pubspec.yaml + Context7 + shell output]
- Architecture: HIGH - the 2026-06-19 Interaction Engine contract and two implementation plans supersede the historical architecture while current context/UI and Phase 39/40 verifiers preserve product boundaries.
- Pitfalls: HIGH - old semantics and verifier failure modes are directly visible in repo files. [VERIFIED: old mobile files + verifier files]
- Environment: MEDIUM - SDK files and versions are present, but command execution requires Wave 0 remediation. [VERIFIED: shell output]

**Research date:** 2026-06-16
**Valid until:** 2026-07-16, or until Phase 42/43 changes the `mobile_v2` interaction/state backbone. [ASSUMED]
