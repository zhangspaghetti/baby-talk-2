package com.zhangspaghetti.babytalk.web;

import static org.assertj.core.api.Assertions.assertThat;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.config.ApiVersionInterceptor;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.SpringBootTest.WebEnvironment;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Black-box HTTP coverage for generated audio. The only speech provider is the
 * existing dev-only fake; authentication, consent, ownership, ACTIVE lookup,
 * and controller response headers all run through the application server.
 */
@SpringBootTest(
        webEnvironment = WebEnvironment.RANDOM_PORT,
        properties = {
                "app.contract.min-supported-version=1.2.0",
                "app.contract.upgrade-url=https://download.example.com/babytalk.apk",
                "app.sms.provider-mode=dev",
                "app.sms.dev-code=246810",
                "app.auth.issuer=babytalk-generated-audio-it",
                "app.auth.jwt-secret=0123456789abcdef0123456789abcdef",
                "app.auth.sensitive-data-pepper=test-auth-sensitive-data-pepper-0123456789abcdef",
                "app.auth.access-token-ttl=PT15M",
                "app.auth.refresh-token-ttl=P7D",
                "babytalk.practice.generated-audio.enabled=true",
                "babytalk.practice.generated-audio.provider-mode=fake"
        })
@ActiveProfiles(profiles = {"test", "dev"}, inheritProfiles = false)
class GeneratedUtteranceAudioHttpIntegrationTest extends AbstractIntegrationTest {

    private static final String CONTENT_ID = "pgc_audio_http_1";
    private static final String STARTER_UTTERANCE_ID = "utt_audio_starter_1";
    private static final List<String> BUNDLE_UTTERANCE_IDS = List.of(
            STARTER_UTTERANCE_ID,
            "utt_audio_cooperating_1",
            "utt_audio_hesitant_1",
            "utt_audio_resisting_1",
            "utt_audio_no_response_1",
            "utt_audio_other_1"
    );
    private static final byte[] FAKE_MP3_BYTES = {0x49, 0x44, 0x33, 0x04, 0x00, 0x00};

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private PlatformTransactionManager transactionManager;

    @LocalServerPort
    private int port;

    private HttpClient httpClient;

    @BeforeEach
    void resetTables() {
        resetDatabase(jdbcTemplate);
        httpClient = HttpClient.newHttpClient();
    }

    @Test
    void acceptedOwnerReceivesActiveGeneratedAudioFromTheDevOnlyFakeProvider() throws Exception {
        var owner = authenticate("13800138021", "generated-audio-owner");
        seedActiveCarePathContent(owner.accountId());

        var beforeConsent = getAudio(owner.accessToken(), CONTENT_ID, STARTER_UTTERANCE_ID);
        assertThat(beforeConsent.statusCode()).isEqualTo(409);
        assertThat(readJson(beforeConsent.body()).get("code").asText()).isEqualTo("consent_required");

        acceptConsent(owner.accessToken());

        var beforeAudio = jdbcTemplate.queryForMap("""
                select status, content_version, updated_at
                from practice_generated_content
                where generated_content_id = ?
                """, CONTENT_ID);
        var audio = getAudio(owner.accessToken(), CONTENT_ID, STARTER_UTTERANCE_ID);
        assertThat(audio.statusCode()).isEqualTo(200);
        assertThat(audio.headers().firstValue("content-type")).contains("audio/mpeg");
        assertThat(audio.headers().firstValue("cache-control")).hasValueSatisfying(value -> {
            assertThat(value).contains("private").contains("no-store");
        });
        assertThat(audio.headers().firstValue("vary")).hasValue("Authorization");
        assertThat(audio.headers().firstValue("x-generated-audio-voice-version"))
                .hasValue("generated-tts-v1");
        assertThat(audio.headers().firstValue("x-generated-audio-provider")).hasValue("fake");
        assertThat(audio.headers().firstValue("x-generated-audio-model")).hasValue("fake");
        assertThat(audio.headers().firstValue("x-generated-audio-profile")).hasValue("default");
        assertThat(audio.headers().firstValue("x-generated-audio-configuration-fingerprint"))
                .hasValueSatisfying(value -> assertThat(value).matches("[a-f0-9]{64}"));
        assertThat(audio.body()).containsExactly(FAKE_MP3_BYTES);
        for (var utteranceId : BUNDLE_UTTERANCE_IDS) {
            var branchAudio = getAudio(owner.accessToken(), CONTENT_ID, utteranceId);
            assertThat(branchAudio.statusCode()).isEqualTo(200);
            assertThat(branchAudio.body()).containsExactly(FAKE_MP3_BYTES);
        }
        assertThat(jdbcTemplate.queryForMap("""
                select status, content_version, updated_at
                from practice_generated_content
                where generated_content_id = ?
                """, CONTENT_ID)).isEqualTo(beforeAudio);

        var otherOwner = authenticate("13800138022", "generated-audio-other");
        acceptConsent(otherOwner.accessToken());
        var denied = getAudio(otherOwner.accessToken(), CONTENT_ID, STARTER_UTTERANCE_ID);
        assertThat(denied.statusCode()).isEqualTo(404);
        assertThat(readJson(denied.body()).get("code").asText()).isEqualTo("generated_audio_not_found");
    }

    private TokenView authenticate(String phoneNumber, String installationId) throws Exception {
        var challenge = postJson("/api/v1/auth/challenges", """
                {"phoneNumber":"%s"}
                """.formatted(phoneNumber), null);
        assertThat(challenge.statusCode()).isEqualTo(201);
        var challengeId = readJson(challenge.body()).get("challengeId").asText();

        var verified = postJson("/api/v1/auth/verify", """
                {
                  "challengeId":"%s",
                  "verificationCode":"246810",
                  "installationId":"%s"
                }
                """.formatted(challengeId, installationId), null);
        assertThat(verified.statusCode()).isEqualTo(200);
        var body = readJson(verified.body());
        return new TokenView(body.get("accountId").asText(), body.get("accessToken").asText());
    }

