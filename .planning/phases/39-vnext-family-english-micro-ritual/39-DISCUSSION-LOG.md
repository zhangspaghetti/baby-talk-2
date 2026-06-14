# Phase 39: vnext-family-english-micro-ritual - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-15T07:36:14.4080395+08:00
**Phase:** 39-vnext-family-english-micro-ritual
**Areas discussed:** Greenfield module boundary, Surface rewrite order, Semantic firewall strictness, Reusable reference assets, Proof and verifier shape

---

## Greenfield Module Boundary

| Option | Description | Selected |
|--------|-------------|----------|
| Independent `mobile_v2/` | New app/package isolated from old `mobile/`; old app remains deprecated reference. | ✓ |
| vNext modules beside old features | Add new modules near `practice/onboarding/garden` while preserving old app structure. | |
| Surface-by-surface replacement | Rewrite old surfaces in place over time. | |

**User's choice:** Independent `mobile_v2/`.
**Notes:** There are no real users or online compatibility pressure. Old `PracticePhrase`, `Activity`, completion, streak, and Garden growth semantics are too deeply embedded in models, UI, tests, and names. A path boundary gives planners, executors, and verifiers a clearer way to prevent semantic contamination.

---

## Surface Rewrite Order

| Option | Description | Selected |
|--------|-------------|----------|
| Onboarding first | Prove first low-pressure micro-ritual entry before Home/Practice/Garden. | ✓ |
| Home first | Start with current-moment orientation. | |
| Practice first | Start with micro-ritual speaking support. | |
| Garden first | Start with memory surface. | |

**User's choice:** Onboarding -> Home -> Practice -> Garden boundary.
**Notes:** Preferred vertical slice is `first micro-ritual onboarding -> Home shows current gentle ritual -> Practice supports speaking it -> Garden only shows non-scoring memory boundary/placeholder`. Garden remains boundary-only in this phase because Garden Memory transitions belong to Phase 40.

---

## Semantic Firewall Strictness

| Option | Description | Selected |
|--------|-------------|----------|
| Hard firewall | Ban old semantic fields in runtime paths; allow only explicit quarantine/reference paths. | ✓ |
| Soft migration adapter | Permit transitional old fields while wrapping/relabeling them. | |
| Planner discretion | Let downstream agents decide case by case. | |

**User's choice:** Hard firewall.
**Notes:** Runtime/product paths in `mobile_v2/lib` must not introduce or reuse `phraseId`, `activityId`, `completedPhrase`, `completedPhraseCount`, `completedPhraseIds`, `nextPhraseId`, `currentStreakDays`, `streak`, old `GardenGrowth`, phrase completion as progress, or activity/path completion as success. Exceptions are limited to reference/quarantine/docs/test-fixture locations and cannot become runtime domain truth.

---

## Reusable Reference Assets

| Option | Description | Selected |
|--------|-------------|----------|
| Reference assets only | Reuse/copy tone, tokens, interactions, raw materials, infrastructure, and tests only after rebuilding meaning. | ✓ |
| Reuse old product catalog | Preserve phrase/activity catalog as product truth. | |
| No reuse | Avoid all old mobile materials. | |

**User's choice:** Reference assets only.
**Notes:** Warm visual tone, design tokens, low-pressure onboarding/copy style, audio/recording/TTS/pronunciation interactions, existing English material, auth, consent, event sourcing, gateway, Helm, Flyway, CI, and test/verifier experience are allowed references. Phrase catalog, activity/path progression, phrase completion, streak, Garden growth/fertilizer/blooming, "next incomplete" Home logic, and `starterPhraseId` onboarding truth are not allowed as vNext semantics.

---

## Proof and Verifier Shape

| Option | Description | Selected |
|--------|-------------|----------|
| Strong verifier proof | Require semantic firewall verifier, import guard, banned-term scan, targeted tests, and docs proof. | ✓ |
| Docs-only proof | Rely on CONTEXT/SPEC and manual review. | |
| Manual review | Inspect implementation without machine-enforced guards. | |

**User's choice:** Strong verifier proof.
**Notes:** Downstream work must produce a `mobile_v2` semantic firewall verifier, grep/import guard, banned-term scan with allowlist, targeted unit/widget tests for onboarding/Home/Practice, and docs supersession proof for reused assets.

---

## the agent's Discretion

No areas were delegated to the agent's discretion. Technical implementation inside `mobile_v2/` remains flexible only within the locked semantic boundary.

## Deferred Ideas

- Deleting or cleaning up old `mobile/` belongs to a later explicit cleanup phase.
- Activation Governor and full Garden Memory transition mechanics belong to Phase 40.
- Pack, Graph, Runtime Agent, and transfer metrics contracts belong to Phase 41.
