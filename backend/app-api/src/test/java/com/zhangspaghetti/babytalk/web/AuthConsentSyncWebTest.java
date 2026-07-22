package com.zhangspaghetti.babytalk.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.config.ApiVersionInterceptor;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties = {
        "app.contract.min-supported-version=1.2.0",
        "app.contract.upgrade-url=https://download.example.com/babytalk.apk",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810"
})
@AutoConfigureMockMvc
class AuthConsentSyncWebTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    void resetTables() {
        resetDatabase(jdbcTemplate);
        jdbcTemplate.execute("delete from interaction_events");
        jdbcTemplate.execute("delete from consent_audit_logs");
        jdbcTemplate.execute("delete from sms_challenges");
        jdbcTemplate.execute("delete from account_refresh_tokens");
        jdbcTemplate.execute("delete from account_sessions");
        jdbcTemplate.execute("delete from accounts");
    }

    @Test
    void happyPathSupportsAcceptIdempotentIngestAndBootstrapRestore() throws Exception {
        var challengeId = createChallenge("13800138000");
        var session = verifyChallenge(challengeId, "install-alpha");

        mockMvc.perform(post("/api/v1/consent/accept")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"consentVersion":"pipl-v1"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.applied").value(true))
                .andExpect(jsonPath("$.consentStatus").value("accepted"));

        mockMvc.perform(post("/api/v1/sync/events")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"install-alpha",
                                  "events":[
                                    {
                                      "eventKey":"install-alpha:evt_1",
                                      "localEventId":"evt_1",
                                      "installationId":"install-alpha",
                                      "spaceId":"daily_care",
                                      "activityId":"bath_time",
                                      "phraseId":"bath_time_warm_water",
                                      "reactionType":"cooperating",
                                      "clientTimestamp":"2026-04-09T02:00:00Z"
                                    },
                                    {
                                      "eventKey":"install-alpha:evt_2",
                                      "localEventId":"evt_2",
                                      "installationId":"install-alpha",
                                      "spaceId":"daily_care",
                                      "activityId":"bath_time",
                                      "phraseId":"bath_time_splash_splash",
                                      "reactionType":"cooperating",
                                      "clientTimestamp":"2026-04-09T02:01:00Z"
                                    }
                                  ]
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.acceptedCount").value(2))
                .andExpect(jsonPath("$.duplicateCount").value(0));

        mockMvc.perform(post("/api/v1/sync/events")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"install-alpha",
                                  "events":[
                                    {
                                      "eventKey":"install-alpha:evt_1",
                                      "localEventId":"evt_1",
                                      "installationId":"install-alpha",
                                      "spaceId":"daily_care",
                                      "activityId":"bath_time",
                                      "phraseId":"bath_time_warm_water",
                                      "reactionType":"cooperating",
                                      "clientTimestamp":"2026-04-09T02:00:00Z"
                                    },
                                    {
                                      "eventKey":"install-alpha:evt_2",
                                      "localEventId":"evt_2",
                                      "installationId":"install-alpha",
                                      "spaceId":"daily_care",
                                      "activityId":"bath_time",
                                      "phraseId":"bath_time_splash_splash",
                                      "reactionType":"cooperating",
                                      "clientTimestamp":"2026-04-09T02:01:00Z"
                                    }
                                  ]
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.acceptedCount").value(0))
                .andExpect(jsonPath("$.duplicateCount").value(2));

        mockMvc.perform(get("/api/v1/bootstrap")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken()))
                        .param("installationId", "install-alpha"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.eventCount").value(2))
                .andExpect(jsonPath("$.events[0].eventKey").value("install-alpha:evt_1"))
                .andExpect(jsonPath("$.events[1].phraseId").value("bath_time_splash_splash"));
    }

    @Test
    void malformedInputsReturn4xxWithoutPartialWrites() throws Exception {
        mockMvc.perform(post("/api/v1/auth/challenges")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"phoneNumber":"12345"}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_phone_number"));

        var challengeId = createChallenge("13800138000");
        mockMvc.perform(post("/api/v1/auth/verify")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "challengeId":"%s",
                                  "verificationCode":"",
                                  "installationId":"install-alpha"
                                }
                                """.formatted(challengeId)))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post("/api/v1/auth/verify")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "challengeId":"%s",
                                  "verificationCode":"246810",
                                  "installationId":""
                                }
                                """.formatted(challengeId)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("validation_failed"));

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("validation_failed"));

        var session = verifyChallenge(challengeId, "install-alpha");
        mockMvc.perform(post("/api/v1/consent/accept")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header("X-Session-Id", session.sessionId())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"consentVersion":"pipl-v1"}
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("consumer_authentication_required"))
                .andExpect(jsonPath("$.details.reason").value("missing"));

        mockMvc.perform(post("/api/v1/consent/accept")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.refreshToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"consentVersion":"pipl-v1"}
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("invalid_access_token"))
                .andExpect(jsonPath("$.details.reason").value("invalid"));

        mockMvc.perform(post("/api/v1/sync/events")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"installationId":"install-alpha","events":[]}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("validation_failed"));

        var count = jdbcTemplate.queryForObject("select count(*) from interaction_events", Integer.class);
        assertThat(count).isZero();
    }

    @Test
    void revokeAndDeleteLeaveAuditTrailAndDeleteIsIdempotent() throws Exception {
        var challengeId = createChallenge("13800138000");
        var session = verifyChallenge(challengeId, "install-alpha");
        acceptConsent(session.accessToken());

        mockMvc.perform(post("/api/v1/consent/revoke")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"reason":"user_requested"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.result").value("applied"))
                .andExpect(jsonPath("$.consentStatus").value("revoked"));

        var reloginChallengeId = createChallenge("13800138000");
        var reloginSession = verifyChallenge(reloginChallengeId, "install-alpha");
        acceptConsent(reloginSession.accessToken());

        mockMvc.perform(put("/api/v1/onboarding/profile")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(reloginSession.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "babyName":"删除前宝宝",
                                  "ageRange":"m7_11",
                                  "onboardingState":"draft"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.version").value(1));
        assertThat(babyProfileCount(reloginSession.accountId())).isEqualTo(1);
        var profileId = babyProfileId(reloginSession.accountId());
        insertGeneratedContent("gen_cleanup_account", "account", reloginSession.accountId(), null, "draft");
        insertGeneratedContent("gen_cleanup_profile", "profile", reloginSession.accountId(), profileId, "active");
        assertThat(generatedContentCount(reloginSession.accountId())).isEqualTo(2);

        mockMvc.perform(delete("/api/v1/account")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(reloginSession.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"reason":"forget_me"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.result").value("applied"));
        assertThat(babyProfileCount(reloginSession.accountId())).isZero();
        assertThat(generatedContentCount(reloginSession.accountId())).isZero();

        mockMvc.perform(delete("/api/v1/account")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(reloginSession.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"reason":"forget_me_again"}
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("account_deleted"))
                .andExpect(jsonPath("$.details.reason").value("account_deleted"));

        mockMvc.perform(get("/api/v1/bootstrap")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(reloginSession.accessToken()))
                        .param("installationId", "install-alpha"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("account_deleted"))
                .andExpect(jsonPath("$.details.reason").value("account_deleted"));

        var auditRows = jdbcTemplate.queryForList(
                "select action, result from consent_audit_logs order by audit_id asc"
        );
        assertThat(auditRows)
                .extracting(row -> row.get("action") + ":" + row.get("result"))
                .containsExactly(
                        "accept:applied",
                        "revoke:applied",
                        "accept:applied",
                        "delete:applied"
                );
    }

    private String createChallenge(String phoneNumber) throws Exception {
        var result = mockMvc.perform(post("/api/v1/auth/challenges")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"phoneNumber":"%s"}
                                """.formatted(phoneNumber)))
                .andExpect(status().isCreated())
                .andReturn();
        return readJson(result.getResponse().getContentAsString()).get("challengeId").asText();
    }

    private TokenView verifyChallenge(String challengeId, String installationId) throws Exception {
        var result = mockMvc.perform(post("/api/v1/auth/verify")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "challengeId":"%s",
                                  "verificationCode":"246810",
                                  "installationId":"%s"
                                }
                                """.formatted(challengeId, installationId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.tokenType").value("Bearer"))
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty())
                .andExpect(jsonPath("$.accessTokenExpiresAt").isNotEmpty())
                .andExpect(jsonPath("$.refreshTokenExpiresAt").isNotEmpty())
                .andReturn();
        var json = readJson(result.getResponse().getContentAsString());
        return new TokenView(
                json.get("accountId").asText(),
                json.get("sessionId").asText(),
                json.get("accessToken").asText(),
                json.get("refreshToken").asText()
        );
    }

    private void acceptConsent(String accessToken) throws Exception {
        mockMvc.perform(post("/api/v1/consent/accept")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(accessToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"consentVersion":"pipl-v1"}
                                """))
                .andExpect(status().isOk());
    }

    private JsonNode readJson(String rawJson) throws Exception {
        return objectMapper.readTree(rawJson);
    }

    private String bearer(String accessToken) {
        return "Bearer " + accessToken;
    }

    private int babyProfileCount(String accountId) {
        Integer count = jdbcTemplate.queryForObject(
                "select count(*) from baby_profiles where account_id = ?",
                Integer.class,
                accountId
        );
        return count == null ? 0 : count;
    }

    private String babyProfileId(String accountId) {
        return jdbcTemplate.queryForObject(
                "select profile_id from baby_profiles where account_id = ?",
                String.class,
                accountId
        );
    }

    private int generatedContentCount(String accountId) {
        Integer count = jdbcTemplate.queryForObject(
                "select count(*) from practice_generated_content where account_id = ?",
                Integer.class,
                accountId
        );
        return count == null ? 0 : count;
    }

    private void insertGeneratedContent(
            String generatedContentId,
            String ownerScope,
            String accountId,
            String profileId,
            String status
    ) {
        var suffix = generatedContentId.replace("_", "-");
        jdbcTemplate.update("""
                        insert into practice_generated_content (
                            generated_content_id,
                            owner_scope,
                            owner_key,
                            owner_key_version,
                            account_id,
                            installation_ref_hash,
                            profile_id,
                            surface,
                            mode,
                            request_fingerprint,
                            normalized_scene_text,
                            age_range,
                            parent_goal,
                            locale,
                            space_slug,
                            activity_slug,
                            phrase_slug,
                            space_title_zh,
                            activity_title_zh,
                            scene_tag_en,
                            tpr_action_zh,
                            delivery_guidance_zh,
                            english_text,
                            chinese_text,
                            pronunciation_hint,
                            difficulty,
                            generation_source,
                            status,
                            generation_profile_version,
                            generation_profile_hash,
                            rubric_version,
                            rubric_content_hash,
                            evidence_policy_version,
                            evidence_policy_content_hash,
                            provider_routing_policy_version,
                            provider_routing_policy_hash,
                            generation_attempt_limit,
                            content_refresh_epoch,
                            content_version,
                            generation_started_at,
                            generation_expires_at,
                            created_at,
                            updated_at
                        ) values (
                            ?, ?, ?, 'v1', ?, null, ?, 'onboarding', 'custom_scene', ?,
                            case when ? = 'draft' then '刷牙洗脸' else null end, 'm7_11',
                            'calmer_care', 'zh-CN', ?, ?, ?, '日常照护', '洗漱', 'wash up',
                            '轻轻擦宝宝的脸。', '慢一点说，配合动作。',
                            'Let us wash your face.', '我们来洗脸。', 'let-us-wash', 'easy', ?, ?,
                            'generation-profile-v1', repeat('a', 64), 'rubric-v1', repeat('b', 64),
                            'evidence-policy-v1', repeat('c', 64), 'routing-policy-v1', repeat('d', 64),
                            3, 1, 1, case when ? = 'active' then now() else null end,
                            case when ? = 'draft' then now() + interval '5 minutes' else null end, now(), now()
                        )
                        """,
                generatedContentId,
                ownerScope,
                "owner_" + suffix,
                accountId,
                profileId,
                "fp_" + suffix,
                status,
                "space_" + suffix,
                "activity_" + suffix,
                "phrase_" + suffix,
                "agentic_search",
                status,
                status,
                status
        );
    }

    private record TokenView(String accountId, String sessionId, String accessToken, String refreshToken) {
    }
}
