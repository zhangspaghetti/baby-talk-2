package com.zhangspaghetti.babytalk.practice.scene;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import com.zhangspaghetti.babytalk.practice.generated.SceneGenerationInput;
import java.sql.Timestamp;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

class ScenePersonalizationContextServiceTest extends AbstractIntegrationTest {

    private static final OffsetDateTime WEEK_START = OffsetDateTime.parse("2026-08-31T00:00:00Z");
    private static final OffsetDateTime NOW = OffsetDateTime.parse("2026-08-31T12:00:00Z");
    private static final String INSTALLATION_REFERENCE =
            "v1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private ScenePersonalizationContextService service;

    @Test
    void householdContextAggregatesAllActiveMemberActorsAndUsesIsoWeekVersion() {
        // Catches a query that only reads the requesting actor, leaks revoked members, or uses a rolling window.
        seedAccount("acct_week_primary");
        seedAccount("acct_week_caregiver");
        seedAccount("acct_week_revoked");
        seedAccount("acct_week_outsider");
        seedSession("sess_week_primary", "acct_week_primary");
        seedSession("sess_week_caregiver", "acct_week_caregiver");
        seedSession("sess_week_revoked", "acct_week_revoked");
        seedSession("sess_week_outsider", "acct_week_outsider");
        seedHousehold("household_week", "acct_week_primary", "active");
        seedMember("household_week", "acct_week_primary", "primary_caregiver", "active");
        seedMember("household_week", "acct_week_caregiver", "caregiver", "active");
        seedMember("household_week", "acct_week_revoked", "caregiver", "revoked");
        seedEvent("acct_week_primary", "sess_week_primary", "primary-1", "daily_care", "bath_time", "cooperating", NOW.minusHours(4));
        seedEvent("acct_week_primary", "sess_week_primary", "primary-2", "daily_care", "bath_time", "cooperating", NOW.minusHours(3));
        seedEvent("acct_week_primary", "sess_week_primary", "primary-3", "family_rhythm", "feeding_time", "hesitant", NOW.minusHours(2));
        seedEvent("acct_week_caregiver", "sess_week_caregiver", "caregiver-1", "daily_care", "bath_time", "hesitant", NOW.minusHours(5));
        seedEvent("acct_week_caregiver", "sess_week_caregiver", "caregiver-2", "family_rhythm", "feeding_time", "hesitant", NOW.minusHours(6));
        seedEvent("acct_week_caregiver", "sess_week_caregiver", "caregiver-3", "play", "turn_taking", "hesitant", NOW.minusHours(7));
        seedEvent("acct_week_caregiver", "sess_week_caregiver", "caregiver-4", "play", "turn_taking", "hesitant", NOW.minusHours(8));
        seedEvent("acct_week_revoked", "sess_week_revoked", "revoked-1", "private", "revoked_activity", "resisting", NOW.minusHours(1));
        seedEvent("acct_week_outsider", "sess_week_outsider", "outsider-1", "private", "outsider_activity", "resisting", NOW.minusHours(1));
        seedEvent("acct_week_primary", "sess_week_primary", "before-week", "old", "old_activity", "resisting", WEEK_START.minusNanos(1_000));

        var context = service.build(householdSubject("household_week", "acct_week_caregiver"), "zh-CN", NOW);

        assertThat(context.recentPracticeCount()).isEqualTo(7);
        assertThat(context.dominantReaction()).isEqualTo("hesitant");
        assertThat(context.recentActivitySummary())
                .isEqualTo("daily_care/bath_time=3,family_rhythm/feeding_time=2,play/turn_taking=2");
        assertThat(context.householdContextVersion()).isEqualTo("2026-W36");
    }

