package com.zhangspaghetti.babytalk.admin.mentor;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.transaction.annotation.Transactional;

public class AdminMentorAuditReadRepository {

    private final AdminMentorAuditReadMapper adminMentorAuditReadMapper;

    public AdminMentorAuditReadRepository(AdminMentorAuditReadMapper adminMentorAuditReadMapper) {
        this.adminMentorAuditReadMapper = adminMentorAuditReadMapper;
    }

    public List<QueueIncidentRow> listFlaggedIncidents(
            String installationReference,
            String legacyInstallationId,
            String flagCode,
            int limit
    ) {
        return adminMentorAuditReadMapper.listFlaggedIncidents(
                installationReference,
                legacyInstallationId,
                flagCode,
                limit);
    }

    public Optional<IncidentSnapshotRow> findIncidentSnapshot(String correlationId) {
        return Optional.ofNullable(adminMentorAuditReadMapper.findIncidentSnapshot(correlationId));
    }

    public List<TimelineRow> listTimeline(String correlationId) {
        return adminMentorAuditReadMapper.listTimeline(correlationId);
    }

    public Optional<DeliveredTurnRow> findDeliveredTurn(String correlationId) {
        return Optional.ofNullable(adminMentorAuditReadMapper.findDeliveredTurn(correlationId));
    }

    public int countCurrentWindowRequests(
            String installationReference,
            String legacyInstallationId,
            Instant windowStart
    ) {
        return adminMentorAuditReadMapper.countCurrentWindowRequests(
                installationReference,
                legacyInstallationId,
                windowStart);
    }

    @Transactional(readOnly = true)
    public OverviewSummaryRow fetchOverviewSummary() {
        adminMentorAuditReadMapper.applyStatementTimeout();
        return adminMentorAuditReadMapper.fetchOverviewSummary();
    }

    public record QueueIncidentRow(
            String correlationId,
            String installationId,
            String flagCode,
            String latestPhase,
            String failureCode,
            boolean retryable,
            boolean historicalRateLimited,
            Instant occurredAt
    ) {
    }

    public record IncidentSnapshotRow(
            String correlationId,
            String installationId,
            String flagCode,
            String latestPhase,
            String failureCode,
            boolean retryable,
            boolean historicalRateLimited,
            Instant occurredAt
    ) {
    }

    public record TimelineRow(
            long auditId,
            String correlationId,
            String installationId,
            String eventType,
            String phase,
            String result,
            String requestSummary,
            String responseSummary,
            String reason,
            String failureCode,
            boolean retryable,
            boolean rateLimited,
            Instant createdAt
    ) {
    }

    public record DeliveredTurnRow(
            String correlationId,
            String installationId,
            String result,
            String phase,
            String requestSummary,
            String responseSummary,
            String responseText,
            String providerMode,
            boolean blockedFallback,
            boolean retryable,
            Instant createdAt
    ) {
    }

    public record OverviewSummaryRow(
            long flaggedIncidentCount,
            long blockedFallbackCount,
            long rateLimitedCount,
            long retryableCount,
            Instant lastOccurredAt
    ) {
    }
}
