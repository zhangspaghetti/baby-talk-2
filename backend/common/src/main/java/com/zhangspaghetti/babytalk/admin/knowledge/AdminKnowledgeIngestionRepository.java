package com.zhangspaghetti.babytalk.admin.knowledge;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;

public class AdminKnowledgeIngestionRepository {

    private static final String STATEMENT_TIMEOUT_SQL = "set local statement_timeout = '2000ms'";

    private final JdbcTemplate jdbcTemplate;

    public AdminKnowledgeIngestionRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<IngestionJobRow> listJobs(String status, int limit) {
        applyStatementTimeout();
        if (status == null) {
            return jdbcTemplate.query(
                    """
                    select id,
                           original_filename,
                           status,
                           total_chunks,
                           error_message,
                           created_at,
                           updated_at
                    from ingestion_jobs
                    order by updated_at desc, created_at desc, id desc
                    limit ?
                    """,
                    this::mapJob,
                    limit
            );
        }
        return jdbcTemplate.query(
                """
                select id,
                       original_filename,
                       status,
                       total_chunks,
                       error_message,
                       created_at,
                       updated_at
                from ingestion_jobs
                where status = ?
                order by updated_at desc, created_at desc, id desc
                limit ?
                """,
                this::mapJob,
                status,
                limit
        );
    }

    public Optional<IngestionJobRow> findJob(UUID jobId) {
        applyStatementTimeout();
        var rows = jdbcTemplate.query(
                """
                select id,
                       original_filename,
                       status,
                       total_chunks,
                       error_message,
                       created_at,
                       updated_at
                from ingestion_jobs
                where id = ?
                limit 1
                """,
                this::mapJob,
                jobId
        );
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    public QueueSummaryRow fetchQueueSummary() {
        applyStatementTimeout();
        return jdbcTemplate.queryForObject(
                """
                select coalesce(sum(case when status = 'PENDING' then 1 else 0 end), 0) as pending_count,
                       coalesce(sum(case when status = 'PROCESSING' then 1 else 0 end), 0) as processing_count,
                       coalesce(sum(case when status = 'FAILED' then 1 else 0 end), 0) as failed_count,
                       coalesce(sum(case when status = 'COMPLETED' then 1 else 0 end), 0) as completed_count,
                       max(updated_at) as last_updated_at
                from ingestion_jobs
                """,
                this::mapQueueSummary
        );
    }

    private IngestionJobRow mapJob(ResultSet resultSet, int rowNum) throws SQLException {
        return new IngestionJobRow(
                UUID.fromString(resultSet.getString("id")),
                resultSet.getString("original_filename"),
                resultSet.getString("status"),
                resultSet.getInt("total_chunks"),
                resultSet.getString("error_message"),
                mapInstant(resultSet.getTimestamp("created_at")),
                mapInstant(resultSet.getTimestamp("updated_at"))
        );
    }

    private QueueSummaryRow mapQueueSummary(ResultSet resultSet, int rowNum) throws SQLException {
        return new QueueSummaryRow(
                resultSet.getLong("pending_count"),
                resultSet.getLong("processing_count"),
                resultSet.getLong("failed_count"),
                resultSet.getLong("completed_count"),
                mapInstant(resultSet.getTimestamp("last_updated_at"))
        );
    }

    private Instant mapInstant(Timestamp timestamp) {
        return timestamp == null ? null : timestamp.toInstant();
    }

    private void applyStatementTimeout() {
        jdbcTemplate.execute(STATEMENT_TIMEOUT_SQL);
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
