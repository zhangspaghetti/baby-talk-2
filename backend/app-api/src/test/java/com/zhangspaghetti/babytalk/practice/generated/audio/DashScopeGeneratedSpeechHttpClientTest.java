package com.zhangspaghetti.babytalk.practice.generated.audio;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.header;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.headerDoesNotExist;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.content;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withStatus;

import java.net.URI;
import java.time.Duration;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.client.RestClient;
import org.springframework.test.web.client.MockRestServiceServer;

class DashScopeGeneratedSpeechHttpClientTest {

    @Test
    void sendsOnlyApprovedTextAndDownloadsBoundedMp3FromTheAllowlistedHost() {
        var builder = RestClient.builder();
        var server = MockRestServiceServer.bindTo(builder).build();
        var client = new DashScopeGeneratedSpeechHttpClient(properties(), "test-only-key", builder);
        var audio = validMp3Frame();

        server.expect(requestTo("https://dashscope.aliyuncs.com/api/v1/services/audio/tts/SpeechSynthesizer"))
                .andExpect(method(HttpMethod.POST))
                .andExpect(header("Authorization", "Bearer test-only-key"))
                .andExpect(content().string("{\"model\":\"qwen-audio-3.0-tts-flash\",\"input\":{\"text\":\"Stored approved phrase.\",\"voice\":\"loongeva_v3.6\",\"format\":\"mp3\",\"sample_rate\":24000}}"))
                .andRespond(withSuccess("""
                        {"request_id":"provider-private","output":{"finish_reason":"stop","audio":{
                          "data":"","url":"https://dashscope-result-bj.oss-cn-beijing.aliyuncs.com/audio.mp3",
                          "id":"provider-private","expires_at":1772697707}},"usage":{"characters":23}}
                        """, MediaType.APPLICATION_JSON));
        server.expect(requestTo("https://dashscope-result-bj.oss-cn-beijing.aliyuncs.com/audio.mp3"))
                .andExpect(method(HttpMethod.GET))
                .andExpect(headerDoesNotExist("Authorization"))
                .andRespond(withSuccess(audio, MediaType.parseMediaType("audio/mpeg")));

        assertThat(client.synthesize("Stored approved phrase.")).isEqualTo(audio);
        server.verify();
    }

    @Test
    void upgradesTheOfficialHttpResultUrlBeforeDownloading() {
        var harness = harness();
        var audio = validMp3WithEmptyId3Tag();
        expectEnvelope(harness.server(), "http://dashscope-result-bj.oss-cn-beijing.aliyuncs.com/audio.mp3");
        harness.server().expect(requestTo("https://dashscope-result-bj.oss-cn-beijing.aliyuncs.com/audio.mp3"))
                .andExpect(method(HttpMethod.GET))
                .andRespond(withSuccess(audio, AUDIO_MPEG));

        assertThat(harness.client().synthesize("Stored approved phrase.")).isEqualTo(audio);
        harness.server().verify();
    }

    @Test
    void acceptsACompleteId3v24FooterBeforeTheMpegFrame() {
        var harness = harness();
        var audio = validMp3WithEmptyId3Footer();
        expectEnvelope(harness.server(), "https://dashscope-result-bj.oss-cn-beijing.aliyuncs.com/audio.mp3");
        harness.server().expect(requestTo("https://dashscope-result-bj.oss-cn-beijing.aliyuncs.com/audio.mp3"))
                .andRespond(withSuccess(audio, AUDIO_MPEG));

        assertThat(harness.client().synthesize("Stored approved phrase.")).isEqualTo(audio);
        harness.server().verify();
    }

    @Test
    void rejectsMalformedEnvelopeWithoutExposingProviderPayload() {
        var harness = harness();
        harness.server().expect(requestTo(PROVIDER_URL))
                .andRespond(withSuccess("provider body: Stored approved phrase.", MediaType.APPLICATION_JSON));

        assertUnavailableAndSanitized(() -> harness.client().synthesize("Stored approved phrase."));
        harness.server().verify();
    }

