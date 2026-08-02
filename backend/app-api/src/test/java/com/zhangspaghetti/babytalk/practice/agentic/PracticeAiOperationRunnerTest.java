package com.zhangspaghetti.babytalk.practice.agentic;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.read.ListAppender;
import com.openai.errors.OpenAIIoException;
import com.openai.errors.OpenAIInvalidDataException;
import com.openai.errors.OpenAIServiceException;
import com.zhangspaghetti.babytalk.practice.agentic.diagnostics.PracticeAiContractViolation;
import com.zhangspaghetti.babytalk.practice.agentic.diagnostics.PracticeAiContractViolation.Category;
import com.zhangspaghetti.babytalk.practice.generated.contract.CompleteGeneratedBundle;
import java.io.IOException;
import java.io.InterruptedIOException;
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
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.slf4j.LoggerFactory;
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

    @Test
    void unclassifiedRuntimeFailureStopsAtPrimaryAndPropagatesOriginalFailure() {
        var audit = new CapturingAuditPort();
        var invoked = new ArrayList<String>();
        var failure = new IllegalStateException(
                "sensitive request body prompt completion endpoint header token secret trace-id");
        var runner = runner(List.of(provider("primary"), provider("secondary")), audit);
        var logger = (Logger) LoggerFactory.getLogger(PracticeAiOperationRunner.class);
        var appender = new ListAppender<ILoggingEvent>();
        appender.start();
        logger.addAppender(appender);

        try {
            assertThatThrownBy(() -> runner.execute(request(
                    PracticeAiCapability.CUSTOM_SCENE_GENERATOR,
                    resolved -> {
                        invoked.add(resolved.providerName());
                        throw failure;
                    }))).isSameAs(failure);
        } finally {
            logger.detachAppender(appender);
            appender.stop();
        }

        assertThat(invoked).containsExactly("primary");
        assertThat(audit.events).containsExactly(
                "operation:started",
                "primary:started",
                "primary:internal_error",
                "operation:internal_error");
        assertThat(appender.list).singleElement().satisfies(event -> {
            assertThat(event.getLevel()).isEqualTo(ch.qos.logback.classic.Level.ERROR);
            assertThat(event.getMessage()).isEqualTo(
                    "Practice AI unclassified provider failure: capability={}, fallbackIndex={}, "
                            + "errorType={}, failureStage={}");
            assertThat(event.getArgumentArray())
                    .containsExactly("custom-scene-generator", 0, "UNKNOWN", "UNKNOWN");
            assertThat(event.getFormattedMessage()).isEqualTo(
                    "Practice AI unclassified provider failure: capability=custom-scene-generator, "
                            + "fallbackIndex=0, errorType=UNKNOWN, failureStage=UNKNOWN");
            assertThat(event.getThrowableProxy()).isNull();
        });
    }

    @Test
    void localIoFailureIsInternalAndDoesNotFallBack() {
        var audit = new CapturingAuditPort();
        var invoked = new ArrayList<String>();
        var failure = new RuntimeException(new IOException("local read failure"));
        var runner = runner(List.of(provider("primary"), provider("secondary")), audit);

        assertThatThrownBy(() -> runner.execute(request(PracticeAiCapability.CUSTOM_SCENE_GENERATOR, resolved -> {
            invoked.add(resolved.providerName());
            throw failure;
        }))).isSameAs(failure);

        assertThat(invoked).containsExactly("primary");
        assertThat(audit.events).containsExactly(
                "operation:started",
                "primary:started",
                "primary:internal_error",
                "operation:internal_error");
    }

    @ParameterizedTest
    @MethodSource("allowlistedDiagnosticFailures")
    void unclassifiedRuntimeFailureUsesOnlyAllowlistedDiagnosticErrorType(
            RuntimeException failure,
            String expectedErrorType,
            String expectedFailureStage
    ) {
        var audit = new CapturingAuditPort();
        var invoked = new ArrayList<String>();
        var runner = runner(List.of(provider("primary"), provider("secondary")), audit);
        var logger = (Logger) LoggerFactory.getLogger(PracticeAiOperationRunner.class);
        var appender = new ListAppender<ILoggingEvent>();
        appender.start();
        logger.addAppender(appender);

        try {
            assertThatThrownBy(() -> runner.execute(request(
                    PracticeAiCapability.CUSTOM_SCENE_REPAIR,
                    resolved -> {
                        invoked.add(resolved.providerName());
                        throw failure;
                    }))).isSameAs(failure);
        } finally {
            logger.detachAppender(appender);
            appender.stop();
        }

        assertThat(appender.list).singleElement().satisfies(event -> {
            assertThat(event.getArgumentArray())
                    .containsExactly("custom-scene-repair", 0, expectedErrorType, expectedFailureStage);
            assertThat(event.getFormattedMessage()).isEqualTo(
                    "Practice AI unclassified provider failure: capability=custom-scene-repair, "
                            + "fallbackIndex=0, errorType=" + expectedErrorType
                            + ", failureStage=" + expectedFailureStage);
            assertThat(event.getThrowableProxy()).isNull();
        });
        assertThat(audit.events).containsExactly(
                "operation:started",
                "primary:started",
                "primary:internal_error",
                "operation:internal_error");
        assertThat(invoked).containsExactly("primary");
    }

    @ParameterizedTest
    @MethodSource("unsafeDiagnosticCauseFailures")
    void diagnosticCauseInspectionCannotReplaceOriginalFailure(RuntimeException failure) {
        var audit = new CapturingAuditPort();
        var invoked = new ArrayList<String>();
        var runner = runner(List.of(provider("primary"), provider("secondary")), audit);
        var logger = (Logger) LoggerFactory.getLogger(PracticeAiOperationRunner.class);
        var appender = new ListAppender<ILoggingEvent>();
        appender.start();
        logger.addAppender(appender);

        try {
            assertThatThrownBy(() -> runner.execute(request(
                    PracticeAiCapability.CUSTOM_SCENE_GENERATOR,
                    resolved -> {
                        invoked.add(resolved.providerName());
                        throw failure;
                    }))).isSameAs(failure);
        } finally {
            logger.detachAppender(appender);
            appender.stop();
        }

        assertThat(appender.list).singleElement().satisfies(event -> {
            assertThat(event.getArgumentArray())
                    .containsExactly("custom-scene-generator", 0, "UNKNOWN", "UNKNOWN");
            assertThat(event.getThrowableProxy()).isNull();
        });
        assertThat(invoked).containsExactly("primary");
        assertThat(audit.events).containsExactly(
                "operation:started",
                "primary:started",
                "primary:internal_error",
                "operation:internal_error");
    }

    @Test
    void providerResponseBindingStageIsLoggedAndOriginalFailureIdentityIsPropagated() {
        var audit = new CapturingAuditPort();
        var invoked = new ArrayList<String>();
        var failureStage = OperationRequest.ProviderFailureStage.PROVIDER_RESPONSE_BINDING;
        var originalFailure = malformedJsonFailure();
        var runner = runner(List.of(provider("primary"), provider("secondary")), audit);
        var logger = (Logger) LoggerFactory.getLogger(PracticeAiOperationRunner.class);
        var appender = new ListAppender<ILoggingEvent>();
        appender.start();
        logger.addAppender(appender);

        try {
            assertThatThrownBy(() -> runner.execute(request(
                    PracticeAiCapability.CUSTOM_SCENE_GENERATOR,
                    resolved -> OperationRequest.atFailureStage(failureStage, () -> {
                        invoked.add(resolved.providerName());
                        throw originalFailure;
                    })))).isSameAs(originalFailure);
        } finally {
            logger.detachAppender(appender);
            appender.stop();
        }

        assertThat(appender.list).singleElement().satisfies(event -> {
            assertThat(event.getArgumentArray())
                    .containsExactly(
                            "custom-scene-generator", 0, "JACKSON", failureStage.name());
            assertThat(event.getThrowableProxy()).isNull();
        });
        assertThat(invoked).containsExactly("primary");
        assertThat(audit.events).containsExactly(
                "operation:started",
                "primary:started",
                "primary:internal_error",
                "operation:internal_error");
    }

    @Test
    void strictParserFailureIsStructuredOutputInvalidAndFallsBackToNextProvider() {
        var audit = new CapturingAuditPort();
        var invoked = new ArrayList<String>();
        var originalFailure = strictProviderParseFailure();
        var runner = runner(List.of(provider("primary"), provider("secondary")), audit);

        var result = runner.execute(request(
                PracticeAiCapability.CUSTOM_SCENE_GENERATOR,
                resolved -> {
                    invoked.add(resolved.providerName());
                    if (resolved.providerName().equals("primary")) {
                        return OperationRequest.atFailureStage(
                                OperationRequest.ProviderFailureStage.CONTENT_STRICT_PARSER,
                                () -> {
                                    throw originalFailure;
                                });
                    }
                    return new OperationRequest.ProviderInvocationResult<>("generated", null);
                }));

        assertThat(result.value()).isEqualTo("generated");
        assertThat(result.providerName()).isEqualTo("secondary");
        assertThat(invoked).containsExactly("primary", "secondary");
        assertThat(audit.events).containsExactly(
                "operation:started",
                "primary:started",
                "primary:structured_output_invalid",
                "secondary:started",
                "secondary:succeeded",
                "operation:succeeded");
    }

    @ParameterizedTest
    @MethodSource("strictParserDiagnosticFailures")
    void strictParserDiagnosticUsesOnlyAllowlistedCategory(
            RuntimeException originalFailure,
            String expectedParserCategory,
            String expectedContractCategory
    ) {
        var audit = new CapturingAuditPort();
        var runner = runner(List.of(provider("primary")), audit);
        var logger = (Logger) LoggerFactory.getLogger(PracticeAiOperationRunner.class);
        var appender = new ListAppender<ILoggingEvent>();
        appender.start();
        logger.addAppender(appender);

        try {
            assertThatThrownBy(() -> runner.execute(request(
                    PracticeAiCapability.CUSTOM_SCENE_GENERATOR,
                    resolved -> OperationRequest.atFailureStage(
                            OperationRequest.ProviderFailureStage.CONTENT_STRICT_PARSER,
                            () -> {
                                throw originalFailure;
                            }))))
                    .isInstanceOf(PracticeAiOperationRunner.ProvidersExhaustedException.class);
        } finally {
            logger.detachAppender(appender);
            appender.stop();
        }

        assertThat(appender.list).singleElement().satisfies(event -> {
            assertThat(event.getLevel()).isEqualTo(ch.qos.logback.classic.Level.WARN);
            assertThat(event.getMessage()).isEqualTo(
                    "Practice AI strict parser rejected provider output: capability={}, "
                            + "fallbackIndex={}, parserFailureCategory={}, contractViolationCategory={}");
            assertThat(event.getArgumentArray())
                    .containsExactly(
                            "custom-scene-generator",
                            0,
                            expectedParserCategory,
                            expectedContractCategory);
            assertThat(event.getThrowableProxy()).isNull();
        });
        assertThat(audit.events).containsExactly(
                "operation:started",
                "primary:started",
                "primary:structured_output_invalid",
                "operation:providers_exhausted");
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
                .hasValue("timeout");
        assertThat(classifier.classify(rateLimit)).hasValue("rate_limited");
        assertThat(classifier.classify(serverError)).hasValue("server_error");
        assertThat(classifier.classify(new OpenAIIoException("connection"))).hasValue("connection_error");
        assertThat(classifier.classify(new PracticeAiStructuredOutputCaller.StructuredOutputInvalidException()))
                .hasValue("structured_output_invalid");
        assertThat(classifier.classify(new IllegalStateException("programming failure"))).isEmpty();
        assertThat(classifier.classify(new RuntimeException(new IOException("local read failure")))).isEmpty();
    }

    @Test
    void classifierRecognizesTheInstalledSdkTimeoutWrapperShape() {
        var classifier = new PracticeAiCallFailureClassifier();

        assertThat(classifier.classify(new OpenAIIoException(
                "Request failed",
                new InterruptedIOException("timeout"))))
                .hasValue("timeout");
    }

    @Test
    void classifierDoesNotGuessTimeoutFromGenericOrNegatedSdkMessages() {
        var classifier = new PracticeAiCallFailureClassifier();

        assertThat(classifier.classify(new OpenAIIoException("Request failed")))
                .hasValue("connection_error");
        assertThat(classifier.classify(new OpenAIIoException("not a timeout")))
                .hasValue("connection_error");
        assertThat(classifier.classify(new OpenAIIoException(
                "Request failed",
                new InterruptedIOException("not a timeout"))))
                .hasValue("connection_error");
        assertThat(classifier.classify(new OpenAIIoException(
                "Request failed",
                new InterruptedIOException("config-invalid"))))
                .hasValue("connection_error");
    }

    @Test
    void classifierDoesNotSwallowFatalCauseInspectionErrors() {
        var classifier = new PracticeAiCallFailureClassifier();

        assertThatThrownBy(() -> classifier.classify(new ThrowingErrorCauseException()))
                .isInstanceOf(AssertionError.class)
                .hasMessage("sensitive diagnostic error");
    }

    @Test
    void everyClassifiedInfrastructureFailureFallsBackToNextProvider() {
        var rateLimit = mock(OpenAIServiceException.class);
        var serverError = mock(OpenAIServiceException.class);
        when(rateLimit.statusCode()).thenReturn(429);
        when(serverError.statusCode()).thenReturn(503);
        var failures = List.<RuntimeException>of(
                new OpenAIIoException("timeout", new SocketTimeoutException()),
                new OpenAIIoException("Request failed", new InterruptedIOException("timeout")),
                rateLimit,
                serverError,
                new OpenAIIoException("connection"),
                new PracticeAiStructuredOutputCaller.StructuredOutputInvalidException());
        var expectedOutcomes = List.of(
                "timeout", "timeout", "rate_limited", "server_error", "connection_error",
                "structured_output_invalid");

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

    private static Stream<Arguments> allowlistedDiagnosticFailures() {
        return Stream.of(
                Arguments.of(
                        new RuntimeException(
                                "sensitive wrapper",
                                new OpenAIInvalidDataException("sensitive provider metadata")),
                        "OPENAI_INVALID_DATA",
                        "UNKNOWN"),
                Arguments.of(malformedJsonFailure(), "JACKSON", "UNKNOWN"),
                Arguments.of(strictProviderParseFailure(), "JACKSON", "UNKNOWN"),
                Arguments.of(
                        new IllegalArgumentException(
                                "sensitive wrapper",
                                new OpenAIInvalidDataException("sensitive provider metadata")),
                        "OPENAI_INVALID_DATA",
                        "UNKNOWN"),
                Arguments.of(
                        new IllegalArgumentException("sensitive argument"), "ILLEGAL_ARGUMENT", "UNKNOWN"),
                Arguments.of(new NullPointerException("sensitive null"), "NULL_POINTER", "UNKNOWN"),
                Arguments.of(new ClassCastException("sensitive type"), "CLASS_CAST", "UNKNOWN"));
    }

    private static Stream<Arguments> unsafeDiagnosticCauseFailures() {
        return Stream.of(
                Arguments.of(new ThrowingCauseException()),
                Arguments.of(new CyclicCauseException()));
    }

    private static Stream<Arguments> strictParserDiagnosticFailures() {
        return Stream.of(
                Arguments.of(strictProviderParseFailure("{"), "JSON_SYNTAX", "UNKNOWN"),
                Arguments.of(strictProviderParseFailure("[]"), "DTO_BINDING", "UNKNOWN"),
                Arguments.of(strictProviderParseFailure("""
                        {
                          "schemaVersion": "custom-scene-generated-output-v1",
                          "scene": {
                            "spaceTitleZh": "x",
                            "activityTitleZh": "x",
                            "sceneTagEn": "x"
                          },
                          "utterances": {}
                        }
                        """), "CONTRACT_VALIDATION", "BRANCH_COMPLETENESS"),
                Arguments.of(
                        new CompleteGeneratedBundle.InvalidProviderResponseException(),
                        "UNKNOWN",
                        "UNKNOWN"),
                Arguments.of(new NullContractCategoryException(), "UNKNOWN", "UNKNOWN"),
                Arguments.of(new ThrowingContractCategoryException(), "UNKNOWN", "UNKNOWN"));
    }

    private static RuntimeException malformedJsonFailure() {
        try {
            tools.jackson.databind.json.JsonMapper.builder().build().readTree("{");
            throw new AssertionError("malformed JSON must fail");
        } catch (tools.jackson.core.JacksonException exception) {
            return exception;
        }
    }

    @Test
    void diagnosticInspectionCannotConsumeOneShotTimeoutCauseBeforeClassification() {
        var audit = new CapturingAuditPort();
        var runner = runner(List.of(provider("primary"), provider("secondary")), audit);

        var result = runner.execute(request(PracticeAiCapability.CUSTOM_SCENE_GENERATOR, resolved -> {
            if (resolved.providerName().equals("primary")) {
                throw new OneShotTimeoutCauseException();
            }
            return new OperationRequest.ProviderInvocationResult<>("ok", null);
        }));

        assertThat(result.providerName()).isEqualTo("secondary");
        assertThat(audit.completedCalls)
                .extracting(PracticeAiAuditPort.ProviderCallCompleted::outcome)
                .containsExactly("timeout", "succeeded");
    }

    private static RuntimeException strictProviderParseFailure() {
        return strictProviderParseFailure("{");
    }

    private static RuntimeException strictProviderParseFailure(String payload) {
        try {
            CompleteGeneratedBundle.ProviderResponse.parse(payload);
            throw new AssertionError("invalid provider response must fail");
        } catch (CompleteGeneratedBundle.InvalidProviderResponseException exception) {
            return exception;
        }
    }

    private PracticeAiOperationRunner runner(List<ResolvedProvider> providers, PracticeAiAuditPort audit) {
        return runner(providers, audit, new PracticeAiCallFailureClassifier());
    }

    private PracticeAiOperationRunner runner(
            List<ResolvedProvider> providers,
            PracticeAiAuditPort audit,
            PracticeAiCallFailureClassifier classifier
    ) {
        var manager = mock(PracticeAiProviderManager.class);
        when(manager.route(org.mockito.ArgumentMatchers.any())).thenReturn(providers);
        when(manager.routingPolicyVersion()).thenReturn("custom-scene-routing-v1");
        when(manager.routingPolicyHash()).thenReturn(HASH);
        return new PracticeAiOperationRunner(manager, audit, classifier, CLOCK);
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

    private static final class ThrowingCauseException extends RuntimeException {
        @Override
        public synchronized Throwable getCause() {
            throw new IllegalStateException("sensitive diagnostic failure");
        }
    }

    private static final class ThrowingErrorCauseException extends RuntimeException {
        @Override
        public synchronized Throwable getCause() {
            throw new AssertionError("sensitive diagnostic error");
        }
    }

    private static final class NullContractCategoryException extends RuntimeException
            implements PracticeAiContractViolation {
        @Override
        public Category category() {
            return null;
        }
    }

    private static final class ThrowingContractCategoryException extends RuntimeException
            implements PracticeAiContractViolation {
        @Override
        public Category category() {
            throw new AssertionError("sensitive diagnostic category error");
        }
    }

    private static final class CyclicCauseException extends RuntimeException {
        private int causeReads;

        @Override
        public synchronized Throwable getCause() {
            causeReads++;
            if (causeReads > 1_000) {
                throw new IllegalStateException("sensitive cause cycle");
            }
            return this;
        }
    }

    private static final class OneShotTimeoutCauseException extends RuntimeException {
        private boolean causeRead;

        @Override
        public synchronized Throwable getCause() {
            if (causeRead) {
                return null;
            }
            causeRead = true;
            return new SocketTimeoutException();
        }
    }
}
