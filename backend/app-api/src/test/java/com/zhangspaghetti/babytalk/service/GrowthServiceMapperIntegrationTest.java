package com.zhangspaghetti.babytalk.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.tuple;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.garden.mapper.GardenSnapshotMapper;
import com.zhangspaghetti.babytalk.growth.mapper.GrowthInsightsMapper;
import com.zhangspaghetti.babytalk.growth.mapper.GrowthSummaryMapper;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.util.ReflectionTestUtils;

@SpringBootTest(properties = {
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810"
})
class GrowthServiceMapperIntegrationTest extends AbstractIntegrationTest {

    private static final ZoneId SHANGHAI = ZoneId.of("Asia/Shanghai");
    private static final Clock GROWTH_CLOCK = Clock.fixed(
            Instant.parse("2026-07-24T12:00:00Z"),
            ZoneOffset.UTC
    );

    @Autowired
    private AuthConsentSyncService authConsentSyncService;

    @Autowired
    private GardenFertilizerService gardenFertilizerService;

    @Autowired
    private GardenSnapshotMapper gardenSnapshotMapper;

    @Autowired
    private GrowthInsightsMapper growthInsightsMapper;

    @Autowired
    private GrowthSummaryMapper growthSummaryMapper;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    void fertilizerMapperPreservesTransactionAndIdempotencySemantics() {
        var session = createAcceptedSession("13800139100", "growth-mapper-fertilizer");
        var userId = session.accountId();
        var now = Instant.now();

        assertThatThrownBy(() -> gardenFertilizerService.apply(userId, "apply-insufficient", now))
                .isInstanceOf(ContractException.class)
                .satisfies(exception -> assertThat(((ContractException) exception).code())
                        .isEqualTo("fertilizer_insufficient"));
        assertThat(jdbcTemplate.queryForObject(
                "select count(*) from garden_fertilizer_apply_log where user_id = ?",
                Integer.class,
                userId
        )).isZero();

        var claim = gardenFertilizerService.claim(userId, "event-1", "claim-1", now);
        var repeatedClaim = gardenFertilizerService.claim(userId, "event-1", "claim-1", now);
        assertThatThrownBy(() -> gardenFertilizerService.claim(userId, "event-1", "claim-conflict", now))
                .isInstanceOf(ContractException.class)
                .satisfies(exception -> {
                    var contractException = (ContractException) exception;
                    assertThat(contractException.code()).isEqualTo("fertilizer_claim_conflict");
                    assertThat(contractException.details()).containsEntry("eventKey", "event-1");
                });
        var apply = gardenFertilizerService.apply(userId, "apply-1", now);
        var repeatedApply = gardenFertilizerService.apply(userId, "apply-1", now);

        assertThat(claim.idempotent()).isFalse();
        assertThat(repeatedClaim.idempotent()).isTrue();
        assertThat(apply.idempotent()).isFalse();
        assertThat(repeatedApply.idempotent()).isTrue();
        assertThat(gardenFertilizerService.getState(userId))
                .extracting(
                        GardenFertilizerService.FertilizerStateResponse::availableCount,
                        GardenFertilizerService.FertilizerStateResponse::appliedCount,
                        GardenFertilizerService.FertilizerStateResponse::version
                )
                .containsExactly(0, 1, 2L);
    }

