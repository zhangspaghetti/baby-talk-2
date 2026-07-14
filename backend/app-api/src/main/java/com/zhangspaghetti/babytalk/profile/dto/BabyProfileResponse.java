package com.zhangspaghetti.babytalk.profile.dto;

import java.time.OffsetDateTime;

public record BabyProfileResponse(
        String babyProfileId,
        String babyName,
        String ageRange,
        String parentGoal,
        StarterResponse starter,
        String onboardingState,
        OffsetDateTime onboardingCompletedAt,
        int version,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {
}
