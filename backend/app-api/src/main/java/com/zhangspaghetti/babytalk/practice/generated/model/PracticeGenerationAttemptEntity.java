package com.zhangspaghetti.babytalk.practice.generated.model;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public record PracticeGenerationAttemptEntity(
        UUID attemptId,
        String generatedContentId,
        int attemptNumber,
        String attemptType,
        String status,
        String outcome,
        List<String> violationCodes,
        OffsetDateTime startedAt,
        OffsetDateTime completedAt
) {
    public PracticeGenerationAttemptEntity {
        violationCodes = AuditListValues.sortedDistinct(violationCodes);
    }
}
