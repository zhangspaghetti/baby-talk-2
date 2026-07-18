package com.zhangspaghetti.babytalk.practice.agentic;

import java.time.OffsetDateTime;
import java.util.UUID;

public interface PracticeAiAuditPort {

    void insertOperationRun(OperationRunStarted operation);

    void completeOperationRun(OperationRunCompleted operation);

    void insertProviderCall(ProviderCallStarted call);

    void completeProviderCall(ProviderCallCompleted call);

    record OperationRunStarted(
            UUID operationRunId,
            String operationType,
            String subjectType,
            String subjectId,
            String generatedContentId,
            int attemptNumber,
            UUID evidenceBundleId,
            String capabilityName,
            String promptVersion,
            String promptHash,
            String policyVersion,
            String policyHash,
            OffsetDateTime startedAt
    ) {
    }

    record OperationRunCompleted(UUID operationRunId, String outcome, OffsetDateTime completedAt) {
    }

    record ProviderCallStarted(
            UUID providerCallId,
            UUID operationRunId,
            String providerName,
            String providerType,
            String modelName,
            int fallbackIndex,
            UUID attemptTraceId,
            String routingPolicyVersion,
            String routingPolicyHash,
            OffsetDateTime startedAt
    ) {
    }

    record ProviderCallCompleted(
            UUID providerCallId,
            String outcome,
            String providerTraceId,
            long latencyMs,
            OffsetDateTime completedAt
    ) {
    }
}
