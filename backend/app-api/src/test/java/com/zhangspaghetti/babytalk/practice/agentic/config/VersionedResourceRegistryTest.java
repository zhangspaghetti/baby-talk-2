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

        assertThat(profile.version()).isEqualTo("custom-scene-generation-v2");
        assertThat(profile.contentHash())
                .isEqualTo("21691398948fe5dc41a20282f4f26d446bc6e6e2e4fd5105be2942e1cf51ca07");
        assertThat(profile.generatorPrompt().version()).isEqualTo("custom-scene-generator-v2");
        assertThat(profile.repairPrompt().version()).isEqualTo("custom-scene-repair-v2");
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
                        "拿起",
                        "等宝宝");
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
