# Custom Scene Health Safety Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 现实宝宝健康求助只返回固定中文安全提示，并确保英语生成、缓存复用、Care Moment 注册和音频播放全部停止。

**Architecture:** 在自定义场景编排入口加入 fail-closed 安全准入：本地紧急规则优先，受约束语义分类补充，版本化策略映射到固定中文模板。新增 v2 判别式响应供 Flutter 使用，v1 对健康结果返回兼容错误信封；只有 `ordinary_scene` 准入结果可以进入现有生成服务。通过提高 `contentRefreshEpoch`、服务端读取检查和客户端策略版本检查使旧自定义内容失效。

**Tech Stack:** Java 17 bytecode / JDK 21、Spring Boot 4.0.7、Spring AI 2.0.0、Jackson 3 `tools.jackson.*`、JUnit 5、AssertJ、Mockito、Flutter、Dart、Riverpod、Dio、flutter_test。

**Spec:** `docs/superpowers/specs/2026-09-12-custom-scene-health-safety-design.md`

## Global Constraints

- 现实健康求助只显示中文安全提示；禁止英语内容、练习入口、自动播放、音频合成、Care Moment 注册和完成计数。
- 系统不诊断，不提供药名、剂量、治疗方案或“可以放心在家观察”的结论。
- 行动枚举只允许 `emergency`、`seek_medical_help`、`uncertain`；不得使用 `safe`、`low_risk`。
- 固定版本：响应 schema `custom-scene-result-v2`，安全策略 `health-safety-v1`，模板 ID 按设计文档第 5 节。
- 分类器超时初始值 3 秒，只调用一次；超时、异常 JSON、未知枚举、缺字段均返回 `assessment_unavailable`，不得调用英语生成器。
- 健康原文、模型证据、账号、token、设备 ID 不进入新日志、指标或服务端健康记录；首期不新增数据库表或 Flyway migration。
- 健康模板上线前必须完成儿科专业审核；工程测试通过不代表医学审核通过。
- 生产 Java 使用 Jackson 3 `tools.jackson.*`；仅注解可继续使用 `com.fasterxml.jackson.annotation.*`。
- 保留现有鉴权、所有权、输入长度、限流、规范化、PII、控制字符和 prompt injection 防护。
- 工作区已有其他未提交更改。每个任务仅暂存所列文件，禁止覆盖或提交无关修改。
- 实施开始前必须通过 `python3 tool/verify_spring_ai_2_backend_platform.py` 和 `cd backend && bash mvnw clean test`。

## File Map

### Backend: safety decision

- Create `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/safety/CustomSceneSafetyAssessment.java`: immutable intent/action/result model and an internal admission token.
- Create `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/safety/CustomSceneSafetyClassifier.java`: semantic classifier port.
- Create `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/safety/CustomSceneEmergencyRuleClassifier.java`: deterministic, scope-aware emergency rules.
- Create `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/safety/CustomSceneSafetyPolicy.java`: precedence and fail-closed routing.
- Create `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/safety/HealthSafetyTemplateRegistry.java`: fixed reviewed Chinese templates.
- Create `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/safety/CustomSceneSafetyProperties.java`: typed, validated policy configuration.
- Create `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/safety/AgenticCustomSceneSafetyClassifier.java`: strict Spring AI semantic classification.
- Create `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/safety/FakeCustomSceneSafetyClassifier.java`: deterministic dev/test classifier.
- Create `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/safety/CustomSceneSafetyExecutorConfiguration.java`: bounded classifier executor and 3-second application deadline.
- Create `backend/app-api/src/main/resources/config/practice-ai/prompts/custom-scene-safety-classifier-v1.txt`: classifier system prompt.
- Create `backend/app-api/src/main/resources/config/practice-health-safety-v1.yml`: versioned signals, mappings and fixed Chinese copy.
- Modify `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/PracticeAiCapability.java`: add safety-classifier capability.
- Modify `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/config/VersionedResourceRegistry.java`: load and verify the classifier prompt as a locked resource.
- Modify `backend/app-api/src/main/resources/application.yml`: bind policy, 3-second timeout and provider route.
- Modify `backend/app-api/src/main/resources/config/practice-ai/version-lock.yml`: lock new prompt/policy hashes.
- Modify `deploy/helm/babytalk-app/templates/practice-ai-configmap.yaml`: require and render the classifier capability route.
- Modify `deploy/helm/babytalk-app/values.yaml`: add disabled-mode empty classifier route.
- Modify `deploy/helm/babytalk-app/values-kind.yaml`: add fake-mode empty classifier route.
- Modify `deploy/helm/babytalk-app/values-kind-qa.yaml`: route classifier to the configured QA provider.
- Modify `deploy/helm/babytalk-app/values-production.yaml`: route classifier to the configured production provider.
- Modify `tool/verify_practice_ai_helm.dart`: verify the fourth required capability without reading credentials.
- Modify `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/SceneTextSecurityPolicy.java`: remove medical terms from generic rejection while retaining other controls.
- Modify `backend/app-api/src/main/resources/config/practice-discovery-policy.yml`: stop treating generic medical language as an unsafe marker.

### Backend: API and generated-content boundary

- Create `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/dto/CustomSceneDiscoveryV2Response.java`: discriminated v2 response.
- Create `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/PracticeDiscoveryV2Controller.java`: v2 custom-scene endpoint.
- Modify `backend/gateway/src/main/resources/application.yml`: route `/api/v2/**` through the existing Redis request limiter to app-api.
- Modify `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/PracticeDiscoveryService.java`: shared context validation, safety routing and delayed generator availability check.
- Modify `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentService.java`: require server-issued admission and raise epoch from 1 to 2.
- Modify `backend/app-api/src/main/resources/mapper/practice/generated/PracticeGeneratedContentQueryMapper.xml`: enforce current epoch in playable-audio lookup.
- Modify `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/audio/GeneratedUtteranceAudioService.java`: pass current epoch to query.

