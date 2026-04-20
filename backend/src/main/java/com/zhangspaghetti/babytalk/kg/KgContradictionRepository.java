package com.zhangspaghetti.babytalk.kg;

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
 * kg_contradictions 表 CRUD — 使用 JdbcTemplate 直接操作。
 */
@Repository
public class KgContradictionRepository {

    private final JdbcTemplate jdbc;

    public KgContradictionRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private static final RowMapper<KgContradiction> ROW_MAPPER = (rs, rowNum) -> mapRow(rs);

    private static KgContradiction mapRow(ResultSet rs) throws SQLException {
        Timestamp reviewedAt = rs.getTimestamp("reviewed_at");
        Timestamp resolvedAt = rs.getTimestamp("resolved_at");
        return new KgContradiction(
                UUID.fromString(rs.getString("id")),
                rs.getString("entity_topic"),
                UUID.fromString(rs.getString("relationship_a_id")),
                UUID.fromString(rs.getString("relationship_b_id")),
                rs.getString("source_a_book"),
                rs.getString("source_b_book"),
                rs.getString("description"),
                rs.getString("status"),
                rs.getString("agent_review_result"),
                rs.getString("admin_notes"),
                rs.getTimestamp("detected_at").toInstant(),
                reviewedAt != null ? reviewedAt.toInstant() : null,
                resolvedAt != null ? resolvedAt.toInstant() : null
        );
    }

    /** 插入新矛盾记录 */
    public void insert(KgContradiction contradiction) {
        jdbc.update("""
                INSERT INTO kg_contradictions (id, entity_topic, relationship_a_id, relationship_b_id,
                                                source_a_book, source_b_book, description, status,
                                                agent_review_result, admin_notes,
                                                detected_at, reviewed_at, resolved_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                contradiction.id(),
                contradiction.entityTopic(),
                contradiction.relationshipAId(),
                contradiction.relationshipBId(),
                contradiction.sourceABook(),
                contradiction.sourceBBook(),
                contradiction.description(),
                contradiction.status(),
                contradiction.agentReviewResult(),
                contradiction.adminNotes(),
                Timestamp.from(contradiction.detectedAt()),
                contradiction.reviewedAt() != null ? Timestamp.from(contradiction.reviewedAt()) : null,
                contradiction.resolvedAt() != null ? Timestamp.from(contradiction.resolvedAt()) : null
        );
    }

    /** 按 ID 查询 */
    public Optional<KgContradiction> findById(UUID id) {
        List<KgContradiction> results = jdbc.query(
                "SELECT * FROM kg_contradictions WHERE id = ?",
                ROW_MAPPER, id
        );
        return results.stream().findFirst();
    }

    /** 按状态查询 */
    public List<KgContradiction> findByStatus(String status) {
        return jdbc.query(
                "SELECT * FROM kg_contradictions WHERE status = ? ORDER BY detected_at DESC",
                ROW_MAPPER, status
        );
    }

    /** 更新状态和 agent 审查结果 */
    public void updateStatus(UUID id, String status, String agentReviewResult) {
        jdbc.update("""
                UPDATE kg_contradictions
                SET status = ?, agent_review_result = ?, reviewed_at = ?
                WHERE id = ?
                """,
                status, agentReviewResult,
                Timestamp.from(Instant.now()),
                id
        );
    }

    /** 标记为已解决 */
    public void updateResolved(UUID id, String adminNotes) {
        jdbc.update("""
                UPDATE kg_contradictions
                SET status = ?, admin_notes = ?, resolved_at = ?
                WHERE id = ?
                """,
                KgContradiction.STATUS_RESOLVED,
                adminNotes,
                Timestamp.from(Instant.now()),
                id
        );
    }

    /** 查找待审查的矛盾（detected 状态，按时间排序，限制批次大小） */
    public List<KgContradiction> findPendingReview(int batchSize) {
        return jdbc.query(
                "SELECT * FROM kg_contradictions WHERE status = ? ORDER BY detected_at LIMIT ?",
                ROW_MAPPER,
                KgContradiction.STATUS_DETECTED,
                batchSize
        );
    }
}
