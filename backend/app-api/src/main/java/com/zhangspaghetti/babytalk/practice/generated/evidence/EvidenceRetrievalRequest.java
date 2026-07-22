package com.zhangspaghetti.babytalk.practice.generated.evidence;

import java.util.LinkedHashSet;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;

public record EvidenceRetrievalRequest(
        String displayText,
        String ageRange,
        String parentGoal,
        Set<String> requestedClaimTypes,
        UUID retrievalTraceId
) {
    public EvidenceRetrievalRequest {
        Objects.requireNonNull(displayText, "displayText");
        Objects.requireNonNull(ageRange, "ageRange");
        Objects.requireNonNull(parentGoal, "parentGoal");
        Objects.requireNonNull(requestedClaimTypes, "requestedClaimTypes");
        Objects.requireNonNull(retrievalTraceId, "retrievalTraceId");
        requestedClaimTypes = Set.copyOf(new LinkedHashSet<>(requestedClaimTypes));
    }
}
