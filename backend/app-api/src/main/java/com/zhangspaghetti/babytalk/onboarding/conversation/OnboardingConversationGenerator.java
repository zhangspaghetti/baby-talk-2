package com.zhangspaghetti.babytalk.onboarding.conversation;

import java.util.Map;

public interface OnboardingConversationGenerator {

    GeneratedUtterance generate(GenerationRequest request);

    default GeneratedUtterance generateNext(NextGenerationRequest request) {
        throw new UnsupportedOperationException("next onboarding generation is unavailable");
    }

    record GenerationRequest(
            String installationId,
            String localEventId,
            String sceneKey,
            Map<String, String> facets,
            String locale,
            String timeBand
    ) {
    }

    record NextGenerationRequest(
            String installationRefHash,
            String installationOwnerKey,
            String localEventId,
            String sceneKey,
            Map<String, String> facets,
            String locale,
            String timeBand,
            String previousUtteranceId,
            String previousEnglishText,
            String parentAction,
            boolean reactionProvided,
            String reaction,
            String reactionText
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
