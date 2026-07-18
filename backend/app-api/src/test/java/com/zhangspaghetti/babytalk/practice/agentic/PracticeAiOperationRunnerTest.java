package com.zhangspaghetti.babytalk.practice.agentic;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.openai.errors.OpenAIIoException;
import com.openai.errors.OpenAIServiceException;
import java.net.SocketTimeoutException;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.ai.chat.client.ChatClient;

class PracticeAiOperationRunnerTest {

    private static final Clock CLOCK = Clock.fixed(Instant.parse("2026-07-18T02:00:00Z"), ZoneOffset.UTC);
    private static final String HASH = "a".repeat(64);

    @Test
    void insertsOperationBeforeCallsAndFallsBackOnceAfterStructuredOutputFailure() {
        var primary = provider("primary");
        var secondary = provider("secondary");
        var audit = new CapturingAuditPort();
        var calls = new ArrayList<String>();
        var runner = runner(List.of(primary, secondary), audit);

        var result = runner.execute(request(PracticeAiCapability.CUSTOM_SCENE_GENERATOR, resolved -> {
            calls.add(resolved.providerName());
            if (resolved.providerName().equals("primary")) {
                throw new PracticeAiStructuredOutputCaller.StructuredOutputInvalidException();
            }
            return new OperationRequest.ProviderInvocationResult<>("generated", "trace_secondary:1");
        }));

        assertThat(result.value()).isEqualTo("generated");
        assertThat(result.providerName()).isEqualTo("secondary");
        assertThat(calls).containsExactly("primary", "secondary");
        assertThat(audit.events).containsExactly(
                "operation:started",
                "primary:started",
                "primary:structured_output_invalid",
                "secondary:started",
                "secondary:succeeded",
                "operation:succeeded");
        assertThat(audit.startedCalls)
                .extracting(PracticeAiAuditPort.ProviderCallStarted::attemptTraceId)
                .doesNotHaveDuplicates();
    }

    @Test
    void allProviderExhaustionIsTypedAndAttemptsEachProviderAtMostOnce() {
        var audit = new CapturingAuditPort();
        var callCount = new HashMap<String, Integer>();
        var runner = runner(List.of(provider("primary"), provider("secondary")), audit);

        assertThatThrownBy(() -> runner.execute(request(PracticeAiCapability.CUSTOM_SCENE_GENERATOR, resolved -> {
            callCount.merge(resolved.providerName(), 1, Integer::sum);
            throw new OpenAIIoException("connection failed");
        })))
                .isInstanceOf(PracticeAiOperationRunner.ProvidersExhaustedException.class)
                .satisfies(error -> assertThat(((PracticeAiOperationRunner.ProvidersExhaustedException) error).code())
                        .isEqualTo("providers_exhausted"));

        assertThat(callCount).containsExactlyInAnyOrderEntriesOf(Map.of("primary", 1, "secondary", 1));
        assertThat(audit.completedCalls)
                .extracting(PracticeAiAuditPort.ProviderCallCompleted::outcome)
                .containsExactly("connection_error", "connection_error");
        assertThat(audit.events.get(audit.events.size() - 1)).isEqualTo("operation:providers_exhausted");
    }

    @ParameterizedTest
    @ValueSource(strings = {"REJECT", "REPAIR"})
    void successfulJudgeVerdictDoesNotFallBack(String verdict) {
        var audit = new CapturingAuditPort();
        var invoked = new ArrayList<String>();
        var runner = runner(List.of(provider("primary"), provider("secondary")), audit);

        var result = runner.execute(request(PracticeAiCapability.CUSTOM_SCENE_QUALITY_JUDGE, resolved -> {
            invoked.add(resolved.providerName());
            return new OperationRequest.ProviderInvocationResult<>(verdict, null);
        }));

        assertThat(result.value()).isEqualTo(verdict);
        assertThat(invoked).containsExactly("primary");
        assertThat(audit.startedOperations.get(0).operationType()).isEqualTo("quality_judge");
    }

    @Test
    void succeededProviderAuditFailurePropagatesWithoutFallbackOrFailureRewrite() {
        var auditFailure = new IllegalStateException("provider success audit unavailable");
        var audit = new FailingAuditPort(FailurePoint.SUCCEEDED_PROVIDER, auditFailure);
        var invoked = new ArrayList<String>();
        var runner = runner(List.of(provider("primary"), provider("secondary")), audit);

        assertThatThrownBy(() -> runner.execute(request(
                        PracticeAiCapability.CUSTOM_SCENE_GENERATOR,
                        resolved -> {
                            invoked.add(resolved.providerName());
                            return new OperationRequest.ProviderInvocationResult<>("generated", null);
                        })))
                .isSameAs(auditFailure);

        assertThat(invoked).containsExactly("primary");
        assertThat(audit.completedCalls).isEmpty();
        assertThat(audit.startedCalls)
                .extracting(PracticeAiAuditPort.ProviderCallStarted::providerName)
                .containsExactly("primary");
    }

