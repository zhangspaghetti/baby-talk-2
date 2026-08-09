package com.zhangspaghetti.babytalk.practice.agentic.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;
import org.springframework.core.io.DefaultResourceLoader;

class VersionedResourceRegistryTest {

    private final VersionedResourceRegistry registry = new VersionedResourceRegistry(new DefaultResourceLoader());

    @Test
    void loadsProfileAndComputesStableCanonicalHashes() {
        var profile = registry.currentGenerationProfile();

        assertThat(profile.version()).isEqualTo("custom-scene-generation-v7");
        assertThat(profile.contentHash())
                .isEqualTo("d946c7d8bb7207215b7b730b2c7ca06e4b641226362e8333f20d5f79fa97b741");
        assertThat(profile.generatorPrompt().version()).isEqualTo("custom-scene-generator-v3");
        assertThat(profile.judgePrompt().version()).isEqualTo("custom-scene-quality-judge-v3");
        assertThat(profile.repairPrompt().version()).isEqualTo("custom-scene-repair-v3");
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
}
