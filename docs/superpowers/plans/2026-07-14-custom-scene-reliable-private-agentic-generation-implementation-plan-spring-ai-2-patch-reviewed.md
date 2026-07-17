# Custom Scene Reliable Private Agentic Generation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current fake/placeholder custom-scene path with a production-capable, Unicode-safe, evidence-grounded Generator → deterministic gate → independent Judge → bounded Repair loop that persists exact private results and never activates content without an application-computed PASS.

**Architecture:** Keep `PracticeDiscoveryService` as the HTTP/domain entry point and turn `PracticeGeneratedContentService` into a small public facade over a dedicated generation orchestrator. Split query and mutation persistence, represent semantic attempts separately from real provider calls, freeze one immutable evidence bundle per attempt, and route typed Spring AI capabilities through a provider manager whose provider selection is configured in Helm/YAML. This plan implements only the approved first private-generation scope; semantic reuse, Scene Abstraction, Reuse Match, Reuse Eligibility, public Approved Output Assets, and global indexing remain separate follow-on plans.

**Tech Stack:** JDK 21 runtime/toolchain with Java 17 source and bytecode, Spring Boot 4.0.7, Spring AI 2.0.0, Spring Cloud 2025.1.2, ICU4J 76.1, MyBatis-Plus 3.5.17 Boot 4 starter, Druid 1.2.28 Boot 4 starter, Jackson 3, PostgreSQL, Flyway V25/V26, JUnit 5, Mockito, Testcontainers, Helm.

## Global Constraints

- Preserve canonical endpoint `POST /api/v1/practice/discovery`.
- Before Task 1 starts, complete `docs/superpowers/plans/2026-07-14-spring-ai-2-backend-platform-upgrade-implementation-plan-patch-reviewed.md` and pass its final Task 8 platform gate: `python3 tool/verify_spring_ai_2_backend_platform.py` plus `cd backend && bash mvnw clean test`.
- The custom-scene provider path uses stable Spring AI `2.0.0` only and must remain compatible with the repository baseline Spring Boot `4.0.7`; Spring AI 2.0 does not support the current Boot 3.4.x baseline.
- One named-provider attempt must equal one outbound model request and one provider-call audit row: custom-scene models hard-code the Spring AI 2/OpenAI SDK `maxRetries` option to `0`, do not use Spring AI `validateSchema()` auto-repair, and do not add hidden advisor/retry loops.
- Provider `temperature` is optional because reasoning models such as GPT-5 reject it; provider configuration may set exactly one of `maxTokens` or `maxCompletionTokens`, never both.
- Spring AI 2's OpenAI implementation still contains internal Jackson 2 deserialization code for the official OpenAI SDK; transitive Jackson 2 inside framework jars is allowed, but Baby Talk application code must use Jackson 3 core/databind packages after the platform prerequisite completes.
- Preserve implemented combinations `surface=onboarding` with `mode=catalog|custom_scene`.
- Implement only the approved first scope: Unicode dual text, state machine, attempts, operation/provider audit, Provider Manager, evidence bundles, Generator/Judge/Repair, versioned resources, exact private reuse, migrations, verifiers, Helm/YAML, and tests.
- Do not implement owner-private semantic reuse, Scene Abstraction, Reuse Match, Reuse Eligibility, Applicability, Global Approved Output Assets, global search, public provenance, or historical asset requalification in this plan.
- Do not modify `mobile/`, `mobile_v2/`, Garden, Growth, care-turn, Baby Profile Option Catalog, or admin UI behavior.
- `displayText` may be sent to approved capability adapters and temporarily stored only while an execution is non-terminal.
- `securityText` and request risk signals must never be persisted, returned, logged, indexed, or sent to any provider.
- Preserve emoji ZWJ (`U+200D`); reject bidi override/isolate controls; remove configured non-semantic invisibles.
- Generated output persists `tpr_action_zh` and `delivery_guidance_zh`; `coachTipZh` is composed at read time and is not a persisted column.
- Real agentic mode cannot activate without deterministic validation and an application-computed Judge PASS.
- Fake mode remains `dev`/`test` only. It validates typed orchestration through deterministic fake capability adapters and must not be treated as semantic-quality evidence.
- Every actual model call gets its own provider-call audit row. Do not store prompts, model responses, raw provider errors, raw scene text, or raw retrieval chunks in audit tables.
- Every semantic attempt uses one immutable evidence bundle. Repair uses a new bundle for the new attempt, either derived with `REUSED` evidence or rebuilt with `REFRESHED` evidence.
- Terminal generated-content rows are never revived. A retry creates a new `practice_generated_content` row.
- `OffsetDateTime` remains the Java timestamp type and all application-created values are UTC.
- V25 and V26 are immutable Flyway history. Current repository evidence proves them only in disposable Testcontainers schemas; no execution in a non-disposable environment is known. If either version has run outside disposable/Testcontainers infrastructure, every generated-content follow-up must use an additive V27+ migration. Never rewrite V25 or V26.
- The reviewed B2.1 hardening working tree must be preserved. Commit commands below assume it has first been committed or captured in an explicitly approved execution baseline; do not accidentally fold the pre-existing patch into a task commit.
- Follow TDD: each task begins with focused failing tests, implements the smallest complete behavior, runs focused tests, then runs the relevant regression set.


---

## Reviewed B2.1 Hardening Baseline

This plan is reviewed against the existing B2.1 implementation captured in
`t8.2-b2.1-custom-scene-hardening.patch`.

```text
base commit: d8960d1c9a68c2dd666cf697b047c0faa367a789
patch SHA-256: e7e6c40fee445ba49eb24d82ad3b9b88ba62cf61d79771ec5d8d69ea5205b2e4
patch size: 579587 bytes
```

The patch already supplies the production endpoint and a substantial private
registry baseline: `PracticeDiscoveryService`, the typed
`CustomSceneGenerationService` boundary, disabled/fake/agentic-placeholder
wiring, NFKC canonicalization, owner-scoped HMAC fingerprints, explicit
generated-content mapper operations, atomic `REQUIRES_NEW` reservation and
rate limiting, retention cleanup, V25, and PostgreSQL concurrency coverage.

Execution rules:

1. On the development computer, do **not** apply this patch again when its
   changes are already present.
2. Before Task 1, either commit the B2.1 hardening as its own reviewed baseline
   or create an isolated worktree from a commit that contains exactly those
   changes. Later task commits must not absorb the pre-existing 79-file diff.
3. Verify the baseline with `git apply --check` only in a clean reconstruction
   of base commit `d8960d1c...`; on the active development tree, verify by
   comparing `git diff --binary` and the recorded patch hash.
4. All commands in this plan are repository-root relative. Do not replace them
   with paths from the machine that authored this document.
5. Copy the approved spec and this patch-reviewed plan into
   `docs/superpowers/specs/` and `docs/superpowers/plans/` on the development
   computer before implementation begins.

## B2.1 Contracts That Must Survive the Agentic Rewrite

- Preserve `POST /api/v1/practice/discovery` and the existing response envelope,
  including scene/moment/starter identifiers and generated `spaceSlug`,
  `activitySlug`, `phraseSlug`, `spaceTitleZh`, `activityTitleZh`, and
  `sceneTagEn`.
- Preserve owner-scoped, domain-separated HMAC keys and fingerprints.
- Current-key lookup and rate accounting remain owner-key-version bound.
- Stale execution cleanup, installation-retention deletion, and account privacy
  deletion continue to work across historical owner-key versions.
- Preserve atomic owner locking, live-lineage recheck, and burst reservation.
  Provider calls remain outside the reservation transaction.
- Safe unlisted family-care scenes remain eligible. Deterministic scene intent
  classification is a retrieval/alignment hint, never an admission allow-list.
- Disabled mode fails before auth, profile lookup, HMAC, reservation, or provider
  work. Fake mode remains dev/test-only.
- Preserve the existing catalog/profile/controller package migration and all
  corresponding regression tests.
- V25 and V26 must never be rewritten. If either has run outside a disposable
  Testcontainers schema, generated-content follow-up work starts at additive V27+.

## File Structure

### Existing files to modify

- `backend/pom.xml`
  - Add the managed ICU4J version property.
- `backend/app-api/pom.xml`
  - Add ICU4J and Jackson 3 YAML dependencies.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/SceneTextCanonicalizer.java`
  - Produce `displayText`, `securityText`, and ephemeral risk signals using ICU4J.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/PolicyTextMatcher.java`
  - Match only approved security forms and high-risk confusable skeletons.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneGenerationService.java`
  - Delete after migrating callers to the focused `CustomSceneGenerator` port.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/DisabledCustomSceneGenerationService.java`
  - Migrate disabled mode to the focused Generator port.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneGeneratedContentValidator.java`
  - Become a deterministic gate that distinguishes terminal and repairable violations.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/FakeCustomSceneGenerationService.java`
  - Emit the new typed contract only.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/PracticeDiscoveryCustomSceneProperties.java`
  - Add bounded semantic-attempt configuration and remove the single prompt/provider-mode coupling.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/PracticeDiscoveryService.java`
  - Compose `coachTipZh` at read time from the two internal guidance fields.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentService.java`
  - Shrink to a facade for input preparation, exact reuse, orchestration, reads, and cleanup.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentKeyFactory.java`
  - Preserve owner-scoped/domain-separated HMAC behavior while replacing old fingerprint material with security text and Generation Profile lineage.
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentKeyFactoryTest.java`
  - Prove canonical-equivalent reuse, cross-owner isolation, profile-version separation, and absence of display text in fingerprint material.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/model/PracticeGeneratedContentEntity.java`
  - Map the approved lineage, state, retryability, attempt-limit, and split guidance fields.
- `backend/app-api/src/main/resources/application.yml`
  - Import versioned AI resources and bind provider/capability configuration.
- `backend/app-api/src/main/resources/config/practice-discovery-policy.yml`
  - Retain only deterministic input/output hard-safety rules; semantic quality moves to the Judge rubric.
- `backend/db-migration/src/main/resources/db/migration/V25__create_practice_generated_content.sql`
  - Replace the draft registry schema with the complete private-generation schema.
- `backend/db-migration/src/test/java/com/zhangspaghetti/babytalk/migration/DbMigrationSmokeTest.java`
  - Assert tables, constraints, indexes, and terminal-data invariants.
- `deploy/helm/babytalk-app/templates/configmap.yaml`
- `deploy/helm/babytalk-app/templates/deployment.yaml`
- `deploy/helm/babytalk-app/templates/secret.yaml`
- `deploy/helm/babytalk-app/values.yaml`
- `deploy/helm/babytalk-app/values-kind.yaml`
- `deploy/helm/babytalk-app/values-kind-qa.yaml`
- `deploy/helm/babytalk-app/values-production.yaml`

### New focused production components

- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/SceneTextForms.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/SceneTextRiskSignals.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/SceneTextSecurityPolicy.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/PracticeAiCapability.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/PracticeAiProperties.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/PracticeAiProviderManager.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/PracticeAiChatClientFactory.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/PracticeAiOperationRunner.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/PracticeAiCallFailureClassifier.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/ResolvedProvider.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/OperationRequest.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/OperationResult.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/config/VersionedResourceRegistry.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/config/GenerationProfile.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/config/VersionedRef.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/config/QualityRubric.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/config/MinimumEvidencePolicy.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/CustomSceneGenerationOrchestrator.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/CustomSceneGenerator.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/CustomSceneQualityJudge.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/CustomSceneRepairer.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/AgenticCustomSceneGenerator.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/AgenticCustomSceneQualityJudge.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/AgenticCustomSceneRepairer.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/FakeCustomSceneQualityJudge.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/FakeCustomSceneRepairer.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/evidence/CustomSceneEvidenceRetriever.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/evidence/CompositeCustomSceneEvidenceRetriever.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/evidence/PalaceCustomSceneEvidenceSource.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/evidence/BaselineFamilyEnglishEvidenceSource.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/evidence/EvidenceSanitizer.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/evidence/EvidenceBundleFactory.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/evidence/EvidenceItem.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/evidence/EvidenceSummary.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/evidence/EvidenceRetrievalRequest.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/evidence/EvidenceRetrievalResult.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/evidence/FrozenEvidenceBundle.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/evidence/ReplayMode.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/evidence/RetrievalStatus.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/quality/GeneratedOutputGateResult.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/quality/GeneratedOutputViolationCode.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/quality/JudgeVerdictCalculator.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/quality/JudgeDimension.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/quality/DimensionResult.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/quality/JudgeVerdict.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/quality/SuggestedJudgeResult.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/quality/EffectiveJudgeResult.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/quality/RepairDirective.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/quality/EvidenceGapCode.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/quality/TypedRepairPackage.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentQueryMapper.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/DraftReservation.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/ReservationPolicy.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/GenerationStartDecision.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentCommands.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/internal/PracticeGeneratedContentCommandMapper.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/internal/PracticeGeneratedContentWriteService.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/internal/PracticeGenerationAuditMapper.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/model/PracticeGenerationAttemptEntity.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/model/PracticeAiOperationRunEntity.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/model/PracticeAiProviderCallEntity.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/model/PracticeEvidenceBundleEntity.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/model/PracticeEvidenceItemEntity.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/model/PracticeJudgeResultEntity.java`

### New versioned resources and verifiers

- `backend/app-api/src/main/resources/config/practice-ai/prompts/custom-scene-generator-v1.txt`
- `backend/app-api/src/main/resources/config/practice-ai/prompts/custom-scene-quality-judge-v1.txt`
- `backend/app-api/src/main/resources/config/practice-ai/prompts/custom-scene-repair-v1.txt`
- `backend/app-api/src/main/resources/config/practice-ai/rubrics/custom-scene-quality-v1.yml`
- `backend/app-api/src/main/resources/config/practice-ai/policies/custom-scene-evidence-v1.yml`
- `backend/app-api/src/main/resources/config/practice-ai/evidence/family-english-baseline-v1.yml`
- `backend/app-api/src/main/resources/config/practice-ai/profiles/custom-scene-generation-v1.yml`
- `backend/app-api/src/main/resources/config/practice-ai/version-lock.yml`
- `tool/verify_practice_ai_version_lock.py`
- `.github/workflows/practice-ai-version-lock.yml`

---

### Task 1: Evolve the existing NFKC canonicalizer into ICU4J dual text forms and a fail-closed input security gate

**Files:**
- Modify: `backend/pom.xml`
- Modify: `backend/app-api/pom.xml`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/SceneTextCanonicalizer.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/PolicyTextMatcher.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/SceneTextForms.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/SceneTextRiskSignals.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/SceneTextSecurityPolicy.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentService.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentKeyFactory.java`
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentKeyFactoryTest.java`
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/SceneTextCanonicalizerTest.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/SceneTextSecurityPolicyTest.java`
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentServiceTest.java`

**Interfaces:**
- Produces: `SceneTextForms SceneTextCanonicalizer.derive(String rawText)`.
- Produces: `void SceneTextSecurityPolicy.requireSafe(SceneTextForms forms)`.
- Preserves: `String SceneTextCanonicalizer.canonicalize(String value)` as a compatibility delegate to `derive(value).displayText()` until all callers migrate.
- Consumed by: Task 4 fingerprinting and Task 10 orchestration.

The existing `SceneTextCanonicalizerTest` cases for Unicode whitespace,
compatibility characters, grapheme length, database code-point length, and emoji
ZWJ are regression contracts. Extend them; do not replace them.

The current `unsupportedIntents` keyword path must be narrowed during this task:
PII, prompt injection, bidi controls, adult/violent content, and dangerous
medical/legal directives remain deterministic hard gates, but ordinary
unlisted care scenes may not be rejected merely because they are absent from
`sceneIntents`. Deterministic intent classification is only a
retrieval/alignment hint. Input security rejection uses HTTP 422; ordinary
unsupported product modes retain their existing contract.

- [ ] **Step 1: Add ICU4J and YAML parser dependencies**

Add to `backend/pom.xml` properties:

```xml
<icu4j.version>76.1</icu4j.version>
```

Add to `backend/app-api/pom.xml`:

```xml
<dependency>
    <groupId>com.ibm.icu</groupId>
    <artifactId>icu4j</artifactId>
    <version>${icu4j.version}</version>
</dependency>
<dependency>
    <groupId>tools.jackson.dataformat</groupId>
    <artifactId>jackson-dataformat-yaml</artifactId>
</dependency>
```

- [ ] **Step 2: Write failing tests for display/security separation and character handling**

Add these cases to `SceneTextCanonicalizerTest`:

```java
@Test
void derivesReadableDisplayAndNfkcCasefoldSecurityText() {
    var forms = canonicalizer.derive("  ＷｅＣｈａｔ\uFEFF  宝宝  ");

    assertThat(forms.displayText()).isEqualTo("WeChat 宝宝");
    assertThat(forms.securityText()).isEqualTo("wechat 宝宝");
    assertThat(forms.riskSignals().removedInvisible()).isTrue();
}

@Test
void preservesEmojiZwjButRejectsBidiOverrideAndIsolateSignals() {
    var emoji = canonicalizer.derive("爸爸👨‍👩‍👧‍👦抱抱宝宝");
    assertThat(emoji.displayText()).contains("👨‍👩‍👧‍👦");
    assertThat(emoji.riskSignals().bidiControlPresent()).isFalse();

    assertThat(canonicalizer.derive("宝宝\u202Eabc").riskSignals().bidiControlPresent()).isTrue();
    assertThat(canonicalizer.derive("宝宝\u2066abc\u2069").riskSignals().bidiControlPresent()).isTrue();
}

@Test
void reportsMixedDigitSystemsOnlyWhenTheyFormOneSensitiveRun() {
    assertThat(canonicalizer.derive("第２次洗澡").riskSignals().mixedDigitSystems()).isFalse();
    assertThat(canonicalizer.derive("电话１２345678901").riskSignals().mixedDigitSystems()).isTrue();
    assertThat(canonicalizer.derive("电话１２345678901").riskSignals().longDigitRun()).isTrue();
}
```

Create `SceneTextSecurityPolicyTest` with cases proving bidi returns `unsafe_custom_scene_text`, full-width/confusable PII markers are caught, ordinary Chinese-English mixing is accepted, and `securityText` is never present in the thrown `ContractException.details()`.

- [ ] **Step 3: Run the focused tests and verify failure**

Run:

```bash
cd "$(git rev-parse --show-toplevel)/backend"
bash mvnw -pl app-api -Dtest=SceneTextCanonicalizerTest,SceneTextSecurityPolicyTest,PracticeGeneratedContentServiceTest test
```

Expected: compilation failures for missing `derive`, `SceneTextForms`, `SceneTextRiskSignals`, and `SceneTextSecurityPolicy`.

- [ ] **Step 4: Add immutable text-form records**

Create `SceneTextForms.java`:

```java
package com.zhangspaghetti.babytalk.practice.discovery;

public record SceneTextForms(
        String displayText,
        String securityText,
        SceneTextRiskSignals riskSignals
) {
}
```

Create `SceneTextRiskSignals.java`:

```java
package com.zhangspaghetti.babytalk.practice.discovery;

public record SceneTextRiskSignals(
        boolean bidiControlPresent,
        boolean removedInvisible,
        boolean mixedDigitSystems,
        boolean longDigitRun
) {
}
```

- [ ] **Step 5: Replace JDK-only canonicalization with ICU4J**

Implement `SceneTextCanonicalizer` with these constants and public methods:

```java
private static final Normalizer2 DISPLAY_NORMALIZER = Normalizer2.getNFKCInstance();
private static final Normalizer2 SECURITY_NORMALIZER = Normalizer2.getNFKCCasefoldInstance();
private static final Pattern WHITESPACE = Pattern.compile("[\\p{Z}\\s]+", Pattern.UNICODE_CHARACTER_CLASS);
private static final Set<Integer> BIDI_CONTROLS = Set.of(
        0x202A, 0x202B, 0x202C, 0x202D, 0x202E,
        0x2066, 0x2067, 0x2068, 0x2069);
private static final Set<Integer> REMOVABLE_INVISIBLES = Set.of(
        0x200B, 0x200C, 0x2060, 0xFEFF);
```

The implementation must scan code points before normalization, preserve `0x200D`, remove only `REMOVABLE_INVISIBLES`, collapse Unicode whitespace, and return `null` display/security text for an empty result. Detect a mixed digit run by tracking `Character.UnicodeBlock` for consecutive decimal digits; only set `mixedDigitSystems=true` when a single run of at least seven digits uses more than one block. Set `longDigitRun=true` for a consecutive decimal-digit run of at least seven code points.

Keep:

```java
public String canonicalize(String value) {
    return derive(value).displayText();
}
```

- [ ] **Step 6: Implement high-risk security matching without persisting skeletons**

Create `SceneTextSecurityPolicy` with constructor dependencies on `PracticeDiscoveryPolicyProperties`, `PolicyTextMatcher`, and a configured ICU4J `SpoofChecker`. Its only public method is:

```java
public void requireSafe(SceneTextForms forms)
```

Rules:

```java
if (forms.riskSignals().bidiControlPresent()) {
    throw unsafe("bidi_control");
}
if (phoneOrEmailOrNameMatches(forms.securityText())) {
    throw unsafe("pii");
}
if (forms.riskSignals().mixedDigitSystems() && forms.riskSignals().longDigitRun()) {
    throw unsafe("mixed_number_system_pii");
}
if (highRiskMarkerMatches(forms.securityText())
        || highRiskMarkerMatches(spoofChecker.getSkeleton(forms.securityText()))) {
    throw unsafe("high_risk_marker");
}
```

`unsafe(...)` must return the existing HTTP 422 contract without including raw text, security text, skeleton, or marker values.

- [ ] **Step 7: Use display text for providers and security text only for fingerprint/safety**

In `PracticeGeneratedContentService.generateCustomScene(...)`:

```java
var forms = sceneTextCanonicalizer.derive(request.customSceneText());
sceneTextSecurityPolicy.requireSafe(forms);
validateDisplayLength(forms.displayText());
var requestFingerprint = fingerprint(request, owner, forms.securityText());
```

Only `forms.displayText()` may be assigned to `normalized_scene_text` or passed to later domain/capability requests. Do not add `SceneTextForms` or `securityText` to any entity, mapper, audit DTO, log argument, or exception details.

Update `PracticeGeneratedContentKeyFactory.RequestFingerprintMaterial` in the
same task. Preserve its owner-scoped, domain-separated HMAC implementation, but
replace `canonicalSceneText`, `promptVersion`, `strategyVersion`, and
`policyVersion` with:

```java
String securitySceneText,
String generationProfileVersion,
String rubricVersion,
String evidencePolicyVersion,
int contentRefreshEpoch
```

The fingerprint must not contain or hash `displayText`. Existing cross-owner
isolation tests remain mandatory.

- [ ] **Step 8: Run focused and regression tests**

Run:

```bash
cd "$(git rev-parse --show-toplevel)/backend"
bash mvnw -pl app-api -Dtest=SceneTextCanonicalizerTest,SceneTextSecurityPolicyTest,PolicyTextMatcherTest,PracticeGeneratedContentServiceTest test
```

Expected: all selected tests pass.

- [ ] **Step 9: Commit the text-security slice**

```bash
git add backend/pom.xml backend/app-api/pom.xml \
  backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery \
  backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentService.java \
  backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery \
  backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentServiceTest.java
git commit -m "feat: harden custom scene unicode input"
```

---

### Task 2: Add versioned prompts, rubric, evidence policy, and Generation Profile verification

**Files:**
- Create: `backend/app-api/src/main/resources/config/practice-ai/prompts/custom-scene-generator-v1.txt`
- Create: `backend/app-api/src/main/resources/config/practice-ai/prompts/custom-scene-quality-judge-v1.txt`
- Create: `backend/app-api/src/main/resources/config/practice-ai/prompts/custom-scene-repair-v1.txt`
- Create: `backend/app-api/src/main/resources/config/practice-ai/rubrics/custom-scene-quality-v1.yml`
- Create: `backend/app-api/src/main/resources/config/practice-ai/policies/custom-scene-evidence-v1.yml`
- Create: `backend/app-api/src/main/resources/config/practice-ai/evidence/family-english-baseline-v1.yml`
- Create: `backend/app-api/src/main/resources/config/practice-ai/profiles/custom-scene-generation-v1.yml`
- Create: `backend/app-api/src/main/resources/config/practice-ai/version-lock.yml`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/config/VersionedResourceRegistry.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/config/GenerationProfile.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/config/VersionedRef.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/config/QualityRubric.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/config/MinimumEvidencePolicy.java`
- Modify: `backend/app-api/src/main/resources/application.yml`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/agentic/config/VersionedResourceRegistryTest.java`
- Create: `tool/verify_practice_ai_version_lock.py`
- Create: `.github/workflows/practice-ai-version-lock.yml`

**Interfaces:**
- Produces: `GenerationProfile VersionedResourceRegistry.currentGenerationProfile()`.
- Produces: `QualityRubric VersionedResourceRegistry.qualityRubric()`.
- Produces: `MinimumEvidencePolicy VersionedResourceRegistry.minimumEvidencePolicy()`.
- Produces: `String VersionedResourceRegistry.promptText(PromptKind kind)`.
- Consumed by: Tasks 5–10.

- [ ] **Step 1: Write failing registry tests**

Cover:

```java
@Test
void loadsProfileAndComputesStableCanonicalHashes() {
    var profile = registry.currentGenerationProfile();
    assertThat(profile.version()).isEqualTo("custom-scene-generation-v1");
    assertThat(profile.contentHash()).matches("[0-9a-f]{64}");
    assertThat(profile.rubricVersion()).isEqualTo("custom-scene-quality-v1");
    assertThat(profile.evidencePolicyVersion()).isEqualTo("custom-scene-evidence-v1");
}

