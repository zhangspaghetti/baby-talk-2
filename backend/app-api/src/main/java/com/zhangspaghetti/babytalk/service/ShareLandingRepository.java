package com.zhangspaghetti.babytalk.service;

import java.time.Instant;
import java.util.Optional;
import org.springframework.stereotype.Repository;

@Repository
public class ShareLandingRepository {

    private final ShareLandingMapper mapper;

    public ShareLandingRepository(ShareLandingMapper mapper) {
        this.mapper = mapper;
    }

    public void insertShareCard(ShareCardRow row) {
        mapper.insertShareCard(row);
    }

    public Optional<ShareCardRow> findByToken(String token) {
        return Optional.ofNullable(mapper.findByToken(token));
    }

    public void insertEvent(EventRow row) {
        mapper.insertEvent(row);
    }

    public record ShareCardRow(
            String token,
            String source,
            String headline,
            String storyText,
            String phraseText,
            String phraseTranslation,
            String recommendationTitle,
            String recommendationReason,
            String spaceId,
            String activityId,
            String platformHint,
            Instant createdAt,
            Instant expiresAt
    ) {
    }

    public record EventRow(
            String token,
            String source,
            String entrypoint,
            String platform,
            String result,
            String failureReason,
            Instant createdAt
    ) {
    }
}
