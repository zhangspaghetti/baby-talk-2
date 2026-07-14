package com.zhangspaghetti.babytalk.profile.model;

import java.time.OffsetDateTime;

public record BabyProfilePatch(
        String babyName,
        String ageRange,
        String parentGoal,
        String starterSceneId,
        String starterMomentId,
        String starterActivityId,
        String starterUtteranceId,
        String starterPhraseId,
        String starterSource,
        String onboardingState,
        OffsetDateTime onboardingCompletedAt
) {
}
