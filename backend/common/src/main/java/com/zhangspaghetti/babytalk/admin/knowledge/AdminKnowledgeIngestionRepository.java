package com.zhangspaghetti.babytalk.admin.knowledge;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.transaction.annotation.Transactional;

public class AdminKnowledgeIngestionRepository {

    private final AdminKnowledgeIngestionMapper adminKnowledgeIngestionMapper;

    public AdminKnowledgeIngestionRepository(AdminKnowledgeIngestionMapper adminKnowledgeIngestionMapper) {
        this.adminKnowledgeIngestionMapper = adminKnowledgeIngestionMapper;
    }

    @Transactional(readOnly = true)
    public List<IngestionJobRow> listJobs(String status, int limit) {
        adminKnowledgeIngestionMapper.applyStatementTimeout();
        return adminKnowledgeIngestionMapper.listJobs(status, limit);
    }

    @Transactional(readOnly = true)
    public Optional<IngestionJobRow> findJob(UUID jobId) {
        adminKnowledgeIngestionMapper.applyStatementTimeout();
        return Optional.ofNullable(adminKnowledgeIngestionMapper.findJob(jobId));
    }

    @Transactional(readOnly = true)
    public QueueSummaryRow fetchQueueSummary() {
        adminKnowledgeIngestionMapper.applyStatementTimeout();
        return adminKnowledgeIngestionMapper.fetchQueueSummary();
    }

    public record IngestionJobRow(
            UUID id,
            String originalFilename,
            String status,
            int totalChunks,
            String errorMessage,
            Instant createdAt,
            Instant updatedAt
    ) {
    }

    public record QueueSummaryRow(
            long pendingCount,
            long processingCount,
            long failedCount,
            long completedCount,
            Instant lastUpdatedAt
    ) {
    }
}
