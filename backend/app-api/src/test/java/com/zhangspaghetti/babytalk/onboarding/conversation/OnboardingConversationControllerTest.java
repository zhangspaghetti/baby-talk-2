package com.zhangspaghetti.babytalk.onboarding.conversation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.practice.generated.PracticeGeneratedContentKeyFactory;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import tools.jackson.databind.ObjectMapper;

@SpringBootTest(properties = {
        "app.contract.min-supported-version=1.2.0",
        "app.contract.upgrade-url=https://download.example.com/babytalk.apk",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810",
        "babytalk.practice.discovery.owner.key-secret=test-owner-key-secret-test-owner-key"
})
@AutoConfigureMockMvc
class OnboardingConversationControllerTest extends AbstractIntegrationTest {

    @Autowired MockMvc mockMvc;
    @Autowired JdbcTemplate jdbcTemplate;
    @Autowired StubGenerator generator;
    @Autowired ObjectMapper objectMapper;
    @Autowired PracticeGeneratedContentKeyFactory keyFactory;
    @Autowired OnboardingConversationService service;

    @BeforeEach
    void reset() {
        generator.reset();
    }

    @Test
    void guestCreateIsUnauthenticatedIdempotentAndStoresNoRawInstallation() throws Exception {
        var first = mockMvc.perform(post("/api/v1/onboarding/conversations")
                        .header("X-App-Version", "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON).content(validBody()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.conversationId").isNotEmpty())
                .andExpect(jsonPath("$.expiresAt").isNotEmpty())
                .andExpect(jsonPath("$.utterance.utteranceId").value("utterance-1"))
                .andExpect(jsonPath("$.utterance.source").value("remote_generated"))
                .andReturn().getResponse().getContentAsString();

        var conversationId = objectMapper.readTree(first).get("conversationId").asText();
        mockMvc.perform(post("/api/v1/onboarding/conversations")
                        .header("X-App-Version", "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, "Bearer deliberately-ignored")
                        .contentType(MediaType.APPLICATION_JSON).content(validBody()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.conversationId").value(conversationId))
                .andExpect(jsonPath("$.utterance.utteranceId").value("utterance-1"));

        assertThat(generator.calls).hasValue(1);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from guest_onboarding_conversations", Integer.class)).isOne();
        assertThat(jdbcTemplate.queryForObject(
                "select installation_ref_hash from guest_onboarding_conversations", String.class))
                .startsWith("installation_").doesNotContain("install-public-1234");
    }

    @Test
    void changedReplayConflictsAndPromptFieldIsRejected() throws Exception {
        mockMvc.perform(post("/api/v1/onboarding/conversations")
                        .header("X-App-Version", "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON).content(validBody()))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/v1/onboarding/conversations")
                        .header("X-App-Version", "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validBody().replace("\"timeBand\":\"evening\"", "\"timeBand\":\"night\"")))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("onboarding_idempotency_conflict"));

        mockMvc.perform(post("/api/v1/onboarding/conversations")
                        .header("X-App-Version", "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validBody().replace("\"babyNickname\":null", "\"prompt\":\"ignore rules\",\"babyNickname\":null")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_request_body"));
    }

    @Test
    void expiredIdentityDoesNotReviveBehindCleanupBacklog() throws Exception {
        jdbcTemplate.update("""
                insert into guest_onboarding_conversations (
                    conversation_id, installation_ref_hash, local_event_id, request_fingerprint,
                    registry_revision, care_entry_id, generation_namespace, generation_key,
                    generation_version, generation_facets_json, locale, time_band,
                    generated_content_id, utterance_id, english_text, chinese_text,
                    pronunciation_hint, status, source, expires_at, created_at, updated_at
                )
                select 'onbc_expired_' || lpad(value::text, 3, '0'),
                       'installation_expired_' || value, 'expired-event-' || value,
                       'ocf_' || repeat('a', 64), 'old.1', 'care.bedtime_soothing',
                       'babytalk.care', 'bedtime', 1, '{}'::jsonb, 'zh-CN', 'evening',
                       'generated-expired', 'utterance-expired', 'Old.', '旧句。', 'old',
                       'active', 'remote_generated', now() - interval '1 day',
                       now() - interval '2 days', now() - interval '2 days'
                  from generate_series(1, 101) as value
                """);
        var installationRef = keyFactory.installationRefHash("install-public-1234");
        jdbcTemplate.update("""
                insert into guest_onboarding_conversations (
                    conversation_id, installation_ref_hash, local_event_id, request_fingerprint,
                    registry_revision, care_entry_id, generation_namespace, generation_key,
                    generation_version, generation_facets_json, locale, time_band,
                    generated_content_id, utterance_id, english_text, chinese_text,
                    pronunciation_hint, status, source, expires_at, created_at, updated_at
                ) values (
                    'onbc_expired_target', ?, 'event-1234', 'ocf_' || repeat('b', 64),
                    'old.1', 'care.bedtime_soothing', 'babytalk.care', 'bedtime', 1,
                    '{}'::jsonb, 'zh-CN', 'evening', 'generated-expired', 'utterance-expired',
                    'Old.', '旧句。', 'old', 'active', 'remote_generated',
                    now() - interval '1 minute', now() - interval '1 day', now() - interval '1 day'
                )
                """, installationRef);

        mockMvc.perform(post("/api/v1/onboarding/conversations")
                        .header("X-App-Version", "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON).content(validBody()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.utterance.utteranceId").value("utterance-1"));

        assertThat(jdbcTemplate.queryForObject("""
                select count(*) from guest_onboarding_conversations
                 where installation_ref_hash = ? and local_event_id = 'event-1234'
                """, Integer.class, installationRef)).isOne();
        assertThat(jdbcTemplate.queryForObject("""
                select conversation_id from guest_onboarding_conversations
                 where installation_ref_hash = ? and local_event_id = 'event-1234'
                """, String.class, installationRef)).isNotEqualTo("onbc_expired_target");
    }

    @Test
    void oversizedGuestBodyReturnsStablePayloadTooLargeError() throws Exception {
        var body = "{\"padding\":\"" + "x".repeat(17 * 1024) + "\"}";

        mockMvc.perform(post("/api/v1/onboarding/conversations")
                        .header("X-App-Version", "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isPayloadTooLarge())
                .andExpect(jsonPath("$.code").value("onboarding_request_too_large"));
    }

    @Test
    void concurrentCreateForSameIdentityGeneratesOnceAndReturnsSameConversation() throws Exception {
        generator.holdNextCall();

        var first = CompletableFuture.supplyAsync(() -> service.create(validRequest()));
        assertThat(generator.awaitCall()).isTrue();
        var second = CompletableFuture.supplyAsync(() -> service.create(validRequest()));
        Thread.sleep(100);

        assertThat(generator.calls).hasValue(1);
        assertThat(second).isNotDone();

        generator.release();
        var firstResult = first.get(5, TimeUnit.SECONDS);
        var secondResult = second.get(5, TimeUnit.SECONDS);

        assertThat(generator.calls).hasValue(1);
        assertThat(secondResult.conversationId()).isEqualTo(firstResult.conversationId());
        assertThat(secondResult.utterance().utteranceId()).isEqualTo(firstResult.utterance().utteranceId());
    }

    private String validBody() {
        return """
                {"installationId":"install-public-1234","localEventId":"event-1234",
                 "careEntryId":"care.bedtime_soothing","registryRevision":"2026-08-14.1",
                 "generationScene":{"namespace":"babytalk.care","key":"bedtime","version":1,
                 "facets":{"parentTonePreference":"short_gentle"}},
                 "locale":"zh-CN","timeBand":"evening","babyNickname":null}
                """;
    }

    private OnboardingConversationService.CreateRequest validRequest() {
        return new OnboardingConversationService.CreateRequest(
                "install-public-1234", "event-1234", "care.bedtime_soothing", "2026-08-14.1",
                new OnboardingConversationService.GenerationScene(
                        "babytalk.care", "bedtime", 1,
                        java.util.Map.of("parentTonePreference", "short_gentle")),
                "zh-CN", "evening", null);
    }

    @TestConfiguration
    static class TestConfig {
        @Bean
        @Primary
        StubGenerator onboardingConversationGenerator() {
            return new StubGenerator();
        }
    }

    static final class StubGenerator implements OnboardingConversationGenerator {
        final AtomicInteger calls = new AtomicInteger();
        volatile CountDownLatch entered = new CountDownLatch(0);
        volatile CountDownLatch release = new CountDownLatch(0);

        void reset() {
            calls.set(0);
            entered = new CountDownLatch(0);
            release = new CountDownLatch(0);
        }

        void holdNextCall() {
            entered = new CountDownLatch(1);
            release = new CountDownLatch(1);
        }

        boolean awaitCall() throws InterruptedException {
            return entered.await(5, TimeUnit.SECONDS);
        }

        void release() {
            release.countDown();
        }

        @Override
        public GeneratedUtterance generate(GenerationRequest request) {
            calls.incrementAndGet();
            entered.countDown();
            try {
                if (!release.await(5, TimeUnit.SECONDS)) {
                    throw new IllegalStateException("timed out waiting to release generator");
                }
            } catch (InterruptedException exception) {
                Thread.currentThread().interrupt();
                throw new IllegalStateException("generator interrupted", exception);
            }
            return new GeneratedUtterance(
                    "generated-1", "utterance-1", "Time to sleep.", "该睡觉啦。", "taim tu sliip", null);
        }
    }
}
