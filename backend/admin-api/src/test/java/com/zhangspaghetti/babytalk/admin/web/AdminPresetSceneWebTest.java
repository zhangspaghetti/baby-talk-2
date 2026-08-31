package com.zhangspaghetti.babytalk.admin.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import com.zhangspaghetti.babytalk.admin.auth.AdminAuthService;
import com.zhangspaghetti.babytalk.admin.rbac.AdminPermissionCatalog;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.List;
import java.util.Objects;
import java.util.concurrent.Callable;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.AfterEach;
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
class AdminPresetSceneWebTest {

    private static final AtomicInteger TEST_SEQUENCE = new AtomicInteger();
    private static final long UPDATE_PAUSE_ADVISORY_KEY = 910001L;
    private static final long CREATE_PAUSE_ADVISORY_KEY = 910002L;
    private static final long ROLLBACK_PAUSE_ADVISORY_KEY = 910003L;

    @SuppressWarnings("resource")
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>(
            DockerImageName.parse("pgvector/pgvector:pg17")
                    .asCompatibleSubstituteFor("postgres"))
            .withDatabaseName("babytalk_admin_preset_scene_web_test")
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

    private int testSequence;

    @BeforeEach
    void resetTables() {
        testSequence = TEST_SEQUENCE.incrementAndGet();
        jdbcTemplate.update("delete from practice_preset_scene_audit");
        jdbcTemplate.update("delete from practice_preset_scene_versions where state = 'draft'");
        jdbcTemplate.update(
                """
                update practice_activities a
                set current_published_version_id = v.version_id
                from practice_preset_scene_versions v
                where a.slug = 'bath_time'
                  and v.activity_id = a.id
                  and v.state = 'published'
                  and v.version = 1
                """);
        jdbcTemplate.update("delete from admin_refresh_tokens");
        jdbcTemplate.update("delete from admin_principal_roles");
        jdbcTemplate.update("delete from admin_role_permissions");
        jdbcTemplate.update("delete from admin_roles");
        jdbcTemplate.update("delete from account_sessions");
        jdbcTemplate.update("delete from accounts");
        adminAuthService.seedBootstrapPrincipalIfMissing();
    }

    @AfterEach
    void removeAuditFailureTrigger() {
        jdbcTemplate.execute("drop trigger if exists test_fail_preset_scene_audit on practice_preset_scene_audit");
        jdbcTemplate.execute("drop function if exists test_fail_preset_scene_audit()");
        jdbcTemplate.execute(
                "drop trigger if exists test_pause_preset_scene_draft_update on practice_preset_scene_versions");
        jdbcTemplate.execute("drop function if exists test_pause_preset_scene_draft_update()");
        jdbcTemplate.execute(
                "drop trigger if exists test_pause_preset_scene_draft_create on practice_preset_scene_versions");
        jdbcTemplate.execute("drop function if exists test_pause_preset_scene_draft_create()");
        jdbcTemplate.execute(
                "drop trigger if exists test_pause_preset_scene_rollback_insert on practice_preset_scene_versions");
        jdbcTemplate.execute("drop function if exists test_pause_preset_scene_rollback_insert()");
    }

    @Test
    void readPermissionListsPublishedScenesAndDoesNotExposeGenerationBrief() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");