    @Test
    void readMappersPreserveAggregatesAndOrdering() {
        var installationId = "growth-mapper-read";
        var session = createAcceptedSession("13800139101", installationId);
        var clock = Clock.fixed(Instant.parse("2026-07-24T12:00:00Z"), ZoneOffset.UTC);
        var gardenSnapshotService = new GardenSnapshotService(
                gardenSnapshotMapper,
                authConsentSyncService,
                clock
        );
        var growthInsightsService = new GrowthInsightsService(
                growthInsightsMapper,
                authConsentSyncService,
                clock
        );
        var growthSummaryService = new GrowthSummaryService(
                growthSummaryMapper,
                authConsentSyncService
        );
        ReflectionTestUtils.setField(growthSummaryService, "clock", clock);
        var monthWindow = growthInsightsService.loadInsights(session.sessionId(), "month");
        var windowStart = monthWindow.windowStart();
        var firstEventAt = eventTime(windowStart, 0);
        var lastEventAt = eventTime(windowStart, 49);

        assertThat(firstEventAt).isAfterOrEqualTo(monthWindow.windowStart());
        assertThat(lastEventAt).isBefore(monthWindow.windowEnd());
        installPracticeScenes();
        insertEventsInReverseOrder(session, installationId, windowStart);
        gardenFertilizerService.claim(
                session.accountId(),
                eventKey(installationId, 49),
                "claim-read-49",
                lastEventAt
        );

        var snapshot = gardenSnapshotService.loadSnapshot(session.sessionId());
        assertThat(snapshot.knownEvents()).isEqualTo(50);
        assertThat(snapshot.coveredSpaceCount()).isEqualTo(6);
        assertThat(snapshot.pendingEventKeys()).containsExactlyElementsOf(expectedPendingKeys(installationId));
        assertThat(snapshot.milestones())
                .extracting(GardenSnapshotService.MilestoneEntry::sortOrder)
                .containsExactly(1, 2, 3, 4, 5);
        assertMilestoneAchievedAt(snapshot, "first_practice", firstEventAt);
        assertMilestoneAchievedAt(snapshot, "ten_phrases", eventTime(windowStart, 9));
        assertMilestoneAchievedAt(snapshot, "three_spaces", eventTime(windowStart, 25));
        assertMilestoneAchievedAt(snapshot, "fifty_events", lastEventAt);

        var summary = growthSummaryService.loadSummary(session.sessionId(), "month");
        assertThat(summary.totalEvents()).isEqualTo(50);
        assertThat(summary.uniquePhrases()).isEqualTo(10);
        assertThat(summary.uniqueActivities()).isEqualTo(6);
        assertThat(summary.cooperatingCount()).isEqualTo(25);
        assertThat(summary.practicedDays()).isEqualTo(6);
        assertThat(summary.firstEventAt()).isEqualTo(firstEventAt);
        assertThat(summary.lastEventAt()).isEqualTo(lastEventAt);

        var insights = growthInsightsService.loadInsights(session.sessionId(), "month");
        assertThat(insights.stats().totalEvents()).isEqualTo(50);
        assertThat(insights.stats().uniquePhrases()).isEqualTo(10);
        assertThat(insights.windowStart()).isEqualTo(monthWindow.windowStart());
        assertThat(insights.windowEnd()).isEqualTo(monthWindow.windowEnd());
        assertThat(insights.stats().uniqueActivities()).isEqualTo(6);
        assertThat(insights.stats().practicedDays()).isEqualTo(6);
        assertThat(insights.stats().firstEventAt()).isEqualTo(firstEventAt);
        assertThat(insights.stats().lastEventAt()).isEqualTo(lastEventAt);
        var bucketStarts = insights.bars().stream()
                .map(GrowthInsightsService.BarBucket::bucketStart)
                .toList();
        assertThat(bucketStarts)
                .hasSizeGreaterThan(1)
                .containsExactlyElementsOf(bucketStarts.stream().sorted().toList())
                .doesNotHaveDuplicates();
        assertThat(insights.bars().stream().mapToLong(GrowthInsightsService.BarBucket::count).sum())
                .isEqualTo(50L);
        assertThat(insights.scenes())
                .extracting(
                        GrowthInsightsService.SceneEntry::spaceId,
                        GrowthInsightsService.SceneEntry::eventCount,
                        GrowthInsightsService.SceneEntry::activityCount
                )
                .containsExactly(
                        tuple("daily_care", 15L, 1),
                        tuple("family_rhythm", 10L, 1),
                        tuple("growth_test_space_1", 8L, 1),
                        tuple("growth_test_space_2", 7L, 1),
                        tuple("growth_test_space_3", 6L, 1)
                );
    }

    @Test
    void todayAndYesterdayAreConsecutivePracticeDays() {
        var installationId = "growth-streak-two-days";
        var session = createAcceptedSession("13800139102", installationId);
        insertPracticeEvent(session, installationId, "today", "daily_care", "bath_time", practiceTime(0));
        insertPracticeEvent(session, installationId, "yesterday", "daily_care", "bath_time", practiceTime(1));

        var streak = growthInsightsService().loadInsights(session.sessionId(), "week").streak();

        assertThat(streak.currentStreak()).isEqualTo(2);
        assertThat(streak.longestStreak()).isEqualTo(2);
        assertThat(streak.totalDaysPracticed()).isEqualTo(2);
    }

