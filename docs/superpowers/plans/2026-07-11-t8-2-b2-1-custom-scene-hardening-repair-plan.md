# T8.2 B2.1 Custom Scene Hardening Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the remaining B2.1 review gaps so custom-scene discovery accepts legitimate unlisted baby-care moments, preserves scene privacy, canonicalizes Unicode safely, validates generated output without false positives, cleans retained data across key versions, and exposes no generic CRUD path around the generated-content state machine.

**Architecture:** Introduce focused text-policy and cryptographic helpers instead of adding more responsibilities to `PracticeGeneratedContentService`. Local deterministic validation will reject PII, injection, clearly unsupported intent, malformed metadata, and unsafe generated output; known scene intents remain optional alignment hints rather than an allow-list. Registry cleanup becomes key-version agnostic for privacy operations, while lookup/idempotency remains bound to the active owner-key version.

**Tech Stack:** Java 21, Spring Boot, MyBatis/MyBatis-Plus annotations already present in the project, PostgreSQL, Flyway V25 (still uncommitted and therefore editable), Hutool, JUnit 5, Mockito, Testcontainers, Maven.

## Global Constraints

- Preserve canonical endpoint `POST /api/v1/practice/discovery`.
- Preserve implemented combinations `surface=onboarding` with `mode=catalog|custom_scene`.
- Do not add `/api/v1/care-turns`, Garden/Growth writes, mobile/mobile_v2/admin-web changes, public `/api/v1/mentor/chat` calls, curated promotion UI, or a real network-backed agentic provider.
- `OffsetDateTime` remains the Java database/API timestamp type and is normalized to UTC.
- `normalized_scene_text` is private transient input: it may exist only while a draft is live and must be cleared on every terminal transition.
- Lookup, idempotency, and rate-limit accounting remain bound to the current `owner_key_version`; privacy cleanup must work across all historical key versions.
- Unknown but plausible family-care scenes must not be rejected only because they are absent from the deterministic `scene-intents` map.
- Current fake provider may support a finite fixture set; unsupported fake scenes return a typed generation-unavailable error rather than unrelated content.
- No production code may call inherited generic mapper mutations to bypass reservation/state-transition rules.
- Follow TDD: each task starts with failing tests, then minimal implementation, then focused and regression verification.
- Do not commit during implementation review unless the user explicitly authorizes commits. The commit commands in this plan are handoff checkpoints to run only after approval.

---

## File Structure

### New focused components

- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/SceneTextCanonicalizer.java`
  - NFKC normalization, Unicode whitespace collapse, grapheme count, and code-point count.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/PolicyTextMatcher.java`
  - Boundary-aware Latin matching and reviewed CJK phrase matching.
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentKeyFactory.java`
  - Domain-separated owner HMAC, installation reference hash, request fingerprint HMAC, and stable slug digest.
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/SceneTextCanonicalizerTest.java`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/PolicyTextMatcherTest.java`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentKeyFactoryTest.java`
- `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentMapperContractTest.java`

### Existing files modified by the repair

- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentService.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentMapper.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentWriteService.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneGeneratedContentValidator.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneIntentClassifier.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/FakeCustomSceneGenerationService.java`
- `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/PracticeDiscoveryPolicyProperties.java`
- `backend/app-api/src/main/resources/config/practice-discovery-policy.yml`
- `backend/app-api/src/main/resources/mapper/practice/generated/PracticeGeneratedContentMapper.xml`
- `backend/db-migration/src/main/resources/db/migration/V25__create_practice_generated_content.sql`
- Existing generated-content, discovery-policy, provider-wiring, repository/mapper, concurrency, and migration tests.
- `docs/superpowers/plans/2026-07-03-t8-2-b2-1-practice-generated-content-custom-scene-plan.md`

---

### Task 1: Add canonical Unicode text handling and boundary-aware policy matching

**Files:**
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/SceneTextCanonicalizer.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/PolicyTextMatcher.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/SceneTextCanonicalizerTest.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/PolicyTextMatcherTest.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/PracticeDiscoveryPolicyProperties.java`
- Modify: `backend/app-api/src/main/resources/config/practice-discovery-policy.yml`

**Interfaces:**
- Produces: `String SceneTextCanonicalizer.canonicalize(String value)`
- Produces: `int SceneTextCanonicalizer.graphemeLength(String value)`
- Produces: `int SceneTextCanonicalizer.codePointLength(String value)`
- Produces: `boolean PolicyTextMatcher.containsAny(String text, Collection<String> markers)`
- Produces: `boolean PolicyTextMatcher.containsMarker(String text, String marker)`
- Consumed by: Tasks 2, 3, and 4.

- [ ] **Step 1: Write canonicalization tests that demonstrate current failures**

```java
package com.zhangspaghetti.babytalk.practice.discovery;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class SceneTextCanonicalizerTest {

    private final SceneTextCanonicalizer canonicalizer = new SceneTextCanonicalizer();

    @Test
    void canonicalizesCompatibilityCharactersAndWhitespace() {
        assertThat(canonicalizer.canonicalize("  宝宝　　不肯\n穿鞋  "))
                .isEqualTo("宝宝 不肯 穿鞋");
        assertThat(canonicalizer.canonicalize("ＡＢＣ１２３"))
                .isEqualTo("ABC123");
    }

    @Test
    void equivalentSceneTextHasOneCanonicalRepresentation() {
        assertThat(canonicalizer.canonicalize("宝宝不肯穿鞋"))
                .isEqualTo(canonicalizer.canonicalize("  宝宝不肯穿鞋  "));
        assertThat(canonicalizer.canonicalize("宝宝  不肯穿鞋"))
                .isEqualTo(canonicalizer.canonicalize("宝宝　不肯穿鞋"));
    }

    @Test
    void exposesGraphemeAndDatabaseCodePointLengthsSeparately() {
        var family = "👨‍👩‍👧‍👦".repeat(80);
        assertThat(canonicalizer.graphemeLength(family)).isEqualTo(80);
        assertThat(canonicalizer.codePointLength(family)).isGreaterThan(160);
    }
}
```

- [ ] **Step 2: Write matcher tests for English boundaries and reviewed CJK phrases**

```java
package com.zhangspaghetti.babytalk.practice.discovery;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import org.junit.jupiter.api.Test;

class PolicyTextMatcherTest {

    private final PolicyTextMatcher matcher =
            new PolicyTextMatcher(new SceneTextCanonicalizer());

    @Test
    void latinMarkersUseWordBoundaries() {
        assertThat(matcher.containsAny("Let's test the water.", List.of("test"))).isTrue();
        assertThat(matcher.containsAny("A useful skill.", List.of("kill"))).isFalse();
        assertThat(matcher.containsAny("Take a quiz.", List.of("quiz"))).isTrue();
    }

    @Test
    void cjkMarkersMatchPhrasesWithoutSingleCharacterFalsePositives() {
        assertThat(matcher.containsAny("注意安全性。", List.of("性行为", "色情内容"))).isFalse();
        assertThat(matcher.containsAny("内容涉及色情内容。", List.of("性行为", "色情内容"))).isTrue();
    }

    @Test
    void matchingUsesTheSameNfkcNormalizationAsPersistence() {
        assertThat(matcher.containsAny("ＷＥＣＨＡＴ abc", List.of("wechat"))).isTrue();
    }
}
```

