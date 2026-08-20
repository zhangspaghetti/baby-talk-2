package com.zhangspaghetti.babytalk.gateway;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatIllegalStateException;

import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.core.env.SystemEnvironmentPropertySource;
import org.springframework.test.web.reactive.server.WebTestClient;

class CandidateCompatibilityControllerTest {

    @Test
    void exposesOnlySafeFrozenCandidateCompatibilityFields() {
        var controller = new CandidateCompatibilityController("btqa-2026-08-15", "34");
        WebTestClient client = WebTestClient.bindToController(controller).build();

        client.get().uri("/qa/candidate-compatibility")
                .exchange()
                .expectStatus().isOk()
                .expectBody()
                .jsonPath("$.candidateId").isEqualTo("btqa-2026-08-15")
                .jsonPath("$.requiredMigrationVersion").isEqualTo("34")
                .jsonPath("$.status").isEqualTo("compatible");

        var response = controller.compatibility();
        assertThat(response).hasNoNullFieldsOrProperties();
    }

    @Test
    void rejectsMissingCandidateIdentityInsteadOfFallingBack() {
        assertThatIllegalStateException()
                .isThrownBy(() -> new CandidateCompatibilityController("", "34"))
                .withMessage("babytalk.candidate.id is required");
        assertThatIllegalStateException()
                .isThrownBy(() -> new CandidateCompatibilityController("btqa-2026-08-15", ""))
                .withMessage("babytalk.candidate.required-migration-version is required");
    }

    @Test
    void springEnvironmentNameMatchesBabytalkPropertyPrefix() {
        var source = new SystemEnvironmentPropertySource(
                "candidate",
                Map.of(
                        "BABYTALK_CANDIDATE_ID", "btqa-2026-08-15",
                        "BABYTALK_CANDIDATE_REQUIRED_MIGRATION_VERSION", "34"));

        assertThat(source.getProperty("babytalk.candidate.id")).isEqualTo("btqa-2026-08-15");
        assertThat(source.getProperty("babytalk.candidate.required-migration-version"))
                .isEqualTo("34");
        assertThat(source.getProperty("baby.talk.candidate.id")).isNull();

        var legacySource = new SystemEnvironmentPropertySource(
                "legacy-candidate",
                Map.of("BABY_TALK_CANDIDATE_ID", "legacy-candidate"));
        assertThat(legacySource.getProperty("babytalk.candidate.id")).isNull();
        assertThat(legacySource.getProperty("baby.talk.candidate.id")).isEqualTo("legacy-candidate");
    }
}
