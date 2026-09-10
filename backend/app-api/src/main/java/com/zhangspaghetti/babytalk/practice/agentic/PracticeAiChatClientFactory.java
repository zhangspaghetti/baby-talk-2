package com.zhangspaghetti.babytalk.practice.agentic;

import com.zhangspaghetti.babytalk.config.ai.OpenAiCompatibleResponseMetadataInterceptor;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.openai.OpenAiChatModel;
import org.springframework.ai.openai.OpenAiChatOptions;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(
        prefix = "babytalk.practice.discovery.custom-scene",
        name = "provider-mode",
        havingValue = "agentic"
)
public class PracticeAiChatClientFactory {

    private final Environment environment;
    private final PracticeAiOpenAiOptionsFactory optionsFactory;

    public PracticeAiChatClientFactory(Environment environment, PracticeAiOpenAiOptionsFactory optionsFactory) {
        this.environment = environment;
        this.optionsFactory = optionsFactory;
    }

    public ResolvedProvider create(String providerName, PracticeAiProperties.ProviderDefinition provider) {
        String apiKey = environment.getRequiredProperty(provider.apiKeyEnvironmentVariable());
        if (apiKey.isBlank()) {
            throw new IllegalArgumentException("AI provider secret must not be blank: " + providerName);
        }
        OpenAiChatOptions options = optionsFactory.build(provider, apiKey);
        var chatModel = OpenAiChatModel.builder()
                .options(options)
                .httpClientBuilderCustomizer(builder ->
                        builder.interceptor(new OpenAiCompatibleResponseMetadataInterceptor()))
                .build();
        return new ResolvedProvider(
                providerName,
                provider.type(),
                provider.model(),
                ChatClient.builder(chatModel).build(),
                provider.maxTokens() != null ? provider.maxTokens() : provider.maxCompletionTokens());
    }
}
