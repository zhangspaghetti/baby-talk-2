package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.config.MentorProperties;
import java.net.SocketTimeoutException;
import org.springframework.ai.chat.client.ChatClient;

/**
 * 基于 Spring AI ChatClient 的 MentorProvider 实现。
 * 支持 OpenAI 兼容的 API（包括 GitHub Models、标准 OpenAI 等）。
 */
public class SpringAiMentorProvider implements MentorProvider {

    // 包级可见，方便测试断言
    static final String SYSTEM_PROMPT = """
            你是小禾老师，一位温暖、专业的早期语言发展导师。
            规则：
            - 回复不超过 200 字，使用简洁中文，可适当加入英文示范短句
            - 不给医疗诊断建议
            - 不讨论任何可能伤害儿童的行为
            - 输出纯文本，不含 markdown 格式符号
            - 每次只给一个具体可操作的建议""";

    private final ChatClient chatClient;
    private final MentorProperties properties;

    public SpringAiMentorProvider(ChatClient chatClient, MentorProperties properties) {
        this.chatClient = chatClient;
        this.properties = properties;
    }

    @Override
    public ProviderResponse respond(ProviderRequest request) {
        String content;
        try {
            content = chatClient.prompt()
                    .system(SYSTEM_PROMPT)
                    .user(request.prompt())
                    .call()
                    .content();
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
     * 将底层异常映射为 MentorProvider 的三种标准异常。
     * 异常消息中包含 provider mode 和诊断信息，但不包含 API key。
     */
    private RuntimeException mapException(Exception e) {
        // 递归搜索 cause chain 中是否包含超时异常
        if (hasTimeoutCause(e)) {
            return new ProviderTimeoutException(
                    "provider [%s] 调用超时: %s".formatted(properties.providerMode(), sanitize(e.getMessage())));
        }

        // 其他所有 SDK/网络异常 → ProviderUnavailableException
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
