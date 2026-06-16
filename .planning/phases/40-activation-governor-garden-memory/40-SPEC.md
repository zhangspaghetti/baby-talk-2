# Phase 40: Activation Governor and Garden Memory Pacing Contract - Specification

**Created:** 2026-06-15
**Ambiguity score:** 0.13 (gate: <= 0.20)
**Requirements:** 9 locked

## Goal

Baby Talk vNext gates every activation-intent product move through Activation Governor while keeping Explore open, and records Garden Memory transfer only through low-pressure parent-confirmed meaningful states.

## Background

Phase 39 changed the active vNext product contract from phrase/activity/completion/growth semantics to Family English Micro-ritual semantics. Its locked artifacts define `Context Seed` as observed evidence, `Joinability` as a hypothesis, and candidate matching as not activation.

The current `mobile_v2/lib` runtime boundary only contains semantic anchors in `vnext_semantic_boundary.dart`: Family English Micro-ritual, Context Seed evidence, Joinability hypothesis, and candidate matching is not activation. There is no Activation Governor domain model, Garden Memory state model, activation verifier, API, schema, UI, or Runtime Agent payload contract yet.

The older `mobile/` product code still contains deprecated phrase-completion and Garden-growth semantics such as phrase IDs, activity progression, completion counts, streaks, GardenGrowth, fertilizer, and flower-stage reward language. Phase 39 classifies those as deprecated or reference-only for vNext. Phase 40 must now lock the WHAT-level pacing contract that prevents those old semantics from re-entering vNext through activation, Garden Memory, or Runtime behavior.

The source product architecture defines the desired direction: conservative activation, open exploration; Activation Governor controls Activate, not Explore; Garden Memory presents state and collects parent confirmation; Runtime Agent applies an existing activation decision rather than self-governing activation policy.

## Requirements

1. **Surface-agnostic activation-intent gate**: Any product move that asks or implies the parent should bring a candidate into family routine must pass through Activation Governor first, regardless of surface.
   - Current: Phase 39 states candidate matching is not activation, but no contract defines what counts as activation intent or requires the gate across Home, Onboarding, Garden, Runtime, reminders, or other future surfaces.
   - Target: Activation intent is gated everywhere. Examples include "today try this", "add this sound", "start this micro-ritual", "say this during bath/shoes/sleep today", setting or implying `active`, Runtime nudges into family routine, onboarding first-ritual activation CTAs, and home/push/reminder cards that turn content into today's family action.
   - Acceptance: A verifier can fail any vNext surface, Runtime path, or product proof that uses activation language or implies active family action without an Activation Governor decision.

2. **Open Explore and candidate generation**: Candidate generation, examples, explanations, and route exploration are not activation by themselves.
   - Current: Pack/Graph candidates and example content are described in vNext docs, but without a Phase 40 contract they could be over-governed as if every candidate mention were an activation attempt.
   - Target: Static Explore surfaces may discuss ideas, examples, candidate routes, future expansions, and expert explanations without Governor approval as long as they do not ask or imply that a candidate should enter family routine now.
   - Acceptance: A verifier can distinguish allowed Explore content from activation-intent CTAs, passing exploration-only examples and failing activation language without a Governor decision.

3. **Governor authority and decision vocabulary**: Activation Governor is the sole pacing decision layer between Pack/Graph candidates and Runtime family-action responses.
   - Current: Phase 39 defers Activation Governor mechanics, and no runtime artifact prevents Pack/Graph matching, Garden, or Runtime from deciding activation on its own.
   - Target: Pack/Graph may produce candidates, Garden may present state and collect feedback, and Runtime may apply an existing activation decision. Activation Governor owns pacing decisions such as `allow_activation`, `nearby_expansion_only`, `defer_to_garden`, `save_for_later`, `rest_existing`, and `belongs_to_family`.
   - Acceptance: A verifier fails if Runtime self-governs activation policy, if Pack/Graph matching directly creates an active micro-ritual, or if Garden owns activation policy instead of presenting state and collecting confirmation.

