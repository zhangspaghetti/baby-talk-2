package com.zhangspaghetti.babytalk.practice.catalog.model;

public record CachedPhrase(
        long id,
        String slug,
        int step,
        String english,
        String chinese,
        String pronunciation,
        String difficulty
) {
}
