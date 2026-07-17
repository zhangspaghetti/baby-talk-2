package com.zhangspaghetti.babytalk.config;

import com.zhangspaghetti.babytalk.palace.PalaceHybridRetrievalService;
import com.zhangspaghetti.babytalk.palace.PalaceToolProvider;
import com.zhangspaghetti.babytalk.service.DevMentorProvider;
import com.zhangspaghetti.babytalk.service.MentorProvider;
import com.zhangspaghetti.babytalk.service.SpringAiMentorProvider;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.client.advisor.MessageChatMemoryAdvisor;
import org.springframework.ai.openai.OpenAiChatModel;
import org.springframework.ai.openai.OpenAiChatOptions;
import java.time.Duration;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class MentorProviderConfiguration {

    @Bean
    public MentorProvider mentorProvider(MentorProperties properties,
                                         ObjectProvider<PalaceToolProvider> palaceToolProviderProvider,
                                         ObjectProvider<PalaceHybridRetrievalService> palaceHybridRetrievalServiceProvider,
                                         ObjectProvider<MessageChatMemoryAdvisor> chatMemoryAdvisorProvider) {
        return switch (properties.providerMode().toLowerCase()) {
            case "dev" -> new DevMentorProvider(properties);
            case "github-models", "openai" -> buildSpringAiProvider(
                    properties,
                    palaceToolProviderProvider.getIfAvailable(),
                    palaceHybridRetrievalServiceProvider.getIfAvailable(),
                    chatMemoryAdvisorProvider.getIfAvailable());
            default -> throw new MentorProvider.ProviderUnavailableException(
                    "不支持的 mentor provider mode: `%s`，可选值: dev, github-models, openai"
                            .formatted(properties.providerMode()));
        };
    }

    private SpringAiMentorProvider buildSpringAiProvider(MentorProperties properties,
                                                          PalaceToolProvider palaceToolProvider,
                                                          PalaceHybridRetrievalService palaceHybridRetrievalService,
                                                          MessageChatMemoryAdvisor chatMemoryAdvisor) {
        var apiKey = properties.aiApiKey();
        if (apiKey == null || apiKey.isBlank()) {
            throw new MentorProvider.ProviderUnavailableException(
                    "provider [%s] 需要配置 app.mentor.ai-api-key (环境变量 BABY_TALK_AI_API_KEY)"
                            .formatted(properties.providerMode()));
        }

        var chatModel = OpenAiChatModel.builder()
                .options(openAiOptions(properties))
                .build();

        // 使用 builder 模式而非 ChatClient.create()，便于后续扩展
        var clientBuilder = ChatClient.builder(chatModel);
        if (chatMemoryAdvisor != null) {
            clientBuilder.defaultAdvisors(chatMemoryAdvisor);
        }
        var chatClient = clientBuilder.build();

        return new SpringAiMentorProvider(chatClient, properties,
                palaceToolProvider, palaceHybridRetrievalService);
    }

    OpenAiChatOptions openAiOptions(MentorProperties properties) {
        var builder = OpenAiChatOptions.builder()
                .baseUrl(OpenAiV1BaseUrl.fromProviderRoot(resolveBaseUrl(properties)))
                .apiKey(properties.aiApiKey())
                .model(properties.aiModel())
                .timeout(Duration.ofSeconds(60))
                .maxRetries(properties.aiMaxAttempts() - 1);
        if (properties.aiTemperature() != null) {
            builder.temperature(properties.aiTemperature());
        }
        if (properties.aiMaxTokens() != null) {
            builder.maxTokens(properties.aiMaxTokens());
        }
        return builder.build();
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