    @Test
    void currentStreakAndLongestStreakComeFromIndependentSegments() {
        var installationId = "growth-streak-segments";
        var session = createAcceptedSession("13800139103", installationId);
        insertPracticeEvent(session, installationId, "today", "daily_care", "bath_time", practiceTime(0));
        insertPracticeEvent(session, installationId, "yesterday", "daily_care", "bath_time", practiceTime(1));
        for (int daysAgo = 10; daysAgo <= 14; daysAgo++) {
            insertPracticeEvent(
                    session,
                    installationId,
                    "older-" + daysAgo,
                    "family_rhythm",
                    "feeding_time",
                    practiceTime(daysAgo)
            );
        }

        var streak = growthInsightsService().loadInsights(session.sessionId(), "week").streak();

        assertThat(streak.currentStreak()).isEqualTo(2);
        assertThat(streak.longestStreak()).isEqualTo(5);
        assertThat(streak.totalDaysPracticed()).isEqualTo(7);
    }

    @Test
    void currentStreakIsZeroWhenNewestPracticeIsOlderThanYesterday() {
        var installationId = "growth-streak-stale";
        var session = createAcceptedSession("13800139104", installationId);
        insertPracticeEvent(session, installationId, "two-days-ago", "daily_care", "bath_time", practiceTime(2));

        var streak = growthInsightsService().loadInsights(session.sessionId(), "week").streak();

        assertThat(streak.currentStreak()).isZero();
        assertThat(streak.longestStreak()).isEqualTo(1);
        assertThat(streak.totalDaysPracticed()).isEqualTo(1);
    }

    @Test
    void scenePercentagesUseEventTotal() {
        var installationId = "growth-scene-percentages";
        var session = createAcceptedSession("13800139105", installationId);
        insertPracticeEvent(session, installationId, "daily-1", "daily_care", "bath_time", practiceTime(0));
        insertPracticeEvent(session, installationId, "daily-2", "daily_care", "bath_time", practiceTime(0));
        insertPracticeEvent(session, installationId, "family-1", "family_rhythm", "feeding_time", practiceTime(0));
        insertPracticeEvent(session, installationId, "family-2", "family_rhythm", "feeding_time", practiceTime(0));
        insertPracticeEvent(session, installationId, "family-3", "family_rhythm", "feeding_time", practiceTime(0));

        var scenes = growthInsightsService().loadInsights(session.sessionId(), "week").scenes();

        assertThat(scenes).hasSize(2);
        assertThat(scenes)
                .allSatisfy(scene -> assertThat(scene.percentage()).isBetween(0.0, 100.0));
        assertThat(scenes.stream().mapToDouble(GrowthInsightsService.SceneEntry::percentage).sum())
                .isCloseTo(100.0, org.assertj.core.data.Offset.offset(0.000001));
    }

    private void installPracticeScenes() {
        for (int index = 1; index <= 4; index++) {
            var spaceId = "growth_test_space_" + index;
            var activityId = "growth_test_activity_" + index;
            jdbcTemplate.update("""
                    insert into practice_spaces (slug, title_zh, description_zh, sort_order)
                    values (?, ?, 'Growth mapper PostgreSQL fixture', ?)
                    on conflict (slug) do nothing
                    """,
                    spaceId,
                    "测试场景 " + index,
                    90 + index
            );
            jdbcTemplate.update("""
                    insert into practice_activities (
                        slug, space_id, title_zh, scene_tag_en, coach_tip, sort_order
                    )
                    values (
                        ?,
                        (select id from practice_spaces where slug = ?),
                        ?,
                        ?,
                        'Test fixture only',
                        ?
                    )
                    on conflict (slug) do nothing
                    """,
                    activityId,
                    spaceId,
                    "测试活动 " + index,
                    "Test scene " + index,
                    90 + index
            );
        }
    }

