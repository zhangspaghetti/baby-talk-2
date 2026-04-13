package com.zhangspaghetti.babytalk.service;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

@Repository
class MentorRepository {

    private final JdbcTemplate jdbcTemplate;

    MentorRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    int countRequestsSince(String installationId, Instant since) {
        return jdbcTemplate.queryForObject(
                """
                select count(*)
                from mentor_audit_logs
                where installation_id = ?
                  and event_type = 'chat_requested'
                  and created_at >= ?
                """,
                Integer.class,
                installationId,
                Timestamp.from(since)
        );
    }

    void insertTurn(TurnRow row) {
        jdbcTemplate.update(
                """
                insert into mentor_turns (
                    turn_id,
                    correlation_id,
                    installation_id,
                    session_id_hint,
                    account_id_hint,
                    surface,
                    mode,
                    result,
                    phase,
                    request_summary,
                    response_summary,
                    response_text,
                    provider_mode,
                    blocked_fallback,
                    retryable,
                    created_at
                ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                row.turnId(),
                row.correlationId(),
                row.installationId(),
                row.sessionIdHint(),
                row.accountIdHint(),
                row.surface(),
                row.mode(),
                row.result(),
                row.phase(),
                row.requestSummary(),
                row.responseSummary(),
                row.responseText(),
                row.providerMode(),
                row.blockedFallback(),
                row.retryable(),
                Timestamp.from(row.createdAt())
        );
    }

    void insertAudit(AuditRow row) {
        jdbcTemplate.update(
                """
                insert into mentor_audit_logs (
                    correlation_id,
                    installation_id,
                    session_id_hint,
                    account_id_hint,
                    event_type,
                    phase,
                    result,
                    request_summary,
                    response_summary,
                    reason,
                    failure_code,
                    retryable,
                    rate_limited,
                    created_at
                ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                row.correlationId(),
                row.installationId(),
                row.sessionIdHint(),
                row.accountIdHint(),
                row.eventType(),
                row.phase(),
                row.result(),
                row.requestSummary(),
                row.responseSummary(),
                row.reason(),
                row.failureCode(),
                row.retryable(),
                row.rateLimited(),
                Timestamp.from(row.createdAt())
        );
    }

    Optional<TurnRow> findTurnByCorrelationId(String correlationId) {
        return findOne(
                """
                select turn_id, correlation_id, installation_id, session_id_hint, account_id_hint, surface, mode,
                       result, phase, request_summary, response_summary, response_text, provider_mode,
                       blocked_fallback, retryable, created_at
                from mentor_turns
                where correlation_id = ?
                """,
                this::mapTurnRow,
                correlationId
        );
    }

    List<AuditRow> listAuditRowsByCorrelationId(String correlationId) {
        return jdbcTemplate.query(
                """
                select correlation_id, installation_id, session_id_hint, account_id_hint, event_type, phase, result,
                       request_summary, response_summary, reason, failure_code, retryable, rate_limited, created_at
                from mentor_audit_logs
                where correlation_id = ?
                order by audit_id asc
                """,
                (rs, rowNum) -> mapAuditRow(rs),
                correlationId
        );
    }

    int countTurns() {
        return jdbcTemplate.queryForObject("select count(*) from mentor_turns", Integer.class);
    }

    int countAuditRows() {
        return jdbcTemplate.queryForObject("select count(*) from mentor_audit_logs", Integer.class);
    }

    private <T> Optional<T> findOne(String sql, RowMapper<T> mapper, Object... args) {
        try {
            return Optional.ofNullable(jdbcTemplate.queryForObject(sql, mapper, args));
        } catch (EmptyResultDataAccessException exception) {
            return Optional.empty();
        }
    }

    private TurnRow mapTurnRow(ResultSet rs, int rowNum) throws SQLException {
        return new TurnRow(
                rs.getString("turn_id"),
                rs.getString("correlation_id"),
                rs.getString("installation_id"),
                rs.getString("session_id_hint"),
                rs.getString("account_id_hint"),
                rs.getString("surface"),
                rs.getString("mode"),
                rs.getString("result"),
                rs.getString("phase"),
                rs.getString("request_summary"),
                rs.getString("response_summary"),
                rs.getString("response_text"),
                rs.getString("provider_mode"),
                rs.getBoolean("blocked_fallback"),
                rs.getBoolean("retryable"),
                rs.getTimestamp("created_at").toInstant()
        );
    }

    private AuditRow mapAuditRow(ResultSet rs) throws SQLException {
        return new AuditRow(
                rs.getString("correlation_id"),
                rs.getString("installation_id"),
                rs.getString("session_id_hint"),
                rs.getString("account_id_hint"),
                rs.getString("event_type"),
                rs.getString("phase"),
                rs.getString("result"),
                rs.getString("request_summary"),
                rs.getString("response_summary"),
                rs.getString("reason"),
                rs.getString("failure_code"),
                rs.getBoolean("retryable"),
                rs.getBoolean("rate_limited"),
                rs.getTimestamp("created_at").toInstant()
        );
    }

    record TurnRow(
            String turnId,
            String correlationId,
            String installationId,
            String sessionIdHint,
            String accountIdHint,
            String surface,
            String mode,
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

    record AuditRow(
            String correlationId,
            String installationId,
            String sessionIdHint,
            String accountIdHint,
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
}