### Flutter: contract, state and presentation

- Create `mobile/lib/features/custom_scene/domain/custom_scene_result.dart`: sealed result and health safety value objects.
- Modify `mobile/lib/features/custom_scene/domain/generated_care_moment.dart`: carry the admitted safety policy version with generated content.
- Modify `mobile/lib/features/custom_scene/data/custom_scene_dtos.dart`: strict v2 envelope and safety DTO parsing.
- Modify `mobile/lib/features/custom_scene/data/custom_scene_api.dart`: call only `/api/v2/practice/discovery` and parse v2.
- Modify `mobile/lib/features/custom_scene/data/custom_scene_mapper.dart`: map v2 variants and validate policy/template/action.
- Modify `mobile/lib/features/custom_scene/domain/custom_scene_repository.dart`: return `Future<CustomSceneResult>`.
- Modify `mobile/lib/features/custom_scene/data/custom_scene_repository_impl.dart`: return mapped union; never downgrade malformed v2 to v1.
- Modify `mobile/lib/features/custom_scene/application/custom_scene_submission_controller.dart`: add safety terminal states and suppress registration/handoff.
- Modify `mobile/lib/features/custom_scene/domain/custom_scene_stored_draft.dart`: represent a cleared terminal intent without storing health text.
- Modify `mobile/lib/features/custom_scene/data/custom_scene_draft_store.dart`: encode/decode terminal intent and safely recover unknown states.
- Modify `mobile/lib/features/custom_scene/presentation/custom_scene_input_screen.dart`: render accessible Chinese safety panel with “关闭/修改描述”.
- Modify `mobile/lib/app/providers/repository_providers.dart`: inject playback stop callback into controller.
- Create `mobile/lib/features/care_path/application/care_audio_session_coordinator.dart`: own the active care-audio controller and provide a global stop boundary.
- Modify `mobile/lib/features/care_path/presentation/widgets/care_turn_surface.dart`: register/unregister playback ownership with the coordinator.
- Modify `mobile/lib/features/care_path/domain/models/care_path_models.dart`: carry generated safety policy version and content epoch into audio sources.
- Modify `mobile/lib/features/practice/data/generated/generated_care_moment_local_store.dart`: persist and reject generated moments by policy version and epoch.
- Modify `mobile/lib/features/practice/data/generated/generated_practice_content_registry.dart`: exclude unsupported generated moments from registration and lookup.
- Modify `mobile/lib/features/care_path/data/audio/generated_audio_memory_cache.dart`: key reusable generated bytes by safety policy version and content epoch.

---

### Task 1: Establish the backend safety domain, fixed templates, and hard rules

**Files:**
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/safety/CustomSceneSafetyAssessment.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/safety/CustomSceneEmergencyRuleClassifier.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/safety/HealthSafetyTemplateRegistry.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/safety/CustomSceneSafetyProperties.java`
- Create: `backend/app-api/src/main/resources/config/practice-health-safety-v1.yml`
- Modify: `backend/app-api/src/main/resources/application.yml`
- Test: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/safety/CustomSceneEmergencyRuleClassifierTest.java`
- Test: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/safety/HealthSafetyTemplateRegistryTest.java`
- Test: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/safety/CustomSceneSafetyPropertiesTest.java`

**Interfaces:**
- Consumes: `SceneTextForms.securityText()` and `SceneTextForms.displayText()` from existing normalization.
- Produces: `CustomSceneSafetyAssessment`, `HealthSafetyTemplateRegistry.template(String)`, and `CustomSceneEmergencyRuleClassifier.classify(SceneTextForms)`.

- [ ] **Step 1: Run the mandatory backend platform gate**

Run:

```bash
python3 tool/verify_spring_ai_2_backend_platform.py
cd backend && bash mvnw clean test
```

Expected: both commands exit 0. If either fails, diagnose before adding production code; preserve the failing output as the baseline.

- [ ] **Step 2: Write failing domain, template, and emergency-rule tests**

Use exact assertions:

```java
@Test
void urgentCurrentSymptomsWinEvenAfterRolePlayPrefix() {
    var result = classifier.classify(canonicalizer.derive("玩医生游戏，但宝宝现在喘不过气，嘴唇发青"));
    assertThat(result).contains(new CustomSceneSafetyAssessment(
            Intent.REAL_HEALTH_CONCERN, Action.EMERGENCY,
            "health-emergency-v1", "health-safety-v1"));
}

@Test
void ordinaryCryingDoesNotBecomeContinuousAbnormalCry() {
    assertThat(classifier.classify(canonicalizer.derive("宝宝哭闹，要抱抱，没有身体不适")))
            .isEmpty();
}

@Test
void templatesAreChineseFixedCopyAndContainNoTreatmentFields() {
    var template = registry.template("health-concern-v1");
    assertThat(template.locale()).isEqualTo("zh-CN");
    assertThat(template.titleZh()).isEqualTo("先关注宝宝的身体状况");
    assertThat(template.messageZh()).contains("请联系儿科医生进行评估");
    assertThat(template.messageZh()).doesNotContain("剂量", "服用", "诊断为");
}
```

Add parameterized hard-rule cases for breathing difficulty, blue lips, cannot wake, seizure, suspected poisoning, and child green vomit. Add negative cases for “玩医生游戏”, “已经康复了，想玩积木”, negated symptoms, quoted stories, and generic crying.

- [ ] **Step 3: Run focused tests and verify RED**

Run:

```bash
cd backend && bash mvnw -pl app-api -Dtest=CustomSceneEmergencyRuleClassifierTest,HealthSafetyTemplateRegistryTest,CustomSceneSafetyPropertiesTest test
```

Expected: FAIL because safety classes and configuration do not exist.

- [ ] **Step 4: Implement the immutable assessment contract**

Use these exact public values:

