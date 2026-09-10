package com.zhangspaghetti.babytalk.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.config.ApiVersionInterceptor;
import com.zhangspaghetti.babytalk.security.JwtTokenService;
import com.zhangspaghetti.babytalk.service.AuthConsentSyncService;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
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
        "app.sms.dev-code=246810",
        "app.auth.issuer=babytalk-app-test",
        "app.auth.jwt-secret=0123456789abcdef0123456789abcdef",
        "app.auth.sensitive-data-pepper=test-auth-sensitive-data-pepper-0123456789abcdef",
        "app.auth.access-token-ttl=PT15M",
        "app.auth.refresh-token-ttl=P7D"
})
@AutoConfigureMockMvc
class JwtTokenLifecycleWebTest extends AbstractIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private JwtTokenService jwtTokenService;

    @Autowired
    private AuthConsentSyncService authConsentSyncService;

    @BeforeEach
    void resetTables() {
        resetDatabase(jdbcTemplate);
    }

    @Test
    void verifyRefreshRotateAndLogoutRevokeOldBearerImmediately() throws Exception {
        var verified = verifyChallenge(createChallenge("13800138000"), "install-alpha");
        acceptConsent(verified.accessToken());
        assertThat(activeRefreshCount(verified.sessionId())).isEqualTo(1);
        assertThat(refreshStatus(verified.refreshToken())).isEqualTo("active");

        var refreshed = refresh(verified.refreshToken());
        assertThat(activeRefreshCount(verified.sessionId())).isEqualTo(1);
        assertThat(refreshed.accountId()).isEqualTo(verified.accountId());
        assertThat(refreshed.sessionId()).isEqualTo(verified.sessionId());
        assertThat(refreshStatus(verified.refreshToken())).isEqualTo("rotated");
        assertThat(refreshStatus(refreshed.refreshToken())).isEqualTo("active");
        assertThat(validateAccessToken(verified.accessToken())).isEqualTo(AuthConsentSyncService.AccessValidationResult.ROTATED);
        assertThat(validateAccessToken(refreshed.accessToken())).isEqualTo(AuthConsentSyncService.AccessValidationResult.ACTIVE);

        mockMvc.perform(post("/api/v1/sync/events")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(verified.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "installationId":"install-alpha",
                                  "events":[
                                    {
                                      "eventKey":"install-alpha:evt_rotated",
                                      "localEventId":"evt_rotated",
                                      "installationId":"install-alpha",
                                      "spaceId":"daily_care",
                                      "activityId":"bath_time",
                                      "phraseId":"bath_time_warm_water",
                                      "reactionType":"cooperating",
                                      "clientTimestamp":"2026-04-09T02:00:00Z"
                                    }
                                  ]
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("access_token_rotated"))
                .andExpect(jsonPath("$.details.reason").value("rotated"));

        acceptConsent(refreshed.accessToken());

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"%s"}
                                """.formatted(verified.refreshToken())))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("refresh_token_rotated"));

        mockMvc.perform(post("/api/v1/auth/logout")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"%s"}
                                """.formatted(refreshed.refreshToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.loggedOut").value(true));

        assertThat(refreshStatus(refreshed.refreshToken())).isEqualTo("revoked");
        assertThat(validateAccessToken(refreshed.accessToken())).isEqualTo(AuthConsentSyncService.AccessValidationResult.REVOKED);

        mockMvc.perform(get("/api/v1/bootstrap")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .header(HttpHeaders.AUTHORIZATION, bearer(refreshed.accessToken()))
                        .param("installationId", "install-alpha"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("access_token_revoked"))
                .andExpect(jsonPath("$.details.reason").value("revoked"));

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"%s"}
                                """.formatted(refreshed.refreshToken())))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("refresh_token_revoked"));
    }

    @Test
    void malformedUnknownAndExpiredRefreshTokensFailClosed() throws Exception {
        var verified = verifyChallenge(createChallenge("13800138001"), "install-beta");

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"%s"}
                                """.formatted(verified.accessToken())))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("invalid_refresh_token"))
                .andExpect(jsonPath("$.details.reason").value("wrong_type"));

        var orphanRefreshToken = jwtTokenService.issueConsumerRefreshToken(
                "babytalk-app-test",
                "acct_orphan",
                "sess_orphan",
                "crt_orphan",
                Duration.ofDays(7)
        );
        mockMvc.perform(post("/api/v1/auth/refresh")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"%s"}
                                """.formatted(orphanRefreshToken.tokenValue())))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("invalid_refresh_token"))
                .andExpect(jsonPath("$.details.reason").value("not_found"));

        jdbcTemplate.update(
                "update account_refresh_tokens set expires_at = ?, updated_at = ? where refresh_token_id = ?",
                Timestamp.from(Instant.now().minusSeconds(60)),
                Timestamp.from(Instant.now()),
                refreshTokenId(verified.refreshToken())
        );

        mockMvc.perform(post("/api/v1/auth/refresh")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"%s"}
                                """.formatted(verified.refreshToken())))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("refresh_token_expired"));

        assertThat(refreshStatus(verified.refreshToken())).isEqualTo("expired");
        assertThat(validateAccessToken(verified.accessToken())).isEqualTo(AuthConsentSyncService.AccessValidationResult.EXPIRED);
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
        return readTokenView(result.getResponse().getContentAsString());
    }

    private TokenView refresh(String refreshToken) throws Exception {
        var result = mockMvc.perform(post("/api/v1/auth/refresh")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"%s"}
                                """.formatted(refreshToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.tokenType").value("Bearer"))
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty())
                .andReturn();
        return readTokenView(result.getResponse().getContentAsString());
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

    private TokenView readTokenView(String rawJson) throws Exception {
        JsonNode json = objectMapper.readTree(rawJson);
        return new TokenView(
                json.get("accountId").asText(),
                json.get("sessionId").asText(),
                json.get("accessToken").asText(),
                json.get("refreshToken").asText(),
                json.get("tokenType").asText()
        );
    }

    private JsonNode readJson(String rawJson) throws Exception {
        return objectMapper.readTree(rawJson);
    }

    private AuthConsentSyncService.AccessValidationResult validateAccessToken(String accessToken) {
        var decoded = jwtTokenService.decode(accessToken);
        return authConsentSyncService.validateAccessToken(
                decoded.subject(),
                decoded.sessionId(),
                decoded.refreshTokenId()
        );
    }

    private String refreshStatus(String refreshToken) {
        return jdbcTemplate.queryForObject(
                "select status from account_refresh_tokens where refresh_token_id = ?",
                String.class,
                refreshTokenId(refreshToken)
        );
    }

    private int activeRefreshCount(String sessionId) {
        Integer count = jdbcTemplate.queryForObject(
                "select count(*) from account_refresh_tokens where session_id = ? and status = 'active'",
                Integer.class,
                sessionId
        );
        return count == null ? 0 : count;
    }

    private String refreshTokenId(String refreshToken) {
        return jwtTokenService.decode(refreshToken).tokenId();
    }

    private String bearer(String accessToken) {
        return "Bearer " + accessToken;
    }

    private record TokenView(
            String accountId,
            String sessionId,
            String accessToken,
            String refreshToken,
            String tokenType
    ) {
    }
}
