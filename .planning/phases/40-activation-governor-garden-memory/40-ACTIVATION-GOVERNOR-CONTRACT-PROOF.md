---
phase: 40-activation-governor-garden-memory
status: approved
proof_type: activation-governor-garden-memory-contract
requirements: [R063, R064, R065]
created: 2026-06-16
---

# Phase 40 Activation Governor / Garden Memory Contract Proof

This proof closes the Phase 40 WHAT-level contract. It ties source requirements, Phase 40 decisions, verifier fixtures, and validation gates together so Phase 41 can consume the contract without treating it as an implementation design.

Phase 40 proves these truths:

- R063: Activation Governor is the pacing authority between Pack/Graph candidates and Runtime family-action responses.
- R064: Garden Memory is parent-confirmed family micro-ritual memory, not checklist, score, streak, completion, reward, or growth.
- R065: Explore remains open, while Activate is conservatively governed.
- D-31/D-32/D-33: the compact decision/state matrix is a contract for planning and verifier pass/fail judgments; it does not lock API payloads, database fields, class names, event names, UI controls, Runtime Agent payloads, Strategy Pack schema, Primitive sequencing, activation algorithms, or metrics instrumentation.

## Source Coverage Audit

| Source Type | Item | Coverage |
|-------------|------|----------|
| GOAL | Define activation pacing contract separating Explore from Activate, conservative micro-ritual activation, and parent-confirmed Garden Memory without checklist pressure. | Covered by 40-01 verifier foundation, 40-02 surface/Garden fixtures, and this proof/validation closeout. |
| REQ | R063 Activation Governor gates Activate between Pack/Graph candidates and Runtime responses. | Covered by authority fixture groups in `tool/verify_activation_governor_contract.dart`, root tests, surface tests, and final validation gate. |
| REQ | R064 Garden Memory is parent-confirmed family micro-ritual memory, not checklist/scoring. | Covered by weak-signal, parent-confirmation, and Garden pressure fixtures plus validation rows. |
| REQ | R065 Explore remains open while Activate is conservatively governed. | Covered by positive Explore cases and negative activation-intent cases across Home, Onboarding, Garden, Runtime, and reminder-like copy. |
| RESEARCH | Independent pure Dart verifier, no package installs, direct SDK fallback, Phase 39 regression guard. | Covered by the new verifier CLI, no dependency additions, Windows direct Dart commands, and the Phase 39 semantic firewall final gate. |
| CONTEXT | D-01 through D-09 contract verifier shape and skill non-substitution. | Covered by independent repo-owned `tool/verify_activation_governor_contract.dart`, not a GSD skill or Phase 39 verifier extension. |
| CONTEXT | D-10 through D-15 authority seams. | Covered by negative Pack/Graph, Runtime, and Garden authority fixtures. |
| CONTEXT | D-16 through D-21 typed fixtures and surface coverage. | Covered by `ActivationGovernorContractCase` and surface fixture tests. |
| CONTEXT | D-22 through D-30 parent confirmation and weak-signal limits. | Covered by weak-signal-only prompt pass cases, truth-state rejection cases, and low-pressure parent confirmation checks. |
| CONTEXT | D-31 through D-33 decision/state matrix contract, not schema. | Covered by the compact matrix below and explicit non-locking exclusions. |

No source item is intentionally unplanned. Deferred ideas remain excluded: repo-wide scan, JSON/YAML fixtures, project-local skill replacement, activation algorithms, database schema, API payloads, event names, UI controls, Runtime Agent payload schema, Strategy Pack schema, Primitive sequencing, and metrics instrumentation.

## Requirement Proof Map

| Requirement | Contract Meaning | Executable Proof |
|-------------|------------------|------------------|
| R063 | Only Activation Governor owns activation pacing decisions such as `allow_activation`, `nearby_expansion_only`, `defer_to_garden`, `save_for_later`, `rest_existing`, and `belongs_to_family`; Pack/Graph creates candidates, Runtime consumes decisions, Garden presents state/confirmation. | `default-pack-graph-shortcut-rejected`, `default-runtime-self-governance-rejected`, `default-garden-policy-rejected`, root authority tests, and surface suspicious-authority tests. |
| R064 | Garden Memory states such as `candidate`, `active`, `familiar`, `resting`, `expandable`, and `belongs_to_family` are family-memory states, not progress or score states; meaningful transfer requires low-pressure parent confirmation. | Weak-signal rejection tests, parent-confirmation tests, Garden pressure language tests, and source scanner pressure terms. |
| R065 | Explore examples, routes, explanations, future expansion, and candidate ideas remain open unless they ask or imply family action now. Any Activate/today/now/add/start/say-this action is governed. | Positive Explore tests plus activation-intent cases for Home, Onboarding, Garden, Runtime, and reminder/push-like copy. |

## Decision Coverage D-01 Through D-33