- [ ] **Step 3: Run the tests and verify they fail because the new types do not exist**

Run:

```powershell
Push-Location C:\code\AI\baby-talk-2\backend
try {
  mvn test -pl app-api -Dtest=SceneTextCanonicalizerTest,PolicyTextMatcherTest
} finally {
  Pop-Location
}
```

Expected: compilation failure for missing `SceneTextCanonicalizer` and `PolicyTextMatcher`.

- [ ] **Step 4: Implement `SceneTextCanonicalizer`**

```java
package com.zhangspaghetti.babytalk.practice.discovery;

import java.text.BreakIterator;
import java.text.Normalizer;
import java.util.Locale;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;

@Component
public final class SceneTextCanonicalizer {

    private static final Pattern WHITESPACE = Pattern.compile("[\\p{Z}\\s]+");

    public String canonicalize(String value) {
        if (value == null) {
            return null;
        }
        var normalized = Normalizer.normalize(value, Normalizer.Form.NFKC);
        normalized = WHITESPACE.matcher(normalized).replaceAll(" ").trim();
        return normalized.isEmpty() ? null : normalized;
    }

    public int graphemeLength(String value) {
        if (value == null || value.isEmpty()) {
            return 0;
        }
        var iterator = BreakIterator.getCharacterInstance(Locale.ROOT);
        iterator.setText(value);
        var count = 0;
        for (var start = iterator.first(), end = iterator.next();
             end != BreakIterator.DONE;
             start = end, end = iterator.next()) {
            if (!value.substring(start, end).isBlank()) {
                count++;
            }
        }
        return count;
    }

    public int codePointLength(String value) {
        return value == null ? 0 : value.codePointCount(0, value.length());
    }
}
```

- [ ] **Step 5: Implement `PolicyTextMatcher`**

```java
package com.zhangspaghetti.babytalk.practice.discovery;

import java.util.Collection;
import java.util.Locale;
import java.util.regex.Pattern;
import org.springframework.stereotype.Component;

@Component
public final class PolicyTextMatcher {

    private static final Pattern CJK = Pattern.compile("[\\p{IsHan}]");
    private final SceneTextCanonicalizer canonicalizer;

    public PolicyTextMatcher(SceneTextCanonicalizer canonicalizer) {
        this.canonicalizer = canonicalizer;
    }

    public boolean containsAny(String text, Collection<String> markers) {
        if (text == null || markers == null || markers.isEmpty()) {
            return false;
        }
        return markers.stream().anyMatch(marker -> containsMarker(text, marker));
    }

    public boolean containsMarker(String text, String marker) {
        var canonicalText = canonicalizer.canonicalize(text);
        var canonicalMarker = canonicalizer.canonicalize(marker);
        if (canonicalText == null || canonicalMarker == null) {
            return false;
        }
        var searchable = canonicalText.toLowerCase(Locale.ROOT);
        var needle = canonicalMarker.toLowerCase(Locale.ROOT);
        if (CJK.matcher(needle).find()) {
            return searchable.contains(needle);
        }
        var boundaryPattern = Pattern.compile(
                "(?<![\\p{L}\\p{N}_])" + Pattern.quote(needle)
                        + "(?![\\p{L}\\p{N}_])",
                Pattern.CASE_INSENSITIVE | Pattern.UNICODE_CASE);
        return boundaryPattern.matcher(searchable).find();
    }
}
```

- [ ] **Step 6: Make policy configuration reject ambiguous one-character CJK markers**

Add this validation to `PracticeDiscoveryPolicyProperties.normalizedRequiredList(...)` after normalization:

```java
for (var marker : normalized) {
    if (marker.codePointCount(0, marker.length()) == 1
            && Character.UnicodeScript.of(marker.codePointAt(0))
                    == Character.UnicodeScript.HAN) {
        throw new IllegalArgumentException(
                "practice discovery policy " + field
                        + " must not contain ambiguous one-character CJK markers: " + marker);
    }
}
```

Update `practice-discovery-policy.yml` by replacing ambiguous entries:

```yaml
validator-adult-violent-sexual:
  - kill
  - blood
  - weapon
  - gun
  - knife
  - sex
  - sexual
  - porn
  - adult
  - 杀死
  - 流血
  - 武器
  - 枪支
  - 刀具
  - 性行为
  - 色情内容
  - 成人内容
```

Keep `test` as a full English token; boundary matching prevents it from matching unrelated larger words. Remove any single-character CJK marker from all policy lists.

- [ ] **Step 7: Run focused tests**

Run:

```powershell
Push-Location C:\code\AI\baby-talk-2\backend
try {
  mvn test -pl app-api -Dtest=SceneTextCanonicalizerTest,PolicyTextMatcherTest,PracticeDiscoveryPolicyPropertiesTest
} finally {
  Pop-Location
}
```

Expected: all tests pass.

- [ ] **Step 8: Record the checkpoint**

After explicit user approval only:

```powershell
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/SceneTextCanonicalizer.java `
        backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/PolicyTextMatcher.java `
        backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/PracticeDiscoveryPolicyProperties.java `
        backend/app-api/src/main/resources/config/practice-discovery-policy.yml `
        backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/SceneTextCanonicalizerTest.java `
        backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/PolicyTextMatcherTest.java `
        backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/PracticeDiscoveryPolicyPropertiesTest.java
git commit -m "fix: canonicalize custom scene policy text"
```

---

### Task 2: Decouple custom-scene eligibility from the finite known-intent map

**Files:**
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentService.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneIntentClassifier.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneGeneratedContentValidator.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/FakeCustomSceneGenerationService.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/PracticeDiscoveryPolicyProperties.java`
- Modify: `backend/app-api/src/main/resources/config/practice-discovery-policy.yml`
- Test: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentServiceTest.java`
- Test: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneGeneratedContentValidatorTest.java`
- Test: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneGenerationProviderWiringTest.java`

**Interfaces:**
- Consumes: `SceneTextCanonicalizer`, `PolicyTextMatcher` from Task 1.
- Produces: canonical input accepted after negative safety checks even when `CustomSceneIntentClassifier.classifyAll(...)` returns an empty list.
- Produces: known intents remain alignment hints; they are not admission requirements.
- Produces: fake provider throws `GenerationUnavailableException("fake_scene_not_supported", false)` for unrecognized fixtures instead of returning unrelated bath content.

- [ ] **Step 1: Add tests for legitimate unlisted family-care scenes**

Add parameterized tests to `PracticeGeneratedContentServiceTest`:

```java
@ParameterizedTest
@ValueSource(strings = {
        "给宝宝剪指甲时总是乱动",
        "擦鼻涕时宝宝一直躲",
        "上安全座椅时宝宝哭",
        "给宝宝涂防晒",
        "量体温时宝宝不肯配合",
        "洗手时宝宝一直玩水"
})
void acceptsSafeUnlistedCareScenesBeforeProviderSelection(String sceneText) {
    mutableGenerator.failWithUnavailable("fake_scene_not_supported", false);

    var exception = assertThrows(ContractException.class,
            () -> service.generateCustomScene(request(sceneText)));

    assertThat(exception.code()).isEqualTo("generation_unavailable");
    assertThat(exception.details()).containsEntry("reason", "fake_scene_not_supported");
    assertThat(exception.details()).doesNotContainEntry("reason", "non_caregiving_scene");
}
```

