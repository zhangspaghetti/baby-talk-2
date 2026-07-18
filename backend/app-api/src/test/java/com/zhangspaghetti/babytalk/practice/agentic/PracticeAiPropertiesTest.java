package com.zhangspaghetti.babytalk.practice.agentic;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.net.URI;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.boot.context.properties.bind.Bindable;
import org.springframework.boot.context.properties.bind.Binder;
import org.springframework.mock.env.MockEnvironment;

class PracticeAiPropertiesTest {

    @Test
    void bindsNamedProvidersAndMandatoryCapabilityRoutes() {
        var environment = new MockEnvironment()
                .withProperty("app.ai.routing-policy.version", "custom-scene-routing-v1")
                .withProperty("app.ai.providers.primary.type", "openai-compatible")
                .withProperty("app.ai.providers.primary.base-url", "https://example.invalid/v1")
                .withProperty("app.ai.providers.primary.api-key-environment-variable", "TEST_AI_KEY")
                .withProperty("app.ai.providers.primary.model", "gpt-4o-mini")
                .withProperty("app.ai.providers.primary.timeout", "20s")
                .withProperty("app.ai.providers.primary.max-tokens", "600")
                .withProperty("app.ai.capabilities.custom-scene-generator.provider-names[0]", "primary")
                .withProperty("app.ai.capabilities.custom-scene-quality-judge.provider-names[0]", "primary")
                .withProperty("app.ai.capabilities.custom-scene-repair.provider-names[0]", "primary");

        var properties = Binder.get(environment)
                .bind("app.ai", Bindable.of(PracticeAiProperties.class))
                .get();

        assertThat(properties.routingPolicy().version()).isEqualTo("custom-scene-routing-v1");
        assertThat(properties.providers()).containsOnlyKeys("primary");
        assertThat(properties.providers().get("primary").temperature()).isNull();
        assertThat(properties.capabilities().get("custom-scene-generator").providerNames())
                .containsExactly("primary");
        assertThat(properties.routingPolicyHash()).matches("[0-9a-f]{64}");
    }

    @Test
    void rejectsUnknownProviderInRoute() {
        assertThatThrownBy(() -> properties(
                provider(null, 600, null),
                Map.of("custom-scene-generator", new PracticeAiProperties.CapabilityRoute(List.of("missing")))))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("unknown provider");
    }

    @Test
    void rejectsDuplicateProviderInRoute() {
        assertThatThrownBy(() -> properties(
                provider(null, 600, null),
                Map.of("custom-scene-generator", new PracticeAiProperties.CapabilityRoute(List.of("primary", "primary")))))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("duplicate");
    }

    @Test
    void rejectsEmptyMandatoryRoute() {
        assertThatThrownBy(() -> properties(
                provider(null, 600, null),
                Map.of("custom-scene-generator", new PracticeAiProperties.CapabilityRoute(List.of()))))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("mandatory capability route");
    }

    @Test
    void rejectsUnsupportedProviderTypeAndBlankModel() {
        assertThatThrownBy(() -> properties(
                new PracticeAiProperties.ProviderDefinition(
                        "anthropic", URI.create("https://example.invalid/v1"), "TEST_AI_KEY", " ",
                        Duration.ofSeconds(2), null, 128, null),
                Map.of()))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void rejectsNonPositiveTimeoutAndTokenLimits() {
        assertThatThrownBy(() -> properties(
                new PracticeAiProperties.ProviderDefinition(
                        "openai-compatible", URI.create("https://example.invalid/v1"), "TEST_AI_KEY", "model",
                        Duration.ZERO, null, 0, null),
                Map.of()))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void rejectsBothTokenLimitFields() {
        assertThatThrownBy(() -> properties(provider(null, 128, 256), Map.of()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("exactly one");
    }

    private PracticeAiProperties properties(
            PracticeAiProperties.ProviderDefinition provider,
            Map<String, PracticeAiProperties.CapabilityRoute> overrides
    ) {
        var routes = new LinkedHashMap<String, PracticeAiProperties.CapabilityRoute>();
        routes.put("custom-scene-generator", new PracticeAiProperties.CapabilityRoute(List.of("primary")));
        routes.put("custom-scene-quality-judge", new PracticeAiProperties.CapabilityRoute(List.of("primary")));
        routes.put("custom-scene-repair", new PracticeAiProperties.CapabilityRoute(List.of("primary")));
        routes.putAll(overrides);
        return new PracticeAiProperties(
                new PracticeAiProperties.RoutingPolicy("custom-scene-routing-v1"),
                Map.of("primary", provider),
                routes);
    }

    private PracticeAiProperties.ProviderDefinition provider(
            Double temperature,
            Integer maxTokens,
            Integer maxCompletionTokens
    ) {
        return new PracticeAiProperties.ProviderDefinition(
                "openai-compatible",
                URI.create("https://example.invalid/v1"),
                "TEST_AI_KEY",
                "gpt-4o-mini",
                Duration.ofSeconds(2),
                temperature,
                maxTokens,
                maxCompletionTokens);
    }
}
