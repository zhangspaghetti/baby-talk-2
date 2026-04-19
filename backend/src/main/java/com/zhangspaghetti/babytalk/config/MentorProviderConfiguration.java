package com.zhangspaghetti.babytalk.config;

import com.zhangspaghetti.babytalk.service.DevMentorProvider;
import com.zhangspaghetti.babytalk.service.MentorProvider;
import com.zhangspaghetti.babytalk.service.SpringAiMentorProvider;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.openai.OpenAiChatModel;
import org.springframework.ai.openai.OpenAiChatOptions;
import org.springframework.ai.openai.api.OpenAiApi;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class MentorProviderConfiguration {

    @Bean
    public MentorProvider mentorProvider(MentorProperties properties) {
        return switch (properties.providerMode().toLowerCase()) {
            case "dev" -> new DevMentorProvider(properties);
            case "github-models", "openai" -> buildSpringAiProvider(properties);
            default -> throw new MentorProvider.ProviderUnavailableException(
                    "不支持的 mentor provider mode: `%s`，可选值: dev, github-models, openai"
                            .formatted(properties.providerMode()));
        };
    }

    private SpringAiMentorProvider buildSpringAiProvider(MentorProperties properties) {
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

        var chatClient = ChatClient.create(chatModel);

        return new SpringAiMentorProvider(chatClient, properties);
    }

    private String resolveBaseUrl(MentorProperties properties) {
        // 如果显式配置了 base URL，则使用配置值
        if (properties.aiBaseUrl() != null && !properties.aiBaseUrl().isBlank()) {
            return properties.aiBaseUrl();
        }
        // github-models 默认使用 Azure Inference 端点
        if ("github-models".equalsIgnoreCase(properties.providerMode())) {
            return "https://models.inference.ai.azure.com";
        }
        // openai 默认使用标准端点
        return "https://api.openai.com";
    }
}
