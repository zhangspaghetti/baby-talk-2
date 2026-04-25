package com.zhangspaghetti.babytalk.admin.mentor;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;

public class AdminMentorAuditReadRepository {

    private static final String STATEMENT_TIMEOUT_SQL = "set local statement_timeout = '2000ms'";

    private static final String FLAG_CODE_SQL = """
            case
                when latest.phase = 'blocked_fallback' or latest.failure_code = 'blocked_fallback' then 'blocked_fallback'
                when latest.rate_limited = true
                    or history.historical_rate_limited = true
                    or latest.failure_code = 'mentor_rate_limited'
                    or latest.phase = 'rate_limited' then 'rate_limited'
                when latest.failure_code = 'provider_timeout' or latest.phase = 'provider_timeout' then 'provider_timeout'
                when latest.failure_code = 'provider_malformed_response' or latest.phase = 'provider_malformed_response' then 'provider_malformed_response'
                when latest.failure_code = 'provider_unavailable' or latest.phase = 'provider_unavailable' then 'provider_unavailable'
                when latest.failure_code = 'invalid_session' or latest.phase = 'invalid_session' then 'invalid_session'
                when latest.failure_code = 'consent_revoked' or latest.phase = 'consent_revoked' then 'consent_revoked'
                when latest.failure_code = 'account_deleted' or latest.phase = 'account_deleted' then 'account_deleted'
                when latest.failure_code = 'session_installation_mismatch' or latest.phase = 'session_installation_mismatch' then 'session_installation_mismatch'
                else 'other_incident'
            end
            """;

    private final JdbcTemplate jdbcTemplate;

    public AdminMentorAuditReadRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public List<QueueIncidentRow> listFlaggedIncidents(String installationId, String flagCode, int limit) {
        var args = new ArrayList<Object>();
        var sql = new StringBuilder(baseIncidentCtes())
                .append("""
                        select correlation_id,
                               installation_id,
                               flag_code,
                               latest_phase,
                               failure_code,
                               retryable,
                               historical_rate_limited,
                               occurred_at
                        from incidents
                        where 1 = 1
                        """);
        if (installationId != null) {
            sql.append(" and installation_id = ?");
            args.add(installationId);
        }
        if (flagCode != null) {
            sql.append(" and flag_code = ?");
            args.add(flagCode);
        }
        sql.append(" order by occurred_at desc limit ?");
        args.add(limit);
        return jdbcTemplate.query(sql.toString(), this::mapQueueIncident, args.toArray());
    }

    public Optional<IncidentSnapshotRow> findIncidentSnapshot(String correlationId) {
        var rows = jdbcTemplate.query(
                baseIncidentCtes() + """
                        select correlation_id,
                               installation_id,
                               flag_code,
                               latest_phase,
                               failure_code,
                               retryable,
                               historical_rate_limited,
                               occurred_at
                        from incidents
                        where correlation_id = ?
                        """,
                this::mapIncidentSnapshot,
                correlationId
        );
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    public List<TimelineRow> listTimeline(String correlationId) {
        return jdbcTemplate.query(
                """
                select audit_id,
                       correlation_id,
                       installation_id,
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
                from mentor_audit_logs
                where correlation_id = ?
                order by audit_id asc
                """,
                this::mapTimeline,
                correlationId
        );
    }

    public Optional<DeliveredTurnRow> findDeliveredTurn(String correlationId) {
        var rows = jdbcTemplate.query(
                """
                select correlation_id,
                       installation_id,
                       result,
                       phase,
                       request_summary,
                       response_summary,
                       response_text,
                       provider_mode,
                       blocked_fallback,
                       retryable,
                       created_at
                from mentor_turns
                where correlation_id = ?
                order by created_at desc
                limit 1
                """,
                this::mapDeliveredTurn,
                correlationId
        );
        return rows.isEmpty() ? Optional.empty() : Optional.of(rows.get(0));
    }

    public int countCurrentWindowRequests(String installationId, Instant windowStart) {
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
                Timestamp.from(windowStart)
        );
    }

    public OverviewSummaryRow fetchOverviewSummary() {
        applyStatementTimeout();
        return jdbcTemplate.queryForObject(
                baseIncidentCtes() + """
                        select count(*) as flagged_incident_count,
                               coalesce(sum(case when flag_code = 'blocked_fallback' then 1 else 0 end), 0) as blocked_fallback_count,
                               coalesce(sum(case when flag_code = 'rate_limited' then 1 else 0 end), 0) as rate_limited_count,
                               coalesce(sum(case when retryable = true then 1 else 0 end), 0) as retryable_count,
                               max(occurred_at) as last_occurred_at
                        from incidents
                        """,
                this::mapOverviewSummary
        );
    }

