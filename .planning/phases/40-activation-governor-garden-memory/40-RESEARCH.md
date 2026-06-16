# Phase 40: activation-governor-garden-memory - Research

**Researched:** 2026-06-16
**Domain:** Flutter/Dart contract verifier, vNext activation pacing, Garden Memory parent-confirmation semantics
**Confidence:** MEDIUM - Phase-local sources are strong and executable repo patterns are verified, but the GSD confidence classifier reports LOW for verified local/codebase providers. [VERIFIED: gsd-tools classify-confidence]

<user_constraints>
## User Constraints (from CONTEXT.md)

All items in this section are copied or condensed from `.planning/phases/40-activation-governor-garden-memory/40-CONTEXT.md`; when a line says "must", planners must treat it as locked. [VERIFIED: .planning/phases/40-activation-governor-garden-memory/40-CONTEXT.md]

### Locked Decisions

#### Contract Verifier Shape
- **D-01:** Phase 40 must create an independent, repo-owned machine-checkable contract verifier, such as `tool/verify_activation_governor_contract.dart`, with fixtures and tests. It must not be a Codex/GSD skill and must not be only an extension of the Phase 39 semantic-firewall verifier. [VERIFIED: 40-CONTEXT.md]
- **D-02:** Reuse Phase 39 verifier ideas for scanning, reports, fail-closed behavior, and allowlists, but Phase 40 owns a separate Activation Governor / Garden Memory proof. [VERIFIED: 40-CONTEXT.md]
- **D-03:** Narrow verifier scope to `mobile_v2/lib`, Phase 40 structured contract fixtures, and tests/proof fixtures created for the Activation Governor / Garden Memory contract. [VERIFIED: 40-CONTEXT.md]
- **D-04:** Do not scan repo-wide in this phase; docs, proof text, architecture docs, reference/quarantine material, deprecated `mobile/`, and old product code would create false positives. [VERIFIED: 40-CONTEXT.md]
- **D-05:** The verifier must be a contract verifier, not a pure grep tool; structured fixtures are the authority backbone and language/name scans are auxiliary guards. [VERIFIED: 40-CONTEXT.md]
- **D-06:** Structured fixtures should model fields such as `producer`, `consumer`, `decisionSource`, `gardenAction`, `requiresGovernorDecision`, and `requiresParentConfirmation`. [VERIFIED: 40-CONTEXT.md]
- **D-07:** Language/name scans should catch activation CTAs, old Garden/checklist/streak/growth language, and suspicious authority names; activation copy without a Governor decision must fail. [VERIFIED: 40-CONTEXT.md]
- **D-08:** Suspicious names such as `markFamiliar`, `setActive`, and `activationPolicy` require proof that they live within allowed Governor or Garden parent-confirmation boundaries. [VERIFIED: 40-CONTEXT.md]
- **D-09:** A project-local skill may later remind agents to run the verifier, but cannot replace the repo-owned verifier as acceptance proof. [VERIFIED: 40-CONTEXT.md]

#### Authority Seams
- **D-10:** All three seams are equally fail-closed: Pack/Graph cannot activate; Runtime cannot self-govern activation; Garden cannot own activation policy. [VERIFIED: 40-CONTEXT.md]
- **D-11:** Activation Governor is the only activation pacing authority. [VERIFIED: 40-CONTEXT.md]
- **D-12:** Pack/Graph may produce candidates only and must not directly create an active micro-ritual or imply the family should say/use it today. [VERIFIED: 40-CONTEXT.md]
- **D-13:** Runtime may consume an existing Activation Governor decision but must not read activation policy or decide whether a candidate enters family routine. [VERIFIED: 40-CONTEXT.md]
- **D-14:** Garden may present state and collect parent confirmation, but must not own activation policy or convert weak signals into meaningful transfer states. [VERIFIED: 40-CONTEXT.md]
- **D-15:** All three seams must be represented as negative fixtures. [VERIFIED: 40-CONTEXT.md]

#### Fixture Format and Coverage
- **D-16:** Use typed Dart fixture objects and table-driven tests; do not introduce JSON/YAML fixture files in Phase 40. [VERIFIED: 40-CONTEXT.md]
- **D-17:** Use a helper such as `ActivationGovernorContractCase` with fields like `id`, `description`, `surface`, `producer`, `consumer`, `decisionSource`, `text`, `gardenAction`, `hasGovernorDecision`, `hasParentIntent`, `requiresGovernorDecision`, `requiresParentConfirmation`, `weakSignalOnly`, `expectedPass`, and `expectedReason`. [VERIFIED: 40-CONTEXT.md]
- **D-18:** Fixture groups must include positive Explore cases, positive Runtime-consuming-existing-decision cases, negative Pack/Graph activation shortcuts, negative Runtime self-governance, negative Garden-owning-policy, negative activation CTA without Governor decision, negative weak-signal promotion, negative checklist/streak/growth language, and positive low-pressure parent-confirmation prompts. [VERIFIED: 40-CONTEXT.md]
- **D-19:** Activation intent examples must cover Home, Onboarding, Garden, Runtime, and reminder/push-like copy. [VERIFIED: 40-CONTEXT.md]
- **D-20:** Positive Explore fixtures are required and must prove that ideas, examples, routes, future expansion, and expert explanation remain open when they do not ask or imply family action now. [VERIFIED: 40-CONTEXT.md]
- **D-21:** Negative activation-intent fixtures must cover language equivalent to "today try this", "add this sound", "start this micro-ritual", and "say this during [routine] today" without a Governor decision. [VERIFIED: 40-CONTEXT.md]