4. **Candidate-to-active fail-closed rule**: `candidate -> active` requires explicit parent activation intent/readiness plus an Activation Governor `allow_activation` decision.
   - Current: No vNext state model exists, and old product progress could be inferred from completion-like signals rather than parent readiness and pacing approval.
   - Target: A candidate can become active only when the parent expresses activation intent/readiness and Governor returns `allow_activation`. Weak signals, Pack matches, repeated views, saves, or inferred routine fit cannot silently create `active`.
   - Acceptance: A verifier fails any contract, model, event, or test fixture where `active` can be created from weak signals, Pack/Graph matching, or system inference without both parent intent/readiness and Governor approval.

5. **Conservative active capacity contract**: The phase must preserve the v1 pacing constraint without exposing it as a user goal.
   - Current: The source architecture names `defaultActiveLimit = 3`, `maxActiveLimit = 5`, and `nearbyExpansionLimit = 2`, but no Phase 40 contract has locked how those values constrain product meaning.
   - Target: v1 defaults to at most 3 active micro-rituals for ordinary family pacing. A mature-family upper bound of 5 is an internal protection parameter, not a user-facing target. Nearby expansion can be more open than new activation, but still must not become unlimited content pressure.
   - Acceptance: A planner can read this SPEC and know that increasing active count, exposing "more active rituals" as a goal, or bypassing conservative pacing violates the contract; the exact enforcement algorithm remains for discuss/plan.

6. **Garden Memory state vocabulary without checklist semantics**: Garden Memory records family migration states, not completion, score, streak, growth, fertilizer, reward, or child learning proof.
   - Current: Old Garden code and archived designs include growth, fertilizer, flower stage, streak, completion, and reward semantics that Phase 39 deprecated for vNext.
   - Target: Garden Memory may represent `candidate`, `active`, `familiar`, `resting`, `expandable`, and `belongs-to-family` as micro-ritual family-memory states. It must not use checklist, streak, completion, score, growth, fertilizer, reward, unlock, or punishment semantics.
   - Acceptance: A verifier fails vNext Garden/runtime artifacts that use banned checklist, streak, completion, score, growth, fertilizer, reward, unlock, or punishment semantics as Garden Memory truth.

7. **Meaningful Garden transfer states require parent confirmation**: Family transfer states cannot be claimed by the system without low-pressure parent confirmation.
   - Current: Source docs say weak signals can assist prompts, but the current codebase has no fail-closed contract for Garden Memory transitions.
   - Target: `active -> familiar`, `active -> resting`, and `familiar -> belongs-to-family` require explicit, low-pressure parent confirmation. These confirmations must avoid shame, scoring, child testing, or pressure to progress.
   - Acceptance: A verifier fails any transition into `familiar`, `resting`, or `belongs-to-family` when the transition is driven only by telemetry, usage count, completion, elapsed time, or system inference.

8. **Weak signals are prompt suggestions only**: Weak signals may help decide when to ask a parent, but cannot directly mark family transfer.
   - Current: The source architecture lists repeated card opens, saves/resting, variant requests, and returns to the same routine as weak signals, but old product semantics could turn similar signals into progress.
   - Target: Weak signals may suggest prompts, save-for-later surfaces, or Garden review moments. They cannot directly mark `familiar`, `belongs-to-family`, active family transfer, or "should be planted today".
   - Acceptance: A verifier fails if repeated views, favorites, routine returns, variant requests, or similar weak signals directly promote a ritual to `familiar`, `belongs-to-family`, or active family transfer without parent confirmation and, for active creation, Governor approval.

