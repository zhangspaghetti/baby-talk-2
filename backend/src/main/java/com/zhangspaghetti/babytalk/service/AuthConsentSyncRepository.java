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
class AuthConsentSyncRepository {

    private final JdbcTemplate jdbcTemplate;

    AuthConsentSyncRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    void insertChallenge(ChallengeRow challenge) {
        jdbcTemplate.update(
                """
                insert into sms_challenges (
                    challenge_id,
                    phone_number,
                    verification_code,
                    status,
                    issued_at,
                    expires_at,
                    verified_at,
                    failure_reason
                ) values (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                challenge.challengeId(),
                challenge.phoneNumber(),
                challenge.verificationCode(),
                challenge.status(),
                Timestamp.from(challenge.issuedAt()),
                Timestamp.from(challenge.expiresAt()),
                toTimestamp(challenge.verifiedAt()),
                challenge.failureReason()
        );
    }

    Optional<ChallengeRow> findChallenge(String challengeId) {
        return findOne(
                """
                select challenge_id, phone_number, verification_code, status, issued_at, expires_at, verified_at, failure_reason
                from sms_challenges
                where challenge_id = ?
                """,
                this::mapChallengeRow,
                challengeId
        );
    }

    void markChallengeVerified(String challengeId, Instant verifiedAt) {
        jdbcTemplate.update(
                "update sms_challenges set status = 'verified', verified_at = ?, failure_reason = null where challenge_id = ?",
                Timestamp.from(verifiedAt),
                challengeId
        );
    }

    void markChallengeExpired(String challengeId, String reason) {
        jdbcTemplate.update(
                "update sms_challenges set status = 'expired', failure_reason = ? where challenge_id = ? and status = 'pending'",
                reason,
                challengeId
        );
    }

    Optional<AccountRow> findActiveAccountByPhone(String phoneNumber) {
        return findOne(
                """
                select account_id, phone_number, status, latest_consent_status, created_at, deleted_at
                from accounts
                where phone_number = ? and status = 'active'
                """,
                this::mapAccountRow,
                phoneNumber
        );
    }

    Optional<AccountRow> findAccountById(String accountId) {
        return findOne(
                """
                select account_id, phone_number, status, latest_consent_status, created_at, deleted_at
                from accounts
                where account_id = ?
                """,
                this::mapAccountRow,
                accountId
        );
    }

    AccountRow insertAccount(AccountRow account) {
        jdbcTemplate.update(
                """
                insert into accounts (
                    account_id,
                    phone_number,
                    status,
                    latest_consent_status,
                    created_at,
                    deleted_at
                ) values (?, ?, ?, ?, ?, ?)
                """,
                account.accountId(),
                account.phoneNumber(),
                account.status(),
                account.latestConsentStatus(),
                Timestamp.from(account.createdAt()),
                toTimestamp(account.deletedAt())
        );
        return account;
    }

    SessionContextRow insertSession(SessionContextRow session) {
        jdbcTemplate.update(
                """
                insert into account_sessions (
                    session_id,
                    account_id,
                    installation_id,
                    status,
                    created_at,
                    revoked_at
                ) values (?, ?, ?, ?, ?, ?)
                """,
                session.sessionId(),
                session.accountId(),
                session.installationId(),
                session.sessionStatus(),
                Timestamp.from(session.createdAt()),
                toTimestamp(session.revokedAt())
        );
        return session;
    }

    Optional<SessionContextRow> findActiveSession(String sessionId) {
        return findSession(sessionId, true);
    }

    Optional<SessionContextRow> findSessionAnyStatus(String sessionId) {
        return findSession(sessionId, false);
    }

    void updateAccountConsent(String accountId, String consentStatus) {
        jdbcTemplate.update(
                "update accounts set latest_consent_status = ? where account_id = ?",
                consentStatus,
                accountId
        );
    }

    void updateSessionsStatus(String accountId, String newStatus, Instant changedAt) {
        jdbcTemplate.update(
                "update account_sessions set status = ?, revoked_at = ? where account_id = ? and status <> ?",
                newStatus,
                Timestamp.from(changedAt),
                accountId,
                newStatus
        );
    }

    void insertConsentAudit(AuditRow auditRow) {
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

    List<AuditRow> listAuditEntries(String accountId) {
        return jdbcTemplate.query(
                """
                select account_id, session_id, installation_id, action, result, reason, created_at
                from consent_audit_logs
                where account_id = ?
                order by created_at asc, audit_id asc
                """,
                (rs, rowNum) -> mapAuditRow(rs),
                accountId
        );
    }

    void insertInteractionEvent(String accountId, String sessionId, SyncEventRecord event, Instant receivedAt) {
        jdbcTemplate.update(
                """
                insert into interaction_events (
                    event_key,
                    account_id,
                    session_id,
                    installation_id,
                    local_event_id,
                    space_id,
                    activity_id,
                    phrase_id,
                    reaction_type,
                    client_timestamp,
                    received_at
                ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                event.eventKey(),
                accountId,
                sessionId,
                event.installationId(),
                event.localEventId(),
                event.spaceId(),
                event.activityId(),
                event.phraseId(),
                event.reactionType(),
                Timestamp.from(event.clientTimestamp()),
                Timestamp.from(receivedAt)
        );
    }

    List<StoredInteractionEvent> listInteractionEvents(String accountId, String installationId, int limit) {
        return jdbcTemplate.query(
                """
                select event_key, local_event_id, installation_id, space_id, activity_id, phrase_id, reaction_type, client_timestamp, received_at
                from interaction_events
                where account_id = ? and installation_id = ?
                order by client_timestamp asc, event_key asc
                limit ?
                """,
                (rs, rowNum) -> mapStoredInteractionEvent(rs),
                accountId,
                installationId,
                limit
        );
    }

    int countInteractionEvents(String accountId, String installationId) {
        return jdbcTemplate.queryForObject(
                "select count(*) from interaction_events where account_id = ? and installation_id = ?",
                Integer.class,
                accountId,
                installationId
        );
    }

    int countAllInteractionEvents() {
        return jdbcTemplate.queryForObject("select count(*) from interaction_events", Integer.class);
    }

    int deleteInteractionEvents(String accountId) {
        return jdbcTemplate.update("delete from interaction_events where account_id = ?", accountId);
    }

    void tombstoneAccount(String accountId, String tombstonePhone, Instant deletedAt) {
        jdbcTemplate.update(
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

    private Optional<SessionContextRow> findSession(String sessionId, boolean activeOnly) {
        var sql = new StringBuilder(
                """
                select s.session_id,
                       s.account_id,
                       s.installation_id,
                       s.status as session_status,
                       s.created_at,
                       s.revoked_at,
                       a.phone_number,
                       a.status as account_status,
                       a.latest_consent_status,
                       a.created_at as account_created_at,
                       a.deleted_at
                from account_sessions s
                join accounts a on a.account_id = s.account_id
                where s.session_id = ?
                """
        );
        if (activeOnly) {
            sql.append(" and s.status = 'active'");
        }
        return findOne(sql.toString(), this::mapSessionContextRow, sessionId);
    }

    private <T> Optional<T> findOne(String sql, RowMapper<T> mapper, Object... args) {
        try {
            return Optional.ofNullable(jdbcTemplate.queryForObject(sql, mapper, args));
        } catch (EmptyResultDataAccessException exception) {
            return Optional.empty();
        }
    }

    private ChallengeRow mapChallengeRow(ResultSet rs, int rowNum) throws SQLException {
        return new ChallengeRow(
                rs.getString("challenge_id"),
                rs.getString("phone_number"),
                rs.getString("verification_code"),
                rs.getString("status"),
                rs.getTimestamp("issued_at").toInstant(),
                rs.getTimestamp("expires_at").toInstant(),
                toInstant(rs.getTimestamp("verified_at")),
                rs.getString("failure_reason")
        );
    }

    private AccountRow mapAccountRow(ResultSet rs, int rowNum) throws SQLException {
        return new AccountRow(
                rs.getString("account_id"),
                rs.getString("phone_number"),
                rs.getString("status"),
                rs.getString("latest_consent_status"),
                rs.getTimestamp("created_at").toInstant(),
                toInstant(rs.getTimestamp("deleted_at"))
        );
    }

    private SessionContextRow mapSessionContextRow(ResultSet rs, int rowNum) throws SQLException {
        return new SessionContextRow(
                rs.getString("session_id"),
                rs.getString("account_id"),
                rs.getString("installation_id"),
                rs.getString("session_status"),
                rs.getTimestamp("created_at").toInstant(),
                toInstant(rs.getTimestamp("revoked_at")),
                rs.getString("phone_number"),
                rs.getString("account_status"),
                rs.getString("latest_consent_status"),
                rs.getTimestamp("account_created_at").toInstant(),
                toInstant(rs.getTimestamp("deleted_at"))
        );
    }

    private AuditRow mapAuditRow(ResultSet rs) throws SQLException {
        return new AuditRow(
                rs.getString("account_id"),
                rs.getString("session_id"),
                rs.getString("installation_id"),
                rs.getString("action"),
                rs.getString("result"),
                rs.getString("reason"),
                rs.getTimestamp("created_at").toInstant()
        );
    }

    private StoredInteractionEvent mapStoredInteractionEvent(ResultSet rs) throws SQLException {
        return new StoredInteractionEvent(
                rs.getString("event_key"),
                rs.getString("local_event_id"),
                rs.getString("installation_id"),
                rs.getString("space_id"),
                rs.getString("activity_id"),
                rs.getString("phrase_id"),
                rs.getString("reaction_type"),
                rs.getTimestamp("client_timestamp").toInstant(),
                rs.getTimestamp("received_at").toInstant()
        );
    }

    private Timestamp toTimestamp(Instant instant) {
        return instant == null ? null : Timestamp.from(instant);
    }

    private Instant toInstant(Timestamp timestamp) {
        return timestamp == null ? null : timestamp.toInstant();
    }

    record ChallengeRow(
            String challengeId,
            String phoneNumber,
            String verificationCode,
            String status,
            Instant issuedAt,
            Instant expiresAt,
            Instant verifiedAt,
            String failureReason
    ) {
    }

    record AccountRow(
            String accountId,
            String phoneNumber,
            String status,
            String latestConsentStatus,
            Instant createdAt,
            Instant deletedAt
    ) {
    }

    record SessionContextRow(
            String sessionId,
            String accountId,
            String installationId,
            String sessionStatus,
            Instant createdAt,
            Instant revokedAt,
            String phoneNumber,
            String accountStatus,
            String latestConsentStatus,
            Instant accountCreatedAt,
            Instant accountDeletedAt
    ) {
    }

    record AuditRow(
            String accountId,
            String sessionId,
            String installationId,
            String action,
            String result,
            String reason,
            Instant createdAt
    ) {
    }

    record StoredInteractionEvent(
            String eventKey,
            String localEventId,
            String installationId,
            String spaceId,
            String activityId,
            String phraseId,
            String reactionType,
            Instant clientTimestamp,
            Instant receivedAt
    ) {
    }

    record SyncEventRecord(
            String eventKey,
            String localEventId,
            String installationId,
            String spaceId,
            String activityId,
            String phraseId,
            String reactionType,
            Instant clientTimestamp
    ) {
    }
}
