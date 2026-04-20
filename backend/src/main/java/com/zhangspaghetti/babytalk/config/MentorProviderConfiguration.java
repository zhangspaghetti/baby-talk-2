package com.zhangspaghetti.babytalk.config;

import com.zhangspaghetti.babytalk.palace.PalaceSearchService;
import com.zhangspaghetti.babytalk.palace.PalaceToolProvider;
import com.zhangspaghetti.babytalk.service.DevMentorProvider;
import com.zhangspaghetti.babytalk.service.MentorProvider;
import com.zhangspaghetti.babytalk.service.SpringAiMentorProvider;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.openai.OpenAiChatModel;
import org.springframework.ai.openai.OpenAiChatOptions;
import org.springframework.ai.openai.api.OpenAiApi;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class MentorProviderConfiguration {

    @Bean
    public MentorProvider mentorProvider(MentorProperties properties,
                                         ObjectProvider<PalaceToolProvider> palaceToolProviderProvider,
                                         ObjectProvider<PalaceSearchService> palaceSearchServiceProvider) {
        return switch (properties.providerMode().toLowerCase()) {
            case "dev" -> new DevMentorProvider(properties);
            case "github-models", "openai" -> buildSpringAiProvider(
                    properties,
                    palaceToolProviderProvider.getIfAvailable(),
                    palaceSearchServiceProvider.getIfAvailable());
            default -> throw new MentorProvider.ProviderUnavailableException(
                    "不支持的 mentor provider mode: `%s`，可选值: dev, github-models, openai"
                            .formatted(properties.providerMode()));
        };
    }

    private SpringAiMentorProvider buildSpringAiProvider(MentorProperties properties,
                                                          PalaceToolProvider palaceToolProvider,
                                                          PalaceSearchService palaceSearchService) {
        var apiKey = properties.aiApiKey();
        if (apiKey == null || apiKey.isBlank()) {
            throw new MentorProvider.ProviderUnavailableException(
                    "provider [%s] 需要配置 app.mentor.ai-api-key (环境变量 BABY_TALK_AI_API_KEY)"
                            .formatted(properties.providerMode()));
        }

        var openAiApi = OpenAiApi.builder()
                .baseUrl(resolveBaseUrl(properties))
                .apiKey(apiKey)
                .build();

        var optionsBuilder = OpenAiChatOptions.builder();
        if (properties.aiModel() != null && !properties.aiModel().isBlank()) {
            optionsBuilder.model(properties.aiModel());
        }
        if (properties.aiTemperature() != null) {
            optionsBuilder.temperature(properties.aiTemperature());
        }
        if (properties.aiMaxTokens() != null) {
            optionsBuilder.maxTokens(properties.aiMaxTokens());
        }

        var chatModel = OpenAiChatModel.builder()
                .openAiApi(openAiApi)
                .defaultOptions(optionsBuilder.build())
                .build();

        // 使用 builder 模式而非 ChatClient.create()，便于后续扩展
        var chatClient = ChatClient.builder(chatModel).build();

        return new SpringAiMentorProvider(chatClient, properties,
                palaceToolProvider, palaceSearchService);
    }

    private String resolveBaseUrl(MentorProperties properties) {
        if (properties.aiBaseUrl() != null && !properties.aiBaseUrl().isBlank()) {
            return properties.aiBaseUrl();
        }
        if ("github-models".equalsIgnoreCase(properties.providerMode())) {
            return "https://models.inference.ai.azure.com";
        }
        return "https://api.openai.com";
    }
}
