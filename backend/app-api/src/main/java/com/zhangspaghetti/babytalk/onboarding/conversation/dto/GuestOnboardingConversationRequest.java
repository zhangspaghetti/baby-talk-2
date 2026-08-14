package com.zhangspaghetti.babytalk.onboarding.conversation.dto;

import com.fasterxml.jackson.annotation.JsonAnySetter;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.util.Map;

@JsonIgnoreProperties(ignoreUnknown = false)
public record GuestOnboardingConversationRequest(
        String installationId,
        String localEventId,
        String careEntryId,
        String registryRevision,
        GenerationSceneRequest generationScene,
        String locale,
        String timeBand,
        String babyNickname
) {
    @JsonAnySetter
    public void rejectUnknownField(String fieldName, Object ignored) {
        throw new IllegalArgumentException("Unsupported onboarding conversation field: " + fieldName);
    }

    @JsonIgnoreProperties(ignoreUnknown = false)
    public record GenerationSceneRequest(
            String namespace,
            String key,
            Integer version,
            Map<String, String> facets
    ) {
        @JsonAnySetter
        public void rejectUnknownField(String fieldName, Object ignored) {
            throw new IllegalArgumentException("Unsupported onboarding generation scene field: " + fieldName);
        }
    }
}
