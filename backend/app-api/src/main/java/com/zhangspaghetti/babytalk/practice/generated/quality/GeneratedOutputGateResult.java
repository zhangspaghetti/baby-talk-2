package com.zhangspaghetti.babytalk.practice.generated.quality;

import com.zhangspaghetti.babytalk.practice.generated.CustomSceneGenerator.GeneratedPracticeContentCandidate;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;

public record GeneratedOutputGateResult(
        GeneratedPracticeContentCandidate normalizedCandidate,
        List<GeneratedOutputViolationCode> terminalViolations,
        List<GeneratedOutputViolationCode> repairableViolations
) {

    public GeneratedOutputGateResult {
        terminalViolations = sortedDistinct(terminalViolations);
        repairableViolations = sortedDistinct(repairableViolations);
    }

    public boolean passed() {
        return terminalViolations.isEmpty() && repairableViolations.isEmpty();
    }

    private static List<GeneratedOutputViolationCode> sortedDistinct(
            List<GeneratedOutputViolationCode> violations
    ) {
        Objects.requireNonNull(violations, "violations");
        return violations.stream()
                .filter(Objects::nonNull)
                .distinct()
                .sorted(Comparator.naturalOrder())
                .toList();
    }
}
