package com.zhangspaghetti.babytalk.practice.agentic;

import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.TreeMap;
public record PracticeAiProperties(
        RoutingPolicy routingPolicy,
        Map<String, ProviderDefinition> providers,
        Map<String, CapabilityRoute> capabilities
) {

    private static final String OPENAI_COMPATIBLE = "openai-compatible";

    public PracticeAiProperties {
        if (routingPolicy == null || isBlank(routingPolicy.version())) {
            throw new IllegalArgumentException("routing policy version must be non-blank");
        }
        providers = immutableLinkedMap(providers);
        capabilities = immutableLinkedMap(capabilities);
        if (providers.isEmpty()) {
            throw new IllegalArgumentException("at least one named provider is required");
        }
        for (var entry : providers.entrySet()) {
            if (isBlank(entry.getKey()) || entry.getValue() == null) {
                throw new IllegalArgumentException("named providers must have non-blank names and definitions");
            }
        }
        for (var capability : PracticeAiCapability.values()) {
            var route = capabilities.get(capability.propertyKey());
            if (route == null || route.providerNames().isEmpty()) {
                throw new IllegalArgumentException("mandatory capability route must not be empty: "
                        + capability.propertyKey());
            }
            var unique = new LinkedHashSet<>(route.providerNames());
            if (unique.size() != route.providerNames().size()) {
                throw new IllegalArgumentException("duplicate provider in capability route: "
                        + capability.propertyKey());
            }
            for (String providerName : route.providerNames()) {
                if (!providers.containsKey(providerName)) {
                    throw new IllegalArgumentException("unknown provider in capability route: " + providerName);
                }
            }
        }
    }

    private static <T> Map<String, T> immutableLinkedMap(Map<String, T> source) {
        return Map.copyOf(source == null ? Map.of() : new LinkedHashMap<>(source));
    }

    private static boolean isBlank(String value) {
        return value == null || value.isBlank();
    }

    public String routingPolicyHash() {
        var canonical = new StringBuilder(routingPolicy.version()).append('\n');
        new TreeMap<>(capabilities).forEach((capability, route) -> canonical
                .append(capability).append('=').append(String.join(",", route.providerNames())).append('\n'));
        new TreeMap<>(providers).forEach((name, provider) -> canonical
                .append(name).append('|').append(provider.type()).append('|').append(provider.baseUrl())
                .append('|').append(provider.model()).append('|').append(provider.timeout())
                .append('|').append(provider.temperature()).append('|').append(provider.maxTokens())
                .append('|').append(provider.maxCompletionTokens()).append('\n'));
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(canonical.toString().getBytes(StandardCharsets.UTF_8));
            var hash = new StringBuilder(64);
            for (byte value : digest) {
                hash.append(String.format("%02x", value));
            }
            return hash.toString();
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is unavailable", exception);
        }
    }

    public record RoutingPolicy(String version) {
        public RoutingPolicy {
            if (isBlank(version)) {
                throw new IllegalArgumentException("routing policy version must be non-blank");
            }
            version = version.trim();
        }
    }

    public record CapabilityRoute(List<String> providerNames) {
        public CapabilityRoute {
            providerNames = List.copyOf(providerNames == null ? List.of() : providerNames);
            if (providerNames.stream().anyMatch(PracticeAiProperties::isBlank)) {
                throw new IllegalArgumentException("provider names must be non-blank");
            }
        }
    }

    public record ProviderDefinition(
            String type,
            URI baseUrl,
            String apiKeyEnvironmentVariable,
            String model,
            Duration timeout,
            Double temperature,
            Integer maxTokens,
            Integer maxCompletionTokens
    ) {
        public ProviderDefinition {
            if (!OPENAI_COMPATIBLE.equals(type)) {
                throw new IllegalArgumentException("unsupported provider type: " + type);
            }
            if (baseUrl == null || !("http".equalsIgnoreCase(baseUrl.getScheme())
                    || "https".equalsIgnoreCase(baseUrl.getScheme()))) {
                throw new IllegalArgumentException("provider base URL must use HTTP or HTTPS");
            }
            if (isBlank(apiKeyEnvironmentVariable)) {
                throw new IllegalArgumentException("provider API key environment variable must be non-blank");
            }
            if (isBlank(model)) {
                throw new IllegalArgumentException("provider model must be non-blank");
            }
            if (timeout == null || timeout.isZero() || timeout.isNegative()) {
                throw new IllegalArgumentException("provider timeout must be positive");
            }
            if ((maxTokens == null) == (maxCompletionTokens == null)) {
                throw new IllegalArgumentException("provider must set exactly one token limit field");
            }
            if ((maxTokens != null && maxTokens <= 0)
                    || (maxCompletionTokens != null && maxCompletionTokens <= 0)) {
                throw new IllegalArgumentException("provider token limit must be positive");
            }
            if (temperature != null && (!Double.isFinite(temperature) || temperature < 0.0d)) {
                throw new IllegalArgumentException("provider temperature must be non-negative when set");
            }
            type = type.trim();
            apiKeyEnvironmentVariable = apiKeyEnvironmentVariable.trim();
            model = model.trim();
            Objects.requireNonNull(baseUrl, "baseUrl");
        }
    }
}
