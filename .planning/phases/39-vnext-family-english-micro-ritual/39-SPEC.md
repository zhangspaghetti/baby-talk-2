# Phase 39: vNext 产品承诺与 Family English Micro-ritual 单元收敛 - Specification

**Created:** 2026-06-15
**Ambiguity score:** 0.14 (gate: <= 0.20)
**Requirements:** 8 locked

## Goal

Baby Talk vNext changes the active product contract from phrase/activity/completion/growth semantics to a greenfield Family English Micro-ritual contract, with explicit WHAT-level supersession boundaries for Home, Practice, Onboarding, and Garden before implementation planning begins.

## Background

M010 was restarted because the previous phases 39-41 were generated from outdated planning docs. The active source is `docs/Baby_Talk_Product_Architecture_Spec_vNext.md`, which defines Baby Talk v1 as a Family English Micro-ritual System plus Activation-governed English Enlightenment Expert.

The current codebase is still built around the old development product model. Mobile domain models include `PracticePhrase` with `spaceId`, `activityId`, `phraseId`, `step`, `english`, `chinese`, and audio fields. Practice catalog summaries expose `completedPhraseCount`, `completedPhraseIds`, `nextPhraseId`, and related completion data. Garden projection models expose `GardenPatchStage`, `GardenFlowerStage`, `GardenGrowthSnapshot.currentStreakDays`, and phrase-completion-derived growth states. Onboarding stores `starterPhraseId` and routes through scene/practice/garden welcome flows. Discover, Home, Me, Practice, Onboarding, and Garden UI code all reference activity/phrase/growth/streak assumptions in some form.

There are no real users or online compatibility requirements for this development-stage software. Therefore the old product model is not a legacy implementation to wrap first. It is a deprecated reference: useful for comparison, selective code movement, and proof reuse, but not a compatibility target and not a semantic foundation for vNext.

Previously validated infrastructure remains valuable if it does not carry old product semantics: auth, consent, append-only event sourcing, gateway, Helm, Flyway/db-migration, CI smoke patterns, admin auth, and related deployment proof can be selectively reused. Product semantics from phrase/activity/completion/streak/growth must not be carried into vNext by default.

## Requirements

1. **vNext thesis lock**: The SPEC must define Baby Talk vNext as Family English Micro-ritual first, with conservative activation and open exploration as product principles.
   - Current: Planning history and shipped development UI still contain phrase cards, activities, completion counts, streaks, and garden growth semantics.
   - Target: Phase 39 locks the product meaning as "few low-pressure English sounds migrate into family routine", not "more phrases, more activities, more completion, more streak, or more generated content".
   - Acceptance: The SPEC states the vNext thesis and non-goals explicitly, and the acceptance criteria reject phrase/activity/completion/streak/growth as active product goals.

2. **Greenfield domain stance**: vNext may start from clean domain modules and is not required to wrap, migrate, or preserve old product-domain compatibility.
   - Current: Old mobile and backend code can be read as working examples, but its product semantics are phrase/activity/completion/garden-growth oriented.
   - Target: Old product code is classified as deprecated reference; vNext planners may create new directories/modules and clean domain models during discuss/plan without first designing a compatibility wrapper.
   - Acceptance: The Supersession Matrix classifies old product semantics as Deprecated or Reference only, and does not mark any phrase/activity/completion/streak/growth product concept as Keep.

3. **Micro-ritual replaces phrase/activity/completion**: Family English Micro-ritual is the core vNext product unit and directly replaces Phrase, Activity, completedPhrase, streak, and old Garden growth as product semantics.
   - Current: `PracticePhrase`, `PracticeCatalogActivitySummary`, `InteractionEventPayload.phraseId`, Garden growth projection, and tests treat phrase completion and reactions as the central loop.
   - Target: A micro-ritual is the unit that can become part of family routine. It must at minimum describe a stable sound, routine anchor, action binding, tone, no-response rule, soft variant, do-not-use conditions, and exit condition.
   - Acceptance: The SPEC names Family English Micro-ritual as the replacement unit and rejects "Phrase", "Activity", "completion", "streak", and old "growth" as vNext product truth.

