package com.zhangspaghetti.babytalk.practice.generated.evidence;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

public record FrozenEvidenceBundle(
        UUID evidenceBundleId,
        String generatedContentId,
        int attemptNumber,
        UUID derivedFromBundleId,
        RetrievalStatus status,
        UUID retrievalTraceId,
        String evidencePolicyVersion,
        String evidencePolicyContentHash,
        String sanitizerVersion,
        String bundleHash,
        List<EvidenceItem> items,
        OffsetDateTime createdAt
) {
    public FrozenEvidenceBundle {
        Objects.requireNonNull(evidenceBundleId, "evidenceBundleId");
        Objects.requireNonNull(generatedContentId, "generatedContentId");
        Objects.requireNonNull(status, "status");
        Objects.requireNonNull(evidencePolicyVersion, "evidencePolicyVersion");
        Objects.requireNonNull(evidencePolicyContentHash, "evidencePolicyContentHash");
        Objects.requireNonNull(sanitizerVersion, "sanitizerVersion");
        Objects.requireNonNull(bundleHash, "bundleHash");
        Objects.requireNonNull(items, "items");
        Objects.requireNonNull(createdAt, "createdAt");
        items = List.copyOf(items);
    }
}
