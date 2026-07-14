package com.zhangspaghetti.babytalk.practice.catalog;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.practice.catalog.model.CachedPhrase;
import com.zhangspaghetti.babytalk.practice.catalog.model.PracticeActivityRow;
import com.zhangspaghetti.babytalk.practice.catalog.model.PracticeSpaceRow;
import com.zhangspaghetti.babytalk.practice.catalog.model.StarterPhraseSourcePolicy;
import java.util.HashSet;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

class PracticeCatalogServiceTest extends AbstractIntegrationTest {

    private static final String TEST_PREFIX = "b20_repo_test_";

    @Autowired
    private PracticeCatalogService catalogMapper;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    void cleanCatalogFixturesBeforeTest() {
        cleanCatalogFixtures();
    }

    @AfterEach
    void cleanCatalogFixturesAfterTest() {
        cleanCatalogFixtures();
    }

    @Test
    void findActivityBySceneTagReturnsSeedActivity() {
        var activity = catalogMapper.findActivityBySceneTag("Bath time");

        assertThat(activity).isPresent();
        assertThat(activity.get().slug()).isEqualTo("bath_time");
        assertThat(activity.get().spaceSlug()).isEqualTo("daily_care");
        assertThat(activity.get().titleZh()).isEqualTo("洗澡时间");
        assertThat(activity.get().coachTip()).contains("慢速");
    }

    @Test
    void findActivityBySceneTagReturnsEmptyForMissingScene() {
        assertThat(catalogMapper.findActivityBySceneTag(TEST_PREFIX + "missing_scene"))
                .isEmpty();
    }

    @Test
    void findActivityBySceneTagUsesStableFirstInsertedTieBreakForDuplicateSceneTags() {
        var spaceId = insertSpaceFixture("scene_tie_space");
        var firstActivityId = catalogMapper.insertActivity(
                TEST_PREFIX + "scene_tie_first",
                spaceId,
                "First duplicate scene",
                TEST_PREFIX + "duplicate_scene",
                "first tip"
        );
        catalogMapper.insertActivity(
                TEST_PREFIX + "scene_tie_second",
                spaceId,
                "Second duplicate scene",
                TEST_PREFIX + "duplicate_scene",
                "second tip"
        );

        var activity = catalogMapper.findActivityBySceneTag(TEST_PREFIX + "duplicate_scene");

        assertThat(activity).isPresent();
        assertThat(activity.get().id()).isEqualTo(firstActivityId);
        assertThat(activity.get().slug()).isEqualTo(TEST_PREFIX + "scene_tie_first");
    }

    @Test
    void findPhrasesByActivityIdReturnsSeedPhrasesInStepOrder() {
        var bathTimeId = seedActivityId("bath_time");

        var phrases = catalogMapper.findPhrasesByActivityId(bathTimeId);

        assertThat(phrases)
                .extracting(CachedPhrase::slug)
                .containsExactly(
                        "bath_time_warm_water",
                        "bath_time_splash_splash",
                        "bath_time_all_clean"
                );
        assertThat(phrases)
                .extracting(CachedPhrase::step)
                .containsExactly(1, 2, 3);
    }

    @Test
    void findPhrasesByActivityIdReturnsEmptyForMissingActivity() {
        assertThat(catalogMapper.findPhrasesByActivityId(-1L)).isEmpty();
    }

    @Test
    void findPhrasesByActivityIdUsesStableIdTieBreakForDuplicateSteps() {
        var spaceId = insertSpaceFixture("phrase_tie_space");
        var activityId = catalogMapper.insertActivity(
                TEST_PREFIX + "phrase_tie_activity",
                spaceId,
                "Phrase tie activity",
                TEST_PREFIX + "phrase_tie_scene",
                null
        );
        var firstPhraseId = catalogMapper.insertPhrase(
                TEST_PREFIX + "phrase_tie_first",
                activityId,
                1,
                "First phrase.",
                "第一句。",
                null,
                "starter"
        );
        var secondPhraseId = catalogMapper.insertPhrase(
                TEST_PREFIX + "phrase_tie_second",
                activityId,
                1,
                "Second phrase.",
                "第二句。",
                null,
                "starter"
        );

        var phrases = catalogMapper.findPhrasesByActivityId(activityId);

        assertThat(phrases)
                .extracting(CachedPhrase::id)
                .containsExactly(firstPhraseId, secondPhraseId);
    }

