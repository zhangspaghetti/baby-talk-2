# Custom Scene Agentic Generation and Approved Output Reuse Design

- **Date:** 2026-07-14
- **Status:** Approved design
- **Target repository:** `baby-talk-2`
- **Target branch:** `gsd/v0.1-milestone`
- **Intended repository path:** `docs/superpowers/specs/2026-07-14-custom-scene-agentic-generation-approved-output-reuse-design.md`

## 1. Purpose

This design hardens the existing custom-scene discovery path into a production-capable agentic generation pipeline and defines how approved outputs become reusable assets without turning model-generated text into authoritative evidence.

The design preserves Baby Talk's core product promise: a parent describes a real care moment and receives complete, directly speakable family English tied to the current action. The system must not turn the interaction into a course, child-performance session, task, reward loop, or generic phrase-generation feature.

The design solves six related problems:

1. Unicode-safe input canonicalization and deterministic hard-safety enforcement.
2. A bounded Generator → deterministic gate → independent Judge → Repair pipeline.
3. Reproducible evidence, prompt, rubric, policy, provider-call, and state-transition audit.
4. Exact and semantic reuse before new generation.
5. Privacy-safe cross-family reuse through immutable Global Approved Output Assets.
6. Fail-closed state, deletion, consent, indexing, and rollout semantics.

## 2. Core architectural rules

The implementation MUST preserve these boundaries:

- **Authoritative evidence** and **approved final outputs** are separate asset classes.
- Model-generated outputs MUST NOT automatically enter the Strategy/RAG evidence index.
- A model recommendation never directly activates content, publishes a public asset, expands applicability, or authorizes cross-family reuse.
- Deterministic application policy computes all effective verdicts and state transitions.
- Search indexes are derived projections, never the system of record.
- Terminal generation executions are immutable and never revived.
- Public output text is immutable after publication.
- Any ambiguity involving safety, privacy, cross-family eligibility, compatibility, or semantic match fails closed.

## 3. Scope and phased delivery

### 3.1 First implementation scope

The first implementation plan SHOULD cover:

- ICU4J-backed dual text canonicalization.
- Generated-content state machine and package-internal write boundary.
- Semantic attempts, AI operation runs, and real provider-call audit.
- Spring AI provider manager and typed capability adapters.
- Immutable attempt evidence bundles.
- Generator, deterministic output validation, Quality Judge, and bounded Repair.
- Prompt, rubric, evidence-policy, and generation-profile versioning.
- Private exact reuse.
- Required database migrations, tests, verifiers, Helm/YAML configuration, and fail-closed startup validation.

### 3.2 Follow-on implementation phases

The following are fully designed here but SHOULD be introduced after the reliable private-generation loop is running:

1. Owner-private semantic reuse.
2. Scene Abstraction.
3. Reuse Match Gate.
4. Reuse Eligibility and applicability evaluation.
5. Global Approved Output Asset publication.
6. Global semantic reuse.
7. Historical asset requalification.

These later phases MUST NOT block delivery of the first reliable custom-scene generation loop.

### 3.3 Explicit non-goals

This design does not require:

- Productionizing the current fake provider as a semantic-quality solution.
- Treating generated outputs as Strategy Pack or RAG evidence.
- Open-ended tool-using Judge, Match, Abstraction, or Reuse Eligibility agents.
- Runtime editing of rubrics or policies through an admin UI.
- Preserving historical provider credentials or dynamically rebuilding old Provider beans.
- A scheduler as a prerequisite where existing lazy/batch cleanup hooks are sufficient.
- Mobile, `mobile_v2`, Garden, Growth, care-turn, or Baby Profile Option Catalog changes.

## 4. End-to-end request flow

The runtime order is:

```text
custom scene request
→ identity and owner scope
→ Unicode canonicalization
→ deterministic input safety gate
→ request abuse protection
→ current profile fingerprint

→ owner-private exact lookup
   → hit: hydrate and return

→ owner-private semantic lookup, when enabled
   → Reuse Match Gate
   → MATCH: hydrate and return

→ obtain or create owner-scoped Scene Abstraction
→ if globally eligible, query Global Approved Output Index
→ deterministic compatibility/applicability filters
→ Reuse Match Gate
   → MATCH: hydrate public asset, record reuse receipt, return

→ no reusable result
→ reserve a new generated-content execution
→ retrieve and freeze evidence
→ Generator
→ deterministic output gate
→ independent Quality Judge
→ bounded Repair when allowed
→ activate private output and return

→ asynchronous Reuse Eligibility and public-asset publication
```

The exact owner lookup MUST precede semantic search. Semantic reuse MUST precede new generation. A semantic miss or abstention silently continues to the normal generation path.

## 5. Unicode-safe input model

### 5.1 Dependency

`backend/app-api` MUST add ICU4J. JDK-only case folding and ad hoc regular expressions are not sufficient for the approved security model.

### 5.2 Dual text representation

Each request produces two derived forms and ephemeral risk signals.

#### `displayText`

Purpose:

- Human-readable canonical form.
- Passed to approved business capability adapters.
- Temporarily stored only while a generated-content execution is non-terminal.

Processing:

- Unicode NFKC-compatible normalization.
- Unicode whitespace collapse.
- Trim.
- Remove selected invisible formatting characters.
- Preserve emoji ZWJ (`U+200D`) sequences.

