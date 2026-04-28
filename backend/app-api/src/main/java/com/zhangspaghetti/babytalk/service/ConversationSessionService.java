package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.config.MentorProperties;
import java.time.Instant;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * 管理对话会话的超时逻辑。
 * <ul>
 *   <li>clientConversationId 为 null/blank → 生成新 UUID（新会话）</li>
 *   <li>SPRING_AI_CHAT_MEMORY 表无记录 → 返回原 conversationId（首次使用）</li>
 *   <li>最后消息超过 sessionTimeout → 生成新 UUID（会话过期）</li>
 *   <li>未超时 → 返回原 conversationId（继续对话）</li>
 * </ul>
 */
@Service
public class ConversationSessionService {

    private static final Logger log = LoggerFactory.getLogger(ConversationSessionService.class);

    private final ConversationSessionMapper conversationSessionMapper;
    private final MentorProperties properties;

    public ConversationSessionService(ConversationSessionMapper conversationSessionMapper, MentorProperties properties) {
        this.conversationSessionMapper = conversationSessionMapper;
        this.properties = properties;
    }

    /**
     * 解析有效的 conversationId。
     *
     * @param clientConversationId 客户端传入的 conversationId（可为 null）
     * @return 有效的 conversationId
     */
    public String resolveConversationId(String clientConversationId) {
        if (clientConversationId == null || clientConversationId.isBlank()) {
            var newId = UUID.randomUUID().toString();
            log.info("conversation.id={}, isNew=true, isExpired=false", newId);
            return newId;
        }

        var trimmed = clientConversationId.trim();
        // 超长 conversationId 截断为安全长度
        if (trimmed.length() > 128) {
            trimmed = trimmed.substring(0, 128);
        }

        var lastTimestamp = findLastMessageTimestamp(trimmed);
        if (lastTimestamp == null) {
            // 首次使用此 conversationId，无历史记录
            log.info("conversation.id={}, isNew=true, isExpired=false", trimmed);
            return trimmed;
        }

        var timeout = properties.effectiveSessionTimeout();
        if (Instant.now().isAfter(lastTimestamp.plus(timeout))) {
            var newId = UUID.randomUUID().toString();
            log.warn("conversation expired after 30min, old.id={}, new.id={}", trimmed, newId);
            log.info("conversation.id={}, isNew=true, isExpired=true", newId);
            return newId;
        }

        log.info("conversation.id={}, isNew=false, isExpired=false", trimmed);
        return trimmed;
    }

    /**
     * 查询 SPRING_AI_CHAT_MEMORY 表中指定 conversation_id 的最后一条消息时间。
     */
    private Instant findLastMessageTimestamp(String conversationId) {
        return conversationSessionMapper.findLastMessageTimestamp(conversationId);
    }
}