4. **Context Seed and Joinability boundary**: Phase 39 must lock the WHAT-level boundary between observed evidence and interpreted joinability.
   - Current: Existing activity/phrase flows can treat user selection or recent practice as enough to continue a task or recommend the next phrase.
   - Target: Observed Moment/Context Seed is evidence only; Interpreted Moment/Joinability is a hypothesis about whether English can lightly join without testing, replacing, diagnosing, or creating pressure.
   - Acceptance: The SPEC states that Context Seed cannot automatically activate new content, and that matching or recommending a candidate is not activation.

5. **Core surface supersession boundaries**: Phase 39 must define WHAT-level supersession boundaries for Home, Practice, Onboarding, and Garden.
   - Current: Home can return to task entry, Practice can return to phrase completion, Onboarding can return to choosing activity/path, and Garden can return to growth/streak/progress.
   - Target: Each surface is redefined by vNext product semantics only: Home orients the current family moment, Practice supports one micro-ritual becoming speakable in routine, Onboarding proves low-pressure entry into a first micro-ritual, and Garden remembers parent-confirmed family-language transfer without scoring.
   - Acceptance: The SPEC includes a surface boundary table that names each surface, its vNext WHAT, invalid old assumptions, and what is deferred to Phase 40 or Phase 41.

6. **Pass/fail supersession matrix**: Phase 39 must include a matrix that leaves no ambiguity for downstream planners about old docs, old code semantics, and old UI assumptions.
   - Current: `.planning/REQUIREMENTS.md`, old design docs, and mobile code contain mixed references to Home, Practice, Onboarding, Garden, phrase, activity, pack, growth, and metrics.
   - Target: The matrix assigns every relevant old concept to one of: Deprecated, Reference only, Re-derived, Deferred to Phase 40, Deferred to Phase 41, or Keep.
   - Acceptance: A verifier can read the matrix and determine whether a downstream plan wrongly carries an old semantic into vNext.

7. **Infrastructure reuse boundary**: Phase 39 must distinguish reusable infrastructure from deprecated product semantics.
   - Current: The repo has validated auth, consent, event append, gateway, Helm, db-migration/Flyway, CI, admin auth, and deployment proof, alongside product-domain code built on old phrase/activity semantics.
   - Target: Infrastructure can be Keep or Reference only if it does not force phrase/activity/completion/streak/growth semantics into vNext.
   - Acceptance: The SPEC's matrix marks reusable infrastructure as Keep with a product-semantic firewall, and marks product-domain payloads or fields as Deprecated/Re-derived rather than Keep.

8. **Phase 40 and Phase 41 deferral boundary**: Phase 39 must not decide implementation structure, activation policy mechanics, runtime schemas, or metrics instrumentation.
   - Current: vNext architecture doc describes Activation Governor, Garden Memory, Strategy Pack, Strategy Graph, Runtime Agent, and transfer metrics, but Phase 39 is only the WHAT/supersession lock.
   - Target: Phase 39 defers Activation Governor and Garden Memory pacing decisions to Phase 40, and defers Primitive/Graph/Pack/Runtime/metrics contracts to Phase 41.
   - Acceptance: The SPEC has explicit out-of-scope items for layout, navigation, directory structure, state management, schema design, rewrite steps, activation algorithms, runtime contracts, and metrics implementation.

## Surface Supersession Boundaries

| Surface | vNext WHAT | Invalid old assumptions | Deferred |
|---|---|---|---|
| Home | Orients the parent to the current family moment and whether a micro-ritual can lightly join. | Home is not a task dashboard, activity launcher, phrase card list, completion prompt, or route to "do more". | Layout, navigation, and concrete entry components go to discuss/plan. Activation prompts and capacity rules go to Phase 40. |
| Practice | Helps one family micro-ritual become speakable in a real routine without testing the child or completing a phrase list. | Practice is not phrase progression, fixed phrase completion, mandatory reaction capture, streak contribution, or "say N sentences". | Turn/state mechanics, runtime response contract, Primitive selection, Pack/Graph integration go to Phase 41. |
| Onboarding | Proves low-pressure entry into a first candidate micro-ritual and establishes parent comfort/readiness signals. | Onboarding is not primarily choosing an activity/path, collecting required profile fields, completing a fixed phrase set, or seeding `starterPhraseId` as product truth. | Exact onboarding flow, screens, data persistence, and consent UX go to discuss/plan; activation readiness policy goes to Phase 40. |
| Garden | Remembers parent-confirmed family-language transfer states without shame, score, streak, or completion pressure. | Garden is not growth/progress visualization from completed phrases, not streak tracking, not fertilizer/reward loop, and not automatic proof that a child learned. | Garden Memory state transition and parent-confirmation rules go to Phase 40; transfer metrics implementation goes to Phase 41. |

