package com.zhangspaghetti.babytalk.practice.discovery.dto;

import com.fasterxml.jackson.annotation.JsonAnySetter;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

@JsonIgnoreProperties(ignoreUnknown = false)
public record PracticeDiscoveryRequest(
        String surface,
        String mode,
        String installationId,
        String babyProfileId,
        String ageRange,
        String parentGoal,
        String locale,
        Integer limit,
        String clientTraceId,
        String customSceneText,
        String clientRequestId
) {
    public PracticeDiscoveryRequest(
            String surface,
            String mode,
            String installationId,
            String babyProfileId,
            String ageRange,
            String parentGoal,
            String locale,
            Integer limit,
            String clientTraceId,
            String customSceneText
    ) {
        this(surface, mode, installationId, babyProfileId, ageRange, parentGoal, locale, limit,
                clientTraceId, customSceneText, null);
    }

    @JsonAnySetter
    public void rejectUnknownField(String fieldName, Object ignored) {
        throw new IllegalArgumentException("Unsupported practice discovery field: " + fieldName);
    }
}
