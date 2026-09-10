package com.zhangspaghetti.babytalk.practice.agentic;

import java.util.Objects;
import java.util.UUID;

public record OperationResult<T>(
        T value,
        UUID operationRunId,
        UUID providerCallId,
        String providerName,
        String modelName,
        String providerTraceId
) {
    public OperationResult {
        Objects.requireNonNull(value, "value");
        Objects.requireNonNull(operationRunId, "operationRunId");
        Objects.requireNonNull(providerCallId, "providerCallId");
        Objects.requireNonNull(providerName, "providerName");
        Objects.requireNonNull(modelName, "modelName");
    }
}
