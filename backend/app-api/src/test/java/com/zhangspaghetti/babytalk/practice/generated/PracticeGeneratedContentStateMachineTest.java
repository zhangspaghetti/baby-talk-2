package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

class PracticeGeneratedContentStateMachineTest extends AbstractIntegrationTest {

    private static final OffsetDateTime NOW = OffsetDateTime.of(
            2026, 7, 3, 4, 0, 0, 0, ZoneOffset.UTC);

    @Autowired
    private PracticeGeneratedContentCommands commands;

    @Autowired
    private PracticeGeneratedContentQueryMapper queries;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    @AfterEach
    void clean() {
        jdbcTemplate.update("delete from practice_generated_content where generated_content_id like 'pgc_state_%'");
    }

    @Test
    void draftTransitionsToGeneratingThenActive() {
        var draft = reserve("pgc_state_active");

        assertThat(commands.startGeneration(draft.generatedContentId(), NOW.minusDays(1), 5, NOW))
                .isEqualTo(GenerationStartDecision.STARTED);
        assertThat(status(draft.generatedContentId())).isEqualTo("generating");

        assertThat(commands.activate(active(draft, NOW.plusSeconds(1)))).isPresent();
        assertThat(status(draft.generatedContentId())).isEqualTo("active");
    }

    @Test
    void draftAndGeneratingCanBeRejectedOrExpired() {
        var draftRejected = reserve("pgc_state_draft_rejected");
        commands.reject(draftRejected.generatedContentId(), "unsafe", false, NOW, NOW.plusDays(7));
        assertThat(status(draftRejected.generatedContentId())).isEqualTo("rejected");

        var generatingRejected = reserve("pgc_state_generating_rejected");
        commands.startGeneration(generatingRejected.generatedContentId(), NOW.minusDays(1), 5, NOW);
        commands.reject(generatingRejected.generatedContentId(), "unsafe", false, NOW, NOW.plusDays(7));
        assertThat(status(generatingRejected.generatedContentId())).isEqualTo("rejected");

        var draftExpired = reserve("pgc_state_draft_expired");
        commands.expire(draftExpired.generatedContentId(), "timeout", true, NOW, NOW.plusDays(7));
        assertThat(status(draftExpired.generatedContentId())).isEqualTo("expired");

        var generatingExpired = reserve("pgc_state_generating_expired");
        commands.startGeneration(generatingExpired.generatedContentId(), NOW.minusDays(1), 5, NOW);
        commands.expire(generatingExpired.generatedContentId(), "timeout", true, NOW, NOW.plusDays(7));
        assertThat(status(generatingExpired.generatedContentId())).isEqualTo("expired");
    }

    @Test
    void terminalRowsCannotTransitionAgain() {
        var active = reserve("pgc_state_terminal_active");
        commands.startGeneration(active.generatedContentId(), NOW.minusDays(1), 5, NOW);
        commands.activate(active(active, NOW.plusSeconds(1)));

        var rejected = reserve("pgc_state_terminal_rejected");
        commands.reject(rejected.generatedContentId(), "unsafe", false, NOW, NOW.plusDays(7));

        var expired = reserve("pgc_state_terminal_expired");
        commands.expire(expired.generatedContentId(), "timeout", true, NOW, NOW.plusDays(7));

        for (var id : new String[]{active.generatedContentId(), rejected.generatedContentId(), expired.generatedContentId()}) {
            var original = status(id);
            assertThat(commands.startGeneration(id, NOW.minusDays(1), 5, NOW.plusMinutes(1)))
                    .isEqualTo(GenerationStartDecision.NOT_LIVE);
            commands.reject(id, "other", true, NOW.plusMinutes(1), NOW.plusDays(7));
            commands.expire(id, "other", true, NOW.plusMinutes(1), NOW.plusDays(7));
            assertThat(status(id)).isEqualTo(original);
        }
    }

