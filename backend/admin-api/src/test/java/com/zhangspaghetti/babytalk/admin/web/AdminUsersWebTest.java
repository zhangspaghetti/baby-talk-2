package com.zhangspaghetti.babytalk.admin.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.nullValue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.admin.auth.AdminAuthService;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
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
        "app.admin.auth.bootstrap.display-name=Super Admin"
})
@AutoConfigureMockMvc
class AdminUsersWebTest {

    @SuppressWarnings("resource")
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>(
            DockerImageName.parse("pgvector/pgvector:pg16")
                    .asCompatibleSubstituteFor("postgres"))
            .withDatabaseName("babytalk_admin_users_test")
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
                "TRUNCATE TABLE admin_refresh_tokens, admin_principal_roles, admin_role_permissions, admin_roles, admin_principals, interaction_events, consent_audit_logs, account_refresh_tokens, account_sessions, accounts RESTART IDENTITY CASCADE"
        );
        adminAuthService.seedBootstrapPrincipalIfMissing();
    }

    @Test
    void listDetailAndDisableContractAlsoMutatesSharedTables() throws Exception {
        var accountCreatedAt = Instant.parse("2026-04-21T00:00:00Z");
        var liveSessionCreatedAt = Instant.parse("2026-04-22T00:00:00Z");
        var oldSessionCreatedAt = Instant.parse("2026-04-20T00:00:00Z");
        var oldSessionRevokedAt = Instant.parse("2026-04-20T12:00:00Z");
        var refreshIssuedAt = Instant.parse("2026-04-22T00:00:00Z");
        seedAccount("acct_001", "13900000001", "active", "accepted", accountCreatedAt, null);
        seedSession("sess_live", "acct_001", "install-alpha", "active", liveSessionCreatedAt, null);
        seedSession("sess_old", "acct_001", "install-beta", "revoked", oldSessionCreatedAt, oldSessionRevokedAt);
        seedRefreshToken(
                "crt_live",
                "acct_001",
                "sess_live",
                "active",
                refreshIssuedAt,
                refreshIssuedAt.plusSeconds(86400),
                refreshIssuedAt,
                null,
                null,
                null
        );
        seedInteractionEvent("install-alpha:event-1", "acct_001", "sess_live", "install-alpha", "event-1", Instant.parse("2026-04-22T00:01:00Z"));
        seedInteractionEvent("install-alpha:event-2", "acct_001", "sess_live", "install-alpha", "event-2", Instant.parse("2026-04-22T00:02:00Z"));
        seedConsentAudit("acct_001", "sess_old", "install-beta", "accept", "applied", "consent_v1", Instant.parse("2026-04-20T00:05:00Z"));
        seedConsentAudit("acct_001", "sess_live", "install-alpha", "revoke", "duplicate", "already_revoked", Instant.parse("2026-04-22T00:03:00Z"));

        var superAdmin = login("super_admin", "SuperAdmin123!");

        mockMvc.perform(get("/api/admin/users")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                        .param("page", "1")
                        .param("pageSize", "10")
                        .param("status", "active")
                        .param("query", "13900000001"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.page").value(1))
                .andExpect(jsonPath("$.pageSize").value(10))
                .andExpect(jsonPath("$.total").value(1))
                .andExpect(jsonPath("$.totalPages").value(1))
                .andExpect(jsonPath("$.filters.status").value("active"))
                .andExpect(jsonPath("$.filters.query").value("13900000001"))
                .andExpect(jsonPath("$.items", hasSize(1)))
                .andExpect(jsonPath("$.items[0].accountId").value("acct_001"))
                .andExpect(jsonPath("$.items[0].phoneNumber").value("13900000001"))
                .andExpect(jsonPath("$.items[0].status").value("active"))
                .andExpect(jsonPath("$.items[0].latestConsentStatus").value("accepted"))
                .andExpect(jsonPath("$.items[0].createdAt").value("2026-04-21T00:00:00Z"))
                .andExpect(jsonPath("$.items[0].deletedAt").value(nullValue()));

        mockMvc.perform(get("/api/admin/users/{accountId}", "acct_001")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.account.accountId").value("acct_001"))
                .andExpect(jsonPath("$.account.phoneNumber").value("13900000001"))
                .andExpect(jsonPath("$.account.status").value("active"))
                .andExpect(jsonPath("$.recentSessions", hasSize(2)))
                .andExpect(jsonPath("$.recentSessions[0].sessionId").value("sess_live"))
                .andExpect(jsonPath("$.recentSessions[0].installationId").value("install-alpha"))
                .andExpect(jsonPath("$.recentSessions[0].status").value("active"))
                .andExpect(jsonPath("$.recentSessions[0].revokedAt").value(nullValue()))
                .andExpect(jsonPath("$.recentSessions[1].sessionId").value("sess_old"))
                .andExpect(jsonPath("$.recentSessions[1].status").value("revoked"))
                .andExpect(jsonPath("$.recentConsentAudit", hasSize(2)))
                .andExpect(jsonPath("$.recentConsentAudit[0].action").value("revoke"))
                .andExpect(jsonPath("$.recentConsentAudit[0].result").value("duplicate"))
                .andExpect(jsonPath("$.recentConsentAudit[0].reason").value("already_revoked"))
                .andExpect(jsonPath("$.recentConsentAudit[1].action").value("accept"))
                .andExpect(jsonPath("$.recentConsentAudit[1].result").value("applied"));

        var disableResult = mockMvc.perform(patch("/api/admin/users/{accountId}/disable", "acct_001")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "reason": "admin_review"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accountId").value("acct_001"))
                .andExpect(jsonPath("$.status").value("deleted"))
                .andExpect(jsonPath("$.applied").value(true))
                .andExpect(jsonPath("$.result").value("applied"))
                .andExpect(jsonPath("$.updatedAt").isNotEmpty())
                .andExpect(jsonPath("$.revokedSessionCount").value(2))
                .andExpect(jsonPath("$.deletedEventCount").value(2))
                .andReturn();

        var disableJson = objectMapper.readTree(disableResult.getResponse().getContentAsString());
        assertThat(disableJson.get("updatedAt").asText()).isNotBlank();

        assertThat(jdbcTemplate.queryForObject(
                "select status from accounts where account_id = ?",
                String.class,
                "acct_001"
        )).isEqualTo("deleted");
        assertThat(jdbcTemplate.queryForObject(
                "select phone_number from accounts where account_id = ?",
                String.class,
                "acct_001"
        )).isEqualTo("deleted:acct_001");
        assertThat(jdbcTemplate.queryForObject(
                "select latest_consent_status from accounts where account_id = ?",
                String.class,
                "acct_001"
        )).isEqualTo("deleted");
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from account_sessions where account_id = ? and status = 'deleted'",
                Integer.class,
                "acct_001"
        )).isEqualTo(2);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from account_sessions where account_id = ? and revoked_at is not null",
                Integer.class,
                "acct_001"
        )).isEqualTo(2);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from interaction_events where account_id = ?",
                Integer.class,
                "acct_001"
        )).isEqualTo(0);
        assertThat(jdbcTemplate.queryForObject(
                "select status from account_refresh_tokens where refresh_token_id = ?",
                String.class,
                "crt_live"
        )).isEqualTo("active");

        var latestAudit = jdbcTemplate.queryForMap(
                "select action, result, reason, session_id, installation_id from consent_audit_logs where account_id = ? order by audit_id desc limit 1",
                "acct_001"
        );
        assertThat(latestAudit)
                .containsEntry("action", "delete")
                .containsEntry("result", "applied")
                .containsEntry("reason", "admin_review")
                .containsEntry("session_id", "sess_live")
                .containsEntry("installation_id", "install-alpha");

        mockMvc.perform(get("/api/admin/users/{accountId}", "acct_001")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.account.status").value("deleted"))
                .andExpect(jsonPath("$.account.latestConsentStatus").value("deleted"))
                .andExpect(jsonPath("$.recentSessions[0].status").value("deleted"))
                .andExpect(jsonPath("$.recentConsentAudit[0].action").value("delete"))
                .andExpect(jsonPath("$.recentConsentAudit[0].result").value("applied"))
                .andExpect(jsonPath("$.recentConsentAudit[0].reason").value("admin_review"));
    }

    @Test
    void disableRejectsMissingReasonAndReadOnlyAdminsCannotWrite() throws Exception {
        seedAccount("acct_101", "13900000101", "active", "accepted", Instant.parse("2026-04-10T00:00:00Z"), null);

        var superAdmin = login("super_admin", "SuperAdmin123!");
        createRole(superAdmin.accessToken(), "users_reader_only", "Users read only", List.of("users:read"));
        createAdmin(superAdmin.accessToken(), "users_reader_only_one", "Users Reader", "Reader123!", "users_reader_only");
        var limitedAdmin = login("users_reader_only_one", "Reader123!");

        mockMvc.perform(patch("/api/admin/users/{accountId}/disable", "acct_101")
                        .header(HttpHeaders.AUTHORIZATION, bearer(limitedAdmin.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "reason": "policy"
                                }
                                """))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("forbidden"));

        mockMvc.perform(patch("/api/admin/users/{accountId}/disable", "acct_101")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "reason": "   "
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("validation_failed"))
                .andExpect(jsonPath("$.details.fields.reason").value("reason 不能为空。"));

        mockMvc.perform(patch("/api/admin/users/{accountId}/disable", "acct_101")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "reason": "%s"
                                }
                                """.formatted("x".repeat(241))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("validation_failed"))
                .andExpect(jsonPath("$.details.fields.reason").value("reason 过长。"));
    }

    @Test
    void duplicateDisableEmptyHistoriesAndNegativeContractsStayStable() throws Exception {
        var deletedAt = Instant.parse("2026-04-12T00:00:00Z");
        seedAccount("acct_empty", "13900000999", "active", "signed_out", Instant.parse("2026-04-09T00:00:00Z"), null);
        seedAccount("acct_dup", "deleted:acct_dup", "deleted", "deleted", Instant.parse("2026-04-08T00:00:00Z"), deletedAt);
        seedSession("sess_dup", "acct_dup", "install-dup", "deleted", Instant.parse("2026-04-08T02:00:00Z"), deletedAt);
        seedConsentAudit("acct_dup", "sess_dup", "install-dup", "delete", "applied", "first_delete", deletedAt);

        var superAdmin = login("super_admin", "SuperAdmin123!");

        mockMvc.perform(get("/api/admin/users/{accountId}", "acct_empty")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.account.accountId").value("acct_empty"))
                .andExpect(jsonPath("$.recentSessions", hasSize(0)))
                .andExpect(jsonPath("$.recentConsentAudit", hasSize(0)));

        mockMvc.perform(get("/api/admin/users")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                        .param("page", "0"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("validation_failed"));

        mockMvc.perform(get("/api/admin/users")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                        .param("pageSize", "101"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("validation_failed"));

        mockMvc.perform(get("/api/admin/users")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                        .param("status", "weird"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_user_status"));

        mockMvc.perform(get("/api/admin/users/{accountId}", "acct_missing")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("user_account_not_found"));

        mockMvc.perform(patch("/api/admin/users/{accountId}/disable", "acct_dup")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "reason": "again"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accountId").value("acct_dup"))
                .andExpect(jsonPath("$.status").value("deleted"))
                .andExpect(jsonPath("$.applied").value(false))
                .andExpect(jsonPath("$.result").value("duplicate"))
                .andExpect(jsonPath("$.revokedSessionCount").value(0))
                .andExpect(jsonPath("$.deletedEventCount").value(0));

        var latestAudit = jdbcTemplate.queryForMap(
                "select action, result, reason from consent_audit_logs where account_id = ? order by audit_id desc limit 1",
                "acct_dup"
        );
        assertThat(latestAudit)
                .containsEntry("action", "delete")
                .containsEntry("result", "duplicate")
                .containsEntry("reason", "again");
    }

    private void createRole(String accessToken, String roleCode, String description, List<String> permissionCodes) throws Exception {
        var payload = objectMapper.writeValueAsString(new RolePayload(roleCode, description, permissionCodes));
        mockMvc.perform(post("/api/admin/roles")
                        .header(HttpHeaders.AUTHORIZATION, bearer(accessToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.roleCode").value(roleCode));
    }

    private CreatedAdmin createAdmin(
            String accessToken,
            String username,
            String displayName,
            String password,
            String roleCode
    ) throws Exception {
        var response = mockMvc.perform(post("/api/admin/admins")
                        .header(HttpHeaders.AUTHORIZATION, bearer(accessToken))
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
                .andExpect(jsonPath("$.username").value(username))
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
                .andExpect(jsonPath("$.tokenType").value("Bearer"))
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty())
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

    private void seedAccount(
            String accountId,
            String phoneNumber,
            String status,
            String consentStatus,
            Instant createdAt,
            Instant deletedAt
    ) {
        jdbcTemplate.update(
                """
                insert into accounts (account_id, phone_number, status, latest_consent_status, created_at, deleted_at)
                values (?, ?, ?, ?, ?, ?)
                """,
                accountId,
                phoneNumber,
                status,
                consentStatus,
                Timestamp.from(createdAt),
                deletedAt == null ? null : Timestamp.from(deletedAt)
        );
    }

    private void seedSession(
            String sessionId,
            String accountId,
            String installationId,
            String status,
            Instant createdAt,
            Instant revokedAt
    ) {
        jdbcTemplate.update(
                """
                insert into account_sessions (session_id, account_id, installation_id, status, created_at, revoked_at)
                values (?, ?, ?, ?, ?, ?)
                """,
                sessionId,
                accountId,
                installationId,
                status,
                Timestamp.from(createdAt),
                revokedAt == null ? null : Timestamp.from(revokedAt)
        );
    }

    private void seedRefreshToken(
            String refreshTokenId,
            String accountId,
            String sessionId,
            String status,
            Instant issuedAt,
            Instant expiresAt,
            Instant updatedAt,
            Instant rotatedAt,
            Instant revokedAt,
            String replacementTokenId
    ) {
        jdbcTemplate.update(
                """
                insert into account_refresh_tokens (
                    refresh_token_id,
                    account_id,
                    session_id,
                    status,
                    issued_at,
                    expires_at,
                    updated_at,
                    rotated_at,
                    revoked_at,
                    replacement_token_id
                ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                refreshTokenId,
                accountId,
                sessionId,
                status,
                Timestamp.from(issuedAt),
                Timestamp.from(expiresAt),
                Timestamp.from(updatedAt),
                rotatedAt == null ? null : Timestamp.from(rotatedAt),
                revokedAt == null ? null : Timestamp.from(revokedAt),
                replacementTokenId
        );
    }

    private void seedInteractionEvent(
            String eventKey,
            String accountId,
            String sessionId,
            String installationId,
            String localEventId,
            Instant clientTimestamp
    ) {
        jdbcTemplate.update(
                """
                insert into interaction_events (
                    event_key,
                    account_id,
                    session_id,
                    installation_id,
                    local_event_id,
                    space_id,
                    activity_id,
                    phrase_id,
                    reaction_type,
                    client_timestamp,
                    received_at
                ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                eventKey,
                accountId,
                sessionId,
                installationId,
                localEventId,
                "space-1",
                "activity-1",
                "phrase-1",
                "calm",
                Timestamp.from(clientTimestamp),
                Timestamp.from(clientTimestamp.plusSeconds(5))
        );
    }

    private void seedConsentAudit(
            String accountId,
            String sessionId,
            String installationId,
            String action,
            String result,
            String reason,
            Instant createdAt
    ) {
        jdbcTemplate.update(
                """
                insert into consent_audit_logs (
                    account_id,
                    session_id,
                    installation_id,
                    action,
                    result,
                    reason,
                    created_at
                ) values (?, ?, ?, ?, ?, ?, ?)
                """,
                accountId,
                sessionId,
                installationId,
                action,
                result,
                reason,
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

    private record RolePayload(String roleCode, String description, List<String> permissionCodes) {
    }
}