    private void insertEventsInReverseOrder(
            AuthConsentSyncService.SessionResponse session,
            String installationId,
            Instant windowStart
    ) {
        for (int index = 49; index >= 0; index--) {
            var scene = sceneAt(index);
            jdbcTemplate.update("""
                    insert into interaction_events (
                        event_key, account_id, session_id, installation_id, local_event_id,
                        space_id, activity_id, phrase_id, reaction_type,
                        client_timestamp, received_at
                    )
                    values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    eventKey(installationId, index),
                    session.accountId(),
                    session.sessionId(),
                    installationId,
                    "evt-" + index,
                    scene.spaceId(),
                    scene.activityId(),
                    "phrase-" + index % 10,
                    index % 2 == 0 ? "cooperating" : "hesitant",
                    eventTime(windowStart, index).atOffset(ZoneOffset.UTC),
                    eventTime(windowStart, index).atOffset(ZoneOffset.UTC)
            );
        }
    }

    private GrowthInsightsService growthInsightsService() {
        return new GrowthInsightsService(
                growthInsightsMapper,
                authConsentSyncService,
                GROWTH_CLOCK
        );
    }

    private Instant practiceTime(int daysAgo) {
        return Instant.now(GROWTH_CLOCK)
                .atZone(SHANGHAI)
                .toLocalDate()
                .minusDays(daysAgo)
                .atTime(12, 0)
                .atZone(SHANGHAI)
                .toInstant();
    }

    private void insertPracticeEvent(
            AuthConsentSyncService.SessionResponse session,
            String installationId,
            String localEventId,
            String spaceId,
            String activityId,
            Instant timestamp
    ) {
        jdbcTemplate.update("""
                insert into interaction_events (
                    event_key, account_id, session_id, installation_id, local_event_id,
                    space_id, activity_id, phrase_id, reaction_type,
                    client_timestamp, received_at
                )
                values (?, ?, ?, ?, ?, ?, ?, ?, 'cooperating', ?, ?)
                """,
                installationId + ":" + localEventId,
                session.accountId(),
                session.sessionId(),
                installationId,
                localEventId,
                spaceId,
                activityId,
                "phrase-" + localEventId,
                timestamp.atOffset(ZoneOffset.UTC),
                timestamp.atOffset(ZoneOffset.UTC)
        );
    }

    private Scene sceneAt(int index) {
        if (index < 15) {
            return new Scene("daily_care", "bath_time");
        }
        if (index < 25) {
            return new Scene("family_rhythm", "feeding_time");
        }
        if (index < 33) {
            return new Scene("growth_test_space_1", "growth_test_activity_1");
        }
        if (index < 40) {
            return new Scene("growth_test_space_2", "growth_test_activity_2");
        }
        if (index < 46) {
            return new Scene("growth_test_space_3", "growth_test_activity_3");
        }
        return new Scene("growth_test_space_4", "growth_test_activity_4");
    }

    private List<String> expectedPendingKeys(String installationId) {
        var keys = new ArrayList<String>();
        for (int index = 48; index >= 29; index--) {
            keys.add(eventKey(installationId, index));
        }
        return keys;
    }

    private void assertMilestoneAchievedAt(
            GardenSnapshotService.GardenSnapshotResponse snapshot,
            String milestoneId,
            Instant expected
    ) {
        assertThat(snapshot.milestones())
                .filteredOn(milestone -> milestone.id().equals(milestoneId))
                .singleElement()
                .extracting(GardenSnapshotService.MilestoneEntry::achievedAt)
                .isEqualTo(expected);
    }

    private String eventKey(String installationId, int index) {
        return installationId + ":evt-" + index;
    }

    private Instant eventTime(Instant windowStart, int index) {
        if (index < 25) {
            return windowStart.plus(3, ChronoUnit.DAYS).plus(index * 2L, ChronoUnit.HOURS);
        }
        return windowStart.plus(17, ChronoUnit.DAYS).plus((index - 25) * 2L, ChronoUnit.HOURS);
    }

    private AuthConsentSyncService.SessionResponse createAcceptedSession(
            String phoneNumber,
            String installationId
    ) {
        var challenge = authConsentSyncService.createChallenge(phoneNumber);
        var session = authConsentSyncService.verifyChallenge(challenge.challengeId(), "246810", installationId);
        authConsentSyncService.acceptConsent(session.sessionId(), "pipl-v1");
        return session;
    }

    private record Scene(String spaceId, String activityId) {
    }
}
