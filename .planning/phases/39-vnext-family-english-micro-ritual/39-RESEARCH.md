# Phase 39: vNext 产品承诺与 Family English Micro-ritual 单元收敛 - Research

**Researched:** 2026-06-15
**Domain:** product/spec convergence, Flutter mobile vNext semantic boundary, verifier architecture
**Confidence:** MEDIUM - project-local authority is strong, but the GSD confidence classifier reports LOW for local `codebase` provider entries.

<user_constraints>
## User Constraints (from CONTEXT.md)

All items in this section are copied or condensed from `.planning/phases/39-vnext-family-english-micro-ritual/39-CONTEXT.md`. [VERIFIED: .planning/phases/39-vnext-family-english-micro-ritual/39-CONTEXT.md]

### Locked Decisions

#### Greenfield Mobile Boundary
- **D-01:** vNext mobile implementation starts as an independent `mobile_v2/` app/package.
- **D-02:** Do not implement vNext by adding modules under old `mobile/lib/features/practice`, `mobile/lib/features/onboarding`, `mobile/lib/features/garden`, or by replacing old meanings surface by surface.
- **D-03:** Old `mobile/` is a frozen deprecated reference: readable, useful for selective copying, but not a legacy compatibility target.
- **D-04:** `mobile_v2/` runtime/product paths must not directly import old `mobile/` domain, data, or presentation models. Any copied code must be semantically re-derived inside `mobile_v2/`.

#### Surface Rewrite Order
- **D-05:** Implement the vertical slice in this order: first micro-ritual onboarding -> Home current-moment orientation -> Practice micro-ritual support -> Garden memory placeholder/boundary.
- **D-06:** Onboarding must prove low-pressure entry into a first candidate micro-ritual. It must not be choosing an activity/path, completing a fixed phrase set, or seeding `starterPhraseId` as product truth.
- **D-07:** Home must orient the current family moment and gentle ritual. It must not use "next incomplete practice" logic.
- **D-08:** Practice must help one micro-ritual become speakable in routine. It must not track phrase completion or treat a child response as required success.
- **D-09:** Garden in Phase 39 implementation remains a non-scoring memory boundary/placeholder only. Full Garden Memory state transitions and parent-confirmation mechanics belong to Phase 40.

#### Semantic Firewall
- **D-10:** Use a hard semantic firewall for `mobile_v2/lib` runtime/product paths.
- **D-11:** Banned old semantics in `mobile_v2/lib` runtime/product paths include: `phraseId`, `activityId`, `completedPhrase`, `completedPhraseCount`, `completedPhraseIds`, `nextPhraseId`, `currentStreakDays`, `streak`, old `GardenGrowth`, phrase completion as progress, and activity/path completion as success.
- **D-12:** Allow old terms only in explicit reference/quarantine locations, such as `mobile_v2/reference_assets/`, `mobile_v2/legacy_reference/`, docs, verifier allowlists, migration notes, or test fixtures that are not runtime product truth.
- **D-13:** Quarantine/reference exceptions must not feed vNext UI, state, repository, or domain models as real product truth.

#### Reuse Policy
- **D-14:** Reusable as reference or copy-and-rederive material: warm visual tone, design tokens, low-pressure onboarding/copy style, audio playback, recording, TTS, pronunciation-button interaction patterns, existing English material as raw fixedSound/example-opener source, auth, consent, event sourcing, gateway, Helm, Flyway, CI, and testing/smoke-verifier patterns.
- **D-15:** Not reusable as vNext semantics: phrase catalog as product truth, activity/path progression, phrase completion, streak, old Garden growth/fertilizer/blooming, "next incomplete" Home logic, and `starterPhraseId` as onboarding truth.
- **D-16:** "素材可以搬运，意义必须重建" is the controlling rule: assets may move only after their product meaning is rebuilt around Family English Micro-rituals.

