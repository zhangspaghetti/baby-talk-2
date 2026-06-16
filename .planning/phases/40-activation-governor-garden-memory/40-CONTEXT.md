# Phase 40: activation-governor-garden-memory - Context

**Gathered:** 2026-06-16T09:04:33.9113771+08:00
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 40 locks the implementation-facing contract for Activation Governor and Garden Memory pacing. It decides how vNext proves that activation intent is gated everywhere, Explore remains open, Pack/Graph cannot activate, Runtime cannot self-govern activation, and Garden Memory records only low-pressure parent-confirmed transfer states.

This context is about the contract and proof shape. It is not the Activation Governor algorithm, Garden Memory implementation, database schema, API shape, Runtime Agent payload, UI control design, or Phase 41 Strategy Pack/Runtime/metrics contract.

</domain>

<spec_lock>
## Requirements (locked via SPEC.md)

**9 requirements are locked.** See `40-SPEC.md` for full requirements, boundaries, and acceptance criteria.

Downstream agents MUST read `40-SPEC.md` before planning or implementing. Requirements are not duplicated here.

**In scope (from SPEC.md):**
- Definition of surface-agnostic activation intent.
- Explore versus Activate boundary.
- Activation Governor authority boundary and decision vocabulary.
- Parent intent/readiness plus `allow_activation` requirement for `candidate -> active`.
- Garden Memory state vocabulary and anti-checklist semantics.
- Parent-confirmed meaningful Garden transfer transitions.
- Weak-signal limits.
- Contract verifier pass/fail rules.

**Out of scope (from SPEC.md):**
- Activation algorithm, scoring, thresholds beyond the contract-level pacing limits, or exact policy implementation.
- UI layout, copy finalization, navigation, interaction controls, or parent-confirmation component design.
- Database schema, API shape, event names, migration files, or persistence model.
- Runtime Agent payload schema, response-generation contract, Strategy Graph details, Strategy Pack schema, or Primitive sequencing.
- Exact domain class names, package/module structure, state management approach, or repository implementation.
- Metrics instrumentation and dashboards; Phase 41 owns parent-confirmed micro-ritual transfer metrics.
- Push/reminder implementation; Phase 40 only states that any push/reminder activation intent must be governed.

</spec_lock>

<decisions>
## Implementation Decisions

### Contract Verifier Shape
- **D-01:** Phase 40 must create an independent, repo-owned machine-checkable contract verifier. It should be a repository artifact such as `tool/verify_activation_governor_contract.dart` with fixtures and tests, not a Codex/GSD skill and not just an extension of the Phase 39 semantic-firewall verifier.
- **D-02:** The verifier should reuse the Phase 39 verifier's scanning, report, fail-closed, and allowlist ideas, but Phase 40 owns a separate Activation Governor / Garden Memory contract proof.
- **D-03:** The verifier scope is intentionally narrow for this phase: scan `mobile_v2/lib`, Phase 40 structured contract fixtures, and tests/proof fixtures created specifically for the Activation Governor / Garden Memory contract.
- **D-04:** Do not scan repo-wide yet. Repo-wide scanning is deferred until more vNext paths exist because current repo-wide scans would confuse docs, proof text, architecture docs, reference/quarantine material, deprecated `mobile/`, and old product code with active vNext truth.
- **D-05:** The verifier must be a contract verifier, not a pure grep tool. Structured fixtures are the authority backbone; language/name scans are auxiliary guards.
- **D-06:** Structured fixtures should explicitly model fields such as `producer`, `consumer`, `decisionSource`, `gardenAction`, `requiresGovernorDecision`, and `requiresParentConfirmation`.
- **D-07:** Language/name scans should catch activation CTAs, old Garden/checklist/streak/growth language, and suspicious authority names. If structured fields look valid but copy says "try this today", "add this sound", "start this ritual", or equivalent activation intent without a Governor decision, the verifier must fail.
- **D-08:** Suspicious authority names such as `markFamiliar`, `setActive`, and `activationPolicy` should require proof that they live within allowed Governor or Garden parent-confirmation boundaries.
- **D-09:** A project-local skill may later remind agents to run/use the verifier, but the skill cannot replace the repo-owned verifier as the acceptance proof.

