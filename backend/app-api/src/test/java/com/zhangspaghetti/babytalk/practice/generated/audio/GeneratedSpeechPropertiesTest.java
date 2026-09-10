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
        assertThatThrownBy(() -> properties(true, "fake", Duration.ofSeconds(9), 512))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("at most 8 seconds");
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
                16_384,
                "generated-tts-v1",
                "mp3",
                "ftp://provider.example.com",
                "TEST_GENERATED_AUDIO_KEY",
                "gpt-4o-mini-tts",
                "alloy",
                "default",
                java.util.Set.of()
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("HTTP or HTTPS");
    }

    @Test
    void configurationIdentityIsStableAndExcludesTheProviderSecret() {
        var properties = new GeneratedSpeechProperties(
                true,
                "openai",
                Duration.ofSeconds(5),
                512,
                16_384,
                "generated-tts-v1",
                "mp3",
                "https://provider.example.com/v1",
                "TEST_GENERATED_AUDIO_KEY",
                "gpt-4o-mini-tts",
                "alloy",
                "uat-v1",
                java.util.Set.of()
        );

        var identity = properties.configurationIdentity();

        assertThat(identity.provider()).isEqualTo("openai");
        assertThat(identity.model()).isEqualTo("gpt-4o-mini-tts");
        assertThat(identity.profile()).isEqualTo("uat-v1");
        assertThat(identity.configurationFingerprint()).matches("[a-f0-9]{64}");
        assertThat(identity.configurationFingerprint()).doesNotContain("TEST_GENERATED_AUDIO_KEY");
    }

    @Test
    void dashScopeRequiresHttpsAndAnExplicitDownloadHostAllowlist() {
        assertThatThrownBy(() -> new GeneratedSpeechProperties(
                true, "dashscope", Duration.ofSeconds(5), 512, 16_384,
                "generated-dashscope-qwen-audio-v1", "mp3",
                "http://dashscope.aliyuncs.com/api/v1/services/audio/tts/SpeechSynthesizer",
                "BABY_TALK_AI_PROVIDER_DASHSCOPE_QWEN_API_KEY",
                "qwen-audio-3.0-tts-flash", "loongeva_v3.6", "qa-formal-v1",
                java.util.Set.of("dashscope-result-bj.oss-cn-beijing.aliyuncs.com")
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("HTTPS");

        assertThatThrownBy(() -> new GeneratedSpeechProperties(
                true, "dashscope", Duration.ofSeconds(5), 512, 16_384,
                "generated-dashscope-qwen-audio-v1", "mp3",
                "https://dashscope.aliyuncs.com/api/v1/services/audio/tts/SpeechSynthesizer",
                "BABY_TALK_AI_PROVIDER_DASHSCOPE_QWEN_API_KEY",
                "qwen-audio-3.0-tts-flash", "loongeva_v3.6", "qa-formal-v1",
                java.util.Set.of()
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("allowed download host");

        assertThatThrownBy(() -> new GeneratedSpeechProperties(
                true, "dashscope", Duration.ofSeconds(5), 512, 16_384,
                "generated-dashscope-qwen-audio-v1", "mp3",
                "https://dashscope.aliyuncs.com/compatible-mode/v1",
                "BABY_TALK_AI_PROVIDER_DASHSCOPE_QWEN_API_KEY",
                "qwen-audio-3.0-tts-flash", "loongeva_v3.6", "qa-formal-v1",
                java.util.Set.of("dashscope-result-bj.oss-cn-beijing.aliyuncs.com")
        )).isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("endpoint");
    }

    @Test
    void dashScopeConfigurationIdentityIncludesTheConfiguredModel() {
        var properties = new GeneratedSpeechProperties(
                true, "dashscope", Duration.ofSeconds(5), 512, 16_384,
                "generated-dashscope-qwen-audio-v1", "mp3",
                "https://dashscope.aliyuncs.com/api/v1/services/audio/tts/SpeechSynthesizer",
                "BABY_TALK_AI_PROVIDER_DASHSCOPE_QWEN_API_KEY",
                "qwen-audio-3.0-tts-flash", "loongeva_v3.6", "qa-formal-v1",
                java.util.Set.of("dashscope-result-bj.oss-cn-beijing.aliyuncs.com")
        );

        assertThat(properties.configurationIdentity().provider()).isEqualTo("dashscope");
        assertThat(properties.configurationIdentity().model()).isEqualTo("qwen-audio-3.0-tts-flash");
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
                16_384,
                "generated-tts-v1",
                "mp3",
                null,
                null,
                null,
                null,
                "default",
                java.util.Set.of()
        );
    }
}
