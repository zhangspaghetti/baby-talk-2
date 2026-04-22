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
 * kg_admin_notifications 表 CRUD — 使用 JdbcTemplate 直接操作。
 */
@Repository
public class KgAdminNotificationRepository {

    private final JdbcTemplate jdbc;

    public KgAdminNotificationRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private static final RowMapper<KgAdminNotification> ROW_MAPPER = (rs, rowNum) -> mapRow(rs);

    private static KgAdminNotification mapRow(ResultSet rs) throws SQLException {
        return new KgAdminNotification(
                UUID.fromString(rs.getString("id")),
                UUID.fromString(rs.getString("contradiction_id")),
                rs.getString("notification_type"),
                rs.getString("message"),
                rs.getBoolean("is_read"),
                rs.getTimestamp("created_at").toInstant()
        );
    }

    /** 插入新通知 */
    public void insert(KgAdminNotification notification) {
        jdbc.update("""
                INSERT INTO kg_admin_notifications (id, contradiction_id, notification_type,
                                                     message, is_read, created_at)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                notification.id(),
                notification.contradictionId(),
                notification.notificationType(),
                notification.message(),
                notification.isRead(),
                Timestamp.from(notification.createdAt())
        );
    }

    /** 查询所有未读通知 */
    public List<KgAdminNotification> findUnread() {
        return jdbc.query(
                "SELECT * FROM kg_admin_notifications WHERE is_read = FALSE ORDER BY created_at DESC",
                ROW_MAPPER
        );
    }

    /** 标记为已读 */
    public void markRead(UUID id) {
        jdbc.update(
                "UPDATE kg_admin_notifications SET is_read = TRUE WHERE id = ?",
                id
        );
    }

    /** 查询所有通知 */
    public List<KgAdminNotification> findAll() {
        return jdbc.query(
                "SELECT * FROM kg_admin_notifications ORDER BY created_at DESC",
                ROW_MAPPER
        );
    }

    /** 按 ID 查询 */
    public Optional<KgAdminNotification> findById(UUID id) {
        List<KgAdminNotification> results = jdbc.query(
                "SELECT * FROM kg_admin_notifications WHERE id = ?",
                ROW_MAPPER, id
        );
        return results.stream().findFirst();
    }

    /** 按矛盾 ID 查询通知 */
    public List<KgAdminNotification> findByContradictionId(UUID contradictionId) {
        return jdbc.query(
                "SELECT * FROM kg_admin_notifications WHERE contradiction_id = ? ORDER BY created_at DESC",
                ROW_MAPPER, contradictionId
        );
    }
}
