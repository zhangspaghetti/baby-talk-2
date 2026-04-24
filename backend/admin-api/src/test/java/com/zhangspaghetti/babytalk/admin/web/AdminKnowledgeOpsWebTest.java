package com.zhangspaghetti.babytalk.admin.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.hasSize;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.admin.auth.AdminAuthService;
import com.zhangspaghetti.babytalk.admin.rbac.AdminPermissionCatalog;
import io.minio.GetObjectResponse;
import io.minio.MinioClient;
import io.minio.ObjectWriteResponse;
import java.io.ByteArrayInputStream;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import okhttp3.Headers;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.ai.vectorstore.VectorStore;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.core.io.ClassPathResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
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
        "app.minio.endpoint=http://localhost:9000",
        "app.minio.access-key=test-access-key",
        "app.minio.secret-key=test-secret-key",
        "app.minio.bucket-name=test-bucket"
})
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AdminKnowledgeOpsWebTest {

    @SuppressWarnings("resource")
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>(
            DockerImageName.parse("pgvector/pgvector:pg16")
                    .asCompatibleSubstituteFor("postgres"))
            .withDatabaseName("babytalk_admin_knowledge_ops_test")
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

    @MockitoBean
    private MinioClient minioClient;

    @MockitoBean
    private VectorStore vectorStore;

    @BeforeEach
    void resetTables() {
        reset(minioClient, vectorStore);
        jdbcTemplate.execute("DELETE FROM vector_store");
        jdbcTemplate.execute(
                "TRUNCATE TABLE kg_admin_notifications, kg_contradictions, kg_relationships, kg_entities, ingestion_jobs, admin_refresh_tokens, admin_principal_roles, admin_role_permissions, admin_roles, admin_principals, account_sessions, accounts RESTART IDENTITY CASCADE"
        );
        adminAuthService.seedBootstrapPrincipalIfMissing();
    }

    @Test
    void listAndDetailContractsStayWithinAdminKnowledgeSurface() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        var completedJobId = UUID.fromString("11111111-1111-1111-1111-111111111111");
        var failedJobId = UUID.fromString("22222222-2222-2222-2222-222222222222");
        seedIngestionJob(
                completedJobId,
                "chapter-1.pdf",
                "ingestion/private/chapter-1.pdf",
                "COMPLETED",
                18,
                null,
                Instant.parse("2026-04-21T00:00:00Z"),
                Instant.parse("2026-04-21T00:05:00Z")
        );
        seedIngestionJob(
                failedJobId,
                "chapter-2.pdf",
                "ingestion/private/chapter-2.pdf",
                "FAILED",
                0,
                "tika parse failed",
                Instant.parse("2026-04-21T00:10:00Z"),
                Instant.parse("2026-04-21T00:11:00Z")
        );

        var contradictionId = UUID.fromString("33333333-3333-3333-3333-333333333333");
        seedContradiction(
                contradictionId,
                "sleep training",
                "escalated",
                "不同月龄对夜醒处理建议互相冲突。",
                "book-a.pdf",
                "book-b.pdf",
                "{\"verdict\":\"escalated\"}",
                null,
                Instant.parse("2026-04-21T01:00:00Z"),
                Instant.parse("2026-04-21T01:05:00Z"),
                null
        );
        var notificationId = UUID.fromString("44444444-4444-4444-4444-444444444444");
        seedNotification(
                notificationId,
                contradictionId,
                "contradiction_escalated",
                "需要人工复核 sleep training。",
                false,
                Instant.parse("2026-04-21T01:06:00Z")
        );

        mockMvc.perform(get("/api/admin/knowledge/ingestion/jobs")
                        .param("status", "failed")
                        .param("limit", "10")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(1)))
                .andExpect(jsonPath("$[0].id").value(failedJobId.toString()))
                .andExpect(jsonPath("$[0].originalFilename").value("chapter-2.pdf"))
                .andExpect(jsonPath("$[0].status").value("FAILED"))
                .andExpect(jsonPath("$[0].retryable").value(true))
                .andExpect(jsonPath("$[0].errorMessage").value("tika parse failed"))
                .andExpect(jsonPath("$[0].minioObjectKey").doesNotExist());

        mockMvc.perform(get("/api/admin/knowledge/ingestion/jobs/{jobId}", failedJobId)
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(failedJobId.toString()))
                .andExpect(jsonPath("$.originalFilename").value("chapter-2.pdf"))
                .andExpect(jsonPath("$.status").value("FAILED"))
                .andExpect(jsonPath("$.errorMessage").value("tika parse failed"))
                .andExpect(jsonPath("$.minioObjectKey").doesNotExist());

        mockMvc.perform(get("/api/admin/knowledge/kg/contradictions")
                        .param("status", "ESCALATED")
                        .param("limit", "5")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(1)))
                .andExpect(jsonPath("$[0].id").value(contradictionId.toString()))
                .andExpect(jsonPath("$[0].entityTopic").value("sleep training"))
                .andExpect(jsonPath("$[0].status").value("escalated"))
                .andExpect(jsonPath("$[0].notificationCount").value(1))
                .andExpect(jsonPath("$[0].unreadNotificationCount").value(1));

        mockMvc.perform(get("/api/admin/knowledge/kg/contradictions/{contradictionId}", contradictionId)
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(contradictionId.toString()))
                .andExpect(jsonPath("$.status").value("escalated"))
                .andExpect(jsonPath("$.agentReviewResult").value("{\"verdict\":\"escalated\"}"))
                .andExpect(jsonPath("$.notificationCount").value(1))
                .andExpect(jsonPath("$.unreadNotificationCount").value(1));

        mockMvc.perform(get("/api/admin/knowledge/kg/contradictions/{contradictionId}/notifications", contradictionId)
                        .param("limit", "5")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(1)))
                .andExpect(jsonPath("$[0].id").value(notificationId.toString()))
                .andExpect(jsonPath("$[0].contradictionId").value(contradictionId.toString()))
                .andExpect(jsonPath("$[0].notificationType").value("contradiction_escalated"))
                .andExpect(jsonPath("$[0].isRead").value(false));
    }

    @Test
    void resolveAndMarkReadMutationsAreIdempotent() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        var contradictionId = UUID.fromString("55555555-5555-5555-5555-555555555555");
        seedContradiction(
                contradictionId,
                "feeding schedule",
                "escalated",
                "同一阶段的喂养频率建议冲突。",
                "feeding-a.pdf",
                "feeding-b.pdf",
                "{\"verdict\":\"escalated\"}",
                null,
                Instant.parse("2026-04-22T00:00:00Z"),
                Instant.parse("2026-04-22T00:05:00Z"),
                null
        );
        var notificationId = UUID.fromString("66666666-6666-6666-6666-666666666666");
        seedNotification(
                notificationId,
                contradictionId,
                "contradiction_escalated",
                "feeding schedule 需要人工确认。",
                false,
                Instant.parse("2026-04-22T00:06:00Z")
        );

        var firstResolve = readJson(mockMvc.perform(patch("/api/admin/knowledge/kg/contradictions/{contradictionId}/resolve", contradictionId)
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  \"adminNotes\": \"manual_resolution\"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("resolved"))
                .andExpect(jsonPath("$.adminNotes").value("manual_resolution"))
                .andExpect(jsonPath("$.resolvedAt").isNotEmpty())
                .andReturn());

        var secondResolve = readJson(mockMvc.perform(patch("/api/admin/knowledge/kg/contradictions/{contradictionId}/resolve", contradictionId)
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  \"adminNotes\": \"should_not_overwrite\"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("resolved"))
                .andExpect(jsonPath("$.adminNotes").value("manual_resolution"))
                .andReturn());

        assertThat(secondResolve.path("resolvedAt").asText()).isEqualTo(firstResolve.path("resolvedAt").asText());
        assertThat(jdbcTemplate.queryForObject(
                "select status from kg_contradictions where id = ?",
                String.class,
                contradictionId
        )).isEqualTo("resolved");
        assertThat(jdbcTemplate.queryForObject(
                "select admin_notes from kg_contradictions where id = ?",
                String.class,
                contradictionId
        )).isEqualTo("manual_resolution");

        var firstRead = readJson(mockMvc.perform(patch("/api/admin/knowledge/kg/notifications/{notificationId}/read", notificationId)
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(notificationId.toString()))
                .andExpect(jsonPath("$.isRead").value(true))
                .andReturn());

        var secondRead = readJson(mockMvc.perform(patch("/api/admin/knowledge/kg/notifications/{notificationId}/read", notificationId)
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(notificationId.toString()))
                .andExpect(jsonPath("$.isRead").value(true))
                .andReturn());

        assertThat(secondRead.path("createdAt").asText()).isEqualTo(firstRead.path("createdAt").asText());
        assertThat(jdbcTemplate.queryForObject(
                "select is_read from kg_admin_notifications where id = ?",
                Boolean.class,
                notificationId
        )).isTrue();

        mockMvc.perform(get("/api/admin/knowledge/kg/contradictions/{contradictionId}/notifications", contradictionId)
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(1)))
                .andExpect(jsonPath("$[0].id").value(notificationId.toString()))
                .andExpect(jsonPath("$[0].isRead").value(true));
    }

    @Test
    void emptyQueuesMissingIdsAndAuthFailuresStayStable() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        var contradictionWithoutNotifications = UUID.fromString("77777777-7777-7777-7777-777777777777");
        seedContradiction(
                contradictionWithoutNotifications,
                "wake windows",
                "detected",
                "需要检查 wake windows 的条件差异。",
                "wake-a.pdf",
                "wake-b.pdf",
                null,
                null,
                Instant.parse("2026-04-23T00:00:00Z"),
                null,
                null
        );

        mockMvc.perform(get("/api/admin/knowledge/ingestion/jobs")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(0)));

        mockMvc.perform(get("/api/admin/knowledge/kg/contradictions/{contradictionId}/notifications", contradictionWithoutNotifications)
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(0)));

        mockMvc.perform(get("/api/admin/knowledge/ingestion/jobs/{jobId}", "not-a-uuid")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_knowledge_ingestion_job_id"));

        mockMvc.perform(get("/api/admin/knowledge/kg/contradictions")
                        .param("status", "weird")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_knowledge_contradiction_status"));

        mockMvc.perform(get("/api/admin/knowledge/ingestion/jobs")
                        .param("status", "x".repeat(33))
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("validation_failed"));

        mockMvc.perform(get("/api/admin/knowledge/ingestion/jobs/{jobId}", UUID.fromString("88888888-8888-8888-8888-888888888888"))
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("knowledge_ingestion_job_not_found"));

        mockMvc.perform(get("/api/admin/knowledge/kg/contradictions/{contradictionId}", UUID.fromString("99999999-9999-9999-9999-999999999999"))
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("knowledge_contradiction_not_found"));

        mockMvc.perform(patch("/api/admin/knowledge/kg/notifications/{notificationId}/read", UUID.fromString("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"))
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("knowledge_notification_not_found"));

        createRole(superAdmin.accessToken(), "kg_reader_only", List.of(AdminPermissionCatalog.KG_READ));
        createAdmin(superAdmin.accessToken(), "kg_reader_only_one", "KG Reader", "Reader123!", "kg_reader_only");
        var readOnlyAdmin = login("kg_reader_only_one", "Reader123!");

        mockMvc.perform(patch("/api/admin/knowledge/kg/contradictions/{contradictionId}/resolve", contradictionWithoutNotifications)
                        .header(HttpHeaders.AUTHORIZATION, bearer(readOnlyAdmin.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  \"adminNotes\": \"cannot_write\"
                                }
                                """))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("forbidden"));

        createRole(superAdmin.accessToken(), "kg_reader_disabled", List.of(AdminPermissionCatalog.KG_READ));
        var disabledAdmin = createAdmin(
                superAdmin.accessToken(),
                "kg_reader_disabled_one",
                "KG Reader Disabled",
                "Reader123!",
                "kg_reader_disabled"
        );
        var disabledReader = login("kg_reader_disabled_one", "Reader123!");

        mockMvc.perform(patch("/api/admin/admins/{principalId}/disable", disabledAdmin.principalId())
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("disabled"));

        mockMvc.perform(get("/api/admin/knowledge/kg/contradictions")
                        .header(HttpHeaders.AUTHORIZATION, bearer(disabledReader.accessToken())))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("admin_account_disabled"));
    }

    @Test
    void uploadAcceptedResponseIncludesJobStateAndCompletesThroughSharedSeam() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        byte[] trackedPdf = trackedPdfBytes();
        stubPutObjectSuccess();
        when(minioClient.getObject(any())).thenReturn(getObjectResponse(trackedPdf));

        var uploadResponse = readJson(mockMvc.perform(multipart("/api/admin/knowledge/ingestion/upload")
                        .file(new MockMultipartFile("file", "knowledge-upload.pdf", "application/pdf", trackedPdf))
                        .param("bookTitle", "Baby Talk")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.jobId").isNotEmpty())
                .andExpect(jsonPath("$.originalFilename").value("knowledge-upload.pdf"))
                .andExpect(jsonPath("$.status").isNotEmpty())
                .andExpect(jsonPath("$.updatedAt").isNotEmpty())
                .andExpect(jsonPath("$.canRetry").value(false))
                .andReturn());

        var jobId = UUID.fromString(uploadResponse.path("jobId").asText());
        var completedJob = awaitIngestionJobStatus(superAdmin.accessToken(), jobId, "COMPLETED");

        assertThat(completedJob.path("id").asText()).isEqualTo(jobId.toString());
        assertThat(completedJob.path("status").asText()).isEqualTo("COMPLETED");
        assertThat(completedJob.path("retryable").asBoolean()).isFalse();
        assertThat(completedJob.path("minioObjectKey").isMissingNode()).isTrue();
    }

    @Test
    void failedJobCanBeRetriedThroughSharedSeam() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        byte[] trackedPdf = trackedPdfBytes();
        stubPutObjectSuccess();
        when(minioClient.getObject(any()))
                .thenReturn(getObjectResponse(new byte[0]))
                .thenReturn(getObjectResponse(trackedPdf));

        var uploadResponse = readJson(mockMvc.perform(multipart("/api/admin/knowledge/ingestion/upload")
                        .file(new MockMultipartFile("file", "retryable.pdf", "application/pdf", trackedPdf))
                        .param("bookTitle", "Retry Book")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.jobId").isNotEmpty())
                .andReturn());

        var jobId = UUID.fromString(uploadResponse.path("jobId").asText());
        var failedJob = awaitIngestionJobStatus(superAdmin.accessToken(), jobId, "FAILED");
        assertThat(failedJob.path("retryable").asBoolean()).isTrue();
        assertThat(failedJob.path("errorMessage").asText()).contains("PARSE").contains("0 字符");

        mockMvc.perform(post("/api/admin/knowledge/ingestion/jobs/{jobId}/retry", jobId)
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.jobId").value(jobId.toString()))
                .andExpect(jsonPath("$.status").isNotEmpty())
                .andExpect(jsonPath("$.updatedAt").isNotEmpty());

        var completedJob = awaitIngestionJobStatus(superAdmin.accessToken(), jobId, "COMPLETED");
        assertThat(completedJob.path("status").asText()).isEqualTo("COMPLETED");
        assertThat(completedJob.path("retryable").asBoolean()).isFalse();
    }

    @Test
    void uploadFailureReturnsFailedJobEnvelope() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        when(minioClient.putObject(any())).thenThrow(new RuntimeException("minio down"));

        var failure = readJson(mockMvc.perform(multipart("/api/admin/knowledge/ingestion/upload")
                        .file(new MockMultipartFile("file", "broken.pdf", "application/pdf", trackedPdfBytes()))
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.code").value("knowledge_ingestion_dispatch_failed"))
                .andExpect(jsonPath("$.details.jobId").isNotEmpty())
                .andExpect(jsonPath("$.details.status").value("FAILED"))
                .andExpect(jsonPath("$.details.errorMessage", containsString("UPLOAD")))
                .andExpect(jsonPath("$.details.errorMessage", containsString("minio down")))
                .andExpect(jsonPath("$.details.canRetry").value(true))
                .andReturn());

        var jobId = UUID.fromString(failure.path("details").path("jobId").asText());
        assertThat(jdbcTemplate.queryForObject(
                "select status from ingestion_jobs where id = ?",
                String.class,
                jobId
        )).isEqualTo("FAILED");
    }

    @Test
    void uploadValidationAndAuthorizationFailuresStayExplicit() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        byte[] trackedPdf = trackedPdfBytes();

        mockMvc.perform(multipart("/api/admin/knowledge/ingestion/upload")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_knowledge_ingestion_file"));

        mockMvc.perform(multipart("/api/admin/knowledge/ingestion/upload")
                        .file(new MockMultipartFile("file", "empty.pdf", "application/pdf", new byte[0]))
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_knowledge_ingestion_file"));

        mockMvc.perform(multipart("/api/admin/knowledge/ingestion/upload")
                        .file(new MockMultipartFile("file", "knowledge-upload.pdf", "application/pdf", trackedPdf)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("admin_authentication_required"));

        createRole(superAdmin.accessToken(), "rag_reader_only", List.of(AdminPermissionCatalog.RAG_READ));
        createAdmin(superAdmin.accessToken(), "rag_reader", "RAG Reader", "Reader123!", "rag_reader_only");
        var readOnlyAdmin = login("rag_reader", "Reader123!");

        mockMvc.perform(post("/api/admin/knowledge/ingestion/jobs/{jobId}/retry", UUID.randomUUID())
                        .header(HttpHeaders.AUTHORIZATION, bearer(readOnlyAdmin.accessToken())))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("forbidden"));

        mockMvc.perform(post("/api/admin/knowledge/ingestion/jobs/{jobId}/retry", "not-a-uuid")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("invalid_knowledge_ingestion_job_id"));
    }

    @Test
    void retryRejectsNonFailedJobsWith409AndTruthfulState() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        var completedJobId = UUID.fromString("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb");
        seedIngestionJob(
                completedJobId,
                "done.pdf",
                "ingestion/private/done.pdf",
                "COMPLETED",
                3,
                null,
                Instant.parse("2026-04-24T00:00:00Z"),
                Instant.parse("2026-04-24T00:01:00Z")
        );

        mockMvc.perform(post("/api/admin/knowledge/ingestion/jobs/{jobId}/retry", completedJobId)
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("knowledge_ingestion_retry_invalid_state"))
                .andExpect(jsonPath("$.details.jobId").value(completedJobId.toString()))
                .andExpect(jsonPath("$.details.status").value("COMPLETED"))
                .andExpect(jsonPath("$.details.canRetry").value(false));
    }

    private void createRole(String accessToken, String roleCode, List<String> permissionCodes) throws Exception {
        var payload = objectMapper.writeValueAsString(new RolePayload(roleCode, "Role " + roleCode, permissionCodes));
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
                                  \"username\": \"%s\",
                                  \"displayName\": \"%s\",
                                  \"password\": \"%s\",
                                  \"roleCodes\": [\"%s\"]
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
                                {\"username\":\"%s\",\"password\":\"%s\"}
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

    private JsonNode awaitIngestionJobStatus(String accessToken, UUID jobId, String expectedStatus) throws Exception {
        long deadline = System.currentTimeMillis() + 10_000L;
        JsonNode lastSeen = null;
        while (System.currentTimeMillis() < deadline) {
            lastSeen = readJson(mockMvc.perform(get("/api/admin/knowledge/ingestion/jobs/{jobId}", jobId)
                            .header(HttpHeaders.AUTHORIZATION, bearer(accessToken)))
                    .andExpect(status().isOk())
                    .andReturn());
            if (expectedStatus.equals(lastSeen.path("status").asText())) {
                return lastSeen;
            }
            Thread.sleep(100L);
        }
        throw new AssertionError("Timed out waiting for job %s to reach %s; last=%s"
                .formatted(jobId, expectedStatus, lastSeen == null ? "<none>" : lastSeen.toPrettyString()));
    }

    private void stubPutObjectSuccess() throws Exception {
        when(minioClient.putObject(any())).thenReturn(
                new ObjectWriteResponse(null, "babytalk", null, "ingestion/test", null, null));
    }

    private GetObjectResponse getObjectResponse(byte[] payload) {
        return new GetObjectResponse(
                Headers.of(),
                "test-bucket",
                null,
                "ingestion/test",
                new ByteArrayInputStream(payload)
        );
    }

    private byte[] trackedPdfBytes() throws Exception {
        try (var inputStream = new ClassPathResource("knowledge-upload.pdf").getInputStream()) {
            return inputStream.readAllBytes();
        }
    }

    private void seedIngestionJob(
            UUID jobId,
            String originalFilename,
            String minioObjectKey,
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
                minioObjectKey,
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
            String description,
            String sourceABook,
            String sourceBBook,
            String agentReviewResult,
            String adminNotes,
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
        seedRelationship(relationshipAId, sourceEntityId, targetEntityId, sourceABook, "context-a");
        seedRelationship(relationshipBId, sourceEntityId, targetEntityId, sourceBBook, "context-b");

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
                sourceABook,
                sourceBBook,
                description,
                status,
                agentReviewResult,
                adminNotes,
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

    private void seedNotification(
            UUID notificationId,
            UUID contradictionId,
            String notificationType,
            String message,
            boolean isRead,
            Instant createdAt
    ) {
        jdbcTemplate.update(
                """
                insert into kg_admin_notifications (
                    id,
                    contradiction_id,
                    notification_type,
                    message,
                    is_read,
                    created_at
                ) values (?, ?, ?, ?, ?, ?)
                """,
                notificationId,
                contradictionId,
                notificationType,
                message,
                isRead,
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
