package com.zhangspaghetti.babytalk.kg;

import com.zhangspaghetti.babytalk.config.MentorProperties;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.openai.OpenAiChatModel;
import org.springframework.ai.openai.OpenAiChatOptions;
import org.springframework.ai.openai.api.OpenAiApi;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * KG 模块配置 — 启用定时调度 + 绑定 {@link KgProperties} + 创建 KG 专用 ChatClient。
 */
@Configuration
@EnableScheduling
@EnableConfigurationProperties(KgProperties.class)
public class KgConfiguration {

    /**
     * KG 审查专用 ChatClient — 复用 {@link MentorProperties} 中的 AI 配置
     * （同一 API key / base-url / model），但独立于 mentor 的 ChatClient，
     * 不绑定会话记忆或工具。
     */
    @Bean
    public ChatClient kgReviewChatClient(MentorProperties mentorProperties) {
        var apiKey = mentorProperties.aiApiKey();
        if (apiKey == null || apiKey.isBlank()) {
            // 如果没有配置 API key，返回一个 stub ChatClient
            // 实际调用时会在 KgContradictionReviewService 层面被 reviewEnabled=false 拦截
            // 或者抛出明确异常
            return ChatClient.builder(buildChatModel(mentorProperties, "")).build();
        }

        var chatModel = buildChatModel(mentorProperties, apiKey);
        return ChatClient.builder(chatModel).build();
    }

    private OpenAiChatModel buildChatModel(MentorProperties properties, String apiKey) {
        var baseUrl = resolveBaseUrl(properties);
        var openAiApi = OpenAiApi.builder()
                .baseUrl(baseUrl)
                .apiKey(apiKey.isBlank() ? "placeholder" : apiKey)
                .build();

        var optionsBuilder = OpenAiChatOptions.builder();
        if (properties.aiModel() != null && !properties.aiModel().isBlank()) {
            optionsBuilder.model(properties.aiModel());
        }
        // KG 审查使用低温度以获得更稳定的 JSON 输出
        optionsBuilder.temperature(0.2);
        if (properties.aiMaxTokens() != null) {
            optionsBuilder.maxTokens(properties.aiMaxTokens());
        }

        return OpenAiChatModel.builder()
                .openAiApi(openAiApi)
                .defaultOptions(optionsBuilder.build())
                .build();
    }

    private String resolveBaseUrl(MentorProperties properties) {
        if (properties.aiBaseUrl() != null && !properties.aiBaseUrl().isBlank()) {
            return properties.aiBaseUrl();
        }
        return "https://api.openai.com";
    }
}