    @Test
    void revokedHouseholdAndRevokedMembersAreExcludedFromHouseholdContext() {
        // Catches missing active predicates that let revoked memberships or revoked households influence prompts.
        seedAccount("acct_revoke_primary");
        seedAccount("acct_revoke_member");
        seedSession("sess_revoke_primary", "acct_revoke_primary");
        seedSession("sess_revoke_member", "acct_revoke_member");
        seedHousehold("household_revoke", "acct_revoke_primary", "active");
        seedMember("household_revoke", "acct_revoke_primary", "primary_caregiver", "active");
        seedMember("household_revoke", "acct_revoke_member", "caregiver", "revoked");
        seedEvent("acct_revoke_primary", "sess_revoke_primary", "active-1", "daily_care", "bath_time", "cooperating", NOW);
        seedEvent("acct_revoke_member", "sess_revoke_member", "revoked-member-1", "private", "revoked_activity", "resisting", NOW);

        var subject = householdSubject("household_revoke", "acct_revoke_primary");
        var activeContext = service.build(subject, "zh-CN", NOW);
        assertThat(activeContext.recentPracticeCount()).isEqualTo(1);
        assertThat(activeContext.dominantReaction()).isEqualTo("cooperating");

        jdbcTemplate.update("update households set status = 'revoked' where household_id = ?", "household_revoke");

        var revokedContext = service.build(subject, "zh-CN", NOW);
        assertThat(revokedContext.recentPracticeCount()).isZero();
        assertThat(revokedContext.dominantReaction()).isNull();
        assertThat(revokedContext.recentActivitySummary()).isEmpty();
    }

    @Test
    void standaloneContextAggregatesOwnerEventsOnly() {
        // Catches an owner query that accidentally aggregates every account or household member in the database.
        seedAccount("acct_standalone_owner");
        seedAccount("acct_standalone_other");
        seedSession("sess_standalone_owner", "acct_standalone_owner");
        seedSession("sess_standalone_other", "acct_standalone_other");
        seedEvent("acct_standalone_owner", "sess_standalone_owner", "owner-1", "daily_care", "bath_time", "cooperating", NOW.minusHours(1));
        seedEvent("acct_standalone_owner", "sess_standalone_owner", "owner-2", "daily_care", "bath_time", "hesitant", NOW.minusHours(2));
        seedEvent("acct_standalone_other", "sess_standalone_other", "other-1", "private", "other_activity", "resisting", NOW.minusHours(1));
        seedEvent("acct_standalone_other", "sess_standalone_other", "other-2", "private", "other_activity", "resisting", NOW.minusHours(2));

        var context = service.build(standaloneSubject("acct_standalone_owner"), "zh-CN", NOW);

        assertThat(context.recentPracticeCount()).isEqualTo(2);
        assertThat(context.dominantReaction()).isEqualTo("cooperating");
        assertThat(context.recentActivitySummary()).isEqualTo("daily_care/bath_time=2");
    }

    @Test
    void weeklyWindowIncludesMondayStartAndNowButExcludesOutsideEvents() {
        // Catches local-time week calculations and inclusive/exclusive predicates that drift from the advertised window.
        var localNow = NOW.withOffsetSameInstant(ZoneOffset.ofHours(8));
        seedAccount("acct_boundary");
        seedSession("sess_boundary", "acct_boundary");
        seedEvent("acct_boundary", "sess_boundary", "at-start", "daily_care", "bath_time", "cooperating", WEEK_START);
        seedEvent("acct_boundary", "sess_boundary", "at-now", "daily_care", "bath_time", "hesitant", NOW);
        seedEvent("acct_boundary", "sess_boundary", "before-start", "private", "before", "resisting", WEEK_START.minusNanos(1_000));
        seedEvent("acct_boundary", "sess_boundary", "after-now", "private", "after", "resisting", NOW.plusNanos(1_000));

        var context = service.build(standaloneSubject("acct_boundary"), "zh-CN", localNow);

        assertThat(context.recentPracticeCount()).isEqualTo(2);
        assertThat(context.recentActivitySummary()).isEqualTo("daily_care/bath_time=2");
    }

    @Test
    void isoWeekVersionChangesAcrossCalendarYearBoundary() {
        // Catches calendar-year formatting that reports 2027-W01 for an instant belonging to ISO week 2026-W53.
        seedAccount("acct_iso_boundary");
        var subject = standaloneSubject("acct_iso_boundary");

        var endOfIsoYear = service.build(subject, "zh-CN", OffsetDateTime.parse("2027-01-01T12:00:00Z"));
        var nextIsoYear = service.build(subject, "zh-CN", OffsetDateTime.parse("2027-01-04T00:00:00Z"));

        assertThat(endOfIsoYear.householdContextVersion()).isEqualTo("2026-W53");
        assertThat(nextIsoYear.householdContextVersion()).isEqualTo("2027-W01");
    }

