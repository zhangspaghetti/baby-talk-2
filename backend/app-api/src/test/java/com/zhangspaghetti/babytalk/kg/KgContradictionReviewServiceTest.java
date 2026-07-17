package com.zhangspaghetti.babytalk.kg;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.json.JsonMapper;
import java.math.BigDecimal;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.client.ChatClient.CallResponseSpec;
import org.springframework.ai.chat.client.ChatClient.ChatClientRequestSpec;

/**
 * 矛盾审查服务单元测试 — 纯 Mockito，mock ChatClient fluent API。
 */
@ExtendWith(MockitoExtension.class)
class KgContradictionReviewServiceTest {

    @Mock private ChatClient chatClient;
    @Mock private ChatClientRequestSpec requestSpec;
    @Mock private CallResponseSpec callResponseSpec;
    @Mock private KgContradictionRepository contradictionRepository;
    @Mock private KgAdminNotificationRepository adminNotificationRepository;
    @Mock private KgEntityRepository entityRepository;
    @Mock private KgRelationshipRepository relationshipRepository;

    private KgContradictionReviewService reviewService;
    private final ObjectMapper objectMapper = JsonMapper.builder().build();

    private static final KgProperties ENABLED_PROPS = new KgProperties(
            Duration.ofMinutes(5), true, 10);
    private static final KgProperties DISABLED_PROPS = new KgProperties(
            Duration.ofMinutes(5), false, 10);

    @BeforeEach
    void setUp() {
        // 设置 ChatClient fluent chain mock
        lenient().when(chatClient.prompt()).thenReturn(requestSpec);
        lenient().when(requestSpec.user(anyString())).thenReturn(requestSpec);
        lenient().when(requestSpec.call()).thenReturn(callResponseSpec);

        reviewService = new KgContradictionReviewService(
                chatClient, contradictionRepository, adminNotificationRepository,
                entityRepository, relationshipRepository, ENABLED_PROPS, objectMapper);
    }

    private KgContradiction sampleContradiction() {
        return KgContradiction.detected(
                "早睡 vs 晚睡",
                UUID.randomUUID(), UUID.randomUUID(),
                "育儿百科", "西尔斯亲密育儿",
                "关于入睡时间的矛盾建议");
    }

    @Test
    @DisplayName("LLM 返回 resolved — 矛盾标记为 resolved，不创建通知")
    void shouldResolveWhenLlmVerdictIsResolved() {
        KgContradiction c = sampleContradiction();
        String llmResponse = """
                ```json
                {"verdict": "resolved", "reason": "两条建议适用于不同月龄，不构成真实矛盾"}
                ```
                """;

        when(callResponseSpec.content()).thenReturn(llmResponse);
        when(relationshipRepository.findById(any())).thenReturn(Optional.empty());
        when(entityRepository.findById(any())).thenReturn(Optional.empty());

        String verdict = reviewService.reviewSingle(c);

        assertThat(verdict).isEqualTo("resolved");
        verify(contradictionRepository).updateStatus(
                eq(c.id()), eq(KgContradiction.STATUS_REVIEWING), isNull());
        verify(contradictionRepository).updateStatus(
                eq(c.id()), eq(KgContradiction.STATUS_RESOLVED), eq(llmResponse));
        verifyNoInteractions(adminNotificationRepository);
    }

    @Test
    @DisplayName("LLM 返回 escalated — 矛盾升级 + 创建管理员通知")
    void shouldEscalateWhenLlmVerdictIsEscalated() {
        KgContradiction c = sampleContradiction();
        String llmResponse = """
                ```json
                {"verdict": "escalated", "reason": "两条建议确实矛盾，需要专家审核"}
                ```
                """;

        when(callResponseSpec.content()).thenReturn(llmResponse);
        when(relationshipRepository.findById(any())).thenReturn(Optional.empty());
        when(entityRepository.findById(any())).thenReturn(Optional.empty());

        String verdict = reviewService.reviewSingle(c);

        assertThat(verdict).isEqualTo("escalated");
        verify(contradictionRepository).updateStatus(
                eq(c.id()), eq(KgContradiction.STATUS_ESCALATED), eq(llmResponse));

        ArgumentCaptor<KgAdminNotification> captor = ArgumentCaptor.forClass(KgAdminNotification.class);
        verify(adminNotificationRepository).insert(captor.capture());
        KgAdminNotification notification = captor.getValue();
        assertThat(notification.contradictionId()).isEqualTo(c.id());
        assertThat(notification.notificationType()).isEqualTo("contradiction_escalated");
        assertThat(notification.isRead()).isFalse();
    }

