package com.zhangspaghetti.babytalk.practice.discovery;

import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Duration;
import org.junit.jupiter.api.Test;

class PracticeDiscoveryCustomScenePropertiesTest {

    @Test
    void persistedPromptAndStrategyVersionsRespectDatabaseLengths() {
        assertThatThrownBy(() -> properties("p".repeat(49), "strategy-v1"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("prompt version");
        assertThatThrownBy(() -> properties("prompt-v1", "s".repeat(49)))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("strategy version");
    }

    private PracticeDiscoveryCustomSceneProperties properties(String promptVersion, String strategyVersion) {
        return new PracticeDiscoveryCustomSceneProperties(
                true,
                Duration.ofSeconds(5),
                promptVersion,
                strategyVersion,
                "fake",
                null,
                null,
                null,
                null,
                null,
                null);
    }
}