    @Test
    void emptyHistoryKeepsCoreProfileAndReturnsZeroCountContext() {
        // Catches null aggregate rows and fallback code that drops the server-resolved baby profile.
        var context = service.build(
                new GenerationSubject(
                        "acct_empty_owner",
                        "acct_empty_owner",
                        "babyprof_empty",
                        9,
                        "小满",
                        "m7_11",
                        "keep_talking",
                        null,
                        "primary_caregiver"
                ),
                "zh-CN",
                NOW
        );

        assertThat(context.babyName()).isEqualTo("小满");
        assertThat(context.ageRange()).isEqualTo("m7_11");
        assertThat(context.parentGoal()).isEqualTo("keep_talking");
        assertThat(context.locale()).isEqualTo("zh-CN");
        assertThat(context.actorRole()).isEqualTo("primary_caregiver");
        assertThat(context.recentPracticeCount()).isZero();
        assertThat(context.dominantReaction()).isNull();
        assertThat(context.recentActivitySummary()).isEmpty();
        assertThat(context.householdContextVersion()).isEqualTo("2026-W36");
    }

    @Test
    void activitySummaryIsBoundedToFiveAndUsesStableIdOrderOnTies() {
        // Catches unbounded prompt growth and nondeterministic database order for equal-count activities.
        seedAccount("acct_top_five");
        seedSession("sess_top_five", "acct_top_five");
        var activities = List.of(
                new Activity("space_a", "activity_a"),
                new Activity("space_a", "activity_b"),
                new Activity("space_b", "activity_a"),
                new Activity("space_c", "activity_a"),
                new Activity("space_d", "activity_a"),
                new Activity("space_e", "activity_a"),
                new Activity("space_f", "activity_a")
        );
        for (int index = 0; index < activities.size(); index++) {
            var activity = activities.get(index);
            seedEvent(
                    "acct_top_five",
                    "sess_top_five",
                    "top-five-" + index,
                    activity.spaceId(),
                    activity.activityId(),
                    "cooperating",
                    NOW.minusMinutes(index + 1L)
            );
        }

        var context = service.build(standaloneSubject("acct_top_five"), "zh-CN", NOW);

        assertThat(context.recentPracticeCount()).isEqualTo(7);
        assertThat(context.recentActivitySummary())
                .isEqualTo("space_a/activity_a=1,space_a/activity_b=1,space_b/activity_a=1,space_c/activity_a=1,space_d/activity_a=1")
                .doesNotContain("space_e", "space_f");
    }

    @Test
    void dominantReactionTieUsesCanonicalReactionOrder() {
        // Catches database-dependent tie selection; canonical order is cooperating, hesitant, resisting, no_response, other.
        seedAccount("acct_reaction_tie");
        seedSession("sess_reaction_tie", "acct_reaction_tie");
        seedEvent("acct_reaction_tie", "sess_reaction_tie", "tie-cooperating", "daily_care", "bath_time", "cooperating", NOW.minusHours(1));
        seedEvent("acct_reaction_tie", "sess_reaction_tie", "tie-hesitant", "daily_care", "bath_time", "hesitant", NOW.minusHours(2));

        var context = service.build(standaloneSubject("acct_reaction_tie"), "zh-CN", NOW);

        assertThat(context.dominantReaction()).isEqualTo("cooperating");
    }

    @Test
    void activitySummarySkipsUnsafeIdsInsteadOfEmbeddingPromptOrIdentifierText() {
        // Catches prompt/diagnostic injection through commas, delimiters, newlines, spaces, and account-like values.
        var mapper = mock(ScenePersonalizationContextMapper.class);
        when(mapper.findWeeklyReactionCounts(any(), any(), any(), any()))
                .thenReturn(new ScenePersonalizationContextMapper.WeeklyReactionCounts(6, 6, 0, 0, 0, 0));
        when(mapper.findTopWeeklyActivities(any(), any(), any(), any()))
                .thenReturn(List.of(
                        new ScenePersonalizationContextMapper.ActivityCount("safe-space", "safe-activity", 1),
                        new ScenePersonalizationContextMapper.ActivityCount("unsafe,space", "safe-activity", 1),
                        new ScenePersonalizationContextMapper.ActivityCount("unsafe=space", "safe-activity", 1),
                        new ScenePersonalizationContextMapper.ActivityCount("unsafe\nspace", "safe-activity", 1),
                        new ScenePersonalizationContextMapper.ActivityCount("prompt injection", "safe-activity", 1),
                        new ScenePersonalizationContextMapper.ActivityCount("acct_secret!", "safe-activity", 1)
                ));

        var context = new ScenePersonalizationContextService(mapper)
                .build(standaloneSubject("acct_summary_safety"), "zh-CN", NOW);

        assertThat(context.recentPracticeCount()).isEqualTo(6);
        assertThat(context.dominantReaction()).isEqualTo("cooperating");
        assertThat(context.recentActivitySummary()).isEqualTo("safe-space/safe-activity=1");
        assertThat(context.recentActivitySummary())
                .doesNotContain("unsafe,space", "unsafe=space", "unsafe\nspace", "prompt injection", "acct_secret!");
    }

