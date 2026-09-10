package com.zhangspaghetti.babytalk.practice.agentic;

import java.util.Objects;
import java.util.UUID;
import java.util.function.Supplier;

public record OperationRequest<T>(
        PracticeAiCapability capability,
        String subjectType,
        String subjectId,
        String generatedContentId,
        Integer attemptNumber,
        UUID evidenceBundleId,
        String promptVersion,
        String promptHash,
        String policyVersion,
        String policyHash,
        ProviderInvocation<T> invocation
) {
    public OperationRequest {
        Objects.requireNonNull(capability, "capability");
        requireNonBlank(subjectType, "subjectType");
        requireNonBlank(subjectId, "subjectId");
        requireNonBlank(generatedContentId, "generatedContentId");
        requireNonBlank(promptVersion, "promptVersion");
        requireHash(promptHash, "promptHash");
        Objects.requireNonNull(invocation, "invocation");
        if (!"generated_content".equals(subjectType) || !subjectId.equals(generatedContentId)) {
            throw new IllegalArgumentException("operation subject must identify generated content");
        }
        if (attemptNumber == null || attemptNumber < 1 || attemptNumber > 5) {
            throw new IllegalArgumentException("attemptNumber must be between 1 and 5");
        }
        if ((policyVersion == null) != (policyHash == null)) {
            throw new IllegalArgumentException("policy version and hash must be supplied together");
        }
        if (policyVersion != null) {
            requireNonBlank(policyVersion, "policyVersion");
            requireHash(policyHash, "policyHash");
        }
    }

    private static void requireNonBlank(String value, String name) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(name + " must be non-blank");
        }
    }

    private static void requireHash(String value, String name) {
        if (value == null || !value.matches("[0-9a-f]{64}")) {
            throw new IllegalArgumentException(name + " must be a lowercase SHA-256 hash");
        }
    }

    public static <T> T atFailureStage(ProviderFailureStage failureStage, Supplier<T> operation) {
        Objects.requireNonNull(failureStage, "failureStage");
        Objects.requireNonNull(operation, "operation");
        if (failureStage == ProviderFailureStage.UNKNOWN) {
            throw new IllegalArgumentException("explicit provider failure stage must not be unknown");
        }
        try {
            return operation.get();
        } catch (StagedProviderFailure failure) {
            throw failure;
        } catch (RuntimeException failure) {
            throw new StagedProviderFailure(failureStage, failure);
        }
    }

    public enum ProviderFailureStage {
        PROVIDER_RESPONSE_BINDING,
        CONTENT_STRICT_PARSER,
        UNKNOWN
    }

    static final class StagedProviderFailure extends RuntimeException {
        private final ProviderFailureStage failureStage;
        private final RuntimeException originalFailure;

        private StagedProviderFailure(
                ProviderFailureStage failureStage,
                RuntimeException originalFailure
        ) {
            super("staged_provider_failure", originalFailure, false, false);
            this.failureStage = failureStage;
            this.originalFailure = originalFailure;
        }

        ProviderFailureStage failureStage() {
            return failureStage;
        }

        RuntimeException originalFailure() {
            return originalFailure;
        }
    }

    @FunctionalInterface
    public interface ProviderInvocation<T> {
        ProviderInvocationResult<T> invoke(ResolvedProvider provider);
    }

    public record ProviderInvocationResult<T>(T value, String providerTraceId) {
        public ProviderInvocationResult {
            Objects.requireNonNull(value, "value");
        }
    }
}