    @Test
    @DisplayName("ChatClient 抛异常 — 矛盾保持 detected 状态（安全默认）")
    void shouldKeepDetectedOnChatClientException() {
        KgContradiction c = sampleContradiction();
        List<KgContradiction> pending = List.of(c);

        when(contradictionRepository.findPendingReview(anyInt())).thenReturn(pending);
        when(relationshipRepository.findById(any())).thenReturn(Optional.empty());
        when(entityRepository.findById(any())).thenReturn(Optional.empty());
        when(callResponseSpec.content()).thenThrow(new RuntimeException("LLM API 超时"));

        reviewService.reviewPendingContradictions();

        // updateStatus 应该被调用一次（reviewing），然后异常导致不再更新
        verify(contradictionRepository).updateStatus(
                eq(c.id()), eq(KgContradiction.STATUS_REVIEWING), isNull());
        // 不应该更新为 resolved 或 escalated
        verify(contradictionRepository, never()).updateStatus(
                eq(c.id()), eq(KgContradiction.STATUS_RESOLVED), anyString());
        verify(contradictionRepository, never()).updateStatus(
                eq(c.id()), eq(KgContradiction.STATUS_ESCALATED), anyString());
        verifyNoInteractions(adminNotificationRepository);
    }

    @Test
    @DisplayName("LLM 返回非 JSON — 默认 escalated")
    void shouldEscalateOnMalformedResponse() {
        KgContradiction c = sampleContradiction();
        String malformedResponse = "我认为这两条建议确实矛盾，但我无法给出 JSON 格式。";

        when(callResponseSpec.content()).thenReturn(malformedResponse);
        when(relationshipRepository.findById(any())).thenReturn(Optional.empty());
        when(entityRepository.findById(any())).thenReturn(Optional.empty());

        String verdict = reviewService.reviewSingle(c);

        assertThat(verdict).isEqualTo("escalated");
        verify(contradictionRepository).updateStatus(
                eq(c.id()), eq(KgContradiction.STATUS_ESCALATED), eq(malformedResponse));
        verify(adminNotificationRepository).insert(any(KgAdminNotification.class));
    }

    @Test
    @DisplayName("reviewEnabled=false 时跳过审查")
    void shouldSkipWhenReviewDisabled() {
        KgContradictionReviewService disabledService = new KgContradictionReviewService(
                chatClient, contradictionRepository, adminNotificationRepository,
                entityRepository, relationshipRepository, DISABLED_PROPS, objectMapper);

        disabledService.reviewPendingContradictions();

        verifyNoInteractions(contradictionRepository);
        verifyNoInteractions(chatClient);
    }

    @Test
    @DisplayName("LLM 返回空响应 — 默认 escalated")
    void shouldEscalateOnEmptyResponse() {
        KgContradiction c = sampleContradiction();

        when(callResponseSpec.content()).thenReturn("");
        when(relationshipRepository.findById(any())).thenReturn(Optional.empty());
        when(entityRepository.findById(any())).thenReturn(Optional.empty());

        String verdict = reviewService.reviewSingle(c);

        assertThat(verdict).isEqualTo("escalated");
    }

    @Test
    @DisplayName("批次扫描 — 多条矛盾依次处理")
    void shouldProcessBatchOfContradictions() {
        KgContradiction c1 = sampleContradiction();
        KgContradiction c2 = sampleContradiction();

        when(contradictionRepository.findPendingReview(anyInt())).thenReturn(List.of(c1, c2));
        when(relationshipRepository.findById(any())).thenReturn(Optional.empty());
        when(entityRepository.findById(any())).thenReturn(Optional.empty());
        when(callResponseSpec.content()).thenReturn(
                "{\"verdict\": \"resolved\", \"reason\": \"OK\"}");

        reviewService.reviewPendingContradictions();

        // 两条都应该被处理（reviewing + resolved 各一次）
        verify(contradictionRepository, times(2)).updateStatus(
                any(), eq(KgContradiction.STATUS_REVIEWING), isNull());
        verify(contradictionRepository, times(2)).updateStatus(
                any(), eq(KgContradiction.STATUS_RESOLVED), anyString());
    }
}