    @Test
    void findSpaceIdBySlugReturnsExistingSeedAndEmptyForMissingSlug() {
        assertThat(catalogMapper.findSpaceIdBySlug("daily_care")).isPresent();
        assertThat(catalogMapper.findSpaceIdBySlug(TEST_PREFIX + "missing_space")).isEmpty();
    }

    @Test
    void findAllSpaceSlugsReturnsSeedSpacesInSortOrderWithoutDuplicates() {
        var slugs = catalogMapper.findAllSpaceSlugs();

        assertThat(slugs).containsExactly("daily_care", "family_rhythm");
        assertThat(new HashSet<>(slugs)).hasSameSizeAs(slugs);
    }

    @Test
    void insertSpaceReturnsInsertedIdAndConflictFallsBackToExistingId() {
        var slug = TEST_PREFIX + "insert_space";

        var insertedId = catalogMapper.insertSpace(slug, "Original title");
        var duplicateId = catalogMapper.insertSpace(slug, "Changed title");

        assertThat(duplicateId).isEqualTo(insertedId);
        assertThat(catalogMapper.findSpaceIdBySlug(slug)).contains(insertedId);
        assertThat(jdbcTemplate.queryForObject(
                "select title_zh from practice_spaces where id = ?",
                String.class,
                insertedId
        )).isEqualTo("Original title");
    }

    @Test
    void insertActivityReturnsInsertedIdWritesLlmSourceAndConflictFallsBackToExistingId() {
        var spaceId = insertSpaceFixture("activity_insert_space");
        var slug = TEST_PREFIX + "activity_insert";

        var insertedId = catalogMapper.insertActivity(
                slug,
                spaceId,
                "Original activity",
                "Original scene",
                "Original tip"
        );
        var duplicateId = catalogMapper.insertActivity(
                slug,
                spaceId,
                "Changed activity",
                "Changed scene",
                "Changed tip"
        );

        assertThat(duplicateId).isEqualTo(insertedId);
        assertThat(jdbcTemplate.queryForMap(
                "select title_zh, scene_tag_en, coach_tip, source from practice_activities where id = ?",
                insertedId
        )).containsEntry("title_zh", "Original activity")
                .containsEntry("scene_tag_en", "Original scene")
                .containsEntry("coach_tip", "Original tip")
                .containsEntry("source", "llm");
    }

    @Test
    void insertPhraseReturnsInsertedIdWritesLlmSourceAndConflictFallsBackToExistingId() {
        var spaceId = insertSpaceFixture("phrase_insert_space");
        var activityId = catalogMapper.insertActivity(
                TEST_PREFIX + "phrase_insert_activity",
                spaceId,
                "Phrase insert activity",
                "Phrase insert scene",
                null
        );
        var slug = TEST_PREFIX + "phrase_insert";

        var insertedId = catalogMapper.insertPhrase(
                slug,
                activityId,
                1,
                "Original English.",
                "原始中文。",
                null,
                null
        );
        var duplicateId = catalogMapper.insertPhrase(
                slug,
                activityId,
                2,
                "Changed English.",
                "改过的中文。",
                "changed",
                "easy"
        );

        assertThat(duplicateId).isEqualTo(insertedId);
        assertThat(jdbcTemplate.queryForMap(
                "select step, english, chinese, pronunciation, difficulty, source from practice_phrases where id = ?",
                insertedId
        )).containsEntry("step", 1)
                .containsEntry("english", "Original English.")
                .containsEntry("chinese", "原始中文。")
                .containsEntry("pronunciation", null)
                .containsEntry("difficulty", null)
                .containsEntry("source", "llm");
    }

