package com.zhangspaghetti.babytalk.admin.knowledge;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.transaction.annotation.Transactional;

public class AdminKnowledgeKgRepository {

    private final AdminKnowledgeKgMapper adminKnowledgeKgMapper;

    public AdminKnowledgeKgRepository(AdminKnowledgeKgMapper adminKnowledgeKgMapper) {
        this.adminKnowledgeKgMapper = adminKnowledgeKgMapper;
    }

    @Transactional(readOnly = true)
    public List<ContradictionRow> listContradictions(String status, int limit) {
        adminKnowledgeKgMapper.applyStatementTimeout();
        return adminKnowledgeKgMapper.listContradictions(status, limit);
    }

    @Transactional(readOnly = true)
    public Optional<ContradictionRow> findContradiction(UUID contradictionId) {
        adminKnowledgeKgMapper.applyStatementTimeout();
        return Optional.ofNullable(adminKnowledgeKgMapper.findContradiction(contradictionId));
    }

    @Transactional
    public Optional<ContradictionRow> findContradictionForUpdate(UUID contradictionId) {
        adminKnowledgeKgMapper.applyStatementTimeout();
        return Optional.ofNullable(adminKnowledgeKgMapper.findContradictionForUpdate(contradictionId));
    }

    @Transactional
    public void resolveContradiction(UUID contradictionId, String adminNotes, Instant resolvedAt) {
        adminKnowledgeKgMapper.applyStatementTimeout();
        adminKnowledgeKgMapper.resolveContradiction(contradictionId, adminNotes, resolvedAt);
    }

    @Transactional(readOnly = true)
    public List<NotificationRow> listNotifications(UUID contradictionId, int limit) {
        adminKnowledgeKgMapper.applyStatementTimeout();
        return adminKnowledgeKgMapper.listNotifications(contradictionId, limit);
    }

    @Transactional(readOnly = true)
    public Optional<NotificationRow> findNotification(UUID notificationId) {
        adminKnowledgeKgMapper.applyStatementTimeout();
        return Optional.ofNullable(adminKnowledgeKgMapper.findNotification(notificationId));
    }

    @Transactional
    public Optional<NotificationRow> findNotificationForUpdate(UUID notificationId) {
        adminKnowledgeKgMapper.applyStatementTimeout();
        return Optional.ofNullable(adminKnowledgeKgMapper.findNotificationForUpdate(notificationId));
    }

    @Transactional
    public void markNotificationRead(UUID notificationId) {
        adminKnowledgeKgMapper.applyStatementTimeout();
        adminKnowledgeKgMapper.markNotificationRead(notificationId);
    }

    @Transactional(readOnly = true)
    public QueueSummaryRow fetchQueueSummary() {
        adminKnowledgeKgMapper.applyStatementTimeout();
        return adminKnowledgeKgMapper.fetchQueueSummary();
    }

    public record ContradictionRow(
            UUID id,
            String entityTopic,
            String sourceABook,
            String sourceBBook,
            String description,
            String status,
            String agentReviewResult,
            String adminNotes,
            Instant detectedAt,
            Instant reviewedAt,
            Instant resolvedAt,
            long notificationCount,
            long unreadNotificationCount
    ) {
    }

    public record NotificationRow(
            UUID id,
            UUID contradictionId,
            String notificationType,
            String message,
            boolean isRead,
            Instant createdAt
    ) {
    }

    public record QueueSummaryRow(
            long openCount,
            long escalatedCount,
            long unreadNotificationCount,
            long resolvedCount,
            Instant lastUpdatedAt
    ) {
    }
}