The existing `normalized_scene_text` column represents this temporary display form. It MUST be cleared when a row becomes active, rejected, or expired.

#### `securityText`

Purpose:

- PII detection.
- Prompt-injection and high-risk policy matching.
- Owner-scoped HMAC request fingerprint input.
- Number-system and digit-sequence analysis.

Processing MUST use:

```java
Normalizer2.getNFKCCasefoldInstance()
```

`securityText` MUST NOT be:

- Persisted.
- Returned through APIs.
- Sent to a provider.
- Written to logs, audit rows, search indexes, or error payloads.

#### Risk signals

Risk signals are request-scoped only. They MUST NOT be persisted or returned.

### 5.3 Character risk handling

- Bidi override and isolate controls: HTTP 422.
- Selected removable invisibles, including BOM and WORD JOINER: remove and continue.
- Emoji ZWJ: preserve.
- Mixed number systems: reject only when they form a long number or strengthen PII suspicion.
- Chinese-English mixing: allowed.
- Confusables: not an independent rejection reason.

ICU4J `SpoofChecker` skeletons MAY strengthen only high-risk matching:

- PII markers.
- Prompt-injection markers.

They MUST NOT drive ordinary scene classification, general content-policy classification, or broad medical/adult keyword matching.

## 6. Generated output contract

### 6.1 Internal fields

A generated candidate contains at least:

```text
englishText
chineseText
tprActionZh
deliveryGuidanceZh
trusted provider metadata
```

`coachTipZh` is not persisted. The API composes it at read time from:

```text
tprActionZh + deliveryGuidanceZh
```

Both fields are required before activation or public publication.

### 6.2 Field semantics

- `englishText`: direct parent speech to the child.
- `chineseText`: meaning support, not parent instruction.
- `tprActionZh`: an executable physical action, object interaction, posture, gesture, or deliberate pause.
- `deliveryGuidanceZh`: timing, tone, pace, waiting, observation, or low-pressure delivery guidance.

### 6.3 Deterministic output gate

The deterministic gate verifies high-confidence safety and structure. It does not pretend to score naturalness comprehensively.

It rejects or repairs:

- Meta instructions or narration instead of direct speech.
- Course, lesson, scoring, reward, streak, completion, or performance framing.
- Markdown, list, or template artifacts.
- Missing required fields.
- Swapped field roles.
- Missing executable TPR signal.
- Missing delivery-guidance signal.
- Database physical overflow.
- PII, bidi, adult/violent, dangerous medical, untrusted metadata, invalid enum, or invalid state.

### 6.4 Repairability split

Non-repairable deterministic failures terminate immediately:

```text
PII
bidi controls
adult or violent output
dangerous medical guidance
untrusted provider metadata
physical database overflow
invalid enum or state
```

Repairable deterministic failures skip Judge and consume a new semantic attempt when capacity remains:

```text
missing TPR action
missing delivery guidance
field-role swap
meta instruction or narration
course/scoring framing
template or Markdown artifacts
```

## 7. Semantic attempts and bounded repair

### 7.1 Attempt configuration

Configuration:

```yaml
max-generation-attempts: 2
```

Constraints:

- Allowed range: 1–5.
- Default: 2.
- Out-of-range configuration fails application startup.
- The value is snapshotted into `practice_generated_content.generation_attempt_limit`.
- Runtime configuration changes affect only new executions.

Meaning:

- Attempt 1 is the initial generation.
- Attempts 2–N are semantic repair rounds.
- Provider fallback calls do not increment the semantic attempt number.

### 7.2 Attempt lifecycle

An attempt row is created before the provider call with `outcome = started` and UTC timestamps.

On stale-draft cleanup or application restart recovery:

- `started` attempts become `interrupted`.
- `completed_at` is set.
- The parent generated-content execution becomes expired.
- Temporary normalized scene text is cleared.

`violation_codes` are stable, deduplicated, sorted enums. They MUST NOT contain excerpts or arbitrary provider text.

### 7.3 Typed Repair Package

Repair receives only:

```text
displayText
ageRange
parentGoal
previous structured candidate
effectiveVerdict
failedDimensions
validated violationCodes
validated repairDirectives
sanitized evidence summaries
prompt/rubric/strategy versions
```

Repair MUST NOT receive:

- Raw retrieval chunks.
- Judge free-text reasons.
- Chain of thought.
- Provider raw response.
- Previous system prompt.
- Account or device identifiers.
- Internal logs.

A repaired candidate must pass the full deterministic gate and a new independent Quality Judge.

## 8. Evidence architecture

### 8.1 Evidence is not generated output

The evidence index contains trusted strategy, primitive, age, safety, or curated knowledge sources. Approved final outputs live in a separate reuse asset system.

Generated outputs MUST NOT automatically become authoritative evidence.

### 8.2 Judge evidence input

Judge receives a sanitized structured evidence summary, never full chunks.

Each evidence item includes:

```text
evidenceId
sourceType
sourceVersion when available
strategyId
claimType
sanitizedSummary
confidence
```

`sanitizedSummary` must be:

- Produced by a trusted retrieval/strategy adapter.
- Length bounded.
- Free of PII, URL, HTML, Markdown, prompt-like directives, and raw web content.
- Treated by Judge as data, never as instruction.

