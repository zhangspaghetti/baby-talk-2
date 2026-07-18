package com.zhangspaghetti.babytalk.practice.generated.model;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public record PracticeJudgeResultEntity(
        UUID judgeResultId,
        UUID providerCallId,
        String suggestedVerdict,
        String effectiveVerdict,
        String verdictConsistency,
        String dimensionResultsJson,
        List<String> violationCodes,
        List<String> repairDirectives,
        List<String> evidenceGapCodes,
        BigDecimal judgeConfidence,
        String rubricVersion,
        String rubricContentHash,
        OffsetDateTime createdAt
) {
    public PracticeJudgeResultEntity {
        violationCodes = AuditListValues.sortedDistinct(violationCodes);
        repairDirectives = AuditListValues.sortedDistinct(repairDirectives);
        evidenceGapCodes = AuditListValues.sortedDistinct(evidenceGapCodes);
    }
}
