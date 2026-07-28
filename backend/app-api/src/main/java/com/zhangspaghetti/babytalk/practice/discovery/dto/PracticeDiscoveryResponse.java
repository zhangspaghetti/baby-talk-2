package com.zhangspaghetti.babytalk.practice.discovery.dto;

import java.util.List;

public record PracticeDiscoveryResponse(
        String discoveryTraceId,
        String surface,
        String mode,
        String profileMode,
        String source,
        String generatedContentId,
        String bundleSchemaVersion,
        List<SceneResponse> scenes,
        List<MomentResponse> moments,
        StarterResponse starter,
        List<ReactionSupportResponse> reactionSupports,
        TraceResponse trace
) {
    public PracticeDiscoveryResponse(
            String discoveryTraceId,
            String surface,
            String mode,
            String profileMode,
            String source,
            String generatedContentId,
            List<SceneResponse> scenes,
            List<MomentResponse> moments,
            StarterResponse starter,
            TraceResponse trace
    ) {
        this(
                discoveryTraceId,
                surface,
                mode,
                profileMode,
                source,
                generatedContentId,
                null,
                scenes,
                moments,
                starter,
                List.of(),
                trace);
    }

    public record SceneResponse(String sceneId, String spaceId, String title, int rank, String reasonCode) {
    }

    public record MomentResponse(
            String momentId,
            String sceneId,
            String spaceId,
            String activityId,
            String title,
            String sceneTag,
            String coachTip,
            int rank,
            List<StarterUtteranceResponse> starterUtterances
    ) {
    }

    public record StarterUtteranceResponse(
            String utteranceId,
            String phraseId,
            String english,
            String chinese,
            String pronunciation,
            String difficulty,
            String source,
            String role,
            String reaction,
            String tprActionZh,
            String deliveryGuidanceZh,
            int displayOrder,
            ProviderProvenanceResponse providerProvenance
    ) {
        public StarterUtteranceResponse(
                String utteranceId,
                String phraseId,
                String english,
                String chinese,
                String pronunciation,
                String difficulty,
                String source
        ) {
            this(utteranceId, phraseId, english, chinese, pronunciation, difficulty, source,
                    "starter", null, null, null, 1, null);
        }
    }

    public record StarterResponse(
            String sceneId,
            String spaceId,
            String momentId,
            String activityId,
            String utteranceId,
            String phraseId,
            String source
    ) {
    }

    public record ReactionSupportResponse(
            String reaction,
            String utteranceId,
            String phraseId,
            String english,
            String chinese,
            String pronunciation,
            String tprActionZh,
            String deliveryGuidanceZh,
            String difficulty,
            String source,
            String role,
            int displayOrder,
            ProviderProvenanceResponse providerProvenance
    ) {
    }

    public record ProviderProvenanceResponse(
            String origin,
            String providerName,
            String modelName,
            int attemptNumber
    ) {
    }

    public record TraceResponse(String strategy, String fallbackReason, int candidateCount, int returnedCount) {
    }
}
