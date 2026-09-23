package com.zhangspaghetti.babytalk.practice.agentic;

import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(
        prefix = "babytalk.practice.discovery.custom-scene",
        name = "provider-mode",
        havingValue = "agentic"
)
public class PracticeAiProviderManager {

    private static final Duration SAFETY_CLASSIFIER_TRANSPORT_TIMEOUT = Duration.ofSeconds(3);

    private final PracticeAiProperties properties;
    private final Map<String, ResolvedProvider> providers;
    private final Map<String, ResolvedProvider> safetyClassifierProviders;

    public PracticeAiProviderManager(PracticeAiProperties properties, PracticeAiChatClientFactory factory) {
        this.properties = properties;
        var resolved = new LinkedHashMap<String, ResolvedProvider>();
        properties.providers().forEach((name, definition) -> resolved.put(name, factory.create(name, definition)));
        this.providers = Map.copyOf(resolved);

        var safetyResolved = new LinkedHashMap<String, ResolvedProvider>();
        var safetyRoute = properties.capabilities().get(
                PracticeAiCapability.CUSTOM_SCENE_SAFETY_CLASSIFIER.propertyKey());
        safetyRoute.providerNames().forEach(name -> safetyResolved.put(
                name,
                factory.create(
                        name,
                        properties.providers().get(name),
                        SAFETY_CLASSIFIER_TRANSPORT_TIMEOUT)));
        this.safetyClassifierProviders = Map.copyOf(safetyResolved);
    }

    public List<ResolvedProvider> route(PracticeAiCapability capability) {
        var route = properties.capabilities().get(capability.propertyKey());
        var resolvedProviders = capability == PracticeAiCapability.CUSTOM_SCENE_SAFETY_CLASSIFIER
                ? safetyClassifierProviders
                : providers;
        return route.providerNames().stream().map(resolvedProviders::get).toList();
    }

    public String routingPolicyVersion() {
        return properties.routingPolicy().version();
    }

    public String routingPolicyHash() {
        return properties.routingPolicyHash();
    }
}
