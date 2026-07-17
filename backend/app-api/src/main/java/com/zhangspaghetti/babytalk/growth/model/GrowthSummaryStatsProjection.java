package com.zhangspaghetti.babytalk.growth.model;

import java.time.Instant;

public record GrowthSummaryStatsProjection(
        int totalEvents,
        int uniquePhrases,
        int uniqueActivities,
        int cooperatingCount,
        Instant firstEventAt,
        Instant lastEventAt,
        int practicedDays
) {
}