Add a regression showing a clearly unsupported request still fails locally:

```java
@Test
void rejectsClearlyUnsupportedNonCareRequest() {
    var exception = assertThrows(ContractException.class,
            () -> service.generateCustomScene(request("帮我完成编程作业和考试答案")));

    assertThat(exception.code()).isEqualTo("unsupported_custom_scene_text");
    verifyNoInteractions(mutableGenerator);
}
```

- [ ] **Step 2: Add validator tests showing unknown intent is not rejected by the deterministic map**

```java
@Test
void unknownSceneIntentDoesNotFailOnlyBecauseClassifierHasNoEntry() {
    var candidate = validCandidate(
            "日常照护",
            "涂防晒",
            "sunscreen_time",
            "出门前轻轻说。",
            "Let's put on sunscreen.",
            "我们来涂防晒。"
    );

    assertThat(validator.normalizeAndValidate(
            candidate,
            ContentConstraints.defaults(),
            new GeneratedOutputValidationContext("给宝宝涂防晒")))
            .isEqualTo(candidate);
}
```

Keep a known-intent mismatch test:

```java
@Test
void knownShoesIntentStillRejectsBathOutput() {
    var exception = assertThrows(RejectedGeneratedContentException.class,
            () -> validator.normalizeAndValidate(
                    bathCandidate(),
                    ContentConstraints.defaults(),
                    new GeneratedOutputValidationContext("给宝宝穿鞋")));

    assertThat(exception.reason()).isEqualTo("scene_intent_mismatch");
}
```

- [ ] **Step 3: Run focused tests and verify current allow-list behavior fails them**

Run:

```powershell
Push-Location C:\code\AI\baby-talk-2\backend
try {
  mvn test -pl app-api -Dtest=PracticeGeneratedContentServiceTest,CustomSceneGeneratedContentValidatorTest
} finally {
  Pop-Location
}
```

Expected: failures with `unsupported_custom_scene_text` or `scene_intent_unclassified`.

- [ ] **Step 4: Remove the known-intent coverage invariant from policy binding**

In `PracticeDiscoveryPolicyProperties`:

- Remove the call to `validateCareIntentCoverage(careOrientation, sceneIntents)`.
- Delete the `validateCareIntentCoverage(...)` method.
- Keep `sceneIntents` validation for nonblank keys and nonempty request/output marker lists.
- Rename `careOrientation` to `careContextMarkers` only if all call sites and YAML are changed in the same task; otherwise retain the serialized property name but stop treating it as a complete intent allow-list.

Use this broad context list in YAML:

```yaml
care-context-markers:
  - baby
  - child
  - toddler
  - parent
  - mom
  - dad
  - 宝宝
  - 宝贝
  - 孩子
  - 娃
  - 妈妈
  - 爸爸
  - 照护
```

If the Java field is renamed, update the record field to `List<String> careContextMarkers` and update all tests and fixture constructors.

- [ ] **Step 5: Change input admission to negative safety checks plus contextual evidence**

Replace the final hard allow-list check in `validateAndNormalizeCustomSceneText(...)` with:

```java
var knownIntents = intentClassifier.classifyAll(normalized);
var hasCareContext = policyTextMatcher.containsAny(
        normalized, policyProperties.careContextMarkers());
if (knownIntents.isEmpty() && !hasCareContext) {
    // The endpoint is already a baby-care custom-scene surface. Do not reject
    // safe ambiguous text here; provider adapters remain responsible for
    // rejecting genuinely non-care content. Keep only explicit unsupported
    // intent rejection in the local policy gate.
}
return normalized;
```

Do not leave an empty `if` block in production. The final implementation is:

```java
if (policyTextMatcher.containsAny(searchable, policyProperties.promptInjectionMarkers())
        || policyTextMatcher.containsAny(searchable, policyProperties.unsupportedIntents())) {
    throw unsupportedCustomSceneText("unsupported_intent");
}
return normalized;
```

The local service must no longer throw `non_caregiving_scene` merely because no deterministic marker matched.

- [ ] **Step 6: Make known-intent alignment conditional rather than mandatory**

Replace this validator behavior:

```java
if (classifiedIntents.isEmpty()) {
    throw new RejectedGeneratedContentException("scene_intent_unclassified");
}
```

with:

```java
if (!classifiedIntents.isEmpty()
        && classifiedIntents.stream()
                .noneMatch(intent -> intentClassifier.matchesOutput(intent, combined))) {
    throw new RejectedGeneratedContentException("scene_intent_mismatch");
}
```

Remove the hard `generatedCareKeywords` requirement for unclassified scenes. For classified scenes, the explicit intent-output marker check is the deterministic alignment gate.

- [ ] **Step 7: Stop fake provider from returning unrelated fallback content**

In `FakeCustomSceneGenerationService`, after checking all supported fixture intents, replace the bath/default fallback with:

```java
throw new CustomSceneGenerationService.GenerationUnavailableException(
        "fake_scene_not_supported",
        false);
```

The fake provider continues to support its explicit fixture set and never invents unrelated content for an unknown scene.

- [ ] **Step 8: Run service, validator, and real Spring wiring tests**

Run:

```powershell
Push-Location C:\code\AI\baby-talk-2\backend
try {
  mvn test -pl app-api -Dtest=PracticeGeneratedContentServiceTest,CustomSceneGeneratedContentValidatorTest,CustomSceneGenerationProviderWiringTest
} finally {
  Pop-Location
}
```

Expected: all tests pass; safe unlisted scenes reach the provider boundary; fake unknown scenes return typed unavailable; known mismatches remain rejected.

- [ ] **Step 9: Record the checkpoint**

After explicit user approval only:

```powershell
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentService.java `
        backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneIntentClassifier.java `
        backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneGeneratedContentValidator.java `
        backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/FakeCustomSceneGenerationService.java `
        backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/PracticeDiscoveryPolicyProperties.java `
        backend/app-api/src/main/resources/config/practice-discovery-policy.yml `
        backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentServiceTest.java `
        backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneGeneratedContentValidatorTest.java `
        backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneGenerationProviderWiringTest.java
git commit -m "fix: keep custom scene discovery open ended"
```

---

### Task 3: Replace plain request fingerprints with owner-scoped HMAC fingerprints

**Files:**
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentKeyFactory.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentKeyFactoryTest.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentService.java`
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentServiceTest.java`

**Interfaces:**
- Produces: `String ownerKey(String ownerScope, String rawOwnerMaterial)`
- Produces: `String installationRefHash(String installationId)`
- Produces: `String requestFingerprint(String ownerKey, RequestFingerprintMaterial material)`
- Produces: `String stableDigest(String value)` for nonsecret slug derivation after the request fingerprint is already protected.
- Consumes: `PracticeGeneratedContentOwnerProperties.keySecret()` and `.keyVersion()`.

- [ ] **Step 1: Write cryptographic behavior tests**