    @Test
    void activitySummaryCapsTotalLengthWithoutTruncatingAnEntry() {
        // Catches a five-entry summary that exceeds the prompt boundary or truncates a legal entry halfway.
        var mapper = mock(ScenePersonalizationContextMapper.class);
        when(mapper.findWeeklyReactionCounts(any(), any(), any(), any()))
                .thenReturn(new ScenePersonalizationContextMapper.WeeklyReactionCounts(5, 5, 0, 0, 0, 0));
        var longActivities = new ArrayList<ScenePersonalizationContextMapper.ActivityCount>();
        for (int index = 0; index < 5; index++) {
            longActivities.add(new ScenePersonalizationContextMapper.ActivityCount(
                    "s" + "a".repeat(94) + index,
                    "a" + "b".repeat(94) + index,
                    1
            ));
        }
        when(mapper.findTopWeeklyActivities(any(), any(), any(), any())).thenReturn(longActivities);

        var summary = new ScenePersonalizationContextService(mapper)
                .build(standaloneSubject("acct_summary_cap"), "zh-CN", NOW)
                .recentActivitySummary();

        assertThat(summary).hasSizeLessThanOrEqualTo(512);
        assertThat(summary.split(",", -1))
                .allMatch(entry -> entry.matches("[a-z0-9][a-z0-9_-]{0,95}/[a-z0-9][a-z0-9_-]{0,95}=1"));
        assertThat(summary.split(",", -1)).hasSizeLessThan(5);
    }

    @Test
    void contextToStringExcludesBabyAndAccountPhoneHouseholdAndRawInteractionValues() {
        // Catches default record toString logging baby names and identifiers that must stay out of diagnostics.
        var context = new ScenePersonalizationContext(
                "小满",
                "m7_11",
                "keep_talking",
                "zh-CN",
                "caregiver",
                7,
                "hesitant",
                "daily_care/bath_time=7",
                "2026-W36"
        );

        assertThat(context.toString())
                .doesNotContain("小满", "acct_privacy", "13800138000", "household_privacy", "raw interaction text")
                .contains("locale='zh-CN'", "actorRole='caregiver'", "recentPracticeCount=7", "dominantReaction='hesitant'", "householdContextVersion='2026-W36'");
    }

    @Test
    void aggregationRuntimeFailureFallsBackToCoreProfileAndZeroCounts() {
        // Catches provider-generation failures caused by telemetry/aggregation outages instead of preserving safe core context.
        var failingMapper = mock(ScenePersonalizationContextMapper.class);
        when(failingMapper.findWeeklyReactionCounts(anyString(), anyString(), any(), any()))
                .thenThrow(new IllegalStateException("raw interaction text must not enter diagnostics"));
        var failingService = new ScenePersonalizationContextService(failingMapper);
        var subject = new GenerationSubject(
                "acct_fallback_actor",
                "acct_fallback_owner",
                "babyprof_fallback",
                3,
                "小满",
                "m7_11",
                "keep_talking",
                "household_fallback",
                "caregiver"
        );

        var context = failingService.build(subject, "zh-CN", NOW);

        assertThat(context.babyName()).isEqualTo("小满");
        assertThat(context.ageRange()).isEqualTo("m7_11");
        assertThat(context.parentGoal()).isEqualTo("keep_talking");
        assertThat(context.locale()).isEqualTo("zh-CN");
        assertThat(context.actorRole()).isEqualTo("caregiver");
        assertThat(context.recentPracticeCount()).isZero();
        assertThat(context.dominantReaction()).isNull();
        assertThat(context.recentActivitySummary()).isEmpty();
        assertThat(context.householdContextVersion()).isEqualTo("2026-W36");
        assertThat(context.toString()).doesNotContain("raw interaction text", "acct_fallback", "household_fallback", "小满");
    }

