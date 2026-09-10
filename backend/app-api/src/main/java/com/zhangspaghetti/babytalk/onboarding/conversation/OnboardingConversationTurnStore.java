package com.zhangspaghetti.babytalk.onboarding.conversation;

import java.time.OffsetDateTime;

public interface OnboardingConversationTurnStore {

    StoredTurn find(String conversationId, String localEventId);

    StoredTurn findByUtterance(String conversationId, String utteranceId);

    int reserve(StoredTurn turn);

    int activate(
            String turnId,
            String generatedContentId,
            String utteranceId,
            String englishText,
            String chineseText,
            String pronunciationHint,
            String audioRef,
            OffsetDateTime expiresAt,
            OffsetDateTime updatedAt);

    int deleteReservation(String turnId);

    int deleteExpiredReservation(
            String conversationId,
            String localEventId,
            OffsetDateTime expiresAtOrBefore);

    record StoredTurn(
            String turnId,
            String conversationId,
            String localEventId,
            String requestFingerprint,
            String previousUtteranceId,
            String parentAction,
            boolean reactionProvided,
            String reaction,
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