#### Proof Requirements
- **D-17:** Downstream work must produce proof stronger than docs-only.
- **D-18:** Required proof includes a `mobile_v2` semantic firewall verifier, grep/import guard, banned-term scan with allowlist, targeted unit/widget tests, and docs supersession proof.
- **D-19:** Import guard must prove `mobile_v2/` does not import old `mobile/` domain/data/presentation models.
- **D-20:** Banned-term verifier must scan `mobile_v2/lib` runtime paths and allow old terms only in explicit quarantine/reference/docs/test-fixture paths.
- **D-21:** Targeted tests must prove first micro-ritual onboarding, Home orientation, and Practice support do not depend on phrase completion, streak, or old Garden growth.
- **D-22:** Docs supersession proof must explain how every reused asset avoids carrying old product semantics.

### the agent's Discretion

No open "you decide" areas were left in this discussion. Planner/executor discretion remains only for technical organization inside `mobile_v2/`, concrete UI layout, state management details, and test implementation details, all constrained by the decisions above and by `39-SPEC.md`.

### Deferred Ideas (OUT OF SCOPE)

- Deleting or cleaning up old `mobile/` belongs to a later explicit cleanup phase.
- Activation Governor algorithms, active capacity enforcement, Garden Memory transition mechanics, and parent-confirmation UI belong to Phase 40.
- Primitive Library, Strategy Graph, Strategy Pack schema, Runtime Agent payloads, and transfer metrics belong to Phase 41.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| R058 | Baby Talk v1 must adopt a Family-micro-ritual-first product promise and reject course, translator, check-in, and infinite generation routes. [VERIFIED: .planning/REQUIREMENTS.md] | Use `39-SPEC.md` and `docs/Baby_Talk_Product_Architecture_Spec_vNext.md` as canonical thesis sources; planner should add supersession proof tasks. [VERIFIED: .planning/phases/39-vnext-family-english-micro-ritual/39-SPEC.md] |
| R059 | The v1 product unit is Family English Micro-ritual, not Phrase, Path, Pack, or activity completion. [VERIFIED: .planning/REQUIREMENTS.md] | Plan new `mobile_v2` domain names around fixedSound, routineAnchor, actionBinding, toneHint, no-response rule, soft variant, do-not-use conditions, and exit condition. [VERIFIED: docs/Baby_Talk_Product_Architecture_Spec_vNext.md] |
| R060 | Observed Moment is Context Seed evidence, and Interpreted Moment is joinability hypothesis; neither may become diagnosis or automatic task activation. [VERIFIED: .planning/REQUIREMENTS.md] | Plan docs and tests that reject automatic activation from context matching and preserve evidence-vs-hypothesis language. [VERIFIED: .planning/phases/39-vnext-family-english-micro-ritual/39-SPEC.md] |
</phase_requirements>

## Summary

Phase 39 is already scoped as a WHAT/WHY and supersession-lock phase, with `39-SPEC.md` passing the ambiguity gate at 0.14 and `39-CONTEXT.md` locking `mobile_v2/` as the active vNext implementation boundary. [VERIFIED: .planning/phases/39-vnext-family-english-micro-ritual/39-SPEC.md] The planner should not create tasks that implement Activation Governor mechanics, Garden Memory transitions, Pack/Graph schemas, Runtime Agent payloads, metrics, database schema, API contracts, or polished UI layout in this phase. [VERIFIED: .planning/phases/39-vnext-family-english-micro-ritual/39-CONTEXT.md]

The biggest implementation-planning risk is semantic leakage from old `mobile/` code. Old mobile models encode `starterPhraseId`, `phraseId`, `activityId`, `completedPhraseCount`, `completedPhraseIds`, `nextPhraseId`, `currentStreakDays`, and Garden growth stages directly in domain/runtime code. [VERIFIED: repo grep + codegraph] This supports the locked greenfield stance: copy assets and interaction patterns only after re-deriving product meaning in `mobile_v2/`. [VERIFIED: .planning/phases/39-vnext-family-english-micro-ritual/39-CONTEXT.md]

