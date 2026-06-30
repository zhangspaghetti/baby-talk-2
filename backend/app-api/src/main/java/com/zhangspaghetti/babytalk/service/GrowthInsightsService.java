package com.zhangspaghetti.babytalk.service;

import java.sql.Timestamp;
import java.time.Clock;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.temporal.TemporalAdjusters;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class GrowthInsightsService {

    private static final ZoneId SHANGHAI = ZoneId.of("Asia/Shanghai");
    private final JdbcTemplate jdbc;
    private final AuthConsentSyncService authConsentSyncService;
    private final Clock clock;

    public GrowthInsightsService(JdbcTemplate jdbc,
                                  AuthConsentSyncService authConsentSyncService) {
        this(jdbc, authConsentSyncService, Clock.systemUTC());
    }

    GrowthInsightsService(JdbcTemplate jdbc,
                           AuthConsentSyncService authConsentSyncService,
                           Clock clock) {
        this.jdbc = jdbc;
        this.authConsentSyncService = authConsentSyncService;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public GrowthInsightsResponse loadInsights(String sessionId, String periodRaw) {
        var period   = normalizePeriod(periodRaw);
        var accountId = authConsentSyncService.resolveAccountIdForGrowthSummary(sessionId);
        var now       = Instant.now(clock);
        var window    = resolveWindow(period, now);

        // --- base stats ---
        var stats = loadStats(accountId, window);

        // --- streak ---
        var streak = loadStreak(accountId, now);

        // --- bars ---
        var bars = loadBars(accountId, window, period);

        // --- scenes ---
        var scenes = loadScenes(accountId, window);

        // --- recentActivity ---
        var recentActivity = loadRecentActivity(accountId, now);

        // --- suggestion (week/month only) ---
        GrowthSuggestion suggestion = null;
        if (!period.equals("year")) {
            suggestion = loadSuggestion(accountId, window);
        }

        return new GrowthInsightsResponse(
                period, window.start(), window.end(), now,
                stats, streak, bars, scenes, recentActivity, suggestion);
    }

    // ── stats ──────────────────────────────────────────────────────────────
    private Stats loadStats(String accountId, Window window) {
        return jdbc.queryForObject(
                """
                SELECT COUNT(*)                                                   AS total_events,
                       COUNT(DISTINCT phrase_id)                                  AS unique_phrases,
                       COUNT(DISTINCT activity_id)                                AS unique_activities,
                       COUNT(*) FILTER (WHERE reaction_type = 'cooperating')      AS cooperating_count,
                       COUNT(DISTINCT DATE(client_timestamp AT TIME ZONE 'Asia/Shanghai'))
                                                                                  AS practiced_days,
                       MIN(client_timestamp)                                      AS first_event_at,
                       MAX(client_timestamp)                                      AS last_event_at
                FROM interaction_events
                WHERE account_id = ?
                  AND client_timestamp >= ?
                  AND client_timestamp < ?
                """,
                (rs, n) -> new Stats(
                        rs.getLong("total_events"),
                        rs.getInt("unique_phrases"),
                        rs.getInt("unique_activities"),
                        rs.getInt("cooperating_count"),
                        rs.getInt("practiced_days"),
                        toInstant(rs.getTimestamp("first_event_at")),
                        toInstant(rs.getTimestamp("last_event_at"))
                ),
                accountId,
                Timestamp.from(window.start()),
                Timestamp.from(window.end())
        );
    }

    // ── streak ─────────────────────────────────────────────────────────────
    private Streak loadStreak(String accountId, Instant now) {
        var today = now.atZone(SHANGHAI).toLocalDate();
        var rows = jdbc.queryForList(
                """
                SELECT DISTINCT DATE(client_timestamp AT TIME ZONE 'Asia/Shanghai') AS practice_date
                FROM interaction_events
                WHERE account_id = ?
                  AND client_timestamp >= ?
                ORDER BY practice_date DESC
                LIMIT 366
                """,
                accountId,
                Timestamp.from(now)
        );

        var dates = rows.stream()
                .map(r -> ((java.sql.Date) r.get("practice_date")).toLocalDate())
                .toList();

        int current = 0;
        int longest = 0;
        int streak  = 0;
        LocalDate prev = today;
        for (LocalDate d : dates) {
            long gap = java.time.temporal.ChronoUnit.DAYS.between(d, prev);
            if (gap <= 1) {
                streak++;
            } else {
                if (streak > longest) longest = streak;
                streak = 1;
            }
            prev = d;
        }
        if (streak > longest) longest = streak;

        // "current streak" resets if no practice today or yesterday
        if (!dates.isEmpty()) {
            long gap = java.time.temporal.ChronoUnit.DAYS.between(dates.get(0), today);
            current = (gap <= 1) ? streak : 0;
        }

        Instant lastPracticed = dates.isEmpty() ? null :
                dates.get(0).atStartOfDay(SHANGHAI).toInstant();

        return new Streak(current, longest, dates.size(), lastPracticed);
    }

    // ── bars ───────────────────────────────────────────────────────────────
    private List<BarBucket> loadBars(String accountId, Window window, String period) {
        var truncUnit = switch (period) {
            case "week"  -> "day";
            case "month" -> "week";
            default      -> "month";
        };
        return jdbc.query(
                """
                SELECT DATE_TRUNC(?, client_timestamp AT TIME ZONE 'Asia/Shanghai') AS bucket_start,
                       COUNT(*) AS count
                FROM interaction_events
                WHERE account_id = ?
                  AND client_timestamp >= ?
                  AND client_timestamp < ?
                GROUP BY bucket_start
                ORDER BY bucket_start
                """,
                (rs, n) -> new BarBucket(rs.getTimestamp("bucket_start").toInstant(), rs.getLong("count")),
                truncUnit,
                accountId,
                Timestamp.from(window.start()),
                Timestamp.from(window.end())
        );
    }

    // ── scenes ─────────────────────────────────────────────────────────────
    private List<SceneEntry> loadScenes(String accountId, Window window) {
        return jdbc.query(
                """
                SELECT COALESCE(ps.slug, ie.activity_id)   AS space_id,
                       COALESCE(ps.title_zh, ie.activity_id) AS scene_tag,
                       COUNT(*)                             AS event_count,
                       COUNT(DISTINCT ie.activity_id)       AS activity_count,
                       COUNT(*) OVER ()                     AS total
                FROM interaction_events ie
                LEFT JOIN practice_activities pa ON pa.slug = ie.activity_id
                LEFT JOIN practice_spaces ps      ON ps.id  = pa.space_id
                WHERE ie.account_id = ?
                  AND ie.client_timestamp >= ?
                  AND ie.client_timestamp < ?
                GROUP BY space_id, scene_tag
                ORDER BY event_count DESC
                LIMIT 5
                """,
                (rs, n) -> new SceneEntry(
                        rs.getString("space_id"),
                        rs.getString("scene_tag"),
                        rs.getLong("event_count"),
                        rs.getInt("activity_count"),
                        rs.getLong("total") > 0 ? (double) rs.getLong("event_count") / rs.getLong("total") * 100 : 0.0
                ),
                accountId,
                Timestamp.from(window.start()),
                Timestamp.from(window.end())
        );
    }

    // ── recentActivity ─────────────────────────────────────────────────────
    private RecentActivity loadRecentActivity(String accountId, Instant now) {
        var weekEnd   = now.atZone(SHANGHAI).with(DayOfWeek.MONDAY).toLocalDate().atStartOfDay(SHANGHAI).toInstant();
        var weekStart = weekEnd.atZone(SHANGHAI).minusWeeks(1).toInstant();


        var row = jdbc.queryForMap(
                """
                SELECT
                  COUNT(*) FILTER (WHERE client_timestamp >= ? AND client_timestamp < ?) AS this_week,
                  COUNT(*) FILTER (WHERE client_timestamp >= ? AND client_timestamp < ?) AS last_week
                FROM interaction_events
                WHERE account_id = ?
                """,
                Timestamp.from(weekEnd), Timestamp.from(now),
                Timestamp.from(weekStart), Timestamp.from(weekEnd),
                accountId
        );
        return new RecentActivity(
                ((Number) row.get("this_week")).intValue(),
                ((Number) row.get("last_week")).intValue()
        );
    }

    // ── suggestion ─────────────────────────────────────────────────────────
    private GrowthSuggestion loadSuggestion(String accountId, Window window) {
        var rows = jdbc.query(
                """
                SELECT pa.slug         AS activity_id,
                       ps.slug         AS space_id,
                       ps.title_zh     AS scene_label,
                       pp.english      AS phrase_english
                FROM practice_activities pa
                JOIN practice_spaces ps  ON ps.id = pa.space_id
                JOIN practice_phrases pp ON pp.activity_id = pa.id AND pp.step = 1
                WHERE NOT EXISTS (
                    SELECT 1 FROM interaction_events ie
                    WHERE ie.activity_id = pa.slug
                      AND ie.account_id = ?
                      AND ie.client_timestamp >= ?
                      AND ie.client_timestamp < ?
                )
                ORDER BY ps.sort_order, pa.sort_order
                LIMIT 1
                """,
                (rs, n) -> new GrowthSuggestion(
                        rs.getString("space_id"),
                        rs.getString("activity_id"),
                        rs.getString("scene_label"),
                        rs.getString("phrase_english")
                ),
                accountId,
                Timestamp.from(window.start()),
                Timestamp.from(window.end())
        );
        return rows.isEmpty() ? null : rows.get(0);
    }

    // ── window / period ────────────────────────────────────────────────────
    private String normalizePeriod(String raw) {
        if (raw == null || raw.isBlank()) return "week";
        return switch (raw.trim().toLowerCase()) {
            case "month" -> "month";
            case "year"  -> "year";
            default      -> "week";
        };
    }

    private Window resolveWindow(String period, Instant now) {
        var zoned = now.atZone(SHANGHAI);
        return switch (period) {
            case "month" -> {
                var start = zoned.with(TemporalAdjusters.firstDayOfMonth()).toLocalDate()
                        .atStartOfDay(SHANGHAI).toInstant();
                var end = zoned.with(TemporalAdjusters.firstDayOfNextMonth()).toLocalDate()
                        .atStartOfDay(SHANGHAI).toInstant();
                yield new Window(start, end);
            }
            case "year" -> {
                var start = zoned.with(TemporalAdjusters.firstDayOfYear()).toLocalDate()
                        .atStartOfDay(SHANGHAI).toInstant();
                var end = zoned.with(TemporalAdjusters.firstDayOfNextYear()).toLocalDate()
                        .atStartOfDay(SHANGHAI).toInstant();
                yield new Window(start, end);
            }
            default -> {
                var monday = zoned.with(DayOfWeek.MONDAY).toLocalDate().atStartOfDay(SHANGHAI).toInstant();
                var nextMonday = monday.atZone(SHANGHAI).plusWeeks(1).toInstant();
                yield new Window(monday, nextMonday);
            }
        };
    }

    private static Instant toInstant(Timestamp ts) {
        return ts == null ? null : ts.toInstant();
    }

    // ── Records (Response / Internal) ──────────────────────────────────────
    public record Window(Instant start, Instant end) {}

    public record Stats(long totalEvents, int uniquePhrases, int uniqueActivities,
                        int cooperatingCount, int practicedDays,
                        Instant firstEventAt, Instant lastEventAt) {}

    public record Streak(int currentStreak, int longestStreak,
                         int totalDaysPracticed, Instant lastPracticedAt) {}

    public record BarBucket(Instant bucketStart, long count) {}

    public record SceneEntry(String spaceId, String sceneTag, long eventCount,
                              int activityCount, double percentage) {}

    public record RecentActivity(int thisWeekCount, int lastWeekCount) {}

    public record GrowthSuggestion(String spaceId, String activityId,
                                    String sceneLabel, String phraseEnglish) {}

    public record GrowthInsightsResponse(
            String period,
            Instant windowStart, Instant windowEnd, Instant generatedAt,
            Stats stats,
            Streak streak,
            List<BarBucket> bars,
            List<SceneEntry> scenes,
            RecentActivity recentActivity,
            GrowthSuggestion suggestion
    ) {}
}
