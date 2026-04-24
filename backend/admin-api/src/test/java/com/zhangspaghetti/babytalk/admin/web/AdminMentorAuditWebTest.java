package com.zhangspaghetti.babytalk.admin.web;

import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.admin.auth.AdminAuthService;
import com.zhangspaghetti.babytalk.admin.rbac.AdminPermissionCatalog;
import java.sql.Timestamp;
import java.time.Instant;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

@SpringBootTest(properties = {
        "spring.flyway.enabled=true",
        "spring.flyway.locations=classpath:db/migration",
        "app.admin.auth.issuer=babytalk-admin-test",
        "app.admin.auth.jwt-secret=0123456789abcdef0123456789abcdef",
        "app.admin.auth.access-token-ttl=PT15M",
        "app.admin.auth.refresh-token-ttl=P7D",
        "app.admin.auth.bootstrap.enabled=true",
        "app.admin.auth.bootstrap.username=super_admin",
        "app.admin.auth.bootstrap.password=SuperAdmin123!",
        "app.admin.auth.bootstrap.display-name=Super Admin",
        "app.embedding.mode=dev-hash",
        "app.admin.mentor-audit.default-limit=50",
        "app.admin.mentor-audit.max-limit=100",
        "app.admin.mentor-audit.rate-limit-max-requests=2",
        "app.admin.mentor-audit.rate-limit-window=PT10M"
})
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AdminMentorAuditWebTest {

    @SuppressWarnings("resource")
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>(
            DockerImageName.parse("pgvector/pgvector:pg16")
                    .asCompatibleSubstituteFor("postgres"))
            .withDatabaseName("babytalk_admin_mentor_audit_test")
            .withUsername("babytalk")
            .withPassword("babytalk");

    static {
        if (System.getenv("DOCKER_API_VERSION") == null
                && System.getProperty("api.version") == null) {
            System.setProperty("api.version", "1.44");
        }
        POSTGRES.start();
    }

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
    }

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private AdminAuthService adminAuthService;

    @BeforeEach
    void resetTables() {
        jdbcTemplate.execute(
                "TRUNCATE TABLE mentor_turns, mentor_audit_logs, admin_refresh_tokens, admin_principal_roles, admin_role_permissions, admin_roles, admin_principals, account_sessions, accounts RESTART IDENTITY CASCADE"
        );
        adminAuthService.seedBootstrapPrincipalIfMissing();
    }

    @Test
    void flaggedQueueSupportsInstallationAndFlagFilters() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        var now = Instant.now();
        seedBlockedIncident("corr_blocked", "install-alpha", now.minusSeconds(180));
        seedRateLimitedIncident("corr_rate_limited", "install-alpha", now.minusSeconds(120));
        seedTimeoutIncident("corr_timeout", "install-beta", now.minusSeconds(60));
        seedSuccessfulIncident("corr_success", "install-gamma", now.minusSeconds(30));

        mockMvc.perform(get("/api/admin/mentor/audits")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(3)))
                .andExpect(jsonPath("$[0].correlationId").value("corr_timeout"))
                .andExpect(jsonPath("$[0].flagCode").value("provider_timeout"))
                .andExpect(jsonPath("$[*].correlationId", not(hasItem("corr_success"))));

        mockMvc.perform(get("/api/admin/mentor/audits")
                        .param("installationId", "install-alpha")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(2)))
                .andExpect(jsonPath("$[*].correlationId", hasItem("corr_blocked")))
                .andExpect(jsonPath("$[*].correlationId", hasItem("corr_rate_limited")));

        mockMvc.perform(get("/api/admin/mentor/audits")
                        .param("flag", "rate_limited")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(1)))
                .andExpect(jsonPath("$[0].correlationId").value("corr_rate_limited"))
                .andExpect(jsonPath("$[0].failureCode").value("mentor_rate_limited"))
                .andExpect(jsonPath("$[0].historicalRateLimited").value(true));
    }

    @Test
    void detailReturnsIncidentEvidenceForBlockedFallback() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        var now = Instant.now();
        seedBlockedIncident("corr_blocked", "install-alpha", now.minusSeconds(90));

        mockMvc.perform(get("/api/admin/mentor/audits/{correlationId}", "corr_blocked")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.scope").value("incident_evidence"))
                .andExpect(jsonPath("$.flagCode").value("blocked_fallback"))
                .andExpect(jsonPath("$.latestPhase").value("blocked_fallback"))
                .andExpect(jsonPath("$.deliveryState").value("delivered"))
                .andExpect(jsonPath("$.requestEvidence.summary").value("surface=home;mode=single_turn;prompt.len=9;preview=我想体罚他，怎么办？"))
                .andExpect(jsonPath("$.deliveredResponse.phase").value("blocked_fallback"))
                .andExpect(jsonPath("$.deliveredResponse.responseText").value("I'm here with you. 先把自己和宝宝放到安全位置，再只说一句短句。"))
                .andExpect(jsonPath("$.timeline", hasSize(2)))
                .andExpect(jsonPath("$.timeline[1].eventType").value("blocked_fallback"))
                .andExpect(jsonPath("$.liveRateLimit.currentCount").value(1))
                .andExpect(jsonPath("$.liveRateLimit.remaining").value(1))
                .andExpect(jsonPath("$.liveRateLimit.limited").value(false));
    }

    @Test
    void detailReturnsMissingTurnAndLiveRateLimitForRateLimitedIncident() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        var now = Instant.now();
        seedBlockedIncident("corr_blocked", "install-alpha", now.minusSeconds(120));
        seedRateLimitedIncident("corr_rate_limited", "install-alpha", now.minusSeconds(60));

        mockMvc.perform(get("/api/admin/mentor/audits/{correlationId}", "corr_rate_limited")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.scope").value("incident_evidence"))
                .andExpect(jsonPath("$.flagCode").value("rate_limited"))
                .andExpect(jsonPath("$.historicalRateLimited").value(true))
                .andExpect(jsonPath("$.deliveryState").value("missing_turn"))
                .andExpect(jsonPath("$.deliveredResponse").isEmpty())
                .andExpect(jsonPath("$.timeline", hasSize(2)))
                .andExpect(jsonPath("$.timeline[1].failureCode").value("mentor_rate_limited"))
                .andExpect(jsonPath("$.liveRateLimit.currentCount").value(2))
                .andExpect(jsonPath("$.liveRateLimit.limit").value(2))
                .andExpect(jsonPath("$.liveRateLimit.remaining").value(0))
                .andExpect(jsonPath("$.liveRateLimit.limited").value(true));
    }

    @Test
    void emptyQueueReturnsStable200() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");

        mockMvc.perform(get("/api/admin/mentor/audits")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(0)));
    }

    @Test
    void nonAuditorGets403() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        createRole(superAdmin.accessToken(), "users_reader", AdminPermissionCatalog.USERS_READ);
        createAdmin(superAdmin.accessToken(), "users_reader_one", "Users Reader", "Reader123!", "users_reader");
        var limitedAdmin = login("users_reader_one", "Reader123!");

        mockMvc.perform(get("/api/admin/mentor/audits")
                        .header(HttpHeaders.AUTHORIZATION, bearer(limitedAdmin.accessToken())))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("forbidden"));
    }

    @Test
    void disabledAuditorGets401() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        createRole(superAdmin.accessToken(), "mentor_auditor", AdminPermissionCatalog.MENTOR_AUDIT);
        var createdAdmin = createAdmin(superAdmin.accessToken(), "mentor_auditor_one", "Mentor Auditor", "Reader123!", "mentor_auditor");
        var auditor = login("mentor_auditor_one", "Reader123!");

        mockMvc.perform(patch("/api/admin/admins/{principalId}/disable", createdAdmin.principalId())
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("disabled"));

        mockMvc.perform(get("/api/admin/mentor/audits")
                        .header(HttpHeaders.AUTHORIZATION, bearer(auditor.accessToken())))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("admin_account_disabled"));
    }

    @Test
    void unknownCorrelationAndMalformedFiltersStayStable() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");

        mockMvc.perform(get("/api/admin/mentor/audits/{correlationId}", "corr_missing")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("mentor_audit_not_found"));

        mockMvc.perform(get("/api/admin/mentor/audits")
                        .param("flag", "nope")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("unknown_mentor_audit_flag"));

        mockMvc.perform(get("/api/admin/mentor/audits")
                        .param("installationId", "x".repeat(129))
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("validation_failed"));

        mockMvc.perform(get("/api/admin/mentor/audits/{correlationId}", "c".repeat(97))
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("validation_failed"));
    }

    private void createRole(String superAdminAccessToken, String roleCode, String permissionCode) throws Exception {
        mockMvc.perform(post("/api/admin/roles")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdminAccessToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "roleCode": "%s",
                                  "description": "Role %s",
                                  "permissionCodes": ["%s"]
                                }
                                """.formatted(roleCode, roleCode, permissionCode)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.roleCode").value(roleCode));
    }

    private CreatedAdmin createAdmin(
            String superAdminAccessToken,
            String username,
            String displayName,
            String password,
            String roleCode
    ) throws Exception {
        var response = mockMvc.perform(post("/api/admin/admins")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdminAccessToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "username": "%s",
                                  "displayName": "%s",
                                  "password": "%s",
                                  "roleCodes": ["%s"]
                                }
                                """.formatted(username, displayName, password, roleCode)))
                .andExpect(status().isCreated())
                .andReturn();
        var json = objectMapper.readTree(response.getResponse().getContentAsString());
        return new CreatedAdmin(json.get("principalId").asText(), json.get("username").asText());
    }

    private TokenView login(String username, String password) throws Exception {
        var response = mockMvc.perform(post("/api/admin/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"%s","password":"%s"}
                                """.formatted(username, password)))
                .andExpect(status().isOk())
                .andReturn();
        return readTokens(response);
    }

    private TokenView readTokens(MvcResult response) throws Exception {
        JsonNode json = objectMapper.readTree(response.getResponse().getContentAsString());
        return new TokenView(
                json.get("accessToken").asText(),
                json.get("refreshToken").asText(),
                json.get("admin").get("principalId").asText(),
                json.get("admin").get("username").asText());
    }

    private void seedSuccessfulIncident(String correlationId, String installationId, Instant requestedAt) {
        var requestSummary = "surface=home;mode=single_turn;prompt.len=8;preview=宝宝哭了怎么办？";
        var responseSummary = "response.len=16;preview=先抱近一点，再慢慢说。";
        seedAudit(
                correlationId,
                installationId,
                "chat_requested",
                "request_received",
                "accepted",
                requestSummary,
                null,
                "anonymous_installation",
                null,
                false,
                false,
                requestedAt
        );
        seedTurn(
                "turn_" + correlationId,
                correlationId,
                installationId,
                "success",
                "response_delivered",
                requestSummary,
                responseSummary,
                "先抱近一点，再慢慢说。",
                "dev",
                false,
                false,
                requestedAt.plusSeconds(1)
        );
        seedAudit(
                correlationId,
                installationId,
                "chat_response_delivered",
                "response_delivered",
                "success",
                requestSummary,
                responseSummary,
                "provider_response_delivered",
                null,
                false,
                false,
                requestedAt.plusSeconds(1)
        );
    }

    private void seedBlockedIncident(String correlationId, String installationId, Instant requestedAt) {
        var requestSummary = "surface=home;mode=single_turn;prompt.len=9;preview=我想体罚他，怎么办？";
        var responseSummary = "response.len=39;preview=I'm here with you. 先把自己和宝宝放到安全位置...";
        seedAudit(
                correlationId,
                installationId,
                "chat_requested",
                "request_received",
                "accepted",
                requestSummary,
                null,
                "anonymous_installation",
                null,
                false,
                false,
                requestedAt
        );
        seedTurn(
                "turn_" + correlationId,
                correlationId,
                installationId,
                "fallback",
                "blocked_fallback",
                requestSummary,
                responseSummary,
                "I'm here with you. 先把自己和宝宝放到安全位置，再只说一句短句。",
                "dev",
                true,
                false,
                requestedAt.plusSeconds(1)
        );
        seedAudit(
                correlationId,
                installationId,
                "blocked_fallback",
                "blocked_fallback",
                "fallback",
                requestSummary,
                responseSummary,
                "policy_boundary_triggered",
                "blocked_fallback",
                false,
                false,
                requestedAt.plusSeconds(1)
        );
    }

    private void seedRateLimitedIncident(String correlationId, String installationId, Instant requestedAt) {
        var requestSummary = "surface=home;mode=single_turn;prompt.len=6;preview=再给我一句建议";
        seedAudit(
                correlationId,
                installationId,
                "chat_requested",
                "request_received",
                "accepted",
                requestSummary,
                null,
                "anonymous_installation",
                null,
                false,
                false,
                requestedAt
        );
        seedAudit(
                correlationId,
                installationId,
                "rate_limited",
                "rate_limited",
                "rejected",
                requestSummary,
                null,
                "installation_window_limit_exceeded",
                "mentor_rate_limited",
                true,
                true,
                requestedAt.plusSeconds(1)
        );
    }

    private void seedTimeoutIncident(String correlationId, String installationId, Instant requestedAt) {
        var requestSummary = "surface=discover;mode=single_turn;prompt.len=11;preview=请给我一个建议 [timeout]";
        seedAudit(
                correlationId,
                installationId,
                "chat_requested",
                "request_received",
                "accepted",
                requestSummary,
                null,
                "anonymous_installation",
                null,
                false,
                false,
                requestedAt
        );
        seedAudit(
                correlationId,
                installationId,
                "provider_timeout",
                "provider_timeout",
                "error",
                requestSummary,
                null,
                "provider_timeout",
                "provider_timeout",
                true,
                false,
                requestedAt.plusSeconds(1)
        );
    }

    private void seedTurn(
            String turnId,
            String correlationId,
            String installationId,
            String result,
            String phase,
            String requestSummary,
            String responseSummary,
            String responseText,
            String providerMode,
            boolean blockedFallback,
            boolean retryable,
            Instant createdAt
    ) {
        jdbcTemplate.update(
                """
                insert into mentor_turns (
                    turn_id,
                    correlation_id,
                    installation_id,
                    session_id_hint,
                    account_id_hint,
                    surface,
                    mode,
                    result,
                    phase,
                    request_summary,
                    response_summary,
                    response_text,
                    provider_mode,
                    blocked_fallback,
                    retryable,
                    created_at
                ) values (?, ?, ?, null, null, 'home', 'single_turn', ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                turnId,
                correlationId,
                installationId,
                result,
                phase,
                requestSummary,
                responseSummary,
                responseText,
                providerMode,
                blockedFallback,
                retryable,
                Timestamp.from(createdAt)
        );
    }

    private void seedAudit(
            String correlationId,
            String installationId,
            String eventType,
            String phase,
            String result,
            String requestSummary,
            String responseSummary,
            String reason,
            String failureCode,
            boolean retryable,
            boolean rateLimited,
            Instant createdAt
    ) {
        jdbcTemplate.update(
                """
                insert into mentor_audit_logs (
                    correlation_id,
                    installation_id,
                    session_id_hint,
                    account_id_hint,
                    event_type,
                    phase,
                    result,
                    request_summary,
                    response_summary,
                    reason,
                    failure_code,
                    retryable,
                    rate_limited,
                    created_at
                ) values (?, ?, null, null, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                correlationId,
                installationId,
                eventType,
                phase,
                result,
                requestSummary,
                responseSummary,
                reason,
                failureCode,
                retryable,
                rateLimited,
                Timestamp.from(createdAt)
        );
    }

    private String bearer(String accessToken) {
        return "Bearer " + accessToken;
    }

    private record TokenView(String accessToken, String refreshToken, String principalId, String username) {
    }

    private record CreatedAdmin(String principalId, String username) {
    }
}
