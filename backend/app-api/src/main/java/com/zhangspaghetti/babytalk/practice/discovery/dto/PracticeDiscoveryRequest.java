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
        String customSceneText
) {
    @JsonAnySetter
    public void rejectUnknownField(String fieldName, Object ignored) {
        throw new IllegalArgumentException("Unsupported practice discovery field: " + fieldName);
    }
}
