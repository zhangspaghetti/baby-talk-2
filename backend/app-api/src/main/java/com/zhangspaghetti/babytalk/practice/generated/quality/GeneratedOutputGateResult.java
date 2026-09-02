package com.zhangspaghetti.babytalk.practice.generated.quality;

import com.zhangspaghetti.babytalk.practice.generated.SceneContentGenerator.GeneratedPracticeContentCandidate;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;

public record GeneratedOutputGateResult(
        GeneratedPracticeContentCandidate normalizedCandidate,
        List<GeneratedOutputViolationCode> terminalViolations,
        List<GeneratedOutputViolationCode> repairableViolations,
        List<GeneratedOutputViolationDiagnostic> terminalViolationDiagnostics,
        List<GeneratedOutputViolationDiagnostic> repairableViolationDiagnostics
) {

    public GeneratedOutputGateResult {
        terminalViolations = sortedDistinct(terminalViolations);
        repairableViolations = sortedDistinct(repairableViolations);
        terminalViolationDiagnostics = sortedDistinctDiagnostics(terminalViolationDiagnostics);
        repairableViolationDiagnostics = sortedDistinctDiagnostics(repairableViolationDiagnostics);
        requireDiagnosticsMatch(
                terminalViolationDiagnostics,
                terminalViolations,
                "terminal diagnostic must match a terminal violation");
        requireDiagnosticsMatch(
                repairableViolationDiagnostics,
                repairableViolations,
                "repairable diagnostic must match a repairable violation");
    }

    public GeneratedOutputGateResult(
            GeneratedPracticeContentCandidate normalizedCandidate,
            List<GeneratedOutputViolationCode> terminalViolations,
            List<GeneratedOutputViolationCode> repairableViolations
    ) {
        this(normalizedCandidate, terminalViolations, repairableViolations, List.of(), List.of());
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

    private static List<GeneratedOutputViolationDiagnostic> sortedDistinctDiagnostics(
            List<GeneratedOutputViolationDiagnostic> diagnostics
    ) {
        Objects.requireNonNull(diagnostics, "diagnostics");
        return diagnostics.stream()
                .filter(Objects::nonNull)
                .distinct()
                .sorted(Comparator.comparing(GeneratedOutputViolationDiagnostic::auditCode))
                .toList();
    }

    private static void requireDiagnosticsMatch(
            List<GeneratedOutputViolationDiagnostic> diagnostics,
            List<GeneratedOutputViolationCode> violations,
            String message
    ) {
        if (diagnostics.stream()
                .map(GeneratedOutputViolationDiagnostic::code)
                .anyMatch(code -> !violations.contains(code))) {
            throw new IllegalArgumentException(message);
        }
    }
}