```java
package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class PracticeGeneratedContentKeyFactoryTest {

    private final PracticeGeneratedContentKeyFactory factory =
            new PracticeGeneratedContentKeyFactory(
                    new PracticeGeneratedContentOwnerProperties(
                            "v1",
                            "0123456789abcdef0123456789abcdef"));

    @Test
    void sameOwnerAndCanonicalRequestProduceStableFingerprint() {
        var material = material("宝宝 不肯穿鞋");
        assertThat(factory.requestFingerprint("owner_a", material))
                .isEqualTo(factory.requestFingerprint("owner_a", material));
    }

    @Test
    void differentOwnersCannotBeComparedByPlainSceneHash() {
        var material = material("宝宝 不肯穿鞋");
        assertThat(factory.requestFingerprint("owner_a", material))
                .isNotEqualTo(factory.requestFingerprint("owner_b", material));
    }

    @Test
    void fingerprintDoesNotEqualPlainSha256OfCanonicalRequest() {
        var material = material("宝宝 不肯穿鞋");
        assertThat(factory.requestFingerprint("owner_a", material))
                .startsWith("fp_")
                .doesNotContain("宝宝");
    }

    private PracticeGeneratedContentKeyFactory.RequestFingerprintMaterial material(String scene) {
        return new PracticeGeneratedContentKeyFactory.RequestFingerprintMaterial(
                "onboarding", "custom_scene", scene, "12_18m",
                "daily_care", "zh-CN", "prompt-v1", "strategy-v1", "policy-v2");
    }
}
```

- [ ] **Step 2: Run the test and verify the factory is missing**

Run:

```powershell
Push-Location C:\code\AI\baby-talk-2\backend
try {
  mvn test -pl app-api -Dtest=PracticeGeneratedContentKeyFactoryTest
} finally {
  Pop-Location
}
```

Expected: compilation failure for missing `PracticeGeneratedContentKeyFactory`.

- [ ] **Step 3: Implement domain-separated HMAC operations**

```java
package com.zhangspaghetti.babytalk.practice.generated;

import java.nio.charset.StandardCharsets;
import java.security.InvalidKeyException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.stereotype.Component;

@Component
public final class PracticeGeneratedContentKeyFactory {

    private static final String HMAC_ALGORITHM = "HmacSHA256";
    private final byte[] secret;
    private final String keyVersion;

    public PracticeGeneratedContentKeyFactory(PracticeGeneratedContentOwnerProperties properties) {
        this.secret = properties.keySecret().getBytes(StandardCharsets.UTF_8);
        this.keyVersion = properties.keyVersion();
    }

    public String ownerKey(String ownerScope, String rawOwnerMaterial) {
        return "owner_" + hmacHex(
                "practice-owner-key:v1|" + keyVersion + "|" + ownerScope + "|" + rawOwnerMaterial);
    }

    public String installationRefHash(String installationId) {
        return "installation_" + hmacHex(
                "practice-installation-ref:v1|" + keyVersion + "|" + installationId);
    }

    public String requestFingerprint(String ownerKey, RequestFingerprintMaterial material) {
        var canonicalRequest = String.join("|",
                "surface=" + material.surface(),
                "mode=" + material.mode(),
                "scene=" + material.canonicalSceneText(),
                "age=" + material.ageRange(),
                "goal=" + material.parentGoal(),
                "locale=" + material.locale(),
                "prompt=" + material.promptVersion(),
                "strategy=" + material.strategyVersion(),
                "policy=" + material.policyVersion());
        return "fp_" + hmacHex(
                "practice-request-fingerprint:v1|" + keyVersion + "|" + ownerKey + "|" + canonicalRequest);
    }

    public String stableDigest(String value) {
        try {
            var digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 unavailable", exception);
        }
    }

    private String hmacHex(String value) {
        try {
            var mac = Mac.getInstance(HMAC_ALGORITHM);
            mac.init(new SecretKeySpec(secret, HMAC_ALGORITHM));
            return HexFormat.of().formatHex(mac.doFinal(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException | InvalidKeyException exception) {
            throw new IllegalStateException("HmacSHA256 unavailable", exception);
        }
    }

    public record RequestFingerprintMaterial(
            String surface,
            String mode,
            String canonicalSceneText,
            String ageRange,
            String parentGoal,
            String locale,
            String promptVersion,
            String strategyVersion,
            String policyVersion
    ) {
    }
}
```

- [ ] **Step 4: Inject and use the key factory in `PracticeGeneratedContentService`**

Constructor dependency:

```java
private final PracticeGeneratedContentKeyFactory keyFactory;
```

Replace owner creation:

```java
keyFactory.ownerKey(OWNER_PROFILE, accountId + ":" + request.profileId())
keyFactory.ownerKey(OWNER_ACCOUNT, accountId)
keyFactory.ownerKey(OWNER_INSTALLATION, installationId)
keyFactory.installationRefHash(installationId)
```

Replace `fingerprint(...)` with:

```java
private String fingerprint(
        CustomSceneDiscoveryRequest request,
        OwnerContext owner,
        String normalizedSceneText
) {
    return keyFactory.requestFingerprint(
            owner.ownerKey(),
            new PracticeGeneratedContentKeyFactory.RequestFingerprintMaterial(
                    request.surface(),
                    request.mode(),
                    normalizedSceneText,
                    request.ageRange(),
                    request.parentGoal(),
                    request.locale(),
                    promptVersion(),
                    strategyVersion(),
                    policyVersion()));
}
```

Replace slug/id SHA calls with `keyFactory.stableDigest(...)`. Remove service imports and fields for `MessageDigest`, `Mac`, `SecretKeySpec`, `HexFormat`, `InvalidKeyException`, and `NoSuchAlgorithmException`. Remove `hmacOwnerKey(...)` and `sha256(...)` from the service.

- [ ] **Step 5: Add service-level regression tests**

Add tests proving:

```java
@Test
void canonicalEquivalentSceneInputsReuseOneFingerprint() {
    var first = service.generateCustomScene(request("宝宝  不肯穿鞋"));
    var second = service.generateCustomScene(request("宝宝　不肯穿鞋"));
    assertThat(second.generatedContentId()).isEqualTo(first.generatedContentId());
    assertThat(generatorCalls.get()).isEqualTo(1);
}

@Test
void sameSceneForDifferentOwnersDoesNotShareFingerprint() {
    var first = service.generateCustomScene(requestForInstallation("install-a", "宝宝不肯穿鞋"));
    var second = service.generateCustomScene(requestForInstallation("install-b", "宝宝不肯穿鞋"));
    assertThat(second.requestFingerprint()).isNotEqualTo(first.requestFingerprint());
}
```

- [ ] **Step 6: Run focused tests**

Run:

```powershell
Push-Location C:\code\AI\baby-talk-2\backend
try {
  mvn test -pl app-api -Dtest=PracticeGeneratedContentKeyFactoryTest,PracticeGeneratedContentServiceTest,PracticeGeneratedContentConcurrencyTest
} finally {
  Pop-Location
}
```

Expected: all tests pass and concurrency behavior remains unchanged.

- [ ] **Step 7: Record the checkpoint**

After explicit user approval only:

```powershell
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentKeyFactory.java `
        backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentService.java `
        backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentKeyFactoryTest.java `
        backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentServiceTest.java
