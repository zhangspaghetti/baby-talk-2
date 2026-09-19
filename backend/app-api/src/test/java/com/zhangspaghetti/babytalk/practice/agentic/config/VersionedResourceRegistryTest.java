package com.zhangspaghetti.babytalk.practice.agentic.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.zhangspaghetti.babytalk.practice.discovery.safety.CustomSceneSafetyProperties;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.List;
import org.springframework.core.io.ByteArrayResource;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.DefaultResourceLoader;
import org.springframework.core.io.Resource;
import org.springframework.core.io.ResourceLoader;
import org.springframework.core.io.DefaultResourceLoader;

class VersionedResourceRegistryTest {

    private final VersionedResourceRegistry registry = new VersionedResourceRegistry(new DefaultResourceLoader());

    @Test
    void loadsProfileAndComputesStableCanonicalHashes() {
        var profile = registry.currentGenerationProfile();

        assertThat(profile.version()).isEqualTo("custom-scene-generation-v7");
        assertThat(profile.contentHash())
                .isEqualTo("c2bb511b8ed95abd51cd2dd3cf88adc542a4025903b833d13a5fb036e1bbea84");
        assertThat(profile.generatorPrompt().version()).isEqualTo("custom-scene-generator-v3");
        assertThat(profile.judgePrompt().version()).isEqualTo("custom-scene-quality-judge-v3");
        assertThat(profile.repairPrompt().version()).isEqualTo("custom-scene-repair-v4");
        assertThat(profile.rubricVersion()).isEqualTo("custom-scene-quality-v1");
        assertThat(profile.evidencePolicyVersion()).isEqualTo("custom-scene-evidence-v1");
        assertThat(profile.minimumCompleteBundleOutputTokens()).isEqualTo(8192);
        assertThat(profile.minimumQualityJudgeOutputTokens()).isEqualTo(8192);
        assertThat(profile.repairInferencePolicy()).isEqualTo(
                new GenerationProfile.InferencePolicy(
                        "openai-compatible",
                        java.util.List.of("glm-5.2"),
                        PracticeAiReasoningEffort.NONE));
        assertThat(profile.generatorInferencePolicy()).isEqualTo(
                new GenerationProfile.InferencePolicy(
                        "openai-compatible",
                        java.util.List.of("glm-5.2"),
                        PracticeAiReasoningEffort.NONE));
        assertThat(profile.qualityJudgeInferencePolicy()).isEqualTo(
                new GenerationProfile.InferencePolicy(
                        "openai-compatible",
                        java.util.List.of("glm-5.2"),
                        PracticeAiReasoningEffort.NONE));
        assertThat(registry.promptText(VersionedResourceRegistry.PromptKind.GENERATOR)).contains("strict JSON");
    }

    @Test
    void loadsSafetyClassifierPromptAndExposesLockedOpaqueMetadata() {
        var prompt = registry.promptText(VersionedResourceRegistry.PromptKind.SAFETY_CLASSIFIER);
        var ref = registry.promptRef(VersionedResourceRegistry.PromptKind.SAFETY_CLASSIFIER);

        assertThat(ref.version()).isEqualTo("custom-scene-safety-classifier-v1");
        assertThat(ref.resourcePath())
                .isEqualTo("config/practice-ai/prompts/custom-scene-safety-classifier-v1.txt");
        assertThat(ref.contentHash())
                .isEqualTo("8e973dbaac37d54747833f3a9676349877307686859fbebfb37fa6d0e459232d");
        assertThat(prompt).contains("untrusted data", "exactly one JSON object", "medical advice");
        assertThat(registry.healthSafetyPolicyHash())
                .isEqualTo("7efe85daa60cfdb29bc4400a4666519c342f585a3486e2bfd23d1cbad1fbac27");
    }

    @Test
    void refusesSafetyClassifierPromptWhenLockHashMismatches() {
        assertThatThrownBy(() -> registryWithLock("0".repeat(64)))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("classifier prompt lock hash mismatch");
    }

