package com.zhangspaghetti.babytalk.practice.generated.audio;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Duration;
import java.util.Set;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;

class DashScopeGeneratedSpeechProviderTest {

    @Test
    void portSendsOnlyStoredApprovedEnglishAndReturnsConfiguredIdentity() {
        var sentText = new AtomicReference<String>();
        var provider = new DashScopeGeneratedSpeechProvider(properties(), text -> {
            sentText.set(text);
            return new byte[] {0x49, 0x44, 0x33};
        });

        var response = provider.synthesize(new GeneratedSpeechSynthesisPort.GeneratedSpeechRequest(
                "pgc_private", "utt_private", "Stored approved phrase."));

        assertThat(sentText).hasValue("Stored approved phrase.");
        assertThat(response.bytes()).containsExactly(0x49, 0x44, 0x33);
        assertThat(response.mimeType()).isEqualTo("audio/mpeg");
        assertThat(response.voiceVersion()).isEqualTo("generated-dashscope-qwen-audio-v1");
    }

    private GeneratedSpeechProperties properties() {
        return new GeneratedSpeechProperties(
                true, "dashscope", Duration.ofSeconds(5), 512, 16_384,
                "generated-dashscope-qwen-audio-v1", "mp3",
                "https://dashscope.aliyuncs.com/api/v1/services/audio/tts/SpeechSynthesizer",
                "BABY_TALK_AI_PROVIDER_DASHSCOPE_QWEN_API_KEY",
                "qwen-audio-3.0-tts-flash", "loongeva_v3.6", "qa-formal-v1",
                Set.of("dashscope-result-bj.oss-cn-beijing.aliyuncs.com")
        );
    }
}
