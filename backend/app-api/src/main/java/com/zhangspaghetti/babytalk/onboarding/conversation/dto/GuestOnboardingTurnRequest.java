package com.zhangspaghetti.babytalk.onboarding.conversation.dto;

import com.fasterxml.jackson.annotation.JsonAnySetter;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.util.Map;

@JsonIgnoreProperties(ignoreUnknown = false)
public record GuestOnboardingTurnRequest(
        String localEventId,
        String previousUtteranceId,
        String parentAction,
        Boolean reactionProvided,
        String reaction,
        String reactionText,
        GenerationSceneRequest generationScene
) {
    @JsonAnySetter
    public void rejectUnknownField(String fieldName, Object ignored) {
        throw new IllegalArgumentException("Unsupported onboarding turn field: " + fieldName);
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
            throw new IllegalArgumentException("Unsupported onboarding turn generation field: " + fieldName);
        }
    }
}
