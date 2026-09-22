package com.zhangspaghetti.babytalk.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.config.ApiVersionInterceptor;
import com.zhangspaghetti.babytalk.practice.preset.PresetSceneCatalogService;
import java.util.HashSet;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

@SpringBootTest(properties = {
        "app.contract.min-supported-version=1.2.0",
        "app.contract.upgrade-url=https://download.example.com/babytalk.apk",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810"
})
@AutoConfigureMockMvc
class PresetSceneCatalogControllerTest extends AbstractIntegrationTest {

    private static final Set<String> PUBLIC_KEYS = Set.of(
            "presetSceneId",
            "publishedVersion",
            "spaceId",
            "title",
            "summary",
            "sceneTag",
            "coachTip",
            "sortOrder"
    );

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private PresetSceneCatalogService catalogService;

    @Autowired
    private PlatformTransactionManager transactionManager;

    @BeforeEach
    void resetCurrentPointersToFirstPublishedVersion() {
        jdbcTemplate.update("""
                update practice_activities a
                set current_published_version_id = (
                    select v.version_id
                    from practice_preset_scene_versions v
                    where v.activity_id = a.id
                      and v.state = 'published'
                    order by v.version asc, v.version_id asc
                    limit 1
                )
                """);
    }

    @Test
    void listsCurrentEnabledPublishedScenesInStableOrderWithExactPublicKeys() throws Exception {
        var result = mockMvc.perform(get("/api/v1/practice/preset-scenes")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].presetSceneId").value("bath_time"))
                .andExpect(jsonPath("$[0].publishedVersion").value(1))
                .andExpect(jsonPath("$[0].generationBrief").doesNotExist())
                .andReturn();

        var body = objectMapper.readTree(result.getResponse().getContentAsString());
        assertThat(body).hasSize(5);
        assertThat(sceneIds(body)).containsExactly(
                "bath_time",
                "feeding_time",
                "bedtime",
                "diaper_change",
                "post_cry_soothing");
        for (JsonNode scene : body) {
            var keys = new HashSet<String>();
            keys.addAll(scene.propertyNames());
            assertThat(keys).containsExactlyInAnyOrderElementsOf(PUBLIC_KEYS);
        }
        assertThat(result.getResponse().getContentAsString())
                .doesNotContain("activityId")
                .doesNotContain("versionId")
                .doesNotContain("generationBrief")
                .doesNotContain("admin")
                .doesNotContain("audit");
    }

