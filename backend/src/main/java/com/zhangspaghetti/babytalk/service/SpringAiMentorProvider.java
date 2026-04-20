package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.config.MentorProperties;
import com.zhangspaghetti.babytalk.palace.MemPalacePromptBuilder;
import com.zhangspaghetti.babytalk.palace.PalaceSearchService;
import com.zhangspaghetti.babytalk.palace.PalaceToolProvider;
import java.net.SocketTimeoutException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.chat.client.ChatClient;

/**
 * 基于 Spring AI ChatClient 的 MentorProvider 实现。
 * 支持 OpenAI 兼容的 API（包括 GitHub Models、标准 OpenAI 等）。
 *
 * <p>通过 {@code app.mentor.search-mode} 配置切换三种模式：
 * <ul>
 *   <li>none — 原有行为，不调用知识宫殿</li>
 *   <li>rag — L0 + L1 预注入知识，无 tool calling</li>
 *   <li>agentic — L0 + L1 + L2 工具指引，启用 tool calling</li>
 * </ul>
 */
public class SpringAiMentorProvider implements MentorProvider {

    private static final Logger log = LoggerFactory.getLogger(SpringAiMentorProvider.class);

    // 保留原始 SYSTEM_PROMPT 常量供向后兼容和测试引用
    static final String SYSTEM_PROMPT = MemPalacePromptBuilder.L0_SYSTEM_PROMPT;

    private final ChatClient chatClient;
    private final MentorProperties properties;
    private final PalaceToolProvider palaceToolProvider;
    private final PalaceSearchService palaceSearchService;

    /**
     * 完整构造函数：支持 agentic/rag/none 三模式。
     *
     * @param chatClient          Spring AI ChatClient
     * @param properties          mentor 配置
     * @param palaceToolProvider  工具提供者（agentic 模式用，可为 null）
     * @param palaceSearchService 知识宫殿搜索服务（L1 预检索用，可为 null）
     */
    public SpringAiMentorProvider(ChatClient chatClient, MentorProperties properties,
                                   PalaceToolProvider palaceToolProvider,
                                   PalaceSearchService palaceSearchService) {
        this.chatClient = chatClient;
        this.properties = properties;
        this.palaceToolProvider = palaceToolProvider;
        this.palaceSearchService = palaceSearchService;
    }

    /**
     * 向后兼容构造函数：等效于 searchMode=none。
     */
    public SpringAiMentorProvider(ChatClient chatClient, MentorProperties properties) {
        this(chatClient, properties, null, null);
    }

    @Override
    public ProviderResponse respond(ProviderRequest request) {
        String searchMode = properties.effectiveSearchMode();
        String systemPrompt = MemPalacePromptBuilder.buildSystemPrompt(
                searchMode, request.prompt(), palaceSearchService);

        String content;
        try {
            content = callChatClient(searchMode, systemPrompt, request.prompt());
        } catch (Exception e) {
            throw mapException(e);
        }

        if (content == null || content.isBlank()) {
            throw new ProviderMalformedResponseException(
                    "provider [%s] 返回了空响应，correlationId=%s"
                            .formatted(properties.providerMode(), request.correlationId()));
        }

        var trimmed = trimToMax(content, properties.responseMaxLength());
        return new ProviderResponse(trimmed, summarize(trimmed));
    }

    /**
     * 根据 searchMode 决定是否注册 tools 并调用 ChatClient。
     */
    private String callChatClient(String searchMode, String systemPrompt, String userPrompt) {
        var spec = chatClient.prompt()
                .system(systemPrompt)
                .user(userPrompt);

        if ("agentic".equals(searchMode) && palaceToolProvider != null) {
            log.info("search-mode=agentic, 注册 PalaceToolProvider tools");
            return spec.tools(palaceToolProvider).call().content();
        }

        // rag 或 none 模式下不注册 tools（L1 已在 systemPrompt 中注入）
        return spec.call().content();
    }

    /**
     * 将底层异常映射为 MentorProvider 的三种标准异常。
     * 异常消息中包含 provider mode 和诊断信息，但不包含 API key。
     */
    private RuntimeException mapException(Exception e) {
        if (hasTimeoutCause(e)) {
            return new ProviderTimeoutException(
                    "provider [%s] 调用超时: %s".formatted(properties.providerMode(), sanitize(e.getMessage())));
        }
        return new ProviderUnavailableException(
                "provider [%s] 不可用: %s".formatted(properties.providerMode(), sanitize(e.getMessage())));
    }

    private boolean hasTimeoutCause(Throwable t) {
        Throwable current = t;
        while (current != null) {
            if (current instanceof SocketTimeoutException
                    || current instanceof java.net.ConnectException
                    || current.getClass().getSimpleName().contains("TimeoutException")) {
                return true;
            }
            if (current == current.getCause()) {
                break;
            }
            current = current.getCause();
        }
        return false;
    }

    /**
     * 清理异常消息，确保不包含 API key。
     */
    private String sanitize(String message) {
        if (message == null) {
            return "unknown error";
        }
        String apiKey = properties.aiApiKey();
        if (apiKey != null && !apiKey.isBlank() && message.contains(apiKey)) {
            return message.replace(apiKey, "[REDACTED]");
        }
        return message;
    }

    private String summarize(String value) {
        var compact = value.replaceAll("\\s+", " ").trim();
        if (compact.length() <= 80) {
            return compact;
        }
        return compact.substring(0, 80) + "…";
    }

    private String trimToMax(String value, int maxLength) {
        if (value.length() <= maxLength) {
            return value;
        }
        return value.substring(0, maxLength);
    }
}