#### Parent Confirmation and Weak Signals
- **D-22:** Weak signals may create prompts or review opportunities only; they must not write Garden Memory truth states. [VERIFIED: 40-CONTEXT.md]
- **D-23:** Allowed without parent confirmation: review prompts, asking the parent, "Does this feel familiar?", "Want to rest this for now?", "Has this become part of your family words?", or non-persistent prompt/review opportunities. [VERIFIED: 40-CONTEXT.md]
- **D-24:** Not allowed without parent confirmation: set `familiar`, set `resting`, set `belongs_to_family`, imply family transfer, count repeated views/usage/time as proof, mark progress toward transfer, or auto-create truth-like states. [VERIFIED: 40-CONTEXT.md]
- **D-25:** Do not introduce intermediate truth-like states such as `suggested_familiar`; represent technical queues as prompt/review requests instead. [VERIFIED: 40-CONTEXT.md]
- **D-26:** Weak-signal-only fixtures may pass only when `gardenAction` is prompt/review/suggestion and no meaningful state changes occur. [VERIFIED: 40-CONTEXT.md]
- **D-27:** Weak-signal-only fixtures must fail if they produce `familiar`, `resting`, `belongs_to_family`, or any truth-like transfer state. [VERIFIED: 40-CONTEXT.md]
- **D-28:** Parent-confirmed fixtures may pass for meaningful transitions only when confirmation is low-pressure and non-scoring. [VERIFIED: 40-CONTEXT.md]
- **D-29:** Warm examples include `这句最近会自然冒出来吗？`, `要不要先放一边？`, and `这句是不是已经属于你们家了？`. [VERIFIED: 40-CONTEXT.md]
- **D-30:** Do not use score, checklist, streak, growth, unlock, reward, progress bar, or similar completion pressure for Garden Memory confirmation. [VERIFIED: 40-CONTEXT.md]

#### Decision and State Matrix
- **D-31:** Downstream agents must receive and preserve a compact decision/state matrix. [VERIFIED: 40-CONTEXT.md]
- **D-32:** The matrix must be clear enough to drive verifier fixtures and planning pass/fail judgments. [VERIFIED: 40-CONTEXT.md]
- **D-33:** The matrix must not lock API payloads, database fields, class names, event names, UI controls, or Runtime Agent payloads. [VERIFIED: 40-CONTEXT.md]

### the agent's Discretion

- Planner/executor may choose exact file names, class names, helper APIs, fixture grouping, report formatting, and test organization as long as they satisfy the contract above. [VERIFIED: 40-CONTEXT.md]
- Planner/executor may choose whether the Phase 40 verifier is a new file or a small package of files, but it must remain repo-owned and machine-checkable. [VERIFIED: 40-CONTEXT.md]
- Planner/executor may design the exact scanning implementation and allowlist mechanics. [VERIFIED: 40-CONTEXT.md]
- Planner/executor must not lock activation algorithms, database schema, API payloads, event names, UI controls, Runtime Agent payload schema, Strategy Pack schema, Primitive sequencing, or metrics instrumentation in Phase 40. [VERIFIED: 40-CONTEXT.md]

### Deferred Ideas (OUT OF SCOPE)

- Repo-wide vNext scan is deferred until more vNext runtime paths exist. [VERIFIED: 40-CONTEXT.md]
- JSON/YAML fixture files are deferred until typed Dart cases stabilize or external review requires data files. [VERIFIED: 40-CONTEXT.md]
- A project-local skill that reminds agents to run/use the verifier is optional and deferred; it is not the Phase 40 acceptance proof. [VERIFIED: 40-CONTEXT.md]
- Activation algorithm, database schema, API payloads, Runtime Agent payload schema, event names, UI controls, Strategy Pack schema, Primitive sequencing, and metrics instrumentation remain out of Phase 40 context. [VERIFIED: 40-CONTEXT.md]
- Phase 41 owns Strategy Pack / Graph / Runtime Agent details and parent-confirmed transfer metrics. [VERIFIED: 40-CONTEXT.md]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| R063 | Activation Governor must sit between Pack/Graph candidates and Runtime Agent responses, controlling Activate and not Explore, with decision vocabulary including `allow_activation`, `nearby_expansion_only`, `defer_to_garden`, `save_for_later`, `rest_existing`, and `belongs_to_family`. [VERIFIED: .planning/REQUIREMENTS.md] | Plan a verifier that fails Pack/Graph direct activation, Runtime self-governance, non-Governor pacing decisions, and activation CTAs without a Governor decision. [VERIFIED: 40-SPEC.md] |
| R064 | Garden Memory must be parent-confirmed family micro-ritual memory, not completion, check-in, or system scoring. [VERIFIED: .planning/REQUIREMENTS.md] | Plan fixtures that pass low-pressure parent confirmation and fail weak-signal promotion, checklist/streak/growth language, auto-familiar, auto-resting, and auto-belongs-to-family. [VERIFIED: 40-SPEC.md] |
| R065 | Explore and Activate must be explicitly separated: expert content remains open, while any "today/now/try/add to family routine" activation intent is governed. [VERIFIED: .planning/REQUIREMENTS.md] | Plan positive Explore fixtures plus activation-intent language fixtures across Home, Onboarding, Garden, Runtime, and reminder/push-like copy. [VERIFIED: 40-CONTEXT.md] |
</phase_requirements>

## Summary

Phase 40 should be planned as a focused contract/verifier phase, not as the Activation Governor algorithm, Garden Memory persistence model, API schema, UI control implementation, Runtime Agent payload, or metrics layer. [VERIFIED: 40-SPEC.md] The implementation should add an independent repo-owned Dart verifier and table-driven tests that prove the pacing contract is machine-checkable before later phases add Pack/Graph/Runtime details. [VERIFIED: 40-CONTEXT.md]

