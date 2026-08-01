package com.zhangspaghetti.babytalk.practice.generated.quality;

import com.zhangspaghetti.babytalk.practice.agentic.config.GenerationProfile;
import com.zhangspaghetti.babytalk.practice.generated.contract.CompleteGeneratedBundle;
import com.zhangspaghetti.babytalk.practice.generated.evidence.EvidenceSummary;
import java.util.Comparator;
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
        List<BranchRequirement> branchRequirements,
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
        branchRequirements = Objects.requireNonNull(branchRequirements, "branchRequirements").stream()
                .sorted(Comparator.comparing(BranchRequirement::branch))
                .toList();
        if (branchRequirements.size() > Branch.values().length
                || branchRequirements.stream().map(BranchRequirement::branch).distinct().count()
                        != branchRequirements.size()) {
            throw new IllegalArgumentException("repair branch requirements must be unique and bounded");
        }
        repairDirectives = List.copyOf(Objects.requireNonNull(repairDirectives, "repairDirectives"));
        evidenceSummaries = List.copyOf(Objects.requireNonNull(evidenceSummaries, "evidenceSummaries"));
        Objects.requireNonNull(generationProfile, "generationProfile");
    }

    public record BranchRequirement(
            Branch branch,
            List<GeneratedOutputViolationCode> violationCodes
    ) {
        public BranchRequirement {
            Objects.requireNonNull(branch, "branch");
            violationCodes = Objects.requireNonNull(violationCodes, "violationCodes").stream()
                    .peek(violation -> Objects.requireNonNull(violation, "branch violation"))
                    .distinct()
                    .sorted()
                    .toList();
            if (violationCodes.isEmpty()
                    || violationCodes.size() > 6
                    || violationCodes.stream().anyMatch(violation -> !violation.repairable())) {
                throw new IllegalArgumentException(
                        "branch requirements must contain bounded repairable violations");
            }
        }
    }

    public enum Branch {
        STARTER("starter"),
        COOPERATING("cooperating"),
        HESITANT("hesitant"),
        RESISTING("resisting"),
        NO_RESPONSE("no_response"),
        OTHER("other");

        private final String wireValue;

        Branch(String wireValue) {
            this.wireValue = wireValue;
        }

        public String wireValue() {
            return wireValue;
        }
    }
}