    @Test
    void rejectsIncompleteNonStreamingEnvelope() {
        var harness = harness();
        harness.server().expect(requestTo(PROVIDER_URL))
                .andRespond(withSuccess("""
                        {"output":{"finish_reason":"stop","audio":{
                          "url":"https://dashscope-result-bj.oss-cn-beijing.aliyuncs.com/audio.mp3"}}}
                        """, MediaType.APPLICATION_JSON));

        assertUnavailableAndSanitized(() -> harness.client().synthesize("Stored approved phrase."));
        harness.server().verify();
    }

    @Test
    void rejectsProviderFailureWithoutExposingProviderPayload() {
        var harness = harness();
        harness.server().expect(requestTo(PROVIDER_URL))
                .andRespond(withStatus(HttpStatus.TOO_MANY_REQUESTS)
                        .body("provider body: Stored approved phrase.")
                        .contentType(MediaType.APPLICATION_JSON));

        assertUnavailableAndSanitized(() -> harness.client().synthesize("Stored approved phrase."));
        harness.server().verify();
    }

    @Test
    void rejectsUntrustedDownloadHostBeforeAnyDownloadRequest() {
        var harness = harness();
        expectEnvelope(harness.server(), "https://attacker.invalid/audio.mp3");

        assertUnavailableAndSanitized(() -> harness.client().synthesize("Stored approved phrase."));
        harness.server().verify();
    }

    @Test
    void rejectsRedirectWithoutFollowingItsLocation() {
        var harness = harness();
        expectEnvelope(harness.server(), "https://dashscope-result-bj.oss-cn-beijing.aliyuncs.com/audio.mp3");
        harness.server().expect(requestTo("https://dashscope-result-bj.oss-cn-beijing.aliyuncs.com/audio.mp3"))
                .andRespond(withStatus(HttpStatus.FOUND).location(URI.create("https://attacker.invalid/audio.mp3")));

        assertUnavailableAndSanitized(() -> harness.client().synthesize("Stored approved phrase."));
        harness.server().verify();
    }

    @Test
    void rejectsOversizeAudioBeforeReturningBytes() {
        var harness = harness();
        expectEnvelope(harness.server(), "https://dashscope-result-bj.oss-cn-beijing.aliyuncs.com/audio.mp3");
        harness.server().expect(requestTo("https://dashscope-result-bj.oss-cn-beijing.aliyuncs.com/audio.mp3"))
                .andRespond(withSuccess(new byte[513], AUDIO_MPEG));

        assertUnavailableAndSanitized(() -> harness.client().synthesize("Stored approved phrase."));
        harness.server().verify();
    }

    @Test
    void rejectsOversizeProviderEnvelopeBeforeParsingIt() {
        var harness = harness();
        harness.server().expect(requestTo(PROVIDER_URL))
                .andRespond(withSuccess(new byte[16_385], MediaType.APPLICATION_JSON));

        assertUnavailableAndSanitized(() -> harness.client().synthesize("Stored approved phrase."));
        harness.server().verify();
    }

    @Test
    void mapsDownloadFailureToStableSanitizedUnavailable() {
        var harness = harness();
        expectEnvelope(harness.server(), "https://dashscope-result-bj.oss-cn-beijing.aliyuncs.com/audio.mp3");
        harness.server().expect(requestTo("https://dashscope-result-bj.oss-cn-beijing.aliyuncs.com/audio.mp3"))
                .andRespond(withStatus(HttpStatus.SERVICE_UNAVAILABLE)
                        .body("private provider failure"));

        assertUnavailableAndSanitized(() -> harness.client().synthesize("Stored approved phrase."));
        harness.server().verify();
    }