## Supersession Matrix

| Item | Classification | Pass/fail rule |
|---|---|---|
| `Phrase` as core product unit | Deprecated | FAIL if a vNext plan treats phrase as the unit of product progress or family transfer. |
| `PracticePhrase` model and phrase catalog data | Reference only | PASS only if used as source material for wording/audio/examples; FAIL if copied as vNext domain truth. |
| `Activity`, `space`, `path`, and activity browsing as product progression | Deprecated | FAIL if vNext requires users to advance through activity/path completion. |
| Routine/context labels such as bath, shoes, sleep, wash hands | Re-derived | PASS only when re-derived as routine anchors for micro-rituals. |
| `completedPhraseCount`, `completedPhraseIds`, `nextPhraseId`, "all phrases completed" | Deprecated | FAIL if completion count determines success, Garden state, or user progress. |
| `currentStreakDays`, streak thresholds, streak bonus | Deprecated | FAIL if streaks appear as vNext success, retention, Garden, or parent feedback semantics. |
| Old Garden growth, patch/flower stages, fertilizer, blooming/fullBloom | Deprecated | FAIL if Garden state is generated from phrase completion or streak-like progress. |
| Existing Garden visual assets or warm design tokens | Reference only | PASS only as visual inspiration; FAIL if they preserve old growth/progress semantics. |
| Home as task/activity dashboard | Deprecated | FAIL if Home asks the parent to complete activities or maximize content. |
| Home as current-moment orientation | Re-derived | PASS if it is re-derived from Context Seed, joinability, and micro-ritual readiness. |
| Practice phrase card, audio, pronunciation, "I said it" widgets | Reference only | PASS only as interaction/material reference; FAIL if they define vNext loop completion. |
| Practice as micro-ritual support surface | Re-derived | PASS if it is defined around parent speakability and routine transfer, not completion. |
| Onboarding `starterPhraseId` and selected scene as product truth | Deprecated | FAIL if starter phrase/activity becomes vNext identity or progress truth. |
| Onboarding warm tone and low-friction entry intent | Re-derived | PASS if re-derived toward first candidate micro-ritual and parent readiness. |
| Design docs that assume Home/Practice/Onboarding/Garden old flows | Deprecated | FAIL if imported as binding vNext requirements without this SPEC's supersession classification. |
| Design docs as examples of copy, visual style, or UX risks | Reference only | PASS when used only as non-binding reference during discuss/plan. |
| Activation Governor decisions and active capacity | Deferred to Phase 40 | FAIL if Phase 39 invents activation algorithms or thresholds beyond naming the boundary. |
| Garden Memory states and parent-confirmed transition rules | Deferred to Phase 40 | FAIL if Phase 39 specifies transition mechanics or UI controls. |
| Primitive Library, Strategy Graph, Strategy Pack schema | Deferred to Phase 41 | FAIL if Phase 39 locks schema or runtime behavior beyond boundaries. |
| Runtime Agent input/output contract | Deferred to Phase 41 | FAIL if Phase 39 decides exact payloads, state machine, or response generation mechanics. |
| Parent-confirmed Micro-ritual Transfer metrics | Deferred to Phase 41 | FAIL if Phase 39 designs instrumentation or dashboards. |
| Auth, consent, local-first sensitive data practices | Keep | PASS if reused without importing old product progression semantics. |
| Append-only event sourcing pattern | Keep | PASS if event truth is reused with new micro-ritual events, not old phrase completion meaning. |
| Gateway, Helm, db-migration/Flyway, CI smoke, admin auth | Keep | PASS if reused as infrastructure only. |

## Boundaries

**In scope:**
- Phase 39 SPEC for vNext product thesis, non-goals, and first-principles unit.
- Explicit replacement of old Phrase/Activity/completion/streak/garden-growth product semantics with Family English Micro-ritual.
- WHAT-level surface boundaries for Home, Practice, Onboarding, and Garden.
- Supersession Matrix covering old design docs, old code semantics, old UI assumptions, deferred areas, and reusable infrastructure.
- Phase 40/41 deferral boundaries.

