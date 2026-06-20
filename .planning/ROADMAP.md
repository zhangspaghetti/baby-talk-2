# Roadmap

## M001: 开口验证闭环

## M002: 连续使用与留存强化

## M003: 扩张与分发能力

## M004: Review 问题收口与仓库整治

## M005: MemPalace 育儿知识宫殿

- [x] **Phase 01: s01** — S01
- [x] **Phase 02: s02** — S02
- [x] **Phase 03: s03** — S03
- [x] **Phase 04: s04** — S04
- [x] **Phase 05: s05** — S05
- [x] **Phase 06: s06** — S06
- [x] **Phase 07: s07** — S07

## M006: Admin 管理后台与后端多模块重构

- [x] **Phase 08: s09** — S09
- [x] **Phase 09: s10** — S10
- [x] **Phase 10: s11** — S11
- [x] **Phase 11: s12** — S12
- [x] **Phase 12: s13** — S13
- [x] **Phase 13: s14** — S14
- [x] **Phase 14: s01** — S01
- [x] **Phase 15: s02** — S02
- [x] **Phase 16: s03** — S03
- [x] **Phase 17: s04** — S04
- [x] **Phase 18: s05** — S05
- [x] **Phase 19: s06** — S06
- [x] **Phase 20: s07** — S07
- [x] **Phase 21: s08** — S08

## M007: Helm-first split deployment, gateway front door, persistence stack migration, and collaborative onboarding docs

- [x] **Phase 22: s01** — S01
- [x] **Phase 23: s02** — S02
- [x] **Phase 24: s03** — S03
- [x] **Phase 25: s04** — S04
- [x] **Phase 26: s05** — S05
- [x] **Phase 27: s06** — S06

## M008: Graph-aware knowledge palace RAG for agentic mentor search, temporal retrieval, and MemPalace design closure

- [x] **Phase 28: s01** — S01
- [x] **Phase 29: s02** — S02
- [x] **Phase 30: s03** — S03

## M009: Historical completeness re-review and UX maturity closure

- [x] **Phase 31: s01** — S01
- [x] **Phase 32: s02** — S02
- [x] **Phase 33: s03** — S03
- [x] **Phase 34: s04** — S04
- [x] **Phase 35: s05** — S05
- [x] **Phase 36: s06** — S06
- [x] **Phase 37: s07** — S07
- [x] **Phase 38: s08** — S08

## M010: Baby Talk vNext Family Micro-ritual 架构重启

**Construction rule:** Phase 39 and Phase 40 remain architecture governance and semantic/activation guardrails. Starting Phase 41, phases must close with runnable `mobile_v2` product construction evidence where applicable: Flutter app entrypoints, page/state flow, widget/golden/smoke tests, and verifier guards. SPEC/proof/verifier artifacts support construction but cannot replace the runnable slice.

### Phase 39: vNext 产品承诺与 Family English Micro-ritual 单元收敛

**Goal:** Lock the vNext product thesis, anti-goals, Family English Micro-ritual unit, Context Seed / Joinability boundary, and supersession rules before any UI or runtime implementation planning.
**Requirements**: R058, R059, R060
**Depends on:** Phase 38
**Plans:** 3/3 plans complete
Plans:
**Wave 1**

- [x] 39-01-PLAN.md — Create source-grounded supersession proof and link SPEC to proof/verifier artifacts.
- [x] 39-02-PLAN.md — Build semantic-firewall verifier, root tests, targeted vNext surface contract tests, and mobile test wrapper.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 39-03-PLAN.md — Create non-UI `mobile_v2` boundary package and close Phase 39 validation gates. (completed 2026-06-15)

### Phase 40: Activation Governor 与 Garden Memory 节奏治理合同

**Goal:** Define the activation pacing contract that separates Explore from Activate, gates new micro-rituals conservatively, and records only parent-confirmed Garden Memory states without checklist pressure.
**Requirements**: R063, R064, R065
**Depends on:** Phase 39
**Plans:** 3/3 plans complete
Plans:

**Wave 1**

