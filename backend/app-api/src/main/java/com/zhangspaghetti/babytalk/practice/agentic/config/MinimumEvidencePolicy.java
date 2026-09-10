package com.zhangspaghetti.babytalk.practice.agentic.config;

import java.util.List;

public record MinimumEvidencePolicy(
        String version,
        String contentHash,
        double minimumConfidence,
        List<String> requiredClaimCoverage,
        List<String> trustedSourceTypes
) {

    public MinimumEvidencePolicy {
        requiredClaimCoverage = List.copyOf(requiredClaimCoverage);
        trustedSourceTypes = List.copyOf(trustedSourceTypes);
    }
}
