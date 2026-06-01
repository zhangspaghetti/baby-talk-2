package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.web.ContractException;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.time.temporal.TemporalAdjusters;
import java.util.List;
import java.util.Locale;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class GrowthInsightsService {

    private static final ZoneId ZONE_SHANGHAI = ZoneId.of("Asia/Shanghai");

    private final JdbcTemplate jdbcTemplate;
    private final AuthConsentSyncService authConsentSyncService;
    private final Clock clock;

    public GrowthInsightsService(JdbcTemplate jdbcTemplate, AuthConsentSyncService authConsentSyncService, Clock clock) {
        this.jdbcTemplate = jdbcTemplate;
        this.authConsentSyncService = authConsentSyncService;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public GrowthInsightsResponse loadInsights(String sessionId, String periodRaw) {
        var period = normalizePeriod(periodRaw);
        var accountId = authConsentSyncService.resolveAccountIdForGrowthSummary(sessionId);
        var now = Instant.now(clock);
        var window = resolveWindow(period, now);
        var prevWindow = resolvePreviousWindow(period, window);

        var stats = loadStats(accountId, window);
        var streak = loadStreak(accountId, now);
        var bars = loadBars(accountId, window, period);
        var scenes = loadScenes(accountId, window);
        var recentActivity = loadRecentActivity(accountId, window, prevWindow);
        var suggestion = ("week".equals(period) || "month".equals(period))
                ? loadSuggestion(accountId, window)
                : null;

        return new GrowthInsightsResponse(
                period,
                window.start(),
                window.end(),
                now,
                stats,
                streak,
                bars,
                scenes,
                recentActivity,
                suggestion
        );
    }

    // ── Stats ────────────────────────────────────────────────────────────────

    private Stats loadStats(String accountId, Window window) {
        return jdbcTemplate.queryForObject(
                """
                select count(*) as total_events,
                       count(distinct phrase_id) as unique_phrases,
                       count(distinct activity_id) as unique_activities,
                       count(*) filter (where reaction_type = 'imitated') as imitation_count,
                       count(distinct (client_timestamp at time zone 'Asia/Shanghai')::date) as practiced_days
                from interaction_events
                where account_id = ?
                  and client_timestamp >= ?
                  and client_timestamp < ?
                """,
                (rs, rowNum) -> new Stats(
                        rs.getInt("total_events"),
                        rs.getInt("unique_phrases"),
                        rs.getInt("unique_activities"),
                        rs.getInt("imitation_count"),
                        rs.getInt("practiced_days")
                ),
                accountId,
                Timestamp.from(window.start()),
                Timestamp.from(window.end())
        );
    }

    // ── Streak ───────────────────────────────────────────────────────────────

    private Streak loadStreak(String accountId, Instant now) {
        var todayShanghai = LocalDate.now(ZONE_SHANGHAI);
        // Walk backwards from today to find the current streak
        int currentStreak = 0;
        var checkDate = todayShanghai;
        while (true) {
            var dayStart = checkDate.atStartOfDay(ZONE_SHANGHAI).toInstant();
            var dayEnd = checkDate.plusDays(1).atStartOfDay(ZONE_SHANGHAI).toInstant();
            Integer count = jdbcTemplate.queryForObject(
                    """
                    select count(*) from interaction_events
                    where account_id = ?
                      and client_timestamp >= ?
                      and client_timestamp < ?
                    """,
                    Integer.class,
                    accountId,
                    Timestamp.from(dayStart),
                    Timestamp.from(dayEnd)
            );
            if (count != null && count > 0) {
                currentStreak++;
                checkDate = checkDate.minusDays(1);
            } else {
                break;
            }
        }

        // Longest streak: find all practiced days, then compute longest consecutive run
        var practicedDays = jdbcTemplate.query(
                """
                select distinct (client_timestamp at time zone 'Asia/Shanghai')::date as d
                from interaction_events
                where account_id = ?
                order by d
                """,
                (rs, rowNum) -> rs.getString("d"),
                accountId
        );

        int longestStreak = computeLongestStreak(practicedDays);

        return new Streak(currentStreak, longestStreak);
    }

    private int computeLongestStreak(List<String> dateStrings) {
        if (dateStrings.isEmpty()) {
            return 0;
        }
        var dates = dateStrings.stream()
                .map(LocalDate::parse)
                .sorted()
                .toList();

        int longest = 1;
        int current = 1;
        for (int i = 1; i < dates.size(); i++) {
            if (dates.get(i).equals(dates.get(i - 1).plusDays(1))) {
                current++;
                longest = Math.max(longest, current);
            } else {
                current = 1;
            }
        }
        return longest;
    }

    // ── Bars ─────────────────────────────────────────────────────────────────

    private List<BarBucket> loadBars(String accountId, Window window, String period) {
        var truncExpr = switch (period) {
            case "week" -> "date_trunc('day', client_timestamp at time zone 'Asia/Shanghai')";
            case "month" -> "date_trunc('day', client_timestamp at time zone 'Asia/Shanghai')";
            case "year" -> "date_trunc('month', client_timestamp at time zone 'Asia/Shanghai')";
            default -> "date_trunc('day', client_timestamp at time zone 'Asia/Shanghai')";
        };

        return jdbcTemplate.query(
                """
                select %s as bucket,
                       count(*) as event_count
                from interaction_events
                where account_id = ?
                  and client_timestamp >= ?
                  and client_timestamp < ?
                group by bucket
                order by bucket
                """.formatted(truncExpr),
                (rs, rowNum) -> new BarBucket(
                        rs.getString("bucket"),
                        rs.getInt("event_count")
                ),
                accountId,
                Timestamp.from(window.start()),
                Timestamp.from(window.end())
        );
    }

    // ── Scenes ───────────────────────────────────────────────────────────────

    private List<SceneEntry> loadScenes(String accountId, Window window) {
        return jdbcTemplate.query(
                """
                select ie.activity_id,
                       pa.title_zh as activity_title,
                       ps.title_zh as space_title,
                       ps.slug as space_slug,
                       count(*) as event_count
                from interaction_events ie
                left join practice_activities pa on pa.slug = ie.activity_id
                left join practice_spaces ps on ps.slug = ie.space_id
                where ie.account_id = ?
                  and ie.client_timestamp >= ?
                  and ie.client_timestamp < ?
                group by ie.activity_id, pa.title_zh, ps.title_zh, ps.slug
                order by event_count desc
                limit 5
                """,
                (rs, rowNum) -> new SceneEntry(
                        rs.getString("activity_id"),
                        rs.getString("activity_title"),
                        rs.getString("space_title"),
                        rs.getString("space_slug"),
                        rs.getInt("event_count")
                ),
                accountId,
                Timestamp.from(window.start()),
                Timestamp.from(window.end())
        );
    }

    // ── Recent Activity ──────────────────────────────────────────────────────

    private RecentActivity loadRecentActivity(String accountId, Window thisWindow, Window prevWindow) {
        Integer thisWeekCount = jdbcTemplate.queryForObject(
                """
                select count(*) from interaction_events
                where account_id = ?
                  and client_timestamp >= ?
                  and client_timestamp < ?
                """,
                Integer.class,
                accountId,
                Timestamp.from(thisWindow.start()),
                Timestamp.from(thisWindow.end())
        );
        Integer lastWeekCount = jdbcTemplate.queryForObject(
                """
                select count(*) from interaction_events
                where account_id = ?
                  and client_timestamp >= ?
                  and client_timestamp < ?
                """,
                Integer.class,
                accountId,
                Timestamp.from(prevWindow.start()),
                Timestamp.from(prevWindow.end())
        );

        int thisCount = thisWeekCount == null ? 0 : thisWeekCount;
        int lastCount = lastWeekCount == null ? 0 : lastWeekCount;
        String trend = thisCount > lastCount ? "up" : thisCount < lastCount ? "down" : "flat";

        return new RecentActivity(thisCount, lastCount, trend);
    }

    // ── Suggestion ───────────────────────────────────────────────────────────

    private GrowthSuggestion loadSuggestion(String accountId, Window window) {
        // Find activities NOT practiced in the window
        var rows = jdbcTemplate.query(
                """
                select pa.slug, pa.title_zh, ps.title_zh as space_title
                from practice_activities pa
                join practice_spaces ps on ps.id = pa.space_id
                where pa.slug not in (
                    select distinct ie.activity_id
                    from interaction_events ie
                    where ie.account_id = ?
                      and ie.client_timestamp >= ?
                      and ie.client_timestamp < ?
                )
                order by pa.sort_order
                limit 1
                """,
                (rs, rowNum) -> new GrowthSuggestion(
                        rs.getString("slug"),
                        rs.getString("title_zh"),
                        rs.getString("space_title")
                ),
                accountId,
                Timestamp.from(window.start()),
                Timestamp.from(window.end())
        );
        return rows.isEmpty() ? null : rows.get(0);
    }

    // ── Window Resolution ────────────────────────────────────────────────────

    private Window resolveWindow(String period, Instant now) {
        var today = LocalDate.now(ZONE_SHANGHAI);
        var start = switch (period) {
            case "week" -> today.with(TemporalAdjusters.previousOrSame(java.time.DayOfWeek.MONDAY));
            case "month" -> today.withDayOfMonth(1);
            case "year" -> today.withDayOfYear(1);
            default -> throw invalidPeriod(period);
        };
        var end = switch (period) {
            case "week" -> start.plusWeeks(1);
            case "month" -> start.plusMonths(1);
            case "year" -> start.plusYears(1);
            default -> throw invalidPeriod(period);
        };
        return new Window(
                start.atStartOfDay(ZONE_SHANGHAI).toInstant(),
                end.atStartOfDay(ZONE_SHANGHAI).toInstant()
        );
    }

    private Window resolvePreviousWindow(String period, Window current) {
        return switch (period) {
            case "week" -> new Window(
                    current.start().minus(java.time.Duration.ofDays(7)),
                    current.start()
            );
            case "month" -> new Window(
                    current.start().atZone(ZONE_SHANGHAI).toLocalDate().minusMonths(1).atStartOfDay(ZONE_SHANGHAI).toInstant(),
                    current.start()
            );
            case "year" -> new Window(
                    current.start().atZone(ZONE_SHANGHAI).toLocalDate().minusYears(1).atStartOfDay(ZONE_SHANGHAI).toInstant(),
                    current.start()
            );
            default -> throw invalidPeriod(period);
        };
    }

    // ── Period Normalization ─────────────────────────────────────────────────

    private String normalizePeriod(String periodRaw) {
        if (periodRaw == null || periodRaw.isBlank()) {
            return "week";
        }
        var period = periodRaw.trim().toLowerCase(Locale.ROOT);
        if (!"week".equals(period) && !"month".equals(period) && !"year".equals(period)) {
            throw invalidPeriod(periodRaw);
        }
        return period;
    }

    private ContractException invalidPeriod(String periodRaw) {
        String periodValue = periodRaw == null ? "<null>" : periodRaw;
        return new ContractException(
                HttpStatus.BAD_REQUEST,
                "invalid_period",
                "period 仅支持 week/month/year。",
                java.util.Map.of("period", periodValue, "allowed", java.util.List.of("week", "month", "year"))
        );
    }

    // ── Internal Records ─────────────────────────────────────────────────────

    private record Window(Instant start, Instant end) {
    }

    public record Stats(
            int totalEvents,
            int uniquePhrases,
            int uniqueActivities,
            int imitationCount,
            int practicedDays
    ) {
    }

    public record Streak(
            int current,
            int longest
    ) {
    }

    public record BarBucket(
            String bucket,
            int eventCount
    ) {
    }

    public record SceneEntry(
            String activityId,
            String activityTitle,
            String spaceTitle,
            String spaceSlug,
            int eventCount
    ) {
    }

    public record RecentActivity(
            int thisPeriodCount,
            int lastPeriodCount,
            String trend
    ) {
    }

    public record GrowthSuggestion(
            String activityId,
            String activityTitle,
            String spaceTitle
    ) {
    }

    // ── Response ─────────────────────────────────────────────────────────────

    public record GrowthInsightsResponse(
            String period,
            Instant windowStart,
            Instant windowEnd,
            Instant generatedAt,
            Stats stats,
            Streak streak,
            List<BarBucket> bars,
            List<SceneEntry> scenes,
            RecentActivity recentActivity,
            GrowthSuggestion suggestion
    ) {
    }
}
