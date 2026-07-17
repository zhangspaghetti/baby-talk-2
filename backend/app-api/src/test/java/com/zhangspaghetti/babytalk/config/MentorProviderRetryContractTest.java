package com.zhangspaghetti.babytalk.config;

import static org.assertj.core.api.Assertions.assertThat;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.ai.chat.messages.UserMessage;
import org.springframework.ai.chat.prompt.Prompt;
import org.springframework.ai.openai.OpenAiChatModel;
import org.springframework.ai.openai.OpenAiChatOptions;

class MentorProviderRetryContractTest {

    private final AtomicInteger requestCount = new AtomicInteger();
    private HttpServer server;

    @BeforeEach
    void startServer() throws IOException {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/v1/chat/completions", this::respond);
        server.start();
    }

    @AfterEach
    void stopServer() {
        if (server != null) {
            server.stop(0);
        }
    }

    @Test
    void configuredTwoAttemptsMakeTwoOutboundRequestsBeforeSuccessfulCompletion() {
        OpenAiChatOptions options = new MentorProviderConfiguration().openAiOptions(
                mentorProperties("http://127.0.0.1:%d/v1".formatted(server.getAddress().getPort()), 2));
        OpenAiChatModel model = OpenAiChatModel.builder().options(options).build();

        String content = model.call(new Prompt(new UserMessage("retry contract")))
                .getResult()
                .getOutput()
                .getText();

        assertThat(content).isEqualTo("retry succeeded");
        assertThat(options.getMaxRetries()).isOne();
        assertThat(requestCount).hasValue(2);
    }

    private MentorProperties mentorProperties(String baseUrl, int aiMaxAttempts) {
        return new MentorProperties(
                "openai",
                Duration.ofSeconds(2),
                baseUrl,
                "local-test-key",
                "gpt-4o-mini",
                null,
                null,
                aiMaxAttempts,
                3,
                Duration.ofMinutes(10),
                280,
                280,
                List.of("home"),
                List.of("single_turn"),
                List.of(),
                "[timeout]",
                "[malformed]",
                "[unavailable]",
                "none",
                Duration.ofMinutes(30),
                2000);
    }

    private void respond(HttpExchange exchange) throws IOException {
        exchange.getRequestBody().readAllBytes();
        int requestNumber = requestCount.incrementAndGet();
        if (requestNumber == 1) {
            exchange.sendResponseHeaders(500, -1);
            exchange.close();
            return;
        }

        byte[] response = """
                {
                  "id": "chatcmpl-local",
                  "object": "chat.completion",
                  "created": 0,
                  "model": "gpt-4o-mini",
                  "choices": [{
                    "index": 0,
                    "message": {"role": "assistant", "content": "retry succeeded"},
                    "finish_reason": "stop"
                  }],
                  "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2}
                }
                """.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "application/json");
        exchange.sendResponseHeaders(200, response.length);
        exchange.getResponseBody().write(response);
        exchange.close();
    }
}
