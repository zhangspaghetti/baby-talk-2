package com.zhangspaghetti.babytalk.practice.agentic;

import java.util.Objects;
import org.springframework.ai.chat.client.ChatClient;

public record ResolvedProvider(
        String providerName,
        String providerType,
        String modelName,
        ChatClient chatClient
) {
    public ResolvedProvider {
        Objects.requireNonNull(providerName, "providerName");
        Objects.requireNonNull(providerType, "providerType");
        Objects.requireNonNull(modelName, "modelName");
        Objects.requireNonNull(chatClient, "chatClient");
    }

    @Override
    public String toString() {
        return "ResolvedProvider[providerName=" + providerName
                + ", providerType=" + providerType
                + ", modelName=" + modelName + "]";
    }
}