    private String baseIncidentCtes() {
        return """
                with history as (
                    select correlation_id,
                           max(installation_id) as installation_id,
                           bool_or(rate_limited) as historical_rate_limited
                    from mentor_audit_logs
                    group by correlation_id
                ),
                latest as (
                    select distinct on (mal.correlation_id)
                           mal.correlation_id,
                           mal.installation_id,
                           mal.phase,
                           mal.result,
                           mal.failure_code,
                           mal.retryable,
                           mal.rate_limited,
                           mal.created_at,
                           mal.audit_id
                    from mentor_audit_logs mal
                    where mal.event_type <> 'chat_requested'
                    order by mal.correlation_id, mal.created_at desc, mal.audit_id desc
                ),
                incidents as (
                    select latest.correlation_id,
                           latest.installation_id,
                           %s as flag_code,
                           latest.phase as latest_phase,
                           latest.failure_code,
                           latest.retryable,
                           history.historical_rate_limited,
                           latest.created_at as occurred_at
                    from latest
                    join history on history.correlation_id = latest.correlation_id
                    where latest.result <> 'success'
                )
                """.formatted(FLAG_CODE_SQL);
    }

    private QueueIncidentRow mapQueueIncident(ResultSet resultSet, int rowNum) throws SQLException {
        return new QueueIncidentRow(
                resultSet.getString("correlation_id"),
                resultSet.getString("installation_id"),
                resultSet.getString("flag_code"),
                resultSet.getString("latest_phase"),
                resultSet.getString("failure_code"),
                resultSet.getBoolean("retryable"),
                resultSet.getBoolean("historical_rate_limited"),
                mapInstant(resultSet.getTimestamp("occurred_at"))
        );
    }

    private IncidentSnapshotRow mapIncidentSnapshot(ResultSet resultSet, int rowNum) throws SQLException {
        return new IncidentSnapshotRow(
                resultSet.getString("correlation_id"),
                resultSet.getString("installation_id"),
                resultSet.getString("flag_code"),
                resultSet.getString("latest_phase"),
                resultSet.getString("failure_code"),
                resultSet.getBoolean("retryable"),
                resultSet.getBoolean("historical_rate_limited"),
                mapInstant(resultSet.getTimestamp("occurred_at"))
        );
    }

    private TimelineRow mapTimeline(ResultSet resultSet, int rowNum) throws SQLException {
        return new TimelineRow(
                resultSet.getLong("audit_id"),
                resultSet.getString("correlation_id"),
                resultSet.getString("installation_id"),
                resultSet.getString("event_type"),
                resultSet.getString("phase"),
                resultSet.getString("result"),
                resultSet.getString("request_summary"),
                resultSet.getString("response_summary"),
                resultSet.getString("reason"),
                resultSet.getString("failure_code"),
                resultSet.getBoolean("retryable"),
                resultSet.getBoolean("rate_limited"),
                mapInstant(resultSet.getTimestamp("created_at"))
        );
    }

    private DeliveredTurnRow mapDeliveredTurn(ResultSet resultSet, int rowNum) throws SQLException {
        return new DeliveredTurnRow(
                resultSet.getString("correlation_id"),
                resultSet.getString("installation_id"),
                resultSet.getString("result"),
                resultSet.getString("phase"),
                resultSet.getString("request_summary"),
                resultSet.getString("response_summary"),
                resultSet.getString("response_text"),
                resultSet.getString("provider_mode"),
                resultSet.getBoolean("blocked_fallback"),
                resultSet.getBoolean("retryable"),
                mapInstant(resultSet.getTimestamp("created_at"))
        );
    }

    private OverviewSummaryRow mapOverviewSummary(ResultSet resultSet, int rowNum) throws SQLException {
        return new OverviewSummaryRow(
                resultSet.getLong("flagged_incident_count"),
                resultSet.getLong("blocked_fallback_count"),
                resultSet.getLong("rate_limited_count"),
                resultSet.getLong("retryable_count"),
                mapInstant(resultSet.getTimestamp("last_occurred_at"))
        );
    }

    private Instant mapInstant(Timestamp timestamp) {
        return timestamp == null ? null : timestamp.toInstant();
    }

    private void applyStatementTimeout() {
        jdbcTemplate.execute(STATEMENT_TIMEOUT_SQL);
    }

    public record QueueIncidentRow(
            String correlationId,
            String installationId,
            String flagCode,
            String latestPhase,
            String failureCode,
            boolean retryable,
            boolean historicalRateLimited,
            Instant occurredAt
    ) {
    }

    public record IncidentSnapshotRow(
            String correlationId,
            String installationId,
            String flagCode,
            String latestPhase,
            String failureCode,
            boolean retryable,
            boolean historicalRateLimited,
            Instant occurredAt
    ) {
    }

    public record TimelineRow(
            long auditId,
            String correlationId,
            String installationId,
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

    public record DeliveredTurnRow(
            String correlationId,
            String installationId,
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

    public record OverviewSummaryRow(
            long flaggedIncidentCount,
            long blockedFallbackCount,
            long rateLimitedCount,
            long retryableCount,
            Instant lastOccurredAt
    ) {
    }
}
