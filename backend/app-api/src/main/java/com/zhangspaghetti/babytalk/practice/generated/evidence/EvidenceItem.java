package com.zhangspaghetti.babytalk.practice.generated.evidence;

import java.util.Objects;

public record EvidenceItem(
        String evidenceId,
        ReplayMode replayMode,
        String sourceType,
        String sourceVersion,
        String strategyId,
        String claimType,
        String sanitizedSummary,
        String sanitizedSummaryHash,
        double confidence
) {
    public EvidenceItem {
        Objects.requireNonNull(evidenceId, "evidenceId");
        Objects.requireNonNull(replayMode, "replayMode");
        Objects.requireNonNull(sourceType, "sourceType");
        Objects.requireNonNull(claimType, "claimType");
        Objects.requireNonNull(sanitizedSummary, "sanitizedSummary");
        Objects.requireNonNull(sanitizedSummaryHash, "sanitizedSummaryHash");
        if (evidenceId.isBlank() || sourceType.isBlank() || claimType.isBlank() || sanitizedSummary.isBlank()) {
            throw new IllegalArgumentException("evidence fields must not be blank");
        }
        if (replayMode == ReplayMode.REFERENCE && (sourceVersion == null || sourceVersion.isBlank())) {
            throw new IllegalArgumentException("reference evidence requires sourceVersion");
        }
        if (!sanitizedSummaryHash.matches("[0-9a-f]{64}")
                || !sanitizedSummaryHash.equals(EvidenceSanitizer.sha256(sanitizedSummary))) {
            throw new IllegalArgumentException(
                    "sanitizedSummaryHash must be lowercase SHA-256 of sanitizedSummary");
        }
        if (confidence < 0.0d || confidence > 1.0d || Double.isNaN(confidence)) {
            throw new IllegalArgumentException("confidence must be between 0 and 1");
        }
    }
}