@Test
void refusesResourceWhoseDeclaredVersionDoesNotMatchItsReferencedFile() {
    assertThatThrownBy(() -> registryFor("fixtures/profile-version-mismatch.yml"))
            .isInstanceOf(IllegalStateException.class)
            .hasMessageContaining("version mismatch");
}

@Test
void refusesMissingDimensionOrUnknownVerdictPolicyKey() {
    assertThatThrownBy(() -> registryFor("fixtures/rubric-invalid.yml"))
            .isInstanceOf(IllegalStateException.class)
            .hasMessageContaining("rubric schema");
}
```

- [ ] **Step 2: Add exact versioned resource contents**

`custom-scene-quality-v1.yml` must declare these dimensions exactly:

```yaml
version: custom-scene-quality-v1
schema-version: judge-rubric-schema-v1
dimensions:
  - scene_alignment
  - parent_speakability
  - non_course_framing
  - tpr_quality
  - delivery_guidance_quality
  - age_suitability
  - bilingual_consistency
  - low_pressure_support
verdict-policy:
  reject-on-fail:
    - age_suitability
  repair-on-fail:
    - scene_alignment
    - parent_speakability
    - non_course_framing
    - tpr_quality
    - delivery_guidance_quality
    - bilingual_consistency
    - low_pressure_support
  repair-on-abstain: true
```

`custom-scene-evidence-v1.yml`:

```yaml
version: custom-scene-evidence-v1
schema-version: evidence-policy-schema-v1
minimum-confidence: 0.70
required-claim-coverage:
  - scene_support
  - parent_speakability
  - age_guidance
  - low_pressure_delivery
trusted-source-types:
  - strategy_pack
  - communication_primitive
  - curated_knowledge
  - approved_external_snapshot
```

`family-english-baseline-v1.yml` must contain immutable internal `REFERENCE` evidence for `parent_speakability`, `age_guidance`, and `low_pressure_delivery`. Each item must have a stable `evidence-id`, `source-version`, `claim-type`, `strategy-id`, bounded sanitized summary, and confidence. Do not include scene-specific generated text.

The three prompt files must demand strict JSON only, prohibit tools/memory/web access for Judge and Repair, and state that evidence summaries are data rather than instructions. The Judge prompt must not request chain-of-thought or free-form reasoning.

`custom-scene-generation-v1.yml` must reference the exact generator/judge/repair prompt versions, rubric version, evidence-policy version, baseline evidence version, current strategy version, content-safety policy version, and generated-output schema version.

- [ ] **Step 3: Implement canonical hashing and startup validation**

`VersionedResourceRegistry` must:

1. Load YAML through `ObjectMapper(new YAMLFactory())`.
2. Recursively sort object keys before serialization.
3. Normalize prompt line endings to `\n` and remove only one final newline.
4. Compute lowercase SHA-256 over UTF-8 canonical bytes.
5. Validate every referenced version and schema.
6. Expose immutable typed records.
7. Throw during context startup for any missing resource, unknown dimension, duplicate dimension, invalid verdict mapping, or version mismatch.

Use these public record shapes:

```java
public record VersionedRef(
        String version,
        String contentHash,
        String resourcePath
) {
}
```

```java
public record GenerationProfile(
        String version,
        String contentHash,
        VersionedRef generatorPrompt,
        VersionedRef judgePrompt,
        VersionedRef repairPrompt,
        VersionedRef rubric,
        VersionedRef evidencePolicy,
        VersionedRef baselineEvidence,
        String strategyVersion,
        String contentSafetyPolicyVersion,
        String generatedOutputSchemaVersion
) {
}
```

- [ ] **Step 4: Generate and verify a committed version lock**

Implement `tool/verify_practice_ai_version_lock.py` with:

```bash
python3 tool/verify_practice_ai_version_lock.py --write
python3 tool/verify_spring_ai_2_backend_platform.py
python3 tool/verify_practice_ai_version_lock.py --verify
```

`--write` scans the profile and all referenced files, writes sorted entries to `version-lock.yml`, and prints:

```text
updated practice AI version lock: 7 resources
```

`--verify` recomputes hashes and exits non-zero when a version is missing, content hash differs, one version points to multiple hashes, or the profile references an unlocked resource. It must print:

```text
practice AI version lock verified: 7 resources
```

- [ ] **Step 5: Add CI verification against the pull-request base**

Create `.github/workflows/practice-ai-version-lock.yml` that checks out full history, runs `--verify`, loads the base branch's lock file, and fails when an existing version's hash changes instead of adding a new version. The workflow must not require provider secrets.

- [ ] **Step 6: Run focused tests and verifier**

```bash
cd "$(git rev-parse --show-toplevel)/backend"
bash mvnw -pl app-api -Dtest=VersionedResourceRegistryTest test
cd "$(git rev-parse --show-toplevel)"
python3 tool/verify_spring_ai_2_backend_platform.py
python3 tool/verify_practice_ai_version_lock.py --verify
```

Expected: registry tests pass and verifier reports seven resources.

- [ ] **Step 7: Commit versioned resource infrastructure**

```bash
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/config \
  backend/app-api/src/main/resources/config/practice-ai \
  backend/app-api/src/main/resources/application.yml \
  backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/agentic/config \
  tool/verify_practice_ai_version_lock.py .github/workflows/practice-ai-version-lock.yml
git commit -m "feat: version custom scene AI resources"
```

---

### Task 3: Rewrite V25 for terminal-safe generation, attempt, provider-call, evidence, and Judge audit

**Files:**
- Modify: `backend/db-migration/src/main/resources/db/migration/V25__create_practice_generated_content.sql`
- Modify: `backend/db-migration/src/test/java/com/zhangspaghetti/babytalk/migration/DbMigrationSmokeTest.java`

**Interfaces:**
- Produces the database contracts consumed by Tasks 4–11.
- Does not introduce any public-reuse tables from the follow-on design.

This task evolves the reviewed V25 rather than replacing its product/API
contract. Explicitly retain these generated response columns and mapper
properties:

```text
space_slug
activity_slug
phrase_slug
space_title_zh
activity_title_zh
scene_tag_en
english_text
chinese_text
pronunciation_hint
difficulty
generation_source
content_version
```

Remove only persisted `coach_tip_zh`, replacing it with `tpr_action_zh` and
`delivery_guidance_zh`.

The private generation table deliberately drops the temporary B2.1
`promoted` status and `global_candidate` owner scope. Public promotion/reuse is
owned by the later Approved Output Asset subsystem. Update constraints, SQL,
mapper methods, fixtures, and tests together; no runtime branch may continue to
treat `promoted` as reusable.

Retain or restate all B2.1 invariants: profile-owner foreign key, owner-shape
checks, installation retention checks, slug uniqueness, active output
completeness, success/error exclusivity, positive content version, current-key
live lookup/rate indexes, cross-version stale cleanup, cross-version
installation deletion, and cross-version account deletion.

State-shape constraints are explicit:

```text
draft      -> display text present; started_at null; expires_at present
generating -> display text present; started_at present
active     -> display text cleared; response + split guidance complete; error null
rejected   -> display text cleared; error and retryable present
expired    -> display text cleared; error and retryable present
```

- [ ] **Step 1: Add failing migration smoke assertions**

Add assertions for these tables:

```text
practice_generated_content
practice_generated_content_attempts
practice_ai_operation_runs
practice_ai_provider_calls
practice_generated_content_evidence_bundles
practice_generated_content_evidence_items
practice_generated_content_judge_results
```

Add negative SQL tests proving:

- `generation_attempt_limit` rejects `0` and `6`.
- active/rejected/expired rows reject non-null `normalized_scene_text`.
- active rows require `tpr_action_zh` and `delivery_guidance_zh`.
- `coach_tip_zh` no longer exists.
- a second evidence bundle for the same `(generated_content_id, attempt_number)` is rejected.
- `REFERENCE` requires `source_version` and forbids snapshot text.
- `SNAPSHOT` requires bounded snapshot text.
- a Judge result cannot exist without a provider call.
- terminal statuses cannot be changed back to `draft` or `generating` by the command SQL used in Task 4.

- [ ] **Step 2: Replace the parent table shape**

Keep owner/account/profile constraints from the reviewed V25, but replace output and lineage columns with:

```sql
tpr_action_zh varchar(240) null,
delivery_guidance_zh varchar(240) null,
english_text varchar(120) null,
chinese_text varchar(120) null,
pronunciation_hint varchar(120) null,
difficulty varchar(16) null,
generation_source varchar(32) null,
status varchar(24) not null,
generation_profile_version varchar(64) not null,
generation_profile_hash char(64) not null,
rubric_version varchar(64) not null,
rubric_content_hash char(64) not null,
evidence_policy_version varchar(64) not null,
evidence_policy_content_hash char(64) not null,
provider_routing_policy_version varchar(64) not null,
provider_routing_policy_hash char(64) not null,
generation_attempt_limit smallint not null,
content_refresh_epoch integer not null default 1,
generation_error_code varchar(64) null,
generation_error_retryable boolean null,
generation_started_at timestamp with time zone null,
generation_expires_at timestamp with time zone null,
retention_expires_at timestamp with time zone null
```

Statuses are exactly:

```sql
check (status in ('draft', 'generating', 'active', 'rejected', 'expired'))
```

`active`, `rejected`, and `expired` are terminal. `active` requires all response fields and clears error fields; `rejected` and `expired` require an error code and retryability value. `generation_attempt_limit` is constrained to `between 1 and 5`.

- [ ] **Step 3: Add attempt and AI-call audit tables**

Use these primary keys and uniqueness rules:

```sql
create table practice_generated_content_attempts (
    attempt_id uuid primary key,
    generated_content_id varchar(64) not null references practice_generated_content(generated_content_id) on delete cascade,
    attempt_number smallint not null,
    attempt_type varchar(16) not null check (attempt_type in ('generator', 'repair')),
    status varchar(16) not null check (status in ('started', 'completed', 'interrupted')),
    outcome varchar(32) null,
    violation_codes text[] not null default '{}',
    started_at timestamp with time zone not null,
    completed_at timestamp with time zone null,
    unique (generated_content_id, attempt_number),
    check (attempt_number between 1 and 5)
);
```

```sql
create table practice_ai_operation_runs (
    operation_run_id uuid primary key,
    operation_type varchar(32) not null check (operation_type in ('generator', 'quality_judge', 'repair')),
    subject_type varchar(32) not null check (subject_type = 'generated_content'),
    subject_id varchar(64) not null,
    generated_content_id varchar(64) not null references practice_generated_content(generated_content_id) on delete cascade,
    attempt_number smallint not null,
    evidence_bundle_id uuid null,
    capability_name varchar(64) not null,
    prompt_version varchar(64) not null,
    prompt_content_hash char(64) not null,
    policy_version varchar(64) null,
    policy_content_hash char(64) null,
    status varchar(16) not null check (status in ('started', 'completed', 'interrupted')),
    outcome varchar(32) null,
    started_at timestamp with time zone not null,
    completed_at timestamp with time zone null
);
```

```sql
create table practice_ai_provider_calls (
    provider_call_id uuid primary key,
    operation_run_id uuid not null references practice_ai_operation_runs(operation_run_id) on delete cascade,
    provider_name varchar(64) not null,
    provider_type varchar(32) not null,
    model_name varchar(96) not null,
    fallback_index smallint not null,
    attempt_trace_id uuid not null unique,
    provider_trace_id varchar(128) null,
    routing_policy_version varchar(64) not null,
    routing_policy_hash char(64) not null,
    outcome varchar(32) not null,
    latency_ms bigint null,
    started_at timestamp with time zone not null,
    completed_at timestamp with time zone null,
    unique (operation_run_id, provider_name)
);
```

Do not add prompt, response, raw error, scene, or evidence text columns to these tables.

- [ ] **Step 4: Add immutable evidence bundle tables**

```sql
create table practice_generated_content_evidence_bundles (
    evidence_bundle_id uuid primary key,
    generated_content_id varchar(64) not null references practice_generated_content(generated_content_id) on delete cascade,
    attempt_number smallint not null,
    derived_from_bundle_id uuid null references practice_generated_content_evidence_bundles(evidence_bundle_id),
    retrieval_outcome varchar(16) not null check (retrieval_outcome in ('initial', 'reused', 'refreshed')),
    retrieval_trace_id uuid null,
    evidence_policy_version varchar(64) not null,
    evidence_policy_content_hash char(64) not null,
    sanitizer_version varchar(64) not null,
    bundle_hash char(64) not null,
    evidence_count integer not null check (evidence_count >= 0),
    created_at timestamp with time zone not null,
    unique (generated_content_id, attempt_number)
);
```

```sql
create table practice_generated_content_evidence_items (
    evidence_bundle_id uuid not null references practice_generated_content_evidence_bundles(evidence_bundle_id) on delete cascade,
    evidence_ordinal integer not null,
    replay_mode varchar(16) not null check (replay_mode in ('reference', 'snapshot')),
    evidence_id varchar(128) not null,
    source_type varchar(48) not null,
    source_version varchar(64) null,
    strategy_id varchar(96) null,
    claim_type varchar(48) not null,
    sanitizer_version varchar(64) not null,
    sanitized_summary_hash char(64) not null,
    sanitized_summary_snapshot varchar(320) null,
    confidence numeric(5,4) not null check (confidence between 0 and 1),
    created_at timestamp with time zone not null,
    primary key (evidence_bundle_id, evidence_ordinal),
    check (
        (replay_mode = 'reference' and source_version is not null and sanitized_summary_snapshot is null)
        or
        (replay_mode = 'snapshot' and sanitized_summary_snapshot is not null)
    )
);
```

Add the foreign key from `practice_ai_operation_runs.evidence_bundle_id` after both tables exist.

- [ ] **Step 5: Add structured Judge results**

```sql
create table practice_generated_content_judge_results (
    judge_result_id uuid primary key,
    provider_call_id uuid not null unique references practice_ai_provider_calls(provider_call_id) on delete cascade,
    suggested_verdict varchar(16) not null check (suggested_verdict in ('pass', 'repair', 'reject', 'abstain')),
    effective_verdict varchar(16) not null check (effective_verdict in ('pass', 'repair', 'reject', 'abstain')),
    verdict_consistency varchar(16) not null check (verdict_consistency in ('consistent', 'inconsistent')),
    dimension_results jsonb not null check (jsonb_typeof(dimension_results) = 'object'),
    violation_codes text[] not null default '{}',
    repair_directives text[] not null default '{}',
    evidence_gap_codes text[] not null default '{}',
    judge_confidence numeric(5,4) null check (judge_confidence is null or judge_confidence between 0 and 1),
    rubric_version varchar(64) not null,
    rubric_content_hash char(64) not null,
    created_at timestamp with time zone not null
);
```

- [ ] **Step 6: Update the live lineage index**

The partial unique index must cover only live rows and use the new profile lineage:

```sql
create unique index uq_practice_generated_content_live_fingerprint
    on practice_generated_content(
        owner_key,
        owner_key_version,
        surface,
        mode,
        request_fingerprint,
        generation_profile_version,
        content_refresh_epoch
    )
    where status in ('draft', 'generating', 'active');