- [x] 40-01-PLAN.md — Create independent TDD Activation Governor / Garden Memory verifier foundation.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 40-02-PLAN.md — Extend verifier for surface activation intent, weak-signal limits, parent-confirmed Garden Memory copy, and wrapper parity.

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 40-03-PLAN.md — Create Phase 40 proof/validation artifacts and SPEC links. (completed 2026-06-16)

### Phase 41: mobile_v2 可运行 Ritual Room Vertical Slice

**Goal:** With the approved D.4.5 visual prototype and static `shoes_on` asset, build a runnable Flutter `mobile_v2` vertical slice of the long-term Ritual Interaction Engine. Stable `shoes_on` room content loads through the content repository; raw reaction, voice transcript, free text, future signal, and strategy-preference events pass through the pure-Dart `InteractionEngine` authority into an atomically committed `ProductSnapshot + ConsistencyState + ReplayJournal`, then through thin MockInteractionApi/DTO/repository adapters into one Riverpod `RitualRoomSessionNotifier`. The mobile UI renders ProductSnapshot as a restricted projection that visibly exposes reaction selection only; later UI/input adapters can open other channels without changing engine lifecycle, version, conflict, replay, or state-authority contracts.
**Architecture authority:** `.planning/phases/41-mobile-v2-runnable-vertical-slice/41-INTERACTION-ENGINE-CONTRACT.md`
**Locked implementation authorities:** `docs/superpowers/plans/2026-06-19-interaction-engine-v1.md`; `docs/superpowers/plans/2026-06-19-interaction-engine-flutter-riverpod.md`
**Requirements**: R058, R059, R060, R063, R064, R065, R067
**Depends on:** Phase 40
**Plans:** 2/11 plans executed
Plans:

**Wave 0**

- [x] 41-01-PLAN.md — Hard-gate D.4.5/static assets, install only audited crypto, record command health, and TDD immutable engine models.

**Wave 1** *(four independent plans after Wave 0)*

- [x] 41-02-PLAN.md — TDD the four pure deterministic Normalize/Accumulator/Strategy/Utterance modules.
- [ ] 41-03-PLAN.md — TDD fingerprinting, consistency truth, evidence-only replay, direct replay, and serialized runtime storage.
- [ ] 41-05-PLAN.md — TDD the independent shoes_on content DTO/mapper/API/repository path and governance evidence.
- [ ] 41-06-PLAN.md — TDD strict five-channel interaction DTOs and schema/privacy mapper contracts.

**Wave 2** *(blocked on 41-02 and 41-03)*

- [ ] 41-04-PLAN.md — TDD InteractionEngine as the sole lifecycle/conflict/atomic-commit authority with one-clock-read and direct-replay integration.

**Wave 3** *(blocked on 41-04 and 41-06)*

- [ ] 41-07-PLAN.md — TDD thin InteractionEnginePort API/repository adapters, all-result mapping, and direct-engine parity.

**Wave 4** *(blocked on 41-04, 41-05, and 41-07)*

- [ ] 41-08-PLAN.md — Install/smoke-test audited Riverpod, lock its coding standards, then TDD the read-only provider graph, five-channel input factory, overrides, and reaction-only CapabilityMask.

**Wave 5** *(blocked on 41-08)*

- [ ] 41-09-PLAN.md — TDD the sole RitualRoomSessionNotifier and whole-ProductSnapshot transient UI state.

**Wave 6** *(blocked on 41-09)*

- [ ] 41-10-PLAN.md — Reassert D.4.5/static assets and TDD projection-only Ritual Room widgets.

**Wave 7** *(blocked on authority, adapters, session, and widgets)*

- [ ] 41-11-PLAN.md — Build the ProviderScope app shell/direct screen and close engine, provider, accessibility, requirement, source-audit, and scope proof.

### Phase 42: mobile_v2 Low-pressure Interaction Schematic

**Goal:** Open more controls over the already capability-complete Phase 41 Interaction Engine through coherent progressive disclosure for reaction, voice, free-text, and strategy inputs; stable layout rhythm; accessible one-hand operation; and no control-console overload.
**Requirements**: R058, R059, R063, R064, R065, R067
**Depends on:** Phase 41
**Plans:** 0 plans

