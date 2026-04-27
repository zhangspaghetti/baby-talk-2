package com.zhangspaghetti.babytalk.admin.knowledge;

import com.zhangspaghetti.babytalk.admin.auth.AdminApiContractException;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AdminPalaceRagService {

    private static final Logger log = LoggerFactory.getLogger(AdminPalaceRagService.class);

    private static final String BRIDGE_EDGE_SELECT = """
            SELECT e.id,
                   e.confidence,
                   e.status,
                   e.source_book_a,
                   e.source_book_b,
                   e.created_at,
                   e.reviewed_by,
                   e.reviewed_at,
                   ra.wing AS room_a_wing,
                   ra.room AS room_a_name,
                   rb.wing AS room_b_wing,
                   rb.room AS room_b_name
            FROM palace_bridge_edges e
            JOIN palace_rooms ra ON ra.id = e.room_a_id
            JOIN palace_rooms rb ON rb.id = e.room_b_id
            """;

    private final JdbcTemplate jdbcTemplate;

    public AdminPalaceRagService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Transactional(readOnly = true)
    public PalaceProjectionStatusView getProjectionStatus() {
        return jdbcTemplate.query(
                        """
                                SELECT version_num, room_count, last_ingestion_batch_id, status, created_at
                                FROM palace_projection_version
                                WHERE status = 'current'
                                ORDER BY version_num DESC
                                LIMIT 1
                                """,
                        (rs, rowNum) -> new PalaceProjectionStatusView(
                                false,
                                getNullableLong(rs, "version_num"),
                                getNullableLong(rs, "room_count"),
                                uuidString(rs, "last_ingestion_batch_id"),
                                rs.getString("status"),
                                timestampString(rs, "created_at")
                        ))
                .stream()
                .findFirst()
                .orElse(new PalaceProjectionStatusView(true, null, null, null, null, null));
    }

    @Transactional(readOnly = true)
    public List<PalaceBridgeEdgeView> listBridgeEdges(String status, int limit) {
        var normalizedStatus = normalizeBridgeStatus(status);
        if (normalizedStatus == null) {
            return jdbcTemplate.query(
                    BRIDGE_EDGE_SELECT + """
                            ORDER BY e.created_at DESC
                            LIMIT ?
                            """,
                    bridgeEdgeRowMapper(),
                    limit
            );
        }
        return jdbcTemplate.query(
                BRIDGE_EDGE_SELECT + """
                        WHERE e.status = ?
                        ORDER BY e.created_at DESC
                        LIMIT ?
                        """,
                bridgeEdgeRowMapper(),
                normalizedStatus,
                limit
        );
    }

    @Transactional(readOnly = true)
    public PalaceBridgeEdgeView getBridgeEdge(UUID id) {
        return jdbcTemplate.query(
                        BRIDGE_EDGE_SELECT + """
                                WHERE e.id = ?
                                LIMIT 1
                                """,
                        bridgeEdgeRowMapper(),
                        id)
                .stream()
                .findFirst()
                .orElseThrow(() -> bridgeEdgeNotFound(id));
    }

    @Transactional
    public PalaceBridgeEdgeView approveBridgeEdge(UUID id, String reviewedBy) {
        return updateBridgeEdgeStatus(id, "approved", reviewedBy);
    }

    @Transactional
    public PalaceBridgeEdgeView rejectBridgeEdge(UUID id, String reviewedBy) {
        return updateBridgeEdgeStatus(id, "rejected", reviewedBy);
    }

    @Transactional(readOnly = true)
    public List<PalaceQueryTraceSampleView> listTraceSamples(int limit) {
        return jdbcTemplate.query(
                """
                        SELECT id,
                               entry_rooms,
                               temporal_rule_applied,
                               candidates_json,
                               bridge_edges_crossed,
                               projection_version_used,
                               queried_at
                        FROM palace_query_traces
                        ORDER BY queried_at DESC
                        LIMIT ?
                        """,
                (rs, rowNum) -> new PalaceQueryTraceSampleView(
                        uuidString(rs, "id"),
                        rs.getString("entry_rooms"),
                        rs.getString("temporal_rule_applied"),
                        rs.getString("candidates_json"),
                        rs.getString("bridge_edges_crossed"),
                        getNullableLong(rs, "projection_version_used"),
                        timestampString(rs, "queried_at")
                ),
                limit
        );
    }

    private PalaceBridgeEdgeView updateBridgeEdgeStatus(UUID id, String status, String reviewedBy) {
        int updatedRows = jdbcTemplate.update(
                """
                        UPDATE palace_bridge_edges
                        SET status = ?, reviewed_by = ?, reviewed_at = now()
                        WHERE id = ?
                        """,
                status,
                reviewedBy,
                id
        );
        if (updatedRows != 1) {
            throw bridgeEdgeNotFound(id);
        }
        return getBridgeEdge(id);
    }

    private String normalizeBridgeStatus(String status) {
        if (status == null || status.isBlank()) {
            return null;
        }
        return status.trim().toLowerCase(Locale.ROOT);
    }

    private RowMapper<PalaceBridgeEdgeView> bridgeEdgeRowMapper() {
        return (rs, rowNum) -> new PalaceBridgeEdgeView(
                uuidString(rs, "id"),
                rs.getDouble("confidence"),
                rs.getString("status"),
                rs.getString("source_book_a"),
                rs.getString("source_book_b"),
                timestampString(rs, "created_at"),
                rs.getString("reviewed_by"),
                timestampString(rs, "reviewed_at"),
                rs.getString("room_a_wing"),
                rs.getString("room_a_name"),
                rs.getString("room_b_wing"),
                rs.getString("room_b_name")
        );
    }

    private AdminApiContractException bridgeEdgeNotFound(UUID id) {
        log.warn("palace bridge edge not found. edgeId={}", id);
        return new AdminApiContractException(
                HttpStatus.NOT_FOUND,
                "palace_bridge_edge_not_found",
                "未找到对应的 palace bridge edge。",
                Map.of("edgeId", id.toString())
        );
    }

    private static Long getNullableLong(ResultSet rs, String columnName) throws SQLException {
        long value = rs.getLong(columnName);
        return rs.wasNull() ? null : value;
    }

    private static String uuidString(ResultSet rs, String columnName) throws SQLException {
        Object value = rs.getObject(columnName);
        return value == null ? null : value.toString();
    }

    private static String timestampString(ResultSet rs, String columnName) throws SQLException {
        OffsetDateTime value = rs.getObject(columnName, OffsetDateTime.class);
        return value == null ? null : value.toInstant().toString();
    }

    public record PalaceProjectionStatusView(
            boolean notReady,
            Long versionNum,
            Long roomCount,
            String lastIngestionBatchId,
            String status,
            String createdAt
    ) {
    }

    public record PalaceBridgeEdgeView(
            String id,
            double confidence,
            String status,
            String sourceBookA,
            String sourceBookB,
            String createdAt,
            String reviewedBy,
            String reviewedAt,
            String roomAWing,
            String roomAName,
            String roomBWing,
            String roomBName
    ) {
    }

    public record PalaceQueryTraceSampleView(
            String id,
            String entryRooms,
            String temporalRuleApplied,
            String candidatesJson,
            String bridgeEdgesCrossed,
            Long projectionVersionUsed,
            String queriedAt
    ) {
    }
}
