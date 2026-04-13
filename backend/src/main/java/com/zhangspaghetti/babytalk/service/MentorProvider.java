package com.zhangspaghetti.babytalk.service;

import java.time.Instant;

public interface MentorProvider {

    ProviderResponse respond(ProviderRequest request);

    record ProviderRequest(
            String correlationId,
            String installationId,
            String surface,
            String mode,
            String prompt,
            String promptSummary,
            boolean authenticated,
            Instant requestedAt
    ) {
    }

    record ProviderResponse(
            String responseText,
            String responseSummary
    ) {
    }

    class ProviderTimeoutException extends RuntimeException {
        public ProviderTimeoutException(String message) {
            super(message);
        }
    }

    class ProviderUnavailableException extends RuntimeException {
        public ProviderUnavailableException(String message) {
            super(message);
        }
    }

    class ProviderMalformedResponseException extends RuntimeException {
        public ProviderMalformedResponseException(String message) {
            super(message);
        }
    }
}
