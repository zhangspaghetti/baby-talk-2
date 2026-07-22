package com.zhangspaghetti.babytalk.practice.agentic;

import java.time.Clock;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Objects;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(
        prefix = "babytalk.practice.discovery.custom-scene",
        name = "provider-mode",
        havingValue = "agentic"
)
public class PracticeAiOperationRunner {

    private static final Pattern PROVIDER_TRACE_PATTERN =
            Pattern.compile("[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}");

    private final PracticeAiProviderManager providerManager;
    private final PracticeAiAuditPort auditPort;
    private final PracticeAiCallFailureClassifier failureClassifier;
    private final Clock clock;

    @Autowired
    public PracticeAiOperationRunner(
            PracticeAiProviderManager providerManager,
            PracticeAiAuditPort auditPort,
            PracticeAiCallFailureClassifier failureClassifier
    ) {
        this(providerManager, auditPort, failureClassifier, Clock.systemUTC());
    }

    PracticeAiOperationRunner(
            PracticeAiProviderManager providerManager,
            PracticeAiAuditPort auditPort,
            PracticeAiCallFailureClassifier failureClassifier,
            Clock clock
    ) {
        this.providerManager = Objects.requireNonNull(providerManager, "providerManager");
        this.auditPort = Objects.requireNonNull(auditPort, "auditPort");
        this.failureClassifier = Objects.requireNonNull(failureClassifier, "failureClassifier");
        this.clock = Objects.requireNonNull(clock, "clock");
    }

    public <T> OperationResult<T> execute(OperationRequest<T> request) {
        Objects.requireNonNull(request, "request");
        UUID operationRunId = UUID.randomUUID();
        auditPort.insertOperationRun(new PracticeAiAuditPort.OperationRunStarted(
                operationRunId,
                operationType(request.capability()),
                request.subjectType(),
                request.subjectId(),
                request.generatedContentId(),
                request.attemptNumber(),
                request.evidenceBundleId(),
                request.capability().propertyKey(),
                request.promptVersion(),
                request.promptHash(),
                request.policyVersion(),
                request.policyHash(),
                now()));

        var providers = providerManager.route(request.capability());
        for (int fallbackIndex = 0; fallbackIndex < providers.size(); fallbackIndex++) {
            var provider = providers.get(fallbackIndex);
            UUID providerCallId = UUID.randomUUID();
            UUID attemptTraceId = UUID.randomUUID();
            auditPort.insertProviderCall(new PracticeAiAuditPort.ProviderCallStarted(
                    providerCallId,
                    operationRunId,
                    provider.providerName(),
                    provider.providerType(),
                    provider.modelName(),
                    fallbackIndex,
                    attemptTraceId,
                    providerManager.routingPolicyVersion(),
                    providerManager.routingPolicyHash(),
                    now()));
            long startedNanos = System.nanoTime();
            OperationRequest.ProviderInvocationResult<T> invocationResult;
            try {
                invocationResult = Objects.requireNonNull(
                        request.invocation().invoke(provider), "provider invocation result");
            } catch (RuntimeException failure) {
                var fallbackOutcome = failureClassifier.classify(failure);
                if (fallbackOutcome.isEmpty()) {
                    auditPort.completeProviderCall(new PracticeAiAuditPort.ProviderCallCompleted(
                            providerCallId, "internal_error", null, latencyMillis(startedNanos), now()));
                    auditPort.completeOperationRun(new PracticeAiAuditPort.OperationRunCompleted(
                            operationRunId, "internal_error", now()));
                    throw failure;
                }
                auditPort.completeProviderCall(new PracticeAiAuditPort.ProviderCallCompleted(
                        providerCallId,
                        fallbackOutcome.orElseThrow(),
                        null,
                        latencyMillis(startedNanos),
                        now()));
                continue;
            }
            String providerTraceId = sanitizeProviderTrace(invocationResult.providerTraceId());
            auditPort.completeProviderCall(new PracticeAiAuditPort.ProviderCallCompleted(
                    providerCallId, "succeeded", providerTraceId, latencyMillis(startedNanos), now()));
            auditPort.completeOperationRun(new PracticeAiAuditPort.OperationRunCompleted(
                    operationRunId, "succeeded", now()));
            return new OperationResult<>(
                    invocationResult.value(),
                    operationRunId,
                    providerCallId,
                    provider.providerName(),
                    provider.modelName(),
                    providerTraceId);
        }
        auditPort.completeOperationRun(new PracticeAiAuditPort.OperationRunCompleted(
                operationRunId, "providers_exhausted", now()));
        throw new ProvidersExhaustedException(operationRunId);
    }

    private String sanitizeProviderTrace(String providerTraceId) {
        return providerTraceId != null && PROVIDER_TRACE_PATTERN.matcher(providerTraceId).matches()
                ? providerTraceId
                : null;
    }

    private long latencyMillis(long startedNanos) {
        return Math.max(0L, TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startedNanos));
    }

    private OffsetDateTime now() {
        return OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC);
    }

    private String operationType(PracticeAiCapability capability) {
        return switch (capability) {
            case CUSTOM_SCENE_GENERATOR -> "generator";
            case CUSTOM_SCENE_QUALITY_JUDGE -> "quality_judge";
            case CUSTOM_SCENE_REPAIR -> "repair";
        };
    }

    public static final class ProvidersExhaustedException extends RuntimeException {
        private final UUID operationRunId;

        public ProvidersExhaustedException(UUID operationRunId) {
            super("providers_exhausted");
            this.operationRunId = operationRunId;
        }

        public String code() {
            return "providers_exhausted";
        }

        public UUID operationRunId() {
            return operationRunId;
        }
    }
}