    @Test
    void dailyQuotaCountsGenerationStartsNotDraftReservations() {
        var firstDraft = draft("pgc_state_quota_first");
        var secondDraft = draft("pgc_state_quota_second");
        firstDraft.setOwnerKey("hmac_shared_quota_owner");
        secondDraft.setOwnerKey("hmac_shared_quota_owner");
        var first = commands.reserveDraft(
                firstDraft, new ReservationPolicy(NOW, NOW.minusMinutes(10), 100, NOW.plusDays(7))).content();
        var second = commands.reserveDraft(
                secondDraft, new ReservationPolicy(NOW, NOW.minusMinutes(10), 100, NOW.plusDays(7))).content();

        assertThat(commands.startGeneration(first.generatedContentId(), NOW.minusDays(1), 1, NOW))
                .isEqualTo(GenerationStartDecision.STARTED);
        assertThat(commands.startGeneration(second.generatedContentId(), NOW.minusDays(1), 1, NOW.plusSeconds(1)))
                .isEqualTo(GenerationStartDecision.DAILY_LIMIT_EXCEEDED);
        assertThat(status(second.generatedContentId())).isEqualTo("draft");
    }

    private PracticeGeneratedContentEntity reserve(String id) {
        var draft = draft(id);
        var reservation = commands.reserveDraft(
                draft,
                new ReservationPolicy(NOW, NOW.minusMinutes(10), 100, NOW.plusDays(7)));
        assertThat(reservation.created()).isTrue();
        return reservation.content();
    }

    private PracticeGeneratedContentEntity draft(String id) {
        var entity = new PracticeGeneratedContentEntity();
        entity.setGeneratedContentId(id);
        entity.setOwnerScope("installation");
        entity.setOwnerKey("hmac_" + id);
        entity.setOwnerKeyVersion("v1");
        entity.setInstallationRefHash("installation_" + id);
        entity.setSurface("onboarding");
        entity.setMode("custom_scene");
        entity.setRequestFingerprint("fingerprint_" + id);
        entity.setNormalizedSceneText("宝宝不肯穿鞋");
        entity.setAgeRange("2-3");
        entity.setParentGoal("daily_routine");
        entity.setLocale("zh-CN");
        entity.setStatus("draft");
        entity.setGenerationProfileVersion("generation-profile-v1");
        entity.setGenerationProfileHash("a".repeat(64));
        entity.setRubricVersion("rubric-v1");
        entity.setRubricContentHash("b".repeat(64));
        entity.setEvidencePolicyVersion("evidence-policy-v1");
        entity.setEvidencePolicyContentHash("c".repeat(64));
        entity.setProviderRoutingPolicyVersion("routing-v1");
        entity.setProviderRoutingPolicyHash("d".repeat(64));
        entity.setGenerationAttemptLimit(3);
        entity.setContentRefreshEpoch(1);
        entity.setContentVersion(1);
        entity.setGenerationExpiresAt(NOW.plusMinutes(5));
        entity.setCreatedAt(NOW);
        entity.setUpdatedAt(NOW);
        return entity;
    }

    private PracticeGeneratedContentEntity active(PracticeGeneratedContentEntity entity, OffsetDateTime updatedAt) {
        entity.setSpaceSlug("space-" + entity.generatedContentId());
        entity.setActivitySlug("activity-" + entity.generatedContentId());
        entity.setPhraseSlug("phrase-" + entity.generatedContentId());
        entity.setSpaceTitleZh("穿鞋");
        entity.setActivityTitleZh("准备出门");
        entity.setSceneTagEn("getting-ready");
        entity.setTprActionZh("指向鞋子");
        entity.setDeliveryGuidanceZh("慢速示范一次");
        entity.setEnglishText("Shoes on.");
        entity.setChineseText("穿鞋啦。");
        entity.setPronunciationHint("shooz on");
        entity.setDifficulty("easy");
        entity.setGenerationSource("fake");
        entity.setRetentionExpiresAt(updatedAt.plusDays(30));
        entity.setUpdatedAt(updatedAt);
        return entity;
    }

    private String status(String id) {
        return queries.findByGeneratedContentId(id).status();
    }
}
