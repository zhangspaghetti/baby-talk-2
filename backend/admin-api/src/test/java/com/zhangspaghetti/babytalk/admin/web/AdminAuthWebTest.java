package com.zhangspaghetti.babytalk.admin.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.admin.auth.AdminApiContractException;
import com.zhangspaghetti.babytalk.admin.auth.AdminAuthService;
import com.zhangspaghetti.babytalk.admin.auth.AdminJwtAuthenticationConverter;
import com.zhangspaghetti.babytalk.admin.rbac.AdminPermissionCatalog;
import com.zhangspaghetti.babytalk.security.JwtTokenService;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
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
class AdminAuthWebTest {

    @SuppressWarnings("resource")
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>(
            DockerImageName.parse("pgvector/pgvector:pg16")
                    .asCompatibleSubstituteFor("postgres"))
            .withDatabaseName("babytalk_admin_test")
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
    private AdminPermissionCatalog adminPermissionCatalog;

    @Autowired
    private AdminAuthService adminAuthService;

    @Autowired
    private JwtTokenService jwtTokenService;

    @Autowired
    @Qualifier("adminAccessTokenJwtDecoder")
    private JwtDecoder adminAccessTokenJwtDecoder;

    @Autowired
    private AdminJwtAuthenticationConverter adminJwtAuthenticationConverter;

    @BeforeEach
    void resetTables() {
        jdbcTemplate.execute("TRUNCATE TABLE admin_refresh_tokens, admin_principal_roles, admin_roles, admin_principals RESTART IDENTITY CASCADE");
        adminAuthService.seedBootstrapPrincipalIfMissing();
    }

    @Test
    void sharedPermissionCatalogMatchesMigratedSeedAndBootstrapRegrantsSuperAdminPermissions() {
        var seededPermissionCodes = jdbcTemplate.queryForList(
                """
                select permission_code
                from admin_permissions
                order by permission_code asc
                """,
                String.class);
        assertThat(seededPermissionCodes)
                .containsExactlyInAnyOrderElementsOf(adminPermissionCatalog.codes());
        assertThat(queryForInt("select count(*) from admin_role_permissions where role_code = 'super_admin'"))
                .isEqualTo(adminPermissionCatalog.codes().size());
    }