9. **Machine-checkable contract verifier as proof shape**: Phase 40 proof must be stronger than docs-only while staying implementation-neutral.
   - Current: Phase 39 has a semantic-firewall verifier for old phrase/activity/GardenGrowth leakage, but no verifier exists for activation-intent gating, Garden Memory transfer confirmation, or Runtime self-governance.
   - Target: Phase 40 requires a machine-checkable contract verifier as the main proof artifact. The SPEC locks pass/fail rules for activation gating, Explore openness, Garden Memory anti-checklist semantics, weak-signal limits, and decision authority. It does not lock the final algorithm, UI, schema, Runtime payloads, or exact implementation model.
   - Acceptance: discuss/plan must produce or extend a verifier that fails direct activation bypasses, Runtime self-governance, Pack/Graph-to-active shortcuts, Explore activation CTAs without Governor decisions, checklist/streak/Garden-growth semantics, weak-signal promotion to transfer states, and `active` creation without parent intent/readiness plus `allow_activation`.

## Contract Verifier Rules

The Phase 40 verifier must fail when any vNext runtime, proof fixture, or contract fixture shows:

- Runtime can self-govern activation or bypass Activation Governor.
- Pack/Graph matching directly creates an active micro-ritual.
- Explore surfaces use activation CTAs without a Governor decision.
- Activation language appears without a Governor decision: "today try this", "add this sound", "start this micro-ritual", "say this during [routine] today", or equivalent product intent.
- `active` can be created without explicit parent intent/readiness plus Governor `allow_activation`.
- Garden uses checklist, streak, completion, score, growth, fertilizer, reward, unlock, or punishment semantics.
- Weak signals directly promote `familiar`, `belongs-to-family`, or active family transfer.

The verifier should pass when:

- Pack/Graph or Explore surfaces generate candidates, examples, explanations, or route ideas without activation language.
- Weak signals only create prompts, review suggestions, save-for-later hints, or parent-confirmation opportunities.
- Runtime consumes a pre-existing activation decision rather than evaluating activation policy itself.

## Boundaries

**In scope:**
- Definition of surface-agnostic activation intent.
- Explore versus Activate boundary.
- Activation Governor authority boundary and decision vocabulary.
- Parent intent/readiness plus `allow_activation` requirement for `candidate -> active`.
- Garden Memory state vocabulary and anti-checklist semantics.
- Parent-confirmed meaningful Garden transfer transitions.
- Weak-signal limits.
- Contract verifier pass/fail rules.

**Out of scope:**
- Activation algorithm, scoring, thresholds beyond the contract-level pacing limits, or exact policy implementation.
- UI layout, copy finalization, navigation, interaction controls, or parent-confirmation component design.
- Database schema, API shape, event names, migration files, or persistence model.
- Runtime Agent payload schema, response-generation contract, Strategy Graph details, Strategy Pack schema, or Primitive sequencing.
- Exact domain class names, package/module structure, state management approach, or repository implementation.
- Metrics instrumentation and dashboards; Phase 41 owns parent-confirmed micro-ritual transfer metrics.
- Push/reminder implementation; Phase 40 only states that any push/reminder activation intent must be governed.

## Constraints

- Phase 40 is a WHAT/WHY contract. discuss-phase and plan-phase decide HOW.
- Explore must stay open. Do not require Governor approval for every candidate, example, explanation, or future-route discussion.
- Activation intent is surface-agnostic. Do not restrict the gate to Runtime only.
- Conservative activation is a product safety constraint, not a content-availability constraint.
- Garden Memory must remain low-shame and parent-confirmed; it must not become a completion tracker or scoring layer.
- Existing `mobile/` Garden, phrase, activity, completion, streak, fertilizer, and growth semantics remain deprecated or reference-only per Phase 39.
- Existing infrastructure may be reused only if it does not import old product progression semantics into vNext.

## Acceptance Criteria

