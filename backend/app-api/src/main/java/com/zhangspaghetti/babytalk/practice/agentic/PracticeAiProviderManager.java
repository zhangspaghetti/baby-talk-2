package com.zhangspaghetti.babytalk.practice.agentic;

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

    private final PracticeAiProperties properties;
    private final Map<String, ResolvedProvider> providers;

    public PracticeAiProviderManager(PracticeAiProperties properties, PracticeAiChatClientFactory factory) {
        this.properties = properties;
        var resolved = new LinkedHashMap<String, ResolvedProvider>();
        properties.providers().forEach((name, definition) -> resolved.put(name, factory.create(name, definition)));
        this.providers = Map.copyOf(resolved);
    }

    public List<ResolvedProvider> route(PracticeAiCapability capability) {
        var route = properties.capabilities().get(capability.propertyKey());
        return route.providerNames().stream().map(providers::get).toList();
    }

    public String routingPolicyVersion() {
        return properties.routingPolicy().version();
    }

    public String routingPolicyHash() {
        return properties.routingPolicyHash();
    }
}
