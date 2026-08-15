package com.zhangspaghetti.babytalk.gateway;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.test.web.reactive.server.WebTestClient;

class CandidateCompatibilityControllerTest {

    @Test
    void exposesOnlySafeFrozenCandidateCompatibilityFields() {
        var controller = new CandidateCompatibilityController("btqa-2026-08-15", "33");
        WebTestClient client = WebTestClient.bindToController(controller).build();

        client.get().uri("/qa/candidate-compatibility")
                .exchange()
                .expectStatus().isOk()
                .expectBody()
                .jsonPath("$.candidateId").isEqualTo("btqa-2026-08-15")
                .jsonPath("$.requiredMigrationVersion").isEqualTo("33")
                .jsonPath("$.status").isEqualTo("compatible");

        var response = controller.compatibility();
        assertThat(response).hasNoNullFieldsOrProperties();
    }
}
