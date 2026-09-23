package com.zhangspaghetti.babytalk.practice.agentic;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.net.URI;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.mock.env.MockEnvironment;

class PracticeAiProviderManagerTest {

    @Test
    void returnsProvidersInConfiguredOrder() {
        var definitions = new LinkedHashMap<String, PracticeAiProperties.ProviderDefinition>();
        definitions.put("secondary", provider("secondary-model"));
        definitions.put("primary", provider("primary-model"));
        var routes = Map.of(
                "custom-scene-generator",
                new PracticeAiProperties.CapabilityRoute(List.of("primary", "secondary")),
                "custom-scene-quality-judge",
                new PracticeAiProperties.CapabilityRoute(List.of("secondary")),
                "custom-scene-repair",
                new PracticeAiProperties.CapabilityRoute(List.of("primary")),
                "custom-scene-safety-classifier",
                new PracticeAiProperties.CapabilityRoute(List.of("primary")));
        var properties = new PracticeAiProperties(
                new PracticeAiProperties.RoutingPolicy("custom-scene-routing-v1"), definitions, routes);
        var factory = mock(PracticeAiChatClientFactory.class);
        var primary = new ResolvedProvider("primary", "openai-compatible", "primary-model", mock(ChatClient.class));
        var secondary = new ResolvedProvider(
                "secondary", "openai-compatible", "secondary-model", mock(ChatClient.class));
        when(factory.create("primary", definitions.get("primary")))
                .thenReturn(primary);
        when(factory.create("secondary", definitions.get("secondary")))
                .thenReturn(secondary);
        when(factory.create("primary", definitions.get("primary"), Duration.ofSeconds(3)))
                .thenReturn(primary);

        var manager = new PracticeAiProviderManager(properties, factory);

        assertThat(manager.route(PracticeAiCapability.CUSTOM_SCENE_GENERATOR))
                .extracting(ResolvedProvider::providerName)
                .containsExactly("primary", "secondary");
    }

    @Test
    void safetyClassifierRouteUsesThreeSecondHttpTransportDeadline() throws Exception {
        var requestCount = new java.util.concurrent.atomic.AtomicInteger();
        var requestStarted = new CountDownLatch(1);
        var releaseServer = new CountDownLatch(1);
        var server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/v1/chat/completions", exchange -> {
            requestCount.incrementAndGet();
            requestStarted.countDown();
            try {
                releaseServer.await();
            } catch (InterruptedException exception) {
                Thread.currentThread().interrupt();
            } finally {
                exchange.close();
            }
        });
        server.start();
        var executor = Executors.newSingleThreadExecutor();
        try {
            var definitions = new LinkedHashMap<String, PracticeAiProperties.ProviderDefinition>();
            definitions.put(
                    "primary",
                    provider(
                            "primary-model",
                            Duration.ofSeconds(10),
                            URI.create("http://127.0.0.1:" + server.getAddress().getPort() + "/v1")));
            var routes = Map.of(
                    "custom-scene-generator",
                    new PracticeAiProperties.CapabilityRoute(List.of("primary")),
                    "custom-scene-quality-judge",
                    new PracticeAiProperties.CapabilityRoute(List.of("primary")),
                    "custom-scene-repair",
                    new PracticeAiProperties.CapabilityRoute(List.of("primary")),
                    "custom-scene-safety-classifier",
                    new PracticeAiProperties.CapabilityRoute(List.of("primary")));
            var properties = new PracticeAiProperties(
                    new PracticeAiProperties.RoutingPolicy("custom-scene-routing-v1"), definitions, routes);
            var factory = new PracticeAiChatClientFactory(
                    new MockEnvironment().withProperty("TEST_AI_KEY", "test-key"),
                    new PracticeAiOpenAiOptionsFactory());
            var manager = new PracticeAiProviderManager(properties, factory);
            var safetyProvider = manager.route(PracticeAiCapability.CUSTOM_SCENE_SAFETY_CLASSIFIER).get(0);
            var future = executor.submit(() -> safetyProvider.chatClient()
                    .prompt()
                    .user("return JSON")
                    .call()
                    .content());

            assertThat(requestStarted.await(2, TimeUnit.SECONDS)).isTrue();
            var startedAt = System.nanoTime();
            Throwable failure;
            try {
                future.get(4, TimeUnit.SECONDS);
                failure = null;
            } catch (InterruptedException | ExecutionException | java.util.concurrent.TimeoutException exception) {
                failure = exception;
            }
            var elapsed = Duration.ofNanos(System.nanoTime() - startedAt);
            assertThat(failure).isInstanceOf(ExecutionException.class);
            assertThat(elapsed).isLessThan(Duration.ofSeconds(4));
            assertThat(elapsed).isGreaterThanOrEqualTo(Duration.ofSeconds(2));
            assertThat(requestCount).hasValue(1);
        } finally {
            releaseServer.countDown();
            executor.shutdownNow();
            server.stop(0);
        }
    }

    private PracticeAiProperties.ProviderDefinition provider(String model) {
        return provider(model, Duration.ofSeconds(2), URI.create("https://example.invalid/v1"));
    }

    private PracticeAiProperties.ProviderDefinition provider(String model, Duration timeout, URI baseUrl) {
        return new PracticeAiProperties.ProviderDefinition(
                "openai-compatible", baseUrl, "TEST_AI_KEY", model, timeout, null, 128, null);
    }
}