    @Test
    void generationInputToStringDoesNotExposeSceneSubjectOrPersonalizationValues() {
        // Catches default record toString leaking prompt text and nested profile/household values into logs.
        var subject = new GenerationSubject(
                "acct_input_actor",
                "acct_input_owner",
                "babyprof_input",
                4,
                "小满",
                "m7_11",
                "keep_talking",
                "household_input",
                "caregiver"
        );
        var personalization = new ScenePersonalizationContext(
                "小满",
                "m7_11",
                "keep_talking",
                "zh-CN",
                "caregiver",
                2,
                "cooperating",
                "daily_care/bath_time=2",
                "2026-W36"
        );
        var input = new SceneGenerationInput(
                "custom",
                "raw resolved scene text",
                subject,
                personalization,
                null,
                null,
                "daily_care",
                "bath_time",
                "zh-CN",
                "client-request-input"
        );

        assertThat(input.toString())
                .contains("inputSource='custom'", "preset=false")
                .doesNotContain(
                        "raw resolved scene text",
                        "acct_input_actor",
                        "acct_input_owner",
                        "babyprof_input",
                        "household_input",
                        "小满",
                        "daily_care",
                        "bath_time",
                        "client-request-input"
                );
    }

    private GenerationSubject householdSubject(String householdId, String actorAccountId) {
        return new GenerationSubject(
                actorAccountId,
                "acct_week_primary",
                "babyprof_week",
                2,
                "小满",
                "m7_11",
                "keep_talking",
                householdId,
                "caregiver"
        );
    }

    private GenerationSubject standaloneSubject(String ownerAccountId) {
        return new GenerationSubject(
                ownerAccountId,
                ownerAccountId,
                "babyprof_" + ownerAccountId,
                1,
                "小满",
                "m7_11",
                "keep_talking",
                null,
                "primary_caregiver"
        );
    }

    private void seedAccount(String accountId) {
        jdbcTemplate.update(
                """
                insert into accounts (
                    account_id, phone_lookup_ref, phone_mask, status,
                    latest_consent_status, created_at, deleted_at
                ) values (?, ?, '138****8000', 'active', 'accepted', ?, null)
                """,
                accountId,
                "test-phone-ref:" + accountId,
                Timestamp.from(NOW.toInstant())
        );
    }

    private void seedSession(String sessionId, String accountId) {
        jdbcTemplate.update(
                """
                insert into account_sessions (
                    session_id, account_id, installation_id, status, created_at, revoked_at
                ) values (?, ?, ?, 'active', ?, null)
                """,
                sessionId,
                accountId,
                "installation-" + accountId,
                Timestamp.from(NOW.toInstant())
        );
    }

    private void seedHousehold(String householdId, String ownerAccountId, String status) {
        jdbcTemplate.update(
                """
                insert into households (
                    household_id, owner_account_id, status, created_at, revoked_at
                ) values (?, ?, ?, ?, null)
                """,
                householdId,
                ownerAccountId,
                status,
                Timestamp.from(NOW.toInstant())
        );
    }

    private void seedMember(String householdId, String accountId, String role, String status) {
        jdbcTemplate.update(
                """
                insert into household_members (
                    household_id, account_id, role, status, invited_by_account_id,
                    joined_at, last_accepted_at
                ) values (?, ?, ?, ?, null, ?, null)
                """,
                householdId,
                accountId,
                role,
                status,
                Timestamp.from(NOW.toInstant())
        );
    }

    private void seedEvent(
            String accountId,
            String sessionId,
            String localEventId,
            String spaceId,
            String activityId,
            String reactionType,
            OffsetDateTime clientTimestamp
    ) {
        var eventKey = "e1:" + String.format("%043d", eventSequence++);
        jdbcTemplate.update(
                """
                insert into interaction_events (
                    event_key, account_id, session_id, installation_id, local_event_id,
                    space_id, activity_id, phrase_id, reaction_type, client_timestamp, received_at
                ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                eventKey,
                accountId,
                sessionId,
                INSTALLATION_REFERENCE,
                localEventId,
                spaceId,
                activityId,
                "phrase-" + localEventId,
                reactionType,
                Timestamp.from(clientTimestamp.toInstant()),
                Timestamp.from(clientTimestamp.toInstant())
        );
    }

    private int eventSequence;

    private record Activity(String spaceId, String activityId) {
    }
}