    @Test
    void nonGetCatalogRoutesRequireConsumerAuthentication() throws Exception {
        mockMvc.perform(post("/api/v1/practice/preset-scenes")
                        .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0")
                        .contentType("application/json")
                        .content("{}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("consumer_authentication_required"))
                .andExpect(jsonPath("$.details.reason").value("missing"));
    }

    @Test
    void disabledCurrentVersionDisappearsFromCatalogAndIsUnavailableToConsumers() throws Exception {
        inRollbackTransaction(() -> {
            var originalVersionId = currentVersionId("bath_time");
            var disabledVersion = insertPublishedVersion("bath_time", "禁用洗澡时间", false, 1);
            setCurrentVersion("bath_time", disabledVersion.versionId());

            var result = mockMvc.perform(get("/api/v1/practice/preset-scenes")
                            .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0"))
                    .andExpect(status().isOk())
                    .andReturn();
            assertThat(sceneIds(objectMapper.readTree(result.getResponse().getContentAsString())))
                    .doesNotContain("bath_time");
            assertUnavailable("bath_time");
            setCurrentVersion("bath_time", originalVersionId);
        });
    }

    @Test
    void currentPublishedTitleChangesWhilePublishedHistoryRemains() throws Exception {
        inRollbackTransaction(() -> {
            var originalVersionId = currentVersionId("bath_time");
            var changedVersion = insertPublishedVersion("bath_time", "新的洗澡时间", true, 1);
            setCurrentVersion("bath_time", changedVersion.versionId());

            var result = mockMvc.perform(get("/api/v1/practice/preset-scenes")
                            .header(ApiVersionInterceptor.VERSION_HEADER, "1.2.0"))
                    .andExpect(status().isOk())
                    .andReturn();

            var body = objectMapper.readTree(result.getResponse().getContentAsString());
            var bathTime = java.util.stream.StreamSupport.stream(body.spliterator(), false)
                    .filter(scene -> "bath_time".equals(scene.get("presetSceneId").asText()))
                    .findFirst()
                    .orElseThrow();
            assertThat(bathTime.get("publishedVersion").asInt()).isEqualTo(changedVersion.version());
            assertThat(bathTime.get("title").asText()).isEqualTo("新的洗澡时间");
            assertThat(jdbcTemplate.queryForObject(
                    "select count(*) from practice_preset_scene_versions "
                            + "where activity_id = (select id from practice_activities where slug = 'bath_time') "
                            + "and state = 'published'",
                    Integer.class)).isGreaterThanOrEqualTo(2);
            assertThat(jdbcTemplate.queryForObject(
                    "select title_zh from practice_preset_scene_versions where version_id = ?",
                    String.class,
                    originalVersionId)).isEqualTo("洗澡时间");
            setCurrentVersion("bath_time", originalVersionId);
        });
    }

    @Test
    void requirePublishedReturnsCurrentInternalIdentityAndGenerationBrief() throws Exception {
        var initial = catalogService.requirePublished("bath_time");
        assertThat(initial.activityId()).isPositive();
        assertThat(initial.versionId()).isPositive();
        assertThat(initial.publishedVersion()).isEqualTo(1);
        assertThat(initial.generationBrief()).isNotBlank();

        inRollbackTransaction(() -> {
            var originalVersionId = currentVersionId("bath_time");
            var changedVersion = insertPublishedVersion("bath_time", "新的洗澡时间", true, 1);
            setCurrentVersion("bath_time", changedVersion.versionId());

            var current = catalogService.requirePublished("bath_time");
            assertThat(current.activityId()).isEqualTo(initial.activityId());
            assertThat(current.versionId()).isEqualTo(changedVersion.versionId());
            assertThat(current.publishedVersion()).isEqualTo(changedVersion.version());
            assertThat(current.generationBrief()).isEqualTo("更新后的生成文案");
            setCurrentVersion("bath_time", originalVersionId);
        });
    }

    @Test
    void missingOrUnpublishedPresetUsesSameUnavailableContract() throws Exception {
        assertUnavailable("does_not_exist");

        inRollbackTransaction(() -> {
            var originalVersionId = currentVersionId("bath_time");
            jdbcTemplate.update(
                    "update practice_activities set current_published_version_id = null where slug = 'bath_time'");
            assertUnavailable("bath_time");
            setCurrentVersion("bath_time", originalVersionId);
        });
    }

    private void inRollbackTransaction(ThrowingRunnable action) throws Exception {
        try {
            new TransactionTemplate(transactionManager).executeWithoutResult(transactionStatus -> {
                try {
                    action.run();
                    transactionStatus.setRollbackOnly();
                } catch (Exception exception) {
                    throw new TestExecutionException(exception);
                }
            });
        } catch (TestExecutionException exception) {
            throw exception.cause;
        }
    }

    @FunctionalInterface
    private interface ThrowingRunnable {

        void run() throws Exception;
    }

    private static final class TestExecutionException extends RuntimeException {

        private final Exception cause;

        private TestExecutionException(Exception cause) {
            super(cause);
            this.cause = cause;
        }
    }

    private void assertUnavailable(String presetSceneId) {
        assertThatThrownBy(() -> catalogService.requirePublished(presetSceneId))
                .isInstanceOfSatisfying(ContractException.class, exception -> {
                    assertThat(exception.status()).isEqualTo(HttpStatus.NOT_FOUND);
                    assertThat(exception.code()).isEqualTo("preset_scene_unavailable");
                    assertThat(exception.details()).isEmpty();
                    assertThat(exception.getMessage()).doesNotContain(presetSceneId);
                });
    }

    private Set<String> sceneIds(JsonNode body) {
        var ids = new java.util.LinkedHashSet<String>();
        for (JsonNode scene : body) {
            ids.add(scene.get("presetSceneId").asText());
        }
        return ids;
    }

    private long currentVersionId(String presetSceneId) {
        return jdbcTemplate.queryForObject(
                "select current_published_version_id from practice_activities where slug = ?",
                Long.class,
                presetSceneId);
    }

    private void setCurrentVersion(String presetSceneId, long versionId) {
        jdbcTemplate.update(
                "update practice_activities set current_published_version_id = ? where slug = ?",
                versionId,
                presetSceneId);
    }

    private InsertedVersion insertPublishedVersion(
            String presetSceneId,
            String title,
            boolean enabled,
            int sortOrder
    ) {
        var activityId = jdbcTemplate.queryForObject(
                "select id from practice_activities where slug = ?", Long.class, presetSceneId);
        var nextVersion = jdbcTemplate.queryForObject(
                "select coalesce(max(version), 0) + 1 from practice_preset_scene_versions "
                        + "where activity_id = ? and state = 'published'",
                Integer.class,
                activityId);
        var versionId = jdbcTemplate.queryForObject("""
                insert into practice_preset_scene_versions (
                    activity_id, version, state, title_zh, summary_zh, scene_tag_en,
                    coach_tip_zh, sort_order, generation_brief, enabled,
                    created_at, updated_at, published_at
                ) values (?, ?, 'published', ?, ?, ?, ?, ?, ?, ?, current_timestamp, current_timestamp, current_timestamp)
                returning version_id
                """, Long.class,
                activityId,
                nextVersion,
                title,
                "更新后的摘要",
                "Bath time",
                "更新后的提示",
                sortOrder,
                "更新后的生成文案",
                enabled);
        return new InsertedVersion(versionId, nextVersion);
    }

    private record InsertedVersion(long versionId, int version) {
    }
}
