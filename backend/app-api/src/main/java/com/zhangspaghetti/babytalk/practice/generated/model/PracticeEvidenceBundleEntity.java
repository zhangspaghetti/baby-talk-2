package com.zhangspaghetti.babytalk.practice.generated.model;

import java.time.OffsetDateTime;
import java.util.UUID;

public record PracticeEvidenceBundleEntity(
        UUID evidenceBundleId,
        String generatedContentId,
        int attemptNumber,
        UUID derivedFromBundleId,
        String retrievalOutcome,
        UUID retrievalTraceId,
        String evidencePolicyVersion,
        String evidencePolicyContentHash,
        String sanitizerVersion,
        String bundleHash,
        int evidenceCount,
        OffsetDateTime createdAt
) {
}