    private void acceptConsent(String accessToken) throws Exception {
        var response = postJson("/api/v1/consent/accept", """
                {"consentVersion":"pipl-v1"}
                """, accessToken);
        assertThat(response.statusCode()).isEqualTo(200);
        assertThat(readJson(response.body()).get("consentStatus").asText()).isEqualTo("accepted");
    }

    private HttpResponse<String> postJson(String path, String body, String accessToken) throws Exception {
        var builder = HttpRequest.newBuilder(uri(path))
                .header("Content-Type", "application/json")
                .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                .POST(HttpRequest.BodyPublishers.ofString(body, StandardCharsets.UTF_8));
        if (accessToken != null) {
            builder.header("Authorization", "Bearer " + accessToken);
        }
        return httpClient.send(builder.build(), HttpResponse.BodyHandlers.ofString());
    }

    private HttpResponse<byte[]> getAudio(String accessToken, String contentId, String utteranceId) throws Exception {
        var request = HttpRequest.newBuilder(uri(
                        "/api/v1/practice/generated-content/%s/utterances/%s/audio".formatted(contentId, utteranceId)))
                .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                .header("Accept", "audio/mpeg, application/json")
                .header("Authorization", "Bearer " + accessToken)
                .GET()
                .build();
        return httpClient.send(request, HttpResponse.BodyHandlers.ofByteArray());
    }

    private URI uri(String path) {
        return URI.create("http://127.0.0.1:" + port + path);
    }

    private JsonNode readJson(byte[] body) throws Exception {
        return objectMapper.readTree(new String(body, StandardCharsets.UTF_8));
    }

    private JsonNode readJson(String body) throws Exception {
        return objectMapper.readTree(body);
    }

    private void seedActiveCarePathContent(String accountId) {
        new TransactionTemplate(transactionManager).executeWithoutResult(status -> {
            jdbcTemplate.update("""
                    insert into practice_generated_content (
                        generated_content_id, owner_scope, owner_key, owner_key_version,
                        account_id, installation_ref_hash, profile_id, surface, mode,
                        request_fingerprint, client_request_id, client_request_fingerprint,
                        normalized_scene_text, age_range, parent_goal, locale,
                        space_slug, activity_slug, phrase_slug, space_title_zh, activity_title_zh,
                        scene_tag_en, tpr_action_zh, delivery_guidance_zh, english_text, chinese_text,
                        pronunciation_hint, difficulty, generation_source, status,
                        generation_profile_version, generation_profile_hash, rubric_version,
                        rubric_content_hash, evidence_policy_version, evidence_policy_content_hash,
                        provider_routing_policy_version, provider_routing_policy_hash,
                        generation_attempt_limit, content_refresh_epoch, content_version,
                        generation_error_code, generation_error_retryable, generation_started_at,
                        generation_expires_at, retention_expires_at, created_at, updated_at
                    ) values (
                        ?, 'account', 'test_hmac_owner_key', 'v1', ?, null, null, 'care_path', 'custom_scene',
                        'test_audio_fingerprint', null, null, '洗澡前宝宝有点紧张', 'm7_11', 'calmer_care', 'zh-CN',
                        'gen_audio_space', 'gen_audio_activity', 'gen_audio_phrase', '日常照护', '洗澡', 'bath time',
                        '指向水。', '慢一点说。', 'Warm water.', '水暖暖的。', 'warm water', 'starter', 'fake', 'generating',
                        'generation-profile-v1', repeat('a', 64), 'rubric-v1', repeat('b', 64),
                        'evidence-policy-v1', repeat('c', 64), 'routing-policy-v1', repeat('d', 64),
                        3, 1, 1, null, null, now(), now() + interval '5 minutes', null, now(), now()
                    )
                    """, CONTENT_ID, accountId);
            insertUtterance(STARTER_UTTERANCE_ID, "starter", null, 1);
            insertUtterance("utt_audio_cooperating_1", "reaction_support", "cooperating", 2);
            insertUtterance("utt_audio_hesitant_1", "reaction_support", "hesitant", 3);
            insertUtterance("utt_audio_resisting_1", "reaction_support", "resisting", 4);
            insertUtterance("utt_audio_no_response_1", "reaction_support", "no_response", 5);
            insertUtterance("utt_audio_other_1", "reaction_support", "other", 6);
            jdbcTemplate.update("""
                    update practice_generated_content
                    set status = 'active', normalized_scene_text = null,
                        generation_started_at = null, generation_expires_at = null, updated_at = now()
                    where generated_content_id = ?
                    """, CONTENT_ID);
        });
    }

    private void insertUtterance(String utteranceId, String role, String reactionType, int displayOrder) {
        jdbcTemplate.update("""
                insert into practice_generated_content_utterances (
                    utterance_id, generated_content_id, role, reaction_type, english_text, chinese_text,
                    pronunciation_hint, tpr_action_zh, delivery_guidance_zh, difficulty, display_order,
                    approval_status, approved_content_version, bundle_schema_version, provider_origin,
                    provider_name, provider_model_name, provider_attempt_number, created_at
                ) values (?, ?, ?, ?, 'Warm water.', '水暖暖的。', 'warm water', '指向水。', '慢一点说。',
                          'starter', ?, 'approved', 1, 'custom-scene-generated-output-v1',
                          'provider_generated', 'test-provider', 'test-model', 1, ?)
                """, utteranceId, CONTENT_ID, role, reactionType, displayOrder, Timestamp.from(Instant.now()));
    }

    private record TokenView(String accountId, String accessToken) {
    }
}
