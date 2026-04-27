package com.zhangspaghetti.babytalk.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.config.ApiVersionInterceptor;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties = {
        "app.contract.min-supported-version=1.2.0",
        "app.contract.upgrade-url=https://download.example.com/babytalk.apk",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810",
        "app.mentor.provider-mode=dev",
        "app.mentor.rate-limit-max-requests=1"
})
@AutoConfigureMockMvc
class MentorWebTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    void resetTables() {
        resetDatabase(jdbcTemplate);
        jdbcTemplate.execute("delete from mentor_turns");
        jdbcTemplate.execute("delete from mentor_audit_logs");
        jdbcTemplate.execute("delete from interaction_events");
        jdbcTemplate.execute("delete from consent_audit_logs");
        jdbcTemplate.execute("delete from sms_challenges");
        jdbcTemplate.execute("delete from account_sessions");
        jdbcTemplate.execute("delete from accounts");
    }

    @Test
    void anonymousHappyPathReturnsControlledTextAndWritesTurn() throws Exception {
        mockMvc.perform(post("/api/v1/mentor/chat")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"install-alpha",
                                  "prompt":"宝宝哭了我现在该怎么说？",
                                  "surface":"home",
                                  "mode":"single_turn",
                                  "correlationId":"corr_web_success"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value("ok"))
                .andExpect(jsonPath("$.phase").value("response_delivered"))
                .andExpect(jsonPath("$.authenticated").value(false))
                .andExpect(jsonPath("$.fallbackUsed").value(false))
                .andExpect(jsonPath("$.responseText").isString())
                .andExpect(jsonPath("$.rateLimit.limit").value(1))
                .andExpect(jsonPath("$.rateLimit.remaining").value(0));

        var turnCount = jdbcTemplate.queryForObject("select count(*) from mentor_turns", Integer.class);
        assertThat(turnCount).isEqualTo(1);
    }

    @Test
    void chatAcceptsOptionalChildAgeMonthsWithoutBreakingExistingFlow() throws Exception {
        mockMvc.perform(post("/api/v1/mentor/chat")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"install-age-aware",
                                  "prompt":"宝宝6个月时我该怎么回应他的咿呀声？",
                                  "surface":"home",
                                  "mode":"single_turn",
                                  "correlationId":"corr_child_age_months",
                                  "childAgeMonths":6
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value("ok"))
                .andExpect(jsonPath("$.phase").value("response_delivered"))
                .andExpect(jsonPath("$.authenticated").value(false))
                .andExpect(jsonPath("$.fallbackUsed").value(false));

        var turnCount = jdbcTemplate.queryForObject("select count(*) from mentor_turns", Integer.class);
        assertThat(turnCount).isEqualTo(1);
    }

    @Test
    void authenticatedHappyPathUsesBearerAndPreservesAuthenticatedSignal() throws Exception {
        var session = createAcceptedSession("13800138000", "install-authenticated");

        mockMvc.perform(post("/api/v1/mentor/chat")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"install-authenticated",
                                  "prompt":"请给我一个适合洗澡时间的鼓励句。",
                                  "surface":"home",
                                  "mode":"single_turn",
                                  "correlationId":"corr_authenticated_success"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value("ok"))
                .andExpect(jsonPath("$.phase").value("response_delivered"))
                .andExpect(jsonPath("$.authenticated").value(true))
                .andExpect(jsonPath("$.fallbackUsed").value(false));
    }

    @Test
    void practiceGenerateRequiresAuthenticatedSession() throws Exception {
        mockMvc.perform(post("/api/v1/mentor/practice/generate")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"install-practice-auth",
                                  "surface":"practice",
                                  "babyAgeMonths":12,
                                  "sceneTag":"morning_routine"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("consumer_authentication_required"));
    }

    @Test
    void practiceGenerateRejectsInstallationMismatch() throws Exception {
        var session = createAcceptedSession("13800138000", "install-owner");

        mockMvc.perform(post("/api/v1/mentor/practice/generate")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"install-other",
                                  "surface":"practice",
                                  "babyAgeMonths":12,
                                  "sceneTag":"morning_routine"
                                }
                                """))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("session_installation_mismatch"));
    }

    @Test
    void practiceGenerateSharesRateLimitWindowWithChat() throws Exception {
        var session = createAcceptedSession("13800138000", "install-practice-rate");

        mockMvc.perform(post("/api/v1/mentor/chat")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"install-practice-rate",
                                  "prompt":"先给我一个开场白。",
                                  "surface":"home",
                                  "mode":"single_turn",
                                  "correlationId":"corr_practice_rl_chat"
                                }
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/v1/mentor/practice/generate")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"install-practice-rate",
                                  "surface":"practice",
                                  "babyAgeMonths":12,
                                  "sceneTag":"morning_routine"
                                }
                                """))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("mentor_rate_limited"))
                .andExpect(jsonPath("$.details.phase").value("rate_limited"))
                .andExpect(jsonPath("$.details.rateLimited").value(true));
    }

    @Test
    void blockedPromptReturnsFallbackAndRedactsStoredSummary() throws Exception {
        mockMvc.perform(post("/api/v1/mentor/chat")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"install-alpha",
                                  "prompt":"我想体罚他，手机号 13800138000，验证码 246810。",
                                  "surface":"garden",
                                  "mode":"single_turn",
                                  "correlationId":"corr_web_blocked"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value("blocked_fallback"))
                .andExpect(jsonPath("$.phase").value("blocked_fallback"))
                .andExpect(jsonPath("$.fallbackUsed").value(true))
                .andExpect(jsonPath("$.responseText").value(org.hamcrest.Matchers.containsString("I'm here with you.")));

        var requestSummary = jdbcTemplate.queryForObject(
                "select request_summary from mentor_turns where correlation_id = 'corr_web_blocked'",
                String.class
        );
        assertThat(requestSummary).doesNotContain("13800138000");
        assertThat(requestSummary).doesNotContain("246810");
    }

    @Test
    void wrongTokenTypeReturns401WithoutMentorWrites() throws Exception {
        var session = verifyChallenge(createChallenge("13800138000"), "install-alpha");

        mockMvc.perform(post("/api/v1/mentor/chat")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.refreshToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"install-alpha",
                                  "prompt":"请给我一个建议",
                                  "surface":"discover",
                                  "mode":"single_turn",
                                  "correlationId":"corr_invalid_token_type"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("invalid_access_token"))
                .andExpect(jsonPath("$.details.reason").value("invalid"));

        assertThat(jdbcTemplate.queryForObject("select count(*) from mentor_turns", Integer.class)).isZero();
        assertThat(jdbcTemplate.queryForObject("select count(*) from mentor_audit_logs", Integer.class)).isZero();
    }

    @Test
    void revokedSessionReturns401WhenGuardRejectsRevokedSession() throws Exception {
        var session = createAcceptedSession("13800138000", "install-alpha");
        revokeConsent(session.accessToken());

        mockMvc.perform(post("/api/v1/mentor/chat")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(session.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"install-alpha",
                                  "prompt":"请给我一个建议",
                                  "surface":"growth",
                                  "mode":"single_turn",
                                  "correlationId":"corr_revoked"
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("consumer_session_invalid"))
                .andExpect(jsonPath("$.details.reason").value("session_invalid"));
    }

    @Test
    void providerTimeoutAndMalformedStayStructured() throws Exception {
        mockMvc.perform(post("/api/v1/mentor/chat")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"install-timeout",
                                  "prompt":"请给我一个建议 [timeout]",
                                  "surface":"home",
                                  "mode":"single_turn",
                                  "correlationId":"corr_timeout"
                                }
                                """))
                .andExpect(status().isGatewayTimeout())
                .andExpect(jsonPath("$.code").value("provider_timeout"))
                .andExpect(jsonPath("$.details.phase").value("provider_timeout"))
                .andExpect(jsonPath("$.details.retryable").value(true));

        mockMvc.perform(post("/api/v1/mentor/chat")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"install-malformed",
                                  "prompt":"请给我一个建议 [malformed]",
                                  "surface":"home",
                                  "mode":"single_turn",
                                  "correlationId":"corr_malformed"
                                }
                                """))
                .andExpect(status().isBadGateway())
                .andExpect(jsonPath("$.code").value("provider_malformed_response"))
                .andExpect(jsonPath("$.details.phase").value("provider_malformed_response"));
    }

    @Test
    void rateLimitBlocksSecondRequest() throws Exception {
        mockMvc.perform(post("/api/v1/mentor/chat")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"install-alpha",
                                  "prompt":"第一条建议",
                                  "surface":"home",
                                  "mode":"single_turn",
                                  "correlationId":"corr_rl_first"
                                }
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/v1/mentor/chat")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"install-alpha",
                                  "prompt":"第二条建议",
                                  "surface":"home",
                                  "mode":"single_turn",
                                  "correlationId":"corr_rl_second"
                                }
                                """))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("mentor_rate_limited"))
                .andExpect(jsonPath("$.details.phase").value("rate_limited"))
                .andExpect(jsonPath("$.details.rateLimited").value(true));
    }

    @Test
    void malformedInputsReturn4xxWithoutWrites() throws Exception {
        mockMvc.perform(post("/api/v1/mentor/chat")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"install-alpha",
                                  "prompt":"",
                                  "surface":"invalid_surface",
                                  "mode":"stream"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("missing_prompt"));

        var turnCount = jdbcTemplate.queryForObject("select count(*) from mentor_turns", Integer.class);
        var auditCount = jdbcTemplate.queryForObject("select count(*) from mentor_audit_logs", Integer.class);
        assertThat(turnCount).isZero();
        assertThat(auditCount).isZero();
    }

    @Test
    void versionGateStillAppliesToMentorEndpoint() throws Exception {
        mockMvc.perform(post("/api/v1/mentor/chat")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.1.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"install-alpha",
                                  "prompt":"请给我一个建议",
                                  "surface":"home",
                                  "mode":"single_turn"
                                }
                                """))
                .andExpect(status().isUpgradeRequired())
                .andExpect(header().string(ApiVersionInterceptor.MIN_VERSION_HEADER, "1.2.0"))
                .andExpect(jsonPath("$.code").value("app_version_unsupported"));

        var auditCount = jdbcTemplate.queryForObject("select count(*) from mentor_audit_logs", Integer.class);
        assertThat(auditCount).isZero();
    }

    private TokenView createAcceptedSession(String phoneNumber, String installationId) throws Exception {
        var session = verifyChallenge(createChallenge(phoneNumber), installationId);
        acceptConsent(session.accessToken());
        return session;
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

    private void revokeConsent(String accessToken) throws Exception {
        mockMvc.perform(post("/api/v1/consent/revoke")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(accessToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"reason":"user_requested"}
                                """))
                .andExpect(status().isOk());
    }

    private JsonNode readJson(String rawJson) throws Exception {
        return objectMapper.readTree(rawJson);
    }

    private String bearer(String accessToken) {
        return "Bearer " + accessToken;
    }

    private record TokenView(String accountId, String sessionId, String accessToken, String refreshToken) {
    }
}