        mockMvc.perform(get("/api/admin/v1/practice/preset-scenes")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(5)))
                .andExpect(jsonPath("$[*].presetSceneId", hasItem("bath_time")))
                .andExpect(jsonPath("$[0].generationBrief").doesNotExist());
    }

    @Test
    void readOnlyAdminCannotCreateDraftAndWriterCannotPublish() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        var readerRole = testRole("reader");
        var readerUsername = testUsername("reader");
        createRole(superAdmin.accessToken(), readerRole, AdminPermissionCatalog.PRACTICE_READ);
        createAdmin(superAdmin.accessToken(), readerUsername, "Practice Reader", "Reader123!", readerRole);
        var reader = login(readerUsername, "Reader123!");

        mockMvc.perform(post("/api/admin/v1/practice/preset-scenes/{id}/draft", "bath_time")
                        .header(HttpHeaders.AUTHORIZATION, bearer(reader.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validDraftJson()))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("forbidden"));

        var writerRole = testRole("writer");
        var writerUsername = testUsername("writer");
        createRole(superAdmin.accessToken(), writerRole, AdminPermissionCatalog.PRACTICE_READ,
                AdminPermissionCatalog.PRACTICE_WRITE);
        createAdmin(superAdmin.accessToken(), writerUsername, "Practice Writer", "Writer123!", writerRole);
        var writer = login(writerUsername, "Writer123!");
        createDraft(writer.accessToken());

        mockMvc.perform(post("/api/admin/v1/practice/preset-scenes/{id}/publish", "bath_time")
                        .header(HttpHeaders.AUTHORIZATION, bearer(writer.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"lockVersion\":0}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("forbidden"));
    }

    @Test
    void draftRejectsControlCharactersAtFieldBoundaries() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");

        var leadingControl = validDraftJson()
                .replace("\"title\": \"洗澡时间（草稿）\"", "\"title\": \"\\n洗澡时间\"");
        mockMvc.perform(post("/api/admin/v1/practice/preset-scenes/{id}/draft", "bath_time")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(leadingControl))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("validation_failed"));

        var trailingControl = validDraftJson()
                .replace("\"coachTip\": \"草稿提示\"", "\"coachTip\": \"草稿提示\\t\"");
        mockMvc.perform(post("/api/admin/v1/practice/preset-scenes/{id}/draft", "bath_time")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(trailingControl))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("validation_failed"));
    }

    @Test
    void rollbackZeroReturnsValidationContract() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");

        mockMvc.perform(post("/api/admin/v1/practice/preset-scenes/{id}/rollback/{version}", "bath_time", 0)
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("validation_failed"));
    }

    @Test
    void createAuditConstraintFailurePropagatesAndRollsBackDraft() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        installConstraintAuditFailureTrigger();

        mockMvc.perform(post("/api/admin/v1/practice/preset-scenes/{id}/draft", "bath_time")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validDraftJson()))
                .andExpect(status().isInternalServerError());

        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_versions where state = 'draft' "
                        + "and activity_id = (select id from practice_activities where slug = 'bath_time')",
                Integer.class)).isZero();
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_audit where action = 'create_draft'",
                Integer.class)).isZero();
    }

    @Test
    void writerUpdatesDraftWithOptimisticLockAndPublisherPublishesAsAuthenticatedPrincipal() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        var writerRole = testRole("writer");
        var writerUsername = testUsername("writer");
        createRole(superAdmin.accessToken(), writerRole, AdminPermissionCatalog.PRACTICE_READ,
                AdminPermissionCatalog.PRACTICE_WRITE);
        createAdmin(superAdmin.accessToken(), writerUsername, "Practice Writer", "Writer123!", writerRole);
        var writer = login(writerUsername, "Writer123!");
        var publisherRole = testRole("publisher");
        var publisherUsername = testUsername("publisher");
        createRole(superAdmin.accessToken(), publisherRole, AdminPermissionCatalog.PRACTICE_READ,
                AdminPermissionCatalog.PRACTICE_WRITE, AdminPermissionCatalog.PRACTICE_PUBLISH);
        createAdmin(superAdmin.accessToken(), publisherUsername, "Practice Publisher", "Publisher123!", publisherRole);
        var publisher = login(publisherUsername, "Publisher123!");

        createDraft(writer.accessToken());
        assertThat(jdbcTemplate.queryForObject(
                "select admin_principal_id from practice_preset_scene_audit where action = 'create_draft'",
                String.class)).isEqualTo(writer.principalId());
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_audit where action = 'create_draft'",
                Integer.class)).isEqualTo(1);

        mockMvc.perform(put("/api/admin/v1/practice/preset-scenes/{id}/draft", "bath_time")
                        .header(HttpHeaders.AUTHORIZATION, bearer(writer.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validDraftJson(0, "洗澡时间（更新）")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.lockVersion").value(1));
        assertThat(jdbcTemplate.queryForObject(
                "select admin_principal_id from practice_preset_scene_audit where action = 'update_draft'",
                String.class)).isEqualTo(writer.principalId());
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_audit where action = 'update_draft'",
                Integer.class)).isEqualTo(1);

        mockMvc.perform(put("/api/admin/v1/practice/preset-scenes/{id}/draft", "bath_time")
                        .header(HttpHeaders.AUTHORIZATION, bearer(writer.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validDraftJson(0, "过期草稿")))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("practice_draft_version_conflict"));

        var expectedPublishedVersion = nextPublishedVersion();
        mockMvc.perform(post("/api/admin/v1/practice/preset-scenes/{id}/publish", "bath_time")
                        .header(HttpHeaders.AUTHORIZATION, bearer(publisher.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"lockVersion\":1,\"adminPrincipalId\":\"forged\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.version").value(expectedPublishedVersion))
                .andExpect(jsonPath("$.title").value("洗澡时间（更新）"));

        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_audit where action = 'publish'",
                Integer.class)).isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject(
                "select admin_principal_id from practice_preset_scene_audit where action = 'publish'",
                String.class)).isEqualTo(publisher.principalId());
        createDraft(publisher.accessToken(), "禁用版本", false);
        mockMvc.perform(post("/api/admin/v1/practice/preset-scenes/{id}/publish", "bath_time")
                        .header(HttpHeaders.AUTHORIZATION, bearer(publisher.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"lockVersion\":0}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.enabled").value(false));
        assertThat(jdbcTemplate.queryForObject(
                "select admin_principal_id from practice_preset_scene_audit where action = 'disable'",
                String.class)).isEqualTo(publisher.principalId());
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_audit where action = 'disable'",
                Integer.class)).isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject(
                "select title_zh from practice_preset_scene_versions where state = 'published' and version = 1 "
                        + "and activity_id = (select id from practice_activities where slug = 'bath_time')",
                String.class)).isEqualTo("洗澡时间");
    }

    @Test
    void invalidBriefCannotPublishAndLeavesCurrentVersionUnchanged() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        createDraft(superAdmin.accessToken());
        jdbcTemplate.update(
                "update practice_preset_scene_versions set generation_brief = ? where state = 'draft' "
                        + "and activity_id = (select id from practice_activities where slug = 'bath_time')",
                "请拨打 13800138000 获取帮助");

        mockMvc.perform(post("/api/admin/v1/practice/preset-scenes/{id}/publish", "bath_time")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"lockVersion\":0}"))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("practice_publish_validation_failed"));

        assertThat(currentPublishedVersion()).isEqualTo(1);
    }

    @Test
    void rollbackCreatesNextPublishedVersionAndOnlyOneRollbackAudit() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        createDraft(superAdmin.accessToken(), "洗澡时间（新版本）");
        var expectedPublishedVersion = nextPublishedVersion();
        publish(superAdmin.accessToken(), 0);
        assertThat(currentPublishedVersion()).isEqualTo(expectedPublishedVersion);
        var expectedRollbackVersion = nextPublishedVersion();

        mockMvc.perform(post("/api/admin/v1/practice/preset-scenes/{id}/rollback/{version}", "bath_time", 1)
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.version").value(expectedRollbackVersion))
                .andExpect(jsonPath("$.title").value("洗澡时间"));

        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_audit where action = 'rollback'",
                Integer.class)).isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_audit where action = 'publish'",
                Integer.class)).isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject(
                "select admin_principal_id from practice_preset_scene_audit where action = 'rollback'",
                String.class)).isEqualTo(superAdmin.principalId());
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_versions where state = 'published' and version = 1 "
                        + "and activity_id = (select id from practice_activities where slug = 'bath_time')",
                Integer.class)).isEqualTo(1);
    }

    @Test
    void auditFailureRollsBackDraftPointerAndPublishedStateInRealDatabase() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        createDraft(superAdmin.accessToken());
        installAuditFailureTrigger();

        mockMvc.perform(put("/api/admin/v1/practice/preset-scenes/{id}/draft", "bath_time")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validDraftJson(0, "不应持久化")))
                .andExpect(status().isInternalServerError());
        assertThat(jdbcTemplate.queryForObject(
                "select title_zh from practice_preset_scene_versions where state = 'draft' "
                        + "and activity_id = (select id from practice_activities where slug = 'bath_time')",
                String.class)).isEqualTo("洗澡时间（草稿）");
        assertThat(jdbcTemplate.queryForObject(
                "select lock_version from practice_preset_scene_versions where state = 'draft' "
                        + "and activity_id = (select id from practice_activities where slug = 'bath_time')",
                Integer.class)).isZero();

        mockMvc.perform(post("/api/admin/v1/practice/preset-scenes/{id}/publish", "bath_time")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"lockVersion\":0}"))
                .andExpect(status().isInternalServerError());
        assertThat(currentPublishedVersion()).isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_versions where state = 'draft' "
                        + "and activity_id = (select id from practice_activities where slug = 'bath_time')",
                Integer.class)).isEqualTo(1);

        jdbcTemplate.update("delete from practice_preset_scene_audit");
        jdbcTemplate.update(
                "delete from practice_preset_scene_versions where state = 'draft' "
                        + "and activity_id = (select id from practice_activities where slug = 'bath_time')");
        var historyBeforeRollback = publishedHistory();
        var publishedCountBeforeRollback = publishedCount();
        mockMvc.perform(post("/api/admin/v1/practice/preset-scenes/{id}/rollback/{version}", "bath_time", 1)
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                .andExpect(status().isInternalServerError());
        assertThat(currentPublishedVersion()).isEqualTo(1);
        assertThat(publishedCount()).isEqualTo(publishedCountBeforeRollback);
        assertThat(publishedHistory()).isEqualTo(historyBeforeRollback);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_audit",
                Integer.class)).isZero();
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_versions where state = 'draft'",
                Integer.class)).isZero();
    }

    @Test
    void concurrentCreateSameSceneAllowsOnlyOneDraft() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        var results = runConcurrently(() -> mockMvc.perform(
                post("/api/admin/v1/practice/preset-scenes/{id}/draft", "bath_time")
                        .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validDraftJson()))
                .andReturn());

        assertThat(statuses(results)).containsExactlyInAnyOrder(201, 409);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_versions where state = 'draft' "
                        + "and activity_id = (select id from practice_activities where slug = 'bath_time')",
                Integer.class)).isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_audit where action = 'create_draft'",
                Integer.class)).isEqualTo(1);
    }

    @Test
    void concurrentUpdateSameLockVersionAllowsOnlyOneUpdate() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        createDraft(superAdmin.accessToken());
        var results = runConcurrently(
                () -> mockMvc.perform(put("/api/admin/v1/practice/preset-scenes/{id}/draft", "bath_time")
                                .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(validDraftJson(0, "并发更新")))
                        .andReturn());

        assertThat(statuses(results)).containsExactlyInAnyOrder(200, 409);
        assertThat(jdbcTemplate.queryForObject(
                "select lock_version from practice_preset_scene_versions where state = 'draft' "
                        + "and activity_id = (select id from practice_activities where slug = 'bath_time')",
                Integer.class)).isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_audit where action = 'update_draft'",
                Integer.class)).isEqualTo(1);
    }

    @Test
    void concurrentPublishSameDraftCreatesOneMonotonicVersion() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        createDraft(superAdmin.accessToken());
        var nextVersion = nextPublishedVersion();
        var results = runConcurrently(
                () -> mockMvc.perform(post("/api/admin/v1/practice/preset-scenes/{id}/publish", "bath_time")
                                .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("{\"lockVersion\":0}"))
                        .andReturn());

        assertThat(statuses(results)).containsExactlyInAnyOrder(200, 409);
        assertThat(publishedCount()).isEqualTo(nextVersion);
        assertThat(currentPublishedVersion()).isEqualTo(nextVersion);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_audit where action = 'publish'",
                Integer.class)).isEqualTo(1);
    }

    @Test
    void concurrentDraftUpdateAndPublishUseSameActivityThenDraftLockOrder() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        createDraft(superAdmin.accessToken());
        installDraftUpdatePauseTrigger(UPDATE_PAUSE_ADVISORY_KEY);
        var publishedCountBefore = publishedCount();
        var nextVersion = nextPublishedVersion();

        ExecutorService executor = Executors.newFixedThreadPool(2);
        Future<MvcResult> update;
        Future<MvcResult> publish;
        try (var gate = holdAdvisoryXactLock(UPDATE_PAUSE_ADVISORY_KEY)) {
            update = executor.submit(() -> mockMvc.perform(
                    put("/api/admin/v1/practice/preset-scenes/{id}/draft", "bath_time")
                            .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(validDraftJson(0, "交叉更新")))
                    .andReturn());
            awaitAdvisoryWait(UPDATE_PAUSE_ADVISORY_KEY);
            publish = executor.submit(() -> mockMvc.perform(
                    post("/api/admin/v1/practice/preset-scenes/{id}/publish", "bath_time")
                            .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("{\"lockVersion\":0}"))
                    .andReturn());
            awaitTransactionLockWait("from practice_activities");
            gate.rollback();

            var results = List.of(
                    update.get(30, TimeUnit.SECONDS),
                    publish.get(30, TimeUnit.SECONDS));

            assertThat(statuses(results)).containsExactlyInAnyOrder(200, 409);
        } finally {
            executor.shutdownNow();
            executor.awaitTermination(10, TimeUnit.SECONDS);
        }

        var updateAudits = jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_audit where action = 'update_draft'",
                Integer.class);
        var publishAudits = jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_audit where action = 'publish'",
                Integer.class);
        assertThat(updateAudits + publishAudits).isEqualTo(1);
        assertThat(publishedCount()).isEqualTo(publishedCountBefore + publishAudits);
        assertThat(currentPublishedVersion()).isEqualTo(publishAudits == 1 ? nextVersion : 1);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_versions where state = 'draft' "
                        + "and activity_id = (select id from practice_activities where slug = 'bath_time')",
                Integer.class)).isEqualTo(publishAudits == 1 ? 0 : 1);
    }

    @Test
    void concurrentCreateWinningRollbackReturnsConflictWithoutNewVersion() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        installDraftCreatePauseTrigger(CREATE_PAUSE_ADVISORY_KEY);
        var publishedCountBefore = publishedCount();
        var historyBefore = publishedHistory();

        ExecutorService executor = Executors.newFixedThreadPool(2);
        Future<MvcResult> create;
        Future<MvcResult> rollback;
        try (var gate = holdAdvisoryXactLock(CREATE_PAUSE_ADVISORY_KEY)) {
            create = executor.submit(() -> mockMvc.perform(
                    post("/api/admin/v1/practice/preset-scenes/{id}/draft", "bath_time")
                            .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(validDraftJson()))
                    .andReturn());
            awaitAdvisoryWait(CREATE_PAUSE_ADVISORY_KEY);
            rollback = executor.submit(() -> mockMvc.perform(
                    post("/api/admin/v1/practice/preset-scenes/{id}/rollback/{version}", "bath_time", 1)
                            .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                    .andReturn());
            awaitTransactionLockWait("from practice_activities");
            gate.rollback();

            var results = List.of(
                    create.get(30, TimeUnit.SECONDS),
                    rollback.get(30, TimeUnit.SECONDS));

            assertThat(statuses(results)).containsExactly(201, 409);
        } finally {
            executor.shutdownNow();
            executor.awaitTermination(10, TimeUnit.SECONDS);
        }

        assertThat(currentPublishedVersion()).isEqualTo(1);
        assertThat(publishedCount()).isEqualTo(publishedCountBefore);
        assertThat(publishedHistory()).isEqualTo(historyBefore);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_versions where state = 'draft' "
                        + "and activity_id = (select id from practice_activities where slug = 'bath_time')",
                Integer.class)).isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_audit where action = 'create_draft'",
                Integer.class)).isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_audit where action = 'rollback'",
                Integer.class)).isZero();
    }

    @Test
    void concurrentRollbackWinningCreateLeavesPublishedVersionAndLaterDraft() throws Exception {
        var superAdmin = login("super_admin", "SuperAdmin123!");
        installRollbackPauseTrigger(ROLLBACK_PAUSE_ADVISORY_KEY);
        var publishedCountBefore = publishedCount();
        var nextVersion = nextPublishedVersion();

        ExecutorService executor = Executors.newFixedThreadPool(2);
        Future<MvcResult> rollback;
        Future<MvcResult> create;
        try (var gate = holdAdvisoryXactLock(ROLLBACK_PAUSE_ADVISORY_KEY)) {
            rollback = executor.submit(() -> mockMvc.perform(
                    post("/api/admin/v1/practice/preset-scenes/{id}/rollback/{version}", "bath_time", 1)
                            .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken())))
                    .andReturn());
            awaitAdvisoryWait(ROLLBACK_PAUSE_ADVISORY_KEY);
            create = executor.submit(() -> mockMvc.perform(
                    post("/api/admin/v1/practice/preset-scenes/{id}/draft", "bath_time")
                            .header(HttpHeaders.AUTHORIZATION, bearer(superAdmin.accessToken()))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(validDraftJson()))
                    .andReturn());
            awaitTransactionLockWait("from practice_activities");
            gate.rollback();

            var results = List.of(
                    rollback.get(30, TimeUnit.SECONDS),
                    create.get(30, TimeUnit.SECONDS));

            assertThat(statuses(results)).containsExactly(200, 201);
        } finally {
            executor.shutdownNow();
            executor.awaitTermination(10, TimeUnit.SECONDS);
        }

        assertThat(currentPublishedVersion()).isEqualTo(nextVersion);
        assertThat(publishedCount()).isEqualTo(publishedCountBefore + 1);
        assertThat(publishedHistory()).contains(nextVersion + ":洗澡时间");
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_versions where state = 'draft' "
                        + "and activity_id = (select id from practice_activities where slug = 'bath_time')",
                Integer.class)).isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_audit where action = 'rollback'",
                Integer.class)).isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_audit where action = 'create_draft'",
                Integer.class)).isEqualTo(1);
    }

    private void installAuditFailureTrigger() {
        jdbcTemplate.execute(
                """
                create or replace function test_fail_preset_scene_audit()
                returns trigger language plpgsql as $$
                begin
                    raise exception 'forced preset scene audit failure';
                end;
                $$
                """);
        jdbcTemplate.execute(
                "create trigger test_fail_preset_scene_audit before insert on practice_preset_scene_audit "
                        + "for each row execute function test_fail_preset_scene_audit()");
    }

    private void installConstraintAuditFailureTrigger() {
        jdbcTemplate.execute(
                """
                create or replace function test_fail_preset_scene_audit()
                returns trigger language plpgsql as $$
                begin
                    raise exception using errcode = '23514', message = 'forced preset scene audit check failure';
                end;
                $$
                """);
        jdbcTemplate.execute(
                "create trigger test_fail_preset_scene_audit before insert on practice_preset_scene_audit "
                        + "for each row execute function test_fail_preset_scene_audit()");
    }

    private void installDraftUpdatePauseTrigger(long advisoryKey) {
        jdbcTemplate.execute(
                """
                create or replace function test_pause_preset_scene_draft_update()
                returns trigger language plpgsql as $$
                begin
                    if old.state = 'draft' and new.state = 'draft' then
                        perform pg_advisory_xact_lock(%d::bigint);
                        perform 1 from practice_activities where id = old.activity_id for update;
                    end if;
                    return new;
                end;
                $$
                """.formatted(advisoryKey));
        jdbcTemplate.execute(
                "create trigger test_pause_preset_scene_draft_update before update on "
                        + "practice_preset_scene_versions for each row execute function "
                        + "test_pause_preset_scene_draft_update()");
    }

    private void installDraftCreatePauseTrigger(long advisoryKey) {
        jdbcTemplate.execute(
                """
                create or replace function test_pause_preset_scene_draft_create()
                returns trigger language plpgsql as $$
                begin
                    if new.state = 'draft' then
                        perform pg_advisory_xact_lock(%d::bigint);
                        perform 1 from practice_activities where id = new.activity_id for update;
                    end if;
                    return new;
                end;
                $$
                """.formatted(advisoryKey));
        jdbcTemplate.execute(
                "create trigger test_pause_preset_scene_draft_create before insert on "
                        + "practice_preset_scene_versions for each row execute function "
                        + "test_pause_preset_scene_draft_create()");
    }

    private void installRollbackPauseTrigger(long advisoryKey) {
        jdbcTemplate.execute(
                """
                create or replace function test_pause_preset_scene_rollback_insert()
                returns trigger language plpgsql as $$
                begin
                    if new.state = 'published' and new.version > 1 then
                        perform pg_advisory_xact_lock(%d::bigint);
                    end if;
                    return new;
                end;
                $$
                """.formatted(advisoryKey));
        jdbcTemplate.execute(
                "create trigger test_pause_preset_scene_rollback_insert before insert on "
                        + "practice_preset_scene_versions for each row execute function "
                        + "test_pause_preset_scene_rollback_insert()");
    }

    private Connection holdAdvisoryXactLock(long advisoryKey) throws SQLException {
        var dataSource = Objects.requireNonNull(jdbcTemplate.getDataSource());
        var connection = dataSource.getConnection();
        connection.setAutoCommit(false);
        try (var statement = connection.prepareStatement(
                "select pg_advisory_xact_lock(?::bigint)")) {
            statement.setLong(1, advisoryKey);
            statement.execute();
        }
        return connection;
    }

    private void awaitAdvisoryWait(long advisoryKey) throws InterruptedException {
        awaitLock(
                "select count(*) from pg_locks "
                        + "where locktype = 'advisory' and classid = 0 and objid = ? and not granted",
                advisoryKey,
                "advisory lock " + advisoryKey);
    }

    private void awaitTransactionLockWait(String queryFragment) throws InterruptedException {
        awaitLock(
                "select count(*) from pg_stat_activity "
                        + "where wait_event_type = 'Lock' and wait_event = 'transactionid' "
                        + "and query like ?",
                "%" + queryFragment + "%",
                "transaction lock for query containing " + queryFragment);
    }

    private void awaitLock(String sql, Object argument, String description) throws InterruptedException {
        var deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(10);
        while (System.nanoTime() < deadline) {
            var waiting = jdbcTemplate.queryForObject(sql, Integer.class, argument);
            if (waiting != null && waiting > 0) {
                return;
            }
            Thread.sleep(25L);
        }
        throw new AssertionError("Timed out waiting for " + description);
    }

    private String testRole(String suffix) {
        return "practice_" + suffix + "_" + testSequence;
    }

    private String testUsername(String suffix) {
        return "practice_" + suffix + "_" + testSequence;
    }

    private void createDraft(String accessToken) throws Exception {
        createDraft(accessToken, "洗澡时间（草稿）", true);
    }

    private void createDraft(String accessToken, String title) throws Exception {
        createDraft(accessToken, title, true);
    }

    private void createDraft(String accessToken, String title, boolean enabled) throws Exception {
        mockMvc.perform(post("/api/admin/v1/practice/preset-scenes/{id}/draft", "bath_time")
                        .header(HttpHeaders.AUTHORIZATION, bearer(accessToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(validDraftJson(0, title, enabled)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.lockVersion").value(0));
    }

    private void publish(String accessToken, int lockVersion) throws Exception {
        mockMvc.perform(post("/api/admin/v1/practice/preset-scenes/{id}/publish", "bath_time")
                        .header(HttpHeaders.AUTHORIZATION, bearer(accessToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"lockVersion\":%d}".formatted(lockVersion)))
                .andExpect(status().isOk());
    }

    private int nextPublishedVersion() {
        return jdbcTemplate.queryForObject(
                "select coalesce(max(version), 0) + 1 from practice_preset_scene_versions "
                        + "where state = 'published' and activity_id = "
                        + "(select id from practice_activities where slug = 'bath_time')",
                Integer.class);
    }

    private int currentPublishedVersion() {
        return jdbcTemplate.queryForObject(
                "select v.version from practice_activities a "
                        + "join practice_preset_scene_versions v on v.version_id = a.current_published_version_id "
                        + "where a.slug = 'bath_time'",
                Integer.class);
    }

    private int publishedCount() {
        return jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_versions where state = 'published' "
                        + "and activity_id = (select id from practice_activities where slug = 'bath_time')",
                Integer.class);
    }

    private List<String> publishedHistory() {
        return jdbcTemplate.query(
                "select version, title_zh from practice_preset_scene_versions where state = 'published' "
                        + "and activity_id = (select id from practice_activities where slug = 'bath_time') "
                        + "order by version",
                (resultSet, rowNum) -> resultSet.getInt("version") + ":" + resultSet.getString("title_zh"));
    }

    private List<Integer> statuses(List<MvcResult> results) {
        return results.stream()
                .map(result -> result.getResponse().getStatus())
                .toList();
    }

    private List<MvcResult> runConcurrently(Callable<MvcResult> request) throws Exception {
        return runConcurrently(request, request);
    }

    private List<MvcResult> runConcurrently(
            Callable<MvcResult> firstRequest,
            Callable<MvcResult> secondRequest
    ) throws Exception {
        ExecutorService executor = Executors.newFixedThreadPool(2);
        var barrier = new CyclicBarrier(2);
        Callable<MvcResult> firstSynchronizedRequest = () -> {
            barrier.await(10, TimeUnit.SECONDS);
            return firstRequest.call();
        };
        Callable<MvcResult> secondSynchronizedRequest = () -> {
            barrier.await(10, TimeUnit.SECONDS);
            return secondRequest.call();
        };
        try {
            Future<MvcResult> first = executor.submit(firstSynchronizedRequest);
            Future<MvcResult> second = executor.submit(secondSynchronizedRequest);
            return List.of(first.get(30, TimeUnit.SECONDS), second.get(30, TimeUnit.SECONDS));
        } finally {
            executor.shutdownNow();
            executor.awaitTermination(10, TimeUnit.SECONDS);
        }
    }

    private String validDraftJson() {
        return validDraftJson(0, "洗澡时间（草稿）");
    }

    private String validDraftJson(int lockVersion, String title) {
        return validDraftJson(lockVersion, title, true);
    }

    private String validDraftJson(int lockVersion, String title, boolean enabled) {
        return """
                {
                  "title": "%s",
                  "summary": "草稿摘要",
                  "sceneTag": "Bath time",
                  "coachTip": "草稿提示",
                  "sortOrder": 1,
                  "generationBrief": "围绕暖水生成互动。",
                  "enabled": %s,
                  "lockVersion": %d
                }
                """.formatted(title, enabled, lockVersion);
    }

    private void createRole(String accessToken, String roleCode, String... permissionCodes) throws Exception {
        var permissions = String.join(", ", java.util.Arrays.stream(permissionCodes)
                .map(permission -> "\"" + permission + "\"")
                .toList());
        mockMvc.perform(post("/api/admin/roles")
                        .header(HttpHeaders.AUTHORIZATION, bearer(accessToken))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "roleCode": "%s",
                                  "description": "Role %s",
                                  "permissionCodes": [%s]
                                }
                                """.formatted(roleCode, roleCode, permissions)))
                .andExpect(status().isCreated());
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
                .andReturn();
        var json = objectMapper.readTree(response.getResponse().getContentAsString());
        return new CreatedAdmin(json.get("principalId").asText(), json.get("username").asText());
    }

    private TokenView login(String username, String password) throws Exception {
        var response = mockMvc.perform(post("/api/admin/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"username\":\"%s\",\"password\":\"%s\"}"
                                .formatted(username, password)))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode json = objectMapper.readTree(response.getResponse().getContentAsString());
        return new TokenView(
                json.get("accessToken").asText(),
                json.get("admin").get("principalId").asText());
    }

    private String bearer(String accessToken) {
        return "Bearer " + accessToken;
    }

    private record TokenView(String accessToken, String principalId) {
    }

    private record CreatedAdmin(String principalId, String username) {
    }
}