Generator output cannot self-declare its own supporting evidence.

### 8.3 Replay modes

Evidence persistence uses two modes.

#### `REFERENCE`

For immutable, version-addressable internal evidence:

```text
evidence_id
source_type
source_version
strategy_id
claim_type
sanitizer_version
sanitized_summary_hash
```

No summary snapshot is stored. Replay retrieves the exact source version, reapplies the sanitizer version, and validates the hash.

#### `SNAPSHOT`

For temporary or non-reproducible evidence:

```text
evidence_id
source_type
strategy_id
claim_type
sanitizer_version
sanitized_summary_hash
bounded sanitized_summary_snapshot
```

Raw chunks are never stored. Snapshot data follows the parent generated-content lifecycle.

### 8.4 Immutable attempt evidence bundle

Each semantic attempt has at most one immutable evidence bundle.

```text
practice_generated_content_evidence_bundles
practice_generated_content_evidence_items
```

All Generator, Repair, and Judge fallback calls in the same attempt reference the same bundle.

A subsequent repair attempt creates a new bundle:

- `REUSED`: derived from the prior bundle without new external retrieval.
- `REFRESHED`: targeted retrieval based on controlled evidence-gap codes.

The bundle records:

```text
derived_from_bundle_id
retrieval_outcome
retrieval_trace_id
evidence_policy_version/hash
sanitizer_version
bundle_hash
evidence_count
```

The bundle and items are immutable after creation.

### 8.5 Minimum Evidence Policy

A versioned YAML policy defines:

```text
required claim coverage
trusted source types
minimum confidence
sanitizer requirements
```

If internal evidence satisfies all required claims, an unavailable external source does not automatically block generation. If minimum coverage is not met:

```text
status = EXPIRED
error_code = insufficient_evidence | evidence_retrieval_unavailable
retryable = true
suggest_catalog_fallback = true
```

Generator is not called and generation quota is not consumed.

### 8.6 Refresh decision

Judge reports only controlled evidence-gap codes, for example:

```text
MISSING_SCENE_SUPPORT
MISSING_AGE_GUIDANCE
MISSING_LOW_PRESSURE_GUIDANCE
LOW_EVIDENCE_CONFIDENCE
CONFLICTING_EVIDENCE
EVIDENCE_SCOPE_MISMATCH
```

Application policy determines `REUSED` or `REFRESHED`. Unknown codes or ungrounded model suggestions do not trigger retrieval.

## 9. Quality Judge

### 9.1 Role

The independent Quality Judge evaluates:

- Scene alignment.
- Parent speakability.
- Absence of course/scoring/reward framing.
- TPR executability.
- Delivery-guidance quality.
- Age suitability.
- English-Chinese semantic consistency.
- Low-pressure family support.

It has no tools, memory, web access, or database writes.

### 9.2 Inputs

Judge receives:

- Sanitized scene representation.
- Candidate structured output.
- Sanitized structured evidence summary.
- Age range and parent goal.
- Trusted version metadata.

Judge does not receive raw retrieval chunks, full provider prompts, account information, arbitrary logs, or unclean web content.

### 9.3 Structured result

Judge returns:

```text
suggestedVerdict = PASS | REPAIR | REJECT | ABSTAIN
dimensionResults = PASS | FAIL | ABSTAIN per required dimension
violationCodes
repairDirectives
evidenceGapCodes
judgeConfidence
```

`dimension_results` is stored as JSONB, validated strictly by `rubric_version`:

- All required dimensions present.
- No unknown dimensions.
- Only allowed enum values.
- No free-text reasoning.

### 9.4 Effective verdict

The application calculates `effectiveVerdict` from the versioned rubric.

If model and application disagree:

- Record `judge_verdict_inconsistent`.
- Never upgrade to PASS because of the model suggestion.
- Use the application-computed verdict for state transitions.

`judgeConfidence` is audit and observability data only. It never directly changes state, triggers retrieval, or overrides a dimension.

### 9.5 ABSTAIN

`ABSTAIN` is content uncertainty, not provider infrastructure failure.

- Record `judge_abstained`.
- Consume a repair attempt when capacity remains.
- If attempts are exhausted, reject the execution.

Provider-chain exhaustion or schema-parse exhaustion is infrastructure failure and expires the execution instead.

## 10. Spring AI provider architecture

### 10.1 Configuration

Providers and capability routes are defined in Helm/YAML:

```yaml
app:
  ai:
    providers:
      <provider-name>: ...
    capabilities:
      custom-scene-generator:
        provider-names: [...]
      custom-scene-quality-judge:
        provider-names: [...]
      custom-scene-repair:
        provider-names: [...]
      scene-abstraction:
        provider-names: [...]
      approved-output-reuse-match:
        provider-names: [...]
      approved-output-reuse-eligibility:
        provider-names: [...]
```

API keys come from Kubernetes Secrets/environment variables, not committed YAML values.

### 10.2 Provider Manager

The Provider Manager:

- Creates and caches `ChatModel`/`ChatClient` beans.
- Validates configuration at startup.
- Owns timeout, fallback iteration, common observability, and trusted provider metadata.
- Never owns business prompts, schemas, or domain state transitions.

Capability adapters:

- Own prompts and typed output schemas.
- Convert provider responses into domain structures.
- Do not write database state.

