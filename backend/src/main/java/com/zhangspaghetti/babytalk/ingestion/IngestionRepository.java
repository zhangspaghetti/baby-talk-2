package com.zhangspaghetti.babytalk.ingestion;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

/**
 * ingestion_jobs 表 CRUD — 使用 JdbcTemplate 直接操作。
 *
 * <p>提供 insert / updateStatus / updateCompleted / updateFailed / findById / findAll 方法。
 */
@Repository
public class IngestionRepository {

    private final JdbcTemplate jdbc;

    public IngestionRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private static final RowMapper<IngestionJob> ROW_MAPPER = (rs, rowNum) -> mapRow(rs);

    private static IngestionJob mapRow(ResultSet rs) throws SQLException {
        return new IngestionJob(
                UUID.fromString(rs.getString("id")),
                rs.getString("original_filename"),
                rs.getString("minio_object_key"),
                rs.getString("status"),
                rs.getInt("total_chunks"),
                rs.getString("error_message"),
                rs.getTimestamp("created_at").toInstant(),
                rs.getTimestamp("updated_at").toInstant()
        );
    }

    /** 插入新 job（PENDING 状态） */
    public void insert(IngestionJob job) {
        jdbc.update("""
                INSERT INTO ingestion_jobs (id, original_filename, minio_object_key, status,
                                            total_chunks, error_message, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                job.id(),
                job.originalFilename(),
                job.minioObjectKey(),
                job.status(),
                job.totalChunks(),
                job.errorMessage(),
                Timestamp.from(job.createdAt()),
                Timestamp.from(job.updatedAt())
        );
    }

    /** 更新状态为 PROCESSING */
    public void updateStatusProcessing(UUID jobId) {
        jdbc.update("""
                UPDATE ingestion_jobs
                SET status = ?, updated_at = ?
                WHERE id = ?
                """,
                IngestionJob.STATUS_PROCESSING,
                Timestamp.from(Instant.now()),
                jobId
        );
    }

    /** 标记完成 — 设置 COMPLETED + chunk 数量 */
    public void updateCompleted(UUID jobId, int totalChunks) {
        jdbc.update("""
                UPDATE ingestion_jobs
                SET status = ?, total_chunks = ?, updated_at = ?
                WHERE id = ?
                """,
                IngestionJob.STATUS_COMPLETED,
                totalChunks,
                Timestamp.from(Instant.now()),
                jobId
        );
    }

    /** 标记失败 — 设置 FAILED + 错误信息 */
    public void updateFailed(UUID jobId, String errorMessage) {
        jdbc.update("""
                UPDATE ingestion_jobs
                SET status = ?, error_message = ?, updated_at = ?
                WHERE id = ?
                """,
                IngestionJob.STATUS_FAILED,
                errorMessage != null ? errorMessage.substring(0, Math.min(errorMessage.length(), 2000)) : null,
                Timestamp.from(Instant.now()),
                jobId
        );
    }

    /** 按 ID 查询 */
    public Optional<IngestionJob> findById(UUID jobId) {
        List<IngestionJob> results = jdbc.query(
                "SELECT * FROM ingestion_jobs WHERE id = ?",
                ROW_MAPPER,
                jobId
        );
        return results.stream().findFirst();
    }

    /** 查询所有 job，按创建时间倒序 */
    public List<IngestionJob> findAll() {
        return jdbc.query(
                "SELECT * FROM ingestion_jobs ORDER BY created_at DESC",
                ROW_MAPPER
        );
    }

    /** 重置状态为 PENDING（用于重试） */
    public void updateStatusPending(UUID jobId) {
        jdbc.update("""
                UPDATE ingestion_jobs
                SET status = ?, error_message = NULL, total_chunks = 0, updated_at = ?
                WHERE id = ?
                """,
                IngestionJob.STATUS_PENDING,
                Timestamp.from(Instant.now()),
                jobId
        );
    }

    /** 按状态查询 */
    public List<IngestionJob> findByStatus(String status) {
        return jdbc.query(
                "SELECT * FROM ingestion_jobs WHERE status = ? ORDER BY created_at DESC",
                ROW_MAPPER,
                status
        );
    }
}