**Primary recommendation:** Plan Phase 39 as one small contract/proof wave: align canonical docs around the SPEC, add a fail-closed semantic firewall verifier for `mobile_v2/lib`, add focused verifier tests, and record docs supersession proof before any surface implementation tasks. [VERIFIED: .planning/phases/39-vnext-family-english-micro-ritual/39-CONTEXT.md]

## Project Constraints (from AGENTS.md)

- Monorepo has three apps: Flutter mobile, Spring Boot backend, React admin-web. [VERIFIED: AGENTS.md]
- Current core stack is Flutter/Riverpod, Spring Boot 3.4.4/Java 17, React 18/Vite 5/AntD 5. [VERIFIED: AGENTS.md]
- Existing anti-patterns include ViewModel + Notifier double truth, manual polling in admin-web, admin token in localStorage, frontend-held admin permission codes, and overloaded large files. [VERIFIED: AGENTS.md]
- Use repo-established commands and wrappers: `cd mobile && flutter test`, repo-root `flutter.cmd` delegation, backend Maven commands, and `pnpm --filter admin-web ...` for admin-web. [VERIFIED: AGENTS.md]
- For web browsing, project instruction says use the `/browse` skill and never `mcp__claude-in-chrome__*`. No web browsing was needed for this local product/spec phase. [VERIFIED: AGENTS.md]
- No project-local `.codex/skills/` or `.agents/skills/` directories were found. [VERIFIED: shell check]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| vNext product thesis and anti-goals | Planning / Product Docs | Mobile Client | The active truth is `39-SPEC.md`, `39-CONTEXT.md`, requirements, and vNext product spec before runtime implementation. [VERIFIED: .planning/phases/39-vnext-family-english-micro-ritual/39-SPEC.md] |
| Family English Micro-ritual unit | Mobile Client | Planning / Product Docs | `mobile_v2` will own the user-facing/domain expression later, but Phase 39 only locks semantic shape and proof boundaries. [VERIFIED: .planning/phases/39-vnext-family-english-micro-ritual/39-CONTEXT.md] |
| Context Seed / Joinability boundary | Mobile Client | Future Runtime Agent | Observed evidence and interpreted hypothesis must be represented without diagnosis or automatic activation; Runtime contracts are deferred to Phase 41. [VERIFIED: docs/Baby_Talk_Product_Architecture_Spec_vNext.md] |
| Semantic firewall | Tooling / CI | Mobile Client | A repo-root Dart verifier should scan `mobile_v2/lib` imports and banned terms before UI/runtime code can carry product truth. [VERIFIED: .planning/phases/39-vnext-family-english-micro-ritual/39-CONTEXT.md] |
| Garden Memory placeholder | Mobile Client | Phase 40 | Phase 39 may define a non-scoring boundary only; parent-confirmed state transitions belong to Phase 40. [VERIFIED: .planning/ROADMAP.md] |

## Standard Stack

### Core
| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Flutter SDK / Dart | SDK constraint `^3.11.4`; runtime version probe timed out | Future `mobile_v2` app and widget/unit tests | Existing mobile package and root delegation are Flutter-based. [VERIFIED: mobile/pubspec.yaml] |
| Flutter test | SDK dependency | Unit/widget/verifier tests | Existing repo uses `flutter_test` across mobile and root-forwarder verifier tests. [VERIFIED: mobile/pubspec.yaml + test files] |
| Dart repo-root verifier pattern | Existing `tool/verify_*.dart` | Semantic firewall/import/banned-term proof | Existing verifier tools scan source and are covered by `test/tool/*_test.dart`. [VERIFIED: tool/verify_refactor_011_feature_boundaries.dart] |
| `rg` | 15.1.0 | Banned-term discovery and validation | Fast source scan is already available in this environment. [VERIFIED: command output] |
| `gsd-tools` | local Codex GSD shim | Phase metadata, research-plan seam, commits | `init.phase-op 39` resolved phase metadata and `commit_docs=true`. [VERIFIED: gsd-tools init.phase-op] |

