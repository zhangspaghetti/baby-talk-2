package com.zhangspaghetti.babytalk.practice.generated.audio;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Duration;
import org.junit.jupiter.api.Test;

class GeneratedSpeechPropertiesTest {

    @Test
    void disabledFeatureRequiresDisabledProviderAndStillHasBoundedRuntimeLimits() {
        var properties = properties(false, "disabled", Duration.ofSeconds(5), 524_288);

        assertThat(properties.mimeType()).isEqualTo("audio/mpeg");
        assertThatThrownBy(() -> properties(false, "fake", Duration.ofSeconds(5), 512))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("disabled generated speech");
        assertThatThrownBy(() -> properties(true, "fake", Duration.ofSeconds(6), 512))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("at most 5 seconds");
        assertThatThrownBy(() -> properties(true, "fake", Duration.ofSeconds(5), 1_048_577))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("max bytes");
    }

    @Test
    void configuredProviderRequiresACompleteOpenAiCompatibleConfiguration() {
        assertThatThrownBy(() -> new GeneratedSpeechProperties(
                true,
                "openai",
                Duration.ofSeconds(5),
                512,
                "generated-tts-v1",
                "mp3",
                "ftp://provider.example.com",
                "TEST_GENERATED_AUDIO_KEY",
                "gpt-4o-mini-tts",
                "alloy"
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("HTTP or HTTPS");
    }

    private GeneratedSpeechProperties properties(
            boolean enabled,
            String providerMode,
            Duration timeout,
            int maxBytes
    ) {
        return new GeneratedSpeechProperties(
                enabled,
                providerMode,
                timeout,
                maxBytes,
                "generated-tts-v1",
                "mp3",
                null,
                null,
                null,
                null
        );
    }
}
