package com.zhangspaghetti.babytalk.practice.generated.internal;

import com.zhangspaghetti.babytalk.practice.generated.model.PracticeAiOperationRunEntity;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeAiProviderCallEntity;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeEvidenceBundleEntity;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGenerationAttemptEntity;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeJudgeResultEntity;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Component;

@Component
public class PracticeGenerationAuditTestAccess {

    private final PracticeGenerationAuditMapper mapper;

    PracticeGenerationAuditTestAccess(PracticeGenerationAuditMapper mapper) {
        this.mapper = mapper;
    }

    public void insertAttempt(PracticeGenerationAttemptEntity entity) {
        mapper.insertAttempt(entity);
    }

    public void completeAttempt(UUID id, String outcome, List<String> codes, OffsetDateTime at) {
        mapper.completeAttempt(id, outcome, codes, at);
    }

    public void insertOperationRun(PracticeAiOperationRunEntity entity) {
        mapper.insertOperationRun(entity);
    }

    public void completeOperationRun(UUID id, String outcome, OffsetDateTime at) {
        mapper.completeOperationRun(id, outcome, at);
    }

    public void insertProviderCall(PracticeAiProviderCallEntity entity) {
        mapper.insertProviderCall(entity);
    }

    public void completeProviderCall(
            UUID id, String outcome, String traceId, Long latencyMs, OffsetDateTime at
    ) {
        mapper.completeProviderCall(id, outcome, traceId, latencyMs, at);
    }

    public void insertEvidenceBundle(PracticeEvidenceBundleEntity entity) {
        mapper.insertEvidenceBundle(entity);
    }

    public void insertJudgeResult(PracticeJudgeResultEntity entity) {
        mapper.insertJudgeResult(entity);
    }
}
