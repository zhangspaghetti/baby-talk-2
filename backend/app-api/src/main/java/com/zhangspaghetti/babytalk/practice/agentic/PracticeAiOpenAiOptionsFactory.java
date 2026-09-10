package com.zhangspaghetti.babytalk.practice.agentic;

import org.springframework.ai.openai.OpenAiChatOptions;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(
        prefix = "babytalk.practice.discovery.custom-scene",
        name = "provider-mode",
        havingValue = "agentic"
)
public class PracticeAiOpenAiOptionsFactory {

    public OpenAiChatOptions build(PracticeAiProperties.ProviderDefinition provider, String apiKey) {
        var builder = OpenAiChatOptions.builder()
                .baseUrl(provider.baseUrl().toString())
                .apiKey(apiKey)
                .model(provider.model())
                .timeout(provider.timeout())
                .n(1)
                .maxRetries(0);
        if (provider.temperature() != null) {
            builder.temperature(provider.temperature());
        }
        if (provider.maxTokens() != null) {
            builder.maxTokens(provider.maxTokens());
        }
        if (provider.maxCompletionTokens() != null) {
            builder.maxCompletionTokens(provider.maxCompletionTokens());
        }
        return builder.build();
    }
}
