package com.zhangspaghetti.babytalk.garden.model;

import java.time.Instant;

public record GardenSnapshotStatsProjection(
        long knownEvents,
        int uniquePhrases,
        int coveredSpaceCount,
        Instant firstEventAt
) {
}