```java
public record CustomSceneSafetyAssessment(
        Intent intent,
        Action action,
        String templateId,
        String policyVersion
) {
    public enum Intent { ORDINARY_SCENE, REAL_HEALTH_CONCERN, UNCERTAIN }
    public enum Action { EMERGENCY, SEEK_MEDICAL_HELP, UNCERTAIN }
}
```

Keep any evidence/signal enum package-private and in memory. Do not include raw source text in `toString()` or exception messages.

- [ ] **Step 5: Implement versioned templates and deterministic hard rules**

Bind `practice-health-safety-v1.yml` with `@ConfigurationProperties(prefix = "babytalk.practice.health-safety")`. Validate at startup:

```yaml
babytalk:
  practice:
    health-safety:
      policy-version: health-safety-v1
      classifier-timeout: 3s
      templates:
        health-emergency-v1:
          action: emergency
          locale: zh-CN
          title-zh: 请立即寻求医疗帮助
          message-zh: 你描述的情况可能需要紧急处理。请立即联系当地急救服务，或前往急诊。不要等待本应用进一步回复。
```

Include all five templates verbatim from the approved spec. Hard rules return only `health-emergency-v1`; scoped matching must prevent a negation or fictional prefix from cancelling a later current symptom. Do not add numeric temperature, stool-count, or time thresholds.

Import the YAML from `application.yml` using the repository's existing `spring.config.import` pattern so production startup creates and validates `CustomSceneSafetyProperties` and `HealthSafetyTemplateRegistry`.

- [ ] **Step 6: Run focused tests and verify GREEN**

Run the Step 3 command. Expected: PASS.

- [ ] **Step 7: Commit Task 1 only**

```bash
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/safety backend/app-api/src/main/resources/application.yml backend/app-api/src/main/resources/config/practice-health-safety-v1.yml backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/safety
git commit -m "feat(safety): add health decision policy"
```

### Task 2: Add strict semantic classification with fail-closed behavior

**Files:**
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/safety/CustomSceneSafetyClassifier.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/safety/AgenticCustomSceneSafetyClassifier.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/safety/FakeCustomSceneSafetyClassifier.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/safety/CustomSceneSafetyPolicy.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/safety/CustomSceneSafetyExecutorConfiguration.java`
- Create: `backend/app-api/src/main/resources/config/practice-ai/prompts/custom-scene-safety-classifier-v1.txt`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/PracticeAiCapability.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/PracticeAiOperationRunner.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic/config/VersionedResourceRegistry.java`
- Modify: `backend/app-api/src/main/resources/application.yml`
- Modify: `backend/app-api/src/main/resources/config/practice-ai/version-lock.yml`
- Modify: `deploy/helm/babytalk-app/templates/practice-ai-configmap.yaml`
- Modify: `deploy/helm/babytalk-app/values.yaml`
- Modify: `deploy/helm/babytalk-app/values-kind.yaml`
- Modify: `deploy/helm/babytalk-app/values-kind-qa.yaml`
- Modify: `deploy/helm/babytalk-app/values-production.yaml`
- Modify: `tool/verify_practice_ai_helm.dart`
- Test: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/safety/AgenticCustomSceneSafetyClassifierTest.java`
- Test: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/safety/CustomSceneSafetyPolicyTest.java`
- Test: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/agentic/PracticeAiPropertiesTest.java`
- Test: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/agentic/config/VersionedResourceRegistryTest.java`
- Test: `test/tool/verify_practice_ai_helm_test.dart`

**Interfaces:**
- Consumes: Task 1 assessment model, templates and hard-rule classifier; existing `PracticeAiOperationRunner` and `PracticeAiStructuredOutputCaller`.
- Produces: `CustomSceneSafetyPolicy.assess(SceneTextForms forms, String ageRange)` returning `CustomSceneSafetyDecision` with result types `GENERATED_SCENE`, `HEALTH_SAFETY`, `ASSESSMENT_UNAVAILABLE`.

- [ ] **Step 1: Write failing strict-output and precedence tests**

```java
@Test
void diarrheaConcernMapsToFixedTemplateWithoutReturningModelCopy() {
    when(classifier.classify(any())).thenReturn(new SemanticResult(
            Intent.REAL_HEALTH_CONCERN, List.of("diarrhea")));
    var decision = policy.assess(canonicalizer.derive("宝宝拉肚子哭闹怎么办"), "m7_11");
    assertThat(decision.resultType()).isEqualTo(HEALTH_SAFETY);
    assertThat(decision.assessment().templateId()).isEqualTo("health-concern-v1");
}

@Test
void classifierFailureClosesGenerationPath() {
    when(classifier.classify(any())).thenThrow(new CustomSceneSafetyClassifier.UnavailableException());
    assertThat(policy.assess(canonicalizer.derive("宝宝洗澡一直躲水"), "m7_11").resultType())
            .isEqualTo(ASSESSMENT_UNAVAILABLE);
}
```

Strict-output tests must reject malformed JSON, unknown top-level fields, unknown intent/signal, duplicate signal, and missing intent. Verify the classifier user payload contains only `displayText`, `ageRange`, `locale`, and policy version; assert it excludes account, installation, token, name, and trace identifiers.

Add a blocking fake provider test that exceeds 3 seconds. Assert the public classifier call returns unavailable within 3.5 seconds, its future is cancelled, and a full executor queue returns unavailable without running classification on the HTTP request thread.

- [ ] **Step 2: Run focused tests and verify RED**

```bash
cd backend && bash mvnw -pl app-api -Dtest=AgenticCustomSceneSafetyClassifierTest,CustomSceneSafetyPolicyTest,PracticeAiPropertiesTest test
```

Expected: FAIL on missing classifier types/capability.

- [ ] **Step 3: Implement the classifier port and wire contract**