The strongest repo pattern to reuse is Phase 39's verifier architecture: a pure Dart tool under `tool/`, exported scanner/report APIs, stable CLI output, fail-closed missing-boundary behavior, allowlisted reference scans, root tests under `test/tool/`, targeted vNext contract tests under `test/features/vnext/`, and a thin `mobile/test/tool/` wrapper for wrapper parity. [VERIFIED: tool/verify_mobile_v2_semantic_firewall.dart] Phase 40 should reuse the pattern, not the same verifier file, because the locked decisions require a separate Activation Governor / Garden Memory contract proof. [VERIFIED: 40-CONTEXT.md]

**Primary recommendation:** Plan Wave 0 around red-green creation of `tool/verify_activation_governor_contract.dart`, `test/tool/verify_activation_governor_contract_test.dart`, optional targeted `test/features/vnext/activation_governor_contract_surface_test.dart`, and `mobile/test/tool/verify_activation_governor_contract_test.dart`, then add a validation document/final gate that runs the new verifier plus existing Phase 39 semantic firewall. [VERIFIED: existing Phase 39 pattern]

## Project Constraints (from AGENTS.md)

- BabyTalk 2 is a monorepo with Flutter mobile, Spring Boot backend, and React admin-web. [VERIFIED: AGENTS.md]
- Existing stack is Flutter/Riverpod, Spring Boot 3.4.4/Java 17, React 18/Vite 5/AntD 5. [VERIFIED: AGENTS.md]
- Flutter development lives under `mobile/lib/`, backend under `backend/`, admin web under `admin-web/src/`, and vNext currently lives under `mobile_v2/`. [VERIFIED: AGENTS.md + mobile_v2/pubspec.yaml]
- Existing anti-patterns include ViewModel + Notifier double truth, manual polling, localStorage token, frontend-held admin permission codes, and overloaded large files; Phase 40 must avoid adding another duplicate source of truth for activation policy or Garden state. [VERIFIED: AGENTS.md]
- Project commands include `cd mobile && flutter test`, repo-root `flutter.cmd` delegation, backend Maven commands, and `pnpm --filter admin-web ...`; Phase 40 should use Dart/Flutter verifier commands only unless scope expands. [VERIFIED: AGENTS.md]
- Project instruction says use `/browse` for web browsing and never `mcp__claude-in-chrome__*`; no web browsing was required because Phase 40 depends on local product/spec contracts and no external package/API selection. [VERIFIED: AGENTS.md]
- No project-local `.codex/skills/` or `.agents/skills/` directories were found in the workspace. [VERIFIED: shell check]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Activation pacing contract | Tooling / Contract Proof | Mobile Client | Phase 40 locks pass/fail authority and copy/state rules through a verifier before runtime implementation exists. [VERIFIED: 40-SPEC.md] |
| Explore vs Activate boundary | Tooling / Contract Proof | Future Mobile UI + Runtime | The contract must distinguish open candidate/explanation content from activation-intent CTAs across surfaces. [VERIFIED: 40-SPEC.md] |
| Pack/Graph candidate authority | Future Backend/Runtime Domain | Tooling / Contract Proof | Phase 41 owns Pack/Graph details; Phase 40 only proves Pack/Graph cannot activate. [VERIFIED: 40-CONTEXT.md] |
| Runtime activation authority | Future Runtime Agent | Tooling / Contract Proof | Runtime may apply existing decisions but must not own activation policy; verifier fixtures should fail self-governance. [VERIFIED: 40-CONTEXT.md] |
| Garden Memory confirmation | Mobile Client | Tooling / Contract Proof | Garden presents state and collects parent confirmation; Phase 40 proves weak signals cannot write truth states. [VERIFIED: 40-SPEC.md] |
| Old Garden/progress quarantine | Tooling / Contract Proof | Deprecated Mobile Reference | Old `mobile/` Garden growth/fertilizer/streak/progress files are landmines, not vNext truth. [VERIFIED: codegraph + 39-SUPERSESSION-PROOF.md] |
| Validation gate | Tooling / CI | Mobile test wrapper | Existing repo pattern uses root Dart verifier tests plus `mobile/test/tool` forwarders for wrapper compatibility. [VERIFIED: test/tool/verify_mobile_v2_semantic_firewall_test.dart + mobile/test/tool/verify_mobile_v2_semantic_firewall_test.dart] |

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Dart SDK | 3.11.4 via `C:\software\flutter\bin\cache\dart-sdk\bin\dart.exe` | Pure verifier CLI and scanner/report APIs | Existing verifier tools are pure Dart and avoid extra dependencies. [VERIFIED: command output + tool/verify_mobile_v2_semantic_firewall.dart] |
| Flutter test | SDK dependency; root `pubspec.yaml` has SDK `^3.11.4` | Root and mobile-wrapper test execution | Existing Phase 39 tests use `package:flutter_test/flutter_test.dart` and temp project fixtures. [VERIFIED: pubspec.yaml + test/tool/verify_mobile_v2_semantic_firewall_test.dart] |
| `dart:io` | Dart standard library | File traversal, line scanning, temp fixture files, CLI output | Existing repo verifier pattern already uses `dart:io`; no package install is needed. [VERIFIED: tool/verify_mobile_v2_semantic_firewall.dart] |
| `rg` | Available in shell; exact version not probed in this phase | Research-time source discovery | Fast repo scans identified existing activation/Garden terms and verifier patterns. [VERIFIED: shell rg output] |
| GSD local shim | `C:\Users\zhang\.codex\gsd-core\bin\gsd-tools.cjs` | Phase metadata, confidence classifier, research-plan seam | `gsd-tools` is not on PATH, but the shim works for `init.phase-op`, `research-plan`, and `classify-confidence`. [VERIFIED: shell output] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| Existing Phase 39 semantic firewall | Current repo file | Baseline guard against old phrase/activity/streak/GardenGrowth leakage | Run alongside Phase 40 verifier at the phase gate so old semantic leakage remains blocked. [VERIFIED: tool/verify_mobile_v2_semantic_firewall.dart] |
| `mobile_v2` package boundary | SDK constraint `^3.11.4`; no old `mobile` dependency | Active vNext runtime scan root | Scan `mobile_v2/lib` only for this phase. [VERIFIED: mobile_v2/pubspec.yaml + 40-CONTEXT.md] |
| `flutter.cmd` wrapper | Repo-local batch file | Mobile test delegation | Use for wrapper parity, but include a Wave 0 health check because `./flutter.cmd test ...` timed out in this research session. [VERIFIED: flutter.cmd + command timeout] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Extending `tool/verify_mobile_v2_semantic_firewall.dart` | New `tool/verify_activation_governor_contract.dart` | Locked D-01/D-02 require a separate Phase 40 proof while reusing Phase 39 ideas. [VERIFIED: 40-CONTEXT.md] |
| JSON/YAML fixtures | Typed Dart cases | Locked D-16 rejects JSON/YAML for Phase 40; Dart cases avoid parser/schema overhead. [VERIFIED: 40-CONTEXT.md] |
| Repo-wide scan | `mobile_v2/lib` + structured fixtures | Locked D-04 defers repo-wide scanning because old docs/code/proof files would create false positives. [VERIFIED: 40-CONTEXT.md] |
| Adding a third-party scanner package | Pure Dart scanner | No external package is necessary; package install would add supply-chain review without value. [VERIFIED: tool/verify_mobile_v2_semantic_firewall.dart] |

