package com.zhangspaghetti.babytalk.admin.practice;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.admin.rbac.AdminPermissionCatalog;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.function.Supplier;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.support.TransactionTemplate;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

@SpringBootTest(properties = {
        "spring.flyway.enabled=true",
        "spring.flyway.locations=classpath:db/migration",
        "app.auth.sensitive-data-pepper=0123456789abcdef0123456789abcdef",
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
@Transactional
class AdminPresetSceneRepositoryTest {

    @SuppressWarnings("resource")
    static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>(
            DockerImageName.parse("pgvector/pgvector:pg17")
                    .asCompatibleSubstituteFor("postgres"))
            .withDatabaseName("babytalk_admin_preset_scene_repository_test")
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
    private AdminPresetSceneRepository repository;

    @Autowired
    private AdminPermissionCatalog permissionCatalog;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private PlatformTransactionManager transactionManager;

    @BeforeEach
    void removeDraftsAndAudits() {
        jdbcTemplate.update("delete from practice_preset_scene_audit");
        jdbcTemplate.update("delete from practice_preset_scene_versions where state = 'draft'");
    }

    @Test
    void findScenesReturnsPublishedVersionAndOptionalDraftLockVersion() {
        assertThat(permissionCatalog.codes()).contains(
                AdminPermissionCatalog.PRACTICE_READ,
                AdminPermissionCatalog.PRACTICE_WRITE,
                AdminPermissionCatalog.PRACTICE_PUBLISH);

        var bathTime = findSceneSummary("bath_time");

        assertThat(bathTime.publishedVersion()).isEqualTo(1);
        assertThat(bathTime.draftLockVersion()).isNull();

        repository.createDraft(
                "bath_time",
                new AdminPresetSceneRepository.DraftWrite(
                        "洗澡时间（编辑）",
                        "新的摘要",
                        "Bath time",
                        "新的提示",
                        4,
                        "生成新的洗澡互动。",
                        true),
                adminPrincipalId(),
                now());

        var withDraft = findSceneSummary("bath_time");
        assertThat(withDraft.publishedVersion()).isEqualTo(1);
        assertThat(withDraft.draftLockVersion()).isZero();
        assertSafeAuditSummary("create_draft", "洗澡时间（编辑）");
    }

    @Test
    void updateDraftUsesOptimisticLockAndIncrementsLockVersion() {
        var draft = createDraft();

        var updated = repository.updateDraft(
                "bath_time",
                draft.lockVersion(),
                new AdminPresetSceneRepository.DraftWrite(
                        "洗澡时间（更新）",
                        "更新摘要",
                        "Bath time",
                        "更新提示",
                        5,
                        "更新生成文案。",
                        false),
                adminPrincipalId(),
                now());

        assertThat(updated.lockVersion()).isEqualTo(1);
        assertThat(updated.title()).isEqualTo("洗澡时间（更新）");
        assertSafeAuditSummary("update_draft", "洗澡时间（更新）");
        assertThat(repository.updateDraft(
                "bath_time",
                draft.lockVersion(),
                updatedWrite(),
                adminPrincipalId(),
                now())).isNull();
    }

    @Test
    void publishAssignsNextVersionUpdatesPointerAndWritesAudit() {
        var draft = createDraft();

        var published = repository.publish(
                "bath_time",
                draft.lockVersion(),
                adminPrincipalId(),
                now());

        assertThat(published.version()).isEqualTo(2);
        assertThat(repository.findScene("bath_time")).get()
                .extracting(AdminPresetSceneRepository.SceneDetailRow::publishedVersion)
                .isEqualTo(2);
        assertThat(repository.findVersions("bath_time"))
                .extracting(AdminPresetSceneRepository.PublishedRow::version)
                .containsExactly(2, 1);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_audit where action = 'publish'",
                Integer.class)).isEqualTo(1);
        assertSafeAuditSummary("publish", "洗澡时间（草稿）");
    }

    @Test
    void publishDisabledDraftRecordsDisableAudit() {
        var draft = createDraft(false);

        var published = repository.publish(
                "bath_time",
                draft.lockVersion(),
                adminPrincipalId(),
                now());

        assertThat(published.enabled()).isFalse();
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_audit where action = 'disable'",
                Integer.class)).isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_audit where action = 'publish'",
                Integer.class)).isZero();
        assertSafeAuditSummary("disable", "洗澡时间（草稿）");
    }

    @Test
    void copyPublishedToDraftCopiesHistoricalContentAndAuditsRollback() {
        var draft = repository.copyPublishedToDraft(
                "bath_time",
                1,
                adminPrincipalId(),
                now());

        assertThat(draft.title()).isEqualTo("洗澡时间");
        assertThat(draft.generationBrief()).isNotBlank();
        assertThat(repository.findDraftForUpdate("bath_time")).contains(draft);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_audit where action = 'rollback'",
                Integer.class)).isEqualTo(1);
        assertSafeAuditSummary("rollback", "洗澡时间");
    }

    @Test
    void rollbackPublishesNextVersionAndWritesOnlyOneRollbackAudit() {
        var published = repository.rollback(
                "bath_time",
                1,
                adminPrincipalId(),
                now());

        assertThat(published.version()).isEqualTo(2);
        assertThat(published.title()).isEqualTo("洗澡时间");
        assertThat(repository.findScene("bath_time")).get()
                .extracting(AdminPresetSceneRepository.SceneDetailRow::publishedVersion)
                .isEqualTo(2);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_audit where action = 'rollback'",
                Integer.class)).isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_audit where action = 'publish'",
                Integer.class)).isZero();
        assertSafeAuditSummary("rollback", "洗澡时间");
    }

    @Test
    @Transactional(propagation = Propagation.NOT_SUPPORTED)
    void concurrentUpdateAndRollbackUseIndependentTransactionsAndPreserveBothAudits() throws Exception {
        var sceneId = createConcurrentScene();
        var principalId = adminPrincipalId();
        var draft = repository.createDraft(
                sceneId,
                new AdminPresetSceneRepository.DraftWrite(
                        "并发草稿",
                        "并发摘要",
                        "Concurrent",
                        "并发提示",
                        1,
                        "并发生成文案。",
                        true),
                principalId,
                now());
        assertThat(draft).isNotNull();

        var results = runRepositoryConcurrently(
                () -> repository.updateDraft(
                        sceneId,
                        0,
                        new AdminPresetSceneRepository.DraftWrite(
                                "并发更新",
                                "并发更新摘要",
                                "Concurrent",
                                "并发更新提示",
                                2,
                                "并发更新文案。",
                                true),
                        principalId,
                        now()),
                () -> repository.rollback(sceneId, 1, principalId, now()));

        assertThat(results).allSatisfy(result -> assertThat(result.failure()).isNull());
        assertThat(results).anyMatch(result -> result.value() instanceof AdminPresetSceneRepository.PublishedRow);
        assertThat(results).anyMatch(result -> result.value() instanceof AdminPresetSceneRepository.DraftRow);
        var updatedDraft = results.stream()
                .map(RepositoryCallResult::value)
                .filter(AdminPresetSceneRepository.DraftRow.class::isInstance)
                .map(AdminPresetSceneRepository.DraftRow.class::cast)
                .findFirst()
                .orElseThrow();
        var rolledBack = results.stream()
                .map(RepositoryCallResult::value)
                .filter(AdminPresetSceneRepository.PublishedRow.class::isInstance)
                .map(AdminPresetSceneRepository.PublishedRow.class::cast)
                .findFirst()
                .orElseThrow();

        assertThat(updatedDraft.lockVersion()).isEqualTo(1);
        assertThat(rolledBack.version()).isEqualTo(2);
        assertThat(currentPublishedVersion(sceneId)).isEqualTo(2);
        assertThat(repository.findDraft(sceneId)).isPresent()
                .get()
                .extracting(AdminPresetSceneRepository.DraftRow::title)
                .isEqualTo("并发更新");
        assertThat(repository.findVersions(sceneId))
                .extracting(AdminPresetSceneRepository.PublishedRow::version)
                .containsExactly(2, 1);
        assertThat(repository.findVersions(sceneId).get(0).title()).isEqualTo("并发测试");
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_audit where activity_id = "
                        + "(select id from practice_activities where slug = ?) and action = 'update_draft'",
                Integer.class,
                sceneId)).isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from practice_preset_scene_audit where activity_id = "
                        + "(select id from practice_activities where slug = ?) and action = 'rollback'",
                Integer.class,
                sceneId)).isEqualTo(1);
        assertThat(jdbcTemplate.queryForObject(
                "select admin_principal_id from practice_preset_scene_audit where activity_id = "
                        + "(select id from practice_activities where slug = ?) and action = 'update_draft'",
                String.class,
                sceneId)).isEqualTo(principalId);
        assertThat(jdbcTemplate.queryForObject(
                "select admin_principal_id from practice_preset_scene_audit where activity_id = "
                        + "(select id from practice_activities where slug = ?) and action = 'rollback'",
                String.class,
                sceneId)).isEqualTo(principalId);
    }

    private AdminPresetSceneRepository.SceneSummaryRow findSceneSummary(String presetSceneId) {
        return repository.findScenes().stream()
                .filter(row -> row.presetSceneId().equals(presetSceneId))
                .findFirst()
                .orElseThrow();
    }

    private AdminPresetSceneRepository.DraftRow createDraft() {
        return createDraft(true);
    }

    private AdminPresetSceneRepository.DraftRow createDraft(boolean enabled) {
        return repository.createDraft(
                "bath_time",
                new AdminPresetSceneRepository.DraftWrite(
                        "洗澡时间（草稿）",
                        "草稿摘要",
                        "Bath time",
                        "草稿提示",
                        1,
                        "围绕暖水生成互动。",
                        enabled),
                adminPrincipalId(),
                now());
    }

    private AdminPresetSceneRepository.DraftWrite updatedWrite() {
        return new AdminPresetSceneRepository.DraftWrite(
                "冲突草稿",
                "冲突摘要",
                "Bath time",
                "冲突提示",
                2,
                "冲突生成文案。",
                true);
    }

    private void assertSafeAuditSummary(String action, String forbiddenText) {
        String summary = jdbcTemplate.queryForObject(
                "select change_summary::text from practice_preset_scene_audit where action = ?",
                String.class,
                action);
        assertThat(summary)
                .isNotBlank()
                .contains(action)
                .contains("lock_version")
                .doesNotContain(forbiddenText)
                .doesNotContain("generationBrief")
                .doesNotContain("coachTip");
    }

    private String adminPrincipalId() {
        return jdbcTemplate.queryForObject(
                "select principal_id from admin_principals where username = 'super_admin'",
                String.class);
    }

    private OffsetDateTime now() {
        return OffsetDateTime.of(2026, 8, 31, 12, 0, 0, 0, ZoneOffset.UTC);
    }

    private String createConcurrentScene() {
        var sceneId = "concurrent_repo_" + UUID.randomUUID().toString().replace("-", "");
        var activityId = jdbcTemplate.queryForObject(
                """
                insert into practice_activities (
                    slug, space_id, title_zh, scene_tag_en, coach_tip, sort_order, source
                )
                select ?, id, '并发测试', 'Concurrent', '并发测试提示', 99, 'seed'
                from practice_spaces
                where slug = 'daily_care'
                returning id
                """,
                Long.class,
                sceneId);
        var versionId = jdbcTemplate.queryForObject(
                """
                insert into practice_preset_scene_versions (
                    activity_id, version, state, title_zh, summary_zh, scene_tag_en,
                    coach_tip_zh, sort_order, generation_brief, enabled, lock_version,
                    created_at, updated_at, published_at
                ) values (?, 1, 'published', '并发测试', '并发摘要', 'Concurrent',
                          '并发提示', 1, '并发历史文案。', true, 0, ?, ?, ?)
                returning version_id
                """,
                Long.class,
                activityId,
                now(),
                now(),
                now());
        jdbcTemplate.update(
                "update practice_activities set current_published_version_id = ? where id = ?",
                versionId,
                activityId);
        return sceneId;
    }

    private int currentPublishedVersion(String sceneId) {
        return jdbcTemplate.queryForObject(
                "select v.version from practice_activities a "
                        + "join practice_preset_scene_versions v on v.version_id = a.current_published_version_id "
                        + "where a.slug = ?",
                Integer.class,
                sceneId);
    }

    private List<RepositoryCallResult> runRepositoryConcurrently(
            Callable<Object> firstCall,
            Callable<Object> secondCall
    ) throws Exception {
        ExecutorService executor = Executors.newFixedThreadPool(2);
        var barrier = new CyclicBarrier(2);
        Callable<RepositoryCallResult> first = synchronizedRepositoryCall(barrier, firstCall);
        Callable<RepositoryCallResult> second = synchronizedRepositoryCall(barrier, secondCall);
        try {
            Future<RepositoryCallResult> firstFuture = executor.submit(first);
            Future<RepositoryCallResult> secondFuture = executor.submit(second);
            return List.of(
                    firstFuture.get(30, TimeUnit.SECONDS),
                    secondFuture.get(30, TimeUnit.SECONDS));
        } finally {
            executor.shutdownNow();
            executor.awaitTermination(10, TimeUnit.SECONDS);
        }
    }

    private Callable<RepositoryCallResult> synchronizedRepositoryCall(
            CyclicBarrier barrier,
            Callable<Object> call
    ) {
        return () -> {
            barrier.await(10, TimeUnit.SECONDS);
            try {
                return new RepositoryCallResult(inIndependentTransaction(() -> {
                    try {
                        return call.call();
                    } catch (Exception failure) {
                        throw new IllegalStateException(failure);
                    }
                }), null);
            } catch (Throwable failure) {
                return new RepositoryCallResult(null, failure);
            }
        };
    }

    private <T> T inIndependentTransaction(Supplier<T> work) {
        return new TransactionTemplate(transactionManager).execute(status -> work.get());
    }

    private record RepositoryCallResult(Object value, Throwable failure) {
    }
}
