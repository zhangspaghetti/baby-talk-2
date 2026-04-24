package com.zhangspaghetti.babytalk.admin.users;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

public class AdminUserReadRepository {

    private final JdbcTemplate jdbcTemplate;

    public AdminUserReadRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public UserPage listUsers(UserListQuery query) {
        var whereClause = new StringBuilder();
        var whereArgs = new ArrayList<Object>();
        appendListFilters(query, whereClause, whereArgs);

        var total = jdbcTemplate.queryForObject(
                "select count(*) from accounts" + whereClause,
                Integer.class,
                whereArgs.toArray()
        );

        var listArgs = new ArrayList<>(whereArgs);
        listArgs.add(query.limit());
        listArgs.add(query.offset());
        var items = jdbcTemplate.query(
                """
                select account_id, phone_number, status, latest_consent_status, created_at, deleted_at
                from accounts
                """ + whereClause + """
                order by account_id asc
                limit ? offset ?
                """,
                this::mapUser,
                listArgs.toArray()
        );
        return new UserPage(items, total == null ? 0 : total);
    }

    public Optional<UserDetailRow> findUserDetail(String accountId, int sessionLimit, int auditLimit) {
        return findAccount(accountId)
                .map(account -> new UserDetailRow(
                        account,
                        listRecentSessions(accountId, sessionLimit),
                        listRecentConsentAudit(accountId, auditLimit)
                ));
    }

    public Optional<AdminUserRow> findAccount(String accountId) {
        return findOne(
                """
                select account_id, phone_number, status, latest_consent_status, created_at, deleted_at
                from accounts
                where account_id = ?
                """,
                this::mapUser,
                accountId
        );
    }

    public Optional<AdminUserRow> lockAccount(String accountId) {
        return findOne(
                """
                select account_id, phone_number, status, latest_consent_status, created_at, deleted_at
                from accounts
                where account_id = ?
                for update
                """,
                this::mapUser,
                accountId
        );
    }

    public Optional<AuditContextRow> findLatestAuditContext(String accountId) {
        return findOne(
                """
                select session_id, installation_id
                from account_sessions
                where account_id = ?
                order by created_at desc, session_id desc
                limit 1
                """,
                this::mapAuditContext,
                accountId
        );
    }

    public List<UserSessionRow> listRecentSessions(String accountId, int limit) {
        return jdbcTemplate.query(
                """
                select session_id, installation_id, status, created_at, revoked_at
                from account_sessions
                where account_id = ?
                order by created_at desc, session_id desc
                limit ?
                """,
                this::mapSession,
                accountId,
                limit
        );
    }

    public List<UserConsentAuditRow> listRecentConsentAudit(String accountId, int limit) {
        return jdbcTemplate.query(
                """
                select audit_id, session_id, installation_id, action, result, reason, created_at
                from consent_audit_logs
                where account_id = ?
                order by created_at desc, audit_id desc
                limit ?
                """,
                this::mapConsentAudit,
                accountId,
                limit
        );
    }

    public int deleteInteractionEvents(String accountId) {
        return jdbcTemplate.update("delete from interaction_events where account_id = ?", accountId);
    }

    public int updateSessionsStatus(String accountId, String newStatus, Instant changedAt) {
        return jdbcTemplate.update(
                "update account_sessions set status = ?, revoked_at = ? where account_id = ? and status <> ?",
                newStatus,
                Timestamp.from(changedAt),
                accountId,
                newStatus
        );
    }

    public int tombstoneAccount(String accountId, String tombstonePhone, Instant deletedAt) {
        return jdbcTemplate.update(
                """
                update accounts
                set status = 'deleted',
                    phone_number = ?,
                    latest_consent_status = 'deleted',
                    deleted_at = ?
                where account_id = ?
                """,
                tombstonePhone,
                Timestamp.from(deletedAt),
                accountId
        );
    }