```

Terminal `rejected` and `expired` rows must not block a new execution.

- [ ] **Step 7: Run migration tests**

```bash
cd "$(git rev-parse --show-toplevel)/backend"
bash mvnw -pl db-migration -Dtest=DbMigrationSmokeTest test
```

Expected: migration applies from an empty PostgreSQL database and all new schema/constraint tests pass.

- [ ] **Step 8: Commit the schema**

```bash
git add backend/db-migration/src/main/resources/db/migration/V25__create_practice_generated_content.sql \
  backend/db-migration/src/test/java/com/zhangspaghetti/babytalk/migration/DbMigrationSmokeTest.java
git commit -m "feat: add custom scene generation audit schema"
```

---

### Task 4: Split query and command persistence and enforce the state-machine write boundary

**Files:**
- Delete: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentMapper.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentQueryMapper.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentCommands.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/DraftReservation.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/ReservationPolicy.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/GenerationStartDecision.java`
- Delete: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentWriteService.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/internal/PracticeGeneratedContentCommandMapper.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/internal/PracticeGeneratedContentWriteService.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/internal/PracticeGenerationAuditMapper.java`
- Delete: `backend/app-api/src/main/resources/mapper/practice/generated/PracticeGeneratedContentMapper.xml`
- Create: `backend/app-api/src/main/resources/mapper/practice/generated/PracticeGeneratedContentQueryMapper.xml`
- Create: `backend/app-api/src/main/resources/mapper/practice/generated/internal/PracticeGeneratedContentCommandMapper.xml`
- Create: `backend/app-api/src/main/resources/mapper/practice/generated/internal/PracticeGenerationAuditMapper.xml`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/model/PracticeGeneratedContentEntity.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/model/PracticeGenerationAttemptEntity.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/model/PracticeAiOperationRunEntity.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/model/PracticeAiProviderCallEntity.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/model/PracticeEvidenceBundleEntity.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/model/PracticeEvidenceItemEntity.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/model/PracticeJudgeResultEntity.java`
- Replace: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentMapperContractTest.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentStateMachineTest.java`

**Interfaces:**
- Produces public domain port `PracticeGeneratedContentCommands`.
- Keeps all SQL mutation methods in package `..practice.generated.internal..`.
- Provides query-only mapper methods to `PracticeGeneratedContentService`.

- [ ] **Step 1: Write failing architecture and state-transition tests**

The contract test must assert:

```java
assertThat(PracticeGeneratedContentQueryMapper.class.getDeclaredMethods())
        .allMatch(method -> method.getName().startsWith("find")
                || method.getName().startsWith("count"));
```

Use classpath scanning to assert only `PracticeGeneratedContentWriteService` references `PracticeGeneratedContentCommandMapper`. Also assert web/controller/discovery packages do not import command mapper or audit mapper types.

State-machine tests must cover:

```text
draft -> generating
generating -> active
draft|generating -> rejected
draft|generating -> expired
active|rejected|expired -> any other status is rejected
```

- [ ] **Step 2: Define the public command port**

Create `PracticeGeneratedContentCommands.java`:

```java
package com.zhangspaghetti.babytalk.practice.generated;

import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity;
import java.time.OffsetDateTime;
import java.util.Optional;

public interface PracticeGeneratedContentCommands {
    DraftReservation reserveDraft(PracticeGeneratedContentEntity draft, ReservationPolicy policy);
    GenerationStartDecision startGeneration(
            String generatedContentId,
            OffsetDateTime dailyFrom,
            int dailyLimit,
            OffsetDateTime now);
    Optional<PracticeGeneratedContentEntity> activate(PracticeGeneratedContentEntity active);
    void reject(String generatedContentId, String errorCode, boolean retryable, OffsetDateTime now, OffsetDateTime retentionExpiresAt);
    void expire(String generatedContentId, String errorCode, boolean retryable, OffsetDateTime now, OffsetDateTime retentionExpiresAt);
    int interruptStaleExecutions(OffsetDateTime interruptedAt, OffsetDateTime installationRetentionExpiresAt, int limit);
}
```

Create these top-level types in the same package so the interface does not depend on the facade implementation:

```java
public record DraftReservation(
        PracticeGeneratedContentEntity content,
        boolean created
) {
}
```

```java
public record ReservationPolicy(
        OffsetDateTime now,
        OffsetDateTime burstFrom,
        int burstLimit,
        OffsetDateTime expiredRetentionExpiresAt
) {
}
```

```java
public enum GenerationStartDecision {
    STARTED,
    DAILY_LIMIT_EXCEEDED,
    NOT_LIVE
}
```

Burst abuse protection applies when reserving the draft. Daily generation quota is consumed only by `startGeneration(...)`, immediately before the first Generator operation.

Create a top-level `PracticeGenerationRateLimitExceededException` in the public
generated-content package. The public facade and `ApiExceptionHandler` may
depend on it; they must not depend on a nested/package-private exception from
the internal write service. Preserve generated-content ID collision handling as
a typed `GeneratedContentIdConflictException` with a bounded ID-regeneration
retry in the facade.

- [ ] **Step 3: Implement package-internal mutation mapper and service**

`PracticeGeneratedContentCommandMapper` must be package-private and expose only named transitions:

```java
int insertDraftIgnoringLiveConflict(PracticeGeneratedContentEntity entity);
int lockOwnerRateLimit(String ownerLockKey);
int countRecentGenerationStarts(String ownerKey, String ownerKeyVersion, String surface, String mode, OffsetDateTime dailyFrom);
int markGenerating(String generatedContentId, OffsetDateTime updatedAt);
int activateGenerating(PracticeGeneratedContentEntity entity);
int rejectLive(String generatedContentId, String errorCode, boolean retryable, OffsetDateTime updatedAt, OffsetDateTime retentionExpiresAt);
int expireLive(String generatedContentId, String errorCode, boolean retryable, OffsetDateTime updatedAt, OffsetDateTime retentionExpiresAt);
int interruptStartedAttempts(...);
int interruptStartedOperations(...);
int interruptStartedProviderCalls(...);
int expireInterruptedGeneratedContent(...);
```

Do not expose `insertRow`, generic updates, or raw status parameters.

The internal `PracticeGeneratedContentWriteService` implements `PracticeGeneratedContentCommands`. `startGeneration(...)` loads the live draft, locks the owner rate-limit key, counts rows whose `generation_started_at` is inside the daily window, and sets `status='generating'` plus `generation_started_at=now` only when capacity remains. Keep transaction methods public so Spring proxies them, and keep the implementation class package-private.

- [ ] **Step 4: Add focused audit persistence methods**

`PracticeGenerationAuditMapper` must expose exact inserts/completions for:

```java
void insertAttempt(PracticeGenerationAttemptEntity entity);
void completeAttempt(UUID attemptId, String outcome, List<String> violationCodes, OffsetDateTime completedAt);
void insertOperationRun(PracticeAiOperationRunEntity entity);
void completeOperationRun(UUID operationRunId, String outcome, OffsetDateTime completedAt);
void insertProviderCall(PracticeAiProviderCallEntity entity);
void completeProviderCall(UUID providerCallId, String outcome, String providerTraceId, Long latencyMs, OffsetDateTime completedAt);
void insertEvidenceBundle(PracticeEvidenceBundleEntity bundle);
void insertEvidenceItems(List<PracticeEvidenceItemEntity> items);
void insertJudgeResult(PracticeJudgeResultEntity result);
```

All list-like fields must be deduplicated and sorted before persistence.

Add relational integrity tests beyond foreign-key existence:

- an operation referencing an evidence bundle must reference a bundle for the
  same `generated_content_id` and `attempt_number`;
- a Judge result may only attach to a provider call whose operation type is
  `QUALITY_JUDGE`;
- an attempt/operation/provider call cannot be completed twice with conflicting
  terminal outcomes.

Use composite foreign keys where practical; otherwise use one transactional
insert service with `INSERT ... SELECT` guards and integration tests.

- [ ] **Step 5: Update entity mappings**

`PracticeGeneratedContentEntity` must remove `coachTipZh`, `promptVersion`, `strategyVersion`, `policyVersion`, parent-level provider trace fields, and model name. Add the lineage/state fields from Task 3 plus `tprActionZh` and `deliveryGuidanceZh`. Do not add a `coachTipZh` entity property or mapper column; Task 11 composes the external field in the read mapper/service.

- [ ] **Step 6: Run focused persistence tests**

```bash
cd "$(git rev-parse --show-toplevel)/backend"
bash mvnw -pl app-api -Dtest=PracticeGeneratedContentMapperContractTest,PracticeGeneratedContentStateMachineTest,PracticeGeneratedContentMapperTest test
```

Expected: all selected tests pass and no generic mutation path remains.

- [ ] **Step 7: Commit persistence boundaries**

```bash
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated \
  backend/app-api/src/main/resources/mapper/practice/generated \
  backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated
git commit -m "refactor: enforce generated content write boundary"
```

---

### Task 5: Build sanitized evidence retrieval and one immutable bundle per attempt

**Files:**
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/evidence/CustomSceneEvidenceRetriever.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/evidence/CompositeCustomSceneEvidenceRetriever.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/evidence/PalaceCustomSceneEvidenceSource.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/evidence/BaselineFamilyEnglishEvidenceSource.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/evidence/EvidenceSanitizer.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/evidence/EvidenceBundleFactory.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/evidence/EvidenceItem.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/evidence/EvidenceSummary.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/evidence/EvidenceRetrievalRequest.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/evidence/EvidenceRetrievalResult.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/evidence/FrozenEvidenceBundle.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/evidence/ReplayMode.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/evidence/RetrievalStatus.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/palace/PalaceHybridRetrievalService.java` only if a typed trace ID accessor is required; do not change its ranking semantics.
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/evidence/EvidenceSanitizerTest.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/evidence/EvidenceBundleFactoryTest.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/evidence/CompositeCustomSceneEvidenceRetrieverTest.java`

**Interfaces:**
- Produces: `EvidenceRetrievalResult CustomSceneEvidenceRetriever.retrieve(EvidenceRetrievalRequest request)`.
- Produces: `FrozenEvidenceBundle EvidenceBundleFactory.createInitial(...)`.
- Produces: `FrozenEvidenceBundle EvidenceBundleFactory.deriveReused(...)`.
- Produces: `FrozenEvidenceBundle EvidenceBundleFactory.createRefreshed(...)`.
- Consumed by: Task 10 orchestration.

- [ ] **Step 1: Write failing sanitizer and policy tests**

Test that the sanitizer:

- removes URLs, Markdown list markers, HTML tags, and instruction phrases such as “忽略前文”.
- rejects or omits PII-bearing summaries.
- truncates to 280 Unicode code points without splitting a grapheme.
- returns stable SHA-256 for the sanitized summary.
- preserves ordinary Chinese care guidance.

Test that Minimum Evidence Policy fails when any required claim is absent or below `0.70`, and succeeds when internal baseline plus scene evidence covers all four claims.

- [ ] **Step 2: Define typed evidence records**

Use:

```java
public record EvidenceItem(
        String evidenceId,
        ReplayMode replayMode,
        String sourceType,
        String sourceVersion,
        String strategyId,
        String claimType,
        String sanitizedSummary,
        String sanitizedSummaryHash,
        double confidence
) {
}
```

```java
public record EvidenceRetrievalRequest(
        String displayText,
        String ageRange,
        String parentGoal,
        Set<String> requestedClaimTypes,
        UUID retrievalTraceId
) {
}
```

```java
public record EvidenceRetrievalResult(
        List<EvidenceItem> items,
        UUID retrievalTraceId,
        RetrievalStatus status
) {
}
```

No evidence record may contain `securityText`, raw chunks, URLs, account data, or provider prompts.

- [ ] **Step 3: Add immutable internal baseline evidence**

`BaselineFamilyEnglishEvidenceSource` loads `family-english-baseline-v1.yml` through `VersionedResourceRegistry`. It returns `REFERENCE` items only. The database row stores the evidence ID, source version, summary hash, strategy ID, claim type, and confidence; it does not store the summary snapshot.

- [ ] **Step 4: Adapt Palace retrieval as bounded SNAPSHOT evidence**

`PalaceCustomSceneEvidenceSource` calls `PalaceHybridRetrievalService.retrieve(...)`, maps at most five candidates, and treats a candidate as:

- `REFERENCE` only when metadata contains a trusted stable `evidence_id`, `source_version`, and `claim_type` from approved ingestion.
- otherwise `SNAPSHOT`, storing only the sanitizer output.

The source must never pass the full candidate content directly to Generator or Judge.

- [ ] **Step 5: Compose and validate the bundle**

`CompositeCustomSceneEvidenceRetriever` merges baseline and Palace items, deduplicates by `(evidenceId, sourceVersion, claimType, summaryHash)`, sorts by claim type then confidence descending, and applies `MinimumEvidencePolicy`.

`EvidenceBundleFactory` computes `bundleHash` over ordered item metadata and summary hashes, persists bundle + items in one transaction, and returns an immutable `FrozenEvidenceBundle` containing the runtime sanitized summaries required by Generator/Judge.

For a `REUSED` repair bundle, create a new bundle ID and new item rows copied from the previous bundle; set `derived_from_bundle_id` and do not invoke Palace. For `REFRESHED`, run retrieval again with the evidence gap claim set and re-apply the minimum policy.

- [ ] **Step 6: Run focused evidence tests**

```bash
cd "$(git rev-parse --show-toplevel)/backend"
bash mvnw -pl app-api -Dtest=EvidenceSanitizerTest,EvidenceBundleFactoryTest,CompositeCustomSceneEvidenceRetrieverTest test
```

Expected: all selected tests pass; tests assert no raw chunk appears in saved entities.

- [ ] **Step 7: Commit evidence architecture**

```bash
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/evidence \
  backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/evidence \
  backend/app-api/src/main/resources/config/practice-ai/evidence \
  backend/app-api/src/main/java/com/zhangspaghetti/babytalk/palace/PalaceHybridRetrievalService.java
git commit -m "feat: freeze custom scene evidence bundles"
```

---

### Task 6: Add named Spring AI providers, capability routes, fallback, and provider-call audit

The existing `babytalk.practice.discovery.custom-scene.provider-mode` remains
the top-level mode gate:

```text
disabled -> fail before auth/profile/HMAC/reservation
fake     -> dev/test deterministic adapters; instantiate no network provider
agentic  -> resolve app.ai.providers/app.ai.capabilities
```

Do not delete `AgenticUnavailableCustomSceneGenerationService` until mandatory
agentic capability beans fail fast correctly and agentic integration tests pass.
Unknown provider mode remains a startup failure.


**Files:**
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/PracticeAiCapability.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/PracticeAiProperties.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/PracticeAiProviderManager.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/PracticeAiChatClientFactory.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/PracticeAiOpenAiOptionsFactory.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/PracticeAiStructuredOutputCaller.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/PracticeAiOperationRunner.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/PracticeAiCallFailureClassifier.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/ResolvedProvider.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/OperationRequest.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/OperationResult.java`
- Modify: `backend/app-api/src/main/resources/application.yml`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/agentic/PracticeAiProviderManagerTest.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/agentic/PracticeAiOperationRunnerTest.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/agentic/PracticeAiPropertiesTest.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/agentic/PracticeAiOpenAiOptionsFactoryTest.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/agentic/PracticeAiStructuredOutputCallerTest.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/agentic/PracticeAiSingleRequestContractTest.java`

**Interfaces:**
- Produces: `ResolvedProvider PracticeAiChatClientFactory.create(String providerName, PracticeAiProperties.ProviderDefinition provider)`.
- Produces: `List<ResolvedProvider> PracticeAiProviderManager.route(PracticeAiCapability capability)`.
- Produces: `<T> OperationResult<T> PracticeAiOperationRunner.execute(OperationRequest<T> request)`.
- Records one `practice_ai_provider_calls` row per actual provider invocation.
- Consumed by: Tasks 7, 9, and 10.

- [ ] **Step 1: Write failing route and fallback tests**

Test:

- ordered providers are returned exactly as configured.
- each provider is attempted at most once per operation.
- a local counting HTTP server receives exactly one outbound request for one named-provider attempt, including 429/5xx responses; SDK retry is disabled with `maxRetries(0)`.
- timeout, connection failure, 429, 5xx, and one-pass structured-output conversion failure fall back to the next configured provider.
- malformed structured output never causes an internal Spring AI schema-repair retry.
- a successful structured Judge `REJECT` or `REPAIR` does not fall back.
- all-provider exhaustion returns a typed infrastructure failure.
- every actual call has a unique Baby Talk `attempt_trace_id`.
- `provider_trace_id` is accepted only when it matches `[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}`.
- `temperature` may be absent; configuration containing both `max-tokens` and `max-completion-tokens` fails at startup.
- audit rows contain no request body, prompt, response, exception message, or scene text.

`PracticeAiSingleRequestContractTest` must exercise the actual Spring AI 2/OpenAI SDK HTTP stack against a local JDK server:

```java
@Test
void oneNamedProviderAttemptMakesExactlyOneOutboundRequestOnServerError() throws Exception {
    var requestCount = new AtomicInteger();
    var server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
    server.createContext("/v1/chat/completions", exchange -> {
        requestCount.incrementAndGet();
        exchange.sendResponseHeaders(500, -1);
        exchange.close();
    });
    server.start();
    try {
        var environment = new MockEnvironment()
                .withProperty("TEST_AI_KEY", "test-key");
        var factory = new PracticeAiChatClientFactory(
                environment,
                new PracticeAiOpenAiOptionsFactory());
        var provider = factory.create(
                "primary",
                new PracticeAiProperties.ProviderDefinition(
                        "openai-compatible",
                        URI.create("http://127.0.0.1:"
                                + server.getAddress().getPort() + "/v1"),
                        "TEST_AI_KEY",
                        "gpt-4o-mini",
                        Duration.ofSeconds(2),
                        null,
                        128,
                        null));

        assertThatThrownBy(() -> provider.chatClient()
                .prompt()
                .user("return JSON")
                .call()
                .content())
                .isInstanceOf(RuntimeException.class);
        assertThat(requestCount).hasValue(1);
    }
    finally {
        server.stop(0);
    }
}
```

Add the same assertion for HTTP `429`. A separate local-server response containing a valid OpenAI envelope whose assistant content is `not-json` must prove `PracticeAiStructuredOutputCaller` raises `structured_output_invalid` after one request rather than repairing invisibly.

- [ ] **Step 2: Bind named provider and capability maps**

`PracticeAiProperties` must bind:

```yaml
app:
  ai:
    routing-policy:
      version: custom-scene-routing-v1
    providers:
      primary:
        type: openai-compatible
        base-url: https://example.invalid
        api-key-environment-variable: BABY_TALK_AI_PROVIDER_PRIMARY_API_KEY
        model: gpt-4o-mini
        timeout: 20s
        max-tokens: 600
        # temperature is optional and omitted for reasoning models.
        # max-completion-tokens is the mutually exclusive alternative for reasoning models.
    capabilities:
      custom-scene-generator:
        provider-names: [primary]
      custom-scene-quality-judge:
        provider-names: [primary]
      custom-scene-repair:
        provider-names: [primary]
```

Startup must fail for unknown provider names, duplicate names in one route, unsupported provider type, blank model, missing API-key environment variable in agentic mode, an empty mandatory capability route, non-positive timeout/token values, or a provider that sets both `max-tokens` and `max-completion-tokens`.

- [ ] **Step 3: Define exact capability, provider, request, and result contracts**

Bind provider definitions to one explicit nested record so configuration validation and the options factory share the same field names:

```java
public record ProviderDefinition(
        String type,
        URI baseUrl,
        String apiKeyEnvironmentVariable,
        String model,
        Duration timeout,
        Double temperature,
        Integer maxTokens,
        Integer maxCompletionTokens) {
}
```

Create the capability enum with stable YAML keys:

```java
public enum PracticeAiCapability {
    CUSTOM_SCENE_GENERATOR("custom-scene-generator"),
    CUSTOM_SCENE_QUALITY_JUDGE("custom-scene-quality-judge"),
    CUSTOM_SCENE_REPAIR("custom-scene-repair");

    private final String propertyKey;

    PracticeAiCapability(String propertyKey) {
        this.propertyKey = propertyKey;
    }

    public String propertyKey() {
        return propertyKey;
    }
}
```

Create the trusted provider receipt boundary:

```java
public record ResolvedProvider(
        String providerName,
        String providerType,
        String modelName,
        ChatClient chatClient
) {
}
```

Create the operation request. The callback receives only the resolved provider and returns the typed value plus an optional supplier trace ID; it never receives credentials:

```java
public record OperationRequest<T>(
        PracticeAiCapability capability,
        String subjectType,
        String subjectId,
        String generatedContentId,
        Integer attemptNumber,
        UUID evidenceBundleId,
        String promptVersion,
        String promptHash,
        String policyVersion,
        String policyHash,
        ProviderInvocation<T> invocation
) {
    @FunctionalInterface
    public interface ProviderInvocation<T> {
        ProviderInvocationResult<T> invoke(ResolvedProvider provider);
    }

    public record ProviderInvocationResult<T>(T value, String providerTraceId) {
    }
}
```

Create the successful operation receipt:

```java
public record OperationResult<T>(
        T value,
        UUID operationRunId,
        UUID providerCallId,
        String providerName,
        String modelName,
        String providerTraceId
) {
}
```

- [ ] **Step 4: Build Spring AI 2 providers without hidden retries or exposed credentials**

`PracticeAiChatClientFactory` resolves the named secret from `Environment`. It passes the resolved key and provider definition to `PracticeAiOpenAiOptionsFactory`, which builds Spring AI 2 options. The options factory must set exactly one token-limit field, apply `temperature` only when configured, force `n(1)`, and hard-code `maxRetries(0)`:

```java
OpenAiChatOptions build(PracticeAiProperties.ProviderDefinition provider, String apiKey) {
    var builder = OpenAiChatOptions.builder()
            .baseUrl(provider.baseUrl().toString())
            .apiKey(apiKey)
            .model(provider.model())
            .timeout(provider.timeout())
            .n(1)
            .maxRetries(0);
    if (provider.temperature() != null) {
        builder.temperature(provider.temperature());
    }
    if (provider.maxTokens() != null) {
        builder.maxTokens(provider.maxTokens());
    }
    if (provider.maxCompletionTokens() != null) {
        builder.maxCompletionTokens(provider.maxCompletionTokens());
    }
    return builder.build();
}
```

`PracticeAiChatClientFactory` then resolves the configured environment variable and creates the model through the Spring AI 2 builder:

```java
public ResolvedProvider create(
        String providerName,
        PracticeAiProperties.ProviderDefinition provider) {
    String apiKey = environment.getRequiredProperty(
            provider.apiKeyEnvironmentVariable());
    OpenAiChatOptions options = optionsFactory.build(provider, apiKey);
    OpenAiChatModel chatModel = OpenAiChatModel.builder()
            .options(options)
            .build();
    return new ResolvedProvider(
            providerName,
            provider.type(),
            provider.model(),
            ChatClient.builder(chatModel).build());
}
```

Do not construct `OpenAiApi`. Do not use auto-configured global retry settings for these named custom-scene clients. `ResolvedProvider` must not expose or stringify the API key.


`PracticeAiStructuredOutputCaller` is the only production helper used by Generator, Judge, and Repair to request typed output. It generates the schema, requests provider-native JSON Schema output, reads one response, and converts once:

```java
public <T> T call(
        ResolvedProvider provider,
        String systemPrompt,
        String userPrompt,
        Class<T> responseType) {
    var converter = new BeanOutputConverter<>(responseType);
    var options = OpenAiChatOptions.builder()
            .responseFormat(OpenAiChatModel.ResponseFormat.builder()
                    .jsonSchema(converter.getJsonSchema())
                    .build())
            .build();
    var content = provider.chatClient()
            .prompt()
            .options(options)
            .system(systemPrompt)
            .user(userPrompt)
            .call()
            .content();
    return converter.convert(content);
}
```

In Spring AI `2.0.0`, `OpenAiChatModel.ResponseFormat.builder().jsonSchema(...)` sets `JSON_SCHEMA` mode, and `OpenAiChatOptions.maxRetries(0)` controls the official OpenAI Java SDK retry count. Keep a compile-time contract test around these exact APIs so a future Spring AI upgrade cannot silently change the one-call invariant.

It must not call `.entity(...validateSchema())`, `.validateSchema()`, an advisor repair loop, or a second provider request. Conversion failure is raised as `structured_output_invalid` to `PracticeAiOperationRunner`.

- [ ] **Step 5: Implement operation and provider-call audit boundaries**

`PracticeAiOperationRunner.execute(...)` must:

1. Insert `practice_ai_operation_runs` before the first provider call.
2. For each configured provider, insert a provider call with outcome `started` and a new UUID `attempt_trace_id`.
3. Execute the typed capability callback.
4. Complete the provider call with `succeeded`, `timeout`, `rate_limited`, `server_error`, `connection_error`, or `structured_output_invalid`.
5. Complete the operation on success or after fallback exhaustion.
6. Persist only trusted adapter metadata and sanitized provider trace ID.

Use monotonic `System.nanoTime()` for latency and UTC `Clock` for timestamps.

- [ ] **Step 6: Remove the `AgenticUnavailableCustomSceneGenerationService` placeholder**

Delete the placeholder only after all three mandatory capability routes can be constructed in agentic mode. Disabled mode still fails before draft reservation. Fake mode continues to use local adapters and must not instantiate network providers.

- [ ] **Step 7: Run focused provider tests**

```bash
cd "$(git rev-parse --show-toplevel)/backend"
bash mvnw -pl app-api -Dtest='PracticeAiProviderManagerTest,PracticeAiOperationRunnerTest,PracticeAiPropertiesTest,PracticeAiOpenAiOptionsFactoryTest,PracticeAiStructuredOutputCallerTest,PracticeAiSingleRequestContractTest,CustomSceneGenerationProviderWiringTest' test
```

Expected: all selected tests pass without external network access.

- [ ] **Step 8: Commit provider infrastructure**

```bash
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic \
  backend/app-api/src/main/resources/application.yml \
  backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/agentic \
  backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/AgenticUnavailableCustomSceneGenerationService.java \
  backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneGenerationProviderWiringTest.java
git commit -m "feat: route custom scene AI capabilities"
```

---

### Task 7: Evolve the generated candidate and implement the agentic Generator adapter

The evolved candidate preserves current externally required metadata:
`spaceTitleZh`, `activityTitleZh`, `sceneTagEn`, English/Chinese text,
pronunciation hint, difficulty, and generation source. Splitting `coachTipZh`
must not shrink `PracticeDiscoveryResponse`. Add a controller regression that
compares all existing generated scene/moment/starter IDs and slug fields.


**Files:**
- Delete: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneGenerationService.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/FakeCustomSceneGenerationService.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/DisabledCustomSceneGenerationService.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/CustomSceneGenerator.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/AgenticCustomSceneGenerator.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/AgenticCustomSceneGeneratorTest.java`
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneGeneratedContentValidatorTest.java`
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneGenerationProviderWiringTest.java`
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/PracticeDiscoveryControllerTest.java`
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentConcurrencyTest.java`
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentMapperTest.java`
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentServiceTest.java`

**Interfaces:**
- Produces: `GeneratedPracticeContentCandidate CustomSceneGenerator.generate(GeneratorRequest request)`.
- Candidate metadata is content only; provider/model/trace metadata comes from `PracticeAiOperationRunner` receipts. The `CustomSceneGenerator` interface owns the request, constraint, candidate, and typed unavailability records that currently live in `CustomSceneGenerationService`.
- Consumed by: Tasks 8 and 10.

- [ ] **Step 1: Write failing candidate-contract tests**

Assert record components contain:

```text
spaceTitleZh
activityTitleZh
sceneTagEn
tprActionZh
deliveryGuidanceZh
englishText
chineseText
pronunciationHint
difficulty
generationSource
```

Assert they do not contain:

```text
coachTipZh
providerTraceId
retrievalTraceId
modelName
```

- [ ] **Step 2: Replace the old generation port and candidate record**

Delete `CustomSceneGenerationService.java`. Create `CustomSceneGenerator.java` with `generate(GeneratorRequest request)` plus nested `ContentConstraints`, `GeneratedPracticeContentCandidate`, and typed infrastructure exceptions. Update fake and disabled implementations and all callers to depend on `CustomSceneGenerator`. Use this candidate record:

```java
public record GeneratedPracticeContentCandidate(
        String spaceTitleZh,
        String activityTitleZh,
        String sceneTagEn,
        String tprActionZh,
        String deliveryGuidanceZh,
        String englishText,
        String chineseText,
        String pronunciationHint,
        String difficulty,
        String generationSource
) {
}
```

Update fake fixtures so every candidate has an executable action and low-pressure delivery guidance. Keep fake `generationSource="fake"` and dev/test profile restrictions.

- [ ] **Step 3: Define the Generator request**

```java
public record GeneratorRequest(
        String generatedContentId,
        int attemptNumber,
        String displayText,
        String ageRange,
        String parentGoal,
        String locale,
        FrozenEvidenceBundle evidenceBundle,
        GenerationProfile generationProfile,
        ContentConstraints constraints
) {
}
```

No request field may expose `securityText`, owner identifiers, raw evidence chunks, or account/profile data.

- [ ] **Step 4: Implement strict structured output conversion**

`AgenticCustomSceneGenerator` uses the generator prompt, serializes only typed request fields, appends ordered sanitized evidence summaries, and invokes `PracticeAiOperationRunner` under capability `CUSTOM_SCENE_GENERATOR`. The provider callback calls:

```java
var wire = structuredOutputCaller.call(
        provider,
        systemPrompt,
        userPrompt,
        GeneratorWireResponse.class);
```

Map exact wire fields to the candidate record. `GeneratorWireResponse` must not contain `generationSource`; the adapter assigns trusted `generationSource="agentic_search"` after parsing. On malformed JSON or schema mismatch, `PracticeAiStructuredOutputCaller` throws `structured_output_invalid` immediately so the runner can close the current provider-call row and try the next named provider. Do not strip Markdown fences, call `.validateSchema()`, or heuristically recover free-form text in production agentic mode.

- [ ] **Step 5: Run Generator tests**

```bash
cd "$(git rev-parse --show-toplevel)/backend"
bash mvnw -pl app-api -Dtest=AgenticCustomSceneGeneratorTest,CustomSceneGenerationProviderWiringTest,PracticeGeneratedContentServiceTest test
```

Expected: all selected tests pass; fake mode remains local and agentic tests use stub clients.

- [ ] **Step 6: Commit the Generator contract**

```bash
git add -A backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneGenerationService.java \
  backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/FakeCustomSceneGenerationService.java \
  backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/DisabledCustomSceneGenerationService.java \
  backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/CustomSceneGenerator.java \
  backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/AgenticCustomSceneGenerator.java \
  backend/app-api/src/test
git commit -m "feat: add typed custom scene generator"
```

---

### Task 8: Convert generated-output validation into a typed terminal/repairable gate

**Files:**
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneGeneratedContentValidator.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/quality/GeneratedOutputGateResult.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/quality/GeneratedOutputViolationCode.java`
- Modify: `backend/app-api/src/main/resources/config/practice-discovery-policy.yml`
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneGeneratedContentValidatorTest.java`

**Interfaces:**
- Produces: `GeneratedOutputGateResult CustomSceneGeneratedContentValidator.evaluate(candidate, context)`.
- Terminal violations stop immediately; repairable violations skip Judge and consume the next semantic attempt when available.
- Consumed by: Task 10.

- [ ] **Step 1: Write failing classification tests**

Required terminal codes:

```text
OUTPUT_PII
OUTPUT_BIDI_CONTROL
OUTPUT_ADULT_VIOLENT
OUTPUT_DANGEROUS_MEDICAL
UNTRUSTED_METADATA
DATABASE_OVERFLOW
INVALID_ENUM
```

Required repairable codes:

```text
MISSING_TPR_ACTION
MISSING_DELIVERY_GUIDANCE
FIELD_ROLE_MISMATCH
META_INSTRUCTION
COURSE_OR_SCORING_FRAMING
MARKDOWN_OR_TEMPLATE
```

Tests must prove `englishText="Repeat after me"` is repairable, a phone number is terminal, a missing action signal is repairable, and a dangerous medical command is terminal.

- [ ] **Step 2: Add stable violation enum and result**

```java
public enum GeneratedOutputViolationCode {
    OUTPUT_PII(false),
    OUTPUT_BIDI_CONTROL(false),
    OUTPUT_ADULT_VIOLENT(false),
    OUTPUT_DANGEROUS_MEDICAL(false),
    UNTRUSTED_METADATA(false),
    DATABASE_OVERFLOW(false),
    INVALID_ENUM(false),
    MISSING_TPR_ACTION(true),
    MISSING_DELIVERY_GUIDANCE(true),
    FIELD_ROLE_MISMATCH(true),
    META_INSTRUCTION(true),
    COURSE_OR_SCORING_FRAMING(true),
    MARKDOWN_OR_TEMPLATE(true);

    private final boolean repairable;
}
```

```java
public record GeneratedOutputGateResult(
        GeneratedPracticeContentCandidate normalizedCandidate,
        List<GeneratedOutputViolationCode> terminalViolations,
        List<GeneratedOutputViolationCode> repairableViolations
) {
    public boolean passed() {
        return terminalViolations.isEmpty() && repairableViolations.isEmpty();
    }
}
```

Sort and deduplicate violation codes before returning.

- [ ] **Step 3: Enforce field-role signals**

The deterministic gate must require:

- `tprActionZh`: at least one configured physical action/object/posture/pause signal.
- `deliveryGuidanceZh`: at least one configured timing/tone/pace/wait/observe/low-pressure signal.

These marker lists remain deterministic policy data. They are not a closed naturalness taxonomy and must not reject otherwise safe English/Chinese solely because a scene keyword is absent.

- [ ] **Step 4: Remove broad semantic keyword decisions from the deterministic gate**

Keep only high-confidence safety and structure checks. Scene alignment, bilingual consistency, natural parent speech, age suitability, and low-pressure quality move to the Judge. Do not use `CustomSceneIntentClassifier` output as an activation decision.

- [ ] **Step 5: Run gate tests**

```bash
cd "$(git rev-parse --show-toplevel)/backend"
bash mvnw -pl app-api -Dtest=CustomSceneGeneratedContentValidatorTest,PracticeDiscoveryPolicyPropertiesTest test
```

Expected: all selected tests pass with stable terminal/repairable codes.

- [ ] **Step 6: Commit the deterministic gate**

```bash
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneGeneratedContentValidator.java \
  backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/quality \
  backend/app-api/src/main/resources/config/practice-discovery-policy.yml \
  backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery
git commit -m "feat: classify generated output violations"
```

---

### Task 9: Add an independent Quality Judge and application-computed verdict

