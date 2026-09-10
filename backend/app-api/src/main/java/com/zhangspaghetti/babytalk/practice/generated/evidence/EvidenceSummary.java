package com.zhangspaghetti.babytalk.practice.generated.evidence;

import java.util.Objects;

public record EvidenceSummary(
        String sanitizedSummary,
        String sanitizedSummaryHash
) {
    public EvidenceSummary {
        Objects.requireNonNull(sanitizedSummary, "sanitizedSummary");
        Objects.requireNonNull(sanitizedSummaryHash, "sanitizedSummaryHash");
    }
}