Domain orchestrators:

- Apply deterministic policies.
- Decide repair, refresh, activation, rejection, expiration, and publication.

### 10.3 Fallback semantics

Each capability has an explicit ordered provider list. There is no hidden global fallback.

Fallback is allowed for:

```text
connection failure
timeout
429
5xx
temporary unavailable
structured-output parse/schema failure
```

Fallback is not allowed for:

```text
deterministic safety violation
Judge REJECT
Judge REPAIR
semantic mismatch
course/pressure issue
```

Each provider is tried at most once per logical operation run.

### 10.4 Routing Policy after restart

Provider configuration changes require application restart because providers are registered as Spring beans.

Routing Policy version/hash is stored for audit only. It is not an executable snapshot and does not enter content fingerprinting.

On application restart:

- Running AI operations become interrupted.
- Started provider calls become interrupted.
- Incomplete generated-content drafts become expired with `generation_interrupted`.
- Retrying creates a new execution using the current Spring beans and routing policy.

The system does not preserve historical credentials or dynamically reconstruct old Provider beans.

## 11. AI operation and provider-call audit

The audit model has two layers.

### 11.1 Logical operation run

```text
practice_ai_operation_runs
```

Fields include:

```text
ai_operation_run_id
operation_type
subject_type
subject_id
generated_content_id nullable
attempt_number nullable
evidence_bundle_id nullable
capability_name
prompt_version/hash
policy_version/hash
status
started_at
completed_at
```

Operation types include:

```text
SCENE_ABSTRACTION
GENERATOR
QUALITY_JUDGE
REPAIR
REUSE_MATCH
REUSE_ELIGIBILITY
APPLICABILITY
ASSET_REQUALIFICATION
```

### 11.2 Actual provider call

```text
practice_ai_provider_calls
```

Fields include:

```text
provider_call_id
ai_operation_run_id
provider_name
model_name
fallback_index
attempt_trace_id UUID
provider_trace_id nullable
routing_policy_version/hash
outcome
latency_ms
started_at
completed_at
```

Rules:

- `attempt_trace_id` is generated by Baby Talk for every real call and is unique.
- `provider_trace_id` comes only from a trusted adapter and is length/character/PII validated.
- `model_name` comes from trusted adapter configuration, never model output.
- No prompt, candidate, response, exception body, or raw provider error text is stored.

A successful Quality Judge call has one separate structured Judge-result row associated with its provider-call ID. Failed or unparseable calls have no Judge-result row; failure remains in provider-call outcome.

## 12. Generated-content state machine and write boundary

### 12.1 States

```text
DRAFT
GENERATING
ACTIVE
REJECTED
EXPIRED
```

- `ACTIVE`: private result available to the current owner.
- `REJECTED`: terminal content-quality failure.
- `EXPIRED`: terminal infrastructure, interruption, timeout, or evidence-availability failure.

Terminal rows are never revived. A retry creates a new generated-content row.

The live unique index applies only to statuses considered live or reusable, such as DRAFT, GENERATING, and ACTIVE. REJECTED and EXPIRED rows do not block a later execution with the same request fingerprint.

### 12.2 Package-internal command boundary

Use:

```text
PracticeGeneratedContentService
practice.generated.internal.PracticeGeneratedContentWriteService
PracticeGeneratedContentCommandMapper
PracticeGeneratedContentQueryMapper
```

Rules:

- Only the write service may depend on the command mapper.
- Web, discovery, capability adapters, and other services cannot call mutation mapper methods.
- No production `insertRow` test helper.
- No generic CRUD or inherited `BaseMapper` mutation path.
- Tests use `JdbcTemplate` or test-only fixtures.
- Public transactional service methods remain compatible with Spring proxies.

ArchUnit/verifier rules enforce this boundary.

## 13. Failure and API semantics

| Failure | Result |
|---|---|
| Input PII, bidi control, or clear attack | HTTP 422; no generated-content execution |
| Minimum evidence not met | EXPIRED; retryable |
| Generator or Repair provider chain unavailable | EXPIRED; retryable |
| Judge provider chain unavailable | EXPIRED; retryable |
| Non-repairable deterministic output violation | REJECTED |
| Judge REJECT | REJECTED |
| Repair attempts exhausted | REJECTED |
| Reuse Match NO_MATCH or ABSTAIN | Continue to next candidate or generation |
| Scene Abstraction unsafe or unavailable | Skip global search; private generation may continue |
| Public publication/index failure | Private ACTIVE result remains usable |
| Application restart interruption | EXPIRED / generation_interrupted; retryable |

Content-quality terminal failures return a stable invalid-output code and may suggest catalog fallback. Infrastructure failures return a stable unavailable/timeout code and are retryable.

The external output contract remains:

```text
englishText
chineseText
coachTipZh
audio metadata
```

Internal source types may include:

```text
PRIVATE_EXACT_REUSE
PRIVATE_SEMANTIC_REUSE
GLOBAL_APPROVED_REUSE
NEW_GENERATION
```

These internal implementation labels are not user-facing copy.

## 14. Versioned prompts, policies, and profiles

### 14.1 Version/hash invariant

Every behavior-defining prompt or policy has:

```text
version
content_hash
schema_version
```

Startup performs:

