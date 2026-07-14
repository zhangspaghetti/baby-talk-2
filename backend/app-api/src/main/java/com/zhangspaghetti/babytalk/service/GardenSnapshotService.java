package com.zhangspaghetti.babytalk.service;

import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class GardenSnapshotService {

    private static final ZoneId SHANGHAI = ZoneId.of("Asia/Shanghai");

    private final JdbcTemplate jdbc;
    private final AuthConsentSyncService authConsentSyncService;
    private final Clock clock;

    @Autowired
    public GardenSnapshotService(JdbcTemplate jdbc,
                                 AuthConsentSyncService authConsentSyncService) {
        this(jdbc, authConsentSyncService, Clock.systemUTC());
    }

    GardenSnapshotService(JdbcTemplate jdbc,
                          AuthConsentSyncService authConsentSyncService,
                          Clock clock) {
        this.jdbc = jdbc;
        this.authConsentSyncService = authConsentSyncService;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public GardenSnapshotResponse loadSnapshot(String sessionId) {
        var accountId = authConsentSyncService.resolveAccountIdForGrowthSummary(sessionId);
        var now = Instant.now(clock);
        var today = now.atZone(SHANGHAI).toLocalDate();

        // --- aggregate stats ---
        var stats = jdbc.queryForObject(
                """
                SELECT COUNT(*)                                                    AS known_events,
                       COUNT(DISTINCT ie.phrase_id)                                AS unique_phrases,
                       COUNT(DISTINCT ps.slug)                                     AS covered_space_count,
                       MIN(client_timestamp)                                       AS first_event_at
                FROM interaction_events ie
                LEFT JOIN practice_activities pa ON pa.slug = ie.activity_id
                LEFT JOIN practice_spaces ps     ON ps.id  = pa.space_id
                WHERE ie.account_id = ?
                """,
                (rs, n) -> new StatsSnapshot(
                        rs.getLong("known_events"),
                        rs.getInt("unique_phrases"),
                        rs.getInt("covered_space_count"),
                        toInstant(rs.getTimestamp("first_event_at"))
                ),
                accountId
        );

        // --- current streak ---
        var currentStreakDays = computeCurrentStreak(accountId, today);

        // --- milestones ---
        var milestones = computeMilestones(accountId, stats, currentStreakDays, now);

        // --- pending event keys ---
        var pendingEventKeys = jdbc.queryForList(
                """
                SELECT ie.event_key
                FROM interaction_events ie
                WHERE ie.account_id = ?
                  AND NOT EXISTS (
                      SELECT 1 FROM garden_fertilizer_claim_log gfcl
                      WHERE gfcl.user_id = ie.account_id
                        AND gfcl.event_key = ie.event_key
                  )
                ORDER BY ie.client_timestamp DESC
                LIMIT 20
                """,
                String.class,
                accountId
        );

        return new GardenSnapshotResponse(
                now,
                stats.knownEvents(),
                stats.coveredSpaceCount(),
                currentStreakDays,
                milestones,
                pendingEventKeys
        );
    }

    // ── streak ─────────────────────────────────────────────────────────────
    private int computeCurrentStreak(String accountId, LocalDate today) {
        var todayTimestamp = Timestamp.from(today.atStartOfDay(SHANGHAI).toInstant());
        var rows = jdbc.queryForList(
                """
                SELECT DISTINCT DATE(client_timestamp AT TIME ZONE 'Asia/Shanghai') AS practice_date
                FROM interaction_events
                WHERE account_id = ?
                  AND client_timestamp >= ? - INTERVAL '365 days'
                ORDER BY practice_date DESC
                """,
                accountId,
                todayTimestamp
        );

        if (rows.isEmpty()) return 0;

        var dates = rows.stream()
                .map(r -> ((java.sql.Date) r.get("practice_date")).toLocalDate())
                .toList();

        // If last practice was > 1 day ago, streak is 0
        long gapFromToday = ChronoUnit.DAYS.between(dates.get(0), today);
        if (gapFromToday > 1) return 0;

        // Count consecutive days from most recent going backwards
        int streak = 1;
        for (int i = 1; i < dates.size(); i++) {
            long gap = ChronoUnit.DAYS.between(dates.get(i), dates.get(i - 1));
            if (gap == 1) {
                streak++;
            } else {
                break;
            }
        }
        return streak;
    }

    // ── milestones ─────────────────────────────────────────────────────────
    private List<MilestoneEntry> computeMilestones(
            String accountId, StatsSnapshot stats, int currentStreakDays, Instant now) {
        var milestones = new ArrayList<MilestoneEntry>();

        // 1. first_practice
        if (stats.knownEvents() >= 1) {
            milestones.add(new MilestoneEntry(
                    "first_practice", "初次练习", 1,
                    stats.firstEventAt(), null
            ));
        } else {
            milestones.add(new MilestoneEntry(
                    "first_practice", "初次练习", 1, null,
                    "完成第一次练习即可解锁"
            ));
        }

        // 2. ten_phrases
        if (stats.uniquePhrases() >= 10) {
            var achievedAt = jdbc.queryForObject(
                    """
                    SELECT achieved_at FROM (
                        SELECT MIN(client_timestamp) AS achieved_at,
                               ROW_NUMBER() OVER (ORDER BY MIN(client_timestamp)) AS rn
                        FROM interaction_events
                        WHERE account_id = ?
                        GROUP BY phrase_id
                    ) sub
                    WHERE rn = 10
                    """,
                    Timestamp.class, accountId
            );
            milestones.add(new MilestoneEntry(
                    "ten_phrases", "十句达人", 2,
                    achievedAt != null ? achievedAt.toInstant() : null, null
            ));
        } else {
            milestones.add(new MilestoneEntry(
                    "ten_phrases", "十句达人", 2, null,
                    "再学 " + (10 - stats.uniquePhrases()) + " 个短语即可解锁"
            ));
        }

        // 3. three_spaces
        if (stats.coveredSpaceCount() >= 3) {
            var achievedAt = jdbc.queryForObject(
                    """
                    SELECT achieved_at FROM (
                        SELECT MIN(ie.client_timestamp) AS achieved_at,
                               ROW_NUMBER() OVER (ORDER BY MIN(ie.client_timestamp)) AS rn
                        FROM interaction_events ie
                        JOIN practice_activities pa ON pa.slug = ie.activity_id
                        JOIN practice_spaces ps     ON ps.id  = pa.space_id
                        WHERE ie.account_id = ?
                        GROUP BY ps.slug
                    ) sub
                    WHERE rn = 3
                    """,
                    Timestamp.class, accountId
            );
            milestones.add(new MilestoneEntry(
                    "three_spaces", "三场景探索", 3,
                    achievedAt != null ? achievedAt.toInstant() : null, null
            ));
        } else {
            milestones.add(new MilestoneEntry(
                    "three_spaces", "三场景探索", 3, null,
                    "再探索 " + (3 - stats.coveredSpaceCount()) + " 个场景即可解锁"
            ));
        }

        // 4. streak_7
        if (currentStreakDays >= 7) {
            var achievedAt = now.atZone(SHANGHAI).toLocalDate()
                    .minusDays(6)
                    .atStartOfDay(SHANGHAI).toInstant();
            milestones.add(new MilestoneEntry(
                    "streak_7", "连续七天", 4, achievedAt, null
            ));
        } else {
            milestones.add(new MilestoneEntry(
                    "streak_7", "连续七天", 4, null,
                    "再坚持 " + (7 - currentStreakDays) + " 天即可解锁"
            ));
        }

        // 5. fifty_events
        if (stats.knownEvents() >= 50) {
            var achievedAt = jdbc.queryForObject(
                    """
                    SELECT client_timestamp FROM interaction_events
                    WHERE account_id = ?
                    ORDER BY client_timestamp ASC
                    OFFSET 49 LIMIT 1
                    """,
                    Timestamp.class, accountId
            );
            milestones.add(new MilestoneEntry(
                    "fifty_events", "五十次里程碑", 5,
                    achievedAt != null ? achievedAt.toInstant() : null, null
            ));
        } else {
            milestones.add(new MilestoneEntry(
                    "fifty_events", "五十次里程碑", 5, null,
                    "再练习 " + (50 - stats.knownEvents()) + " 次即可解锁"
            ));
        }

        return milestones;
    }

    private static Instant toInstant(Timestamp ts) {
        return ts == null ? null : ts.toInstant();
    }

    // ── Records ────────────────────────────────────────────────────────────

    private record StatsSnapshot(long knownEvents, int uniquePhrases, int coveredSpaceCount, Instant firstEventAt) {}

    public record MilestoneEntry(
            String id,
            String title,
            int sortOrder,
            Instant achievedAt,
            String remainingHint
    ) {}

    public record GardenSnapshotResponse(
            Instant generatedAt,
            long knownEvents,
            int coveredSpaceCount,
            int currentStreakDays,
            List<MilestoneEntry> milestones,
            List<String> pendingEventKeys
    ) {}
}
