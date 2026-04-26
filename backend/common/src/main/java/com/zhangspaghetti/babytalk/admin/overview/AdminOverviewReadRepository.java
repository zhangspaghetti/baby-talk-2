package com.zhangspaghetti.babytalk.admin.overview;

import com.zhangspaghetti.babytalk.admin.distribution.AdminDistributionStatsReadRepository;
import com.zhangspaghetti.babytalk.admin.knowledge.AdminKnowledgeIngestionRepository;
import com.zhangspaghetti.babytalk.admin.knowledge.AdminKnowledgeKgRepository;
import com.zhangspaghetti.babytalk.admin.mentor.AdminMentorAuditReadRepository;
import java.time.Instant;

public class AdminOverviewReadRepository {

    private final AdminKnowledgeIngestionRepository ingestionRepository;
    private final AdminKnowledgeKgRepository kgRepository;
    private final AdminMentorAuditReadRepository mentorAuditReadRepository;
    private final AdminDistributionStatsReadRepository distributionStatsReadRepository;

    public AdminOverviewReadRepository(
            AdminKnowledgeIngestionRepository ingestionRepository,
            AdminKnowledgeKgRepository kgRepository,
            AdminMentorAuditReadRepository mentorAuditReadRepository,
            AdminDistributionStatsReadRepository distributionStatsReadRepository
    ) {
        this.ingestionRepository = ingestionRepository;
        this.kgRepository = kgRepository;
        this.mentorAuditReadRepository = mentorAuditReadRepository;
        this.distributionStatsReadRepository = distributionStatsReadRepository;
    }

    public KnowledgeIngestionSummaryRow fetchKnowledgeIngestionSummary() {
        var row = ingestionRepository.fetchQueueSummary();
        return new KnowledgeIngestionSummaryRow(
                row.pendingCount(),
                row.processingCount(),
                row.failedCount(),
                row.completedCount(),
                row.lastUpdatedAt()
        );
    }

    public KnowledgeKgSummaryRow fetchKnowledgeKgSummary() {
        var row = kgRepository.fetchQueueSummary();
        return new KnowledgeKgSummaryRow(
                row.openCount(),
                row.escalatedCount(),
                row.unreadNotificationCount(),
                row.resolvedCount(),
                row.lastUpdatedAt()
        );
    }

    public MentorAuditSummaryRow fetchMentorAuditSummary() {
        var row = mentorAuditReadRepository.fetchOverviewSummary();
        return new MentorAuditSummaryRow(
                row.flaggedIncidentCount(),
                row.blockedFallbackCount(),
                row.rateLimitedCount(),
                row.retryableCount(),
                row.lastOccurredAt()
        );
    }

    public DistributionSummaryRow fetchDistributionSummary(Instant windowStart) {
        var row = distributionStatsReadRepository.fetchOverviewSummary(windowStart);
        return new DistributionSummaryRow(
                row.releaseTotalEvents(),
                row.releaseFailureEvents(),
                row.shareTotalEvents(),
                row.shareFailureEvents(),
                row.lastSeenAt()
        );
    }

    public record KnowledgeIngestionSummaryRow(
            long pendingCount,
            long processingCount,
            long failedCount,
            long completedCount,
            Instant lastUpdatedAt
    ) {
    }

    public record KnowledgeKgSummaryRow(
            long openCount,
            long escalatedCount,
            long unreadNotificationCount,
            long resolvedCount,
            Instant lastUpdatedAt
    ) {
    }

    public record MentorAuditSummaryRow(
            long flaggedIncidentCount,
            long blockedFallbackCount,
            long rateLimitedCount,
            long retryableCount,
            Instant lastOccurredAt
    ) {
    }

    public record DistributionSummaryRow(
            long releaseTotalEvents,
            long releaseFailureEvents,
            long shareTotalEvents,
            long shareFailureEvents,
            Instant lastSeenAt
    ) {
    }
}
