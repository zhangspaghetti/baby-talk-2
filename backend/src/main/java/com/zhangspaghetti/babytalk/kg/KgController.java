package com.zhangspaghetti.babytalk.kg;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * KG REST API — 矛盾管理 + 管理员通知。
 *
 * <ul>
 *   <li>GET  /api/v1/kg/notifications — 查询通知（可选 ?unread=true）</li>
 *   <li>PUT  /api/v1/kg/notifications/{id}/read — 标记通知已读</li>
 *   <li>GET  /api/v1/kg/contradictions — 查询矛盾（可选 ?status=escalated）</li>
 *   <li>PUT  /api/v1/kg/contradictions/{id}/resolve — 解决矛盾</li>
 * </ul>
 */
@RestController
@RequestMapping("/api/v1/kg")
public class KgController {

    private static final Logger log = LoggerFactory.getLogger(KgController.class);

    private final KgAdminNotificationRepository notificationRepository;
    private final KgContradictionRepository contradictionRepository;

    public KgController(KgAdminNotificationRepository notificationRepository,
                         KgContradictionRepository contradictionRepository) {
        this.notificationRepository = notificationRepository;
        this.contradictionRepository = contradictionRepository;
    }

    // ─── 通知端点 ─────────────────────────────────────────────

    /**
     * 查询管理员通知。
     *
     * @param unread 如果 true，只返回未读通知
     * @return 通知列表
     */
    @GetMapping("/notifications")
    public ResponseEntity<List<Map<String, Object>>> getNotifications(
            @RequestParam(value = "unread", required = false) Boolean unread) {

        log.info("GET /notifications: unread={}", unread);

        List<KgAdminNotification> notifications;
        if (Boolean.TRUE.equals(unread)) {
            notifications = notificationRepository.findUnread();
        } else {
            notifications = notificationRepository.findAll();
        }

        List<Map<String, Object>> result = notifications.stream()
                .map(KgController::notificationToMap)
                .collect(Collectors.toList());

        return ResponseEntity.ok(result);
    }

    /**
     * 标记通知为已读。
     *
     * @param id 通知 UUID
     * @return 200 OK 或 404 Not Found
     */
    @PutMapping("/notifications/{id}/read")
    public ResponseEntity<Map<String, Object>> markNotificationRead(@PathVariable("id") String id) {
        UUID notificationId;
        try {
            notificationId = UUID.fromString(id);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest()
                    .body(Map.of("error", "无效的 UUID 格式: " + id));
        }

        return notificationRepository.findById(notificationId)
                .map(notification -> {
                    notificationRepository.markRead(notificationId);
                    log.info("通知已标记为已读: id={}", notificationId);
                    return ResponseEntity.ok(Map.<String, Object>of(
                            "id", notificationId.toString(),
                            "message", "已标记为已读"));
                })
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    // ─── 矛盾端点 ─────────────────────────────────────────────

    /**
     * 查询矛盾记录。
     *
     * @param status 按状态过滤（可选，如 escalated）
     * @return 矛盾列表
     */
    @GetMapping("/contradictions")
    public ResponseEntity<List<Map<String, Object>>> getContradictions(
            @RequestParam(value = "status", required = false) String status) {

        log.info("GET /contradictions: status={}", status);

        List<KgContradiction> contradictions;
        if (status != null && !status.isBlank()) {
            contradictions = contradictionRepository.findByStatus(status);
        } else {
            contradictions = contradictionRepository.findAll();
        }

        List<Map<String, Object>> result = contradictions.stream()
                .map(KgController::contradictionToMap)
                .collect(Collectors.toList());

        return ResponseEntity.ok(result);
    }

    /**
     * 解决矛盾 — 更新状态为 resolved + 设置 adminNotes。
     * 幂等：已 resolved 的矛盾再次 resolve 不报错，返回当前状态。
     *
     * @param id   矛盾 UUID
     * @param body 包含 adminNotes 的请求体
     * @return 200 OK 或 404 Not Found
     */
    @PutMapping("/contradictions/{id}/resolve")
    public ResponseEntity<Map<String, Object>> resolveContradiction(
            @PathVariable("id") String id,
            @RequestBody(required = false) Map<String, String> body) {

        UUID contradictionId;
        try {
            contradictionId = UUID.fromString(id);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest()
                    .body(Map.of("error", "无效的 UUID 格式: " + id));
        }

        return contradictionRepository.findById(contradictionId)
                .map(contradiction -> {
                    // 幂等：已 resolved 的不再操作
                    if (KgContradiction.STATUS_RESOLVED.equals(contradiction.status())) {
                        log.info("矛盾已处于 resolved 状态（幂等）: id={}", contradictionId);
                        return ResponseEntity.ok(contradictionToMap(contradiction));
                    }

                    String adminNotes = (body != null) ? body.getOrDefault("adminNotes", "") : "";
                    contradictionRepository.updateResolved(contradictionId, adminNotes);

                    log.info("矛盾已解决: id={}, adminNotes='{}'", contradictionId, adminNotes);

                    // 重新查询以返回最新状态
                    KgContradiction updated = contradictionRepository.findById(contradictionId)
                            .orElse(contradiction);
                    return ResponseEntity.ok(contradictionToMap(updated));
                })
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    // ─── 转换辅助方法 ─────────────────────────────────────────

    private static Map<String, Object> notificationToMap(KgAdminNotification n) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("id", n.id().toString());
        map.put("contradictionId", n.contradictionId().toString());
        map.put("notificationType", n.notificationType());
        map.put("message", n.message());
        map.put("isRead", n.isRead());
        map.put("createdAt", n.createdAt().toString());
        return map;
    }

    private static Map<String, Object> contradictionToMap(KgContradiction c) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("id", c.id().toString());
        map.put("entityTopic", c.entityTopic());
        map.put("relationshipAId", c.relationshipAId().toString());
        map.put("relationshipBId", c.relationshipBId().toString());
        map.put("sourceABook", c.sourceABook());
        map.put("sourceBBook", c.sourceBBook());
        map.put("description", c.description());
        map.put("status", c.status());
        map.put("agentReviewResult", c.agentReviewResult());
        map.put("adminNotes", c.adminNotes());
        map.put("detectedAt", c.detectedAt().toString());
        map.put("reviewedAt", c.reviewedAt() != null ? c.reviewedAt().toString() : null);
        map.put("resolvedAt", c.resolvedAt() != null ? c.resolvedAt().toString() : null);
        return map;
    }
}
