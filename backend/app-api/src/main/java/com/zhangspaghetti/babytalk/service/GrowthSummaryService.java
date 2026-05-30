package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.web.ContractException;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.temporal.TemporalAdjusters;
import java.util.Locale;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class GrowthSummaryService {

    private final JdbcTemplate jdbcTemplate;
    private final AuthConsentSyncService authConsentSyncService;
    private final Clock clock = Clock.systemUTC();

    public GrowthSummaryService(JdbcTemplate jdbcTemplate, AuthConsentSyncService authConsentSyncService) {
        this.jdbcTemplate = jdbcTemplate;
        this.authConsentSyncService = authConsentSyncService;
    }

    @Transactional(readOnly = true)
    public GrowthSummaryResponse loadSummary(String sessionId, String periodRaw) {
        var period = normalizePeriod(periodRaw);
        var accountId = authConsentSyncService.resolveAccountIdForGrowthSummary(sessionId);
        var now = Instant.now(clock);
        var window = resolveWindow(period, now);

        return jdbcTemplate.queryForObject(
                """
                select count(*) as total_events,
                       count(distinct phrase_id) as unique_phrases,
                       count(distinct activity_id) as unique_activities,
                       count(*) filter (where reaction_type = 'imitated') as imitation_count,
                       min(client_timestamp) as first_event_at,
                       max(client_timestamp) as last_event_at,
                       count(distinct (client_timestamp at time zone 'UTC')::date) as practiced_days
                from interaction_events
                where account_id = ?
                  and client_timestamp >= ?
                  and client_timestamp < ?
                """,
                (rs, rowNum) -> mapSummary(rs, period, window.start(), window.end(), now),
                accountId,
                Timestamp.from(window.start()),
                Timestamp.from(window.end())
        );
    }

    private GrowthSummaryResponse mapSummary(ResultSet rs, String period, Instant windowStart, Instant windowEnd, Instant generatedAt)
            throws SQLException {
        return new GrowthSummaryResponse(
                period,
                rs.getInt("total_events"),
                rs.getInt("unique_phrases"),
                rs.getInt("unique_activities"),
                rs.getInt("imitation_count"),
                toInstant(rs.getTimestamp("first_event_at")),
                toInstant(rs.getTimestamp("last_event_at")),
                rs.getInt("practiced_days"),
                windowStart,
                windowEnd,
                generatedAt
        );
    }

    private Instant toInstant(Timestamp timestamp) {
        return timestamp == null ? null : timestamp.toInstant();
    }

    private String normalizePeriod(String periodRaw) {
        if (periodRaw == null || periodRaw.isBlank()) {
            throw invalidPeriod(periodRaw);
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

    private SummaryWindow resolveWindow(String period, Instant now) {
        var todayUtc = LocalDate.ofInstant(now, ZoneOffset.UTC);
        var start = switch (period) {
            case "week" -> todayUtc.with(TemporalAdjusters.previousOrSame(java.time.DayOfWeek.MONDAY));
            case "month" -> todayUtc.withDayOfMonth(1);
            case "year" -> todayUtc.withDayOfYear(1);
            default -> throw invalidPeriod(period);
        };
        return new SummaryWindow(start.atStartOfDay().toInstant(ZoneOffset.UTC), now);
    }

    private record SummaryWindow(Instant start, Instant end) {
    }

    public record GrowthSummaryResponse(
            String period,
            int totalEvents,
            int uniquePhrases,
            int uniqueActivities,
            int imitationCount,
            Instant firstEventAt,
            Instant lastEventAt,
            int practicedDays,
            Instant windowStart,
            Instant windowEnd,
            Instant generatedAt
    ) {
    }
}