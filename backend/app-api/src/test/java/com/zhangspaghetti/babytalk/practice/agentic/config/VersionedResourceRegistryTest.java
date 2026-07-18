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

        assertThat(profile.version()).isEqualTo("custom-scene-generation-v1");
        assertThat(profile.contentHash()).matches("[0-9a-f]{64}");
        assertThat(profile.rubricVersion()).isEqualTo("custom-scene-quality-v1");
        assertThat(profile.evidencePolicyVersion()).isEqualTo("custom-scene-evidence-v1");
        assertThat(registry.promptText(VersionedResourceRegistry.PromptKind.GENERATOR)).contains("strict JSON");
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
