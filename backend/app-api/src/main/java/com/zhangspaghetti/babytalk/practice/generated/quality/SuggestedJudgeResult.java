package com.zhangspaghetti.babytalk.practice.generated.quality;

import java.util.List;
import java.util.Map;

public record SuggestedJudgeResult(
        JudgeVerdict suggestedVerdict,
        Map<JudgeDimension, DimensionResult> dimensionResults,
        List<String> violationCodes,
        List<RepairDirective> repairDirectives,
        List<EvidenceGapCode> evidenceGapCodes,
        Double confidence
) {
    public SuggestedJudgeResult {
        dimensionResults = dimensionResults == null ? null : Map.copyOf(dimensionResults);
        violationCodes = violationCodes == null ? null : List.copyOf(violationCodes);
        repairDirectives = repairDirectives == null ? null : List.copyOf(repairDirectives);
        evidenceGapCodes = evidenceGapCodes == null ? null : List.copyOf(evidenceGapCodes);
    }
}
