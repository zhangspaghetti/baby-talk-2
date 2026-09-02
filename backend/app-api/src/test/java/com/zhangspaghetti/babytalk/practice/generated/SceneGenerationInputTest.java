package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.practice.scene.GenerationSubject;
import com.zhangspaghetti.babytalk.practice.scene.ScenePersonalizationContext;
import org.junit.jupiter.api.Test;

class SceneGenerationInputTest {

    @Test
    void carriesInstallationIdWithoutIncludingItInDiagnosticRendering() {
        var input = new SceneGenerationInput(
                "custom",
                "洗澡后哄睡",
                new GenerationSubject("actor", "owner", "profile", 3, "小米", "m7_11",
                        "calmer_care", "household", "primary"),
                new ScenePersonalizationContext("小米", "m7_11", "calmer_care", "zh-CN", "primary",
                        2, "engaged", "洗澡", "weekly-v4"),
                null,
                null,
                null,
                null,
                "zh-CN",
                "install-secret",
                "request-1");

        assertThat(input.installationId()).isEqualTo("install-secret");
        assertThat(input.toString()).doesNotContain("install-secret", "小米", "洗澡后哄睡");

        var malformed = new SceneGenerationInput(
                "raw prompt should not be logged",
                "ignored",
                input.subject(),
                input.personalization(),
                null,
                null,
                null,
                null,
                "zh-CN",
                "install-secret",
                "request-1");
        assertThat(malformed.toString()).doesNotContain("raw prompt should not be logged");
    }
}
