package com.zhangspaghetti.babytalk.practice.generated.internal;

import com.zhangspaghetti.babytalk.practice.generated.GenerationAttemptAuditPort;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGenerationAttemptEntity;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
class GenerationAttemptAuditPersistenceAdapter implements GenerationAttemptAuditPort {

    private final PracticeGenerationAuditMapper mapper;

    GenerationAttemptAuditPersistenceAdapter(PracticeGenerationAuditMapper mapper) {
        this.mapper = mapper;
    }

    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void startAttempt(AttemptStarted attempt) {
        mapper.insertAttempt(new PracticeGenerationAttemptEntity(
                attempt.attemptId(),
                attempt.generatedContentId(),
                attempt.attemptNumber(),
                attempt.attemptType(),
                "started",
                null,
                List.of(),
                attempt.startedAt(),
                null));
    }

    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void completeAttempt(AttemptCompleted attempt) {
        mapper.completeAttempt(
                attempt.attemptId(),
                attempt.outcome(),
                attempt.violationCodes(),
                attempt.completedAt());
    }
}
