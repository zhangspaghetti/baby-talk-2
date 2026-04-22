package com.zhangspaghetti.babytalk.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.config.ApiVersionInterceptor;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import org.springframework.boot.test.context.SpringBootTest;
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
        jdbcTemplate.execute("delete from account_sessions");
        jdbcTemplate.execute("delete from accounts");
    }

    @Test
    void happyPathSupportsAcceptIdempotentIngestAndBootstrapRestore() throws Exception {
        var challengeId = createChallenge("13800138000");
        var session = verifyChallenge(challengeId, "install-alpha");

        mockMvc.perform(post("/api/v1/consent/accept")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header("X-Session-Id", session.sessionId())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"consentVersion":"pipl-v1"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.applied").value(true))
                .andExpect(jsonPath("$.consentStatus").value("accepted"));

        mockMvc.perform(post("/api/v1/sync/events")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header("X-Session-Id", session.sessionId())
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
                                      "reactionType":"calm",
                                      "clientTimestamp":"2026-04-09T02:00:00Z"
                                    },
                                    {
                                      "eventKey":"install-alpha:evt_2",
                                      "localEventId":"evt_2",
                                      "installationId":"install-alpha",
                                      "spaceId":"daily_care",
                                      "activityId":"bath_time",
                                      "phraseId":"bath_time_splash_splash",
                                      "reactionType":"engaged",
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
                        .header("X-Session-Id", session.sessionId())
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
                                      "reactionType":"calm",
                                      "clientTimestamp":"2026-04-09T02:00:00Z"
                                    },
                                    {
                                      "eventKey":"install-alpha:evt_2",
                                      "localEventId":"evt_2",
                                      "installationId":"install-alpha",
                                      "spaceId":"daily_care",
                                      "activityId":"bath_time",
                                      "phraseId":"bath_time_splash_splash",
                                      "reactionType":"engaged",
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
                        .header("X-Session-Id", session.sessionId())
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

        var session = verifyChallenge(challengeId, "install-alpha");
        mockMvc.perform(post("/api/v1/sync/events")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header("X-Session-Id", session.sessionId())
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
        acceptConsent(session.sessionId());

        mockMvc.perform(post("/api/v1/consent/revoke")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header("X-Session-Id", session.sessionId())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"reason":"user_requested"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.result").value("applied"))
                .andExpect(jsonPath("$.consentStatus").value("revoked"));

        var reloginChallengeId = createChallenge("13800138000");
        var reloginSession = verifyChallenge(reloginChallengeId, "install-alpha");
        acceptConsent(reloginSession.sessionId());

        mockMvc.perform(delete("/api/v1/account")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header("X-Session-Id", reloginSession.sessionId())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"reason":"forget_me"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.result").value("applied"));

        mockMvc.perform(delete("/api/v1/account")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header("X-Session-Id", reloginSession.sessionId())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"reason":"forget_me_again"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.result").value("duplicate"));

        mockMvc.perform(get("/api/v1/bootstrap")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header("X-Session-Id", reloginSession.sessionId())
                        .param("installationId", "install-alpha"))
                .andExpect(status().isGone())
                .andExpect(jsonPath("$.code").value("account_deleted"));

        var auditRows = jdbcTemplate.queryForList(
                "select action, result from consent_audit_logs order by audit_id asc"
        );
        assertThat(auditRows)
                .extracting(row -> row.get("action") + ":" + row.get("result"))
                .containsExactly(
                        "accept:applied",
                        "revoke:applied",
                        "accept:applied",
                        "delete:applied",
                        "delete:duplicate"
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

    private SessionView verifyChallenge(String challengeId, String installationId) throws Exception {
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
        return new SessionView(json.get("accountId").asText(), json.get("sessionId").asText());
    }

    private void acceptConsent(String sessionId) throws Exception {
        mockMvc.perform(post("/api/v1/consent/accept")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header("X-Session-Id", sessionId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"consentVersion":"pipl-v1"}
                                """))
                .andExpect(status().isOk());
    }

    private JsonNode readJson(String rawJson) throws Exception {
        return objectMapper.readTree(rawJson);
    }

    private record SessionView(String accountId, String sessionId) {
    }
}
