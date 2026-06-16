# Phase 41: mobile_v2 可运行 First Micro-ritual Vertical Slice - Research

**Researched:** 2026-06-16
**Domain:** Flutter `mobile_v2` runnable vertical slice, local fixture state, vNext semantic/activation guardrails
**Confidence:** MEDIUM - phase-local product contracts and repo guardrails are strong, Flutter docs were checked through Context7, but local Flutter CLI execution is currently blocked by tool/cache access issues. [VERIFIED: 41-CONTEXT.md + Context7 Flutter docs + shell output]

<user_constraints>
## User Constraints (from CONTEXT.md)

All items in this section are copied from `.planning/phases/41-mobile-v2-runnable-vertical-slice/41-CONTEXT.md`; planners must treat these as locked phase constraints. [VERIFIED: 41-CONTEXT.md]

### Locked Decisions

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

### the agent's Discretion

- Planner/executor may choose exact file names, class names, route mechanics, local state holder, widget structure, and test layout as long as the Ritual Room decisions above remain the product truth.
- Planner/executor may choose the visual composition and copy refinements within the locked tone: parent-facing, warm, low-pressure, action-bound, and non-scoring.
- Planner/executor may re-derive selected warm visual/audio interaction patterns from old `mobile/`, but must not import old mobile product/domain/data/presentation code into `mobile_v2/lib`.
- Planner/executor may decide whether the local Memory Lens option response is a visual placeholder, banner, or local in-memory field, as long as it is not production Garden Memory transition truth.

### Deferred Ideas (OUT OF SCOPE)

- Bottom navigation and multi-room organization are deferred until after the first Ritual Room works.
- Full Garden Memory transition mechanics are deferred; Phase 41 may only show local visual placeholder responses.
- Future Ritual Room activation flows are deferred; Phase 41 First Entry opens only the first room.
- Backend integration, AI, real Strategy Pack, real Strategy Graph, production Runtime Agent, and transfer metrics remain deferred to later M010 phases.
- Phase 42 owns refinement of low-pressure interaction schematic, layout rhythm, accessible touch flow, and screenshot/golden polish.
- Phase 43 owns hardening local fixture/state into replaceable adapters and a testable local state backbone.
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
</phase_requirements>

## Summary