### Supporting
| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| Riverpod / hooks_riverpod | 2.6.1 | Future `mobile_v2` state management | Use only when actual runtime screens are planned; Phase 39 should not lock state-management details. [VERIFIED: mobile/pubspec.yaml + 39-SPEC.md] |
| Freezed / json_serializable | Freezed 2.5.2, json_serializable ^6.8.0 | Future immutable models | Use only if `mobile_v2` domain models are created later; avoid copying old generated model semantics. [VERIFIED: mobile/pubspec.yaml + repo grep] |
| GoRouter | 14.8.1 | Future navigation | Out of scope for Phase 39 except to avoid route names that reintroduce old semantics. [VERIFIED: mobile/pubspec.yaml + 39-SPEC.md] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| New external verifier package | Custom Dart scanner using `dart:io` | Existing repo already has pure Dart scanner patterns; adding packages creates unnecessary supply-chain and planning surface. [VERIFIED: tool/verify_refactor_011_feature_boundaries.dart] |
| In-place `mobile/` rewrite | Independent `mobile_v2/` | In-place rewrite would fight deeply embedded old semantics; `mobile_v2/` is locked by context. [VERIFIED: .planning/phases/39-vnext-family-english-micro-ritual/39-CONTEXT.md] |

**Installation:** No new external packages should be installed for Phase 39. [VERIFIED: phase scope]

## Package Legitimacy Audit

Not applicable: Phase 39 should not install external packages. [VERIFIED: .planning/phases/39-vnext-family-english-micro-ritual/39-SPEC.md]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| none | — | — | — | — | — | No install planned |

**Packages removed due to [SLOP] verdict:** none  
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```text
Canonical sources
  39-SPEC.md + 39-CONTEXT.md + REQUIREMENTS.md + vNext product spec
        |
        v
Phase 39 plan tasks
  docs supersession proof + semantic firewall verifier + focused tests
        |
        v
Verifier gates
  import guard: mobile_v2/lib must not import old mobile domain/data/presentation
  banned-term scan: phrase/activity/completion/streak/GardenGrowth blocked except allowlisted quarantine
        |
        v
Planning handoff
  Phase 40: Activation Governor + Garden Memory pacing
  Phase 41: Primitive/Graph/Pack/Runtime/metrics contracts
```

### Recommended Project Structure

```text
.planning/phases/39-vnext-family-english-micro-ritual/
├── 39-SPEC.md          # locked WHAT/WHY and supersession matrix
├── 39-CONTEXT.md       # locked implementation constraints
└── 39-RESEARCH.md      # planner-facing research output

tool/
└── verify_mobile_v2_semantic_firewall.dart   # recommended Phase 39 verifier

test/tool/
└── verify_mobile_v2_semantic_firewall_test.dart

mobile_v2/                                  # future active app boundary
├── lib/                                    # runtime/product path scanned strictly
├── reference_assets/                       # allowed quarantine/reference path
└── legacy_reference/                       # allowed quarantine/reference path
```

### Pattern 1: Supersession Matrix Drives Tasks
**What:** Every reused old artifact must be classified as Deprecated, Reference only, Re-derived, Deferred to Phase 40, Deferred to Phase 41, or Keep. [VERIFIED: .planning/phases/39-vnext-family-english-micro-ritual/39-SPEC.md]  
**When to use:** Before any plan task copies old mobile code, assets, docs, tests, or product wording into `mobile_v2`. [VERIFIED: .planning/phases/39-vnext-family-english-micro-ritual/39-CONTEXT.md]