Plans:

- [ ] Refine the vertical slice UI and prototype truthful voice/free-text/strategy affordance states without introducing a control-console layout, checklist pressure, streaks, scores, completion goals, or Garden growth semantics.
- [ ] Add responsive/widget/golden or screenshot smoke coverage for the primary flow and low-pressure Garden states.
- [ ] Keep an injected backend-shaped mock API acceptable; no deployed backend, AI generation, or production Pack/Graph required.

### Phase 43: Local Micro-ritual State Backbone

**Goal:** Harden the Interaction Engine state/domain seams behind the vertical slice: multi-channel context envelope, accumulated interaction snapshot, strategy evolution, mock/real API adapter boundary, micro-ritual state transitions, fake Governor decision adapter, and fake Garden Memory store.
**Requirements**: R059, R063, R064, R065, R067
**Depends on:** Phase 42
**Plans:** 0 plans

Plans:

- [ ] Harden the Phase 41 mock Interaction API/repository contract into replaceable multi-channel adapters while preserving the running app flow.
- [ ] Encode candidate/active/familiar/resting/belongs-to-family semantics only as local construction scaffolding, not production schema.
- [ ] Verify state tests, widget flow tests, and Phase 39/40 guardrails.

### Phase 44: Strategy Pack / Graph / Runtime Adapter Skeleton

**Goal:** Reintroduce the original Pack/Graph/Runtime work as an adapter behind the working `mobile_v2` slice, so Primitive Library, Strategy Graph, Strategy Pack, Runtime Agent input/output, and transfer metrics are shaped by a concrete user loop instead of preceding it.
**Requirements**: R061, R062, R066, R067
**Depends on:** Phase 43
**Plans:** 0 plans

Plans:

- [ ] Map the Phase 41-43 API-shaped Ritual content contract into early Pack/Graph/Runtime-shaped adapter boundaries without locking full production schema too early.
- [ ] Preserve Activation Governor authority and Garden Memory parent-confirmation as guardrails, not optional implementation details.
- [ ] Keep adapter tests tied to the runnable vertical slice.

### Phase 45: Transfer Metrics / Backend / AI Integration Readiness

**Goal:** Prepare parent-confirmed micro-ritual transfer metrics and backend/AI integration seams after the mobile loop exists, using the construction slice as the behavioral authority.
**Requirements**: R062, R066, R067
**Depends on:** Phase 44
**Plans:** 0 plans

Plans:

- [ ] Define transfer metrics only from parent-confirmed low-pressure Garden Memory events, not completion, score, streak, or child-test signals.
- [ ] Identify backend/API/AI integration seams needed to replace the Phase 41 mock adapter safely without changing mobile UI content ownership.
- [ ] Acceptance must include integration-readiness tests or contract tests plus existing mobile smoke/widget flow protection.

### Phase 46: Ritual Illustration System

**Goal:** Build the backend / AI asset pipeline for ritual-linked approved illustrations, using a shared Ritual Illustration Grammar and stable caregiver / child reference characters so each ritual can have a coherent, inspectable visual asset.
**Requirements**: TBD — must preserve R058/R059/R064 low-pressure micro-ritual semantics and must not introduce classroom, reward, streak, growth, or task-dashboard imagery.
**Depends on:** Phase 45
**Plans:** 0 plans

Plans:

- [ ] Define the Ritual Illustration Grammar and Ritual action / TPR Grammar, including allowed composition, line style, palette, character references, action focus, phrase-action pairing, and forbidden imagery.
- [ ] Model per-ritual illustration lifecycle states such as `missing`, `generating`, `ready`, `failed`, and `approved`.
- [ ] Design backend/API/AI generation flow for rituals without approved illustrations, using preset caregiver / child reference assets to reduce character drift.
- [ ] Define approval, retry, and fallback behavior so mobile clients consume only approved or safe static illustration assets.
- [ ] Keep Phase 41 out of this scope: Phase 41 may use one approved static `shoes_on` illustration but must not implement generation services.