```text
load
→ canonicalize
→ schema validate
→ SHA-256
→ verify version/hash contract
```

CI verifies that the canonical content for an existing version cannot change. Content changes require a new version.

### 14.2 Independent prompt versions

Maintain independent versions and hashes for:

```text
generator prompt
quality-judge prompt
repair prompt
scene-abstraction prompt
reuse-match prompt
reuse-eligibility prompt
applicability prompt
```

### 14.3 Generation Profile

A `generation_profile_version/hash` combines at least:

```text
generator prompt
judge prompt
repair prompt
quality rubric
minimum evidence policy
strategy version
communication primitive version
content safety policy
generated-output schema version
```

The request fingerprint explicitly includes:

```text
owner scope
surface/mode
securityText-derived scene HMAC
ageRange
parentGoal
generation_profile_version
rubric_version
evidence_policy_version
content_refresh_epoch
```

Rubric and evidence-policy fields are also persisted as explicit lineage columns even though they are members of the profile.

### 14.4 Other profiles and policies

Versioned assets include:

```text
Scene Abstraction Profile
Reuse Match Policy
Reuse Eligibility Policy
Applicability Policy
Approved Output Compatibility Policy
Provider Routing Policy
```

Provider Routing Policy is audit-only and does not automatically invalidate approved content.

## 15. Scene Abstraction

### 15.1 Purpose

Global reuse cannot receive raw custom-scene text because it may contain names, locations, schedules, medical facts, family relations, or Garden Memory.

Scene Abstraction converts the owner-private scene into a controlled, de-identified representation:

```text
genericSceneIntent
careAction
actionPhase
reaction
parentGoal
ageRange
contextTags
suggestedGlobalSearchEligible
abstractionConfidence
```

Unknown information is represented as `UNKNOWN`; the model does not guess.

### 15.2 Pipeline

```text
displayText
→ deterministic PII/sensitive-context gate and redaction
→ no-tool structured Scene Abstraction LLM
→ strict schema validation
→ deterministic privacy recheck
→ Abstraction Policy computes effectiveGlobalSearchEligible
```

The model's eligibility suggestion never directly enables global search. Schema failure, privacy recheck failure, or policy uncertainty forces `effectiveGlobalSearchEligible = false`.

`abstractionConfidence` is observability-only.

### 15.3 Persistence

`practice_scene_abstractions` is owner-scoped private data.

Reuse requires:

```text
same owner
same request fingerprint
same abstraction profile version
same source content hash
valid status
```

There is no cross-family abstraction cache and no cross-owner hash correlation.

Deleting the source custom scene, clearing child/family data, or deleting the account deletes the related abstraction.

## 16. Approved Output reuse architecture

### 16.1 Separate indexes

#### Evidence Index

Contains authoritative, trusted evidence used to support generation.

#### Approved Output Index

Contains final utterances that passed the required quality and reuse gates.

Approved outputs can be directly reused but cannot be cited as authoritative evidence merely because they were generated and judged.

### 16.2 Private reuse

Owner-private exact reuse queries current ACTIVE generated-content rows using the owner-scoped fingerprint.

Owner-private semantic reuse, when enabled, searches only within the owner boundary and still passes the Reuse Match Gate before return.

### 16.3 Global reuse

Global search accepts only a safe Scene Abstraction, never raw scene text or `displayText`.

The path is:

```text
Global Approved Output Index recall
→ database hydrate
→ ACTIVE status
→ effective provenance exists
→ current qualification/compatibility
→ applicability filters
→ Reuse Match Gate
→ MATCH: reuse
→ NO_MATCH: next candidate
→ ABSTAIN/no candidate: new generation
```

## 17. Reuse Match Gate

### 17.1 Deterministic prefilter

Reject candidates before LLM matching when any of these are incompatible:

```text
age range
parent goal
care action
action phase
reaction/context tags
asset status
qualification
compatibility policy
privacy/context dependency
```

### 17.2 Lightweight Match Judge

Remaining candidates are evaluated by a no-tool structured LLM that only answers whether the approved utterance applies to the current abstracted scene.

Output:

```text
MATCH | NO_MATCH | ABSTAIN
```

Dimensions:

```text
care_action_alignment
reaction_alignment
timing_alignment
parent_goal_alignment
age_alignment
context_dependency
```

The application computes the effective verdict under a versioned Match Policy. ABSTAIN never directly reuses content.

The Match Judge does not reevaluate full content quality and does not invoke Generator or Repair.

## 18. Reuse Eligibility and owner-specific content

### 18.1 Effective reuse scope

Private activation initially assigns or evaluates:

```text
OWNER_ONLY
GLOBAL_CANDIDATE
GLOBAL_REUSABLE
```

`OWNER_ONLY` is the safe default.

Cross-family eligibility evaluates both output text and context dependency. A phrase that looks generic can still be owner-dependent if it was selected because of private medical, developmental, routine, location, or family-memory facts.

### 18.2 Independent Reuse Eligibility Gate

The gate evaluates controlled dimensions such as:

```text
contains_owner_specific_information
depends_on_private_context
safe_when_decontextualized
generic_scene_supported
suggested_reuse_scope
```

Deterministic application policy computes the effective scope. Any sensitive signal, inconsistency, or ABSTAIN yields OWNER_ONLY.