**Installation:** No new external packages should be installed for Phase 40. [VERIFIED: 40-SPEC.md]

## Package Legitimacy Audit

Not applicable: Phase 40 should not install external packages. [VERIFIED: 40-SPEC.md]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| none | — | — | — | — | — | No install planned |

**Packages removed due to [SLOP] verdict:** none  
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```text
Phase 40 locked sources
  REQUIREMENTS.md R063/R064/R065
  40-SPEC.md + 40-CONTEXT.md + 40-UI-SPEC.md
  Phase 39 verifier/proof/boundary artifacts
        |
        v
Typed contract fixtures
  ActivationGovernorContractCase rows
  - positive Explore
  - positive Runtime consumes decision
  - positive low-pressure parent confirmation
  - negative Pack/Graph activates
  - negative Runtime self-governs
  - negative Garden owns policy
  - negative activation CTA without Governor
  - negative weak-signal promotion
  - negative checklist/streak/growth language
        |
        v
Phase 40 verifier
  structured authority checks
  + activation-language scan
  + Garden/checklist language scan
  + suspicious-authority-name scan
  + mobile_v2/lib runtime scan
        |
        v
CLI/report/test gate
  test/tool/verify_activation_governor_contract_test.dart
  test/features/vnext/activation_governor_contract_surface_test.dart
  mobile/test/tool/verify_activation_governor_contract_test.dart
  C:\software\flutter\bin\cache\dart-sdk\bin\dart.exe tool\verify_activation_governor_contract.dart
        |
        v
Phase 41 handoff
  Pack/Graph/Runtime/metrics can build on a protected activation contract
```

### Recommended Project Structure

```text
tool/
└── verify_activation_governor_contract.dart

test/tool/
└── verify_activation_governor_contract_test.dart

test/features/vnext/
└── activation_governor_contract_surface_test.dart

mobile/test/tool/
└── verify_activation_governor_contract_test.dart

mobile_v2/lib/
└── vnext_semantic_boundary.dart   # may gain boundary constants only if needed; no algorithm/schema/UI lock
```

### Pattern 1: Contract Case Table
**What:** Encode each authority scenario as a typed Dart case with explicit producer, consumer, decision source, Garden action, Governor-decision requirement, parent-confirmation requirement, weak-signal flag, expected result, and reason. [VERIFIED: 40-CONTEXT.md]

**When to use:** Every required positive/negative fixture group should be a table row before scanner details are added. [VERIFIED: 40-CONTEXT.md]

**Example:**
```dart
// Source: Phase 40 CONTEXT fixture contract [VERIFIED: 40-CONTEXT.md]
const case = ActivationGovernorContractCase(
  id: 'runtime-consumes-allow-activation',
  surface: ActivationSurface.runtime,
  producer: ContractActor.activationGovernor,
  consumer: ContractActor.runtime,
  decisionSource: ContractDecisionSource.activationGovernor,
  text: 'Runtime applies an existing allow_activation decision.',
  gardenAction: GardenAction.none,
  hasGovernorDecision: true,
  hasParentIntent: true,
  requiresGovernorDecision: true,
  requiresParentConfirmation: false,
  weakSignalOnly: false,
  expectedPass: true,
  expectedReason: 'Runtime consumes an existing Governor decision.',
);
```

### Pattern 2: Fail-Closed Report Object
**What:** Mirror Phase 39's `Report`, `Violation`, `ViolationType`, `scan...`, and `render...Report` style so tests can assert counts and reasons through public APIs. [VERIFIED: tool/verify_mobile_v2_semantic_firewall.dart]

**When to use:** The verifier should be directly importable by `test/tool/..._test.dart`, and the CLI should call the same scanner/report path. [VERIFIED: test/tool/verify_mobile_v2_semantic_firewall_test.dart]

### Pattern 3: Auxiliary Language/Name Scans
**What:** After structured checks, scan `text` and runtime Dart lines for activation CTAs, old checklist/Garden pressure words, and suspicious authority names. [VERIFIED: 40-CONTEXT.md]