    @Test
    void succeededOperationAuditFailurePropagatesWithoutFallbackOrProviderFailureRewrite() {
        var auditFailure = new IllegalStateException("operation success audit unavailable");
        var audit = new FailingAuditPort(FailurePoint.SUCCEEDED_OPERATION, auditFailure);
        var invoked = new ArrayList<String>();
        var runner = runner(List.of(provider("primary"), provider("secondary")), audit);

        assertThatThrownBy(() -> runner.execute(request(
                        PracticeAiCapability.CUSTOM_SCENE_GENERATOR,
                        resolved -> {
                            invoked.add(resolved.providerName());
                            return new OperationRequest.ProviderInvocationResult<>("generated", null);
                        })))
                .isSameAs(auditFailure);

        assertThat(invoked).containsExactly("primary");
        assertThat(audit.completedCalls)
                .extracting(PracticeAiAuditPort.ProviderCallCompleted::outcome)
                .containsExactly("succeeded");
        assertThat(audit.startedCalls)
                .extracting(PracticeAiAuditPort.ProviderCallStarted::providerName)
                .containsExactly("primary");
    }

    @Test
    void failedProviderAuditFailurePropagatesWithoutFallback() {
        var auditFailure = new IllegalStateException("provider failure audit unavailable");
        var audit = new FailingAuditPort(FailurePoint.FAILED_PROVIDER, auditFailure);
        var invoked = new ArrayList<String>();
        var runner = runner(List.of(provider("primary"), provider("secondary")), audit);

        assertThatThrownBy(() -> runner.execute(request(
                        PracticeAiCapability.CUSTOM_SCENE_GENERATOR,
                        resolved -> {
                            invoked.add(resolved.providerName());
                            throw new PracticeAiStructuredOutputCaller.StructuredOutputInvalidException();
                        })))
                .isSameAs(auditFailure);

        assertThat(invoked).containsExactly("primary");
        assertThat(audit.completedCalls).isEmpty();
        assertThat(audit.startedCalls)
                .extracting(PracticeAiAuditPort.ProviderCallStarted::providerName)
                .containsExactly("primary");
    }

    @Test
    void providerTraceIdIsPersistedOnlyWhenItMatchesTrustedPattern() {
        var invalidAudit = new CapturingAuditPort();
        var invalidResult = runner(List.of(provider("primary")), invalidAudit).execute(request(
                PracticeAiCapability.CUSTOM_SCENE_REPAIR,
                resolved -> new OperationRequest.ProviderInvocationResult<>("ok", "bad trace\nscene text")));

        var validAudit = new CapturingAuditPort();
        var validResult = runner(List.of(provider("primary")), validAudit).execute(request(
                PracticeAiCapability.CUSTOM_SCENE_REPAIR,
                resolved -> new OperationRequest.ProviderInvocationResult<>("ok", "req_1/part:2")));

        assertThat(invalidResult.providerTraceId()).isNull();
        assertThat(invalidAudit.completedCalls.get(0).providerTraceId()).isNull();
        assertThat(validResult.providerTraceId()).isEqualTo("req_1/part:2");
        assertThat(validAudit.completedCalls.get(0).providerTraceId()).isEqualTo("req_1/part:2");
    }

    @Test
    void classifierMapsTimeoutRateLimitServerConnectionAndStructuredFailures() {
        var classifier = new PracticeAiCallFailureClassifier();
        var rateLimit = mock(OpenAIServiceException.class);
        var serverError = mock(OpenAIServiceException.class);
        when(rateLimit.statusCode()).thenReturn(429);
        when(serverError.statusCode()).thenReturn(503);

        assertThat(classifier.classify(new OpenAIIoException("timeout", new SocketTimeoutException())))
                .isEqualTo("timeout");
        assertThat(classifier.classify(rateLimit)).isEqualTo("rate_limited");
        assertThat(classifier.classify(serverError)).isEqualTo("server_error");
        assertThat(classifier.classify(new OpenAIIoException("connection"))).isEqualTo("connection_error");
        assertThat(classifier.classify(new PracticeAiStructuredOutputCaller.StructuredOutputInvalidException()))
                .isEqualTo("structured_output_invalid");
    }

    @Test
    void everyClassifiedInfrastructureFailureFallsBackToNextProvider() {
        var rateLimit = mock(OpenAIServiceException.class);
        var serverError = mock(OpenAIServiceException.class);
        when(rateLimit.statusCode()).thenReturn(429);
        when(serverError.statusCode()).thenReturn(503);
        var failures = List.<RuntimeException>of(
                new OpenAIIoException("timeout", new SocketTimeoutException()),
                rateLimit,
                serverError,
                new OpenAIIoException("connection"),
                new PracticeAiStructuredOutputCaller.StructuredOutputInvalidException());
        var expectedOutcomes = List.of(
                "timeout", "rate_limited", "server_error", "connection_error", "structured_output_invalid");

        for (int index = 0; index < failures.size(); index++) {
            var audit = new CapturingAuditPort();
            var failure = failures.get(index);
            var runner = runner(List.of(provider("primary"), provider("secondary")), audit);

            var result = runner.execute(request(PracticeAiCapability.CUSTOM_SCENE_GENERATOR, resolved -> {
                if (resolved.providerName().equals("primary")) {
                    throw failure;
                }
                return new OperationRequest.ProviderInvocationResult<>("ok", null);
            }));

            assertThat(result.providerName()).isEqualTo("secondary");
            assertThat(audit.completedCalls)
                    .extracting(PracticeAiAuditPort.ProviderCallCompleted::outcome)
                    .containsExactly(expectedOutcomes.get(index), "succeeded");
        }
    }