### Authority Seams
- **D-10:** The strongest fail-closed line is all three authority seams equally: Pack/Graph cannot activate; Runtime cannot self-govern activation; Garden cannot own activation policy.
- **D-11:** Activation Governor is the only activation pacing authority.
- **D-12:** Pack/Graph may produce candidates only. Pack/Graph matching must not directly create an active micro-ritual or imply the family should say/use it today.
- **D-13:** Runtime may consume an existing Activation Governor decision. Runtime must not read activation policy or decide on its own whether a candidate enters family routine.
- **D-14:** Garden may present state and collect parent confirmation. Garden must not own activation policy or convert weak signals into meaningful transfer states.
- **D-15:** All three seams must be represented as negative fixtures so planner/executor cannot prove only one seam while leaving another soft.

### Fixture Format and Coverage
- **D-16:** Use typed Dart fixture objects and table-driven tests for Phase 40. Do not introduce JSON/YAML fixture files in this phase.
- **D-17:** Use a small typed helper such as `ActivationGovernorContractCase` with fields like `id`, `description`, `surface`, `producer`, `consumer`, `decisionSource`, `text`, `gardenAction`, `hasGovernorDecision`, `hasParentIntent`, `requiresGovernorDecision`, `requiresParentConfirmation`, `weakSignalOnly`, `expectedPass`, and `expectedReason`.
- **D-18:** Fixture groups must include positive Explore cases, positive Runtime-consuming-existing-decision cases, negative Pack/Graph activation shortcuts, negative Runtime self-governance, negative Garden-owning-policy, negative activation CTA without Governor decision, negative weak-signal promotion, negative checklist/streak/growth language, and positive low-pressure parent-confirmation prompts.
- **D-19:** Activation intent examples should cover all relevant surfaces: Home, Onboarding, Garden, Runtime, and reminder/push-like copy.
- **D-20:** Positive Explore fixtures are required. They must prove that ideas, examples, routes, future expansion, and expert explanation can remain open when they do not ask or imply that a candidate should enter family routine now.
- **D-21:** Negative activation-intent fixtures must cover language equivalent to "today try this", "add this sound", "start this micro-ritual", "say this during [routine] today", or similar product intent without a Governor decision.

### Parent Confirmation and Weak Signals
- **D-22:** Weak signals may create prompts or review opportunities only. They must not write Garden Memory truth states.
- **D-23:** Allowed without parent confirmation: show a review prompt, suggest asking the parent, surface "Does this feel familiar?", surface "Want to rest this for now?", surface "Has this become part of your family words?", or create a non-persistent UI prompt/review opportunity in fixtures.
- **D-24:** Not allowed without parent confirmation: set `familiar`, set `resting`, set `belongs_to_family`, set or imply family transfer, count repeated views/usage/time as proof, mark progress toward transfer, or auto-create "almost familiar" style truth.
- **D-25:** Do not introduce intermediate truth-like states such as `suggested_familiar` in Phase 40. If planning later needs a technical queue, represent it as a prompt/review request, not as a Garden Memory state.
- **D-26:** Weak-signal-only fixtures may pass only when `gardenAction` is prompt/review/suggestion and no meaningful state changes occur.
- **D-27:** Weak-signal-only fixtures must fail if they produce `familiar`, `resting`, `belongs_to_family`, or any truth-like transfer state.
- **D-28:** Parent-confirmed fixtures may pass for meaningful transitions only when confirmation is low-pressure and non-scoring.
- **D-29:** Parent confirmation language should be warm and low pressure, for example: "这句最近会自然冒出来吗？", "要不要先放一边？", and "这句是不是已经属于你们家了？"
- **D-30:** Do not use score, checklist, streak, growth, unlock, reward, progress bar, or similar completion pressure for Garden Memory confirmation.

### Decision and State Matrix
- **D-31:** Downstream agents must receive and preserve a compact decision/state matrix. The matrix is a contract, not a schema.
- **D-32:** The matrix must be clear enough to drive verifier fixtures and planning pass/fail judgments.
- **D-33:** Do not use the matrix to lock API payloads, database fields, class names, event names, UI controls, or Runtime Agent payloads.

