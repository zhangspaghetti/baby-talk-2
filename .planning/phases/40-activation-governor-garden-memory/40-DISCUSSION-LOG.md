# Phase 40: activation-governor-garden-memory - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-16T09:04:33.9113771+08:00
**Phase:** 40-activation-governor-garden-memory
**Areas discussed:** Contract verifier shape, authority seams, fixture scope, parent confirmation, decision/state matrix

---

## Gray Area Selection

| Option | Description | Selected |
|--------|-------------|----------|
| Contract verifier shape | How Phase 40 proves the contract without sliding back into old semantics. | ✓ |
| Authority seams | Whether Pack/Graph, Runtime, or Garden should be the strongest fail-closed line. | ✓ |
| Activation intent examples | Which surfaces need activation-positive/activation-negative fixtures. | ✓ |
| Garden Memory parent confirmation | How to express low-pressure confirmation without completion pressure. | ✓ |
| Governor decision/state contract | How explicit the matrix should be without locking implementation schema. | ✓ |

**User's choice:** Discuss all areas, but prioritize 1+5 first, then 2+4, then 3.
**Notes:** User supplied strong defaults for every area, so follow-up questions focused only on unresolved implementation-contract boundaries.

---

## Contract Verifier Shape

| Option | Description | Selected |
|--------|-------------|----------|
| Independent verifier | Separate Phase 40 verifier, reusing Phase 39 scanner/allowlist ideas but not embedded in the old verifier. | ✓ |
| Extend old verifier | Add Phase 40 checks into `verify_mobile_v2_semantic_firewall.dart`. | |
| Skill-driven proof | Use a Codex/GSD skill as the main enforcement mechanism. | |

**User's choice:** Independent repo-owned contract verifier.
**Notes:** User clarified that the verifier should support structured contract fixtures plus banned-language/authority scans. A skill may help agents remember the process but cannot replace machine-checkable repo proof.

---

## Verifier Scope

| Option | Description | Selected |
|--------|-------------|----------|
| `mobile_v2/lib` + structured fixtures | Narrow, fail-closed scan of active vNext boundary plus proof fixtures. | ✓ |
| Repo-wide vNext paths + structured fixtures | Broader scan, but likely to misclassify docs/proof/reference/old code. | |
| Structured fixtures only | Stable, but weak against real runtime code drift. | |

**User's choice:** `mobile_v2/lib` + Phase 40 structured contract fixtures + tests/proof fixtures.
**Notes:** Repo-wide scan is deferred. Docs, deprecated `mobile/`, Phase 39 proof text, architecture docs, and reference/quarantine material stay outside the main scan. Fixtures may contain old terms only when labeled as negative examples or allowlisted reference text.

---

## Authority Proof

| Option | Description | Selected |
|--------|-------------|----------|
| Structured authority fields + language scans | Fixture fields define authority; scans catch suspicious copy/names. | ✓ |
| Language/name scans only | Simpler but risks becoming grep-only and missing disguised authority. | |
| Type/API-shape fixtures only | Clean for object contracts but weak against product copy. | |

**User's choice:** Structured authority fields are primary; language/name scans are auxiliary.
**Notes:** Fields should include `producer`, `consumer`, `decisionSource`, `gardenAction`, `requiresGovernorDecision`, and `requiresParentConfirmation`. Scans should catch activation CTAs, old Garden/checklist/streak/growth language, and suspicious names such as `markFamiliar`, `setActive`, and `activationPolicy`.

---

## Authority Seams

| Option | Description | Selected |
|--------|-------------|----------|
| Pack/Graph cannot activate | Candidate generation cannot create or imply active family action. | ✓ |
| Runtime cannot self-govern | Runtime only consumes existing Governor decisions. | ✓ |
| Garden cannot own policy | Garden presents state and collects confirmation, but does not decide activation. | ✓ |
| Pick one strongest seam | Treat one seam as primary and others as secondary. | |

**User's choice:** All three seams equally fail-closed.
**Notes:** Governor is the only activation pacing authority; Pack produces candidate; Runtime consumes decision; Garden presents state and collects parent confirmation.

---

## Fixture Format

| Option | Description | Selected |
|--------|-------------|----------|
| Dart fixture objects / table-driven tests | Fits current Phase 39 verifier/test style and Flutter/Dart boundary. | ✓ |
| JSON/YAML fixture files + Dart verifier | More external-review friendly but adds parser/schema overhead. | |
| Hybrid data files + Dart helpers | Stronger audit trail but heavier than needed for Phase 40. | |

**User's choice:** Typed Dart fixtures and table-driven tests.
**Notes:** Preferred helper: `ActivationGovernorContractCase`, with fields such as `id`, `description`, `surface`, `producer`, `consumer`, `decisionSource`, `text`, `gardenAction`, `hasGovernorDecision`, `hasParentIntent`, `requiresGovernorDecision`, `requiresParentConfirmation`, `weakSignalOnly`, `expectedPass`, and `expectedReason`. JSON/YAML can be converted later if needed.

---

## Fixture Coverage

| Option | Description | Selected |
|--------|-------------|----------|
| All activation surfaces | Home, Onboarding, Garden, Runtime, reminder/push-like copy. | ✓ |
| Runtime only | Narrowest proof, but misses surface-agnostic activation intent. | |
| Product surfaces only | Misses Runtime self-governance. | |

**User's choice:** Cover all surfaces.
**Notes:** Positive Explore fixtures must prove ideas/examples/routes are allowed without activation intent. Negative fixtures must fail activation CTAs such as "today try", "add this sound", "start this ritual", and "say this today" without Governor decision.

---

## Parent Confirmation

| Option | Description | Selected |
|--------|-------------|----------|
| Prompts only; no meaningful state change | Weak signals may create review opportunities only. | ✓ |
| Temporary suggested state allowed | Weak signals can create a pending truth-like state. | |
| Planner discretion | State the principle only and let planner choose vocabulary. | |

**User's choice:** Weak signals may prompt/review only; no meaningful state change.
**Notes:** Allowed prompts include "这句最近会自然冒出来吗？", "要不要先放一边？", and "这句是不是已经属于你们家了？" Not allowed: setting `familiar`, `resting`, `belongs_to_family`, implied transfer, progress toward transfer, or `suggested_familiar`-style truth.

---

## Decision / State Matrix

| Option | Description | Selected |
|--------|-------------|----------|
| Compact decision/state table | Directly mappable to verifier fixtures while avoiding schema lock. | ✓ |
| Narrative rules only | Easier prose but harder to convert to pass/fail proof. | |
| Detailed pseudo-schema | Actionable but risks locking Phase 41/runtime/persistence too early. | |

**User's choice:** Compact decision/state table.
**Notes:** Matrix columns should include decision/state, allowed producer, allowed consumer, prerequisites, forbidden shortcut, parent confirmation required, weak-signal allowance, and verifier expectation. The matrix is explicitly not an API payload, database schema, class contract, event name list, or UI control design.

---

## the agent's Discretion

- Exact verifier file organization, class names, helper APIs, test grouping, scan implementation, and report formatting.
- Exact allowlist mechanics, as long as `mobile_v2/lib` fails closed and proof fixtures remain fixture-aware.
- Exact implementation approach during planning, constrained by the contract matrix.

## Deferred Ideas

- Repo-wide vNext scan after more vNext runtime paths exist.
- JSON/YAML fixtures after Dart cases stabilize or external review requires data files.
- Optional project-local skill as an agent reminder only.
- Activation algorithm, API/schema/persistence, Runtime Agent payloads, UI controls, Strategy Pack/Graph/Primitive details, and metrics instrumentation.
