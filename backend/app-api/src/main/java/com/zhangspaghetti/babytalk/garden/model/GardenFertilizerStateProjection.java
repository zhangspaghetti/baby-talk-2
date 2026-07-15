package com.zhangspaghetti.babytalk.garden.model;

import java.time.Instant;

public record GardenFertilizerStateProjection(
        int appliedCount,
        Instant lastClaimedAt,
        Instant lastAppliedAt,
        long version,
        int claimCount
) {
}
