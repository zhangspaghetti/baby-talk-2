package com.zhangspaghetti.babytalk.kg;

import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.zhangspaghetti.babytalk.config.ApiContractProperties;
import com.zhangspaghetti.babytalk.config.ApiVersionInterceptor;
import com.zhangspaghetti.babytalk.config.ApiVersionService;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.MockMvc;

/**
 * KgController MockMvc 测试 — 验证 4 个 REST 端点的请求/响应映射。
 */
@WebMvcTest(KgController.class)
@AutoConfigureMockMvc(addFilters = false)
class KgControllerTest {

        private static final String SUPPORTED_APP_VERSION = "1.2.0";

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private KgAdminNotificationRepository notificationRepository;

    @MockitoBean
    private KgContradictionRepository contradictionRepository;

        @MockitoBean
        private ApiContractProperties apiContractProperties;

        @MockitoBean
        private ApiVersionService apiVersionService;

        @BeforeEach
        void allowSupportedAppVersion() {
                when(apiContractProperties.minSupportedVersion()).thenReturn(SUPPORTED_APP_VERSION);
                when(apiVersionService.isSupported(anyString(), anyString())).thenReturn(true);
        }

    // ─── GET /notifications ─────────────────────────────────

    @Test
    void getNotifications_returnsAllWhenUnreadNotSpecified() throws Exception {
        KgAdminNotification n1 = new KgAdminNotification(
                UUID.randomUUID(), UUID.randomUUID(),
                "contradiction_escalated", "测试通知1", false, Instant.now());
        KgAdminNotification n2 = new KgAdminNotification(
                UUID.randomUUID(), UUID.randomUUID(),
                "contradiction_escalated", "测试通知2", true, Instant.now());

        when(notificationRepository.findAll()).thenReturn(List.of(n1, n2));

        mockMvc.perform(apiGet("/api/v1/kg/notifications"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].message").value("测试通知1"))
                .andExpect(jsonPath("$[1].isRead").value(true));
    }

    @Test
    void getNotifications_returnsUnreadOnly() throws Exception {
        KgAdminNotification unread = new KgAdminNotification(
                UUID.randomUUID(), UUID.randomUUID(),
                "contradiction_escalated", "未读通知", false, Instant.now());

        when(notificationRepository.findUnread()).thenReturn(List.of(unread));

        mockMvc.perform(apiGet("/api/v1/kg/notifications").param("unread", "true"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].isRead").value(false));
    }

    @Test
    void getNotifications_returnsEmptyArrayWhenNone() throws Exception {
        when(notificationRepository.findAll()).thenReturn(List.of());

        mockMvc.perform(apiGet("/api/v1/kg/notifications"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));
    }

    // ─── PUT /notifications/{id}/read ─────────────────────

    @Test
    void markNotificationRead_returns200ForExisting() throws Exception {
        UUID notifId = UUID.randomUUID();
        KgAdminNotification n = new KgAdminNotification(
                notifId, UUID.randomUUID(),
                "contradiction_escalated", "测试", false, Instant.now());

        when(notificationRepository.findById(notifId)).thenReturn(Optional.of(n));

        mockMvc.perform(apiPut("/api/v1/kg/notifications/{id}/read", notifId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(notifId.toString()))
                .andExpect(jsonPath("$.message").value("已标记为已读"));

        verify(notificationRepository).markRead(notifId);
    }

    @Test
    void markNotificationRead_returns404ForNonExistent() throws Exception {
        UUID notifId = UUID.randomUUID();
        when(notificationRepository.findById(notifId)).thenReturn(Optional.empty());

        mockMvc.perform(apiPut("/api/v1/kg/notifications/{id}/read", notifId))
                .andExpect(status().isNotFound());
    }

    @Test
    void markNotificationRead_returns400ForInvalidUuid() throws Exception {
        mockMvc.perform(apiPut("/api/v1/kg/notifications/{id}/read", "not-a-uuid"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").isNotEmpty());
    }

    // ─── GET /contradictions ────────────────────────────────

    @Test
    void getContradictions_returnsAllWhenStatusNotSpecified() throws Exception {
        KgContradiction c = new KgContradiction(
                UUID.randomUUID(), "睡眠训练",
                UUID.randomUUID(), UUID.randomUUID(),
                "Book A", "Book B", "矛盾描述",
                "escalated", null, null,
                Instant.now(), null, null);

        when(contradictionRepository.findAll()).thenReturn(List.of(c));

        mockMvc.perform(apiGet("/api/v1/kg/contradictions"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].entityTopic").value("睡眠训练"))
                .andExpect(jsonPath("$[0].status").value("escalated"));
    }

    @Test
    void getContradictions_filtersByStatus() throws Exception {
        KgContradiction c = new KgContradiction(
                UUID.randomUUID(), "喂养方式",
                UUID.randomUUID(), UUID.randomUUID(),
                "Book C", "Book D", "喂养矛盾",
                "escalated", null, null,
                Instant.now(), null, null);

        when(contradictionRepository.findByStatus("escalated")).thenReturn(List.of(c));

        mockMvc.perform(apiGet("/api/v1/kg/contradictions").param("status", "escalated"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].status").value("escalated"));
    }

    // ─── PUT /contradictions/{id}/resolve ─────────────────

    @Test
    void resolveContradiction_returns200AndUpdates() throws Exception {
        UUID cId = UUID.randomUUID();
        KgContradiction c = new KgContradiction(
                cId, "母乳喂养",
                UUID.randomUUID(), UUID.randomUUID(),
                "Book E", "Book F", "母乳矛盾",
                "escalated", null, null,
                Instant.now(), Instant.now(), null);

        KgContradiction resolved = new KgContradiction(
                cId, "母乳喂养",
                c.relationshipAId(), c.relationshipBId(),
                "Book E", "Book F", "母乳矛盾",
                "resolved", null, "管理员备注",
                c.detectedAt(), c.reviewedAt(), Instant.now());

        when(contradictionRepository.findById(cId))
                .thenReturn(Optional.of(c))
                .thenReturn(Optional.of(resolved));

        mockMvc.perform(apiPut("/api/v1/kg/contradictions/{id}/resolve", cId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"adminNotes\":\"管理员备注\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("resolved"));

        verify(contradictionRepository).updateResolved(cId, "管理员备注");
    }

    @Test
    void resolveContradiction_returns404ForNonExistent() throws Exception {
        UUID cId = UUID.randomUUID();
        when(contradictionRepository.findById(cId)).thenReturn(Optional.empty());

        mockMvc.perform(apiPut("/api/v1/kg/contradictions/{id}/resolve", cId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"adminNotes\":\"test\"}"))
                .andExpect(status().isNotFound());
    }

    @Test
    void resolveContradiction_returns400ForInvalidUuid() throws Exception {
        mockMvc.perform(apiPut("/api/v1/kg/contradictions/{id}/resolve", "bad-uuid")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"adminNotes\":\"test\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").isNotEmpty());
    }

    @Test
    void resolveContradiction_idempotentForAlreadyResolved() throws Exception {
        UUID cId = UUID.randomUUID();
        KgContradiction resolved = new KgContradiction(
                cId, "已解决矛盾",
                UUID.randomUUID(), UUID.randomUUID(),
                "Book G", "Book H", "已解决",
                "resolved", null, "已有备注",
                Instant.now(), Instant.now(), Instant.now());

        when(contradictionRepository.findById(cId)).thenReturn(Optional.of(resolved));

                mockMvc.perform(apiPut("/api/v1/kg/contradictions/{id}/resolve", cId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"adminNotes\":\"新备注\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("resolved"));
        // 不应调用 updateResolved（幂等）
    }

        private MockHttpServletRequestBuilder apiGet(String path, Object... uriVariables) {
                return get(path, uriVariables)
                                .header(ApiVersionInterceptor.VERSION_HEADER, SUPPORTED_APP_VERSION);
        }

        private MockHttpServletRequestBuilder apiPut(String path, Object... uriVariables) {
                return put(path, uriVariables)
                                .header(ApiVersionInterceptor.VERSION_HEADER, SUPPORTED_APP_VERSION);
        }
}