    @Test
    void rejectsWrongAudioContentTypeAndWrongMp3Bytes() {
        var wrongType = harness();
        expectEnvelope(wrongType.server(), "https://dashscope-result-bj.oss-cn-beijing.aliyuncs.com/audio.mp3");
        wrongType.server().expect(requestTo("https://dashscope-result-bj.oss-cn-beijing.aliyuncs.com/audio.mp3"))
                .andRespond(withSuccess(new byte[] {0x49, 0x44, 0x33}, MediaType.APPLICATION_OCTET_STREAM));
        assertUnavailableAndSanitized(() -> wrongType.client().synthesize("Stored approved phrase."));
        wrongType.server().verify();

        var wrongBytes = harness();
        expectEnvelope(wrongBytes.server(), "https://dashscope-result-bj.oss-cn-beijing.aliyuncs.com/audio.mp3");
        wrongBytes.server().expect(requestTo("https://dashscope-result-bj.oss-cn-beijing.aliyuncs.com/audio.mp3"))
                .andRespond(withSuccess(new byte[] {0x52, 0x49, 0x46, 0x46}, AUDIO_MPEG));
        assertUnavailableAndSanitized(() -> wrongBytes.client().synthesize("Stored approved phrase."));
        wrongBytes.server().verify();
    }

    @Test
    void rejectsTruncatedId3AndFalseMpegFrameSync() {
        var truncatedId3 = harness();
        expectEnvelope(truncatedId3.server(), "https://dashscope-result-bj.oss-cn-beijing.aliyuncs.com/audio.mp3");
        truncatedId3.server().expect(requestTo("https://dashscope-result-bj.oss-cn-beijing.aliyuncs.com/audio.mp3"))
                .andRespond(withSuccess(new byte[] {0x49, 0x44, 0x33}, AUDIO_MPEG));
        assertUnavailableAndSanitized(() -> truncatedId3.client().synthesize("Stored approved phrase."));
        truncatedId3.server().verify();

        var falseFrameSync = harness();
        expectEnvelope(falseFrameSync.server(), "https://dashscope-result-bj.oss-cn-beijing.aliyuncs.com/audio.mp3");
        falseFrameSync.server().expect(requestTo("https://dashscope-result-bj.oss-cn-beijing.aliyuncs.com/audio.mp3"))
                .andRespond(withSuccess(new byte[] {(byte) 0xff, (byte) 0xe0, 0x00, 0x00}, AUDIO_MPEG));
        assertUnavailableAndSanitized(() -> falseFrameSync.client().synthesize("Stored approved phrase."));
        falseFrameSync.server().verify();
    }

    @Test
    void rejectsTruncatedOrMalformedId3v24Footer() {
        var truncatedFooter = harness();
        expectEnvelope(truncatedFooter.server(), "https://dashscope-result-bj.oss-cn-beijing.aliyuncs.com/audio.mp3");
        truncatedFooter.server().expect(requestTo("https://dashscope-result-bj.oss-cn-beijing.aliyuncs.com/audio.mp3"))
                .andRespond(withSuccess(new byte[] {
                        0x49, 0x44, 0x33, 0x04, 0x00, 0x10, 0x00, 0x00, 0x00, 0x00,
                        0x33, 0x44, 0x49
                }, AUDIO_MPEG));
        assertUnavailableAndSanitized(() -> truncatedFooter.client().synthesize("Stored approved phrase."));
        truncatedFooter.server().verify();

        var malformedFooter = harness();
        expectEnvelope(malformedFooter.server(), "https://dashscope-result-bj.oss-cn-beijing.aliyuncs.com/audio.mp3");
        var malformed = validMp3WithEmptyId3Footer();
        malformed[10] = 0x49;
        malformedFooter.server().expect(requestTo("https://dashscope-result-bj.oss-cn-beijing.aliyuncs.com/audio.mp3"))
                .andRespond(withSuccess(malformed, AUDIO_MPEG));
        assertUnavailableAndSanitized(() -> malformedFooter.client().synthesize("Stored approved phrase."));
        malformedFooter.server().verify();
    }

