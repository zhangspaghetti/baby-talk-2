package com.zhangspaghetti.babytalk.onboarding.conversation;

import java.time.OffsetDateTime;

public interface OnboardingConversationStore {

    StoredConversation find(String installationRefHash, String localEventId);

    StoredConversation findByConversationId(String conversationId);

    int reserve(StoredConversation conversation);

    int activate(
            String conversationId,
            String generatedContentId,
            String utteranceId,
            String englishText,
            String chineseText,
            String pronunciationHint,
            String audioRef,
            OffsetDateTime expiresAt,
            OffsetDateTime updatedAt);

    int deleteReservation(String conversationId);

    int extendExpiry(String conversationId, OffsetDateTime expiresAt, OffsetDateTime updatedAt);

    int deleteExpired(OffsetDateTime expiresAtOrBefore, int limit);

    int deleteExpiredIdentity(
            String installationRefHash,
            String localEventId,
            OffsetDateTime expiresAtOrBefore);

    record StoredConversation(
            String conversationId,
            String installationRefHash,
            String localEventId,
            String requestFingerprint,
            String registryRevision,
            String careEntryId,
            String generationNamespace,
            String generationKey,
            int generationVersion,
            String generationFacetsJson,
            String locale,
            String timeBand,
            String generatedContentId,
            String utteranceId,
            String englishText,
            String chineseText,
            String pronunciationHint,
            String audioRef,
            String status,
            OffsetDateTime expiresAt,
            OffsetDateTime createdAt,
            OffsetDateTime updatedAt
    ) {
    }
}
