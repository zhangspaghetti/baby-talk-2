package com.zhangspaghetti.babytalk.practice.generated;

import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity;
import java.time.OffsetDateTime;
import java.util.Optional;

public interface PracticeGeneratedContentCommands {

    DraftReservation reserveDraft(PracticeGeneratedContentEntity draft, ReservationPolicy policy);

    GenerationStartDecision startGeneration(
            String generatedContentId,
            OffsetDateTime dailyFrom,
            int dailyLimit,
            OffsetDateTime now);

    Optional<PracticeGeneratedContentEntity> activate(PracticeGeneratedContentEntity active);

    void reject(
            String generatedContentId,
            String errorCode,
            boolean retryable,
            OffsetDateTime now,
            OffsetDateTime retentionExpiresAt);

    void expire(
            String generatedContentId,
            String errorCode,
            boolean retryable,
            OffsetDateTime now,
            OffsetDateTime retentionExpiresAt);

    int interruptStaleExecutions(
            OffsetDateTime interruptedAt,
            OffsetDateTime installationRetentionExpiresAt,
            int limit);

    int deleteExpiredInstallationRows(OffsetDateTime retentionExpiresAtOrBefore, int limit);

    int deleteAccountOwned(String accountId);
}