- [ ] SPEC defines activation-intent gating as surface-agnostic and includes examples of gated language/actions.
- [ ] SPEC states candidate generation, examples, explanations, and route exploration are not activation.
- [ ] SPEC states Explore remains open unless it uses activation language or implies family-routine action now.
- [ ] SPEC states Runtime cannot self-govern activation policy and Pack/Graph matching cannot directly create active rituals.
- [ ] SPEC states `candidate -> active` requires parent intent/readiness plus Governor `allow_activation`.
- [ ] SPEC preserves conservative active capacity as a contract-level constraint while deferring enforcement details.
- [ ] SPEC defines Garden Memory states without checklist, streak, completion, score, growth, fertilizer, reward, unlock, or punishment semantics.
- [ ] SPEC states `active -> familiar`, `active -> resting`, and `familiar -> belongs-to-family` require parent confirmation.
- [ ] SPEC states weak signals may suggest prompts but cannot directly mark `familiar`, `belongs-to-family`, or active family transfer.
- [ ] SPEC requires a machine-checkable contract verifier as the main proof artifact.
- [ ] SPEC defers algorithm, UI, schema, Runtime payloads, and exact implementation model to discuss/plan.

## Phase 40 Proof Artifacts

Phase 40 is closed by executable proof artifacts, not by SPEC text alone:

- `40-ACTIVATION-GOVERNOR-CONTRACT-PROOF.md` - source coverage audit, R063/R064/R065 proof map, D-01 through D-33 coverage, and compact decision/state matrix preservation.
- `tool/verify_activation_governor_contract.dart` - pure Dart Activation Governor / Garden Memory contract verifier and CLI gate.
- `test/tool/verify_activation_governor_contract_test.dart` - root verifier tests for authority seams, Explore openness, activation intent, weak-signal limits, and parent-confirmed Garden Memory transitions.
- `test/features/vnext/activation_governor_contract_surface_test.dart` - surface scanner tests for Home, Onboarding, Garden, Runtime, reminder/push-like copy, suspicious authority names, and Garden pressure copy.
- `mobile/test/tool/verify_activation_governor_contract_test.dart` - mobile wrapper parity forwarding to the root verifier tests.
- `40-VALIDATION.md` - Phase 40 validation record, Nyquist coverage map, and final automated gate commands.

## Ambiguity Report

| Dimension           | Score | Min   | Status | Notes |
|---------------------|-------|-------|--------|-------|
| Goal Clarity        | 0.90  | 0.75  | met    | Activation-intent gating and Garden Memory transfer contract are explicit. |
| Boundary Clarity    | 0.88  | 0.70  | met    | Explore remains open; Activate is gated everywhere; implementation details are deferred. |
| Constraint Clarity  | 0.83  | 0.65  | met    | Parent confirmation, weak-signal limits, capacity semantics, and anti-checklist constraints are locked. |
| Acceptance Criteria | 0.87  | 0.70  | met    | Contract verifier failure modes and SPEC checkboxes are pass/fail. |
| **Ambiguity**       | 0.13  | <=0.20| met    | Gate passed after round 1. |

Status: met = met minimum, below = below minimum (planner treats as assumption)

## Interview Log

| Round | Perspective | Question summary | Decision locked |
|---|---|---|---|
| 1 | Researcher | What counts as an Activate attempt that must pass through Activation Governor? | Activation-intent gated everywhere. Candidate generation and Explore remain open, but any CTA or implication that a candidate should enter family routine must pass Governor first, regardless of surface. |
| 1 | Researcher | Which Garden Memory transitions must be parent-confirmed? | `active -> familiar`, `active -> resting`, and `familiar -> belongs-to-family` require parent confirmation. `candidate -> active` requires parent intent/readiness plus Governor `allow_activation`; weak signals cannot silently create active or transfer states. |
| 1 | Researcher | What should Phase 40 require as the main proof artifact? | A machine-checkable contract verifier is required. Docs matrix alone is insufficient, while concrete domain model tests are deferred until discuss/plan chooses the implementation model. |
| 1 | Gate | Ambiguity reached 0.13. Proceed? | User approved writing SPEC with locked decisions and deferral boundaries. |

---

*Phase: 40-activation-governor-garden-memory*
*Spec created: 2026-06-15*
*Next step: $gsd-discuss-phase 40 - implementation decisions (how to build what is specified above)*