### Pattern 2: Fail-Closed Semantic Firewall
**What:** Use a Dart verifier that fails when `mobile_v2/lib` imports old `mobile/` product layers or contains banned old product terms outside explicit allowlist paths. [VERIFIED: .planning/phases/39-vnext-family-english-micro-ritual/39-CONTEXT.md]  
**When to use:** Wave 0 or first task of the phase, before any broad implementation. [VERIFIED: existing verifier pattern]

### Pattern 3: Reference Quarantine
**What:** Put copied raw assets, examples, migration notes, or old snippets under explicit quarantine paths such as `mobile_v2/reference_assets/` or `mobile_v2/legacy_reference/`. [VERIFIED: .planning/phases/39-vnext-family-english-micro-ritual/39-CONTEXT.md]  
**When to use:** When old phrases/audio/design tokens are useful as material but must not become vNext product truth. [VERIFIED: .planning/phases/39-vnext-family-english-micro-ritual/39-CONTEXT.md]

### Anti-Patterns to Avoid
- **Docs-only closure:** Fails D-17 because downstream work must produce machine-checkable proof. [VERIFIED: .planning/phases/39-vnext-family-english-micro-ritual/39-CONTEXT.md]
- **Phrase as renamed micro-ritual:** Fails R059 if phrase IDs or completion counts remain the unit of progress. [VERIFIED: .planning/REQUIREMENTS.md]
- **Home as next incomplete task:** Fails D-07 and the Home supersession boundary. [VERIFIED: .planning/phases/39-vnext-family-english-micro-ritual/39-CONTEXT.md]
- **Garden placeholder with streak/growth language:** Fails D-09 and R064 handoff constraints. [VERIFIED: .planning/REQUIREMENTS.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Source scanning | Ad hoc shell chains in every plan task | One Dart verifier under `tool/` plus focused tests | Existing repo uses verifier tools as reusable proof surfaces. [VERIFIED: tool/verify_refactor_011_feature_boundaries.dart] |
| Product-unit migration | Compatibility adapter from old Phrase/Activity models | Clean `mobile_v2` semantic model | No real-user compatibility pressure exists, and old semantics are deprecated/reference-only. [VERIFIED: 39-SPEC.md] |
| Garden progress | Completion/streak-derived projection | Phase 39 placeholder, Phase 40 parent-confirmed Garden Memory | Garden Memory transitions are deferred and must avoid score/checklist semantics. [VERIFIED: .planning/ROADMAP.md] |
| Activation logic | Hard-coded Activate Today rules | Phase 40 Activation Governor contract | Phase 39 must not invent algorithms or thresholds. [VERIFIED: 39-SPEC.md] |

**Key insight:** the hard part is not Flutter implementation; it is preventing old product meaning from re-entering through copied models, test fixtures, generated code, copy text, and Garden/Home assumptions. [VERIFIED: repo grep + 39-CONTEXT.md]

## Runtime State Inventory

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | Old mobile local data and generated models may contain phrase/activity/streak semantics, but Phase 39 has no real-user compatibility requirement and old `mobile/` remains frozen reference. [VERIFIED: 39-SPEC.md] | No data migration in Phase 39; plan semantic guard and future `mobile_v2` clean state only. |
| Live service config | No external live service config was identified for Phase 39; backend/API contracts are out of scope. [VERIFIED: 39-SPEC.md] | None. |
| OS-registered state | No OS-level registrations were identified for Phase 39. [VERIFIED: phase scope] | None. |
| Secrets/env vars | No secret or env var rename is required by Phase 39. [VERIFIED: phase scope] | None. |
| Build artifacts | Existing generated Freezed files under `mobile/lib/generated` contain old phrase/activity/Garden terms. [VERIFIED: repo grep] | Do not treat generated old files as reusable domain truth; if `mobile_v2` uses codegen later, generated outputs must be under `mobile_v2` and pass the firewall. |

## Common Pitfalls

### Pitfall 1: Copying Old Models Because They Compile
**What goes wrong:** `PracticePhrase`, `PracticeCatalogActivitySummary`, `OnboardingSnapshot`, or `GardenGrowthSnapshot` shape reappears in `mobile_v2`. [VERIFIED: codegraph]  
**Why it happens:** The old app is complete enough to be tempting reference code. [VERIFIED: .planning/PROJECT.md]  
**How to avoid:** Require supersession classification and a banned-term/import verifier before copying. [VERIFIED: 39-CONTEXT.md]  
**Warning signs:** `phraseId`, `activityId`, `completedPhraseCount`, `nextPhraseId`, `currentStreakDays`, or old `GardenGrowth` appears under `mobile_v2/lib`. [VERIFIED: 39-CONTEXT.md]

### Pitfall 2: Treating Context Match as Activation
**What goes wrong:** Observed routine signals automatically produce “today go say this” tasks. [VERIFIED: docs/Baby_Talk_Product_Architecture_Spec_vNext.md]  
**Why it happens:** Old flows use selection/recent practice as next-step truth. [VERIFIED: 39-SPEC.md]  
**How to avoid:** Keep Context Seed as evidence and Joinability as hypothesis; activation policy is Phase 40. [VERIFIED: 39-SPEC.md]

### Pitfall 3: Garden Placeholder Becomes Scoreboard
**What goes wrong:** Placeholder UI or tests use completion, streak, growth, fertilizer, bloom, or unlock language. [VERIFIED: 39-SPEC.md]  
**Why it happens:** Existing Garden projection is phrase-completion-derived. [VERIFIED: codegraph]  
**How to avoid:** Phase 39 Garden should be a non-scoring memory boundary only. [VERIFIED: 39-CONTEXT.md]

## Code Examples

### Dart Verifier Shape
```dart
// Source: tool/verify_refactor_011_feature_boundaries.dart [VERIFIED: repo file]
final directivePattern = RegExp(r'''^\s*(import|export)\s+['"]([^'"]+)['"]''');

// Recommended Phase 39 adaptation:
// - scan mobile_v2/lib/**/*.dart
// - reject imports matching package:mobile/features/{practice,onboarding,garden}/...
// - reject banned terms unless the path is an explicit quarantine/docs/test fixture path
```

### Banned-Term Scan Seed
```text
# Source: 39-CONTEXT.md D-11 [VERIFIED: .planning/phases/39-vnext-family-english-micro-ritual/39-CONTEXT.md]
phraseId
activityId
completedPhrase
completedPhraseCount
completedPhraseIds
nextPhraseId
currentStreakDays
streak
GardenGrowth
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Phrase/activity/completion/streak/Garden growth loop | Family English Micro-ritual + Context Seed/Joinability + conservative activation boundaries | M010 restart on 2026-06-14/15 | Plans must stop treating old mobile product semantics as legacy compatibility targets. [VERIFIED: .planning/STATE.md] |
| Old M010 Phase 39-41 planning docs | New Phase 39-41 sequence from vNext product architecture spec | 2026-06-14 | Phase 39 locks supersession; Phase 40 locks Activation/Garden; Phase 41 locks Runtime/Pack/metrics. [VERIFIED: .planning/ROADMAP.md] |

**Deprecated/outdated:** old design docs and code assumptions that make Home a task dashboard, Practice phrase completion, Onboarding starter phrase truth, or Garden growth/streak projection. [VERIFIED: 39-SPEC.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Dart/Flutter are installed but version probes timed out, so availability should be rechecked in Wave 0. | Environment Availability | Planner may choose commands that hang in this shell without a preflight fallback. |
| A2 | It is unclear whether Phase 39 should create an empty `mobile_v2/` package skeleton or only prepare the proof contract. | Open Questions | Planner may either overbuild runtime structure too early or lack a concrete path for verifier proof. |
| A3 | It is unclear whether docs supersession proof should live in a phase-local note or a durable `docs/` supersession note. | Open Questions | Supersession evidence may be hard for future phases to find. |

## Open Questions

1. **Should Phase 39 itself create `mobile_v2/` or only prepare the proof contract?**
   - What we know: Context locks `mobile_v2/` as the boundary and proof must be stronger than docs-only. [VERIFIED: 39-CONTEXT.md]
   - What's unclear: Whether the first implementation plan should create an empty `mobile_v2` package skeleton or leave package creation to the next phase. [ASSUMED]
   - Recommendation: Create only the minimum path/skeleton needed for verifier tests if the planner needs executable proof; avoid UI/runtime screens in this phase.

2. **Should docs supersession proof update archived design specs or add a new supersession note?**
   - What we know: Old design docs may be reference-only and fail if imported as binding vNext requirements. [VERIFIED: 39-SPEC.md]
   - What's unclear: The preferred docs location for a durable supersession note. [ASSUMED]
   - Recommendation: Prefer a small phase-local or `docs/` supersession note linked from `39-SPEC.md`, not broad archived-doc rewrites.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| `git` | source inspection / commit | yes | 2.53.0.windows.2 | — |
| `rg` | banned-term scans | yes | 15.1.0 | PowerShell `Select-String`, slower |
| `node` | `gsd-tools` shim | yes | v24.14.0 | — |
| `pnpm` | admin-web only, likely not needed | yes | 11.1.1 | npm, if admin-web touched |
| `dart` | verifier execution | command found, version probe timed out | path `C:\software\flutter\bin\dart.bat` | Wave 0 preflight; use repo wrapper where possible |
| `flutter` | focused Flutter tests | command found, version probe timed out | path `C:\software\flutter\bin\flutter.bat` | Wave 0 preflight; use `./flutter.cmd` wrapper |
| `gsd-tools` | phase metadata and commit | yes | local shim | direct file write if commit tool fails |

**Missing dependencies with no fallback:** none confirmed.  
**Missing dependencies with fallback:** Dart/Flutter version proof timed out; planner should include a Wave 0 command-health check. [VERIFIED: command output]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Flutter test / Dart verifier tests from existing repo pattern. [VERIFIED: mobile/pubspec.yaml] |
| Config file | `mobile/dart_test.yaml`, `mobile/analysis_options.yaml`, root `pubspec.yaml` delegation. [VERIFIED: rg --files] |
| Quick run command | `./flutter.cmd test test/tool/verify_mobile_v2_semantic_firewall_test.dart` |
| Full suite command | `./flutter.cmd test test/tool/verify_mobile_v2_semantic_firewall_test.dart test/features/vnext/` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| R058 | vNext thesis rejects course/translator/check-in/infinite generation and old completion/growth goals | verifier/docs test | `./flutter.cmd test test/tool/verify_mobile_v2_semantic_firewall_test.dart` | ❌ Wave 0 |
| R059 | `mobile_v2/lib` does not use Phrase/Activity/completion/streak as product truth | static verifier | `dart run tool/verify_mobile_v2_semantic_firewall.dart` | ❌ Wave 0 |
| R060 | Context Seed/Joinability wording does not auto-activate content or diagnose child state | docs/static verifier plus later unit tests | `./flutter.cmd test test/features/vnext/context_joinability_boundary_test.dart` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** focused verifier test plus `dart run tool/verify_mobile_v2_semantic_firewall.dart` after tool exists.
- **Per wave merge:** focused Flutter test pack for vNext boundary plus semantic firewall verifier.
- **Phase gate:** docs supersession proof, semantic firewall verifier, import guard, and banned-term scan green before `$gsd-verify-work`.

### Wave 0 Gaps
- [ ] `tool/verify_mobile_v2_semantic_firewall.dart` — scanner for imports, banned terms, and allowlisted quarantine paths.
- [ ] `test/tool/verify_mobile_v2_semantic_firewall_test.dart` — pure tests for scanner behavior.
- [ ] `mobile/test/tool/verify_mobile_v2_semantic_firewall_test.dart` — optional wrapper-forwarder only if root/mobile test delegation needs it, matching existing pattern. [VERIFIED: mobile/test/tool/verify_m006_s14_release_closure_test.dart]
- [ ] `test/features/vnext/` or future `mobile_v2/test/` targeted tests — only if Phase 39 creates a minimal package/skeleton.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no Phase 39 runtime change | Reuse existing auth only as infrastructure; do not change token/session contract. [VERIFIED: 39-CONTEXT.md] |
| V3 Session Management | no Phase 39 runtime change | No session work planned. [VERIFIED: 39-SPEC.md] |
| V4 Access Control | no direct runtime change | Future `mobile_v2` must not bypass consent/auth infrastructure if reused. [VERIFIED: 39-CONTEXT.md] |
| V5 Input Validation | yes, semantic/data-boundary validation | Validate Context Seed vs Interpreted Moment wording and reject automatic activation/diagnosis semantics. [VERIFIED: docs/Baby_Talk_Product_Architecture_Spec_vNext.md] |
| V6 Cryptography | no new crypto | Do not hand-roll crypto; reuse existing secure storage/auth infrastructure if needed later. [VERIFIED: AGENTS.md] |

### Known Threat Patterns for Flutter/Product-Semantic Phase

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Old semantic injection through copied models or fixtures | Tampering | Semantic firewall verifier and supersession matrix classification. [VERIFIED: 39-CONTEXT.md] |
| Child-state diagnosis from interpreted hypotheses | Information Disclosure / Safety | Keep Observed Moment as evidence and Interpreted Moment as low-confidence joinability hypothesis. [VERIFIED: docs/Baby_Talk_Product_Architecture_Spec_vNext.md] |
| Pressure/checklist UX disguised as Garden memory | Repudiation / Safety | Reject streak/completion/scoring terms in `mobile_v2/lib`; defer real Garden Memory mechanics to Phase 40. [VERIFIED: .planning/ROADMAP.md] |

## Sources

### Primary (project-authoritative)
- `.planning/phases/39-vnext-family-english-micro-ritual/39-SPEC.md` - locked requirements, supersession matrix, boundaries, ambiguity gate.
- `.planning/phases/39-vnext-family-english-micro-ritual/39-CONTEXT.md` - implementation decisions, `mobile_v2` boundary, semantic firewall, proof requirements.
- `.planning/REQUIREMENTS.md` - R058/R059/R060 plus Phase 40/41 handoff requirements.
- `.planning/ROADMAP.md` - M010 Phase 39/40/41 sequence.
- `.planning/STATE.md` - M010 restart history.
- `docs/Baby_Talk_Product_Architecture_Spec_vNext.md` - canonical vNext product architecture thesis.

### Secondary (repo evidence)
- `mobile/lib/features/onboarding/domain/models/onboarding_snapshot.dart` - old `starterPhraseId` truth model evidence.
- `mobile/lib/features/practice/domain/models/garden_growth_snapshot.dart` - old Garden growth/streak/completion model evidence.
- `tool/verify_refactor_011_feature_boundaries.dart` and `test/tool/verify_refactor_011_feature_boundaries_test.dart` - verifier pattern evidence.
- `mobile/pubspec.yaml` and root `pubspec.yaml` - Flutter/test dependency and delegation evidence.

### Tertiary
- None. External web research was not used because this phase is governed by local product/spec artifacts and no external package/API choice is in scope. [VERIFIED: gsd-tools init.phase-op]

## Metadata

**Confidence breakdown:**
- Standard stack: MEDIUM - existing repo files verify stack, but Dart/Flutter version commands timed out.
- Architecture: HIGH - phase SPEC/CONTEXT lock boundaries clearly.
- Pitfalls: HIGH - old semantics are directly visible in repo grep and codegraph output.

**Research date:** 2026-06-15  
**Valid until:** 2026-07-15, or until Phase 40/41 changes the vNext contract.
