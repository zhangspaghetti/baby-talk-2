package com.zhangspaghetti.babytalk.practice.generated.model;

import java.time.OffsetDateTime;
import java.util.UUID;

public record PracticeAiOperationRunEntity(
        UUID operationRunId,
        String operationType,
        String subjectType,
        String subjectId,
        String generatedContentId,
        int attemptNumber,
        UUID evidenceBundleId,
        String capabilityName,
        String promptVersion,
        String promptContentHash,
        String policyVersion,
        String policyContentHash,
        String status,
        String outcome,
        OffsetDateTime startedAt,
        OffsetDateTime completedAt
) {
}
