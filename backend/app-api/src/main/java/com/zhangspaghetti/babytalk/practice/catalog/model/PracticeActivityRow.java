package com.zhangspaghetti.babytalk.practice.catalog.model;

public record PracticeActivityRow(
        long id,
        String activityId,
        String spaceId,
        String titleZh,
        String sceneTagEn,
        String coachTip,
        int sortOrder,
        String source
) {
}
