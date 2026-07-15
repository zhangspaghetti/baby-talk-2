package com.zhangspaghetti.babytalk.growth.model;

import java.time.Instant;

public final class GrowthInsightsProjections {

    private GrowthInsightsProjections() {
    }

    public record Stats(
            long totalEvents,
            int uniquePhrases,
            int uniqueActivities,
            int cooperatingCount,
            int practicedDays,
            Instant firstEventAt,
            Instant lastEventAt
    ) {
    }

    public record BarBucket(Instant bucketStart, long count) {
    }

    public record Scene(
            String spaceId,
            String sceneTag,
            long eventCount,
            int activityCount,
            long total
    ) {
    }

    public record RecentActivity(int thisWeekCount, int lastWeekCount) {
    }

    public record Suggestion(
            String spaceId,
            String activityId,
            String sceneLabel,
            String phraseEnglish
    ) {
    }
}
