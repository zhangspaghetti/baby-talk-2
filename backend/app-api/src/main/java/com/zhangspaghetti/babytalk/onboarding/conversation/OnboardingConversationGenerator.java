package com.zhangspaghetti.babytalk.onboarding.conversation;

import java.util.Map;

public interface OnboardingConversationGenerator {

    GeneratedUtterance generate(GenerationRequest request);

    record GenerationRequest(
            String installationId,
            String localEventId,
            String sceneKey,
            Map<String, String> facets,
            String locale,
            String timeBand
    ) {
    }

    record GeneratedUtterance(
            String generatedContentId,
            String utteranceId,
            String englishText,
            String chineseText,
            String pronunciationHint,
            String audioRef
    ) {
    }
}
