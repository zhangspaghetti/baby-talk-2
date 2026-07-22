package com.zhangspaghetti.babytalk.practice.generated;

import java.time.OffsetDateTime;

public record ReservationPolicy(
        OffsetDateTime now,
        OffsetDateTime burstFrom,
        int burstLimit,
        OffsetDateTime expiredRetentionExpiresAt
) {
}