Phase 41 should be planned as a tiny runnable Flutter product slice inside the independent `mobile_v2` package, not as a port of old `mobile/` surfaces. [VERIFIED: mobile_v2/pubspec.yaml + 41-CONTEXT.md] The implementation should create a `runApp`/`MaterialApp` entrypoint, one local fixture-backed Ritual Room, minimal local state for the four semantic lenses, and widget tests that tap through First Entry -> Today Orientation -> Room Support -> Memory Lens. [CITED: https://docs.flutter.dev/learn/pathway/tutorial/create-an-app] [CITED: https://docs.flutter.dev/cookbook/testing/widget/finders]

The product truth is locked to `shoes_on_room_v1` / `出门小声音` / `Shoes on.` and a fake Governor `allow_activation` decision. [VERIFIED: 41-CONTEXT.md] The planner should avoid backend, AI, Strategy Pack/Graph, Runtime Agent, transfer metrics, bottom navigation, multi-room organization, production Garden state transitions, and old phrase/activity/completion/streak/Garden-growth language. [VERIFIED: ROADMAP.md + 41-CONTEXT.md]

**Primary recommendation:** Build `mobile_v2` as a self-contained Flutter slice with no new packages: local fixture/domain types, `BabyTalkV2App`, lens widgets, one in-memory controller, widget/smoke tests, and a final gate that includes `cd mobile_v2 && flutter test`, Phase 39 semantic firewall, and Phase 40 Activation Governor / Garden Memory verifier guards. [VERIFIED: mobile_v2/pubspec.yaml + tool/verify_mobile_v2_semantic_firewall.dart + tool/verify_activation_governor_contract.dart]

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
| Runnable `mobile_v2` app shell | Mobile Client | Tooling / Tests | Phase 41 acceptance requires Flutter app entrypoint and runnable page/state flow inside `mobile_v2`. [VERIFIED: ROADMAP.md] |
| Ritual Room fixture truth | Mobile Client | Test Fixtures | Phase 41 uses local fake data only; backend/AI/Pack/Graph/Runtime are out of scope. [VERIFIED: 41-CONTEXT.md] |
| First Entry lens | Mobile Client | Local State | It creates/opens only `shoes_on_room_v1`, not recurring onboarding or profile setup. [VERIFIED: 41-CONTEXT.md] |
| Today Orientation lens | Mobile Client | Local State | It orients the parent to the one active room and current small job, not a task dashboard. [VERIFIED: 41-CONTEXT.md] |
| Room Support lens | Mobile Client | Optional Local Playback Stub | It helps the parent say `Shoes on.` naturally once; no recording/scoring/child response requirement. [VERIFIED: 41-CONTEXT.md + 41-UI-SPEC.md] |
| Memory Lens | Mobile Client | Local Placeholder State | It asks one low-pressure parent prompt and can update local UI only; production Garden Memory transition mechanics are deferred. [VERIFIED: 41-CONTEXT.md] |
| Semantic firewall | Tooling / CI | Mobile Client | Existing verifier scans `mobile_v2/lib` for old phrase/activity/completion/streak/Garden terms and forbidden imports. [VERIFIED: tool/verify_mobile_v2_semantic_firewall.dart] |
| Activation/Garden guard | Tooling / CI | Mobile Client | Existing verifier scans `mobile_v2/lib` for activation-intent copy without Governor decision and Garden pressure semantics. [VERIFIED: tool/verify_activation_governor_contract.dart] |
| Backend/API/AI integration | Deferred Backend / Runtime | — | Explicitly out of scope for Phase 41. [VERIFIED: ROADMAP.md + 41-CONTEXT.md] |

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
| Riverpod/GoRouter/codegen in Phase 41 | Plain Flutter local state and simple route/lens stack | `mobile_v2` currently has no Riverpod/GoRouter dependencies; adding them would require package legitimacy and overbuild a single-room slice. [VERIFIED: mobile_v2/pubspec.yaml] |
| Porting old `mobile` `PhraseCard` | Re-derived `FixedSoundDisplay` + optional `AudioPlayControl` | Old widget imports phrase model, completion state, reaction chips, and `phraseId`; only the visual/play affordance is safe as reference. [VERIFIED: mobile/lib/features/practice/presentation/widgets/phrase_card.dart] |
| Root `flutter.cmd` | `cd mobile_v2 && flutter test` or direct SDK Flutter from `mobile_v2` | Root wrapper delegates into old `mobile/`, so it is wrong for `mobile_v2` package tests. [VERIFIED: flutter.cmd] |
| Golden-heavy UI proof | Focused widget/smoke tests first | Phase 42 owns screenshot/golden polish; Phase 41 needs runnable flow proof. [VERIFIED: ROADMAP.md + 41-CONTEXT.md] |

**Installation:** No new packages should be installed for Phase 41. [VERIFIED: mobile_v2/pubspec.yaml + 41-UI-SPEC.md]

## Package Legitimacy Audit

Not applicable: Phase 41 should not install external packages. [VERIFIED: mobile_v2/pubspec.yaml + 41-UI-SPEC.md]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| none | — | — | — | — | — | No install planned |

**Packages removed due to [SLOP] verdict:** none  
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```text
Local Phase 41 fixture
  RitualRoom(shoes_on_room_v1)
  ContextSeed(parent preparing shoes / child near door)
  Joinability(action_bound + routine_ready)
  FakeGovernorDecision(allow_activation)
  GardenMemory(active)
        |
        v
BabyTalkV2App / MaterialApp
        |
        v
Lens controller or simple route stack
        |
        +--> First Entry
        |      opens the first Ritual Room only
        |
        +--> Today Orientation
        |      shows active room and one-small-sound framing
        |
        +--> Room Support
        |      fixed sound + Chinese helper + action binding + no-response reassurance
        |
        +--> Memory Lens
               one low-pressure prompt + local placeholder response only
        |
        v
Validation gates
  mobile_v2 widget flow tests
  Phase 39 semantic firewall
  Phase 40 Activation/Garden verifier
```

### Recommended Project Structure

```text
mobile_v2/
├── lib/
│   ├── main.dart                         # runApp entrypoint
│   ├── baby_talk_v2_app.dart             # MaterialApp shell
│   ├── vnext_semantic_boundary.dart      # keep existing anchors
│   └── first_micro_ritual/
│       ├── first_micro_ritual_fixture.dart
│       ├── ritual_room_models.dart
│       ├── ritual_lens_controller.dart
│       └── widgets/
│           ├── first_entry_lens.dart
│           ├── today_orientation_lens.dart
│           ├── room_support_lens.dart
│           ├── memory_lens.dart
│           └── ritual_room_surface.dart
└── test/
    ├── first_micro_ritual_flow_test.dart
    ├── first_micro_ritual_fixture_test.dart
    └── accessibility_smoke_test.dart
```

This structure is recommended, not locked; names can change as long as runtime truth stays under `mobile_v2/lib` and tests stay inside `mobile_v2/test` or existing root vNext test paths. [VERIFIED: 41-CONTEXT.md]

### Pattern 1: Single Fixture, Future-Compatible Shape

**What:** Define one local fixture for `shoes_on_room_v1` with nested Context Seed, Joinability, fake Governor decision, and Garden Memory state. [VERIFIED: 41-CONTEXT.md]

**When to use:** Use it as the only data source for Phase 41 screens and tests. [VERIFIED: 41-CONTEXT.md]

**Example:**
```dart
// Source: 41-CONTEXT.md fixture decisions, re-derived for planning only. [VERIFIED: 41-CONTEXT.md]
const firstRitualRoomFixture = RitualRoomFixture(
  roomId: 'shoes_on_room_v1',
  roomName: '出门小声音',
  fixedSound: 'Shoes on.',
  routineAnchor: '出门穿鞋',
  actionBinding: '拿鞋、套脚、轻拍鞋',
  toneHint: 'short, warm, action-bound',
  childNoResponseRule: '宝宝不用跟读、回答或看 app；父母继续穿鞋动作即可',
  softVariants: ['One shoe. Two shoes.', 'Tap tap.'],
  fakeGovernorDecision: 'allow_activation',
  gardenMemoryState: 'active',
);
```

### Pattern 2: In-Memory Lens Controller

**What:** Use one small local state holder for lens position, support-seen state, and selected Memory Lens option. [VERIFIED: Context7 Flutter docs]

**When to use:** Use it when implementing the guided path without bottom navigation or global app state. [VERIFIED: 41-CONTEXT.md]

**Example:**
```dart
// Source: Flutter widget testing supports pumpWidget/tap/pump for local state flows. [CITED: https://docs.flutter.dev/cookbook/testing/widget/tap-drag]
enum RitualLens { firstEntry, todayOrientation, roomSupport, memoryLens }

class RitualLensState {
  const RitualLensState({
    this.currentLens = RitualLens.firstEntry,
    this.hasVisitedSupport = false,
    this.memoryChoice,
  });

  final RitualLens currentLens;
  final bool hasVisitedSupport;
  final String? memoryChoice;
}
```

### Pattern 3: Widget Test the Whole Behavioral Path

**What:** Pump the app, assert the first lens, tap the CTA, pump, and assert each subsequent lens and copy. [CITED: https://docs.flutter.dev/cookbook/testing/widget/finders]

**When to use:** Use as Phase 41’s main runnable proof before visual polish. [VERIFIED: ROADMAP.md]

**Example:**
```dart
// Source: Flutter official widget testing docs. [CITED: https://docs.flutter.dev/cookbook/testing/widget/finders]
testWidgets('walks first Ritual Room through all four lenses', (tester) async {
  await tester.pumpWidget(const BabyTalkV2App());

  expect(find.text('出门小声音'), findsOneWidget);
  await tester.tap(find.text('进入小声音房间'));
  await tester.pumpAndSettle();

  expect(find.text('试试这句小声音'), findsOneWidget);
  await tester.tap(find.text('试试这句小声音'));
  await tester.pumpAndSettle();

  expect(find.text('Shoes on.'), findsOneWidget);
  expect(find.text('宝宝不用跟读，也不用回应。你继续穿鞋就好。'), findsOneWidget);
});
```

### Anti-Patterns to Avoid

- **Old surface reproduction:** Do not rebuild Onboarding/Home/Practice/Garden as old page structures or global tabs; they are semantic lenses over one room. [VERIFIED: 41-CONTEXT.md]
- **Progress language:** Do not use completion, score, streak, growth, unlock, reward, `phraseId`, `activityId`, `completedPhraseCount`, or `nextPhraseId` in runtime truth. [VERIFIED: 41-CONTEXT.md + tool/verify_mobile_v2_semantic_firewall.dart]
- **Ungoverned activation copy:** Copy such as “今天试试这个声音” can trigger Phase 40 verifier unless it is tied to an explicit Governor decision; use locked safer copy from UI-SPEC. [VERIFIED: tool/verify_activation_governor_contract.dart + 41-UI-SPEC.md]
- **Production Garden transition:** Memory option selection may update only a local placeholder response, not `familiar`, `resting`, or `belongs_to_family` truth. [VERIFIED: 41-CONTEXT.md + 40-SPEC.md]
- **Root wrapper for `mobile_v2`:** Do not use repo-root `flutter.cmd` for `mobile_v2` package tests because it changes directory to old `mobile/`. [VERIFIED: flutter.cmd]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Navigation shell | Bottom nav, drawer, global mentor FAB, multi-room switcher | In-memory lens state or minimal route stack | Phase 41 is a single guided room slice. [VERIFIED: 41-CONTEXT.md] |
| State architecture | Riverpod/provider/codegen stack | One local state holder or `StatefulWidget` controller | `mobile_v2` has no such dependencies and Phase 43 owns hardened state backbone. [VERIFIED: mobile_v2/pubspec.yaml + ROADMAP.md] |
| Data source | Backend/API/AI/real Pack/Graph/Runtime | Local fixture/fake data | Backend and real runtime systems are explicitly out of scope. [VERIFIED: 41-CONTEXT.md] |
| Audio engine | TTS/audio playback implementation | Optional button stub or no-op local callback | Acceptance needs support UI, not real audio. [VERIFIED: 41-UI-SPEC.md] |
| Garden state machine | Production transfer transitions | Local visual placeholder / gentle response | Phase 41 Memory Lens must not implement full Garden Memory mechanics. [VERIFIED: 41-CONTEXT.md] |
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

### Pitfall 3: Memory Lens Becomes a Result Screen
**What goes wrong:** The Garden lens frames the parent selection as completion, success, score, progress, growth, or state promotion. [VERIFIED: 40-SPEC.md]
**Why it happens:** Old Garden semantics and common app patterns push toward visible achievement feedback. [VERIFIED: 39-SPEC.md + DESIGN.md]
**How to avoid:** Ask only the locked low-pressure prompt and show a local narrative response; do not name production transfer states in UI. [VERIFIED: 41-CONTEXT.md]
**Warning signs:** Copy includes `完成`, `进度`, `积分`, `连胜`, `解锁`, `成长值`, `reward`, or `score`. [VERIFIED: 41-UI-SPEC.md + tool/verify_activation_governor_contract.dart]

### Pitfall 4: Overbuilding Phase 43 Early
**What goes wrong:** Planner adds repositories, adapters, persistence, event schema, or multi-room state backbone in Phase 41. [VERIFIED: ROADMAP.md]
**Why it happens:** The fixture is future-compatible, which can be mistaken for production architecture scope. [VERIFIED: 41-CONTEXT.md]
**How to avoid:** Keep fixture local and replaceable; defer hardened adapters and state backbone to Phase 43. [VERIFIED: ROADMAP.md]
**Warning signs:** Tasks mention Isar, API clients, Pack IDs as runtime truth, production Garden store, or multi-room rendering. [VERIFIED: ROADMAP.md + 41-CONTEXT.md]

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
| Home/Practice/Garden as app surfaces | First Entry / Today Orientation / Room Support / Memory Lens as lenses over one Ritual Room | Phase 41 discuss context | Planner should assign tasks by lens behavior, not old feature folders. [VERIFIED: 41-CONTEXT.md] |
| Docs/proof-only closure | Runnable Flutter construction evidence | Roadmap revision on 2026-06-16 | Acceptance must include app entrypoint, state flow, tests, and verifiers. [VERIFIED: ROADMAP.md + STATE.md] |
| Real Pack/Graph/Runtime before UI | Local fake data first, adapters later | Roadmap revision on 2026-06-16 | Phase 44/45 own Pack/Graph/Runtime/metrics readiness after the slice exists. [VERIFIED: ROADMAP.md] |

**Deprecated/outdated:** old `mobile/` product semantics; old phrase-completion Garden growth; old bottom navigation/multi-surface app shell for this phase; docs-only acceptance for Phase 41. [VERIFIED: 39-SPEC.md + 41-CONTEXT.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A plain `StatefulWidget` or tiny controller is enough for Phase 41 local lens state. [ASSUMED] | Standard Stack / Patterns | Low; if implementation complexity grows, Phase 43 can harden state, but Phase 41 should stay small. |
| A2 | Real audio playback is not required because UI-SPEC marks AudioPlayControl optional and Phase 41 acceptance centers on support flow. [ASSUMED] | Don't Hand-Roll | Medium; if user expects audible `Shoes on.`, planner must add asset/TTS scope and package checks. |
| A3 | Flutter CLI timeouts are environment/tool-cache issues, not evidence that Flutter is unavailable. [ASSUMED] | Environment Availability | Medium; executor must prove command health before claiming validation. |

## Open Questions

1. **Should Room Support include a real sound playback asset in Phase 41?**
   - What we know: AudioPlayControl is optional and can use a speaker/play icon; no package or asset is declared in `mobile_v2`. [VERIFIED: 41-UI-SPEC.md + mobile_v2/pubspec.yaml]
   - What's unclear: Whether acceptance expects actual audio output or only the support affordance. [ASSUMED]
   - Recommendation: Plan a no-op/placeholder playback button with semantics label only, unless the planner explicitly adds an audio asset task and package/asset verification. [VERIFIED: 41-UI-SPEC.md]

2. **Should widget tests live only in `mobile_v2/test` or also root `test/features/vnext`?**
   - What we know: Phase 41 context allows `mobile_v2/test` and/or root vNext paths; existing semantic guard tests live at root and mobile wrapper paths. [VERIFIED: 41-CONTEXT.md + repo file list]
   - What's unclear: Which path the execution workflow will prefer for final test commands. [ASSUMED]
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

**Missing dependencies with no fallback:** none confirmed. [VERIFIED: environment probes]

**Missing dependencies with fallback:** Flutter/Dart CLI execution needs Wave 0 health work because `flutter --version`, direct `flutter.bat --version`, and `dart run tool/...` did not complete cleanly in this sandbox. [VERIFIED: shell output]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Flutter widget tests using `flutter_test`; existing guard CLIs are Dart verifier tools. [VERIFIED: mobile_v2/pubspec.yaml + tool files] |
| Config file | `mobile_v2/pubspec.yaml`; root `flutter.cmd` is not suitable for `mobile_v2` because it delegates to old `mobile/`. [VERIFIED: mobile_v2/pubspec.yaml + flutter.cmd] |
| Quick run command | `cd mobile_v2 && flutter test test/first_micro_ritual_flow_test.dart` after Flutter CLI health is resolved. [VERIFIED: Flutter docs + mobile_v2/pubspec.yaml] |
| Full suite command | `cd mobile_v2 && flutter test` plus root verifier gates. [VERIFIED: ROADMAP.md + tool files] |
| Guard command | `dart run tool/verify_mobile_v2_semantic_firewall.dart` and `dart run tool/verify_activation_governor_contract.dart`, or direct SDK equivalents if `dart run` remains blocked. [VERIFIED: tool files + shell output] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| R058 | App presents one low-pressure family micro-ritual loop, not course/check-in/content volume. | widget flow + copy assertions | `cd mobile_v2 && flutter test test/first_micro_ritual_flow_test.dart` | No - Wave 0 |
| R059 | Runtime truth is Ritual Room / micro-ritual fields, not phrase/activity/completion progress. | fixture unit + semantic firewall | `dart run tool/verify_mobile_v2_semantic_firewall.dart` | Guard exists; new app tests missing |
| R060 | Context Seed and Joinability are displayed/held as evidence/hypothesis only, not diagnosis or auto-task trigger. | fixture unit | `cd mobile_v2 && flutter test test/first_micro_ritual_fixture_test.dart` | No - Wave 0 |
| R063 | Initial active room is justified by fake Governor `allow_activation`; no ungoverned activation copy appears. | source verifier | `dart run tool/verify_activation_governor_contract.dart` | Guard exists |
| R064 | Memory Lens asks low-pressure parent prompt and does not score/complete/promote production Garden state. | widget flow + source verifier | `cd mobile_v2 && flutter test test/first_micro_ritual_flow_test.dart` | No - Wave 0 |
| R065 | No Explore/Activate confusion or multi-candidate activation flow is introduced. | source verifier + widget assertions | `dart run tool/verify_activation_governor_contract.dart` | Guard exists |

### Sampling Rate

- **Per task commit:** Run the focused `mobile_v2` widget/fixture test for changed lens or fixture. [CITED: https://docs.flutter.dev/cookbook/testing/widget/tap-drag]
- **Per wave merge:** Run `cd mobile_v2 && flutter test`, then the Phase 39 and Phase 40 verifier CLIs. [VERIFIED: ROADMAP.md]
- **Phase gate:** Full `mobile_v2` test suite green, Phase 39 semantic firewall green, Phase 40 Activation/Garden verifier green, and a source assertion that no backend/AI/Pack/Graph/Runtime/metrics code was added for this phase. [VERIFIED: 41-CONTEXT.md]

### Wave 0 Gaps

- [ ] `mobile_v2/lib/main.dart` - runnable entrypoint. [VERIFIED: mobile_v2 file list]
- [ ] `mobile_v2/lib/baby_talk_v2_app.dart` - `MaterialApp` app shell. [CITED: https://docs.flutter.dev/learn/pathway/tutorial/create-an-app]
- [ ] `mobile_v2/lib/first_micro_ritual/*` - local fixture, models, lens state, and widgets. [VERIFIED: 41-CONTEXT.md]
- [ ] `mobile_v2/test/first_micro_ritual_flow_test.dart` - tap-through lens path. [CITED: https://docs.flutter.dev/cookbook/testing/widget/finders]
- [ ] `mobile_v2/test/first_micro_ritual_fixture_test.dart` - local fixture fields and forbidden old semantics assertions. [VERIFIED: 41-CONTEXT.md]
- [ ] `mobile_v2/test/accessibility_smoke_test.dart` - tap target/label checks if practical. [CITED: https://docs.flutter.dev/ui/accessibility/accessibility-testing]
- [ ] Flutter command-health task - resolve current CLI timeout / telemetry-cache issue before final validation. [VERIFIED: shell output]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | No auth/login/backend work in Phase 41. [VERIFIED: 41-CONTEXT.md] |
| V3 Session Management | no | No session state or tokens in scope. [VERIFIED: 41-CONTEXT.md] |
| V4 Access Control | yes, semantic authority boundary | Fake `allow_activation` must be explicit; app must not create new active rituals without Governor authority. [VERIFIED: 40-SPEC.md + 41-CONTEXT.md] |
| V5 Input Validation | yes | Validate fixture values and UI copy through widget tests and verifiers; reject old semantics and pressure language. [VERIFIED: tool/verify_mobile_v2_semantic_firewall.dart + tool/verify_activation_governor_contract.dart] |
| V6 Cryptography | no | Do not add secrets, crypto, secure storage, or backend credentials. [VERIFIED: 41-CONTEXT.md] |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Old product semantic injection | Tampering | Phase 39 semantic firewall, no imports from old `mobile` product layers, new fixture/domain names. [VERIFIED: tool/verify_mobile_v2_semantic_firewall.dart] |
| Ungoverned activation intent | Elevation of Privilege | Phase 40 source scan and explicit fake Governor decision. [VERIFIED: tool/verify_activation_governor_contract.dart] |
| Parent shame/pressure from memory prompt | Safety / Repudiation | Low-pressure locked prompt/options and no production state promotion. [VERIFIED: 41-CONTEXT.md] |
| Child learning inference | Safety / Privacy | No baby response requirement, no scoring, no proof of learning. [VERIFIED: 41-CONTEXT.md] |
| Hidden external dependency | Supply Chain | No new packages; local fixture only. [VERIFIED: mobile_v2/pubspec.yaml] |

## Sources

### Primary (HIGH confidence project sources)
- `.planning/phases/41-mobile-v2-runnable-vertical-slice/41-CONTEXT.md` - locked decisions, fixture truth, flow, acceptance. [VERIFIED: file read]
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
- Architecture: HIGH - Phase 41 context, UI-SPEC, and prior Phase 39/40 contracts are explicit and machine-guarded. [VERIFIED: 41-CONTEXT.md + 41-UI-SPEC.md + verifier files]
- Pitfalls: HIGH - old semantics and verifier failure modes are directly visible in repo files. [VERIFIED: old mobile files + verifier files]
- Environment: MEDIUM - SDK files and versions are present, but command execution requires Wave 0 remediation. [VERIFIED: shell output]

**Research date:** 2026-06-16  
**Valid until:** 2026-07-16, or until Phase 42/43 changes the `mobile_v2` interaction/state backbone. [ASSUMED]
