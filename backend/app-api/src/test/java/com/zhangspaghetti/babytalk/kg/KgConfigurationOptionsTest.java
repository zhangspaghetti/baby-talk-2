package com.zhangspaghetti.babytalk.kg;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.config.MentorProperties;
import java.time.Duration;
import java.util.List;
import org.junit.jupiter.api.Test;

class KgConfigurationOptionsTest {

    private final KgConfiguration configuration = new KgConfiguration();

    @Test
    void buildsSpringAi2OptionsForKgReview() {
        var options = configuration.openAiOptions(properties(
                "https://models.inference.ai.azure.com", "secret", "gpt-4o-mini", 600, 10), "secret");

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
                "https://models.inference.ai.azure.com", "secret", "gpt-4o-mini", 600, 1), "secret");

        assertThat(options.getMaxRetries()).isZero();
    }

    private static MentorProperties properties(
            String baseUrl, String apiKey, String model, Integer maxTokens, int maxAttempts) {
        return new MentorProperties(
                "openai",
                Duration.ofSeconds(4),
                baseUrl,
                apiKey,
                model,
                0.7,
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
