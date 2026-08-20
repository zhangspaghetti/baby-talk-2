package com.zhangspaghetti.babytalk.gateway;

import java.util.Objects;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/** Public, non-secret identity used to bind a QA APK to its deployed candidate. */
@RestController
public class CandidateCompatibilityController {

    private static final Pattern SAFE_CANDIDATE_ID = Pattern.compile("^[a-z0-9][a-z0-9._-]{2,127}$");
    private static final Pattern SAFE_MIGRATION_VERSION = Pattern.compile("^[0-9]+(?:_[0-9]+)?$");

    private final String candidateId;
    private final String requiredMigrationVersion;

    public CandidateCompatibilityController(
            @Value("${babytalk.candidate.id}") String candidateId,
            @Value("${babytalk.candidate.required-migration-version}") String requiredMigrationVersion
    ) {
        this.candidateId = require(candidateId, "babytalk.candidate.id", SAFE_CANDIDATE_ID,
                "must be a safe immutable candidate identifier");
        this.requiredMigrationVersion = require(requiredMigrationVersion,
                "babytalk.candidate.required-migration-version", SAFE_MIGRATION_VERSION,
                "must be a Flyway version");
    }

    @GetMapping("/qa/candidate-compatibility")
    public CandidateCompatibilityResponse compatibility() {
        return new CandidateCompatibilityResponse(candidateId, requiredMigrationVersion, "compatible");
    }

    public record CandidateCompatibilityResponse(
            String candidateId,
            String requiredMigrationVersion,
            String status
    ) {
    }

    private static String require(
            String value,
            String property,
            Pattern pattern,
            String constraint
    ) {
        var normalized = Objects.requireNonNullElse(value, "").trim();
        if (normalized.isEmpty()) {
            throw new IllegalStateException(property + " is required");
        }
        if (!pattern.matcher(normalized).matches()) {
            throw new IllegalStateException(property + " " + constraint);
        }
        return normalized;
    }
}