**Out of scope:**
- New directory/module structure - discuss/plan will decide HOW to organize code.
- Rewrite steps, migration order, or compatibility adapter design - no real-user compatibility pressure exists, and this phase only locks WHAT.
- UI layout, components, navigation, route names, visual hierarchy, copy finalization, or state management.
- Activation Governor algorithms, active capacity enforcement, Garden Memory transition mechanics, or parent-confirmation UI - Phase 40.
- Primitive Library implementation, Strategy Graph schema, Strategy Pack schema, Runtime Agent payloads, and metrics instrumentation - Phase 41.
- Backend/mobile/admin implementation work.
- Database schema changes or API contracts.

## Constraints

- Development-stage product: there is no real-user or online backward-compatibility constraint for old product semantics.
- Existing validated infrastructure may be reused only behind a product-semantic firewall: auth, consent, event sourcing, gateway, Helm, CI, Flyway/db-migration, and admin auth are infrastructure, not vNext product meaning.
- Phase 39 is a WHAT/WHY lock. It must not decide concrete implementation structure or rewrite sequencing.
- Any downstream plan that reuses old code must classify the reused material through the Supersession Matrix before treating it as vNext scope.
- Chinese/English parent-facing product tone remains low-pressure and non-testing, but final UI copy is not locked in this phase.

## Acceptance Criteria

- [ ] SPEC states that old `Phrase / Activity / completedPhrase / streak / Garden growth` semantics are Deprecated or Reference only, not legacy to wrap first.
- [ ] SPEC states that vNext may greenfield clean domain modules and is not required to preserve compatibility with old product-domain models.
- [ ] SPEC defines Family English Micro-ritual as the direct replacement product unit and includes minimum semantic fields.
- [ ] SPEC includes WHAT-level Home / Practice / Onboarding / Garden supersession boundaries and excludes layout, navigation, component, and state-management decisions.
- [ ] SPEC includes a pass/fail Supersession Matrix with the classifications Deprecated, Reference only, Re-derived, Deferred to Phase 40, Deferred to Phase 41, and Keep.
- [ ] SPEC marks reusable infrastructure as Keep only when it does not import old product semantics.
- [ ] SPEC clearly defers Activation Governor and Garden Memory pacing to Phase 40.
- [ ] SPEC clearly defers Pack / Graph / Runtime / metrics contracts to Phase 41.
- [ ] A planner can read this SPEC and know how to treat old Phrase/Activity/completion/streak/growth, the four core surface assumptions, referenceable assets, and Phase 40/41 handoffs without asking another WHAT question.

## Ambiguity Report

| Dimension          | Score | Min   | Status | Notes |
|--------------------|-------|-------|--------|-------|
| Goal Clarity       | 0.91  | 0.75  | ✓      | vNext product semantic restart is explicit. |
| Boundary Clarity   | 0.90  | 0.70  | ✓      | Deprecated/reference/re-derived/deferral/keep boundaries are matrixed. |
| Constraint Clarity | 0.78  | 0.65  | ✓      | No real-user compatibility pressure; infrastructure reuse is constrained by product-semantic firewall. |
| Acceptance Criteria| 0.86  | 0.70  | ✓      | Pass/fail matrix and checklist define verifier behavior. |
| **Ambiguity**      | 0.14  | <=0.20| ✓      | Gate passed after round 1. |

Status: ✓ = met minimum, ⚠ = below minimum (planner treats as assumption)

## Interview Log

| Round | Perspective | Question summary | Decision locked |
|---|---|---|---|
| 1 | Researcher | Should old Phrase/Activity/completion/streak/Garden growth be wrapped as legacy or replaced? | Old software has no real-user compatibility pressure; old product code is deprecated reference, and vNext may greenfield clean domain modules. |
| 1 | Researcher | Should Phase 39 define Home/Practice/Onboarding/Garden supersession boundaries? | Yes, at WHAT level only, because old semantics are anchored in those surfaces. |
| 1 | Researcher | Is a pass/fail supersession matrix required? | Yes. The SPEC passes only if the matrix tells planners what is Deprecated, Reference only, Re-derived, Deferred to Phase 40, Deferred to Phase 41, and Keep. |
| 1 | Gate | Ambiguity reached 0.14. Proceed? | User approved writing SPEC. |

---

*Phase: 39-vnext-family-english-micro-ritual*
*Spec created: 2026-06-15*
*Next step: $gsd-discuss-phase 39 - implementation decisions (how to build what is specified above)*