    @Test
    void refusesSafetyClassifierPromptWhenLockIsMissing() {
        assertThatThrownBy(() -> new VersionedResourceRegistry(
                new DefaultResourceLoader(),
                "classpath:config/practice-ai/profiles/custom-scene-generation-v7.yml",
                CustomSceneSafetyProperties.defaults(),
                "classpath:config/practice-ai/missing-version-lock.yml"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("missing versioned resource");
    }

    @Test
    void refusesHealthSafetyPolicyWhenBoundTemplateCopyDiffersFromLockedContent() {
        var defaults = CustomSceneSafetyProperties.defaults();
        var templates = new LinkedHashMap<>(defaults.templates());
        var original = templates.get("health-concern-v1");
        templates.put("health-concern-v1", new CustomSceneSafetyProperties.Template(
                original.action(), original.locale(), original.titleZh(), original.messageZh() + "替换文案"));
        var replaced = new CustomSceneSafetyProperties(
                defaults.policyVersion(), defaults.classifierTimeout(), templates, defaults.emergencySignals());

        assertThatThrownBy(() -> new VersionedResourceRegistry(
                new DefaultResourceLoader(),
                "classpath:config/practice-ai/profiles/custom-scene-generation-v7.yml",
                replaced))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("health safety policy lock hash mismatch");
    }

    @Test
    void refusesHealthSafetyPolicyWhenBoundEmergencySignalDiffersFromLockedContent() {
        var defaults = CustomSceneSafetyProperties.defaults();
        var signals = new LinkedHashMap<>(defaults.emergencySignals());
        signals.put("seizure", List.of("替换信号"));
        var replaced = new CustomSceneSafetyProperties(
                defaults.policyVersion(), defaults.classifierTimeout(), defaults.templates(), signals);

        assertThatThrownBy(() -> new VersionedResourceRegistry(
                new DefaultResourceLoader(),
                "classpath:config/practice-ai/profiles/custom-scene-generation-v7.yml",
                replaced))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("health safety policy lock hash mismatch");
    }

    @Test
    void v6ProfileRemainsImmutableAndHasNoQualityJudgeInferenceOverride() {
        var legacy = registryFor("profiles/custom-scene-generation-v6.yml")
                .currentGenerationProfile();

        assertThat(legacy.version()).isEqualTo("custom-scene-generation-v6");
        assertThat(legacy.contentHash())
                .isEqualTo("da4bbe0e608725f2bd94e8131560158259f0dbe29698b1cf9ae41f423afed8d7");
        assertThat(legacy.qualityJudgeInferencePolicy()).isNull();
    }

    @Test
    void v5ProfileRemainsImmutableAndHasNoGeneratorInferenceOverride() {
        var legacy = registryFor("profiles/custom-scene-generation-v5.yml")
                .currentGenerationProfile();

        assertThat(legacy.version()).isEqualTo("custom-scene-generation-v5");
        assertThat(legacy.contentHash())
                .isEqualTo("aef5649cd454d6fa8f4704b8b4eacec7f421cda8f2ca30dd5e7aeec750eeef31");
        assertThat(legacy.generatorInferencePolicy()).isNull();
    }

    @Test
    void legacyProfileKeepsJudgeBudgetBehaviorUnchanged() {
        var legacy = registryFor("profiles/custom-scene-generation-v3.yml")
                .currentGenerationProfile();

        assertThat(legacy.version()).isEqualTo("custom-scene-generation-v3");
        assertThat(legacy.minimumQualityJudgeOutputTokens()).isZero();
        assertThat(legacy.repairInferencePolicy()).isNull();
    }

    @Test
    void v4ProfileRemainsImmutableAndHasNoRepairInferenceOverride() {
        var legacy = registryFor("profiles/custom-scene-generation-v4.yml")
                .currentGenerationProfile();

        assertThat(legacy.version()).isEqualTo("custom-scene-generation-v4");
        assertThat(legacy.contentHash())
                .isEqualTo("fe96ac339eda8bfcd653d90d83bd981e2aa296141ad5e066990c83e8ccc2110d");
        assertThat(legacy.repairInferencePolicy()).isNull();
    }

    @Test
    void v3ProfileSchemaRequiresCompleteRepairInferencePolicy() {
        assertThatThrownBy(() -> registryFor("fixtures/profile-repair-inference-missing.yml"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("profile repair-inference-policy must be a mapping");
    }

    @Test
    void v3ProfileSchemaRejectsUnsupportedRepairReasoningEffort() {
        assertThatThrownBy(() -> registryFor("fixtures/profile-repair-inference-invalid.yml"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("profile repair-inference-policy reasoning-effort is invalid");
    }

    @Test
    void v4ProfileSchemaRequiresCompleteGeneratorInferencePolicy() {
        assertThatThrownBy(() -> registryFor("fixtures/profile-generator-inference-missing.yml"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("profile generator-inference-policy must be a mapping");
    }

    @Test
    void v4ProfileSchemaRejectsUnsupportedGeneratorReasoningEffort() {
        assertThatThrownBy(() -> registryFor("fixtures/profile-generator-inference-invalid.yml"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("profile generator-inference-policy reasoning-effort is invalid");
    }

    @Test
    void v5ProfileSchemaRequiresCompleteQualityJudgeInferencePolicy() {
        assertThatThrownBy(() -> registryFor("fixtures/profile-quality-judge-inference-missing.yml"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("profile quality-judge-inference-policy must be a mapping");
    }

    @Test
    void v5ProfileSchemaRejectsUnsupportedQualityJudgeReasoningEffort() {
        assertThatThrownBy(() -> registryFor("fixtures/profile-quality-judge-inference-invalid.yml"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("profile quality-judge-inference-policy reasoning-effort is invalid");
    }

    @Test
    void currentPromptsDefineValidatorRecognizableRequirementsForEveryBranch() {
        assertThat(registry.promptText(VersionedResourceRegistry.PromptKind.GENERATOR))
                .contains(
                        "For every branch, tprActionZh",
                        "For every branch, deliveryGuidanceZh",
                        "拿起",
                        "等宝宝");
        assertThat(registry.promptText(VersionedResourceRegistry.PromptKind.REPAIR))
                .contains(
                        "Apply every structured branchRequirements item",
                        "MISSING_TPR_ACTION",
                        "MISSING_DELIVERY_GUIDANCE",
                        "judge_evidence_action_inconsistent",
                        "evidenceActionConsistencyPolicy.groundingSources",
                        "拿起",
                        "等宝宝");
        assertThat(registry.promptText(VersionedResourceRegistry.PromptKind.JUDGE))
                .contains(
                        "semantic triangle",
                        "Do not emit TPR_QUALITY_EVIDENCE_MISSING only because",
                        "Do not relax any rubric dimension",
                        "Each enum array must contain unique items only",
                        "Never repeat an enum item");
    }

    @Test
    void refusesResourceWhoseDeclaredVersionDoesNotMatchItsReferencedFile() {
        assertThatThrownBy(() -> registryFor("fixtures/profile-version-mismatch.yml"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("version mismatch");
    }

    @Test
    void refusesMissingDimensionOrUnknownVerdictPolicyKey() {
        assertThatThrownBy(() -> registryFor("fixtures/profile-rubric-invalid.yml"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("rubric schema");
    }

    private VersionedResourceRegistry registryFor(String profilePath) {
        return new VersionedResourceRegistry(new DefaultResourceLoader(), "classpath:config/practice-ai/" + profilePath);
    }

    private VersionedResourceRegistry registryWithLock(String hash) {
        var delegate = new DefaultResourceLoader();
        ResourceLoader loader = new ResourceLoader() {
            @Override
            public Resource getResource(String location) {
                if ("test-lock".equals(location)) {
                    var yaml = """
                            schema-version: practice-ai-version-lock-schema-v1
                            resources:
                            - version: custom-scene-safety-classifier-v1
                              resource-path: config/practice-ai/prompts/custom-scene-safety-classifier-v1.txt
                              content-hash: %s
                            """.formatted(hash);
                    return new ByteArrayResource(yaml.getBytes(StandardCharsets.UTF_8));
                }
                return delegate.getResource(location);
            }

            @Override
            public ClassLoader getClassLoader() {
                return delegate.getClassLoader();
            }
        };
        return new VersionedResourceRegistry(
                loader,
                "classpath:config/practice-ai/profiles/custom-scene-generation-v7.yml",
                CustomSceneSafetyProperties.defaults(),
                "test-lock");
    }
}
