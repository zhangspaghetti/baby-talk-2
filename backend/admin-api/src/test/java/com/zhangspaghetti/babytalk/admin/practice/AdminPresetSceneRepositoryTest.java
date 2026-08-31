package com.zhangspaghetti.babytalk.admin.practice;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.admin.rbac.AdminPermissionCatalog;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.transaction.annotation.Transactional;
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
    }

    private AdminPresetSceneRepository.SceneSummaryRow findSceneSummary(String presetSceneId) {
        return repository.findScenes().stream()
                .filter(row -> row.presetSceneId().equals(presetSceneId))
                .findFirst()
                .orElseThrow();
    }

    private AdminPresetSceneRepository.DraftRow createDraft() {
        return repository.createDraft(
                "bath_time",
                new AdminPresetSceneRepository.DraftWrite(
                        "洗澡时间（草稿）",
                        "草稿摘要",
                        "Bath time",
                        "草稿提示",
                        1,
                        "围绕暖水生成互动。",
                        true),
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

    private String adminPrincipalId() {
        return jdbcTemplate.queryForObject(
                "select principal_id from admin_principals where username = 'super_admin'",
                String.class);
    }

    private OffsetDateTime now() {
        return OffsetDateTime.of(2026, 8, 31, 12, 0, 0, 0, ZoneOffset.UTC);
    }
}
