package com.zhangspaghetti.babytalk.practice.generated.model;

import java.time.OffsetDateTime;
import java.util.UUID;

public record PracticeAiProviderCallEntity(
        UUID providerCallId,
        UUID operationRunId,
        String providerName,
        String providerType,
        String modelName,
        int fallbackIndex,
        UUID attemptTraceId,
        String providerTraceId,
        String routingPolicyVersion,
        String routingPolicyHash,
        String outcome,
        Long latencyMs,
        OffsetDateTime startedAt,
        OffsetDateTime completedAt
) {
}