Quality PASS does not imply global reuse eligibility.

### 18.3 Asynchronous publication

Private content activation and public publication are separate responsibilities.

Primary request:

```text
quality PASS
→ private generated content ACTIVE
→ PRIVATE_CONTENT_ACTIVATED outbox
→ return to current family
```

Async worker:

```text
check current consent
→ Reuse Eligibility Gate
→ OWNER_ONLY: private indexing only
→ GLOBAL_REUSABLE: create/reuse public asset, provenance, applicability, qualification, and publish outbox
```

Public publication failure never revokes the private ACTIVE result.

## 19. Anonymous reuse consent and privacy deletion

### 19.1 Account-level consent

Cross-family publication requires versioned account-level anonymous-output-reuse consent:

```text
consent status
consent version
granted_at
```

Rules:

- No consent: generation works normally, but reuse scope is forced to OWNER_ONLY.
- Draft creation records the consent state/version for audit.
- Async publication rechecks the current consent before publishing.
- Consent withdrawal cancels pending publication tasks.

### 19.2 Provenance withdrawal

Each public asset is supported by one or more private generated-content provenances.

On consent withdrawal:

1. Withdraw the owner's pending and active provenance relationships.
2. Recalculate whether the public asset has any other effective authorized provenance.
3. If none remain, mark the asset WITHDRAWN and emit deindex outbox.

One valid authorized provenance is sufficient for publication. Provenance count affects ranking and monitoring, not the publication hard gate.

### 19.3 Private data deletion

Deleting one generated-content row, clearing family data, or deleting an account automatically withdraws the corresponding provenance before physical deletion.

The transaction order is:

```text
withdraw provenance
→ update public asset if last source
→ write outbox
→ commit
→ physically delete private source/provenance under privacy cleanup
```

Owner-scoped abstractions, private index documents, and owner reuse receipts are also deleted.

A public asset may remain only when another valid authorized provenance independently supports it.

## 20. Immutable Global Approved Output Assets

### 20.1 Asset identity

`approved_output_assets` stores de-identified immutable utterance content:

```text
approved_output_id
status = ACTIVE | SUPERSEDED | WITHDRAWN
english_text
chinese_text
tpr_action_zh
delivery_guidance_zh
content_hash
origin_generation_profile_version/hash
published_at
superseded_by_approved_output_id nullable
superseded_at nullable
```

`origin_generation_profile_*` records the first publication lineage only. Current reusability is determined by qualifications, compatibility policy, applicability, status, and provenance—not solely by the origin profile.

### 20.2 Content immutability

These fields never change after publication:

```text
english_text
chinese_text
tpr_action_zh
delivery_guidance_zh
content_hash
```

Any content change creates a new asset.

### 20.3 Supersession

Current usability is determined only by `status`.

To supersede:

1. Create new ACTIVE asset.
2. Mark old asset SUPERSEDED.
3. Set old `superseded_by_approved_output_id` and `superseded_at`.
4. Emit deindex-old/index-new outbox events in the same transaction.

Normal queries use:

```sql
where status = 'ACTIVE'
```

They do not infer deprecation through reverse lookup.

### 20.4 Exact deduplication

A canonical `content_hash` covers the four immutable output fields and the output schema/canonicalization version.

- Exact normalized content hash match: reuse the existing asset and add provenance/applicability candidates.
- Merely similar content: create an independent asset variant.
- Similar variants may share a semantic cluster for ranking and duplicate-result suppression.
- Vector similarity never automatically merges assets.

## 21. Applicability

Content deduplication does not automatically expand where a phrase may be used.

Each new context is an independent applicability candidate:

```text
approved_output_applicabilities
- approved_output_id
- generic_scene_intent
- care_action
- action_phase
- reaction
- parent_goal
- age_range
- context_tags
- status
- applicability_policy_version/hash
```

A new applicability passes:

```text
Scene Abstraction
→ deterministic compatibility check
→ structured Applicability Gate
→ application-computed verdict
```

The same immutable phrase can have multiple separately approved applicability rows. No source scene, age, reaction, or action phase is inherited merely because content hashes match.

## 22. Asset qualifications and compatibility

### 22.1 Compatibility Policy

A versioned Approved Output Compatibility Policy explicitly lists which historical profile, rubric, reuse-policy, schema, and qualification combinations may participate in current reuse.

A candidate absent from the policy fails closed and is skipped.

### 22.2 Requalification

An incompatible historical asset may undergo asynchronous requalification without generating or repairing text:

```text
existing immutable asset
→ current deterministic gate
→ current Quality Judge
→ current Reuse Eligibility Gate
→ application-computed result
```

A successful review adds a new qualification record. It does not mutate asset content.

A failed or abstained review leaves the historical asset stored but ineligible for the current reuse path. Infrastructure failure may be retried.

If content needs modification, the normal generation pipeline must produce a new asset.

## 23. Core data model

### 23.1 Private generation

```text
practice_generated_content
practice_generated_content_attempts
practice_generated_content_evidence_bundles
practice_generated_content_evidence_items
practice_generated_content_judge_results
practice_ai_operation_runs
practice_ai_provider_calls
practice_scene_abstractions
```

### 23.2 Public reuse

```text
approved_output_assets
approved_output_applicabilities
approved_output_provenances
approved_output_asset_qualifications
approved_output_reuse_events
```

