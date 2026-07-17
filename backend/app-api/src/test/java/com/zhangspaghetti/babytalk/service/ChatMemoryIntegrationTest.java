package com.zhangspaghetti.babytalk.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.ai.chat.memory.ChatMemory;
import org.springframework.ai.chat.messages.AssistantMessage;
import org.springframework.ai.chat.messages.Message;
import org.springframework.ai.chat.messages.UserMessage;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * ChatMemory 端到端集成测试。
 * 验证多轮对话记忆、10 轮滑动窗口、30 分钟超时的端到端行为。
 * 依赖 Testcontainers PostgreSQL + Flyway 自动建表。
 */
class ChatMemoryIntegrationTest extends AbstractIntegrationTest {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private ConversationSessionService conversationSessionService;

    @Autowired
    private ChatMemory chatMemory;

    @BeforeEach
    void cleanUp() {
        jdbcTemplate.execute("DELETE FROM spring_ai_chat_memory");
    }

    // 测试 1: 同一 conversationId 多轮对话 — 未超时返回原 ID
    @Test
    void sameConversationIdReturnedWhenNotExpired() {
        String convId = "conv-multi-turn";
        Timestamp now = Timestamp.from(Instant.now());

        // 插入 3 条消息模拟多轮对话
        insertFixtureMessage(convId, "你好", "USER", now);
        insertFixtureMessage(convId, "你好！有什么可以帮忙的吗？", "ASSISTANT", now);
        insertFixtureMessage(convId, "讲个故事", "USER", now);

        String resolved = conversationSessionService.resolveConversationId(convId);
        assertThat(resolved).isEqualTo(convId);
    }

    // 测试 2: 11 轮滑动窗口 — maxMessages=10 正确裁剪
    @Test
    void slidingWindowTrimsOldestMessages() {
        String convId = "conv-sliding-window";

        // 连续添加 12 条消息（6 轮对话 = 12 条 user+assistant）
        for (int i = 1; i <= 12; i++) {
            Message msg = (i % 2 == 1)
                    ? new UserMessage("用户消息 " + i)
                    : new AssistantMessage("助手回复 " + i);
            chatMemory.add(convId, List.of(msg));
        }

        // 获取记忆 — 应该只保留最近 10 条，最早的 2 条被丢弃
        List<Message> messages = chatMemory.get(convId);
        List<String> contents = messages.stream()
                .map(Message::getText)
                .toList();
        assertThat(contents).containsExactly(
                "用户消息 3",
                "助手回复 4",
                "用户消息 5",
                "助手回复 6",
                "用户消息 7",
                "助手回复 8",
                "用户消息 9",
                "助手回复 10",
                "用户消息 11",
                "助手回复 12");
    }

    // 测试 3: 30 分钟超时 — 返回新的不同 conversationId
    @Test
    void expiredConversationReturnsNewId() {
        String oldConvId = "conv-expired-test";
        Timestamp pastTimestamp = Timestamp.from(Instant.now().minus(31, ChronoUnit.MINUTES));

        insertFixtureMessage(oldConvId, "旧消息", "USER", pastTimestamp);

        String resolved = conversationSessionService.resolveConversationId(oldConvId);
        assertThat(resolved)
                .isNotEqualTo(oldConvId)
                .matches("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}");
    }

    // 测试 4: 向后兼容 — null conversationId 生成 UUID
    @Test
    void nullConversationIdGeneratesUuid() {
        String resolved = conversationSessionService.resolveConversationId(null);
        assertThat(resolved)
                .isNotNull()
                .matches("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}");
    }

    // 测试 5: 首次使用的 conversationId — 表中无记录返回原 ID
    @Test
    void brandNewConversationIdReturnedAsIs() {
        String brandNewId = "brand-new-conv-id";
        // 确认表中没有这个 ID 的记录
        Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM spring_ai_chat_memory WHERE conversation_id = ?",
                Integer.class, brandNewId);
        assertThat(count).isZero();

        String resolved = conversationSessionService.resolveConversationId(brandNewId);
        assertThat(resolved).isEqualTo(brandNewId);
    }

    @Test
    void databaseGeneratedSequencePreservesSameTimestampMessageOrder() {
        String convId = "conv-generated-sequence";
        Timestamp sameTimestamp = Timestamp.from(Instant.parse("2026-07-14T00:00:00Z"));

        insertFixtureMessage(convId, "第一句", "USER", sameTimestamp);
        insertFixtureMessage(convId, "第二句", "ASSISTANT", sameTimestamp);
        insertFixtureMessage(convId, "第三句", "USER", sameTimestamp);

        assertThat(chatMemory.get(convId).stream().map(Message::getText).toList())
                .containsExactly("第一句", "第二句", "第三句");
        assertThat(jdbcTemplate.queryForList(
                "SELECT sequence_id FROM spring_ai_chat_memory WHERE conversation_id = ? ORDER BY sequence_id",
                Long.class,
                convId)).hasSize(3).doesNotHaveDuplicates().isSorted();
    }

    private void insertFixtureMessage(String conversationId, String content, String type, Timestamp timestamp) {
        jdbcTemplate.update(
                "INSERT INTO spring_ai_chat_memory (conversation_id, content, type, \"timestamp\") VALUES (?, ?, ?, ?)",
                conversationId,
                content,
                type,
                timestamp);
    }
}