    @Test
    void mapsTransportTimeoutToTheStableSanitizedTimeout() {
        var harness = harness();
        harness.server().expect(requestTo(PROVIDER_URL)).andRespond(request -> {
            throw new java.net.SocketTimeoutException("provider body: Stored approved phrase.");
        });

        assertThatThrownBy(() -> harness.client().synthesize("Stored approved phrase."))
                .isInstanceOf(GeneratedSpeechSynthesisException.class)
                .satisfies(error -> {
                    var exception = (GeneratedSpeechSynthesisException) error;
                    assertThat(exception.kind()).isEqualTo(GeneratedSpeechSynthesisException.Kind.TIMEOUT);
                    assertThat(exception.getMessage()).isEqualTo("timeout");
                    assertThat(exception.getCause()).isNull();
                });
        harness.server().verify();
    }

    private Harness harness() {
        var builder = RestClient.builder();
        var server = MockRestServiceServer.bindTo(builder).build();
        return new Harness(server, new DashScopeGeneratedSpeechHttpClient(properties(), "test-only-key", builder));
    }

    private void expectEnvelope(MockRestServiceServer server, String audioUrl) {
        server.expect(requestTo(PROVIDER_URL))
                .andRespond(withSuccess("""
                        {"request_id":"provider-private","output":{"finish_reason":"stop","audio":{
                          "data":"","url":"%s","id":"provider-private","expires_at":1772697707}}}
                        """.formatted(audioUrl), MediaType.APPLICATION_JSON));
    }

    private void assertUnavailableAndSanitized(org.assertj.core.api.ThrowableAssert.ThrowingCallable call) {
        assertThatThrownBy(call)
                .isInstanceOf(GeneratedSpeechSynthesisException.class)
                .satisfies(error -> {
                    var exception = (GeneratedSpeechSynthesisException) error;
                    assertThat(exception.kind()).isEqualTo(GeneratedSpeechSynthesisException.Kind.UNAVAILABLE);
                    assertThat(exception.getMessage()).isEqualTo("unavailable");
                    assertThat(exception.getCause()).isNull();
                });
    }

    private GeneratedSpeechProperties properties() {
        return new GeneratedSpeechProperties(
                true,
                "dashscope",
                Duration.ofSeconds(5),
                512,
                16_384,
                "generated-dashscope-qwen-audio-v1",
                "mp3",
                "https://dashscope.aliyuncs.com/api/v1/services/audio/tts/SpeechSynthesizer",
                "BABY_TALK_AI_PROVIDER_DASHSCOPE_QWEN_API_KEY",
                "qwen-audio-3.0-tts-flash",
                "loongeva_v3.6",
                "qa-formal-v1",
                Set.of("dashscope-result-bj.oss-cn-beijing.aliyuncs.com")
        );
    }

    private byte[] validMp3Frame() {
        var frame = new byte[417];
        frame[0] = (byte) 0xff;
        frame[1] = (byte) 0xfb;
        frame[2] = (byte) 0x90;
        frame[3] = 0x00;
        return frame;
    }

    private byte[] validMp3WithEmptyId3Tag() {
        var frame = validMp3Frame();
        var audio = new byte[10 + frame.length];
        audio[0] = 0x49;
        audio[1] = 0x44;
        audio[2] = 0x33;
        audio[3] = 0x04;
        System.arraycopy(frame, 0, audio, 10, frame.length);
        return audio;
    }

    private byte[] validMp3WithEmptyId3Footer() {
        var frame = validMp3Frame();
        var audio = new byte[20 + frame.length];
        audio[0] = 0x49;
        audio[1] = 0x44;
        audio[2] = 0x33;
        audio[3] = 0x04;
        audio[5] = 0x10;
        audio[10] = 0x33;
        audio[11] = 0x44;
        audio[12] = 0x49;
        audio[13] = 0x04;
        audio[15] = 0x10;
        System.arraycopy(frame, 0, audio, 20, frame.length);
        return audio;
    }

    private record Harness(MockRestServiceServer server, DashScopeGeneratedSpeechHttpClient client) {
    }

    private static final String PROVIDER_URL =
            "https://dashscope.aliyuncs.com/api/v1/services/audio/tts/SpeechSynthesizer";
    private static final MediaType AUDIO_MPEG = MediaType.parseMediaType("audio/mpeg");
}