git commit -m "fix: protect custom scene request fingerprints"
```

---

### Task 4: Harden generated-output privacy, metadata, prompt-echo, and physical-length validation

**Files:**
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneGeneratedContentValidator.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneGenerationService.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentService.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/PracticeDiscoveryPolicyProperties.java`
- Modify: `backend/app-api/src/main/resources/config/practice-discovery-policy.yml`
- Test: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneGeneratedContentValidatorTest.java`
- Test: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentServiceTest.java`

**Interfaces:**
- Consumes: `SceneTextCanonicalizer`, `PolicyTextMatcher`.
- Produces: every persisted string passes both product/grapheme limits and database code-point limits.
- Produces: `providerTraceId`, `retrievalTraceId`, and `modelName` accept opaque tokens only.
- Produces: generated display text is rejected for configured PII markers and verbatim/long-window input echo.
- Produces: provider request receives only canonical scene text, not both raw and canonical copies.

- [ ] **Step 1: Add output-privacy and length tests**

Add to `CustomSceneGeneratedContentValidatorTest`:

```java
@ParameterizedTest
@ValueSource(strings = {
        "加我微信 abc123。",
        "QQ 是 abc888。",
        "住址记录在这里。",
        "身份证信息如下。"
})
void rejectsConfiguredOutputPiiMarkers(String chineseText) {
    var exception = assertThrows(RejectedGeneratedContentException.class,
            () -> validator.normalizeAndValidate(
                    candidateWithChineseText(chineseText),
                    ContentConstraints.defaults(),
                    new GeneratedOutputValidationContext("给宝宝穿鞋")));
    assertThat(exception.reason()).isEqualTo("output_pii_leakage");
}

@Test
void rejectsNaturalLanguageInProviderTraceMetadata() {
    var candidate = validCandidate().withProviderTraceId("宝宝不肯穿鞋的原始输入");
    var exception = assertThrows(InvalidGeneratedContentException.class,
            () -> validator.normalizeAndValidate(candidate, ContentConstraints.defaults()));
    assertThat(exception.fieldName()).isEqualTo("providerTraceId");
}

@Test
void rejectsPromptEchoEvenWithoutInjectionKeywords() {
    var scene = "给宝宝剪指甲时总是乱动并且一直躲开";
    var candidate = candidateWithCoachTip(scene);
    var exception = assertThrows(RejectedGeneratedContentException.class,
            () -> validator.normalizeAndValidate(
                    candidate,
                    ContentConstraints.defaults(),
                    new GeneratedOutputValidationContext(scene)));
    assertThat(exception.reason()).isEqualTo("custom_scene_prompt_echo");
}

@Test
void rejectsDatabaseOverflowDespiteAcceptableGraphemeCount() {
    var candidate = candidateWithChineseText("👨‍👩‍👧‍👦".repeat(80));
    var exception = assertThrows(InvalidGeneratedContentException.class,
            () -> validator.normalizeAndValidate(candidate, ContentConstraints.defaults()));
    assertThat(exception.fieldName()).isEqualTo("chineseText");
}
```

- [ ] **Step 2: Add tests for canonical-only provider requests**

In `PracticeGeneratedContentServiceTest`, capture the generation request:

```java
@Test
void providerReceivesOnlyCanonicalSceneText() {
    service.generateCustomScene(request("  宝宝　不肯\n穿鞋  "));

    assertThat(mutableGenerator.lastRequest().canonicalSceneText())
            .isEqualTo("宝宝 不肯 穿鞋");
}
```

Modify the typed request expectation so there is no second raw `customSceneText` field.

- [ ] **Step 3: Run focused tests and verify current behavior fails**

Run:

```powershell
Push-Location C:\code\AI\baby-talk-2\backend
try {
  mvn test -pl app-api -Dtest=CustomSceneGeneratedContentValidatorTest,PracticeGeneratedContentServiceTest
} finally {
  Pop-Location
}
```

Expected: current validator accepts at least the marker/trace/echo cases or fails only at the database boundary.

- [ ] **Step 4: Change the generation request to canonical text only**

In `CustomSceneGenerationService.CustomSceneGenerationRequest`, remove the raw scene field and keep:

```java
public record CustomSceneGenerationRequest(
        String generatedContentId,
        String canonicalSceneText,
        PracticeDiscoverySurface surface,
        PracticeDiscoveryMode mode,
        String ageRange,
        String parentGoal,
        String locale,
        String traceId,
        Duration timeout,
        ContentConstraints constraints,
        String promptVersion,
        String strategyVersion
) {
}
```

Update `PracticeGeneratedContentService.generateAndActivate(...)` and fake/disabled/agentic-unavailable providers accordingly.

- [ ] **Step 5: Add explicit output PII policy**

Add `validatorPiiMarkers` to `PracticeDiscoveryPolicyProperties` and YAML:

```yaml
validator-pii-markers:
  - 身份证
  - 微信
  - wechat
  - qq
  - 住址
  - 地址
  - phone
  - 手机号
  - 电话
```

Normalize and validate the list using the same rules as other policy lists.

- [ ] **Step 6: Validate all persisted field lengths against V25 columns**

Use a helper:

```java
private void validateDatabaseLength(String value, int maxCodePoints, String fieldName) {
    if (value != null && canonicalizer.codePointLength(value) > maxCodePoints) {
        throw new InvalidGeneratedContentException(fieldName);
    }
}
```

Apply it to:

```text
spaceTitleZh       120
activityTitleZh    120
sceneTagEn         120
coachTipZh         240
englishText        120
chineseText        120
pronunciationHint  120
difficulty          16
generationSource    32
providerTraceId    128
retrievalTraceId   128
modelName           96
```

Retain product/grapheme/word-count constraints in addition to physical database limits.

- [ ] **Step 7: Restrict provider metadata to opaque tokens**

Add patterns:

```java
private static final Pattern TRACE_ID_PATTERN =
        Pattern.compile("[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}");
private static final Pattern MODEL_NAME_PATTERN =
        Pattern.compile("[A-Za-z0-9][A-Za-z0-9._:/-]{0,95}");
```

Validation:

```java
private void validateOpaqueMetadata(String value, Pattern pattern, String fieldName) {
    if (value != null && !pattern.matcher(value).matches()) {
        throw new InvalidGeneratedContentException(fieldName);
    }
}
```

Apply to provider trace, retrieval trace, and model name. The adapter owns these fields; the LLM must not freely generate them.

- [ ] **Step 8: Implement output PII and prompt-echo checks**

After producing canonical combined display text:

```java
if (policyProperties.compiledPhonePattern().matcher(combined).find()
        || policyProperties.compiledEmailPattern().matcher(combined).find()
        || policyProperties.compiledBabyNamePattern().matcher(combined).find()
        || policyTextMatcher.containsAny(combined, policyProperties.validatorPiiMarkers())) {
    throw new RejectedGeneratedContentException("output_pii_leakage");
}
if (containsPromptEcho(context == null ? null : context.normalizedSceneText(), combined)) {
    throw new RejectedGeneratedContentException("custom_scene_prompt_echo");
}
```

Use this prompt-echo implementation:

