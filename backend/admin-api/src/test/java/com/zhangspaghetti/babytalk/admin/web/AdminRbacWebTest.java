package com.zhangspaghetti.babytalk.admin.web;

import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.hasSize;
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
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
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
        "app.admin.auth.bootstrap.display-name=Super Admin",
        "app.embedding.mode=dev-hash"
})
@AutoConfigureMockMvc
class AdminRbacWebTest {

    @SuppressWarnings("resource")
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>(
            DockerImageName.parse("pgvector/pgvector:pg16")
                    .asCompatibleSubstituteFor("postgres"))
            .withDatabaseName("babytalk_admin_rbac_test")
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
                "TRUNCATE TABLE admin_refresh_tokens, admin_principal_roles, admin_role_permissions, admin_roles, admin_principals, account_sessions, accounts RESTART IDENTITY CASCADE"
        );
        adminAuthService.seedBootstrapPrincipalIfMissing();
    }

    @Test
    void superAdminCanCreateRoleAndAdminAndLimitedAdminCanOnlyReadUsers() throws Exception {
        seedAccount("acct_001", "13900000001", "active", "accepted", Instant.parse("2026-04-01T00:00:00Z"));
        seedAccount("acct_002", "13900000002", "deleted", "revoked", Instant.parse("2026-04-02T00:00:00Z"));

        var superAdmin = login("super_admin", "SuperAdmin123!");

        mockMvc.perform(get("/api/admin/permissions")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[*].permissionCode", hasItem(AdminPermissionCatalog.USERS_READ)));

        mockMvc.perform(post("/api/admin/roles")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "roleCode": "users_reader",
                                  "description": "Users read only",
                                  "permissionCodes": ["users:read"]
                                }
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.roleCode").value("users_reader"))
                .andExpect(jsonPath("$.permissionCodes", hasItem(AdminPermissionCatalog.USERS_READ)));

        var createdAdmin = createAdmin(superAdmin.accessToken(), "users_reader_one", "Users Reader", "Reader123!", "users_reader");

        mockMvc.perform(get("/api/admin/roles")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[*].roleCode", hasItem("users_reader")));

        mockMvc.perform(get("/api/admin/admins")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[*].principalId", hasItem(createdAdmin.principalId())))
                .andExpect(jsonPath("$[*].username", hasItem("users_reader_one")));

        var limitedAdmin = login("users_reader_one", "Reader123!");

        mockMvc.perform(get("/api/admin/users")
                        .header(HttpHeaders.AUTHORIZATION, bearer(limitedAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.page").value(1))
                .andExpect(jsonPath("$.pageSize").value(20))
                .andExpect(jsonPath("$.total").value(2))
                .andExpect(jsonPath("$.filters.status").value("all"))
                .andExpect(jsonPath("$.filters.query").isEmpty())
                .andExpect(jsonPath("$.items", hasSize(2)))
                .andExpect(jsonPath("$.items[0].accountId").value("acct_001"))
                .andExpect(jsonPath("$.items[0].phoneNumber").value("13900000001"))
                .andExpect(jsonPath("$.items[0].status").value("active"))
                .andExpect(jsonPath("$.items[0].latestConsentStatus").value("accepted"))
                .andExpect(jsonPath("$.items[0].createdAt").value("2026-04-01T00:00:00Z"))
                .andExpect(jsonPath("$.items[0].deletedAt").isEmpty());

        mockMvc.perform(post("/api/admin/roles")
                        .header(HttpHeaders.AUTHORIZATION, bearer(limitedAdmin.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "roleCode": "blocked_role",
                                  "description": "Should not be allowed",
                                  "permissionCodes": ["users:read"]
                                }
                                """))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("forbidden"));

        mockMvc.perform(post("/api/admin/admins")
                        .header(HttpHeaders.AUTHORIZATION, bearer(limitedAdmin.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "username": "blocked_admin",
                                  "displayName": "Blocked Admin",
                                  "password": "Blocked123!",
                                  "roleCodes": ["users_reader"]
                                }
                                """))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("forbidden"));
    }

    @Test
    void sameAccessTokenImmediatelyLosesUsersReadAfterRoleRemoval() throws Exception {
        seedAccount("acct_101", "13900000101", "active", "accepted", Instant.parse("2026-04-10T00:00:00Z"));

        var superAdmin = login("super_admin", "SuperAdmin123!");
        createUsersReaderRole(superAdmin.accessToken());
        var createdAdmin = createAdmin(superAdmin.accessToken(), "users_reader_two", "Users Reader Two", "Reader123!", "users_reader");
        var limitedAdmin = login("users_reader_two", "Reader123!");

        mockMvc.perform(get("/api/admin/users")
                        .header(HttpHeaders.AUTHORIZATION, bearer(limitedAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items", hasSize(1)));

        jdbcTemplate.update("delete from admin_principal_roles where principal_id = ?", createdAdmin.principalId());

        mockMvc.perform(get("/api/admin/users")
                        .header(HttpHeaders.AUTHORIZATION, bearer(limitedAdmin.accessToken())))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("forbidden"));
    }

    @Test
    void sameAccessTokenImmediatelyFailsAfterDisableAndDisableEndpointIsIdempotent() throws Exception {
        seedAccount("acct_201", "13900000201", "active", "accepted", Instant.parse("2026-04-20T00:00:00Z"));

        var superAdmin = login("super_admin", "SuperAdmin123!");
        createUsersReaderRole(superAdmin.accessToken());
        var createdAdmin = createAdmin(superAdmin.accessToken(), "users_reader_three", "Users Reader Three", "Reader123!", "users_reader");
        var limitedAdmin = login("users_reader_three", "Reader123!");

        mockMvc.perform(patch("/api/admin/admins/{principalId}/disable", createdAdmin.principalId())
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.principalId").value(createdAdmin.principalId()))
                .andExpect(jsonPath("$.status").value("disabled"));

        mockMvc.perform(patch("/api/admin/admins/{principalId}/disable", createdAdmin.principalId())
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.principalId").value(createdAdmin.principalId()))
                .andExpect(jsonPath("$.status").value("disabled"));

        mockMvc.perform(get("/api/admin/users")
                        .header(HttpHeaders.AUTHORIZATION, bearer(limitedAdmin.accessToken())))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("admin_account_disabled"));
    }

    @Test
    void negativeContractsStayStableAndUsersListCanBeEmpty() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");

        mockMvc.perform(get("/api/admin/users")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items", hasSize(0)))
                .andExpect(jsonPath("$.total").value(0));

        mockMvc.perform(post("/api/admin/roles")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "roleCode": "bad_role",
                                  "description": "Bad Role",
                                  "permissionCodes": ["users:nope"]
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("unknown_admin_permission"));

        mockMvc.perform(post("/api/admin/admins")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "username": "missing_fields",
                                  "roleCodes": ["super_admin"]
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("validation_failed"));

        mockMvc.perform(post("/api/admin/admins")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "username": "unknown_role_admin",
                                  "displayName": "Unknown Role Admin",
                                  "password": "Reader123!",
                                  "roleCodes": ["missing_role"]
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("unknown_admin_role"));

        createUsersReaderRole(superAdmin.accessToken());
        createAdmin(superAdmin.accessToken(), "duplicate_admin", "Duplicate Admin", "Reader123!", "users_reader");

        mockMvc.perform(post("/api/admin/admins")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "username": "duplicate_admin",
                                  "displayName": "Duplicate Admin",
                                  "password": "Reader123!",
                                  "roleCodes": ["users_reader"]
                                }
                                """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("admin_username_conflict"));

        mockMvc.perform(patch("/api/admin/admins/{principalId}/disable", "admin_missing")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("admin_principal_not_found"));
    }

    private void createUsersReaderRole(String superAdminAccessToken) throws Exception {
        mockMvc.perform(post("/api/admin/roles")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdminAccessToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "roleCode": "users_reader",
                                  "description": "Users read only",
                                  "permissionCodes": ["users:read"]
                                }
                                """))
                .andExpect(status().isCreated());
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
                .andExpect(jsonPath("$.username").value(username))
                .andExpect(jsonPath("$.status").value("active"))
                .andExpect(jsonPath("$.roleCodes", hasItem(roleCode)))
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

    private void seedAccount(String accountId, String phoneNumber, String status, String consentStatus, Instant createdAt) {
        jdbcTemplate.update(
                """
                insert into accounts (account_id, phone_number, status, latest_consent_status, created_at, deleted_at)
                values (?, ?, ?, ?, ?, null)
                """,
                accountId,
                phoneNumber,
                status,
                consentStatus,
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
