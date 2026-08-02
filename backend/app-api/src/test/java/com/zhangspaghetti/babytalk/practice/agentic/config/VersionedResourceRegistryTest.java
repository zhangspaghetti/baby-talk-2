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

        assertThat(profile.version()).isEqualTo("custom-scene-generation-v3");
        assertThat(profile.contentHash())
                .isEqualTo("a207f125c7beb7e80d5aad104f9339ff280972b77326b6c9d97fd96d171ef66b");
        assertThat(profile.generatorPrompt().version()).isEqualTo("custom-scene-generator-v3");
        assertThat(profile.judgePrompt().version()).isEqualTo("custom-scene-quality-judge-v2");
        assertThat(profile.repairPrompt().version()).isEqualTo("custom-scene-repair-v3");
        assertThat(profile.rubricVersion()).isEqualTo("custom-scene-quality-v1");
        assertThat(profile.evidencePolicyVersion()).isEqualTo("custom-scene-evidence-v1");
        assertThat(profile.minimumCompleteBundleOutputTokens()).isEqualTo(8192);
        assertThat(registry.promptText(VersionedResourceRegistry.PromptKind.GENERATOR)).contains("strict JSON");
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
                        "Do not relax any rubric dimension");
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
