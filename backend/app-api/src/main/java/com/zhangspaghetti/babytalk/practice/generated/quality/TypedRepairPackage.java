package com.zhangspaghetti.babytalk.practice.generated.quality;

import com.zhangspaghetti.babytalk.practice.agentic.config.GenerationProfile;
import com.zhangspaghetti.babytalk.practice.generated.contract.CompleteGeneratedBundle;
import com.zhangspaghetti.babytalk.practice.generated.evidence.EvidenceSummary;
import java.util.List;
import java.util.Objects;

public record TypedRepairPackage(
        String displayText,
        String ageRange,
        String parentGoal,
        CompleteGeneratedBundle previousBundle,
        JudgeVerdict effectiveVerdict,
        List<JudgeDimension> failedDimensions,
        List<String> violationCodes,
        List<RepairDirective> repairDirectives,
        List<EvidenceSummary> evidenceSummaries,
        GenerationProfile generationProfile
) {
    public TypedRepairPackage {
        Objects.requireNonNull(displayText, "displayText");
        Objects.requireNonNull(ageRange, "ageRange");
        Objects.requireNonNull(parentGoal, "parentGoal");
        Objects.requireNonNull(previousBundle, "previousBundle");
        Objects.requireNonNull(effectiveVerdict, "effectiveVerdict");
        failedDimensions = List.copyOf(Objects.requireNonNull(failedDimensions, "failedDimensions"));
        violationCodes = List.copyOf(Objects.requireNonNull(violationCodes, "violationCodes"));
        repairDirectives = List.copyOf(Objects.requireNonNull(repairDirectives, "repairDirectives"));
        evidenceSummaries = List.copyOf(Objects.requireNonNull(evidenceSummaries, "evidenceSummaries"));
        Objects.requireNonNull(generationProfile, "generationProfile");
    }
}
