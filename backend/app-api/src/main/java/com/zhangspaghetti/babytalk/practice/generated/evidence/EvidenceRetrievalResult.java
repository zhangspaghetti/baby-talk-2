package com.zhangspaghetti.babytalk.practice.generated.evidence;

import java.util.List;
import java.util.Objects;
import java.util.UUID;

public record EvidenceRetrievalResult(
        List<EvidenceItem> items,
        UUID retrievalTraceId,
        RetrievalStatus status
) {
    public EvidenceRetrievalResult {
        Objects.requireNonNull(items, "items");
        Objects.requireNonNull(status, "status");
        items = List.copyOf(items);
    }
}
