package com.zhangspaghetti.babytalk.profile.dto;

public record StarterResponse(
        String sceneId,
        String momentId,
        String activityId,
        String utteranceId,
        String phraseId,
        String source
) {
}