**When to use:** Use scans as guardrails against valid-looking fields paired with forbidden copy such as `今天试试这个`, `add this sound`, `setActive`, or `activationPolicy` outside allowed ownership. [VERIFIED: 40-UI-SPEC.md + 40-CONTEXT.md]

### Anti-Patterns to Avoid

- **Pure grep verifier:** It misses disguised authority and violates D-05. [VERIFIED: 40-CONTEXT.md]
- **Docs-only proof:** It violates the SPEC requirement for machine-checkable proof. [VERIFIED: 40-SPEC.md]
- **Runtime owns activation policy:** Runtime may consume existing decisions only. [VERIFIED: 40-CONTEXT.md]
- **Garden owns pacing:** Garden collects confirmation and presents state, but cannot create policy decisions. [VERIFIED: 40-CONTEXT.md]
- **Weak-signal truth states:** Repeated opens, saves, returns, variant requests, or elapsed time may prompt review only. [VERIFIED: 40-SPEC.md]
- **Capacity as parent goal:** Default active limit 3 and upper bound 5 are internal protection parameters, not user-facing targets. [VERIFIED: docs/Baby_Talk_Product_Architecture_Spec_vNext.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Activation policy algorithm | Threshold/scoring engine | Contract fixtures and verifier only | Phase 40 locks the pacing contract, not final algorithm or thresholds. [VERIFIED: 40-SPEC.md] |
| Garden Memory persistence | Database schema/API/event model | Parent-confirmation contract cases | Persistence and exact event names are out of scope. [VERIFIED: 40-CONTEXT.md] |
| Runtime Agent payload | JSON schema/input-output contract | Runtime self-governance negative fixtures | Phase 41 owns Runtime Agent payloads. [VERIFIED: 40-CONTEXT.md] |
| Generic text grep gate | Standalone regex-only script | Structured Dart contract verifier plus auxiliary scans | Locked D-05 makes structured cases the authority backbone. [VERIFIED: 40-CONTEXT.md] |
| New package-based scanner | Third-party parsing/scanning dependency | Existing pure Dart `dart:io` verifier pattern | Existing repo tools already solve recursive scan/report/test needs. [VERIFIED: tool/verify_mobile_v2_semantic_firewall.dart] |

**Key insight:** Phase 40 succeeds by making bad authority flows impossible to miss in planning and tests, not by implementing the real Governor/Garden runtime. [VERIFIED: 40-SPEC.md]

## Common Pitfalls

### Pitfall 1: Over-Governing Explore
**What goes wrong:** Planner requires Governor approval for every candidate, example, explanation, or future route. [VERIFIED: 40-SPEC.md]
**Why it happens:** Activation and candidate generation share vocabulary unless fixtures distinguish intent. [VERIFIED: 40-CONTEXT.md]
**How to avoid:** Add positive Explore fixtures that pass without a Governor decision when they avoid action-now copy. [VERIFIED: 40-CONTEXT.md]
**Warning signs:** Verifier fails neutral examples like `看看这个说法` or route explanations. [VERIFIED: 40-UI-SPEC.md]

### Pitfall 2: Runtime Self-Governance Sneaks In
**What goes wrong:** Runtime reads `activationPolicy`, decides `allow_activation`, or turns candidate Pack into today's action. [VERIFIED: 40-CONTEXT.md]
**Why it happens:** Phase 41 Runtime examples in the product spec contain activationDecision fields, which can be misread as Runtime authority. [VERIFIED: docs/Baby_Talk_Product_Architecture_Spec_vNext.md]
**How to avoid:** Add negative fixture rows for Runtime-owned decisions and suspicious names, and positive rows where Runtime only consumes an existing decision. [VERIFIED: 40-CONTEXT.md]
**Warning signs:** `decisionSource` is Runtime, or runtime copy says it decided pacing. [VERIFIED: 40-CONTEXT.md]

### Pitfall 3: Garden Memory Becomes a Checklist
**What goes wrong:** Garden uses streak, completion, score, growth, fertilizer, unlock, reward, progress bar, or punishment semantics. [VERIFIED: 40-SPEC.md]
**Why it happens:** Old `mobile/` Garden code is built around growth/fertilizer/progress semantics and remains visible as reference material. [VERIFIED: codegraph]
**How to avoid:** Add explicit banned Garden/checklist language scans and negative fixtures that assert these terms fail in Phase 40 contract cases. [VERIFIED: 40-CONTEXT.md]
**Warning signs:** `GardenGrowth`, `currentStreakDays`, `completedPhraseCount`, `unlock`, `reward`, `score`, or `progress` appears as vNext truth. [VERIFIED: 39-SUPERSESSION-PROOF.md + 40-SPEC.md]

### Pitfall 4: Weak Signals Become Truth-Like State
**What goes wrong:** Repeated views, favorites, routine returns, or variant requests mark `familiar`, `resting`, `belongs_to_family`, or `active`. [VERIFIED: 40-SPEC.md]
**Why it happens:** Telemetry is tempting as a substitute for parent confirmation. [VERIFIED: docs/Baby_Talk_Product_Architecture_Spec_vNext.md]
**How to avoid:** Make weak-signal-only cases pass only for prompt/review/suggestion actions and fail for meaningful state changes. [VERIFIED: 40-CONTEXT.md]
**Warning signs:** `suggested_familiar`, `almost familiar`, or progress-toward-transfer appears as state vocabulary. [VERIFIED: 40-CONTEXT.md]

## TDD Opportunities

TDD mode is active in `.planning/config.json`, and the TDD skill requires one red-green-refactor cycle per vertical slice through public interfaces. [VERIFIED: .planning/config.json + tdd SKILL.md]

| Slice | First Red Test | Minimal Green | Refactor Target |
|-------|----------------|---------------|-----------------|
| Verifier skeleton | `scanActivationGovernorContract` fails closed when `mobile_v2/lib` is missing or no contract cases exist. [VERIFIED: Phase 39 pattern] | Add report/violation types and missing-boundary behavior. [VERIFIED: tool/verify_mobile_v2_semantic_firewall.dart] | Stable report rendering and public API names. |
| Positive Explore | Explore case with candidate/example copy passes without Governor decision. [VERIFIED: 40-CONTEXT.md] | Implement structured case evaluator that recognizes non-activation Explore. | Extract enum/value helpers. |
| Activation CTA gate | Home/Onboarding/Garden/Runtime/reminder copy with `today try/add/start/say today` fails without Governor decision. [VERIFIED: 40-SPEC.md] | Add activation-language scan over case text. | Consolidate banned-copy patterns. |
| Authority seams | Pack/Graph direct activation, Runtime self-governance, and Garden policy ownership each fail. [VERIFIED: 40-CONTEXT.md] | Add producer/consumer/decisionSource checks. | Table-driven seam rules. |
| Parent confirmation | Parent-confirmed `familiar`, `resting`, and `belongs_to_family` pass only with low-pressure confirmation. [VERIFIED: 40-CONTEXT.md] | Add Garden action and confirmation checks. | Extract Garden transition rule map. |
| Weak signal limits | Weak-signal-only cases fail when they create truth states and pass when they only prompt review. [VERIFIED: 40-SPEC.md] | Add weak-signal decision logic. | Share prompt-only action vocabulary. |
| CLI proof | CLI emits status/report and success marker; unknown args fail usage. [VERIFIED: Phase 39 pattern] | Add `main`, options parser, renderer. | Match Phase 39 report readability. |

## Code Examples

### Phase 39 Scanner Pattern to Reuse
```dart
// Source: tool/verify_mobile_v2_semantic_firewall.dart [VERIFIED: repo file]
final report = scanMobileV2SemanticFirewall(
  projectRoot: Directory.current.path,
);
stdout.write(renderMobileV2SemanticFirewallReport(report));
if (report.hasBlockingViolations) {
  exit(1);
}
stdout.writeln(mobileV2SemanticFirewallSuccessMarker);
```

### Phase 40 Contract Case Shape
```dart
// Source: 40-CONTEXT.md D-17 [VERIFIED: 40-CONTEXT.md]
class ActivationGovernorContractCase {
  const ActivationGovernorContractCase({
    required this.id,
    required this.description,
    required this.surface,
    required this.producer,
    required this.consumer,
    required this.decisionSource,
    required this.text,
    required this.gardenAction,
    required this.hasGovernorDecision,
    required this.hasParentIntent,
    required this.requiresGovernorDecision,
    required this.requiresParentConfirmation,
    required this.weakSignalOnly,
    required this.expectedPass,
    required this.expectedReason,
  });

  final String id;
  final String description;
  final String surface;
  final String producer;
  final String consumer;
  final String decisionSource;
  final String text;
  final String gardenAction;
  final bool hasGovernorDecision;
  final bool hasParentIntent;
  final bool requiresGovernorDecision;
  final bool requiresParentConfirmation;
  final bool weakSignalOnly;
  final bool expectedPass;
  final String expectedReason;
}
```

### Mobile Wrapper Pattern
```dart
// Source: mobile/test/tool/verify_mobile_v2_semantic_firewall_test.dart [VERIFIED: repo file]
import '../../../test/tool/verify_mobile_v2_semantic_firewall_test.dart'
    as root_test;

void main() => root_test.main();
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Phrase/activity/completion/streak/Garden growth | Family English Micro-ritual with conservative activation/open exploration | M010 restart, 2026-06-14/15 | Phase 40 must protect activation/Garden semantics from old progress logic. [VERIFIED: 39-SUPERSESSION-PROOF.md] |
| Pack match implies next action | Candidate generation is not activation | Phase 39 locked; Phase 40 expands proof | Pack/Graph candidate rows must fail if they create active family routine action. [VERIFIED: 39-SPEC.md + 40-SPEC.md] |
| Garden as growth/progress projection | Garden Memory as parent-confirmed family-language memory | Phase 40 SPEC | Meaningful transfer states require low-pressure parent confirmation. [VERIFIED: 40-SPEC.md] |
| Runtime decides next task | Runtime consumes Activation Governor decision | vNext product spec and Phase 40 context | Runtime self-governance is a required negative fixture. [VERIFIED: docs/Baby_Talk_Product_Architecture_Spec_vNext.md + 40-CONTEXT.md] |

**Deprecated/outdated:** old `mobile/` Garden growth/fertilizer/streak/progress semantics; old `Phrase`/`Activity` completion truth; checklist/reward/unlock/progress framing for vNext Garden. [VERIFIED: 39-SUPERSESSION-PROOF.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `rg` is available and suitable for research-time scans, but exact version was not probed in this phase. | Standard Stack | Low; planner does not need `rg` for implementation if Dart verifier owns scanning. |
| A2 | The wrapper timeout is environmental rather than a Phase 39 test regression, because the direct Phase 39 verifier CLI passed and the wrapper command did not return before test output. | Environment Availability | Medium; planner should add Wave 0 command-health checks before relying on wrapper commands. |

## Open Questions

1. **Should Phase 40 add boundary constants to `mobile_v2/lib/vnext_semantic_boundary.dart`?**
   - What we know: Phase 39 added boundary constants for the prior contract, and Phase 40 scan scope includes `mobile_v2/lib`. [VERIFIED: mobile_v2/lib/vnext_semantic_boundary.dart + 40-CONTEXT.md]
   - What's unclear: The context requires a verifier and fixtures, not runtime constants. [VERIFIED: 40-CONTEXT.md]
   - Recommendation: Make constants optional; only add minimal boundary anchors if a red test needs a real runtime file, and do not encode algorithm/schema/UI details. [VERIFIED: 40-SPEC.md]

2. **Should the final gate use `dart run tool/...` or direct `dart.exe tool\...` on this Windows machine?**
   - What we know: Direct `dart.exe tool\verify_mobile_v2_semantic_firewall.dart` passed, while `dart run tool\... --help` failed due telemetry write access under `C:\Users\zhang\AppData\Roaming\.dart-tool`. [VERIFIED: command output]
   - What's unclear: Whether executor environment will have telemetry write access or disabled analytics. [ASSUMED]
   - Recommendation: Plan Wave 0 to choose a stable command path; direct SDK invocation is currently the reliable local fallback. [VERIFIED: command output]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| `dart` batch wrapper | `dart run` style verifier commands | found | path `C:\software\flutter\bin\dart.bat`; `dart --version` timed out | Use direct SDK executable. [VERIFIED: command output] |
| direct Dart SDK executable | verifier CLI | yes | Dart SDK 3.11.4 | — [VERIFIED: command output] |
| `flutter` batch wrapper | Flutter tests | found | path `C:\software\flutter\bin\flutter.bat`; version not probed | Use repo `flutter.cmd` after Wave 0 health check. [VERIFIED: command output] |
| `flutter.cmd` | mobile-wrapper test parity | yes | repo batch wrapper changes into `mobile/` | Direct root Flutter test if wrapper blocks, but verify path first. [VERIFIED: flutter.cmd] |
| GSD shim | phase metadata/commit/research plan | yes | local `gsd-tools.cjs`; PATH command missing | Invoke with `node C:\Users\zhang\.codex\gsd-core\bin\gsd-tools.cjs`. [VERIFIED: command output] |
| `mobile_v2/lib` | runtime scan root | yes | one Dart boundary file | Fail closed if missing. [VERIFIED: mobile_v2 file listing] |

**Missing dependencies with no fallback:** none confirmed. [VERIFIED: environment probes]

**Missing dependencies with fallback:** `dart run` is blocked by telemetry access in this session; `./flutter.cmd test test\tool\verify_mobile_v2_semantic_firewall_test.dart` timed out after 120 seconds. Use Wave 0 command-health checks and direct SDK fallback. [VERIFIED: command output]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Flutter test / Dart verifier tests using `flutter_test`. [VERIFIED: test/tool/verify_mobile_v2_semantic_firewall_test.dart] |
| Config file | root `pubspec.yaml`, `mobile/dart_test.yaml`, `mobile/analysis_options.yaml`; root `flutter.cmd` delegates into `mobile/`. [VERIFIED: pubspec.yaml + flutter.cmd] |
| Quick run command | `./flutter.cmd test test/tool/verify_activation_governor_contract_test.dart` after mobile wrapper exists; Wave 0 must verify wrapper health. [VERIFIED: existing wrapper pattern] |
| Full suite command | `./flutter.cmd test test/tool/verify_activation_governor_contract_test.dart test/features/vnext/activation_governor_contract_surface_test.dart test/tool/verify_mobile_v2_semantic_firewall_test.dart mobile/test/tool/verify_activation_governor_contract_test.dart` after files exist. [VERIFIED: Phase 39 validation pattern] |
| CLI command | Prefer `C:\software\flutter\bin\cache\dart-sdk\bin\dart.exe tool\verify_activation_governor_contract.dart` on this machine unless Wave 0 proves `dart run` works. [VERIFIED: command output] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| R063 | Pack/Graph cannot activate, Runtime cannot self-govern, Garden cannot own activation policy, and only Governor emits activation pacing decisions. [VERIFIED: REQUIREMENTS.md] | verifier unit | `./flutter.cmd test test/tool/verify_activation_governor_contract_test.dart` | No - Wave 0 |
| R063 | CLI scans `mobile_v2/lib` and typed fixtures, then emits pass/fail report. [VERIFIED: 40-CONTEXT.md] | static verifier | `C:\software\flutter\bin\cache\dart-sdk\bin\dart.exe tool\verify_activation_governor_contract.dart` | No - Wave 0 |
| R064 | Parent-confirmed `familiar`, `resting`, and `belongs_to_family` pass only with low-pressure confirmation; weak signals cannot write truth. [VERIFIED: 40-SPEC.md] | table-driven unit | `./flutter.cmd test test/tool/verify_activation_governor_contract_test.dart` | No - Wave 0 |
| R064 | Checklist/streak/growth/reward/unlock/progress language fails as Garden Memory truth. [VERIFIED: 40-SPEC.md] | language scan unit | `./flutter.cmd test test/tool/verify_activation_governor_contract_test.dart` | No - Wave 0 |
| R065 | Explore examples/routes pass without Governor decision; action-now activation CTAs fail without Governor decision across Home, Onboarding, Garden, Runtime, reminder/push-like copy. [VERIFIED: 40-CONTEXT.md] | surface contract | `./flutter.cmd test test/features/vnext/activation_governor_contract_surface_test.dart` | No - Wave 0 |

### Sampling Rate

- **Per task commit:** Run the focused Phase 40 verifier unit test after the first test file exists. [VERIFIED: TDD skill + Phase 39 validation pattern]
- **Per verifier task:** Run the new CLI verifier plus existing Phase 39 semantic firewall. [VERIFIED: 39-VALIDATION.md]
- **Per wave merge:** Run Phase 40 focused tests, Phase 39 semantic firewall tests, and the new CLI verifier. [VERIFIED: 39-VALIDATION.md]
- **Phase gate:** Require new Activation Governor contract verifier, existing mobile_v2 semantic firewall, surface fixtures, mobile wrapper parity, and source proof assertions to pass. [VERIFIED: 40-SPEC.md]

### Wave 0 Gaps

- [ ] `tool/verify_activation_governor_contract.dart` - independent Phase 40 contract verifier. [VERIFIED: 40-CONTEXT.md]
- [ ] `test/tool/verify_activation_governor_contract_test.dart` - table-driven red-green tests for structured cases and scans. [VERIFIED: TDD skill]
- [ ] `test/features/vnext/activation_governor_contract_surface_test.dart` - focused surface coverage for Home, Onboarding, Garden, Runtime, reminder/push-like copy. [VERIFIED: 40-CONTEXT.md]
- [ ] `mobile/test/tool/verify_activation_governor_contract_test.dart` - thin wrapper-forwarder matching existing mobile test pattern. [VERIFIED: mobile/test/tool/verify_mobile_v2_semantic_firewall_test.dart]
- [ ] `40-VALIDATION.md` - Nyquist validation map and final gate commands after verifier/test files exist. [VERIFIED: .planning/config.json]
- [ ] Command-health preflight for `dart run`, direct `dart.exe`, and `./flutter.cmd test ...`. [VERIFIED: command output]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no direct Phase 40 auth work | Reuse existing auth/consent infrastructure later; do not create activation decisions in unauthenticated backend paths in this contract phase. [VERIFIED: 39-SUPERSESSION-PROOF.md] |
| V3 Session Management | no direct Phase 40 session work | No session changes planned. [VERIFIED: 40-SPEC.md] |
| V4 Access Control | yes, conceptual authority control | Verifier enforces authority boundaries: Governor owns pacing, Runtime consumes, Garden confirms, Pack/Graph candidates only. [VERIFIED: 40-CONTEXT.md] |
| V5 Input Validation | yes | Validate structured fixtures and scan activation/Garden copy to reject unsafe state transitions and pressure language. [VERIFIED: 40-SPEC.md] |
| V6 Cryptography | no | Do not introduce crypto; no secrets or encryption changes are in scope. [VERIFIED: 40-SPEC.md] |

### Known Threat Patterns for Phase 40

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Activation bypass by Pack/Graph, Runtime, or Garden | Elevation of Privilege | Structured authority fixtures and fail-closed verifier rules. [VERIFIED: 40-CONTEXT.md] |
| Weak-signal telemetry promoted to family truth | Tampering / Repudiation | Parent-confirmation requirement and weak-signal-only prompt restrictions. [VERIFIED: 40-SPEC.md] |
| Checklist pressure disguised as Garden Memory | Safety / Repudiation | Banned Garden/checklist/streak/growth/reward language scan. [VERIFIED: 40-UI-SPEC.md] |
| Over-activation as product harm | Safety | Conservative active-capacity contract and activation-intent gate. [VERIFIED: docs/Baby_Talk_Product_Architecture_Spec_vNext.md] |
| Child performance inference | Information Disclosure / Safety | Garden confirmation is about family routine fit, not child response, scoring, or learning proof. [VERIFIED: 40-SPEC.md] |

## Sources

### Primary (project-authoritative)
- `.planning/phases/40-activation-governor-garden-memory/40-SPEC.md` - locked requirements, verifier rules, scope boundaries, acceptance criteria. [VERIFIED: file read]
- `.planning/phases/40-activation-governor-garden-memory/40-CONTEXT.md` - locked implementation decisions D-01 through D-33, fixture shape, authority seams, matrix. [VERIFIED: file read]
- `.planning/phases/40-activation-governor-garden-memory/40-UI-SPEC.md` - UI/copy pressure constraints for activation and Garden Memory. [VERIFIED: file read]
- `.planning/REQUIREMENTS.md` - R063/R064/R065 active requirements and related R058-R066 M010 context. [VERIFIED: file read]
- `docs/Baby_Talk_Product_Architecture_Spec_vNext.md` - canonical product architecture for Activation Governor, Garden Memory, Explore/Activate, and v1 default active limits. [VERIFIED: file read]

### Secondary (repo evidence)
- `tool/verify_mobile_v2_semantic_firewall.dart` - current Dart verifier/report/scanner/CLI pattern. [VERIFIED: file read]
- `test/tool/verify_mobile_v2_semantic_firewall_test.dart` - temp project fixture and table-style test pattern. [VERIFIED: file read]
- `test/features/vnext/mobile_v2_surface_contract_test.dart` - focused surface contract fixture pattern. [VERIFIED: file read]
- `mobile/test/tool/verify_mobile_v2_semantic_firewall_test.dart` - mobile wrapper-forwarder pattern. [VERIFIED: file read]
- `mobile_v2/lib/vnext_semantic_boundary.dart` and `mobile_v2/pubspec.yaml` - active vNext boundary. [VERIFIED: file read]

### Tertiary
- No external web or package documentation was used; the research-plan seam returned zero fetch items because the phase needs no new package/API decision. [VERIFIED: gsd-tools research-plan]

## Metadata

**Confidence breakdown:**
- Standard stack: MEDIUM - Dart SDK and repo files are verified, but wrapper commands showed local environment issues. [VERIFIED: command output]
- Architecture: HIGH - Phase 40 SPEC/CONTEXT lock scope and authority seams clearly. [VERIFIED: 40-SPEC.md + 40-CONTEXT.md]
- Pitfalls: HIGH - old Garden/progress landmines and Phase 39 verifier patterns are directly visible in repo files. [VERIFIED: codegraph + file reads]
- Formal GSD source confidence: LOW for verified local/codebase/docs providers per classifier; MEDIUM for Context7, which was not needed. [VERIFIED: gsd-tools classify-confidence]

**Research date:** 2026-06-16  
**Valid until:** 2026-07-16, or until Phase 41 adds real Pack/Graph/Runtime contracts that expand the scan surface. [ASSUMED]
