package com.zhangspaghetti.babytalk.practice.generated.internal;

import com.zhangspaghetti.babytalk.practice.agentic.PracticeAiAuditPort;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeAiOperationRunEntity;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeAiProviderCallEntity;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
@ConditionalOnProperty(
        prefix = "babytalk.practice.discovery.custom-scene",
        name = "provider-mode",
        havingValue = "agentic"
)
class PracticeAiAuditPersistenceAdapter implements PracticeAiAuditPort {

    private final PracticeGenerationAuditMapper auditMapper;

    PracticeAiAuditPersistenceAdapter(PracticeGenerationAuditMapper auditMapper) {
        this.auditMapper = auditMapper;
    }

    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void insertOperationRun(OperationRunStarted operation) {
        auditMapper.insertOperationRun(new PracticeAiOperationRunEntity(
                operation.operationRunId(),
                operation.operationType(),
                operation.subjectType(),
                operation.subjectId(),
                operation.generatedContentId(),
                operation.attemptNumber(),
                operation.evidenceBundleId(),
                operation.capabilityName(),
                operation.promptVersion(),
                operation.promptHash(),
                operation.policyVersion(),
                operation.policyHash(),
                "started",
                null,
                operation.startedAt(),
                null));
    }

    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void completeOperationRun(OperationRunCompleted operation) {
        auditMapper.completeOperationRun(
                operation.operationRunId(), operation.outcome(), operation.completedAt());
    }

    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void insertProviderCall(ProviderCallStarted call) {
        auditMapper.insertProviderCall(new PracticeAiProviderCallEntity(
                call.providerCallId(),
                call.operationRunId(),
                call.providerName(),
                call.providerType(),
                call.modelName(),
                call.fallbackIndex(),
                call.attemptTraceId(),
                null,
                call.routingPolicyVersion(),
                call.routingPolicyHash(),
                "started",
                null,
                call.startedAt(),
                null));
    }

    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void completeProviderCall(ProviderCallCompleted call) {
        auditMapper.completeProviderCall(
                call.providerCallId(),
                call.outcome(),
                call.providerTraceId(),
                call.latencyMs(),
                call.completedAt());
    }
}