| Decision / State | Allowed Producer | Allowed Consumer | Prerequisites | Forbidden Shortcut | Parent Confirmation Required? | Weak-Signal Allowance | Verifier Expectation |
|---|---|---|---|---|---|---|---|
| `candidate` | Pack/Graph, Explore, Expert/candidate generation | Governor, Explore, Garden as candidate display, Runtime only as non-activation content | Candidate generation only; no activation CTA or implied family action now | Candidate directly creates `active` or says the family should try/say/start it today | No | May inform candidates or review prompts only | Pass candidate/example/routes without activation language; fail candidate-to-active shortcut |
| `active` | Activation Governor decision applied after parent intent/readiness | Runtime, Garden, Home/Onboarding surfaces that display active family action | Explicit parent intent/readiness plus Governor `allow_activation`; conservative active capacity respected | Pack match, Runtime, Garden, telemetry, usage count, weak signal, or inferred fit sets active | Yes: parent intent/readiness is required before activation | None for direct state change | Fail any `active` creation without parent intent/readiness and Governor `allow_activation` |
| `familiar` | Garden parent-confirmation flow; Governor may consume/result from the confirmed state but not infer it from telemetry | Garden, Governor, Runtime pacing | Parent explicitly confirms the sound is becoming natural/familiar | Repeated opens, usage, elapsed time, child response, completion, or system inference marks familiar | Yes | May prompt the question only | Pass low-pressure confirmation; fail weak-signal promotion |
| `resting` | Garden parent-confirmation flow, possibly after Governor `rest_existing` recommendation | Garden, Governor, Runtime pacing | Parent confirms the sound should rest; no shame/failure framing | System auto-rests because of inactivity, missed usage, score, or penalty | Yes | May suggest asking whether to rest | Pass parent-confirmed rest; fail punishment/inactivity rest |
| `expandable` | Governor or Garden confirmation flow as a non-reward pacing cue around an existing sound | Governor, Runtime, Explore, Garden | Existing active/familiar context; nearby expansion does not create a new active ritual | Treating expansion as unlock, reward, progress, or unlimited new content pressure | Not for an Explore suggestion; yes if stored as durable family-memory truth | May suggest review/nearby expansion prompt only | Pass light expansion candidate; fail if it becomes reward/unlock/progress |
| `belongs_to_family` state | Garden parent-confirmation flow | Garden, Governor, Runtime/reminder pacing | Parent confirms the sound belongs to the family and may exit app reminders | Telemetry, repeated use, child response, usage count, or system inference claims family transfer | Yes | May prompt the question only | Pass explicit low-pressure confirmation; fail auto-transfer |
| `allow_activation` | Activation Governor only | Runtime, Home, Onboarding, Garden display/action surfaces | Candidate exists, parent intent/readiness exists, active capacity/pacing contract allows activation | Pack/Graph/Runtime/Garden emits allow decision or directly activates | Requires parent intent/readiness | Weak signals may inform prompt/context, not produce decision alone | Fail activation CTA without Governor decision |
| `nearby_expansion_only` | Activation Governor only | Runtime, Explore, Garden/Home surfaces | Existing sound context; expansion stays near current ritual; no new active ritual | New scene/ritual activation disguised as expansion; unlimited expansion pressure | Parent intent/readiness required if asking for family action now | May suggest a review or expansion prompt only | Pass nearby wording that does not create new active; fail new activation shortcut |
| `defer_to_garden` | Activation Governor only | Runtime, Garden/Home surfaces | Activation intent exists but pacing/readiness suggests returning to Garden review first | Runtime/Garden uses defer as its own policy decision without Governor | No transfer confirmation by itself | Weak signals may trigger review prompt considered by Governor | Pass Governor-authored defer; fail non-Governor policy ownership |
| `save_for_later` | Activation Governor for pacing decision; parent/user may explicitly save content without creating activation | Garden, Explore, Runtime pacing | Content can be saved without becoming today's family action | Save silently becomes active or "should say today" | No transfer confirmation by itself | May suggest saving/reviewing only | Pass save as non-activation; fail save-to-active shortcut |
| `rest_existing` | Activation Governor as recommendation; Garden parent-confirmation flow applies durable `resting` state | Garden, Runtime pacing | Existing active/familiar sound; pacing risk or parent desire to rest | System marks rest as failure, punishment, inactivity penalty, or Garden-owned policy | Yes before durable `resting` state | May prompt whether to rest | Pass rest recommendation plus parent confirmation; fail auto-rest truth |
| `belongs_to_family` decision | Activation Governor after/with parent-confirmed family transfer | Garden, Runtime/reminder pacing | Parent confirms familiar sound belongs to the family | System says learned/owned because of usage, score, child response, or repeated opens | Yes | May prompt the question only | Pass decision tied to confirmation; fail telemetry-based family transfer |