    @Test
    void auditBoundaryExposesOnlyTrustedMetadata() {
        assertThat(componentNames(PracticeAiAuditPort.OperationRunStarted.class)).containsExactlyInAnyOrder(
                "operationRunId", "operationType", "subjectType", "subjectId", "generatedContentId",
                "attemptNumber", "evidenceBundleId", "capabilityName", "promptVersion", "promptHash",
                "policyVersion", "policyHash", "startedAt");
        assertThat(componentNames(PracticeAiAuditPort.ProviderCallStarted.class)).containsExactlyInAnyOrder(
                "providerCallId", "operationRunId", "providerName", "providerType", "modelName",
                "fallbackIndex", "attemptTraceId", "routingPolicyVersion", "routingPolicyHash", "startedAt");
    }

    private Set<String> componentNames(Class<?> recordType) {
        return java.util.Arrays.stream(recordType.getRecordComponents())
                .map(java.lang.reflect.RecordComponent::getName)
                .collect(java.util.stream.Collectors.toSet());
    }

    private PracticeAiOperationRunner runner(List<ResolvedProvider> providers, PracticeAiAuditPort audit) {
        var manager = mock(PracticeAiProviderManager.class);
        when(manager.route(org.mockito.ArgumentMatchers.any())).thenReturn(providers);
        when(manager.routingPolicyVersion()).thenReturn("custom-scene-routing-v1");
        when(manager.routingPolicyHash()).thenReturn(HASH);
        return new PracticeAiOperationRunner(manager, audit, new PracticeAiCallFailureClassifier(), CLOCK);
    }

    private OperationRequest<String> request(
            PracticeAiCapability capability,
            OperationRequest.ProviderInvocation<String> invocation
    ) {
        return new OperationRequest<>(
                capability,
                "generated_content",
                "pgc_task6",
                "pgc_task6",
                1,
                UUID.fromString("11111111-1111-1111-1111-111111111111"),
                "prompt-v1",
                HASH,
                "policy-v1",
                HASH,
                invocation);
    }

    private ResolvedProvider provider(String name) {
        return new ResolvedProvider(name, "openai-compatible", name + "-model", mock(ChatClient.class));
    }

    private static class CapturingAuditPort implements PracticeAiAuditPort {
        final List<String> events = new ArrayList<>();
        final List<OperationRunStarted> startedOperations = new ArrayList<>();
        final List<ProviderCallStarted> startedCalls = new ArrayList<>();
        final List<ProviderCallCompleted> completedCalls = new ArrayList<>();

        @Override
        public void insertOperationRun(OperationRunStarted operation) {
            startedOperations.add(operation);
            events.add("operation:started");
        }

        @Override
        public void completeOperationRun(OperationRunCompleted operation) {
            events.add("operation:" + operation.outcome());
        }

        @Override
        public void insertProviderCall(ProviderCallStarted call) {
            startedCalls.add(call);
            events.add(call.providerName() + ":started");
        }

        @Override
        public void completeProviderCall(ProviderCallCompleted call) {
            completedCalls.add(call);
            var providerName = startedCalls.stream()
                    .filter(started -> started.providerCallId().equals(call.providerCallId()))
                    .findFirst().orElseThrow().providerName();
            events.add(providerName + ":" + call.outcome());
        }
    }

    private enum FailurePoint {
        SUCCEEDED_PROVIDER,
        SUCCEEDED_OPERATION,
        FAILED_PROVIDER
    }

    private static final class FailingAuditPort extends CapturingAuditPort {
        private final FailurePoint failurePoint;
        private final RuntimeException failure;

        private FailingAuditPort(FailurePoint failurePoint, RuntimeException failure) {
            this.failurePoint = failurePoint;
            this.failure = failure;
        }

        @Override
        public void completeOperationRun(OperationRunCompleted operation) {
            if (failurePoint == FailurePoint.SUCCEEDED_OPERATION && operation.outcome().equals("succeeded")) {
                throw failure;
            }
            super.completeOperationRun(operation);
        }

        @Override
        public void completeProviderCall(ProviderCallCompleted call) {
            boolean succeeded = call.outcome().equals("succeeded");
            if ((failurePoint == FailurePoint.SUCCEEDED_PROVIDER && succeeded)
                    || (failurePoint == FailurePoint.FAILED_PROVIDER && !succeeded)) {
                throw failure;
            }
            super.completeProviderCall(call);
        }
    }
}