    @Test
    void firstSuperAdminSeedCanLoginAndMeReturnsCurrentPermissions() throws Exception {
        assertThat(queryForInt("select count(*) from admin_principals")).isEqualTo(1);
        assertThat(queryForInt("select count(*) from accounts")).isZero();
        assertThat(queryForInt("select count(*) from account_sessions")).isZero();

        mockMvc.perform(get("/actuator/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"));

        mockMvc.perform(get("/api/admin/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("admin_authentication_required"));

        var login = login("super_admin", "SuperAdmin123!");

        assertThat(queryForInt("select count(*) from admin_refresh_tokens")).isEqualTo(1);
        assertThat(queryForInt("select count(*) from account_sessions")).isZero();

        mockMvc.perform(get("/api/admin/me")
                        .header(HttpHeaders.AUTHORIZATION, bearer(login.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.principalId").value(login.principalId()))
                .andExpect(jsonPath("$.username").value("super_admin"))
                .andExpect(jsonPath("$.displayName").value("Super Admin"))
                .andExpect(jsonPath("$.roles[0]").value("super_admin"))
                .andExpect(jsonPath("$.permissions", hasSize(adminPermissionCatalog.codes().size())))
                .andExpect(jsonPath("$.permissions", hasItem(AdminPermissionCatalog.USERS_READ)));
    }

    @Test
    void currentPermissionsReflectDatabaseAfterRoleRemovalOnSameAccessToken() throws Exception {
        var login = login("super_admin", "SuperAdmin123!");
        jdbcTemplate.update("delete from admin_principal_roles where principal_id = ?", login.principalId());

        mockMvc.perform(get("/api/admin/me")
                        .header(HttpHeaders.AUTHORIZATION, bearer(login.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.roles").isEmpty())
                .andExpect(jsonPath("$.permissions").isEmpty());
    }

    @Test
    void authenticationConverterUsesCurrentDatabaseAuthoritiesInsteadOfJwtRolesClaim() throws Exception {
        var login = login("super_admin", "SuperAdmin123!");
        var decodedAccessToken = adminAccessTokenJwtDecoder.decode(login.accessToken());
        assertThat(decodedAccessToken.getClaimAsStringList("roles")).containsExactly("super_admin");

        jdbcTemplate.update("delete from admin_principal_roles where principal_id = ?", login.principalId());

        var authentication = adminJwtAuthenticationConverter.convert(decodedAccessToken);
        assertThat(authentication).isNotNull();
        assertThat(authentication.getAuthorities())
                .extracting(GrantedAuthority::getAuthority)
                .doesNotContain("ROLE_SUPER_ADMIN", AdminPermissionCatalog.USERS_READ);
    }

    @Test
    void badCredentialsReturnStable401WithoutEchoingPassword() throws Exception {
        mockMvc.perform(post("/api/admin/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"super_admin","password":"WrongPassword123!"}
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("invalid_admin_credentials"))
                .andExpect(content().string(not(containsString("WrongPassword123!"))));
    }

    @Test
    void refreshRotatesTokensAndOldSessionStopsWorking() throws Exception {
        var login = login("super_admin", "SuperAdmin123!");

        var refreshed = refresh(login.refreshToken());

        mockMvc.perform(get("/api/admin/me")
                        .header(HttpHeaders.AUTHORIZATION, bearer(refreshed.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.username").value("super_admin"))
                .andExpect(jsonPath("$.permissions", hasSize(adminPermissionCatalog.codes().size())))
                .andExpect(jsonPath("$.permissions", hasItem(AdminPermissionCatalog.USERS_READ)));

        mockMvc.perform(get("/api/admin/me")
                        .header(HttpHeaders.AUTHORIZATION, bearer(login.accessToken())))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("admin_session_invalid"));

        mockMvc.perform(post("/api/admin/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"%s"}
                                """.formatted(login.refreshToken())))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("refresh_token_rotated"));
    }

        @Test
        void concurrentRefreshOnlyAllowsOneSuccessfulRotation() throws Exception {
                var login = login("super_admin", "SuperAdmin123!");
                ExecutorService executor = Executors.newFixedThreadPool(2);
                CountDownLatch start = new CountDownLatch(1);

                try {
                        var futures = List.of(
                                        executor.submit(() -> refreshConcurrently(login.refreshToken(), start)),
                                        executor.submit(() -> refreshConcurrently(login.refreshToken(), start))
                        );

                        start.countDown();

                        var outcomes = futures.stream()
                                        .map(future -> {
                                                try {
                                                        return future.get(10, TimeUnit.SECONDS);
                                                } catch (Exception exception) {
                                                        throw new RuntimeException(exception);
                                                }
                                        })
                                        .toList();

                        assertThat(outcomes).extracting(RefreshAttempt::success)
                                        .containsExactlyInAnyOrder(true, false);
                        assertThat(outcomes.stream()
                                        .filter(outcome -> !outcome.success())
                                        .findFirst()
                                        .orElseThrow()
                                        .errorCode()).isEqualTo("refresh_token_rotated");
                        assertThat(queryForInt("select count(*) from admin_refresh_tokens where status = 'active'"))
                                        .isEqualTo(1);
                        assertThat(queryForInt("select count(*) from admin_refresh_tokens where status = 'rotated'"))
                                        .isEqualTo(1);
                } finally {
                        executor.shutdownNow();
                }
        }

    @Test
    void disabledPrincipalImmediatelyReturns401WithoutEchoingTokens() throws Exception {
        var login = login("super_admin", "SuperAdmin123!");
        var now = Timestamp.from(Instant.now());
        jdbcTemplate.update(
                "update admin_principals set status = 'disabled', updated_at = ? where principal_id = ?",
                now,
                login.principalId()
        );

        mockMvc.perform(get("/api/admin/me")
                        .header(HttpHeaders.AUTHORIZATION, bearer(login.accessToken())))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("admin_account_disabled"))
                .andExpect(content().string(not(containsString(login.accessToken()))))
                .andExpect(content().string(not(containsString(login.refreshToken()))));
    }

    @Test
    void expiredAndRevokedRefreshTokensReturn401AndLogoutInvalidatesAccess() throws Exception {
        var expiredLogin = login("super_admin", "SuperAdmin123!");
        jdbcTemplate.update(
                "update admin_refresh_tokens set expires_at = ?, updated_at = ? where refresh_token_id = ?",
                Timestamp.from(Instant.now().minusSeconds(60)),
                Timestamp.from(Instant.now()),
                refreshTokenId(expiredLogin.refreshToken())
        );

        mockMvc.perform(post("/api/admin/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"%s"}
                                """.formatted(expiredLogin.refreshToken())))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("refresh_token_expired"));

        var activeLogin = login("super_admin", "SuperAdmin123!");
        mockMvc.perform(post("/api/admin/auth/logout")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"%s"}
                                """.formatted(activeLogin.refreshToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.loggedOut").value(true));

        mockMvc.perform(post("/api/admin/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"%s"}
                                """.formatted(activeLogin.refreshToken())))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("refresh_token_revoked"));

        mockMvc.perform(get("/api/admin/me")
                        .header(HttpHeaders.AUTHORIZATION, bearer(activeLogin.accessToken())))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("admin_session_invalid"));
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
                .andExpect(jsonPath("$.admin.roles[0]").value("super_admin"))
                .andExpect(jsonPath("$.admin.permissions", hasSize(adminPermissionCatalog.codes().size())))
                .andExpect(jsonPath("$.admin.permissions", hasItem(AdminPermissionCatalog.USERS_READ)))
                .andReturn();
        return readTokens(response.getResponse().getContentAsString());
    }

    private TokenView refresh(String refreshToken) throws Exception {
        var response = mockMvc.perform(post("/api/admin/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"%s"}
                                """.formatted(refreshToken)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty())
                .andExpect(jsonPath("$.admin.permissions", hasSize(adminPermissionCatalog.codes().size())))
                .andExpect(jsonPath("$.admin.permissions", hasItem(AdminPermissionCatalog.USERS_READ)))
                .andReturn();
        return readTokens(response.getResponse().getContentAsString());
    }

        private RefreshAttempt refreshConcurrently(String refreshToken, CountDownLatch start) {
                try {
                        start.await(10, TimeUnit.SECONDS);
                        adminAuthService.refresh(refreshToken);
                        return new RefreshAttempt(true, null);
                } catch (AdminApiContractException exception) {
                        return new RefreshAttempt(false, exception.code());
                } catch (InterruptedException exception) {
                        Thread.currentThread().interrupt();
                        throw new RuntimeException(exception);
                }
        }

    private TokenView readTokens(String rawJson) throws Exception {
        JsonNode json = objectMapper.readTree(rawJson);
        return new TokenView(
                json.get("accessToken").asText(),
                json.get("refreshToken").asText(),
                json.get("admin").get("principalId").asText());
    }

    private String refreshTokenId(String refreshToken) {
        return jwtTokenService.decode(refreshToken).tokenId();
    }

    private String bearer(String accessToken) {
        return "Bearer " + accessToken;
    }

    private int queryForInt(String sql) {
        Integer value = jdbcTemplate.queryForObject(sql, Integer.class);
        return value == null ? 0 : value;
    }

    private record TokenView(String accessToken, String refreshToken, String principalId) {
    }

        private record RefreshAttempt(boolean success, String errorCode) {
        }
}