```java
private boolean containsPromptEcho(String sceneText, String outputText) {
    var scene = canonicalizer.canonicalize(sceneText);
    var output = canonicalizer.canonicalize(outputText);
    if (scene == null || output == null) {
        return false;
    }
    var searchableOutput = output.toLowerCase(Locale.ROOT);
    var searchableScene = scene.toLowerCase(Locale.ROOT);
    if (canonicalizer.codePointLength(searchableScene) >= 8
            && searchableOutput.contains(searchableScene)) {
        return true;
    }
    var codePoints = searchableScene.codePoints().toArray();
    var windowSize = 16;
    for (var start = 0; start + windowSize <= codePoints.length; start++) {
        var window = new String(codePoints, start, windowSize);
        if (searchableOutput.contains(window)) {
            return true;
        }
    }
    return false;
}
```

- [ ] **Step 9: Replace validator substring checks with `PolicyTextMatcher`**

Remove `containsAny(...)` from the validator and classifier. Inject `PolicyTextMatcher` and use it for:

- output PII markers;
- prompt-injection markers;
- blocked framing;
- medical/legal;
- adult/violent/sexual;
- unsupported claims;
- unsuitable 0–3 content;
- scene intent request/output markers.

- [ ] **Step 10: Run focused tests**

Run:

```powershell
Push-Location C:\code\AI\baby-talk-2\backend
try {
  mvn test -pl app-api -Dtest=CustomSceneGeneratedContentValidatorTest,PracticeGeneratedContentServiceTest,PracticeDiscoveryPolicyPropertiesTest,PolicyTextMatcherTest
} finally {
  Pop-Location
}
```

Expected: all tests pass; no generated string can reach PostgreSQL with an overlong code-point count; traces are opaque; configured PII and prompt echo are rejected.

- [ ] **Step 11: Record the checkpoint**

After explicit user approval only:

```powershell
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneGeneratedContentValidator.java `
        backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneGenerationService.java `
        backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneIntentClassifier.java `
        backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/PracticeDiscoveryPolicyProperties.java `
        backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentService.java `
        backend/app-api/src/main/resources/config/practice-discovery-policy.yml `
        backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/CustomSceneGeneratedContentValidatorTest.java `
        backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentServiceTest.java
git commit -m "fix: harden generated practice content validation"
```

---

### Task 5: Make privacy retention cleanup independent of active owner-key version

**Files:**
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentMapper.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentService.java`
- Modify: `backend/app-api/src/main/resources/mapper/practice/generated/PracticeGeneratedContentMapper.xml`
- Modify: `backend/db-migration/src/main/resources/db/migration/V25__create_practice_generated_content.sql`
- Test: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentRepositoryTest.java`
- Test: `backend/db-migration/src/test/java/com/zhangspaghetti/babytalk/migration/DbMigrationSmokeTest.java`

**Interfaces:**
- Produces: `deleteExpiredInstallationRows(OffsetDateTime cutoff, int limit)` across every key version.
- Produces: `expireStaleDrafts(OffsetDateTime cutoff, OffsetDateTime installationRetentionExpiry, OffsetDateTime updatedAt, int limit)` across every key version.
- Keeps: lookup, idempotency, rate counting, and per-current-installation candidate lookup bound to current key version.

- [ ] **Step 1: Add cross-version privacy cleanup tests**

Add repository integration tests:

```java
@Test
void staleDraftCleanupClearsInputAcrossHistoricalOwnerKeyVersions() {
    insertDraft("draft-v1", "v1", now.minusMinutes(10), "宝宝不肯穿鞋");
    insertDraft("draft-v2", "v2", now.minusMinutes(10), "宝宝不肯洗手");

    assertThat(service.expireStaleDrafts(now, 100)).isEqualTo(2);

    assertExpiredAndInputCleared("draft-v1");
    assertExpiredAndInputCleared("draft-v2");
}

@Test
void expiredInstallationCleanupDeletesRowsAcrossHistoricalOwnerKeyVersions() {
    insertExpiredInstallation("expired-v1", "v1", now.minusDays(1));
    insertExpiredInstallation("expired-v2", "v2", now.minusDays(1));

    assertThat(service.deleteExpiredInstallationRows(now, 100)).isEqualTo(2);
    assertThat(findById("expired-v1")).isNull();
    assertThat(findById("expired-v2")).isNull();
}
```

- [ ] **Step 2: Run tests and verify current version filters leave historical rows behind**

Run:

```powershell
Push-Location C:\code\AI\baby-talk-2\backend
try {
  mvn test -pl app-api -Dtest=PracticeGeneratedContentRepositoryTest
} finally {
  Pop-Location
}
```

Expected: historical-version rows remain and assertions fail.

- [ ] **Step 3: Remove key-version parameters from global privacy cleanup methods**

Change mapper signatures to:

```java
int deleteExpiredInstallationRows(
        @Param("retentionExpiresAtOrBefore") OffsetDateTime retentionExpiresAtOrBefore,
        @Param("limit") int limit);

int expireStaleDrafts(
        @Param("generationExpiresAtOrBefore") OffsetDateTime generationExpiresAtOrBefore,
        @Param("installationRetentionExpiresAt") OffsetDateTime installationRetentionExpiresAt,
        @Param("updatedAt") OffsetDateTime updatedAt,
        @Param("limit") int limit);
```

Update service calls so neither method passes `ownerKeyVersion()`.

Keep `findInstallationCleanupCandidates(...)` version-bound because its `installation_ref_hash` is derived from the active key and is a current-installation lookup rather than a global retention sweep.

- [ ] **Step 4: Remove owner-key-version filters from global cleanup SQL**

`deleteExpiredInstallationRows`:

```xml
<delete id="deleteExpiredInstallationRows">
    delete from practice_generated_content
    where generated_content_id in (
        select generated_content_id
        from practice_generated_content
        where owner_scope = 'installation'
          and status in ('active', 'expired', 'rejected')
          and retention_expires_at &lt;= #{retentionExpiresAtOrBefore,typeHandler=org.apache.ibatis.type.OffsetDateTimeTypeHandler}
        order by retention_expires_at asc, generated_content_id asc
        limit #{limit}
        for update skip locked
    )
      and owner_scope = 'installation'
      and status in ('active', 'expired', 'rejected')
      and retention_expires_at &lt;= #{retentionExpiresAtOrBefore,typeHandler=org.apache.ibatis.type.OffsetDateTimeTypeHandler}
</delete>
```

`expireStaleDrafts`:

```xml
<update id="expireStaleDrafts">
    with candidates as (
        select generated_content_id
        from practice_generated_content
        where status = 'draft'
          and generation_expires_at &lt;= #{generationExpiresAtOrBefore,typeHandler=org.apache.ibatis.type.OffsetDateTimeTypeHandler}
        order by generation_expires_at asc, generated_content_id asc
        limit #{limit}
        for update skip locked
    )
    update practice_generated_content target
    set status = 'expired',
        generation_error_code = 'draft_expired',
        normalized_scene_text = null,
        retention_expires_at = case
            when target.owner_scope = 'installation'
                then #{installationRetentionExpiresAt,typeHandler=org.apache.ibatis.type.OffsetDateTimeTypeHandler}
            else null
        end,
        updated_at = #{updatedAt,typeHandler=org.apache.ibatis.type.OffsetDateTimeTypeHandler}
    from candidates
    where target.generated_content_id = candidates.generated_content_id
      and target.status = 'draft'
      and target.generation_expires_at &lt;= #{generationExpiresAtOrBefore,typeHandler=org.apache.ibatis.type.OffsetDateTimeTypeHandler}