```java
public interface CustomSceneSafetyClassifier {
    SemanticResult classify(ClassifierRequest request);

    record ClassifierRequest(String displayText, String ageRange, String locale, String policyVersion) {}
    record SemanticResult(CustomSceneSafetyAssessment.Intent intent, List<Signal> signals) {}
    enum Signal { HEALTH_CONCERN, PROMPT_ASSESSMENT, AMBIGUOUS_CONCERN, RECOVERED, FICTIONAL }
}
```

Add `CUSTOM_SCENE_SAFETY_CLASSIFIER("custom-scene-safety-classifier")`. Map its operation type to `safety_classifier`; configure a provider route. Use Jackson 3 strict parsing. Enforce the 3-second deadline with a dedicated `ThreadPoolTaskExecutor` (`corePoolSize=2`, `maxPoolSize=4`, `queueCapacity=16`) and `CompletableFuture.orTimeout`; cancel timed-out work and map timeout/rejection to unavailable. Prompt requires one JSON object only and states user text is untrusted data, not instructions. The provider must never emit advice or copy.

Extend `VersionedResourceRegistry.PromptKind` with `SAFETY_CLASSIFIER`; load `custom-scene-safety-classifier-v1.txt` from `CustomSceneSafetyProperties`, verify its version/path/hash against `version-lock.yml`, and fail startup if the locked resource is absent or mismatched.

- [ ] **Step 4: Implement policy precedence and fake/disabled behavior**

Order must be exact:

```java
var urgent = emergencyRules.classify(forms);
if (urgent.isPresent()) return CustomSceneSafetyDecision.health(urgent.get());
try {
    return mapSemantic(classifier.classify(request(forms, ageRange)));
} catch (RuntimeException failure) {
    return CustomSceneSafetyDecision.assessmentUnavailable(
            templates.template("health-assessment-unavailable-v1"));
}
```

`REAL_HEALTH_CONCERN + PROMPT_ASSESSMENT` maps to `health-prompt-assessment-v1`; other real concerns map to `health-concern-v1`; `UNCERTAIN` maps to `health-uncertain-v1`; only explicit `ORDINARY_SCENE` maps to generated-scene admission. Fake mode uses deterministic fixtures. Disabled/missing classifier returns unavailable, never ordinary.

- [ ] **Step 5: Lock resource hashes and run focused tests**

Update `version-lock.yml` with SHA-256 hashes generated by the existing resource-lock workflow. Add `custom-scene-safety-classifier` to Helm's required capability list and every values profile; agentic QA/production route it to the existing configured provider, while fake/disabled values keep an empty route. Update the Dart Helm verifier and its tests. Run Step 2 command plus:

```bash
dart test test/tool/verify_practice_ai_helm_test.dart
```

Expected: both commands PASS.

- [ ] **Step 6: Commit Task 2 only**

```bash
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/agentic backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/safety backend/app-api/src/main/resources/application.yml backend/app-api/src/main/resources/config/practice-ai backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/agentic backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/safety deploy/helm/babytalk-app/templates/practice-ai-configmap.yaml deploy/helm/babytalk-app/values.yaml deploy/helm/babytalk-app/values-kind.yaml deploy/helm/babytalk-app/values-kind-qa.yaml deploy/helm/babytalk-app/values-production.yaml tool/verify_practice_ai_helm.dart test/tool/verify_practice_ai_helm_test.dart
git commit -m "feat(safety): classify health concerns"
```

### Task 3: Route v1 and v2 requests through one safety admission gate

