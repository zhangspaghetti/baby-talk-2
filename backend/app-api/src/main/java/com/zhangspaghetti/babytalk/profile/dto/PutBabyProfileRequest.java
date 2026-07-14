package com.zhangspaghetti.babytalk.profile.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import java.time.OffsetDateTime;

public record PutBabyProfileRequest(
        @Positive Integer expectedVersion,
        String babyName,
        @NotBlank(message = "ageRange 不能为空。") String ageRange,
        String parentGoal,
        @Valid StarterRequest starter,
        @NotBlank(message = "onboardingState 不能为空。") String onboardingState,
        OffsetDateTime completedAt,
        @Size(max = 96, message = "clientTraceId 过长。") String clientTraceId
) {
}