**Files:**
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/CustomSceneQualityJudge.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/AgenticCustomSceneQualityJudge.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/FakeCustomSceneQualityJudge.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/quality/JudgeVerdictCalculator.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/quality/JudgeDimension.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/quality/DimensionResult.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/quality/JudgeVerdict.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/quality/SuggestedJudgeResult.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/quality/EffectiveJudgeResult.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/quality/RepairDirective.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/quality/EvidenceGapCode.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/quality/JudgeVerdictCalculatorTest.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/AgenticCustomSceneQualityJudgeTest.java`

**Interfaces:**
- Produces: `SuggestedJudgeResult CustomSceneQualityJudge.judge(JudgeRequest request)`.
- Produces: `EffectiveJudgeResult JudgeVerdictCalculator.calculate(SuggestedJudgeResult suggested, QualityRubric rubric)`.
- Consumed by: Task 10.

- [ ] **Step 1: Write failing verdict-policy tests**

Cover:

- all dimensions PASS → effective PASS.
- age suitability FAIL → effective REJECT.
- parent speakability FAIL → effective REPAIR.
- any dimension ABSTAIN → effective ABSTAIN/repairable uncertainty.
- suggested PASS with a failed dimension → `verdictConsistency=INCONSISTENT` and conservative effective verdict.
- `judgeConfidence` never changes the effective verdict.
- unknown/missing dimension fails closed as structured-output invalid.

- [ ] **Step 2: Define strict Judge structures**

```java
public enum JudgeDimension {
    SCENE_ALIGNMENT,
    PARENT_SPEAKABILITY,
    NON_COURSE_FRAMING,
    TPR_QUALITY,
    DELIVERY_GUIDANCE_QUALITY,
    AGE_SUITABILITY,
    BILINGUAL_CONSISTENCY,
    LOW_PRESSURE_SUPPORT
}
```

```java
public enum DimensionResult { PASS, FAIL, ABSTAIN }
public enum JudgeVerdict { PASS, REPAIR, REJECT, ABSTAIN }
```

```java
public record SuggestedJudgeResult(
        JudgeVerdict suggestedVerdict,
        Map<JudgeDimension, DimensionResult> dimensionResults,
        List<String> violationCodes,
        List<RepairDirective> repairDirectives,
        List<EvidenceGapCode> evidenceGapCodes,
        Double confidence
) {
}
```

`violationCodes` must be validated against the Rubric's stable allowlist. Repair directives and evidence gaps are typed enums. Do not accept free-form reasons.

- [ ] **Step 3: Restrict Judge inputs**

`JudgeRequest` contains only:

```text
displayText
ageRange
parentGoal
normalized candidate
strategy IDs
communication primitive IDs
age guidance tags
safety constraint tags
ordered sanitized evidence summaries
rubric version/hash
```

It must not contain raw retrieval chunks, account/profile data, provider prompts, logs, or any free-form prior Judge reasoning.

- [ ] **Step 4: Implement the agentic and fake Judges**

`AgenticCustomSceneQualityJudge` runs the mandatory `CUSTOM_SCENE_QUALITY_JUDGE` capability and uses `PracticeAiStructuredOutputCaller.call(..., JudgeWireResponse.class)`. It receives no tools or memory and performs exactly one response conversion per named provider. Missing/unknown dimensions, malformed JSON, or schema mismatch become `structured_output_invalid`; they do not invoke `.validateSchema()` or an internal repair request. `FakeCustomSceneQualityJudge` is active only in `dev`/`test` fake mode and returns a deterministic structured PASS for valid fake fixtures; it performs no network call and is never registered for production agentic mode.

- [ ] **Step 5: Persist the successful structured Judge result**

After a provider call succeeds and parses, persist one `practice_generated_content_judge_results` row linked to that exact provider call. Persist suggested/effective verdicts, consistency, complete dimension map, stable code arrays, confidence, and rubric version/hash. Do not persist free text.

- [ ] **Step 6: Run Judge tests**

```bash
cd "$(git rev-parse --show-toplevel)/backend"
bash mvnw -pl app-api -Dtest=JudgeVerdictCalculatorTest,AgenticCustomSceneQualityJudgeTest,CustomSceneGenerationProviderWiringTest test
```

Expected: all selected tests pass and no Judge test requires network access.

- [ ] **Step 7: Commit the Quality Judge**

```bash
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated \
  backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/quality \
  backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated
git commit -m "feat: add independent custom scene quality judge"
```

---

### Task 10: Implement bounded semantic attempts and the typed Repair loop

Migrate, do not weaken, the current atomic quota contract:

- burst accounting and draft reservation stay in the owner-locked
  `REQUIRES_NEW` transaction;
- daily generation quota is consumed exactly once by `startGeneration`
  immediately before attempt-1 Generator;
- insufficient evidence before Generator consumes no daily generation quota;
- provider fallback and Repair consume no extra user quota;
- provider calls remain outside the owner reservation lock.

Update the current concurrency tests rather than replacing them.


**Files:**
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/CustomSceneRepairer.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/AgenticCustomSceneRepairer.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/FakeCustomSceneRepairer.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/quality/TypedRepairPackage.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/CustomSceneGenerationOrchestrator.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/PracticeDiscoveryCustomSceneProperties.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentService.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/CustomSceneGenerationOrchestratorTest.java`
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentServiceTest.java`

**Interfaces:**
- Produces: `PracticeGeneratedContentEntity CustomSceneGenerationOrchestrator.execute(GenerationExecution execution)`.
- Uses exactly one Generator operation in attempt 1 and exactly one Repair operation in each later attempt.
- Every candidate that passes the deterministic gate receives a fresh independent Judge.

- [ ] **Step 1: Add bounded attempt configuration tests**

Extend `PracticeDiscoveryCustomSceneProperties` with:

```java
Integer maxGenerationAttempts
```

Default is `2`; startup rejects values outside `1..5`. Add properties tests for `1`, `2`, `5`, `0`, and `6`.

- [ ] **Step 2: Write orchestration tests before implementation**

Cover these exact call sequences:

```text
Generator -> deterministic PASS -> Judge PASS -> ACTIVE
Generator -> repairable deterministic failure -> Repair -> deterministic PASS -> Judge PASS
Generator -> deterministic PASS -> Judge REPAIR -> Repair -> Judge PASS
Generator -> Judge ABSTAIN -> Repair -> Judge PASS
Generator -> terminal deterministic failure -> REJECTED, no Judge, no Repair
Generator -> Judge REJECT -> REJECTED, no Repair
Generator providers exhausted -> EXPIRED
Judge providers exhausted -> EXPIRED
Repair providers exhausted -> EXPIRED
attempt limit exhausted -> REJECTED
```

Also assert every attempt has one bundle, each Repair result is revalidated and re-judged, and fallback calls do not increment `attempt_number`.

- [ ] **Step 3: Define the Typed Repair Package**

```java
public record TypedRepairPackage(
        String displayText,
        String ageRange,
        String parentGoal,
        GeneratedPracticeContentCandidate previousCandidate,
        JudgeVerdict effectiveVerdict,
        List<JudgeDimension> failedDimensions,
        List<String> violationCodes,
        List<RepairDirective> repairDirectives,
        List<EvidenceSummary> evidenceSummaries,
        GenerationProfile generationProfile
) {
}
```

It must not contain raw chunks, Judge free text, chain-of-thought, provider response, prior system prompt, or owner/account/device details.

`AgenticCustomSceneRepairer` invokes capability `CUSTOM_SCENE_REPAIR` and calls `PracticeAiStructuredOutputCaller.call(..., RepairWireResponse.class)`. It obeys the same single-conversion/no-`validateSchema()` rule as Generator and Judge; malformed output closes the current provider call as `structured_output_invalid` and allows only the configured next-provider fallback.

- [ ] **Step 4: Implement evidence reuse versus refresh**

The application decides:

```java
if (effectiveEvidenceGapCodes.isEmpty()) {
    nextBundle = evidenceBundleFactory.deriveReused(previousBundle, nextAttemptNumber);
} else {
    nextBundle = evidenceBundleFactory.createRefreshed(
            execution, nextAttemptNumber, effectiveEvidenceGapCodes);
}
```

Unknown gap codes are ignored for refresh and recorded as `judge_evidence_action_inconsistent`. If refreshed evidence fails Minimum Evidence Policy, expire the parent as `insufficient_evidence`, retryable `true`, without invoking Repair.

- [ ] **Step 5: Implement the orchestration loop**

Use an explicit `for (attemptNumber = 1; attemptNumber <= attemptLimit; attemptNumber++)` loop. For each iteration:

1. Persist attempt `started` before retrieval/provider work.
2. Create/freeze the attempt evidence bundle.
3. Call Generator for attempt 1, Repair for later attempts.
4. Run deterministic gate.
5. On terminal violations, complete attempt and reject parent.
6. On repairable violations, complete attempt and continue if capacity remains.
7. On gate pass, call the independent Judge.
8. Persist Judge result and apply effective verdict.
9. PASS activates; REJECT rejects; REPAIR/ABSTAIN continues if capacity remains.
10. Any provider-chain infrastructure exhaustion expires parent.

The parent snapshots `generation_attempt_limit` when the draft is created. Runtime config changes affect only new drafts.

- [ ] **Step 6: Separate burst abuse protection from daily generation quota**

Draft reservation applies only the burst request limit. After the initial evidence bundle passes Minimum Evidence Policy and immediately before the attempt-1 Generator operation, call:

```java
var decision = generatedContentCommands.startGeneration(
        execution.generatedContentId(),
        execution.dailyQuotaFrom(),
        execution.dailyGenerationLimit(),
        clock.now());
```

Handle the result exactly:

```text
STARTED
→ execute the Generator operation

DAILY_LIMIT_EXCEEDED
→ expire the draft with generation_rate_limited
→ throw PracticeGenerationRateLimitExceededException for HTTP 429
→ do not create a Generator operation/provider call

NOT_LIVE
→ reload the winner; return it only when ACTIVE, otherwise fail closed
```

Provider fallback and Repair remain inside the same parent execution and do not consume another daily generation slot. If Minimum Evidence Policy fails before `startGeneration(...)`, expire the draft as `insufficient_evidence`; it remains visible to burst-abuse accounting but does not consume daily generation quota.

- [ ] **Step 7: Run orchestration tests**

```bash
cd "$(git rev-parse --show-toplevel)/backend"
bash mvnw -pl app-api -Dtest=CustomSceneGenerationOrchestratorTest,PracticeGeneratedContentServiceTest,PracticeDiscoveryCustomScenePropertiesTest test
```

Expected: all selected tests pass with exact call-count and state assertions.

- [ ] **Step 8: Commit bounded Repair orchestration**

```bash
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated \
  backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/PracticeDiscoveryCustomSceneProperties.java \
  backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated \
  backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/PracticeDiscoveryCustomScenePropertiesTest.java
git commit -m "feat: orchestrate bounded custom scene repair"
```

---

### Task 11: Complete exact reuse, API composition, terminal cleanup, and failure semantics

Exact reuse keeps owner-key isolation and response hydration. The live lookup
uses the HMAC fingerprint from `PracticeGeneratedContentKeyFactory` plus new
Generation Profile lineage; never introduce a plain scene hash or compare scene
hashes across owners.

Terminal cleanup preserves B2.1 cross-version behavior: current-key lookup and
rate limits are version-bound; stale execution cleanup, installation retention
deletion, and account deletion cover historical owner-key versions.


**Files:**
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentService.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentKeyFactory.java`
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentKeyFactoryTest.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/PracticeDiscoveryService.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/ApiExceptionHandler.java` only when a new typed exception mapping is required.
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentServiceTest.java`
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/PracticeDiscoveryControllerTest.java`
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentConcurrencyTest.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGenerationInterruptionTest.java`

**Interfaces:**
- Exact owner/profile/installation lookup remains the only reuse mechanism in this plan.
- API continues returning `englishText`, `chineseText`, and `coachTipZh`.

- [ ] **Step 1: Write failing exact-reuse and terminal-immutability tests**

Prove:

- same owner + same `securityText` fingerprint + same generation profile + same refresh epoch returns active content without evidence retrieval, Generator, Judge, or Repair.
- different owner does not reuse.
- changing Generation Profile version creates a new lineage.
- rejected/expired rows do not block a new draft.
- active/rejected/expired rows cannot be revived.
- API `coachTipZh` is composed from `tprActionZh + deliveryGuidanceZh`.

- [ ] **Step 2: Update fingerprint inputs**

The owner-scoped HMAC fingerprint payload must include:

```text
surface
mode
securityText
ageRange
parentGoal
locale
generationProfileVersion
rubricVersion
evidencePolicyVersion
contentRefreshEpoch
```

Do not include Routing Policy. Preserve the existing owner-key HMAC domain separation.

- [ ] **Step 3: Normalize failure semantics**

Use these terminal mappings:

```text
content quality failure / attempts exhausted / Judge REJECT
→ status=rejected
→ error_code=generation_invalid_output
→ retryable=false
→ suggestCatalogFallback=true

provider exhaustion / Judge infrastructure failure / timeout / evidence unavailable / interruption
→ status=expired
→ error_code=generation_unavailable | generation_timeout | insufficient_evidence | generation_interrupted
→ retryable=true
→ suggestCatalogFallback=true

atomic daily generation quota denial before Generator
→ status=expired
→ error_code=generation_rate_limited
→ retryable=true
→ HTTP 429 through the existing typed rate-limit mapping
→ zero Generator operation/provider calls
```

Input PII, bidi controls, and unsafe request content remain HTTP 422 before draft reservation.

- [ ] **Step 4: Mark stale started work interrupted before expiring parent rows**

`interruptStaleExecutions(...)` must, in one transaction:

1. set `started` provider calls to `interrupted` with completion time.
2. set `started` operation runs to `interrupted`.
3. set `started` attempts to `interrupted`.
4. expire parent `draft`/`generating` rows as `generation_interrupted`.
5. clear `normalized_scene_text`.

Do not resume a pre-restart lineage with newly registered provider beans.

- [ ] **Step 5: Compose API guidance at read time**

In `PracticeDiscoveryService.toGeneratedResponse(...)`, compose the external field directly from the two persisted values:

```java
var coachTipZh = row.tprActionZh() + " " + row.deliveryGuidanceZh();
```