    @Test
    void generatedPersistenceBehaviorKeepsRowsReadableByLegacyLookupMethods() {
        var spaceId = insertSpaceFixture("generated_space");
        var activityId = catalogMapper.insertActivity(
                TEST_PREFIX + "generated_activity",
                spaceId,
                "Generated activity",
                TEST_PREFIX + "generated_scene",
                "Generated tip"
        );
        var firstPhraseId = catalogMapper.insertPhrase(
                TEST_PREFIX + "generated_phrase_1",
                activityId,
                1,
                "Generated one.",
                "生成一句。",
                "generated one",
                "easy"
        );
        var secondPhraseId = catalogMapper.insertPhrase(
                TEST_PREFIX + "generated_phrase_2",
                activityId,
                2,
                "Generated two.",
                "生成两句。",
                "generated two",
                "medium"
        );

        var activity = catalogMapper.findActivityBySceneTag(TEST_PREFIX + "generated_scene");
        var phrases = catalogMapper.findPhrasesByActivityId(activityId);

        assertThat(activity).isPresent();
        assertThat(activity.get().id()).isEqualTo(activityId);
        assertThat(activity.get().slug()).isEqualTo(TEST_PREFIX + "generated_activity");
        assertThat(activity.get().spaceSlug()).isEqualTo(TEST_PREFIX + "generated_space");
        assertThat(activity.get().coachTip()).isEqualTo("Generated tip");
        assertThat(phrases)
                .extracting(CachedPhrase::id)
                .containsExactly(firstPhraseId, secondPhraseId);
        assertThat(phrases)
                .extracting(CachedPhrase::difficulty)
                .containsExactly("easy", "medium");
    }

    @Test
    void findSpacesReturnsPublicSpaceRowsInSortOrderWithoutDuplicates() {
        var spaces = catalogMapper.findSpaces("zh-CN", 10);

        assertThat(spaces)
                .extracting(PracticeSpaceRow::spaceId)
                .containsExactly("daily_care", "family_rhythm");
        assertThat(spaces)
                .extracting(PracticeSpaceRow::titleZh)
                .containsExactly("日常照护", "家庭节奏");
        assertThat(spaces)
                .extracting(PracticeSpaceRow::sortOrder)
                .containsExactly(1, 2);
        assertThat(spaces.get(0).descriptionZh()).contains("洗澡");
        assertThat(new HashSet<>(spaces.stream()
                .map(PracticeSpaceRow::spaceId)
                .toList())).hasSameSizeAs(spaces);
    }

    @Test
    void findSpacesClampsLowerLimitBoundaryToOne() {
        var spaces = catalogMapper.findSpaces("zh-CN", 0);

        assertThat(spaces)
                .extracting(PracticeSpaceRow::spaceId)
                .containsExactly("daily_care");
    }

    @Test
    void findSpacesClampsUpperLimitBoundaryToFifty() {
        for (int i = 0; i < 55; i++) {
            catalogMapper.insertSpace(TEST_PREFIX + "limit_space_%02d".formatted(i), "Limit space " + i);
        }

        var spaces = catalogMapper.findSpaces("zh-CN", 1000);

        assertThat(spaces).hasSize(50);
        assertThat(new HashSet<>(spaces.stream()
                .map(PracticeSpaceRow::spaceId)
                .toList())).hasSameSizeAs(spaces);
    }

