package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.config.MentorProperties;
import com.zhangspaghetti.babytalk.palace.HybridCandidate;
import com.zhangspaghetti.babytalk.palace.MemPalacePromptBuilder;
import com.zhangspaghetti.babytalk.palace.PalaceHybridRetrievalService;
import com.zhangspaghetti.babytalk.palace.PalaceToolProvider;
import com.zhangspaghetti.babytalk.palace.QueryTrace;
import com.zhangspaghetti.babytalk.palace.RetrievalRequest;
import com.zhangspaghetti.babytalk.palace.RetrievalResult;
import java.net.SocketTimeoutException;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.memory.ChatMemory;

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
    private static final int PRE_RETRIEVAL_MAX_RESULTS = 10;
    private static final int PRE_RETRIEVAL_MAX_HOPS = 2;

    // 保留原始 SYSTEM_PROMPT 常量供向后兼容和测试引用
    static final String SYSTEM_PROMPT = MemPalacePromptBuilder.L0_SYSTEM_PROMPT;

    private final ChatClient chatClient;
    private final MentorProperties properties;
    private final PalaceToolProvider palaceToolProvider;
    private final PalaceHybridRetrievalService palaceHybridRetrievalService;

    /**
     * 完整构造函数：支持 agentic/rag/none 三模式。
     *
     * @param chatClient                    Spring AI ChatClient
     * @param properties                    mentor 配置
     * @param palaceToolProvider            工具提供者（agentic 模式用，可为 null）
     * @param palaceHybridRetrievalService  混合检索服务（rag / agentic 模式 L1 预检索用，可为 null）
     */
    public SpringAiMentorProvider(ChatClient chatClient, MentorProperties properties,
                                   PalaceToolProvider palaceToolProvider,
                                   PalaceHybridRetrievalService palaceHybridRetrievalService) {
        this.chatClient = chatClient;
        this.properties = properties;
        this.palaceToolProvider = palaceToolProvider;
        this.palaceHybridRetrievalService = palaceHybridRetrievalService;
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
        List<String> preRetrievedEvidence = preRetrieveEvidence(searchMode, request);
        String systemPrompt = MemPalacePromptBuilder.buildSystemPrompt(searchMode, preRetrievedEvidence);

        String content;
        try {
            content = callChatClient(searchMode, systemPrompt, request.prompt(), request.conversationId());
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
     * 根据 searchMode 决定是否执行 L1 预检索。
     */
    private List<String> preRetrieveEvidence(String searchMode, ProviderRequest request) {
        if (!requiresPreRetrieval(searchMode)) {
            return List.of();
        }
        if (palaceHybridRetrievalService == null) {
            log.warn("search-mode={} requires pre-retrieval but PalaceHybridRetrievalService is unavailable", searchMode);
            return List.of();
        }

        RetrievalRequest retrievalRequest = new RetrievalRequest(
                request.prompt(),
                null,
                null,
                request.childAgeMonths(),
                PRE_RETRIEVAL_MAX_RESULTS,
                PRE_RETRIEVAL_MAX_HOPS);

        try {
            RetrievalResult retrievalResult = palaceHybridRetrievalService.retrieve(retrievalRequest);
            QueryTrace trace = retrievalResult.trace();
            log.info(
                    "hybrid pre-retrieval complete: mode={}, candidates={}, trace.present={}, temporalRule='{}', projectionVersion='{}'",
                    searchMode,
                    retrievalResult.rankedCandidates().size(),
                    trace != null,
                    trace == null ? "missing" : trace.temporalRuleApplied(),
                    trace == null ? "missing" : trace.projectionVersionUsed());

            return retrievalResult.rankedCandidates().stream()
                    .map(this::formatEvidence)
                    .filter(content -> content != null && !content.isBlank())
                    .limit(PRE_RETRIEVAL_MAX_RESULTS)
                    .toList();
        } catch (Exception e) {
            log.warn(
                    "hybrid pre-retrieval failed: mode={}, childAgeMonths={}, prompt.length={}, reason={}",
                    searchMode,
                    request.childAgeMonths(),
                    request.prompt() == null ? 0 : request.prompt().length(),
                    sanitize(e.getMessage()));
            return List.of();
        }
    }

    private boolean requiresPreRetrieval(String searchMode) {
        return "rag".equals(searchMode) || "agentic".equals(searchMode);
    }

    private String formatEvidence(HybridCandidate candidate) {
        if (candidate == null || candidate.content() == null || candidate.content().isBlank()) {
            return "";
        }
        String sourceBook = candidate.sourceBook();
        String ageRange = candidate.ageRangeRaw();
        StringBuilder sb = new StringBuilder();
        if (sourceBook != null && !sourceBook.isBlank()) {
            sb.append("【").append(sourceBook).append("】");
        }
        if (ageRange != null && !ageRange.isBlank()) {
            sb.append("（适用年龄：").append(ageRange).append("）");
        }
        if (!sb.isEmpty()) {
            sb.append("：");
        }
        sb.append(candidate.content().trim());
        return sb.toString();
    }

    /**
     * 根据 searchMode 决定是否注册 tools 并调用 ChatClient。
     * 通过 advisors(param) 传入 conversationId，当 conversationId 为 null 时自动生成临时 UUID。
     */
    private String callChatClient(String searchMode, String systemPrompt, String userPrompt, String conversationId) {
        String effectiveConversationId = (conversationId != null && !conversationId.isBlank())
                ? conversationId
                : UUID.randomUUID().toString();
        log.info("conversation.id={}", effectiveConversationId);

        var spec = chatClient.prompt()
                .system(systemPrompt)
                .user(userPrompt)
                .advisors(a -> a.param(ChatMemory.CONVERSATION_ID, effectiveConversationId));

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
