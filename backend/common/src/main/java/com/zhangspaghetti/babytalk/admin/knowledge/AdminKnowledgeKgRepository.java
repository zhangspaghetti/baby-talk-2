package com.zhangspaghetti.babytalk.admin.knowledge;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;

public class AdminKnowledgeKgRepository {

    private static final String STATEMENT_TIMEOUT_SQL = "set local statement_timeout = '2000ms'";

    private final JdbcTemplate jdbcTemplate;

    public AdminKnowledgeKgRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<ContradictionRow> listContradictions(String status, int limit) {
        applyStatementTimeout();
        if (status == null) {
            return jdbcTemplate.query(
                    contradictionSelect() + """
                            order by c.detected_at desc, c.id desc
                            limit ?
                            """,
                    this::mapContradiction,
                    limit
            );
        }
        return jdbcTemplate.query(
                contradictionSelect() + """
                        where c.status = ?
                        order by c.detected_at desc, c.id desc
                        limit ?
                        """,
                this::mapContradiction,
                status,
                limit
        );
    }

    public Optional<ContradictionRow> findContradiction(UUID contradictionId) {
        applyStatementTimeout();
        var rows = jdbcTemplate.query(
                contradictionSelect() + """
                        where c.id = ?
                        limit 1
                        """,
                this::mapContradiction,
                contradictionId
        );
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    public Optional<ContradictionRow> findContradictionForUpdate(UUID contradictionId) {
        applyStatementTimeout();
        var rows = jdbcTemplate.query(
                contradictionSelect() + """
                        where c.id = ?
                        limit 1
                        for update
                        """,
                this::mapContradiction,
                contradictionId
        );
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    public void resolveContradiction(UUID contradictionId, String adminNotes, Instant resolvedAt) {
        applyStatementTimeout();
        jdbcTemplate.update(
                """
                update kg_contradictions
                set status = 'resolved',
                    admin_notes = ?,
                    reviewed_at = coalesce(reviewed_at, ?),
                    resolved_at = ?
                where id = ?
                """,
                adminNotes,
                Timestamp.from(resolvedAt),
                Timestamp.from(resolvedAt),
                contradictionId
        );
    }

    public List<NotificationRow> listNotifications(UUID contradictionId, int limit) {
        applyStatementTimeout();
        return jdbcTemplate.query(
                """
                select id,
                       contradiction_id,
                       notification_type,
                       message,
                       is_read,
                       created_at
                from kg_admin_notifications
                where contradiction_id = ?
                order by created_at desc, id desc
                limit ?
                """,
                this::mapNotification,
                contradictionId,
                limit
        );
    }

    public Optional<NotificationRow> findNotification(UUID notificationId) {
        applyStatementTimeout();
        var rows = jdbcTemplate.query(
                """
                select id,
                       contradiction_id,
                       notification_type,
                       message,
                       is_read,
                       created_at
                from kg_admin_notifications
                where id = ?
                limit 1
                """,
                this::mapNotification,
                notificationId
        );
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    public Optional<NotificationRow> findNotificationForUpdate(UUID notificationId) {
        applyStatementTimeout();
        var rows = jdbcTemplate.query(
                """
                select id,
                       contradiction_id,
                       notification_type,
                       message,
                       is_read,
                       created_at
                from kg_admin_notifications
                where id = ?
                limit 1
                for update
                """,
                this::mapNotification,
                notificationId
        );
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    public void markNotificationRead(UUID notificationId) {
        applyStatementTimeout();
        jdbcTemplate.update(
                """
                update kg_admin_notifications
                set is_read = true
                where id = ?
                """,
                notificationId
        );
    }

    private String contradictionSelect() {
        return """
                select c.id,
                       c.entity_topic,
                       c.source_a_book,
                       c.source_b_book,
                       c.description,
                       c.status,
                       c.agent_review_result,
                       c.admin_notes,
                       c.detected_at,
                       c.reviewed_at,
                       c.resolved_at,
                       (select count(*) from kg_admin_notifications n where n.contradiction_id = c.id) as notification_count,
                       (select count(*) from kg_admin_notifications n where n.contradiction_id = c.id and n.is_read = false) as unread_notification_count
                from kg_contradictions c
                """;
    }

    private ContradictionRow mapContradiction(ResultSet resultSet, int rowNum) throws SQLException {
        return new ContradictionRow(
                UUID.fromString(resultSet.getString("id")),
                resultSet.getString("entity_topic"),
                resultSet.getString("source_a_book"),
                resultSet.getString("source_b_book"),
                resultSet.getString("description"),
                resultSet.getString("status"),
                resultSet.getString("agent_review_result"),
                resultSet.getString("admin_notes"),
                mapInstant(resultSet.getTimestamp("detected_at")),
                mapInstant(resultSet.getTimestamp("reviewed_at")),
                mapInstant(resultSet.getTimestamp("resolved_at")),
                resultSet.getLong("notification_count"),
                resultSet.getLong("unread_notification_count")
        );
    }

    private NotificationRow mapNotification(ResultSet resultSet, int rowNum) throws SQLException {
        return new NotificationRow(
                UUID.fromString(resultSet.getString("id")),
                UUID.fromString(resultSet.getString("contradiction_id")),
                resultSet.getString("notification_type"),
                resultSet.getString("message"),
                resultSet.getBoolean("is_read"),
                mapInstant(resultSet.getTimestamp("created_at"))
        );
    }

    private Instant mapInstant(Timestamp timestamp) {
        return timestamp == null ? null : timestamp.toInstant();
    }

    private void applyStatementTimeout() {
        jdbcTemplate.execute(STATEMENT_TIMEOUT_SQL);
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
}
