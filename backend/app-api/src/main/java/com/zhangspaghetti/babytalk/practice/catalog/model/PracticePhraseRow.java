package com.zhangspaghetti.babytalk.practice.catalog.model;

public record PracticePhraseRow(
        long id,
        String phraseId,
        String activityId,
        int step,
        String english,
        String chinese,
        String pronunciation,
        String difficulty,
        String audioAsset,
        String source
) {
}
