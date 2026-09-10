package com.zhangspaghetti.babytalk.practice.generated;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

public interface GenerationAttemptAuditPort {

    void startAttempt(AttemptStarted attempt);

    void completeAttempt(AttemptCompleted attempt);

    record AttemptStarted(
            UUID attemptId,
            String generatedContentId,
            int attemptNumber,
            String attemptType,
            OffsetDateTime startedAt
    ) {
        public AttemptStarted {
            Objects.requireNonNull(attemptId, "attemptId");
            Objects.requireNonNull(generatedContentId, "generatedContentId");
            Objects.requireNonNull(attemptType, "attemptType");
            Objects.requireNonNull(startedAt, "startedAt");
        }
    }

    record AttemptCompleted(
            UUID attemptId,
            int attemptNumber,
            String outcome,
            List<String> violationCodes,
            OffsetDateTime completedAt
    ) {
        public AttemptCompleted {
            Objects.requireNonNull(attemptId, "attemptId");
            Objects.requireNonNull(outcome, "outcome");
            violationCodes = List.copyOf(Objects.requireNonNull(violationCodes, "violationCodes"));
            Objects.requireNonNull(completedAt, "completedAt");
        }
    }
}