### the agent's Discretion
- Planner/executor may choose exact file names, class names, helper APIs, fixture grouping, report formatting, and test organization as long as they satisfy the contract above.
- Planner/executor may choose whether the Phase 40 verifier is a new file or a small package of files, but it must remain repo-owned and machine-checkable.
- Planner/executor may design the exact scanning implementation and allowlist mechanics.
- Planner/executor must not lock activation algorithms, database schema, API payloads, event names, UI controls, Runtime Agent payload schema, Strategy Pack schema, Primitive sequencing, or metrics instrumentation in Phase 40.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Lock
- `.planning/phases/40-activation-governor-garden-memory/40-SPEC.md` — locked Phase 40 requirements, boundaries, acceptance criteria, and verifier failure modes.
- `.planning/ROADMAP.md` — M010 ordering and Phase 40 position between Phase 39 semantic reset and Phase 41 runtime/metrics loop.
- `.planning/REQUIREMENTS.md` — active R063, R064, and R065 requirements; related R058-R060 and R066 handoffs.
- `.planning/STATE.md` — current M010 state and Phase 40 readiness note.

### Prior Phase Contract
- `.planning/phases/39-vnext-family-english-micro-ritual/39-SPEC.md` — locked vNext product thesis, micro-ritual unit, and supersession boundaries.
- `.planning/phases/39-vnext-family-english-micro-ritual/39-CONTEXT.md` — implementation decisions D-01 through D-22, including `mobile_v2/` boundary, reuse policy, and semantic firewall.
- `.planning/phases/39-vnext-family-english-micro-ritual/39-SUPERSESSION-PROOF.md` — source-grounded proof that old phrase/activity/completion/streak/Garden-growth semantics are deprecated or reference-only.

### vNext Product Source
- `docs/Baby_Talk_Product_Architecture_Spec_vNext.md` — canonical product architecture source for Activation Governor, Garden Memory, conservative activation/open exploration, decision vocabulary, and Runtime/Garden authority boundaries.
- `.planning/intel/decisions.md` — supplemental Activation Governor decision intel; does not override Phase 40 SPEC or this context.
- `.planning/intel/context.md` — supplemental product/design context, including Garden as low-shame family memory; does not override Phase 40 SPEC or this context.
- `.planning/intel/requirements.md` — supplemental requirement extraction for Activation Governor, Garden Memory, and parent-confirmed transfer.

### Existing Proof Pattern
- `tool/verify_mobile_v2_semantic_firewall.dart` — Phase 39 verifier pattern to reuse conceptually: typed scan report, fail-closed runtime boundary, allowlisted references, CLI report, success marker.
- `test/tool/verify_mobile_v2_semantic_firewall_test.dart` — table-style verifier tests and temporary project fixtures to emulate pass/fail runtime cases.
- `test/features/vnext/mobile_v2_surface_contract_test.dart` — proof that surface contract violations can be represented as focused Dart fixtures.
- `mobile_v2/lib/vnext_semantic_boundary.dart` — current vNext runtime boundary; Phase 40 scan scope includes `mobile_v2/lib`.

