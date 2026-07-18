package com.zhangspaghetti.babytalk.practice.agentic;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.net.URI;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.ai.chat.client.ChatClient;

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
                new PracticeAiProperties.CapabilityRoute(List.of("primary")));
        var properties = new PracticeAiProperties(
                new PracticeAiProperties.RoutingPolicy("custom-scene-routing-v1"), definitions, routes);
        var factory = mock(PracticeAiChatClientFactory.class);
        when(factory.create("primary", definitions.get("primary")))
                .thenReturn(new ResolvedProvider("primary", "openai-compatible", "primary-model", mock(ChatClient.class)));
        when(factory.create("secondary", definitions.get("secondary")))
                .thenReturn(new ResolvedProvider("secondary", "openai-compatible", "secondary-model", mock(ChatClient.class)));

        var manager = new PracticeAiProviderManager(properties, factory);

        assertThat(manager.route(PracticeAiCapability.CUSTOM_SCENE_GENERATOR))
                .extracting(ResolvedProvider::providerName)
                .containsExactly("primary", "secondary");
    }

    private PracticeAiProperties.ProviderDefinition provider(String model) {
        return new PracticeAiProperties.ProviderDefinition(
                "openai-compatible", URI.create("https://example.invalid/v1"), "TEST_AI_KEY", model,
                Duration.ofSeconds(2), null, 128, null);
    }
}
