package com.zhangspaghetti.babytalk.admin.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.reset;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.request;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.admin.auth.AdminAuthService;
import com.zhangspaghetti.babytalk.admin.overview.AdminOverviewReadRepository;
import com.zhangspaghetti.babytalk.admin.overview.AdminOverviewService;
import com.zhangspaghetti.babytalk.admin.overview.AdminOverviewStreamService;
import com.zhangspaghetti.babytalk.admin.rbac.AdminPermissionCatalog;
import io.minio.MinioClient;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.ai.vectorstore.VectorStore;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.dao.QueryTimeoutException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.util.ReflectionTestUtils;
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
        "app.admin.mentor-audit.rate-limit-window=PT10M",
        "app.minio.endpoint=http://localhost:9000",
        "app.minio.access-key=test-access-key",
        "app.minio.secret-key=test-secret-key",
        "app.minio.bucket-name=test-bucket"
})
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AdminOverviewWebTest {

    @SuppressWarnings("resource")
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>(
            DockerImageName.parse("pgvector/pgvector:pg16")
                    .asCompatibleSubstituteFor("postgres"))
            .withDatabaseName("babytalk_admin_overview_test")
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

    @Autowired
    private AdminOverviewService adminOverviewService;

    @Autowired
    private AdminOverviewStreamService adminOverviewStreamService;

    @MockitoSpyBean
    private AdminOverviewReadRepository adminOverviewReadRepository;

    @MockitoBean
    private MinioClient minioClient;

    @MockitoBean
    private VectorStore vectorStore;

    @BeforeEach
    void resetState() {
        reset(minioClient, vectorStore, adminOverviewReadRepository);
        jdbcTemplate.execute("DELETE FROM vector_store");
        jdbcTemplate.execute(
                "TRUNCATE TABLE share_landing_events, share_landing_cards, release_distribution_events, mentor_turns, mentor_audit_logs, kg_admin_notifications, kg_contradictions, kg_relationships, kg_entities, ingestion_jobs, admin_refresh_tokens, admin_principal_roles, admin_role_permissions, admin_roles, admin_principals, account_sessions, accounts RESTART IDENTITY CASCADE"
        );
        adminAuthService.seedBootstrapPrincipalIfMissing();
        clearMapField(adminOverviewService, "cachedDomains");
        clearMapField(adminOverviewService, "lastSuccessfulSelectionSnapshots");
    }

    @Test
    void summaryAggregatesExistingDomainTruthAndExposesLiveTransport() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        var now = Instant.now().truncatedTo(ChronoUnit.SECONDS);

        seedIngestionJob(
                UUID.fromString("11111111-1111-1111-1111-111111111111"),
                "queue.pdf",
                "PROCESSING",
                3,
                null,
                now.minusSeconds(180),
                now.minusSeconds(30)
        );
        seedIngestionJob(
                UUID.fromString("22222222-2222-2222-2222-222222222222"),
                "failed.pdf",
                "FAILED",
                0,
                "tika parse failed",
                now.minusSeconds(170),
                now.minusSeconds(20)
        );

        var contradictionId = UUID.fromString("33333333-3333-3333-3333-333333333333");
        seedContradiction(
                contradictionId,
                "sleep training",
                "escalated",
                now.minusSeconds(60),
                now.minusSeconds(40),
                null
        );
        seedNotification(
                UUID.fromString("44444444-4444-4444-4444-444444444444"),
                contradictionId,
                false,
                now.minusSeconds(15)
        );

        seedBlockedIncident("corr_blocked", "install-alpha", now.minusSeconds(45));
        seedReleaseEvent("download", "stable", "public_link", "android", "unavailable", "asset_missing", now.minusSeconds(120));
        seedShareEvent("token-alpha", "paired_progress", "landing", "android", "page_view", null, now.minusSeconds(90));

        var summary = readJson(mockMvc.perform(get("/api/admin/overview/summary")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(summary.path("visibleDomainCount").asInt()).isEqualTo(4);
        assertThat(summary.path("degradedDomainCount").asInt()).isZero();
        assertThat(summary.path("transport").path("mode").asText()).isEqualTo("live");
        assertThat(summary.path("lastSuccessfulSnapshotAt").asText()).isNotBlank();

        var ingestion = requireDomain(summary, "knowledge_ingestion");
        assertThat(ingestion.path("visible").asBoolean()).isTrue();
        assertThat(ingestion.path("freshness").path("state").asText()).isEqualTo("updating");
        assertThat(ingestion.path("queue").path("queueCount").asLong()).isEqualTo(2);
        assertThat(ingestion.path("queue").path("attentionCount").asLong()).isEqualTo(1);
        assertThat(ingestion.path("nextAction").path("code").asText()).isEqualTo("retry_failed_jobs");

        var knowledgeKg = requireDomain(summary, "knowledge_kg");
        assertThat(knowledgeKg.path("visible").asBoolean()).isTrue();
        assertThat(knowledgeKg.path("freshness").path("state").asText()).isEqualTo("fresh");
        assertThat(knowledgeKg.path("queue").path("queueCount").asLong()).isEqualTo(2);
        assertThat(knowledgeKg.path("nextAction").path("code").asText()).isEqualTo("review_escalated_contradictions");

        var mentor = requireDomain(summary, "mentor_audit");
        assertThat(mentor.path("visible").asBoolean()).isTrue();
        assertThat(mentor.path("freshness").path("state").asText()).isEqualTo("fresh");
        assertThat(mentor.path("queue").path("queueCount").asLong()).isEqualTo(1);
        assertThat(mentor.path("nextAction").path("code").asText()).isEqualTo("review_blocked_fallback");

        var distribution = requireDomain(summary, "distribution");
        assertThat(distribution.path("visible").asBoolean()).isTrue();
        assertThat(distribution.path("freshness").path("state").asText()).isEqualTo("fresh");
        assertThat(distribution.path("queue").path("queueCount").asLong()).isEqualTo(1);
        assertThat(distribution.path("nextAction").path("code").asText()).isEqualTo("inspect_distribution_failures");
    }

    @Test
    void summaryRespectsVisibilityAndRejectsUnknownQueryParams() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        createRole(superAdmin.accessToken(), "distribution_reader", AdminPermissionCatalog.DISTRIBUTION_READ);
        createRole(superAdmin.accessToken(), "users_reader", AdminPermissionCatalog.USERS_READ);
        createAdmin(superAdmin.accessToken(), "dist_only", "Distribution Only", "Reader123!", "distribution_reader");
        createAdmin(superAdmin.accessToken(), "users_only", "Users Only", "Reader123!", "users_reader");

        var distributionReader = login("dist_only", "Reader123!");
        var summary = readJson(mockMvc.perform(get("/api/admin/overview/summary")
                        .header(HttpHeaders.AUTHORIZATION, bearer(distributionReader.accessToken())))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(summary.path("domains").size()).isEqualTo(4);
        assertThat(requireDomain(summary, "distribution").path("visible").asBoolean()).isTrue();
        assertThat(requireDomain(summary, "knowledge_ingestion").path("visible").asBoolean()).isFalse();
        assertThat(requireDomain(summary, "knowledge_ingestion").path("freshness").path("state").asText()).isEqualTo("forbidden");
        assertThat(requireDomain(summary, "mentor_audit").path("visible").asBoolean()).isFalse();

        var usersReader = login("users_only", "Reader123!");
        mockMvc.perform(get("/api/admin/overview/summary")
                        .header(HttpHeaders.AUTHORIZATION, bearer(usersReader.accessToken())))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("forbidden"));

        mockMvc.perform(get("/api/admin/overview/stream")
                        .header(HttpHeaders.AUTHORIZATION, bearer(usersReader.accessToken())))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("forbidden"));

        mockMvc.perform(get("/api/admin/overview/summary")
                        .param("scope", "all")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_overview_query_param"));

        mockMvc.perform(get("/api/admin/overview/stream")
                        .param("cursor", "unexpected")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_overview_query_param"));

        mockMvc.perform(get("/api/admin/overview/stream")
                        .param("sinceEventId", "")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_overview_since_event_id"));

        mockMvc.perform(get("/api/admin/overview/stream")
                        .header("Last-Event-ID", "9".repeat(65))
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_overview_since_event_id"));
    }

    @Test
    void summaryFallsBackToCachedSnapshotWhenVisibleDomainTimesOut() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        var now = Instant.now().truncatedTo(ChronoUnit.SECONDS);
        seedBlockedIncident("corr_timeout", "install-timeout", now.minusSeconds(30));

        var initial = readJson(mockMvc.perform(get("/api/admin/overview/summary")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andReturn());
        var firstSnapshotAt = initial.path("lastSuccessfulSnapshotAt").asText();
        var firstMentorQueueCount = requireDomain(initial, "mentor_audit").path("queue").path("queueCount").asLong();

        doThrow(timeoutException()).when(adminOverviewReadRepository).fetchMentorAuditSummary();

        var degraded = readJson(mockMvc.perform(get("/api/admin/overview/summary")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(degraded.path("degradedDomainCount").asInt()).isEqualTo(1);
        assertThat(degraded.path("lastSuccessfulSnapshotAt").asText()).isEqualTo(firstSnapshotAt);
        assertThat(degraded.path("transport").path("mode").asText()).isEqualTo("polling_required");
        assertThat(degraded.path("transport").path("degradedReason").asText()).isEqualTo("repository_timeout");
        assertThat(requireDomain(degraded, "mentor_audit").path("freshness").path("state").asText()).isEqualTo("degraded");
        assertThat(requireDomain(degraded, "mentor_audit").path("queue").path("queueCount").asLong()).isEqualTo(firstMentorQueueCount);
    }

    @Test
    void summaryReturnsSnapshotUnavailableWhenNoCachedSelectionExists() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");

        doThrow(timeoutException()).when(adminOverviewReadRepository).fetchMentorAuditSummary();

        mockMvc.perform(get("/api/admin/overview/summary")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.code").value("overview_snapshot_unavailable"))
                .andExpect(jsonPath("$.details.retryable").value(true))
                .andExpect(jsonPath("$.details.timedOutDomains[0]").value("mentor_audit"));
    }

    @Test
    void streamReplayExposesMetadataOnlyTransportAndSummaryRejectsMalformedVisibleDomainPayload() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        var baseReconnectCount = adminOverviewStreamService.currentView().reconnectCount();

        var streamResult = mockMvc.perform(get("/api/admin/overview/stream")
                        .param("sinceEventId", "1")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(request().asyncStarted())
                .andExpect(status().isOk())
                .andReturn();

        var streamPayload = "";
        try {
            streamPayload = awaitSsePayload(streamResult, "event:transport");
        } finally {
            completeAsyncRequest(streamResult);
        }

        assertThat(streamPayload).contains("event:transport");
        assertThat(streamPayload).contains("\"replayed\":true");
        assertThat(streamPayload).contains("\"connectionCount\":");
        assertThat(streamPayload).contains("\"reconnectCount\":");
        assertThat(streamPayload).doesNotContain("knowledge_ingestion");
        assertThat(streamPayload).doesNotContain("knowledge_kg");
        assertThat(streamPayload).doesNotContain("mentor_audit");
        assertThat(streamPayload).doesNotContain("distribution");
        assertThat(streamPayload).doesNotContain("share_token");
        assertThat(streamPayload).doesNotContain("accessToken");
        assertThat(streamPayload).doesNotContain("public-admin-api-url");

        doReturn(new AdminOverviewReadRepository.DistributionSummaryRow(1, 1, 0, 0, null))
                .when(adminOverviewReadRepository)
                .fetchDistributionSummary(any());

        var failure = readJson(mockMvc.perform(get("/api/admin/overview/summary")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isInternalServerError())
                .andReturn());

        assertThat(failure.path("code").asText()).isEqualTo("overview_contract_failure");
        assertThat(failure.path("details").path("domain").asText()).isEqualTo("distribution");
        assertThat(adminOverviewStreamService.currentView().reconnectCount()).isGreaterThan(baseReconnectCount);
    }

    private QueryTimeoutException timeoutException() {
        return new QueryTimeoutException(
                "canceling statement due to statement timeout",
                new SQLException("canceling statement due to statement timeout", "57014")
        );
    }

    private void clearMapField(Object target, String fieldName) {
        @SuppressWarnings("unchecked")
        var map = (java.util.Map<Object, Object>) ReflectionTestUtils.getField(target, fieldName);
        if (map != null) {
            map.clear();
        }
    }

    private JsonNode requireDomain(JsonNode summary, String key) {
        for (var domain : summary.path("domains")) {
            if (key.equals(domain.path("key").asText())) {
                return domain;
            }
        }
        throw new AssertionError("Missing domain: " + key + " in " + summary);
    }

    private String awaitSsePayload(MvcResult result, String expectedFragment) throws Exception {
        for (var attempt = 0; attempt < 20; attempt++) {
            var payload = result.getResponse().getContentAsString();
            if (payload.contains(expectedFragment)) {
                return payload;
            }
            Thread.sleep(25L);
        }
        throw new AssertionError("Expected SSE payload to contain '" + expectedFragment + "' but got: "
                + result.getResponse().getContentAsString());
    }

    private void completeAsyncRequest(MvcResult result) throws InterruptedException {
        var asyncContext = result.getRequest().getAsyncContext();
        if (asyncContext != null) {
            asyncContext.complete();
            Thread.sleep(25L);
        }
    }

    private void createRole(String accessToken, String roleCode, String permissionCode) throws Exception {
        mockMvc.perform(post("/api/admin/roles")
                        .header(HttpHeaders.AUTHORIZATION, bearer(accessToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  \"roleCode\": \"%s\",
                                  \"description\": \"Role %s\",
                                  \"permissionCodes\": [\"%s\"]
                                }
                                """.formatted(roleCode, roleCode, permissionCode)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.roleCode").value(roleCode));
    }

    private void createAdmin(
            String accessToken,
            String username,
            String displayName,
            String password,
            String roleCode
    ) throws Exception {
        mockMvc.perform(post("/api/admin/admins")
                        .header(HttpHeaders.AUTHORIZATION, bearer(accessToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  \"username\": \"%s\",
                                  \"displayName\": \"%s\",
                                  \"password\": \"%s\",
                                  \"roleCodes\": [\"%s\"]
                                }
                                """.formatted(username, displayName, password, roleCode)))
                .andExpect(status().isCreated());
    }

    private TokenView login(String username, String password) throws Exception {
        var response = mockMvc.perform(post("/api/admin/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {\"username\":\"%s\",\"password\":\"%s\"}
                                """.formatted(username, password)))
                .andExpect(status().isOk())
                .andReturn();
        var json = objectMapper.readTree(response.getResponse().getContentAsString());
        return new TokenView(
                json.get("accessToken").asText(),
                json.get("refreshToken").asText(),
                json.get("admin").get("principalId").asText(),
                json.get("admin").get("username").asText());
    }

    private JsonNode readJson(MvcResult response) throws Exception {
        return objectMapper.readTree(response.getResponse().getContentAsString());
    }

    private void seedIngestionJob(
            UUID jobId,
            String originalFilename,
            String status,
            int totalChunks,
            String errorMessage,
            Instant createdAt,
            Instant updatedAt
    ) {
        jdbcTemplate.update(
                """
                insert into ingestion_jobs (
                    id,
                    original_filename,
                    minio_object_key,
                    status,
                    total_chunks,
                    error_message,
                    created_at,
                    updated_at
                ) values (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                jobId,
                originalFilename,
                "ingestion/private/" + originalFilename,
                status,
                totalChunks,
                errorMessage,
                Timestamp.from(createdAt),
                Timestamp.from(updatedAt)
        );
    }

    private void seedContradiction(
            UUID contradictionId,
            String entityTopic,
            String status,
            Instant detectedAt,
            Instant reviewedAt,
            Instant resolvedAt
    ) {
        var sourceEntityId = UUID.randomUUID();
        var targetEntityId = UUID.randomUUID();
        var relationshipAId = UUID.randomUUID();
        var relationshipBId = UUID.randomUUID();

        seedEntity(sourceEntityId, entityTopic + " source");
        seedEntity(targetEntityId, entityTopic + " target");
        seedRelationship(relationshipAId, sourceEntityId, targetEntityId, "book-a.pdf", "context-a");
        seedRelationship(relationshipBId, sourceEntityId, targetEntityId, "book-b.pdf", "context-b");

        jdbcTemplate.update(
                """
                insert into kg_contradictions (
                    id,
                    entity_topic,
                    relationship_a_id,
                    relationship_b_id,
                    source_a_book,
                    source_b_book,
                    description,
                    status,
                    agent_review_result,
                    admin_notes,
                    detected_at,
                    reviewed_at,
                    resolved_at
                ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                contradictionId,
                entityTopic,
                relationshipAId,
                relationshipBId,
                "book-a.pdf",
                "book-b.pdf",
                "不同月龄对夜醒处理建议互相冲突。",
                status,
                "{\"verdict\":\"escalated\"}",
                null,
                Timestamp.from(detectedAt),
                reviewedAt == null ? null : Timestamp.from(reviewedAt),
                resolvedAt == null ? null : Timestamp.from(resolvedAt)
        );
    }

    private void seedEntity(UUID entityId, String name) {
        jdbcTemplate.update(
                """
                insert into kg_entities (id, name, entity_type, description)
                values (?, ?, 'concept', ?)
                """,
                entityId,
                name,
                "desc-" + name
        );
    }

    private void seedRelationship(
            UUID relationshipId,
            UUID sourceEntityId,
            UUID targetEntityId,
            String sourceBook,
            String contextNote
    ) {
        jdbcTemplate.update(
                """
                insert into kg_relationships (
                    id,
                    source_entity_id,
                    target_entity_id,
                    relation_type,
                    source_book,
                    context_note
                ) values (?, ?, ?, 'contradicts', ?, ?)
                """,
                relationshipId,
                sourceEntityId,
                targetEntityId,
                sourceBook,
                contextNote
        );
    }

    private void seedNotification(UUID notificationId, UUID contradictionId, boolean isRead, Instant createdAt) {
        jdbcTemplate.update(
                """
                insert into kg_admin_notifications (
                    id,
                    contradiction_id,
                    notification_type,
                    message,
                    is_read,
                    created_at
                ) values (?, ?, 'contradiction_escalated', '需要人工复核。', ?, ?)
                """,
                notificationId,
                contradictionId,
                isRead,
                Timestamp.from(createdAt)
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

    private String bearer(String accessToken) {
        return "Bearer " + accessToken;
    }

    private record TokenView(String accessToken, String refreshToken, String principalId, String username) {
    }
}