**Files:**
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/dto/CustomSceneDiscoveryV2Response.java`
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/PracticeDiscoveryV2Controller.java`
- Modify: `backend/gateway/src/main/resources/application.yml`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/PracticeDiscoveryService.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/SceneTextSecurityPolicy.java`
- Modify: `backend/app-api/src/main/resources/config/practice-discovery-policy.yml`
- Test: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/PracticeDiscoveryServiceTest.java`
- Test: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/SceneTextSecurityPolicyTest.java`
- Test: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/PracticeDiscoveryControllerTest.java`
- Test: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/PracticeDiscoveryV2ControllerTest.java`
- Test: `backend/gateway/src/test/java/com/zhangspaghetti/babytalk/gateway/GatewayApplicationContextTest.java`

**Interfaces:**
- Consumes: `CustomSceneSafetyPolicy.assess(...)` and existing `PracticeDiscoveryRequest`/`PracticeDiscoveryResponse`.
- Produces: `PracticeDiscoveryService.discoverCustomSceneV2(...)`; v1 retains its response type and emits `health_safety_redirect` or `health_assessment_unavailable` error contracts for non-generated results.

- [ ] **Step 1: Write failing service and HTTP contract tests**

Test these exact effects:

```java
verify(generatedContentService, never()).requireCustomSceneGenerationAvailable();
verify(generatedContentService, never()).generateCustomScene(any(), any());
```

For `宝宝拉肚子哭闹怎么办`, v2 must return HTTP 200 with exactly `schemaVersion`, `discoveryTraceId`, `resultType`, `safety`; JSON must not contain `generatedContentId`, `scene`, `english`, `starter`, or `audio`. For an ordinary scene, return `resultType=generated_scene`, `policyVersion=health-safety-v1`, nested `scene`, and no `safety`. For v1 health requests, assert HTTP 422 code `health_safety_redirect`; unavailable classification uses HTTP 503 code `health_assessment_unavailable`. Both messages are fixed Chinese and details contain no source text.

- [ ] **Step 2: Run focused tests and verify RED**

```bash
cd backend && bash mvnw -pl app-api -Dtest=PracticeDiscoveryServiceTest,SceneTextSecurityPolicyTest,PracticeDiscoveryControllerTest,PracticeDiscoveryV2ControllerTest test
```

Expected: FAIL because v2 response/controller and safety route do not exist.

- [ ] **Step 3: Implement the discriminated v2 response**

```java
public record CustomSceneDiscoveryV2Response(
        String schemaVersion,
        String discoveryTraceId,
        String resultType,
        String policyVersion,
        PracticeDiscoveryResponse scene,
        SafetyResponse safety
) {
    public record SafetyResponse(
            String action, String templateId, String policyVersion,
            String locale, String titleZh, String messageZh) {}
}
```

Use `@JsonInclude(NON_NULL)` so forbidden variant fields are absent, not null. Add a v2 controller that only accepts `mode=custom_scene`; other modes return existing unsupported-mode semantics.

- [ ] **Step 4: Refactor shared custom-scene validation, then apply safety admission**

Keep validation order: request/surface/mode/locale/client ID, accepted consumer session and profile ownership, installation validation, canonicalization and non-medical security checks, safety decision. The gateway's existing default `RequestRateLimiter` runs before both `/api/v1/**` and `/api/v2/**`; existing database-backed generation burst/daily limits remain in the ordinary generated branch. Only the generated branch calls:

```java
generatedContentService.requireCustomSceneGenerationAvailable();
generatedContentService.generateCustomScene(request, safetyDecision.admission());
```

Remove `validatorMedicalLegal()` from `SceneTextSecurityPolicy.highRiskMarkers()`. Keep PII, prompt injection, bidi, adult/violent/sexual and dangerous generated-output checks. Do not remove output medical-command validation.

Change the gateway app-api predicate to `Path=/api/v1/**,/api/v2/**`. Extend `GatewayApplicationContextTest` to resolve `/api/v2/practice/discovery` to app-api and confirm the default `RequestRateLimiter` filter remains attached.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run the app-api command from Step 2, then:

```bash
cd backend && bash mvnw -pl gateway -Dtest=GatewayApplicationContextTest test
```

Expected: both commands PASS.

- [ ] **Step 6: Commit Task 3 only**

```bash
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery backend/app-api/src/main/java/com/zhangspaghetti/babytalk/web/PracticeDiscoveryV2Controller.java backend/app-api/src/main/resources/config/practice-discovery-policy.yml backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/PracticeDiscoveryV2ControllerTest.java backend/gateway/src/main/resources/application.yml backend/gateway/src/test/java/com/zhangspaghetti/babytalk/gateway/GatewayApplicationContextTest.java
git commit -m "feat(api): add health-safe discovery v2"
```

### Task 4: Prevent cache, replay, ID, and audio bypasses

**Files:**
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentService.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/audio/GeneratedUtteranceAudioService.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentQueryMapper.java`
- Modify: `backend/app-api/src/main/resources/mapper/practice/generated/PracticeGeneratedContentQueryMapper.xml`
- Test: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentServiceTest.java`
- Test: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentServiceOrchestrationTest.java`
- Test: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/PracticeGeneratedContentMapperTest.java`
- Test: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/audio/GeneratedUtteranceAudioServiceTest.java`
- Test: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/GeneratedUtteranceAudioHttpIntegrationTest.java`

**Interfaces:**
- Consumes: server-created `CustomSceneSafetyDecision.Admission` bound to normalized security text, age range, locale, owner context, and `health-safety-v1`.
- Produces: generated content at `CONTENT_REFRESH_EPOCH = 2`; all read/play paths reject older epochs.

- [ ] **Step 1: Write failing bypass regression tests**

Cover four independent bypasses:

```java
assertThatThrownBy(() -> service.generateCustomScene(request, forgedOrMismatchedAdmission))
        .isInstanceOf(IllegalArgumentException.class);
verify(queryMapper, never()).findLiveByFingerprint(any(), any(), any(), any(), any(), any(), anyInt());
```

Also seed an epoch-1 active `Hold you.` bundle and verify: fingerprint request does not reuse it; clientRequestId replay cannot return it; lookup by generatedContentId reports expired/unsupported; `/audio` returns 404 and synthesis port receives zero calls.

- [ ] **Step 2: Run focused tests and verify RED**

```bash
cd backend && bash mvnw -pl app-api -Dtest=PracticeGeneratedContentServiceTest,PracticeGeneratedContentServiceOrchestrationTest,PracticeGeneratedContentMapperTest,GeneratedUtteranceAudioServiceTest,GeneratedUtteranceAudioHttpIntegrationTest test
```

Expected: FAIL because epoch 1 remains reusable or admission is not required.

- [ ] **Step 3: Bind admission and advance the epoch**

Set:

```java
private static final int CONTENT_REFRESH_EPOCH = 2;
private static final String HEALTH_SAFETY_POLICY_VERSION = "health-safety-v1";
```

Make the generation overload without admission package-private only for fixture construction or remove it after updating callers. Validate admission before `findByClientRequestId` and `findLiveByFingerprint`. Admission comparison uses canonical security text hash and exact owner/profile/age/locale/policy version; it never logs values.

- [ ] **Step 4: Enforce epoch in every content and audio read**

Add `content_refresh_epoch = #{contentRefreshEpoch}` to `findPlayableOwnedActiveBundleUtterance`, and pass epoch 2 from `GeneratedUtteranceAudioService`. Confirm existing active/generated-content lookup already filters epoch; add the parameter where it does not. Return existing sanitized not-found/expired contracts.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run Step 2 command. Expected: PASS.

- [ ] **Step 6: Commit Task 4 only**

```bash
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/generated backend/app-api/src/main/resources/mapper/practice/generated backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/GeneratedUtteranceAudioHttpIntegrationTest.java
git commit -m "fix(safety): block legacy scene replay"
```

### Task 5: Parse and map the Flutter v2 discriminated result

**Files:**
- Create: `mobile/lib/features/custom_scene/domain/custom_scene_result.dart`
- Modify: `mobile/lib/features/custom_scene/domain/generated_care_moment.dart`
- Modify: `mobile/lib/features/custom_scene/data/custom_scene_dtos.dart`
- Modify: `mobile/lib/features/custom_scene/data/custom_scene_api.dart`
- Modify: `mobile/lib/features/custom_scene/data/custom_scene_mapper.dart`
- Modify: `mobile/lib/features/custom_scene/domain/custom_scene_repository.dart`
- Modify: `mobile/lib/features/custom_scene/data/custom_scene_repository_impl.dart`
- Test: `mobile/test/features/custom_scene/custom_scene_api_test.dart`
- Test: `mobile/test/features/custom_scene/custom_scene_mapper_test.dart`
- Test: `mobile/test/features/custom_scene/custom_scene_repository_test.dart`

**Interfaces:**
- Consumes: Task 3 v2 JSON contract.
- Produces: `Future<CustomSceneResult> generate(CustomSceneDraft draft)` with `GeneratedSceneResult`, `HealthSafetyResult`, `AssessmentUnavailableResult`.

- [ ] **Step 1: Write failing API and union-mapping tests**

```dart
expect(options.path, '/api/v2/practice/discovery');
expect(result, isA<HealthSafetyResult>());
final safety = (result as HealthSafetyResult).safety;
expect(safety.templateId, 'health-concern-v1');
expect(safety.titleZh, '先关注宝宝的身体状况');
```

Add tests that reject extra fields, `health_safety` carrying `scene`, `generated_scene` carrying `safety`, unknown resultType/action/template/policy, non-Chinese locale, missing copy, or missing schemaVersion. Unknown/malformed responses map to the embedded assessment-unavailable copy and never call a v1 endpoint.

- [ ] **Step 2: Run focused tests and verify RED**

```bash
cd mobile && flutter test test/features/custom_scene/custom_scene_api_test.dart test/features/custom_scene/custom_scene_mapper_test.dart test/features/custom_scene/custom_scene_repository_test.dart
```

Expected: FAIL because API uses v1 and repository returns only `GeneratedCareMoment`.

- [ ] **Step 3: Implement domain union and strict DTO parser**

```dart
sealed class CustomSceneResult { const CustomSceneResult(); }
final class GeneratedSceneResult extends CustomSceneResult {
  const GeneratedSceneResult(this.moment, {required this.policyVersion});
  final GeneratedCareMoment moment;
  final String policyVersion;
}
final class HealthSafetyResult extends CustomSceneResult {
  const HealthSafetyResult(this.safety);
  final HealthSafetyNotice safety;
}
final class AssessmentUnavailableResult extends CustomSceneResult {
  const AssessmentUnavailableResult(this.safety);
  final HealthSafetyNotice safety;
}
```

`HealthSafetyNotice` exposes only action/template/policy/locale/title/message. Keep exact-key validation per variant. `GeneratedCareMoment` gains required `safetyPolicyVersion` and `contentRefreshEpoch`; accept only `health-safety-v1` and epoch `2`. Define one built-in `health-assessment-unavailable-v1` Chinese fallback in Dart for malformed or future server variants.

- [ ] **Step 4: Switch API and repository without fallback**

Change endpoint to `/api/v2/practice/discovery`. Map only the v2 envelope. Keep auth refresh behavior. A 404/5xx from v2 maps to unavailable; do not retry `/api/v1/practice/discovery`.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run Step 2 command. Expected: PASS.

- [ ] **Step 6: Commit Task 5 only**

```bash
git add mobile/lib/features/custom_scene/domain/custom_scene_result.dart mobile/lib/features/custom_scene/domain/custom_scene_repository.dart mobile/lib/features/custom_scene/domain/generated_care_moment.dart mobile/lib/features/custom_scene/data/custom_scene_api.dart mobile/lib/features/custom_scene/data/custom_scene_dtos.dart mobile/lib/features/custom_scene/data/custom_scene_mapper.dart mobile/lib/features/custom_scene/data/custom_scene_repository_impl.dart mobile/test/features/custom_scene/custom_scene_api_test.dart mobile/test/features/custom_scene/custom_scene_mapper_test.dart mobile/test/features/custom_scene/custom_scene_repository_test.dart
git commit -m "feat(mobile): parse health safety results"
```

### Task 6: Make health safety a terminal submission state and stop audio

**Files:**
- Modify: `mobile/lib/features/custom_scene/application/custom_scene_submission_controller.dart`
- Modify: `mobile/lib/features/custom_scene/domain/custom_scene_stored_draft.dart`
- Modify: `mobile/lib/features/custom_scene/data/custom_scene_draft_store.dart`
- Modify: `mobile/lib/app/providers/repository_providers.dart`
- Modify: `mobile/lib/app/custom_scene_recovery_coordinator.dart`
- Create: `mobile/lib/features/care_path/application/care_audio_session_coordinator.dart`
- Modify: `mobile/lib/features/care_path/presentation/widgets/care_turn_surface.dart`
- Modify: `mobile/lib/features/care_path/domain/models/care_path_models.dart`
- Modify: `mobile/lib/features/practice/data/generated/generated_care_moment_local_store.dart`
- Modify: `mobile/lib/features/practice/data/generated/generated_practice_content_registry.dart`
- Modify: `mobile/lib/features/care_path/data/audio/generated_audio_memory_cache.dart`
- Test: `mobile/test/features/custom_scene/custom_scene_submission_controller_test.dart`
- Test: `mobile/test/features/custom_scene/custom_scene_draft_continuation_test.dart`
- Test: `mobile/test/features/custom_scene/custom_scene_input_screen_test.dart`
- Test: `mobile/test/features/practice/generated/generated_audio_api_test.dart`
- Test: `mobile/test/features/practice/generated/generated_care_moment_local_store_test.dart`
- Test: `mobile/test/features/care_path/care_audio_session_coordinator_test.dart`

**Interfaces:**
- Consumes: Task 5 `CustomSceneResult` union and existing `CareAudioPlaybackController.stop()`.
- Produces: `CustomSceneSubmissionPhase.healthSafety` and `.assessmentUnavailable`; state carries `HealthSafetyNotice? safetyNotice` and never carries generatedContentId for these phases.

- [ ] **Step 1: Write failing terminal-state and race tests**

For health and unavailable results, assert:

```dart
expect(controller.state.phase, CustomSceneSubmissionPhase.healthSafety);
expect(controller.state.generatedContentId, isNull);
expect(registrar.calls, 0);
expect(handoff.calls, 0);
expect(audioStop.calls, 1);
expect(await draftStore.read(now: clock()), isNull);
```

Add race tests: an older generated network result arrives after a newer health result; a delayed audio callback arrives after safety; draft cleanup throws; account switches; process restarts with `submitting` or an unknown new state. Safety remains visible, no registration/play occurs, and restart requires fresh classification.

- [ ] **Step 2: Run focused tests and verify RED**

```bash
cd mobile && flutter test test/features/custom_scene/custom_scene_submission_controller_test.dart test/features/custom_scene/custom_scene_draft_continuation_test.dart test/features/custom_scene/custom_scene_input_screen_test.dart test/features/practice/generated/generated_audio_api_test.dart test/features/practice/generated/generated_care_moment_local_store_test.dart test/features/care_path/care_audio_session_coordinator_test.dart
```

Expected: FAIL because controller handles every success as a generated moment.

- [ ] **Step 3: Branch submission by result type**

Use exhaustive Dart pattern matching:

```dart
switch (await _repository.generate(submitting.toDraft())) {
  case GeneratedSceneResult(:final moment):
    await _persistAndRegister(moment, submitting, accountContext, operationEpoch);
  case HealthSafetyResult(:final safety):
    await _publishSafety(CustomSceneSubmissionPhase.healthSafety, safety, operationEpoch);
  case AssessmentUnavailableResult(:final safety):
    await _publishSafety(CustomSceneSubmissionPhase.assessmentUnavailable, safety, operationEpoch);
}
```

`_publishSafety` first increments/validates the operation epoch, clears `_approvedMomentPendingRegistration`, calls `CareAudioSessionCoordinator.stopActive()`, publishes notice, then best-effort deletes draft and authentication continuation. Do not publish before `stopActive()` completes: the test timeout for the local stop boundary is 250 ms, after which the coordinator invalidates the session and returns. A cleanup error must not replace the safety state.

- [ ] **Step 4: Harden recovery and local audio cache**

Do not persist health input or notice. Any recovery state without `safetyPolicyVersion == 'health-safety-v1'` and `contentRefreshEpoch == 2` returns to editing and requires resubmission. Add those fields to `StoredGeneratedCareMoment`, `GeneratedCareAudioSource`, and `GeneratedAudioCacheKey`; reject local-store decode/registry lookup for other values. Register the active `CareAudioPlaybackController` with `CareAudioSessionCoordinator` from `CareTurnSurface`, unregister only when the same owner disposes, and invalidate late completion callbacks on `stopActive()`.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run Step 2 command. Expected: PASS.

- [ ] **Step 6: Commit Task 6 only**

```bash
git add mobile/lib/features/custom_scene/application mobile/lib/features/custom_scene/domain/custom_scene_stored_draft.dart mobile/lib/features/custom_scene/data/custom_scene_draft_store.dart mobile/lib/app/providers/repository_providers.dart mobile/lib/app/custom_scene_recovery_coordinator.dart mobile/lib/features/care_path/application/care_audio_session_coordinator.dart mobile/lib/features/care_path/presentation/widgets/care_turn_surface.dart mobile/lib/features/care_path/domain/models/care_path_models.dart mobile/lib/features/practice/data/generated/generated_care_moment_local_store.dart mobile/lib/features/practice/data/generated/generated_practice_content_registry.dart mobile/lib/features/care_path/data/audio/generated_audio_memory_cache.dart mobile/test/features/custom_scene mobile/test/features/practice/generated/generated_audio_api_test.dart mobile/test/features/practice/generated/generated_care_moment_local_store_test.dart mobile/test/features/care_path/care_audio_session_coordinator_test.dart
git commit -m "feat(mobile): stop scene flow on health risk"
```

### Task 7: Render the accessible Chinese-only safety experience

**Files:**
- Modify: `mobile/lib/features/custom_scene/presentation/custom_scene_input_screen.dart`
- Test: `mobile/test/features/custom_scene/custom_scene_input_screen_test.dart`
- Test: `mobile/test/features/custom_scene/custom_scene_entry_test.dart`

**Interfaces:**
- Consumes: Task 6 safety states and `HealthSafetyNotice`.
- Produces: in-page `CustomSceneHealthSafetyPanel`, “关闭” and “修改描述” actions.

- [ ] **Step 1: Write failing widget tests**

```dart
expect(find.text('先关注宝宝的身体状况'), findsOneWidget);
expect(find.textContaining('请联系儿科医生进行评估'), findsOneWidget);
expect(find.text('帮我准备一句'), findsNothing);
expect(find.byKey(const Key('custom-scene-health-close')), findsOneWidget);
expect(find.byKey(const Key('custom-scene-health-edit')), findsOneWidget);
expect(tester.takeException(), isNull);
```

Assert no English/starter/audio/play/open-prepared/celebration widgets. For emergency notice at 320x568, verify title and action message are visible without scrolling. Verify live-region semantics announce title plus message once. Tapping “修改描述” clears notice, retains no old generated ID, focuses the text field, and creates a new request identity on resubmit. “关闭” exits without handoff.

- [ ] **Step 2: Run widget tests and verify RED**

```bash
cd mobile && flutter test test/features/custom_scene/custom_scene_input_screen_test.dart test/features/custom_scene/custom_scene_entry_test.dart
```

Expected: FAIL because safety panel and actions do not exist.

- [ ] **Step 3: Implement the safety panel in the existing input screen**

Render safety phases before the editable form. Use one `Semantics(container: true, liveRegion: true, label: '$title。$message')`. Keep the title/action above the fold, use theme tokens, and show only the fixed server/built-in Chinese strings. Do not add diagnosis copy, medical links, call buttons, retry-generation, audio controls, or celebratory UI.

- [ ] **Step 4: Run widget tests and verify GREEN**

Run Step 2 command. Expected: PASS.

- [ ] **Step 5: Commit Task 7 only**

```bash
git add mobile/lib/features/custom_scene/presentation/custom_scene_input_screen.dart mobile/test/features/custom_scene/custom_scene_input_screen_test.dart mobile/test/features/custom_scene/custom_scene_entry_test.dart
git commit -m "feat(mobile): show Chinese health guidance"
```

### Task 8: Add privacy-safe observability and end-to-end release gates

**Files:**
- Create: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/safety/CustomSceneSafetyMetrics.java`
- Create: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/safety/CustomSceneSafetyCorpusTest.java`
- Modify: `backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/safety/CustomSceneSafetyPolicy.java`
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/CustomSceneAgenticGenerationIntegrationTest.java`
- Modify: `backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/GeneratedUtteranceAudioHttpIntegrationTest.java`
- Create: `docs/release/custom-scene-health-safety-v1-checklist.md`

**Interfaces:**
- Consumes: Tasks 1–7 behavior.
- Produces: aggregate counters/timer and a release checklist containing medical review and client rollout gates.

- [ ] **Step 1: Write failing metric privacy and corpus tests**

Metrics allow only these tags: `result_type`, `template_id`, `policy_version`, `failure_kind`. Assert meter IDs and captured logs do not contain the input, evidence, account ID, installation ID, provider payload, or token.

Corpus must include every acceptance example in spec section 10. For deterministic tests, assert exact result and zero generation calls. For opt-in real-model evaluation, repeat each core health and emergency prompt five times with fixed provider/model/prompt/policy versions and write only aggregate pass/fail counts.

- [ ] **Step 2: Run focused backend integration tests and verify RED**

```bash
cd backend && bash mvnw -pl app-api -Dtest=CustomSceneSafetyCorpusTest,CustomSceneAgenticGenerationIntegrationTest,GeneratedUtteranceAudioHttpIntegrationTest test
```

Expected: FAIL because metrics/corpus coverage is incomplete.

- [ ] **Step 3: Implement privacy-safe metrics**

Record counters for each result type, classifier timeout, invalid output and blocked legacy bypass; record classifier duration. Pass enum-derived tags only. Do not attach free-text exception messages or trace IDs as metric tags.

- [ ] **Step 4: Write release checklist with hard gates**

The checklist must require:

```markdown
- [ ] Pediatric reviewer approved every signal mapping and all five Chinese templates; reviewer/date/source versions recorded outside runtime logs.
- [ ] v2-capable mobile build is the minimum supported build for custom-scene entry.
- [ ] v1 health request returns no English payload.
- [ ] Epoch-1 content cannot be opened, registered, or synthesized.
- [ ] Fixed corpus: every core health/emergency prompt passes 5/5; all ordinary negative controls match expected outcomes.
- [ ] Rollback target still contains health safety routing; otherwise disable custom-scene generation.
```

- [ ] **Step 5: Run full verification**

```bash
python3 tool/verify_spring_ai_2_backend_platform.py
cd backend && bash mvnw clean test
cd ../mobile && flutter test
```

Expected: all commands exit 0. If real-provider credentials are intentionally absent, deterministic corpus must pass and the opt-in five-run evaluation remains a checked release gate; do not report medical production readiness.

- [ ] **Step 6: Run formatting and diff checks**

```bash
cd mobile && dart format --output=none --set-exit-if-changed lib test
cd .. && git diff --check
```

Expected: exit 0 with no formatting or whitespace errors.

- [ ] **Step 7: Commit Task 8 only**

```bash
git add backend/app-api/src/main/java/com/zhangspaghetti/babytalk/practice/discovery/safety backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/discovery/safety backend/app-api/src/test/java/com/zhangspaghetti/babytalk/practice/generated/CustomSceneAgenticGenerationIntegrationTest.java backend/app-api/src/test/java/com/zhangspaghetti/babytalk/web/GeneratedUtteranceAudioHttpIntegrationTest.java docs/release/custom-scene-health-safety-v1-checklist.md
git commit -m "test(safety): gate health scene release"
```

## Execution Notes

- Before each `git add`, run `git status --short` and verify only task-owned hunks are staged. Several listed Flutter files are already modified in the current worktree; use patch staging or execute in a fresh worktree from commit `707430aa` to avoid mixing ownership.
- Do not deploy or enable the production policy from this implementation plan. Production enablement requires the medical and client-rollout checks in Task 8.
- Every generated-content read/play path must carry epoch 2. If a path cannot carry it, stop implementation and amend the approved spec before adding another trust marker or database column.
- If the classifier provider cannot enforce a 3-second timeout independently of generation routes, add a dedicated provider definition rather than increasing the approved timeout.

## Plan Self-Review

- Spec sections 1 and 4–5 map to Tasks 1–3: intent/action model, hard-rule precedence, semantic classification, fail-closed behavior and fixed Chinese templates.
- Spec sections 2, 6 and 6.1 map to Tasks 2–3: current service ordering, locked prompt resources, shared v1/v2 routing and old-client error contracts.
- Spec section 7 maps to Tasks 4–6: admission before replay/cache, epoch 2, generated-content ID/audio checks and local policy/epoch rejection.
- Spec section 8 maps to Tasks 5–7: discriminated result, terminal state, draft cleanup, late-response suppression, global audio stop and accessible Chinese-only UI.
- Spec sections 3, 9 and 10 map to Tasks 1, 2 and 8: medical-source boundary, privacy-safe metrics, full corpus, five-run model gate and pediatric review gate.
- No database migration, diagnosis, treatment advice, hospital search, auto-dial, multi-turn symptom collection, v1 fallback or production deployment is included.
- Gap review: none. Production activation intentionally remains blocked on pediatric review and v2 client rollout evidence.