    @Test
    void findActivitiesBySpaceReturnsSeedActivitiesInSortOrderWithoutDuplicates() {
        var activities = catalogMapper.findActivitiesBySpace("daily_care", "zh-CN", 10);

        assertThat(activities)
                .extracting(PracticeActivityRow::activityId)
                .containsExactly("bath_time", "diaper_change");
        assertThat(activities)
                .extracting(PracticeActivityRow::spaceId)
                .containsExactly("daily_care", "daily_care");
        assertThat(activities)
                .extracting(PracticeActivityRow::source)
                .containsExactly("seed", "seed");
        assertThat(activities.get(0).sceneTagEn()).isEqualTo("Bath time");
        assertThat(new HashSet<>(activities.stream()
                .map(PracticeActivityRow::activityId)
                .toList())).hasSameSizeAs(activities);
    }

    @Test
    void findActivitiesBySpaceClampsLowerLimitBoundaryToOne() {
        var activities = catalogMapper.findActivitiesBySpace("daily_care", "zh-CN", -5);

        assertThat(activities)
                .extracting(PracticeActivityRow::activityId)
                .containsExactly("bath_time");
    }

    @Test
    void findActivitiesBySpaceReturnsEmptyForMissingSpace() {
        assertThat(catalogMapper.findActivitiesBySpace(TEST_PREFIX + "missing_space", "zh-CN", 10))
                .isEmpty();
    }

    @Test
    void findStarterPhraseReturnsSeedStarterPhraseWithFullFields() {
        var phrase = catalogMapper.findStarterPhrase("bath_time", "zh-CN");

        assertThat(phrase).isPresent();
        assertThat(phrase.get().phraseId()).isEqualTo("bath_time_warm_water");
        assertThat(phrase.get().activityId()).isEqualTo("bath_time");
        assertThat(phrase.get().step()).isEqualTo(1);
        assertThat(phrase.get().english()).isEqualTo("Warm water.");
        assertThat(phrase.get().chinese()).isEqualTo("水暖暖的。");
        assertThat(phrase.get().pronunciation()).isEqualTo("wɔːrm ˈwɔː.t̬ɚ");
        assertThat(phrase.get().difficulty()).isEqualTo("starter");
        assertThat(phrase.get().audioAsset()).isEqualTo("assets/audio/phrases/bath_time_warm_water.mp3");
        assertThat(phrase.get().source()).isEqualTo("seed");
    }

    @Test
    void findStarterPhrasePrefersStarterDifficultyBeforeStepOrder() {
        var spaceId = insertSpaceFixture("starter_preference_space");
        var activityId = catalogMapper.insertActivity(
                TEST_PREFIX + "starter_preference_activity",
                spaceId,
                "Starter preference activity",
                TEST_PREFIX + "starter_preference_scene",
                null
        );
        catalogMapper.insertPhrase(
                TEST_PREFIX + "starter_preference_easy",
                activityId,
                1,
                "Easy first.",
                "先简单。",
                null,
                "easy"
        );
        catalogMapper.insertPhrase(
                TEST_PREFIX + "starter_preference_starter",
                activityId,
                2,
                "Starter second.",
                "后入门。",
                null,
                "starter"
        );

        var phrase = catalogMapper.findStarterPhrase(TEST_PREFIX + "starter_preference_activity", "zh-CN");

        assertThat(phrase).isPresent();
        assertThat(phrase.get().phraseId()).isEqualTo(TEST_PREFIX + "starter_preference_starter");
        assertThat(phrase.get().source()).isEqualTo("llm");
    }

    @Test
    void findStarterPhraseSourcePolicyControlsWhetherLlmCanShadowSeedPhrase() {
        var bathTimeId = seedActivityId("bath_time");
        catalogMapper.insertPhrase(
                TEST_PREFIX + "shadow_llm_starter",
                bathTimeId,
                0,
                "Generated first.",
                "生成优先。",
                null,
                "starter"
        );

        var legacyPhrase = catalogMapper.findStarterPhrase("bath_time", "zh-CN");
        var anySourcePhrase = catalogMapper.findStarterPhrase(
                "bath_time",
                "zh-CN",
                StarterPhraseSourcePolicy.ANY_SOURCE
        );
        var seedPhrase = catalogMapper.findStarterPhrase(
                "bath_time",
                "zh-CN",
                StarterPhraseSourcePolicy.SEED_ONLY
        );

        assertThat(legacyPhrase).isPresent();
        assertThat(legacyPhrase.get().phraseId()).isEqualTo(TEST_PREFIX + "shadow_llm_starter");
        assertThat(legacyPhrase.get().source()).isEqualTo("llm");
        assertThat(anySourcePhrase).isPresent();
        assertThat(anySourcePhrase.get().phraseId()).isEqualTo(TEST_PREFIX + "shadow_llm_starter");
        assertThat(anySourcePhrase.get().source()).isEqualTo("llm");
        assertThat(seedPhrase).isPresent();
        assertThat(seedPhrase.get().phraseId()).isEqualTo("bath_time_warm_water");
        assertThat(seedPhrase.get().source()).isEqualTo("seed");
    }