### 23.3 Outbox

Key event types:

```text
PRIVATE_CONTENT_ACTIVATED
GLOBAL_ASSET_PUBLISHED
GLOBAL_ASSET_SUPERSEDED
GLOBAL_ASSET_WITHDRAWN
PROVENANCE_WITHDRAWN
PRIVATE_CONTENT_DELETED
```

Database state is authoritative. Index documents are projections.

## 24. Search projections and outbox consistency

### 24.1 Private index

Owner-private documents may contain:

```text
generated_content_id
owner scope
owner-safe canonical search representation
Scene Abstraction
active final utterance
generation profile
content hash
```

Every query requires owner scoping.

### 24.2 Global index

Global documents may contain only de-identified fields:

```text
approved_output_id
generic scene intent
care action
action phase
reaction
parent goal
age range
context tags
strategy IDs
communication primitive IDs
immutable utterance fields
qualification metadata
content hash
```

They must not contain:

```text
owner identity
raw custom scene
family memory
name/location/schedule
medical or developmental private facts
private evidence
source family profile
```

### 24.3 Hydration gate

Every search hit returns an ID only. Before use, the application rechecks:

```text
status ACTIVE
effective provenance exists
qualification is current/compatible
applicability is valid
owner/privacy boundary
Reuse Match verdict
```

A stale index document cannot authorize reuse.

### 24.4 Idempotent projection

Outbox worker idempotency uses:

```text
event_type
aggregate_type
aggregate_id
aggregate_version
```

- Publish is an upsert.
- Withdrawal is a tombstone/delete.
- A late old aggregate version cannot roll the projection backward.
- Failed events retry with controlled backoff and eventually enter an observable dead-letter state.

## 25. Quota and cost semantics

```text
private exact reuse
→ no generation quota
→ no LLM call

private/global semantic reuse success
→ no generation quota
→ record actual Abstraction/Match costs only

enter Generator or Repair pipeline
→ consume one user generation quota for the execution
```

Rules:

- Provider fallback does not charge another user generation quota.
- Repair belongs to the original execution and does not charge another quota.
- Every real provider call records actual provider cost/latency metadata.
- Burst abuse protection may apply to all incoming requests.
- Daily generation limit applies only when the request enters generation.
- Minimum-evidence failure before Generator does not consume generation quota.
- Once Generator is actually called, the execution consumes quota even if Judge or Repair later fails.

## 26. Fake and disabled modes

The fake provider remains a transitional dev/test mechanism that proves typed wiring, deterministic control flow, and persistence behavior.

It is not required to solve semantic custom-scene quality.

Rules:

- Fake is available only in dev/test profiles.
- Disabled mode fails without network or key dependency.
- Unknown provider mode fails application startup.
- Fake does not make real Judge network calls.
- Fake output is excluded from public asset publication and cross-family reuse.
- Test-only unsafe/timeout/invalid providers remain test fixtures, not production routes.

## 27. Testing strategy

### 27.1 Database and state-machine tests

Cover:

```text
DRAFT → GENERATING → ACTIVE
DRAFT/GENERATING → EXPIRED
GENERATING → REJECTED
ACTIVE private deletion
ACTIVE public asset → SUPERSEDED/WITHDRAWN
```

Assert:

- Terminal execution cannot revive.
- Retry creates a new generated-content ID.
- Live unique index prevents duplicate concurrent generation.
- One immutable evidence bundle per attempt.
- REFERENCE/SNAPSHOT constraints.
- Judge result only for a Quality Judge provider call.
- Public text immutability.
- Asset `status` is the sole current-usability authority.
- Last provenance withdrawal removes global usability.
- Unapproved applicability cannot be indexed.

### 27.2 Orchestration tests

Use deterministic fake capability adapters, never a real provider.

Cover:

```text
private exact hit
private semantic hit
global semantic hit
all candidates NO_MATCH
Match ABSTAIN
minimum evidence failure
Generator fallback
Judge fallback
Judge REPAIR
Judge ABSTAIN
Repair then PASS
attempt exhaustion
restart interruption
```

Every test asserts:

```text
final state
capabilities called and not called
quota effect
operation/provider audit
outbox events
temporary scene clearing
```

Critical negative assertions:

- Global reuse hit calls no Generator, Quality Judge, or Repair.
- Evidence failure calls no Generator and charges no generation quota.
- Reuse Eligibility failure leaves private content ACTIVE.

### 27.3 Structured capability contract tests

Each capability has strict contract tests:

```text
Scene Abstraction
Generator
Quality Judge
Repair
Reuse Match
Reuse Eligibility
Applicability
Asset Requalification
```

Cover:

- Missing/unknown fields.
- Illegal enums.
- Schema parse failure.
- Model/effective verdict conflict.
- Confidence not affecting state.
- Unknown evidence-gap code not causing retrieval.
- Controlled repair directive validation.
- No free-text reasoning persistence.

Prompt fixture tests verify only input boundaries, schema contracts, sensitive-field exclusion, and version/hash propagation. Model quality is evaluated through a separate offline evaluation set.

### 27.4 Privacy and deletion tests

Verifiers scan production DTOs and persistence/index code to ensure these cannot cross boundaries:

```text
securityText
risk signals
raw scene
owner profile
Garden Memory text
raw retrieval chunk
prompt/response body
provider exception body
```