    public void insertConsentAudit(AuditWriteRow auditRow) {
        jdbcTemplate.update(
                """
                insert into consent_audit_logs (
                    account_id,
                    session_id,
                    installation_id,
                    action,
                    result,
                    reason,
                    created_at
                ) values (?, ?, ?, ?, ?, ?, ?)
                """,
                auditRow.accountId(),
                auditRow.sessionId(),
                auditRow.installationId(),
                auditRow.action(),
                auditRow.result(),
                auditRow.reason(),
                Timestamp.from(auditRow.createdAt())
        );
    }

    private void appendListFilters(UserListQuery query, StringBuilder whereClause, List<Object> whereArgs) {
        var predicates = new ArrayList<String>();
        if (query.status() != null) {
            predicates.add("status = ?");
            whereArgs.add(query.status());
        }
        if (query.query() != null) {
            predicates.add("(account_id like ? or phone_number like ?)");
            var prefixQuery = query.query() + "%";
            whereArgs.add(prefixQuery);
            whereArgs.add(prefixQuery);
        }
        if (!predicates.isEmpty()) {
            whereClause.append(" where ").append(String.join(" and ", predicates));
        }
    }

    private <T> Optional<T> findOne(String sql, RowMapper<T> mapper, Object... args) {
        try {
            return Optional.ofNullable(jdbcTemplate.queryForObject(sql, mapper, args));
        } catch (EmptyResultDataAccessException exception) {
            return Optional.empty();
        }
    }

    private AdminUserRow mapUser(ResultSet resultSet, int rowNum) throws SQLException {
        return new AdminUserRow(
                resultSet.getString("account_id"),
                resultSet.getString("phone_number"),
                resultSet.getString("status"),
                resultSet.getString("latest_consent_status"),
                mapInstant(resultSet.getTimestamp("created_at")),
                mapInstant(resultSet.getTimestamp("deleted_at"))
        );
    }

    private AuditContextRow mapAuditContext(ResultSet resultSet, int rowNum) throws SQLException {
        return new AuditContextRow(
                resultSet.getString("session_id"),
                resultSet.getString("installation_id")
        );
    }

    private UserSessionRow mapSession(ResultSet resultSet, int rowNum) throws SQLException {
        return new UserSessionRow(
                resultSet.getString("session_id"),
                resultSet.getString("installation_id"),
                resultSet.getString("status"),
                mapInstant(resultSet.getTimestamp("created_at")),
                mapInstant(resultSet.getTimestamp("revoked_at"))
        );
    }

    private UserConsentAuditRow mapConsentAudit(ResultSet resultSet, int rowNum) throws SQLException {
        return new UserConsentAuditRow(
                resultSet.getLong("audit_id"),
                resultSet.getString("session_id"),
                resultSet.getString("installation_id"),
                resultSet.getString("action"),
                resultSet.getString("result"),
                resultSet.getString("reason"),
                mapInstant(resultSet.getTimestamp("created_at"))
        );
    }

    private Instant mapInstant(Timestamp timestamp) {
        return timestamp == null ? null : timestamp.toInstant();
    }

    public record UserListQuery(
            String status,
            String query,
            int limit,
            int offset
    ) {
    }

    public record UserPage(List<AdminUserRow> items, int total) {
    }

    public record UserDetailRow(
            AdminUserRow account,
            List<UserSessionRow> recentSessions,
            List<UserConsentAuditRow> recentConsentAudit
    ) {
    }

    public record AdminUserRow(
            String accountId,
            String phoneNumber,
            String status,
            String latestConsentStatus,
            Instant createdAt,
            Instant deletedAt
    ) {
    }

    public record UserSessionRow(
            String sessionId,
            String installationId,
            String status,
            Instant createdAt,
            Instant revokedAt
    ) {
    }

    public record UserConsentAuditRow(
            long auditId,
            String sessionId,
            String installationId,
            String action,
            String result,
            String reason,
            Instant createdAt
    ) {
    }

    public record AuditContextRow(String sessionId, String installationId) {
    }

    public record AuditWriteRow(
            String accountId,
            String sessionId,
            String installationId,
            String action,
            String result,
            String reason,
            Instant createdAt
    ) {
    }
}
