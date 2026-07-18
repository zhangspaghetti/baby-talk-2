package com.zhangspaghetti.babytalk.practice.generated.model;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

public record PracticeEvidenceItemEntity(
        UUID evidenceBundleId,
        int evidenceOrdinal,
        String replayMode,
        String evidenceId,
        String sourceType,
        String sourceVersion,
        String strategyId,
        String claimType,
        String sanitizerVersion,
        String sanitizedSummaryHash,
        String sanitizedSummarySnapshot,
        BigDecimal confidence,
        OffsetDateTime createdAt
) {
}