</update>
```

- [ ] **Step 5: Align V25 indexes with cross-version cleanup queries**

Replace:

```sql
create index idx_practice_generated_content_installation_cleanup
    on practice_generated_content(owner_key_version, retention_expires_at, generated_content_id)
    where owner_scope = 'installation';

create index idx_practice_generated_content_stale_draft_cleanup
    on practice_generated_content(owner_key_version, generation_expires_at, generated_content_id)
    where status = 'draft';
```

with:

```sql
create index idx_practice_generated_content_installation_cleanup
    on practice_generated_content(retention_expires_at, generated_content_id)
    where owner_scope = 'installation'
      and status in ('active', 'expired', 'rejected');

create index idx_practice_generated_content_stale_draft_cleanup
    on practice_generated_content(generation_expires_at, generated_content_id)
    where status = 'draft';
```

- [ ] **Step 6: Extend migration smoke assertions**

Assert the cleanup index leading columns no longer contain `owner_key_version`, and assert both partial predicates contain the expected owner/status conditions.

- [ ] **Step 7: Run repository and migration tests**

Run:

```powershell
Push-Location C:\code\AI\baby-talk-2\backend
try {
  mvn test -pl app-api -Dtest=PracticeGeneratedContentRepositoryTest
  mvn test -pl db-migration -Dtest=DbMigrationSmokeTest
} finally {
  Pop-Location
}
```

Expected: all historical-version rows are cleaned; current version-bound lookup tests remain green; Flyway smoke remains at V25 with the expected applied migration count.

- [ ] **Step 8: Record the checkpoint**

After explicit user approval only:

```powershell
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentMapper.java `
        backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentService.java `
        backend/app-api/src/main/resources/mapper/practice/generated/PracticeGeneratedContentMapper.xml `
        backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentRepositoryTest.java `
        backend/db-migration/src/main/resources/db/migration/V25__create_practice_generated_content.sql `
        backend/db-migration/src/test/java/com/zhangspaghetti/babytalk/migration/DbMigrationSmokeTest.java
git commit -m "fix: clean generated content across key versions"
```

---

### Task 6: Seal generated-content writes behind explicit state-machine methods

**Files:**
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentMapper.java`
- Rename: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentRepositoryTest.java` to `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentMapperTest.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentMapperContractTest.java`
- Verify: all production callers under `backend/app-api/src/main/java`.

**Interfaces:**
- Produces: mapper exposes only named state-machine/query methods.
- Removes: inherited `BaseMapper.insert`, `updateById`, `update`, `deleteById`, and generic wrappers.
- Keeps: explicit XML methods such as `insertRow`, `insertDraftIgnoringLiveConflict`, `activateDraft`, `rejectDraft`, `expireDraft`, and cleanup methods.

- [ ] **Step 1: Add a mapper-contract test**

```java
package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;

class PracticeGeneratedContentMapperContractTest {

    @Test
    void generatedContentMapperDoesNotExposeGenericCrudMutations() {
        assertThat(BaseMapper.class.isAssignableFrom(PracticeGeneratedContentMapper.class))
                .isFalse();

        var declaredMethods = Stream.of(PracticeGeneratedContentMapper.class.getDeclaredMethods())
                .map(method -> method.getName())
                .collect(Collectors.toSet());

        assertThat(declaredMethods).doesNotContain(
                "insert", "update", "updateById", "delete", "deleteById");
        assertThat(declaredMethods).contains(
                "insertRow",
                "insertDraftIgnoringLiveConflict",
                "activateDraft",
                "rejectDraft",
                "expireDraft",
                "deleteExpiredInstallationRows");
    }
}
```

- [ ] **Step 2: Run the test and verify it fails because the mapper extends `BaseMapper`**

Run:

```powershell
Push-Location C:\code\AI\baby-talk-2\backend
try {
  mvn test -pl app-api -Dtest=PracticeGeneratedContentMapperContractTest
} finally {
  Pop-Location
}
```

Expected: assertion failure showing `BaseMapper` is assignable from the mapper.

- [ ] **Step 3: Remove the generic CRUD inheritance**

Change the interface declaration from:

```java
public interface PracticeGeneratedContentMapper
        extends BaseMapper<PracticeGeneratedContentEntity> {
```

to:

```java
@Mapper
public interface PracticeGeneratedContentMapper {
```

Remove the `BaseMapper` import. Keep `Constants.ENTITY` only if current XML parameter references still use `#{et...}`; otherwise replace `@Param(Constants.ENTITY)` with `@Param("entity")` and update XML consistently.

- [ ] **Step 4: Rename the outdated repository test**

Rename the file and class:

```text
PracticeGeneratedContentRepositoryTest
→ PracticeGeneratedContentMapperTest
```

The test remains an integration test of explicit mapper/service persistence behavior; no `Repository` type exists after the B2.1 refactor.

- [ ] **Step 5: Search for generic CRUD calls and require zero production matches**

Run:

```powershell
rg -n "practiceGeneratedContentMapper\.(insert|update|updateById|delete|deleteById)\(" `
  C:\code\AI\baby-talk-2\backend\app-api\src\main\java
```

Expected: zero matches.

Also run:

```powershell
rg -n "PracticeGeneratedContentMapper" `
  C:\code\AI\baby-talk-2\backend\app-api\src\main\java
```

Expected production injections:

```text
PracticeGeneratedContentService
PracticeGeneratedContentWriteService
```

No controller or unrelated service may inject the mapper.

- [ ] **Step 6: Run mapper, service, concurrency, and contract tests**

Run:

```powershell
Push-Location C:\code\AI\baby-talk-2\backend
try {
  mvn test -pl app-api -Dtest=PracticeGeneratedContentMapperContractTest,PracticeGeneratedContentMapperTest,PracticeGeneratedContentServiceTest,PracticeGeneratedContentConcurrencyTest
} finally {
  Pop-Location
}
```

Expected: all tests pass with explicit state-machine SQL only.

- [ ] **Step 7: Record the checkpoint**

After explicit user approval only:

```powershell
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentMapper.java `
        backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentMapperContractTest.java `
        backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentMapperTest.java
git commit -m "refactor: seal generated content state transitions"
```

---

### Task 7: Update B2.1 contracts and run the complete repair verification matrix

**Files:**
- Modify: `docs/superpowers/plans/2026-07-03-t8-2-b2-1-practice-generated-content-custom-scene-plan.md`
- Verify only: `docs/superpowers/plans/2026-07-10-baby-profile-option-catalog-follow-up-plan.md`
- Verify only: all B2.1 application and migration files.

**Interfaces:**
- Produces: approved plan text matches final code semantics.
- Produces: final review evidence covering canonicalization, open-ended custom scenes, HMAC fingerprints, output privacy, cross-version cleanup, explicit state transitions, concurrency, routes, profiles, catalog, mentor regression, and Flyway.

- [ ] **Step 1: Amend the approved B2.1 plan with the hardened contracts**

Add a review-hardening section containing these exact decisions:

