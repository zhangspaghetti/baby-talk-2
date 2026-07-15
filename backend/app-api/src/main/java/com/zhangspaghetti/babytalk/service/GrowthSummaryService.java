package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.growth.mapper.GrowthSummaryMapper;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.temporal.TemporalAdjusters;
import java.util.Locale;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class GrowthSummaryService {

    private final GrowthSummaryMapper mapper;
    private final AuthConsentSyncService authConsentSyncService;
    private final Clock clock = Clock.systemUTC();

    public GrowthSummaryService(GrowthSummaryMapper mapper, AuthConsentSyncService authConsentSyncService) {
        this.mapper = mapper;
        this.authConsentSyncService = authConsentSyncService;
    }

    @Transactional(readOnly = true)
    public GrowthSummaryResponse loadSummary(String sessionId, String periodRaw) {
        var period = normalizePeriod(periodRaw);
        var accountId = authConsentSyncService.resolveAccountIdForGrowthSummary(sessionId);
        var now = Instant.now(clock);
        var window = resolveWindow(period, now);

        var stats = mapper.loadStats(accountId, window.start(), window.end());
        return new GrowthSummaryResponse(
                period,
                stats.totalEvents(),
                stats.uniquePhrases(),
                stats.uniqueActivities(),
                stats.cooperatingCount(),
                stats.firstEventAt(),
                stats.lastEventAt(),
                stats.practicedDays(),
                window.start(),
                window.end(),
                now
        );
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
            int cooperatingCount,
            Instant firstEventAt,
            Instant lastEventAt,
            int practicedDays,
            Instant windowStart,
            Instant windowEnd,
            Instant generatedAt
    ) {
    }
}
