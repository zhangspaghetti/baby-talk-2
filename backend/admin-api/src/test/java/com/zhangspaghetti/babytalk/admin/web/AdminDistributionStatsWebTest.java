package com.zhangspaghetti.babytalk.admin.web;

import static org.assertj.core.api.Assertions.assertThat;
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
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.stream.StreamSupport;
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
        "app.admin.distribution-stats.default-range=30d",
        "app.admin.distribution-stats.detail-limit=200"
})
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AdminDistributionStatsWebTest {

    @SuppressWarnings("resource")
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>(
            DockerImageName.parse("pgvector/pgvector:pg16")
                    .asCompatibleSubstituteFor("postgres"))
            .withDatabaseName("babytalk_admin_distribution_stats_test")
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
                "TRUNCATE TABLE share_landing_events, share_landing_cards, release_distribution_events, admin_refresh_tokens, admin_principal_roles, admin_role_permissions, admin_roles, admin_principals, account_sessions, accounts RESTART IDENTITY CASCADE"
        );
        adminAuthService.seedBootstrapPrincipalIfMissing();
    }

    @Test
    void statsSeparateTruthfulSectionsAndApplyReleaseOnlyChannelFilter() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        var now = Instant.now().truncatedTo(ChronoUnit.SECONDS);
        seedReleaseEvent("download", "stable", "public_link", "android", "page_view", null, now.minusSeconds(3600));
        seedReleaseEvent("upgrade", "beta", "version_gate", "ios", "unavailable", "platform_target_missing", now.minusSeconds(3500));
        seedShareEvent("token-alpha", "paired_progress", "create", null, "create", null, now.minusSeconds(3400));
        seedShareEvent("token-alpha", "paired_progress", "landing", "android", "page_view", null, now.minusSeconds(3300));
        seedShareEvent("token-alpha", "paired_progress", "download", "android", "download_fallback", null, now.minusSeconds(3200));
        seedReleaseEvent("download", "stable", "share_card", "android", "redirect", null, now.minusSeconds(3100));
        seedReleaseEvent("download", "beta", "share_card", "android", "redirect", null, now.minusSeconds(3000));

        var response = mockMvc.perform(get("/api/admin/distribution/stats")
                        .param("range", "30d")
                        .param("channel", "stable")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.applied.range").value("30d"))
                .andExpect(jsonPath("$.applied.channel").value("stable"))
                .andExpect(jsonPath("$.applied.detailLimit").value(200))
                .andReturn();

        var json = readJson(response);
        assertThat(json.path("channelScopeNote").asText()).contains("share_landing_events");
        assertThat(json.path("releaseOverview").path("totalEvents").asLong()).isEqualTo(2);
        assertThat(json.path("releaseOverview").path("successfulEvents").asLong()).isEqualTo(2);
        assertThat(json.path("shareOverview").path("totalEvents").asLong()).isEqualTo(3);
        assertThat(json.path("shareOverview").path("successfulEvents").asLong()).isEqualTo(3);
        assertThat(json.path("shareHandoff").path("totalShareDownloadFallbackEvents").asLong()).isEqualTo(1);
        assertThat(json.path("shareHandoff").path("totalReleaseShareCardEvents").asLong()).isEqualTo(1);
        assertThat(sumEventCounts(json.path("releaseTrend"))).isEqualTo(2);
        assertThat(sumEventCounts(json.path("shareTrend"))).isEqualTo(3);

        var detailRows = toList(json.path("detailRows"));
        assertThat(detailRows).hasSize(5);
        var releaseRows = detailRows.stream()
                .filter(row -> "release_distribution".equals(row.path("surface").asText()))
                .toList();
        var shareRows = detailRows.stream()
                .filter(row -> "share_landing".equals(row.path("surface").asText()))
                .toList();
        assertThat(releaseRows).hasSize(2);
        assertThat(shareRows).hasSize(3);
        assertThat(releaseRows)
                .extracting(row -> row.path("channel").asText())
                .containsOnly("stable");
        assertThat(shareRows).allSatisfy(row -> {
            assertThat(row.path("channel").isNull() || row.path("channel").isMissingNode()).isTrue();
            assertThat(row.has("token")).isFalse();
        });
        assertThat(detailRows)
                .extracting(row -> row.path("source").asText())
                .doesNotContain("version_gate");
    }

    @Test
    void rangePresetsBoundWindowAndEmptyStateStayStable() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        var now = Instant.now().truncatedTo(ChronoUnit.SECONDS);
        seedReleaseEvent("download", "stable", "public_link", "android", "page_view", null, now.minus(10, ChronoUnit.DAYS));
        seedShareEvent("token-recent", "latest_impact", "landing", "android", "page_view", null, now.minus(10, ChronoUnit.DAYS));
        seedReleaseEvent("download", "stable", "public_link", "ios", "redirect", null, now.minus(40, ChronoUnit.DAYS));
        seedShareEvent("token-older", "paired_progress", "download", "ios", "download_fallback", null, now.minus(40, ChronoUnit.DAYS));

        var sevenDay = readJson(mockMvc.perform(get("/api/admin/distribution/stats")
                        .param("range", "7d")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andReturn());
        assertThat(sevenDay.path("releaseOverview").path("totalEvents").asLong()).isZero();
        assertThat(sevenDay.path("shareOverview").path("totalEvents").asLong()).isZero();
        assertThat(toList(sevenDay.path("detailRows"))).hasSize(0);

        var defaultWindow = readJson(mockMvc.perform(get("/api/admin/distribution/stats")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andReturn());
        assertThat(defaultWindow.path("applied").path("range").asText()).isEqualTo("30d");
        assertThat(defaultWindow.path("releaseOverview").path("totalEvents").asLong()).isEqualTo(1);
        assertThat(defaultWindow.path("shareOverview").path("totalEvents").asLong()).isEqualTo(1);

        var ninetyDay = readJson(mockMvc.perform(get("/api/admin/distribution/stats")
                        .param("range", "90d")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andReturn());
        assertThat(ninetyDay.path("releaseOverview").path("totalEvents").asLong()).isEqualTo(2);
        assertThat(ninetyDay.path("shareOverview").path("totalEvents").asLong()).isEqualTo(2);
        assertThat(toList(ninetyDay.path("detailRows"))).hasSize(4);
    }

    @Test
    void invalidFiltersStayStable400() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");

        mockMvc.perform(get("/api/admin/distribution/stats")
                        .param("range", "14d")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_distribution_stats_range"))
                .andExpect(jsonPath("$.details.allowedRanges[0]").value("7d"));

        mockMvc.perform(get("/api/admin/distribution/stats")
                        .param("range", "")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_distribution_stats_range"));

        mockMvc.perform(get("/api/admin/distribution/stats")
                        .param("channel", "rogue")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_distribution_stats_channel"))
                .andExpect(jsonPath("$.details.allowedChannels[0]").value("all"));

        mockMvc.perform(get("/api/admin/distribution/stats")
                        .param("channel", "")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_distribution_stats_channel"));
    }

    @Test
    void nonReaderGets403() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        createRole(superAdmin.accessToken(), "users_reader", AdminPermissionCatalog.USERS_READ);
        createAdmin(superAdmin.accessToken(), "users_reader_one", "Users Reader", "Reader123!", "users_reader");
        var limitedAdmin = login("users_reader_one", "Reader123!");

        mockMvc.perform(get("/api/admin/distribution/stats")
                        .header(HttpHeaders.AUTHORIZATION, bearer(limitedAdmin.accessToken())))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("forbidden"));
    }

    @Test
    void disabledReaderGets401() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        createRole(superAdmin.accessToken(), "distribution_reader", AdminPermissionCatalog.DISTRIBUTION_READ);
        var createdAdmin = createAdmin(
                superAdmin.accessToken(),
                "distribution_reader_one",
                "Distribution Reader",
                "Reader123!",
                "distribution_reader");
        var distributionReader = login("distribution_reader_one", "Reader123!");

        mockMvc.perform(patch("/api/admin/admins/{principalId}/disable", createdAdmin.principalId())
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("disabled"));

        mockMvc.perform(get("/api/admin/distribution/stats")
                        .header(HttpHeaders.AUTHORIZATION, bearer(distributionReader.accessToken())))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("admin_account_disabled"));
    }

    private void seedReleaseEvent(
            String entrypoint,
            String releaseChannel,
            String source,
            String platform,
            String result,
            String failureReason,
            Instant createdAt
    ) {
        jdbcTemplate.update(
                """
                insert into release_distribution_events (
                    entrypoint,
                    release_channel,
                    source,
                    platform,
                    result,
                    failure_reason,
                    created_at
                ) values (?, ?, ?, ?, ?, ?, ?)
                """,
                entrypoint,
                releaseChannel,
                source,
                platform,
                result,
                failureReason,
                Timestamp.from(createdAt)
        );
    }

    private void seedShareEvent(
            String token,
            String source,
            String entrypoint,
            String platform,
            String result,
            String failureReason,
            Instant createdAt
    ) {
        jdbcTemplate.update(
                """
                insert into share_landing_events (
                    token,
                    source,
                    entrypoint,
                    platform,
                    result,
                    failure_reason,
                    created_at
                ) values (?, ?, ?, ?, ?, ?, ?)
                """,
                token,
                source,
                entrypoint,
                platform,
                result,
                failureReason,
                Timestamp.from(createdAt)
        );
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

    private JsonNode readJson(MvcResult response) throws Exception {
        return objectMapper.readTree(response.getResponse().getContentAsString());
    }

    private long sumEventCounts(JsonNode trendNode) {
        return toList(trendNode).stream()
                .mapToLong(row -> row.path("eventCount").asLong())
                .sum();
    }

    private List<JsonNode> toList(JsonNode arrayNode) {
        return StreamSupport.stream(arrayNode.spliterator(), false).toList();
    }

    private String bearer(String accessToken) {
        return "Bearer " + accessToken;
    }

    private record TokenView(String accessToken, String refreshToken, String principalId, String username) {
    }

    private record CreatedAdmin(String principalId, String username) {
    }
}
