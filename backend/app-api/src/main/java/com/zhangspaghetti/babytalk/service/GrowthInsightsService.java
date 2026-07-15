package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.growth.mapper.GrowthInsightsMapper;
import java.time.Clock;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.temporal.TemporalAdjusters;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class GrowthInsightsService {

    private static final ZoneId SHANGHAI = ZoneId.of("Asia/Shanghai");
    private final GrowthInsightsMapper mapper;
    private final AuthConsentSyncService authConsentSyncService;
    private final Clock clock;

    @Autowired
    public GrowthInsightsService(GrowthInsightsMapper mapper,
                                  AuthConsentSyncService authConsentSyncService) {
        this(mapper, authConsentSyncService, Clock.systemUTC());
    }

    GrowthInsightsService(GrowthInsightsMapper mapper,
                           AuthConsentSyncService authConsentSyncService,
                           Clock clock) {
        this.mapper = mapper;
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
        var row = mapper.loadStats(accountId, window.start(), window.end());
        return new Stats(
                row.totalEvents(),
                row.uniquePhrases(),
                row.uniqueActivities(),
                row.cooperatingCount(),
                row.practicedDays(),
                row.firstEventAt(),
                row.lastEventAt()
        );
    }

    // ── streak ─────────────────────────────────────────────────────────────
    private Streak loadStreak(String accountId, Instant now) {
        var today = now.atZone(SHANGHAI).toLocalDate();
        var dates = mapper.listPracticeDates(accountId, now);

        int current = 0;
        int longest = 0;
        int streak  = 0;
        LocalDate prev = today;
        for (LocalDate d : dates) {
            long gap = java.time.temporal.ChronoUnit.DAYS.between(d, prev);
            if (gap <= 1) {
                streak++;
            } else {
                if (streak > longest) {
                    longest = streak;
                }
                streak = 1;
            }
            prev = d;
        }
        if (streak > longest) {
            longest = streak;
        }

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
        return mapper.listBars(truncUnit, accountId, window.start(), window.end()).stream()
                .map(row -> new BarBucket(row.bucketStart(), row.count()))
                .toList();
    }

    // ── scenes ─────────────────────────────────────────────────────────────
    private List<SceneEntry> loadScenes(String accountId, Window window) {
        return mapper.listScenes(accountId, window.start(), window.end()).stream()
                .map(row -> new SceneEntry(
                        row.spaceId(),
                        row.sceneTag(),
                        row.eventCount(),
                        row.activityCount(),
                        row.total() > 0 ? (double) row.eventCount() / row.total() * 100 : 0.0
                ))
                .toList();
    }

    // ── recentActivity ─────────────────────────────────────────────────────
    private RecentActivity loadRecentActivity(String accountId, Instant now) {
        var weekEnd   = now.atZone(SHANGHAI).with(DayOfWeek.MONDAY).toLocalDate().atStartOfDay(SHANGHAI).toInstant();
        var weekStart = weekEnd.atZone(SHANGHAI).minusWeeks(1).toInstant();


        var row = mapper.loadRecentActivity(accountId, weekEnd, now, weekStart);
        return new RecentActivity(row.thisWeekCount(), row.lastWeekCount());
    }

    // ── suggestion ─────────────────────────────────────────────────────────
    private GrowthSuggestion loadSuggestion(String accountId, Window window) {
        var row = mapper.findSuggestion(accountId, window.start(), window.end());
        return row == null
                ? null
                : new GrowthSuggestion(row.spaceId(), row.activityId(), row.sceneLabel(), row.phraseEnglish());
    }

    // ── window / period ────────────────────────────────────────────────────
    private String normalizePeriod(String raw) {
        if (raw == null || raw.isBlank()) {
            return "week";
        }
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