| Decision | Coverage |
|----------|----------|
| D-01 | Independent repo-owned verifier exists at `tool/verify_activation_governor_contract.dart`. |
| D-02 | The verifier reuses Phase 39 report/fail-closed/CLI ideas while staying separate from `tool/verify_mobile_v2_semantic_firewall.dart`. |
| D-03 | Runtime source scanning is intentionally limited to `mobile_v2/lib` plus typed Phase 40 contract cases and proof tests. |
| D-04 | Repo-wide scanning remains deferred; validation and summaries document this boundary. |
| D-05 | Structured `ActivationGovernorContractCase` fixtures are the authority backbone; text scans are auxiliary guards. |
| D-06 | Fixture fields include producer, consumer, decisionSource, gardenAction, requiresGovernorDecision, and requiresParentConfirmation. |
| D-07 | Activation copy, Garden pressure copy, and authority names are scanned in source and fixture text. |
| D-08 | `markFamiliar`, `setActive`, and `activationPolicy` are blocked unless they live under Governor or parent-confirmation boundaries. |
| D-09 | Any future skill can only remind agents to use the verifier; it cannot replace this repo-owned proof. |
| D-10 | Pack/Graph, Runtime, and Garden authority seams are all fail-closed. |
| D-11 | Activation Governor is the only activation pacing authority. |
| D-12 | Pack/Graph may produce candidates only; direct active creation or action-now copy is rejected. |
| D-13 | Runtime may consume an existing Governor decision; Runtime-owned activation policy is rejected. |
| D-14 | Garden may present state and collect parent confirmation; Garden-owned activation policy is rejected. |
| D-15 | All three authority seams are represented by negative fixtures. |
| D-16 | Fixtures are typed Dart cases; no JSON/YAML fixture files are introduced. |
| D-17 | `ActivationGovernorContractCase` implements the compact typed helper shape. |
| D-18 | Fixture groups include Explore positives, Runtime consumption positives, Pack/Graph/Runtime/Garden negatives, activation CTA negatives, weak-signal negatives, pressure-language negatives, and low-pressure confirmation positives. |
| D-19 | Activation examples cover Home, Onboarding, Garden, Runtime, and reminder/push-like copy. |
| D-20 | Positive Explore fixtures prove ideas, examples, routes, future expansion, and expert explanation can remain open. |
| D-21 | Negative activation-intent fixtures cover "today try this", "add this sound", "start this micro-ritual", and "say this during routine today" equivalents. |
| D-22 | Weak signals may create prompts or review opportunities only. |
| D-23 | Review prompts and parent questions may be surfaced without writing Garden Memory truth states. |
| D-24 | `familiar`, `resting`, `belongs_to_family`, active family transfer, and truth-like transfer progress cannot be inferred from weak signals. |
| D-25 | Truth-like intermediate states such as `suggested_familiar` are rejected. |
| D-26 | Weak-signal-only cases pass only when they remain prompt/review/suggestion actions. |
| D-27 | Weak-signal-only cases fail when they produce meaningful or truth-like states. |
| D-28 | Parent-confirmed meaningful transitions pass only with warm, low-pressure, non-scoring language. |
| D-29 | Warm confirmation examples are represented by Chinese and English low-pressure copy patterns. |
| D-30 | Score, checklist, streak, growth, unlock, reward, progress, and punishment terms are rejected for Garden Memory truth. |
| D-31 | The decision/state matrix below is preserved for downstream agents. |
| D-32 | The matrix is clear enough to drive verifier fixtures and planning pass/fail judgments. |
| D-33 | The matrix is not schema/API/UI/runtime design and must not lock API payloads, database fields, class names, event names, UI controls, Runtime Agent payloads, Strategy Pack schema, Primitive sequencing, activation algorithms, or metrics instrumentation. |

## Compact Decision / State Matrix

The matrix is a contract for authority, prerequisites, and pass/fail reasoning. It is not a schema, API, UI, runtime payload, algorithm, event model, database model, Strategy Pack schema, Primitive graph, or metrics design.

