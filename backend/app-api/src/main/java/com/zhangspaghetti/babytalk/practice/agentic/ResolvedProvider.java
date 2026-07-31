package com.zhangspaghetti.babytalk.practice.agentic;

import java.util.Objects;
import org.springframework.ai.chat.client.ChatClient;

public record ResolvedProvider(
        String providerName,
        String providerType,
        String modelName,
        ChatClient chatClient,
        int outputTokenLimit
) {
    public ResolvedProvider(String providerName, String providerType, String modelName, ChatClient chatClient) {
        this(providerName, providerType, modelName, chatClient, Integer.MAX_VALUE);
    }

    public ResolvedProvider {
        Objects.requireNonNull(providerName, "providerName");
        Objects.requireNonNull(providerType, "providerType");
        Objects.requireNonNull(modelName, "modelName");
        Objects.requireNonNull(chatClient, "chatClient");
        if (outputTokenLimit <= 0) {
            throw new IllegalArgumentException("outputTokenLimit must be positive");
        }
    }

    @Override
    public String toString() {
        return "ResolvedProvider[providerName=" + providerName
                + ", providerType=" + providerType
                + ", modelName=" + modelName + "]";
    }
}
