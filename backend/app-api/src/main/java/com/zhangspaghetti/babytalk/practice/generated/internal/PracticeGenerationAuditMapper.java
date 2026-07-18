package com.zhangspaghetti.babytalk.practice.generated.internal;

import com.zhangspaghetti.babytalk.practice.generated.model.PracticeAiOperationRunEntity;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeAiProviderCallEntity;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeEvidenceBundleEntity;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeEvidenceItemEntity;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGenerationAttemptEntity;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeJudgeResultEntity;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
interface PracticeGenerationAuditMapper {

    void insertAttempt(PracticeGenerationAttemptEntity entity);

    void completeAttempt(
            @Param("attemptId") UUID attemptId,
            @Param("outcome") String outcome,
            @Param("violationCodes") List<String> violationCodes,
            @Param("completedAt") OffsetDateTime completedAt);

    void insertOperationRun(PracticeAiOperationRunEntity entity);

    void completeOperationRun(
            @Param("operationRunId") UUID operationRunId,
            @Param("outcome") String outcome,
            @Param("completedAt") OffsetDateTime completedAt);

    void insertProviderCall(PracticeAiProviderCallEntity entity);

    void completeProviderCall(
            @Param("providerCallId") UUID providerCallId,
            @Param("outcome") String outcome,
            @Param("providerTraceId") String providerTraceId,
            @Param("latencyMs") Long latencyMs,
            @Param("completedAt") OffsetDateTime completedAt);

    void insertEvidenceBundle(PracticeEvidenceBundleEntity bundle);

    void insertEvidenceItems(@Param("items") List<PracticeEvidenceItemEntity> items);

    void insertJudgeResult(PracticeJudgeResultEntity result);
}
