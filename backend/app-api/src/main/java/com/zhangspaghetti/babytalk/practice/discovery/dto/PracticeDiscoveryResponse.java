package com.zhangspaghetti.babytalk.practice.discovery.dto;

import java.util.List;

public record PracticeDiscoveryResponse(
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
            String source
    ) {
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

    public record TraceResponse(String strategy, String fallbackReason, int candidateCount, int returnedCount) {
    }
}
