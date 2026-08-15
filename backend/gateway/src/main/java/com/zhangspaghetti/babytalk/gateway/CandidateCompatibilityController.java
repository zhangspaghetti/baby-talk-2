package com.zhangspaghetti.babytalk.gateway;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/** Public, non-secret identity used to bind a QA APK to its deployed candidate. */
@RestController
public class CandidateCompatibilityController {

    private final String candidateId;
    private final String requiredMigrationVersion;

    public CandidateCompatibilityController(
            @Value("${babytalk.candidate.id:local-dev}") String candidateId,
            @Value("${babytalk.candidate.required-migration-version:33}") String requiredMigrationVersion
    ) {
        this.candidateId = candidateId;
        this.requiredMigrationVersion = requiredMigrationVersion;
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
}
