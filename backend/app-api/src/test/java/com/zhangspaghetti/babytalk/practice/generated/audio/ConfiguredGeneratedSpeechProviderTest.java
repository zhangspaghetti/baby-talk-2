package com.zhangspaghetti.babytalk.practice.generated.audio;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Duration;
import java.util.concurrent.TimeoutException;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;

class ConfiguredGeneratedSpeechProviderTest {

    @Test
    void realProviderAdapterSendsOnlyStoredApprovedTextAndReturnsConfiguredAudioIdentity() {
        var sentText = new AtomicReference<String>();
        var provider = new ConfiguredGeneratedSpeechProvider(properties(), text -> {
            sentText.set(text);
            return new byte[] {0x49, 0x44, 0x33};
        });

        var response = provider.synthesize(new GeneratedSpeechSynthesisPort.GeneratedSpeechRequest(
                "pgc_1", "utt_1", "Stored approved phrase."));

        assertThat(sentText).hasValue("Stored approved phrase.");
        assertThat(response.bytes()).containsExactly(0x49, 0x44, 0x33);
        assertThat(response.mimeType()).isEqualTo("audio/mpeg");
        assertThat(response.voiceVersion()).isEqualTo("generated-tts-v1");
    }

    @Test
    void timeoutCauseMapsToSanitizedTimeoutWithoutProviderPayload() {
        var provider = new ConfiguredGeneratedSpeechProvider(properties(), text -> {
            throw new IllegalStateException("provider body: Stored approved phrase.", new TimeoutException("deadline"));
        });

        assertThatThrownBy(() -> provider.synthesize(new GeneratedSpeechSynthesisPort.GeneratedSpeechRequest(
                "pgc_1", "utt_1", "Stored approved phrase.")))
                .isInstanceOf(GeneratedSpeechSynthesisException.class)
                .satisfies(error -> {
                    var exception = (GeneratedSpeechSynthesisException) error;
                    assertThat(exception.kind()).isEqualTo(GeneratedSpeechSynthesisException.Kind.TIMEOUT);
                    assertThat(exception.getMessage()).doesNotContain("Stored approved phrase.");
                });
    }

    private GeneratedSpeechProperties properties() {
        return new GeneratedSpeechProperties(
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
    }
}
