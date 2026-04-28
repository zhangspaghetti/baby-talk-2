package com.zhangspaghetti.babytalk.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

import com.zhangspaghetti.babytalk.config.MentorProperties;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class ConversationSessionServiceTest {

    @Mock
    private ConversationSessionMapper conversationSessionMapper;

    private ConversationSessionService service;

    private MentorProperties makeProperties(Duration sessionTimeout) {
        return new MentorProperties(
                "dev",
                Duration.ofSeconds(4),
                null,
                null,
                null,
                null,
                null,
                3,
                Duration.ofMinutes(10),
                280,
                280,
                List.of("home"),
                List.of("single_turn"),
                List.of("体罚"),
                "[timeout]",
                "[malformed]",
                "[unavailable]",
                "none",
                sessionTimeout,
                null
        );
    }

    @BeforeEach
    void setUp() {
        service = new ConversationSessionService(conversationSessionMapper, makeProperties(Duration.ofMinutes(30)));
    }

    @Nested
    @DisplayName("null/blank conversationId")
    class NullOrBlankConversationId {

        @Test
        @DisplayName("null → 生成新 UUID")
        void nullConversationIdGeneratesUuid() {
            var result = service.resolveConversationId(null);
            assertThat(result).isNotNull().isNotBlank();
            assertThat(result).matches("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}");
        }

        @Test
        @DisplayName("blank → 生成新 UUID")
        void blankConversationIdGeneratesUuid() {
            var result = service.resolveConversationId("   ");
            assertThat(result).isNotNull().isNotBlank();
            assertThat(result).matches("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}");
        }

        @Test
        @DisplayName("empty → 生成新 UUID")
        void emptyConversationIdGeneratesUuid() {
            var result = service.resolveConversationId("");
            assertThat(result).isNotNull().isNotBlank();
            assertThat(result).matches("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}");
        }
    }

    @Nested
    @DisplayName("有效 conversationId")
    class ValidConversationId {

        @Test
        @DisplayName("无历史记录 → 返回原 ID（首次使用）")
        void noHistoryReturnsOriginalId() {
            when(conversationSessionMapper.findLastMessageTimestamp("conv-123")).thenReturn(null);

            var result = service.resolveConversationId("conv-123");
            assertThat(result).isEqualTo("conv-123");
        }

        @Test
        @DisplayName("未超时 → 返回原 ID")
        void notExpiredReturnsOriginalId() {
            when(conversationSessionMapper.findLastMessageTimestamp("conv-active"))
                    .thenReturn(Instant.now().minus(Duration.ofMinutes(10)));

            var result = service.resolveConversationId("conv-active");
            assertThat(result).isEqualTo("conv-active");
        }

        @Test
        @DisplayName("超时 → 生成新 UUID")
        void expiredGeneratesNewUuid() {
            when(conversationSessionMapper.findLastMessageTimestamp("conv-expired"))
                    .thenReturn(Instant.now().minus(Duration.ofMinutes(45)));

            var result = service.resolveConversationId("conv-expired");
            assertThat(result).isNotEqualTo("conv-expired");
            assertThat(result).matches("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}");
        }
    }

    @Nested
    @DisplayName("边界和恶意输入")
    class BoundaryAndMalformedInputs {

        @Test
        @DisplayName("超长 conversationId (>128 chars) → 截断后正常处理")
        void overlyLongConversationIdIsTruncated() {
            var longId = "a".repeat(200);
            var truncated = "a".repeat(128);
            when(conversationSessionMapper.findLastMessageTimestamp(truncated)).thenReturn(null);

            var result = service.resolveConversationId(longId);
            assertThat(result).isEqualTo(truncated);
        }

        @Test
        @DisplayName("正好在 30 分钟边界（29分59秒前）→ 不超时")
        void exactlyAtBoundaryNotExpired() {
            when(conversationSessionMapper.findLastMessageTimestamp("conv-border"))
                    .thenReturn(Instant.now().minus(Duration.ofMinutes(29).plusSeconds(59)));

            var result = service.resolveConversationId("conv-border");
            assertThat(result).isEqualTo("conv-border");
        }

        @Test
        @DisplayName("正好在 30 分钟边界（31分钟前）→ 超时")
        void justPastBoundaryExpired() {
            when(conversationSessionMapper.findLastMessageTimestamp("conv-past"))
                    .thenReturn(Instant.now().minus(Duration.ofMinutes(31)));

            var result = service.resolveConversationId("conv-past");
            assertThat(result).isNotEqualTo("conv-past");
            assertThat(result).matches("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}");
        }
    }
}