Deletion tests cover single output, all-family-data clearing, consent withdrawal, and account deletion.

### 27.5 Outbox and search tests

Cover:

- Duplicate consumption.
- Late old aggregate version.
- Index success followed by acknowledgement failure.
- Deindex retry.
- Dead-letter handling.
- Stale index hit rejected by database hydration.
- SUPERSEDED asset never returned.

### 27.6 Concurrency tests

At minimum:

```text
two identical generation requests
two families publish same content hash
consent withdrawal races publication
last provenance withdrawal races new provenance
asset supersession races search
multiple workers compete for one outbox event
```

Correctness relies on database constraints, row locks, advisory locks, or optimistic versions—not JVM-only locks.

### 27.7 Architecture tests

Enforce:

- Controllers cannot depend on mappers.
- Only write service can depend on command mapper.
- Capability adapters cannot mutate database state.
- Provider Manager cannot depend on business-domain packages.
- Search adapters cannot directly return API DTOs.
- Public asset package cannot import owner profile or Garden Memory.
- Evidence Index DTOs and Approved Output Index DTOs cannot be reused interchangeably.
- Fake provider cannot enter production routing.

## 28. Rollout plan

Roll out in guarded stages:

### Stage 1

- Database schema.
- State/audit model.
- Prompt/policy verifiers.
- Features disabled.

### Stage 2

- Private Generation + deterministic gate + Quality Judge + Repair.
- No public publication.

### Stage 3

- Private exact reuse.
- Then owner-private semantic reuse and Scene Abstraction.

### Stage 4

- Reuse Eligibility and public asset publication.
- Global index shadow writes only.

### Stage 5

- Global shadow reads.
- Measure candidates and Match decisions without returning them.

### Stage 6

- Small-percentage global reuse.
- Gradual expansion with rollback controls.

Independent feature flags must disable:

```text
semantic reuse
global reuse
public publication
asset requalification
```

Disabling public functionality must not affect the private generation path.

## 29. Acceptance criteria

The design is correctly implemented when all of the following are true:

1. Same-owner exact hits return without any provider call.
2. Semantic approved-output hits return without Generator, full Quality Judge, or Repair.
3. New generation cannot activate without deterministic validation and an application-computed Judge PASS.
4. Repair cannot bypass evidence policy, deterministic validation, or a new Judge.
5. Every real model call is auditable without storing prompts, responses, raw errors, or private scene text.
6. Every attempt uses one immutable evidence bundle.
7. Evidence is replayable by reference or bounded sanitized snapshot.
8. Terminal generation executions are never revived.
9. Raw scenes and owner-specific data never enter the global index or Match Judge.
10. Cross-family publication requires current versioned consent and a fail-closed Reuse Eligibility result.
11. Public asset text never mutates in place.
12. Applicability never expands automatically because content hashes match.
13. Last valid provenance withdrawal removes the asset from current global use.
14. Stale indexes cannot return withdrawn, superseded, incompatible, or inapplicable assets.
15. Prompt/policy content cannot change without version changes detected by CI/startup verification.
16. Fake mode remains dev/test-only and cannot publish global assets.

## 30. Design self-review resolutions

The final design resolves the following potential ambiguities:

- **Routing snapshots:** audit metadata is retained, but executable provider configuration is not snapshotted across restarts.
- **Asset origin profile versus exact deduplication:** the asset stores the first origin profile for provenance; current validity comes from qualification and compatibility records.
- **Supersession lookup:** old rows explicitly store `status` and `superseded_by_approved_output_id`; callers do not infer deprecation through reverse queries.
- **Deletion and provenance:** provenance is withdrawn and asset state/outbox is committed before the private source relation is physically removed.
- **Content versus applicability:** exact content deduplication never grants a new scene, age, reaction, goal, or action-phase applicability.
- **Evidence versus output reuse:** approved outputs are reusable answers, not authoritative knowledge evidence.

## 31. First-scope implementation proof

The private exact-reuse scope is evidenced by the following executable checks:

- [Agentic endpoint lifecycle and negative paths](../../../backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/CustomSceneAgenticGenerationIntegrationTest.java): deterministic local provider/evidence stubs exercise `POST /api/v1/practice/discovery`, audit lineage, exact-hit zero-call reuse, bidi, evidence/quota/Judge failures, PII rejection, repair, and attempt exhaustion.
- [Schema privacy boundary](../../../backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGenerationAuditPrivacyTest.java): PostgreSQL schema assertions prove audit tables lack raw prompt/response/security fields and preserve only approved generated response metadata.
- [PostgreSQL lineage and cleanup races](../../../backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentConcurrencyTest.java): real database locks prove one exact live lineage, terminal retry freshness, and single-effect concurrent cleanup.
- [Static privacy firewall](../../../tool/verify_practice_generation_privacy.py) and [its regression tests](../../../test/tool/verify_practice_generation_privacy_test.py): production custom-scene Java/DTOs, mapper XML, and V25 schema are checked for forbidden persistence, unsafe structured-output hooks/retries, and B2.1 key/cleanup boundaries.

Owner-private semantic reuse, Scene Abstraction, global Match/Eligibility, public Approved Output Assets, and global indexing remain deferred as specified in the rollout plan.
