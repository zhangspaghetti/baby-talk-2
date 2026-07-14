package com.zhangspaghetti.babytalk.config;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Duration;
import java.util.List;
import org.junit.jupiter.api.Test;

class MentorProviderConfigurationOptionsTest {

    private final MentorProviderConfiguration configuration = new MentorProviderConfiguration();

    @Test
    void buildsSpringAi2OptionsFromMentorProperties() {
        var options = configuration.openAiOptions(properties(
                "https://models.inference.ai.azure.com", "secret", "gpt-4o-mini", 0.2, 600, 10));

        assertThat(options.getBaseUrl()).isEqualTo("https://models.inference.ai.azure.com");
        assertThat(options.getApiKey()).isEqualTo("secret");
        assertThat(options.getModel()).isEqualTo("gpt-4o-mini");
        assertThat(options.getTemperature()).isEqualTo(0.2);
        assertThat(options.getMaxTokens()).isEqualTo(600);
        assertThat(options.getMaxRetries()).isEqualTo(9);
    }

    @Test
    void mapsSingleTotalAttemptToZeroSpringAiRetries() {
        var options = configuration.openAiOptions(properties(
                "https://models.inference.ai.azure.com", "secret", "gpt-4o-mini", 0.2, 600, 1));

        assertThat(options.getMaxRetries()).isZero();
    }

    private static MentorProperties properties(
            String baseUrl,
            String apiKey,
            String model,
            Double temperature,
            Integer maxTokens,
            int maxAttempts) {
        return new MentorProperties(
                "openai",
                Duration.ofSeconds(4),
                baseUrl,
                apiKey,
                model,
                temperature,
                maxTokens,
                maxAttempts,
                3,
                Duration.ofMinutes(10),
                280,
                280,
                List.of("home"),
                List.of("single_turn"),
                List.of("体罚"),
                "[timeout]",
                "[malformed]",
                "[unavailable]",
                "none",
                Duration.ofMinutes(30),
                2000);
    }
}