### Deprecated Reference / Landmines
- `mobile/lib/features/practice/data/repositories/garden_growth_repository.dart` — old Garden growth projection; reference-only and a source of banned semantics.
- `mobile/lib/features/practice/domain/models/garden_growth_snapshot.dart` — old Garden growth/streak/milestone shape; reference-only and not vNext truth.
- `mobile/lib/features/garden/presentation/garden_fertilizer_notifier.dart` — old fertilizer/growth composition; reference-only and not Garden Memory truth.
- `mobile/lib/features/shell/presentation/widgets/garden_patch_card.dart` — old progress/flower/stage UI semantics; reference-only visual/anti-pattern material.
- `mobile/lib/features/garden/data/models/garden_snapshot_payload.dart` — old Garden payload with streak/milestone semantics; reference-only.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/service/GardenSnapshotService.java` — backend old Garden streak/milestone projection; deprecated semantics and not vNext truth.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `tool/verify_mobile_v2_semantic_firewall.dart`: reuse the reporting, scanning, fail-closed, allowlist, and CLI style, but create a distinct Phase 40 contract verifier.
- `test/tool/verify_mobile_v2_semantic_firewall_test.dart`: reuse table-driven temporary-project fixture style.
- `test/features/vnext/mobile_v2_surface_contract_test.dart`: reuse focused pass/fail surface fixture pattern.
- `mobile_v2/lib/vnext_semantic_boundary.dart`: current vNext runtime boundary and the real code path that Phase 40 should scan.

### Established Patterns
- Phase 39 already made `mobile_v2/lib` the active vNext runtime truth boundary and keeps old `mobile/` as deprecated reference only.
- Existing proof prefers repo-root Dart verifier/tests over docs-only assertions.
- Existing allowlist logic distinguishes runtime truth from reference/quarantine material. Phase 40 should preserve that idea because negative fixtures may intentionally contain old or forbidden terms.

### Integration Points
- A likely proof path is a new root tool such as `tool/verify_activation_governor_contract.dart`, plus focused tests under `test/tool/` and/or `test/features/vnext/`.
- The verifier should scan `mobile_v2/lib` but keep architecture docs, Phase 39 proof text, deprecated `mobile/`, and explicit reference/quarantine folders outside the main runtime scan.
- Phase 40 plans should connect the verifier to the existing root Flutter/Dart test flow, similar to Phase 39, so it can be rerun by CI/review agents.

</code_context>

<specifics>
## Specific Ideas

- Discussed priority order: first verifier shape and authority seams, then activation fixtures and parent confirmation, then decision/state matrix.
- Preferred verifier identity: "contract verifier", not pure string scanner.
- Preferred fixture helper: `ActivationGovernorContractCase`.
- Preferred fixture fields: `id`, `description`, `surface`, `producer`, `consumer`, `decisionSource`, `text`, `gardenAction`, `hasGovernorDecision`, `hasParentIntent`, `requiresGovernorDecision`, `requiresParentConfirmation`, `weakSignalOnly`, `expectedPass`, `expectedReason`.
- Required negative fixtures: Runtime self-governance, Pack-to-active shortcut, Garden owning policy, activation CTA without Governor decision, weak-signal promotion, checklist/streak/growth language.
- Required positive fixtures: Explore examples/routes without activation intent, Runtime consuming an existing decision, Garden prompting for parent confirmation without changing meaningful transfer state.
- Activation examples must cover Home, Onboarding, Garden, Runtime, and reminder/push-like copy.
- Low-pressure confirmation examples: "这句最近会自然冒出来吗？", "要不要先放一边？", "这句是不是已经属于你们家了？"

</specifics>

<deferred>
## Deferred Ideas

- Repo-wide vNext scan is deferred until more vNext runtime paths exist.
- JSON/YAML fixture files are deferred until typed Dart cases stabilize or non-engineer/external-tool review becomes necessary.
- A project-local skill that reminds agents to run/use the verifier is optional and deferred; it is not the Phase 40 acceptance proof.
- Activation algorithm, database schema, API payloads, Runtime Agent payload schema, event names, UI controls, Strategy Pack schema, Primitive sequencing, and metrics instrumentation remain out of Phase 40 context and must not be locked here.
- Phase 41 owns Strategy Pack / Graph / Runtime Agent details and parent-confirmed transfer metrics.

</deferred>

---

*Phase: 40-activation-governor-garden-memory*
*Context gathered: 2026-06-16T09:04:33.9113771+08:00*
