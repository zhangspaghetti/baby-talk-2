package com.zhangspaghetti.babytalk.practice.scene;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class SceneGenerationRequestTest {

    @Test
    void customRequestAndNestedSourceToStringNeverExposeSensitiveValues() {
        var source = new SceneGenerationRequest.SourceRequest("custom", "宝宝的秘密洗澡安排", null);
        var request = new SceneGenerationRequest(
                source, "zh-CN", "installation-secret-123", "client-secret-456");

        assertThat(source.toString())
                .contains("type=custom", "textPresent=true", "presetSceneIdPresent=false")
                .doesNotContain("宝宝的秘密洗澡安排", "installation-secret-123", "client-secret-456");
        assertThat(request.toString())
                .contains("sourceType=custom", "localePresent=true", "installationIdPresent=true",
                        "clientRequestIdPresent=true")
                .doesNotContain("宝宝的秘密洗澡安排", "installation-secret-123", "client-secret-456");
    }

    @Test
    void presetRequestToStringExposesOnlySafePresenceMetadata() {
        var source = new SceneGenerationRequest.SourceRequest("preset", null, "private-preset-id");
        var request = new SceneGenerationRequest(
                source, "zh-CN", "installation-secret-789", "client-secret-987");

        assertThat(source.toString())
                .contains("type=preset", "textPresent=false", "presetSceneIdPresent=true")
                .doesNotContain("private-preset-id", "installation-secret-789", "client-secret-987");
        assertThat(request.toString())
                .contains("sourceType=preset", "localePresent=true", "installationIdPresent=true",
                        "clientRequestIdPresent=true")
                .doesNotContain("private-preset-id", "installation-secret-789", "client-secret-987");
    }
}
