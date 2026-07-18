package com.zhangspaghetti.babytalk.practice.agentic;

import static org.assertj.core.api.Assertions.assertThat;

import java.net.URI;
import java.time.Duration;
import org.junit.jupiter.api.Test;

class PracticeAiOpenAiOptionsFactoryTest {

    private final PracticeAiOpenAiOptionsFactory factory = new PracticeAiOpenAiOptionsFactory();

    @Test
    void forcesOneChoiceAndDisablesSdkRetriesWithoutInventingTemperature() {
        var options = factory.build(provider(null, 128, null), "secret-value");

        assertThat(options.getBaseUrl()).isEqualTo("https://example.invalid/v1");
        assertThat(options.getApiKey()).isEqualTo("secret-value");
        assertThat(options.getModel()).isEqualTo("gpt-4o-mini");
        assertThat(options.getTimeout()).isEqualTo(Duration.ofSeconds(2));
        assertThat(options.getN()).isEqualTo(1);
        assertThat(options.getMaxRetries()).isZero();
        assertThat(options.getTemperature()).isNull();
        assertThat(options.getMaxTokens()).isEqualTo(128);
        assertThat(options.getMaxCompletionTokens()).isNull();
    }

    @Test
    void setsOptionalTemperatureAndExactlyOneCompletionTokenField() {
        var options = factory.build(provider(0.2d, null, 256), "secret-value");

        assertThat(options.getTemperature()).isEqualTo(0.2d);
        assertThat(options.getMaxTokens()).isNull();
        assertThat(options.getMaxCompletionTokens()).isEqualTo(256);
        assertThat(options.getN()).isEqualTo(1);
        assertThat(options.getMaxRetries()).isZero();
    }

    private PracticeAiProperties.ProviderDefinition provider(
            Double temperature,
            Integer maxTokens,
            Integer maxCompletionTokens
    ) {
        return new PracticeAiProperties.ProviderDefinition(
                "openai-compatible",
                URI.create("https://example.invalid/v1"),
                "TEST_AI_KEY",
                "gpt-4o-mini",
                Duration.ofSeconds(2),
                temperature,
                maxTokens,
                maxCompletionTokens);
    }
}