    @Test
    void findStarterPhraseReturnsEmptyForMissingActivity() {
        assertThat(catalogMapper.findStarterPhrase(TEST_PREFIX + "missing_activity", "zh-CN"))
                .isEmpty();
    }

    @Test
    void findNextPhraseReturnsNextHigherStepWithinSameActivity() {
        var phrase = catalogMapper.findNextPhrase("bath_time", "bath_time_warm_water");

        assertThat(phrase).isPresent();
        assertThat(phrase.get().phraseId()).isEqualTo("bath_time_splash_splash");
        assertThat(phrase.get().activityId()).isEqualTo("bath_time");
        assertThat(phrase.get().step()).isEqualTo(2);
    }

    @Test
    void findNextPhraseReturnsEmptyForLastInvalidOrMismatchedPhrase() {
        assertThat(catalogMapper.findNextPhrase("bath_time", "bath_time_all_clean"))
                .isEmpty();
        assertThat(catalogMapper.findNextPhrase("bath_time", "feeding_time_open_wide"))
                .isEmpty();
        assertThat(catalogMapper.findNextPhrase(TEST_PREFIX + "missing_activity", "bath_time_warm_water"))
                .isEmpty();
    }

    @Test
    void existsSpaceActivityPhraseValidatesTheFullSlugPath() {
        assertThat(catalogMapper.existsSpaceActivityPhrase(
                "daily_care",
                "bath_time",
                "bath_time_warm_water"
        )).isTrue();
        assertThat(catalogMapper.existsSpaceActivityPhrase(
                "family_rhythm",
                "bath_time",
                "bath_time_warm_water"
        )).isFalse();
        assertThat(catalogMapper.existsSpaceActivityPhrase(
                "daily_care",
                "feeding_time",
                "feeding_time_open_wide"
        )).isFalse();
        assertThat(catalogMapper.existsSpaceActivityPhrase(
                "daily_care",
                "bath_time",
                "feeding_time_open_wide"
        )).isFalse();
        assertThat(catalogMapper.existsSpaceActivityPhrase(
                TEST_PREFIX + "missing_space",
                "bath_time",
                "bath_time_warm_water"
        )).isFalse();
    }

    private long insertSpaceFixture(String suffix) {
        return catalogMapper.insertSpace(TEST_PREFIX + suffix, "Test " + suffix);
    }

    private long seedActivityId(String slug) {
        return jdbcTemplate.queryForObject(
                "select id from practice_activities where slug = ?",
                Long.class,
                slug
        );
    }

    private void cleanCatalogFixtures() {
        var likePattern = TEST_PREFIX + "%";
        jdbcTemplate.update(
                """
                delete from practice_phrases
                where slug like ?
                   or activity_id in (
                       select id from practice_activities where slug like ?
                   )
                """,
                likePattern,
                likePattern
        );
        jdbcTemplate.update(
                """
                delete from practice_activities
                where slug like ?
                   or space_id in (
                       select id from practice_spaces where slug like ?
                   )
                """,
                likePattern,
                likePattern
        );
        jdbcTemplate.update("delete from practice_spaces where slug like ?", likePattern);
    }
}