```text
Custom scene eligibility:
- Deterministic sceneIntents are alignment hints, not an allow-list.
- Safe unlisted care scenes may reach the typed provider boundary.
- Fake fixtures return generation_unavailable for unsupported scenes and never return unrelated fallback content.

Canonical text:
- customSceneText is normalized with Unicode NFKC and Unicode whitespace collapse before validation, fingerprinting, persistence, and provider invocation.
- Product grapheme limits and database code-point limits are both enforced.

Fingerprint privacy:
- request_fingerprint is an owner-scoped, domain-separated HMAC over canonical request material.
- It must not be a plain hash that permits cross-owner equality comparison or dictionary recovery.

Generated output privacy:
- Output PII markers, phone/email/name patterns, prompt echo, physical column limits, and opaque provider metadata are validated before activation.

Retention:
- Current-key lookup and rate accounting remain version-bound.
- Global stale-draft expiration and installation retention deletion operate across every owner-key version.

Registry writes:
- PracticeGeneratedContentMapper exposes only explicit state-machine/query operations and does not extend BaseMapper.
```

Do not modify the separate Baby Profile Option Catalog follow-up scope.

- [ ] **Step 2: Run focused new tests first**

```powershell
Push-Location C:\code\AI\baby-talk-2\backend
try {
  mvn test -pl app-api -Dtest=SceneTextCanonicalizerTest,PolicyTextMatcherTest,PracticeGeneratedContentKeyFactoryTest,PracticeGeneratedContentMapperContractTest
} finally {
  Pop-Location
}
```

Expected: all new tests pass.

- [ ] **Step 3: Run generated-content and discovery tests**

```powershell
Push-Location C:\code\AI\baby-talk-2\backend
try {
  mvn test -pl app-api -Dtest=PracticeGeneratedContentMapperTest
  mvn test -pl app-api -Dtest=PracticeGeneratedContentServiceTest
  mvn test -pl app-api -Dtest=PracticeGeneratedContentConcurrencyTest
  mvn test -pl app-api -Dtest=PracticeGeneratedContentOwnerPropertiesTest
  mvn test -pl app-api -Dtest=CustomSceneGeneratedContentValidatorTest
  mvn test -pl app-api -Dtest=CustomSceneGenerationProviderWiringTest
  mvn test -pl app-api -Dtest=PracticeDiscoveryCustomScenePropertiesTest
  mvn test -pl app-api -Dtest=PracticeDiscoveryPolicyPropertiesTest
  mvn test -pl app-api -Dtest=PracticeDiscoveryServiceTest
  mvn test -pl app-api -Dtest=PracticeDiscoveryControllerTest
} finally {
  Pop-Location
}
```

Expected: every test passes; no real provider/network/key is required.

- [ ] **Step 4: Run catalog, profile, auth, mentor, and migration regressions**

```powershell
Push-Location C:\code\AI\baby-talk-2\backend
try {
  mvn test -pl app-api -Dtest=PracticeCatalogMapperTest
  mvn test -pl app-api -Dtest=PracticeCatalogServiceTest
  mvn test -pl app-api -Dtest=BabyProfileMapperTest
  mvn test -pl app-api -Dtest=BabyProfileServiceTest
  mvn test -pl app-api -Dtest=BabyProfileControllerTest
  mvn test -pl app-api -Dtest=AuthConsentSyncWebTest
  mvn test -pl app-api -Dtest=MentorServiceTest
  mvn test -pl app-api -Dtest=MentorWebTest
  mvn test -pl app-api -Dtest=PracticeGenerateControllerTest
  mvn test -pl db-migration -Dtest=DbMigrationSmokeTest
} finally {
  Pop-Location
}
```

Expected: all tests pass with V25 as the current Flyway version.

- [ ] **Step 5: Run source and scope guards**

```powershell
rg -n "LocalDateTime" C:\code\AI\baby-talk-2\backend\app-api\src\main\java\com\zhangspaghetti\babytalk\practice
rg -n "text\.contains\(marker\)|anyMatch\(text::contains\)" C:\code\AI\baby-talk-2\backend\app-api\src\main\java\com\zhangspaghetti\babytalk\practice
rg -n "extends BaseMapper<PracticeGeneratedContentEntity>" C:\code\AI\baby-talk-2\backend\app-api\src
rg -n "request_fingerprint.*sha256|scene=.*sha256" C:\code\AI\baby-talk-2\backend\app-api\src\main\java
```

Expected: zero matches.

Scope guard:

```powershell
git diff HEAD --name-only -- mobile mobile_v2 admin-web
git diff HEAD --check
git diff --cached --check
```

Expected:

```text
mobile/mobile_v2/admin-web: no files
diff checks: exit 0
```

- [ ] **Step 6: Produce final review evidence without committing**

```powershell
git status --short
git diff --cached --name-only
git diff HEAD --name-only
git diff HEAD --binary > .tmp/patch/t8.2-b2.1-custom-scene-hardening.patch
Get-FileHash .tmp/patch/t8.2-b2.1-custom-scene-hardening.patch -Algorithm SHA256
```

Final report must state:

1. Safe unlisted care-scene examples that now pass local admission.
2. Clearly unsupported examples that still fail locally.
3. Canonicalization examples and canonical fingerprint reuse.
4. HMAC fingerprint cross-owner isolation evidence.
5. Output PII, trace-token, prompt-echo, and database-length test results.
6. Cross-version stale-draft and installation-cleanup test results.
7. Mapper state-machine contract result.
8. Complete test counts and failures/errors/skips.
9. Scope guard result.
10. Confirmation that no real agentic adapter, scheduler, Option Catalog implementation, mobile, Garden/Growth, or care-turn work was added.
11. Confirmation that no commit was created.

- [ ] **Step 7: Commit only after final human approval**

Recommended commit separation after approval:

```powershell
# Commit A: governance/plan documentation, if AGENTS.md or other governance files are included
git commit -m "docs: record custom scene hardening contracts"

# Commit B: B2.1 implementation and tests
git commit -m "fix: harden generated practice discovery"
```

Do not run these commands before the user explicitly approves the final patch.

---

## Explicitly Deferred Work

The implementation must not absorb these follow-ups:

- Real agentic/RAG custom-scene provider.
- Scheduled retention job; this plan keeps tested lazy/batch cleanup hooks only.
- Full HMAC key ring, rotation, or historical-key lookup.
- Baby Profile Option Catalog implementation; the separate follow-up plan remains authoritative.
- Whole-repository thin-Repository audit.
- Strong pre-auth abuse protection using WAF/IP/device attestation/Redis/provider billing circuit breakers.
- Semantic model-based alignment for unknown scenes. Before a real provider is enabled, its adapter needs an explicit semantic-classification/grounding gate; B2.1 keeps the local contract open without pretending the current keyword map is comprehensive.

## Self-Review Checklist

- [x] Every blocker from the final review maps to at least one task.
- [x] Custom-scene openness and known-intent alignment are separate concerns.
- [x] Plain fingerprint SHA is replaced with owner-scoped HMAC.
- [x] Canonical text precedes validation, fingerprinting, persistence, and provider invocation.
- [x] Product length and database physical length are both tested.
- [x] Generated display text and metadata have distinct privacy validation.
- [x] Global privacy cleanup is cross-version while current-owner lookup remains version-bound.
- [x] Registry generic CRUD inheritance is removed and verified.
- [x] No real provider, scheduler, mobile, care-turn, Garden/Growth, or Option Catalog implementation is introduced.
- [x] All task interfaces and method names are consistent across tasks.
- [x] No placeholder task text remains.
