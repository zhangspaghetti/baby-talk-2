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
                        128,
                        null));
    }

    private String openAiEnvelope(String content) {
        var escapedContent = content
                .replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\r", "\\r")
                .replace("\n", "\\n");
        return """
                {"id":"chatcmpl-test","object":"chat.completion","created":1,"model":"gpt-4o-mini",\
                "choices":[{"index":0,"message":{"role":"assistant","content":"%s"},"finish_reason":"stop"}],\
                "usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":2}}
                """.formatted(escapedContent);
    }

    record Answer(String answer) {
        Answer {
            if (answer == null || answer.isBlank()) {
                throw new IllegalArgumentException("answer is required");
            }
        }
    }
}
