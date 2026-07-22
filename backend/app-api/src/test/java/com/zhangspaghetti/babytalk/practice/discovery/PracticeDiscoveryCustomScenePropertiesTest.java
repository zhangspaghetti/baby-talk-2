package com.zhangspaghetti.babytalk.practice.discovery;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

class PracticeDiscoveryCustomScenePropertiesTest {

    @Test
    void persistedPromptAndStrategyVersionsRespectDatabaseLengths() {
        assertThatThrownBy(() -> properties("p".repeat(49), "strategy-v1", null))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("prompt version");
        assertThatThrownBy(() -> properties("prompt-v1", "s".repeat(49), null))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("strategy version");
    }

    @Test
    void maxGenerationAttemptsDefaultsToTwo() {
        assertThat(properties("prompt-v1", "strategy-v1", null).maxGenerationAttempts()).isEqualTo(2);
    }

    @ParameterizedTest
    @ValueSource(ints = {1, 2, 5})
    void acceptsBoundedMaxGenerationAttempts(int maxGenerationAttempts) {
        assertThat(properties("prompt-v1", "strategy-v1", maxGenerationAttempts).maxGenerationAttempts())
                .isEqualTo(maxGenerationAttempts);
    }

    @ParameterizedTest
    @ValueSource(ints = {0, 6})
    void rejectsOutOfRangeMaxGenerationAttempts(int maxGenerationAttempts) {
        assertThatThrownBy(() -> properties("prompt-v1", "strategy-v1", maxGenerationAttempts))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("generation attempts");
    }

    private PracticeDiscoveryCustomSceneProperties properties(
            String promptVersion,
            String strategyVersion,
            Integer maxGenerationAttempts
    ) {
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
                null,
                maxGenerationAttempts);
    }
}