Pass `coachTipZh` to the response DTO. `PracticeGeneratedContentEntity`, mapper XML, and SQL must not define or reference `coach_tip_zh`.

- [ ] **Step 6: Run service, controller, interruption, and concurrency tests**

```bash
cd "$(git rev-parse --show-toplevel)/backend"
bash mvnw -pl app-api -Dtest=PracticeGeneratedContentServiceTest,PracticeDiscoveryControllerTest,PracticeGenerationInterruptionTest,PracticeGeneratedContentConcurrencyTest test
```

Expected: all selected tests pass; exact hits have zero provider operations.

- [ ] **Step 7: Commit runtime completion**

```bash
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice \
  backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/ApiExceptionHandler.java \
  backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice
git commit -m "feat: complete private custom scene generation loop"
```

---

### Task 12: Wire fail-closed Helm provider configuration and secret handling

**Files:**
- Modify: `deploy/helm/babytalk-app/templates/configmap.yaml`
- Modify: `deploy/helm/babytalk-app/templates/deployment.yaml`
- Modify: `deploy/helm/babytalk-app/templates/secret.yaml`
- Modify: `deploy/helm/babytalk-app/values.yaml`
- Modify: `deploy/helm/babytalk-app/values-kind.yaml`
- Modify: `deploy/helm/babytalk-app/values-kind-qa.yaml`
- Modify: `deploy/helm/babytalk-app/values-production.yaml`
- Create: `deploy/helm/babytalk-app/templates/practice-ai-configmap.yaml`
- Create: `tool/verify_practice_ai_helm.dart`
- Create: `test/tool/verify_practice_ai_helm_test.dart`
- Modify: `tool/verify_m007_s01_helm_baseline.dart`
- Modify: `test/tool/verify_m007_s01_helm_baseline_test.dart`

**Interfaces:**
- Helm renders named provider definitions and capability routes into a mounted YAML file.
- API keys remain Kubernetes Secrets and are exposed only through named environment variables.

- [ ] **Step 1: Add failing Helm verifier cases**

Verify rendered manifests contain:

- `practice-ai-runtime.yml` ConfigMap data with named providers and ordered routes.
- no literal API key in ConfigMap, Deployment args, or annotations.
- Secret keys for each configured provider.
- `SPRING_CONFIG_ADDITIONAL_LOCATION=/config/practice-ai-runtime.yml` or equivalent mount.
- fake mode only in kind/dev values, never production.
- agentic production values require generator, judge, and repair routes.
- every provider has a positive `timeout`, omits hidden retry settings, and sets at most one of `maxTokens` or `maxCompletionTokens`.
- `temperature` is optional and no chart default forces it onto reasoning models.

- [ ] **Step 2: Add nested provider and capability values**

Add chart values:

```yaml
practiceAi:
  routingPolicyVersion: custom-scene-routing-v1
  providers:
    primary:
      type: openai-compatible
      baseUrl: https://models.inference.ai.azure.com
      apiKeyEnvironmentVariable: BABY_TALK_AI_PROVIDER_PRIMARY_API_KEY
      model: gpt-4o-mini
      timeout: 20s
      maxTokens: 600
      # temperature is optional; omit it for GPT-5/o-series reasoning models.
      # maxCompletionTokens is the mutually exclusive alternative.
  capabilities:
    custom-scene-generator: [primary]
    custom-scene-quality-judge: [primary]
    custom-scene-repair: [primary]
```

Render this as Spring YAML, not a JSON string environment variable.

- [ ] **Step 3: Keep provider credentials only in Secret values**

Add Secret value keys such as:

```yaml
secret:
  BABY_TALK_AI_PROVIDER_PRIMARY_API_KEY: change-me
```

The Deployment maps the Secret key to the exact environment variable named by the provider definition. Do not write credentials to `values-production.yaml` beyond existing explicit placeholder conventions; deployment documentation must direct operators to external secret injection.

- [ ] **Step 4: Run Helm and verifier tests**

```bash
cd "$(git rev-parse --show-toplevel)"
helm template babytalk deploy/helm/babytalk-app -f deploy/helm/babytalk-app/values-kind.yaml >/tmp/babytalk-rendered.yaml
dart test test/tool/verify_practice_ai_helm_test.dart
dart run tool/verify_practice_ai_helm.dart
```

Expected: chart renders, verifier passes, and `/tmp/babytalk-rendered.yaml` contains no configured secret value.

- [ ] **Step 5: Commit deployment wiring**

```bash
git add deploy/helm/babytalk-app tool/verify_practice_ai_helm.dart test/tool/verify_practice_ai_helm_test.dart
git commit -m "feat: configure custom scene AI providers in helm"
```

---

### Task 13: Add end-to-end, privacy, concurrency, and full regression verification

**Files:**
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/CustomSceneAgenticGenerationIntegrationTest.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGenerationAuditPrivacyTest.java`
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/PracticeDiscoveryControllerTest.java`
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentConcurrencyTest.java`
- Create: `tool/verify_practice_generation_privacy.py`
- Create: `test/tool/verify_practice_generation_privacy_test.py`
- Modify: `docs/superpowers/specs/2026-07-14-custom-scene-agentic-generation-approved-output-reuse-design.md` only to add implementation-proof links after code exists.

**Interfaces:**
- This task proves the first-scope acceptance criteria and intentionally leaves semantic/global reuse unimplemented.

- [ ] **Step 1: Add an end-to-end Testcontainers flow with stub ChatClients**

The integration test must execute through `POST /api/v1/practice/discovery` and assert:

1. first request persists draft, attempt, evidence bundle/items, operation/provider calls, Judge result, and active content.
2. `normalized_scene_text` is null after activation.
3. response contains composed `coachTipZh`.
4. second identical request returns the same active `generatedContentId`.
5. second request adds no provider-call rows.
6. terminal rows contain no raw scene, prompt, response, or raw error columns because such columns do not exist.

Use deterministic stub provider clients; do not call an external model.

- [ ] **Step 2: Add negative integration paths**

Cover:

```text
bidi input -> 422, zero draft rows
insufficient evidence -> expired/retryable, zero Generator calls
daily generation quota denial -> expired/429, zero Generator calls
Judge provider exhaustion -> expired/retryable
terminal generated-output PII -> rejected/non-retryable
repair then PASS -> active with two attempts and two evidence bundles
attempts exhausted -> rejected
```

- [ ] **Step 3: Add database concurrency tests**

Use real PostgreSQL/Testcontainers to cover:

- two identical requests reserve one live lineage and make one Generator operation.
- a terminal row allows a new retry row.
- stale cleanup racing with completion cannot revive or overwrite an active row.
- two cleanup workers do not double-complete the same started provider call.

Use database unique constraints and row-level locking; do not rely on synchronized JVM blocks.

- [ ] **Step 4: Add privacy/static verifier**

`tool/verify_practice_generation_privacy.py` scans production Java, mapper XML, SQL, and search/index DTOs and fails when any audit/entity mapping introduces forbidden fields:

```text
security_text
risk_signals
raw_scene
raw_prompt
prompt_body
raw_response
response_body
raw_error
raw_chunk
chain_of_thought
```

It also verifies `coach_tip_zh` is absent from V25 and generated-content mapper XML, and that `securityText` is referenced only inside approved input-security/fingerprint classes. It fails if production custom-scene code contains `.validateSchema(`, `new OpenAiApi`, or a configured retry count other than the hard-coded zero-retry options factory.

It also fails when the private-generation schema/runtime still contains
`promoted` or `global_candidate`, when required response metadata/slugs are
removed, or when current-key lookup and cross-version cleanup lose their B2.1
boundaries.

- [ ] **Step 5: Run the complete first-scope verification matrix**

Run focused unit and integration tests:

```bash
cd "$(git rev-parse --show-toplevel)/backend"
bash mvnw -pl app-api -Dtest='SceneTextCanonicalizerTest,SceneTextSecurityPolicyTest,VersionedResourceRegistryTest,PracticeAiProviderManagerTest,PracticeAiOperationRunnerTest,PracticeAiOpenAiOptionsFactoryTest,PracticeAiStructuredOutputCallerTest,PracticeAiSingleRequestContractTest,EvidenceSanitizerTest,EvidenceBundleFactoryTest,AgenticCustomSceneGeneratorTest,CustomSceneGeneratedContentValidatorTest,JudgeVerdictCalculatorTest,AgenticCustomSceneQualityJudgeTest,CustomSceneGenerationOrchestratorTest,PracticeGenerationInterruptionTest,CustomSceneAgenticGenerationIntegrationTest,PracticeGenerationAuditPrivacyTest,PracticeGeneratedContentConcurrencyTest' test
bash mvnw -pl db-migration -Dtest=DbMigrationSmokeTest test
```

Run the reviewed B2.1 hardening regression set before the full module run:

```bash
cd "$(git rev-parse --show-toplevel)/backend"
bash mvnw -pl app-api -Dtest='SceneTextCanonicalizerTest,PolicyTextMatcherTest,PracticeGeneratedContentKeyFactoryTest,PracticeGeneratedContentMapperContractTest,PracticeGeneratedContentMapperTest,PracticeGeneratedContentServiceTest,PracticeGeneratedContentConcurrencyTest,PracticeGeneratedContentOwnerPropertiesTest,CustomSceneGeneratedContentValidatorTest,CustomSceneGenerationProviderWiringTest,PracticeDiscoveryCustomScenePropertiesTest,PracticeDiscoveryPolicyPropertiesTest,PracticeDiscoveryServiceTest,PracticeDiscoveryControllerTest,PracticeCatalogMapperTest,PracticeCatalogServiceTest,BabyProfileMapperTest,BabyProfileServiceTest,AuthConsentSyncWebTest' test
bash mvnw -pl db-migration -Dtest=DbMigrationSmokeTest test
```

Run module regressions:

```bash
cd "$(git rev-parse --show-toplevel)/backend"
bash mvnw -pl app-api,db-migration -am test
```

Run static verifiers:

```bash
cd "$(git rev-parse --show-toplevel)"
python3 tool/verify_spring_ai_2_backend_platform.py
python3 tool/verify_practice_ai_version_lock.py --verify
python3 tool/verify_practice_generation_privacy.py
python3 test/tool/verify_practice_generation_privacy_test.py
dart run tool/verify_practice_ai_helm.dart
git diff --check
```

Expected: all commands exit `0`.

- [ ] **Step 6: Perform the plan self-audit against the approved spec**

Confirm the implementation proves first-scope acceptance criteria:

```text
exact owner hit -> zero provider calls
new content cannot activate without deterministic PASS + effective Judge PASS
Repair always creates a new attempt/bundle and receives a new Judge
one immutable evidence bundle per attempt
all real provider calls audited without prompt/response/private text
one named-provider attempt -> one outbound request -> one provider-call row
custom-scene clients use maxRetries(0) and no validateSchema() hidden repair retry
terminal executions never revived
same version cannot silently change prompt/policy content
fake mode dev/test-only
```

Explicitly record these deferred items as out of scope, not missing implementation:

```text
owner-private semantic reuse
Scene Abstraction
Reuse Match
Reuse Eligibility
public Approved Output Assets
Global Index
asset requalification
```

- [ ] **Step 7: Commit verification and proof links**

```bash
git add backend/app-api/src/test backend/db-migration/src/test \
  tool/verify_practice_generation_privacy.py test/tool/verify_practice_generation_privacy_test.py \
  docs/superpowers/specs/2026-07-14-custom-scene-agentic-generation-approved-output-reuse-design.md
git commit -m "test: verify custom scene agentic generation"
```

---

## Final Review Gate

Before declaring the implementation complete:

1. Confirm the development branch contains the reviewed B2.1 baseline as a
   separate commit or isolated worktree. Record base commit
   `d8960d1c9a68c2dd666cf697b047c0faa367a789` and patch SHA-256
   `e7e6c40fee445ba49eb24d82ad3b9b88ba62cf61d79771ec5d8d69ea5205b2e4`
   in the review evidence.
2. Run `python3 tool/verify_spring_ai_2_backend_platform.py` and confirm the
   prerequisite platform remains Boot 4.0.7 / Spring AI 2.0.0 before running
   feature verification.
3. Run `git status --short` and verify only intentional files remain.
4. Confirm no provider secret, prompt body, model response, raw scene, or raw
   evidence chunk appears in `git diff` outside approved resource prompts and
   test fixtures.
5. Confirm whether V25 or V26 has run outside a disposable Testcontainers schema.
   If so, generated-content follow-up uses additive V27+ migrations and reruns all
   migration tests; neither historical migration may be edited.
6. Confirm production Helm values cannot select fake mode.
7. Confirm the public API still exposes one complete directly speakable
   utterance and composed guidance, without course, score, completion, reward,
   or child-performance language.
8. Confirm one named-provider attempt produces exactly one outbound request and
   one provider-call row, including 429/5xx and malformed structured-output
   cases.
9. Request code review before merging or pushing.
