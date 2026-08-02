package com.zhangspaghetti.babytalk.practice.agentic;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.mock.env.MockEnvironment;

class PracticeAiSingleRequestContractTest {

    @Test
    void oneNamedProviderAttemptMakesExactlyOneOutboundRequestOnServerError() throws Exception {
        assertSingleRequestForStatus(500);
    }

    @Test
    void oneNamedProviderAttemptMakesExactlyOneOutboundRequestOnRateLimit() throws Exception {
        assertSingleRequestForStatus(429);
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "```json\n{\"answer\":\"ok\"}\n```",
            "{\"answer\":\"ok\",\"extra\":true}",
            "{}",
            "{\"answer\":null}",
            "{\"answer\":\"ok\""
    })
    void nonConformingStructuredOutputFailsAfterOneRequestWithoutRepair(String content) throws Exception {
        var requestCount = new AtomicInteger();
        var server = server(requestCount, 200, openAiEnvelope(content));
        try {
            var provider = provider(server);

            assertThatThrownBy(() -> new PracticeAiStructuredOutputCaller().call(
                    provider, "system", "return JSON", Answer.class))
                    .isInstanceOf(PracticeAiStructuredOutputCaller.StructuredOutputInvalidException.class)
                    .hasMessage("structured_output_invalid");
            assertThat(requestCount).hasValue(1);
        } finally {
            server.stop(0);
        }
    }

    @Test
    void conformingStructuredOutputSucceedsAfterOneRequest() throws Exception {
        var requestCount = new AtomicInteger();
        var server = server(requestCount, 200, openAiEnvelope("  \n{\"answer\":\"ok\"}\r\n  "));
        try {
            var provider = provider(server);

            assertThat(new PracticeAiStructuredOutputCaller().call(
                    provider, "system", "return JSON", Answer.class))
                    .isEqualTo(new Answer("ok"));
            assertThat(requestCount).hasValue(1);
        } finally {
            server.stop(0);
        }
    }

    @ParameterizedTest
    @ValueSource(strings = {"", "{\"answer\":\"partial\"}"})
    void structuredOutputStoppedByLengthIsClassifiedAsTruncatedAfterOneRequest(String content) throws Exception {
        var requestCount = new AtomicInteger();
        var server = server(requestCount, 200, openAiEnvelope(content, "length", 100, 600));
        try {
            var provider = provider(server);

            var exception = org.assertj.core.api.Assertions.catchThrowableOfType(
                    () -> new PracticeAiStructuredOutputCaller().callRaw(
                            provider, "system", "return JSON", Answer.class),
                    PracticeAiStructuredOutputCaller.StructuredOutputInvalidException.class);

            assertThat(exception)
                    .isInstanceOf(PracticeAiStructuredOutputCaller.StructuredOutputInvalidException.class)
                    .hasMessage("output_truncated");
            assertThat(exception.providerResponseMetadata()).isEqualTo(
                    new PracticeAiStructuredOutputCaller.ProviderResponseMetadata(
                            PracticeAiStructuredOutputCaller.FinishReason.LENGTH,
                            100,
                            600,
                            700));
            assertThat(new PracticeAiCallFailureClassifier().classify(exception))
                    .hasValue("output_truncated");
            assertThat(requestCount).hasValue(1);
        } finally {
            server.stop(0);
        }
    }

    @Test
    void conformingStructuredOutputSucceedsAfterOneRequestWhenUsageIsOmitted() throws Exception {
        var requestCount = new AtomicInteger();
        var server = server(requestCount, 200, openAiEnvelopeWithoutUsage("{\"answer\":\"ok\"}", "stop"));
        try {
            var provider = provider(server);

            assertThat(new PracticeAiStructuredOutputCaller().call(
                    provider, "system", "return JSON", Answer.class))
                    .isEqualTo(new Answer("ok"));
            assertThat(requestCount).hasValue(1);
        } finally {
            server.stop(0);
        }
    }

    @Test
    void conformingStructuredOutputSucceedsAfterOneRequestForUnknownFinishReason() throws Exception {
        var requestCount = new AtomicInteger();
        var server = server(requestCount, 200, openAiEnvelopeWithoutUsage(
                "{\"answer\":\"ok\"}", "provider_specific"));
        try {
            var provider = provider(server);

            assertThat(new PracticeAiStructuredOutputCaller().call(
                    provider, "system", "return JSON", Answer.class))
                    .isEqualTo(new Answer("ok"));
            assertThat(requestCount).hasValue(1);
        } finally {
            server.stop(0);
        }
    }

    @Test
    void conformingStructuredOutputSucceedsAfterOneRequestWhenFinishReasonIsNull() throws Exception {
        var requestCount = new AtomicInteger();
        var server = server(requestCount, 200, openAiEnvelopeWithRawMetadata(
                "{\"answer\":\"ok\"}",
                "null",
                "{\"prompt_tokens\":1,\"completion_tokens\":1,\"total_tokens\":2}"));
        try {
            var provider = provider(server);

            assertThat(new PracticeAiStructuredOutputCaller().call(
                    provider, "system", "return JSON", Answer.class))
                    .isEqualTo(new Answer("ok"));
            assertThat(requestCount).hasValue(1);
        } finally {
            server.stop(0);
        }
    }

    @Test
    void conformingStructuredOutputSucceedsAfterOneRequestWhenUsageCountersAreNull() throws Exception {
        var requestCount = new AtomicInteger();
        var server = server(requestCount, 200, openAiEnvelopeWithRawUsage(
                "{\"answer\":\"温暖\\n回应\"}",
                "stop",
                "{\"prompt_tokens\":null,\"completion_tokens\":null,\"total_tokens\":null}"));
        try {
            var provider = provider(server);

            assertThat(new PracticeAiStructuredOutputCaller().call(
                    provider, "system", "return JSON", Answer.class))
                    .isEqualTo(new Answer("温暖\n回应"));
            assertThat(requestCount).hasValue(1);
        } finally {
            server.stop(0);
        }
    }

    @Test
    void conformingStructuredOutputSucceedsAfterOneRequestWhenUsageCountersArePartial() throws Exception {
        var requestCount = new AtomicInteger();
        var server = server(requestCount, 200, openAiEnvelopeWithRawUsage(
                "{\"answer\":\"ok\"}", "stop", "{\"prompt_tokens\":7}"));
        try {
            var provider = provider(server);

            assertThat(new PracticeAiStructuredOutputCaller().call(
                    provider, "system", "return JSON", Answer.class))
                    .isEqualTo(new Answer("ok"));
            assertThat(requestCount).hasValue(1);
        } finally {
            server.stop(0);
        }
    }

    @Test
    void nullableUsageNormalizationDoesNotBypassStrictStructuredOutputParsing() throws Exception {
        var requestCount = new AtomicInteger();
        var server = server(requestCount, 200, openAiEnvelopeWithRawUsage(
                "{\"answer\":\"ok\",\"extra\":true}",
                "stop",
                "{\"prompt_tokens\":null,\"completion_tokens\":null,\"total_tokens\":null}"));
        try {
            var provider = provider(server);

            var exception = org.assertj.core.api.Assertions.catchThrowableOfType(
                    () -> new PracticeAiStructuredOutputCaller().call(
                            provider, "system", "return JSON", Answer.class),
                    PracticeAiStructuredOutputCaller.StructuredOutputInvalidException.class);

            assertThat(exception)
                    .isInstanceOf(PracticeAiStructuredOutputCaller.StructuredOutputInvalidException.class)
                    .hasMessage("structured_output_invalid");
            assertThat(exception.providerResponseMetadata()).isEqualTo(
                    new PracticeAiStructuredOutputCaller.ProviderResponseMetadata(
                            PracticeAiStructuredOutputCaller.FinishReason.STOP,
                            0,
                            0,
                            0));
            assertThat(requestCount).hasValue(1);
        } finally {
            server.stop(0);
        }
    }

    @ParameterizedTest
    @ValueSource(strings = {"maxTokens", "maxCompletionTokens"})
    void completeBundleBudgetBelowSafeMinimumFailsBeforeOutboundRequest(String tokenLimitField) throws Exception {
        var requestCount = new AtomicInteger();
        var server = server(requestCount, 200, openAiEnvelope("{\"answer\":\"ok\"}"));
        try {
            var provider = provider(server, tokenLimitField);

            var exception = org.assertj.core.api.Assertions.catchThrowableOfType(
                    () -> new PracticeAiStructuredOutputCaller().callRaw(
                            provider, "system", "return JSON", Answer.class, 8192),
                    PracticeAiStructuredOutputCaller.OutputBudgetTooSmallException.class);

            assertThat(exception).hasMessage("output_budget_too_small");
            assertThat(exception.configuredLimit()).isEqualTo(600);
            assertThat(exception.safeMinimum()).isEqualTo(8192);
            assertThat(new PracticeAiCallFailureClassifier().classify(exception))
                    .hasValue("output_budget_too_small");
            assertThat(requestCount).hasValue(0);
        } finally {
            server.stop(0);
        }
    }

    @ParameterizedTest
    @ValueSource(strings = {"maxTokens", "maxCompletionTokens"})
    void typedJudgeBudgetBelowSafeMinimumFailsBeforeOutboundRequest(String tokenLimitField) throws Exception {
        var requestCount = new AtomicInteger();
        var server = server(requestCount, 200, openAiEnvelope("{\"answer\":\"ok\"}"));
        try {
            var provider = provider(server, tokenLimitField);

            var exception = org.assertj.core.api.Assertions.catchThrowableOfType(
                    () -> new PracticeAiStructuredOutputCaller().call(
                            provider, "system", "return JSON", Answer.class, 8192),
                    PracticeAiStructuredOutputCaller.OutputBudgetTooSmallException.class);

            assertThat(exception).hasMessage("output_budget_too_small");
            assertThat(exception.configuredLimit()).isEqualTo(600);
            assertThat(exception.safeMinimum()).isEqualTo(8192);
            assertThat(new PracticeAiCallFailureClassifier().classify(exception))
                    .hasValue("output_budget_too_small");
            assertThat(requestCount).hasValue(0);
        } finally {
            server.stop(0);
        }
    }

    @Test
    void structuredOutputRequestCarriesConfiguredOutputBudget() throws Exception {
        var requestCount = new AtomicInteger();
        var requestBody = new AtomicReference<String>();
        var server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/v1/chat/completions", exchange -> {
            requestCount.incrementAndGet();
            requestBody.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            var bytes = openAiEnvelope("{\"answer\":\"ok\"}").getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "application/json");
            exchange.sendResponseHeaders(200, bytes.length);
            try (var body = exchange.getResponseBody()) {
                body.write(bytes);
            }
        });
        server.start();
        try {
            var provider = provider(server, "maxTokens", 8192);

            assertThat(new PracticeAiStructuredOutputCaller().callRaw(
                    provider, "system", "return JSON", Answer.class, 8192))
                    .isEqualTo("{\"answer\":\"ok\"}");
            assertThat(requestCount).hasValue(1);
            assertThat(requestBody.get())
                    .contains("\"max_tokens\":8192")
                    .contains("\"response_format\"")
                    .contains("\"json_schema\"")
                    .doesNotContain("reasoning_effort");
        } finally {
            server.stop(0);
        }
    }

    @Test
    void boundedNonReasoningRepairRequestAvoidsTruncatedCompletionInOneOutboundCall() throws Exception {
        var requestCount = new AtomicInteger();
        var requestBody = new AtomicReference<String>();
        var server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/v1/chat/completions", exchange -> {
            requestCount.incrementAndGet();
            var body = new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8);
            requestBody.set(body);
            var compatible = body.contains("\"reasoning_effort\":\"none\"");
            var response = compatible
                    ? openAiEnvelope("{\"answer\":\"complete\"}")
                    : openAiEnvelope("{\"answer\":\"partial", "length", 100, 8192);
            var bytes = response.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "application/json");
            exchange.sendResponseHeaders(200, bytes.length);
            try (var responseBody = exchange.getResponseBody()) {
                responseBody.write(bytes);
            }
        });
        server.start();
        try {
            var provider = provider(server, "maxTokens", 8192);

            assertThat(new PracticeAiStructuredOutputCaller().callRaw(
                    provider,
                    "system",
                    "return JSON",
                    Answer.class,
                    8192,
                    PracticeAiStructuredOutputCaller.ReasoningEffort.NONE))
                    .isEqualTo("{\"answer\":\"complete\"}");
            assertThat(requestCount).hasValue(1);
            assertThat(requestBody.get())
                    .contains("\"max_tokens\":8192")
                    .contains("\"response_format\"")
                    .contains("\"json_schema\"")
                    .contains("\"reasoning_effort\":\"none\"");
        } finally {
            server.stop(0);
        }
    }

    @Test
    void boundedNonReasoningRepairRequestStillRejectsLowBudgetBeforeOutboundCall() throws Exception {
        var requestCount = new AtomicInteger();
        var server = server(requestCount, 200, openAiEnvelope("{\"answer\":\"ok\"}"));
        try {
            var provider = provider(server, "maxTokens", 600);

            assertThatThrownBy(() -> new PracticeAiStructuredOutputCaller().callRaw(
                    provider,
                    "system",
                    "return JSON",
                    Answer.class,
                    8192,
                    PracticeAiStructuredOutputCaller.ReasoningEffort.NONE))
                    .isInstanceOf(PracticeAiStructuredOutputCaller.OutputBudgetTooSmallException.class)
                    .hasMessage("output_budget_too_small");
            assertThat(requestCount).hasValue(0);
        } finally {
            server.stop(0);
        }
    }

    private void assertSingleRequestForStatus(int status) throws Exception {
        var requestCount = new AtomicInteger();
        var server = server(requestCount, status, "{}");
        try {
            var provider = provider(server);

            assertThatThrownBy(() -> provider.chatClient()
                    .prompt()
                    .user("return JSON")
                    .call()
                    .content())
                    .isInstanceOf(RuntimeException.class);
            assertThat(requestCount).hasValue(1);
        } finally {
            server.stop(0);
        }
    }

    private HttpServer server(AtomicInteger requestCount, int status, String response) throws IOException {
        var server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/v1/chat/completions", exchange -> {
            requestCount.incrementAndGet();
            var bytes = response.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "application/json");
            exchange.sendResponseHeaders(status, bytes.length);
            try (var body = exchange.getResponseBody()) {
                body.write(bytes);
            }
        });
        server.start();
        return server;
    }

    private ResolvedProvider provider(HttpServer server) {
        return provider(server, "maxTokens", 128);
    }

    private ResolvedProvider provider(HttpServer server, String tokenLimitField) {
        return provider(server, tokenLimitField, 600);
    }

    private ResolvedProvider provider(HttpServer server, String tokenLimitField, int tokenLimit) {
        var environment = new MockEnvironment().withProperty("TEST_AI_KEY", "test-key");
        var factory = new PracticeAiChatClientFactory(environment, new PracticeAiOpenAiOptionsFactory());
        return factory.create(
                "primary",
                new PracticeAiProperties.ProviderDefinition(
                        "openai-compatible",
                        URI.create("http://127.0.0.1:" + server.getAddress().getPort() + "/v1"),
                        "TEST_AI_KEY",
                        "gpt-4o-mini",
                        Duration.ofSeconds(2),
                        null,
                        "maxTokens".equals(tokenLimitField) ? tokenLimit : null,
                        "maxCompletionTokens".equals(tokenLimitField) ? tokenLimit : null));
    }

    private String openAiEnvelope(String content) {
        return openAiEnvelope(content, "stop", 1, 1);
    }

    private String openAiEnvelope(String content, String finishReason, int promptTokens, int completionTokens) {
        return openAiEnvelopeWithRawUsage(
                content,
                finishReason,
                "{\"prompt_tokens\":%d,\"completion_tokens\":%d,\"total_tokens\":%d}"
                        .formatted(promptTokens, completionTokens, promptTokens + completionTokens));
    }

    private String openAiEnvelopeWithoutUsage(String content, String finishReason) {
        return openAiEnvelopeWithRawUsage(content, finishReason, null);
    }

    private String openAiEnvelopeWithRawUsage(String content, String finishReason, String usage) {
        var escapedFinishReason = finishReason
                .replace("\\", "\\\\")
                .replace("\"", "\\\"");
        return openAiEnvelopeWithRawMetadata(content, "\"" + escapedFinishReason + "\"", usage);
    }

    private String openAiEnvelopeWithRawMetadata(String content, String rawFinishReason, String usage) {
        var escapedContent = content
                .replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\r", "\\r")
                .replace("\n", "\\n");
        var envelope = """
                {"id":"chatcmpl-test","object":"chat.completion","created":1,"model":"gpt-4o-mini",\
                "choices":[{"index":0,"message":{"role":"assistant","content":"%s"},"finish_reason":%s}]%s}
                """.formatted(
                        escapedContent,
                        rawFinishReason,
                        usage == null ? "" : ",\"usage\":" + usage);
        return envelope;
    }

    record Answer(String answer) {
        Answer {
            if (answer == null || answer.isBlank()) {
                throw new IllegalArgumentException("answer is required");
            }
        }
    }
}