| Decision / State | Allowed Producer | Allowed Consumer | Prerequisites | Forbidden Shortcut | Parent Confirmation Required? | Weak-Signal Allowance | Verifier Expectation |
|---|---|---|---|---|---|---|---|
| `candidate` | Pack/Graph, Explore, Expert/candidate generation | Governor, Explore, Garden as candidate display, Runtime only as non-activation content | Candidate generation only; no activation CTA or implied family action now | Candidate directly creates `active` or says the family should try/say/start it today | No | May inform candidates or review prompts only | Pass candidate/example/routes without activation language; fail candidate-to-active shortcut |
| `active` | Activation Governor decision applied after parent intent/readiness | Runtime, Garden, Home/Onboarding surfaces that display active family action | Explicit parent intent/readiness plus Governor `allow_activation`; conservative active capacity respected | Pack match, Runtime, Garden, telemetry, usage count, weak signal, or inferred fit sets active | Yes: parent intent/readiness is required before activation | None for direct state change | Fail any `active` creation without parent intent/readiness and Governor `allow_activation` |
| `familiar` | Garden parent-confirmation flow; Governor may consume the confirmed state but not infer it from telemetry | Garden, Governor, Runtime pacing | Parent explicitly confirms the sound is becoming natural/familiar | Repeated opens, usage, elapsed time, child response, completion, or system inference marks familiar | Yes | May prompt the question only | Pass low-pressure confirmation; fail weak-signal promotion |
| `resting` | Garden parent-confirmation flow, possibly after Governor `rest_existing` recommendation | Garden, Governor, Runtime pacing | Parent confirms the sound should rest; no shame/failure framing | System auto-rests because of inactivity, missed usage, score, or penalty | Yes | May suggest asking whether to rest | Pass parent-confirmed rest; fail punishment/inactivity rest |
| `expandable` | Governor or Garden confirmation flow as a non-reward pacing cue around an existing sound | Governor, Runtime, Explore, Garden | Existing active/familiar context; nearby expansion does not create a new active ritual | Treating expansion as unlock, reward, progress, or unlimited new content pressure | Not for an Explore suggestion; yes if stored as durable family-memory truth | May suggest review/nearby expansion prompt only | Pass light expansion candidate; fail if it becomes reward/unlock/progress |
| `belongs_to_family` state | Garden parent-confirmation flow | Garden, Governor, Runtime/reminder pacing | Parent confirms the sound belongs to the family and may exit app reminders | Telemetry, repeated use, child response, usage count, or system inference claims family transfer | Yes | May prompt the question only | Pass explicit low-pressure confirmation; fail auto-transfer |
| `allow_activation` | Activation Governor only | Runtime, Home, Onboarding, Garden display/action surfaces | Candidate exists, parent intent/readiness exists, active capacity/pacing contract allows activation | Pack/Graph/Runtime/Garden emits allow decision or directly activates | Requires parent intent/readiness | Weak signals may inform prompt/context, not produce decision alone | Fail activation CTA without Governor decision |
| `nearby_expansion_only` | Activation Governor only | Runtime, Explore, Garden/Home surfaces | Existing sound context; expansion stays near current ritual; no new active ritual | New scene/ritual activation disguised as expansion; unlimited expansion pressure | Parent intent/readiness required if asking for family action now | May suggest a review or expansion prompt only | Pass nearby wording that does not create new active; fail new activation shortcut |
| `defer_to_garden` | Activation Governor only | Runtime, Garden/Home surfaces | Activation intent exists but pacing/readiness suggests returning to Garden review first | Runtime/Garden uses defer as its own policy decision without Governor | No transfer confirmation by itself | Weak signals may trigger review prompt considered by Governor | Pass Governor-authored defer; fail non-Governor policy ownership |
| `save_for_later` | Activation Governor for pacing decision; parent/user may explicitly save content without creating activation | Garden, Explore, Runtime pacing | Content can be saved without becoming today's family action | Save silently becomes active or "should say today" | No transfer confirmation by itself | May suggest saving/reviewing only | Pass save as non-activation; fail save-to-active shortcut |
| `rest_existing` | Activation Governor as recommendation; Garden parent-confirmation flow applies durable `resting` state | Garden, Runtime pacing | Existing active/familiar sound; pacing risk or parent desire to rest | System marks rest as failure, punishment, inactivity penalty, or Garden-owned policy | Yes before durable `resting` state | May prompt whether to rest | Pass rest recommendation plus parent confirmation; fail auto-rest truth |
| `belongs_to_family` decision | Activation Governor after/with parent-confirmed family transfer | Garden, Runtime/reminder pacing | Parent confirms familiar sound belongs to the family | System says learned/owned because of usage, score, child response, or repeated opens | Yes | May prompt the question only | Pass decision tied to confirmation; fail telemetry-based family transfer |

## Proof Artifact Map

| Artifact | Role |
|----------|------|
| `tool/verify_activation_governor_contract.dart` | Pure Dart CLI/verifier that scans `mobile_v2/lib` and evaluates typed contract cases. |
| `test/tool/verify_activation_governor_contract_test.dart` | Root verifier tests for fail-closed behavior, authority seams, Explore openness, activation-intent copy, weak signals, parent confirmation, and scope guards. |
| `test/features/vnext/activation_governor_contract_surface_test.dart` | Focused surface scanner tests for Home, Onboarding, Garden, Runtime, reminder/push-like copy, suspicious authority names, and Garden pressure copy. |
| `mobile/test/tool/verify_activation_governor_contract_test.dart` | Mobile wrapper parity forwarding to the root verifier tests. |
| `tool/verify_mobile_v2_semantic_firewall.dart` | Phase 39 regression guard that keeps old phrase/activity/completion/streak/GardenGrowth semantics out of `mobile_v2/lib`. |
| `40-VALIDATION.md` | Final validation record and Nyquist map for R063/R064/R065 and D-01 through D-33. |

## Phase Boundary

This proof intentionally does not implement or lock:

- activation algorithms, scoring, thresholds, or capacity enforcement mechanics;
- database schema, API payloads, event names, persistence models, or migrations;
- UI controls, navigation, component names, or copy finalization beyond contract-level pressure/activation examples;
- Runtime Agent payload schema, Strategy Pack schema, Strategy Graph details, Primitive sequencing, or metrics instrumentation.

Phase 41 may design Pack/Graph/Runtime/metrics details, but those designs must satisfy this contract and the final validation gate.
