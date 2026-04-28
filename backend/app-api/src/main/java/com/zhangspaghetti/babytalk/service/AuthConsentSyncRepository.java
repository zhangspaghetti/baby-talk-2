package com.zhangspaghetti.babytalk.service;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Repository;

@Repository
public class AuthConsentSyncRepository {

    private final AuthConsentSyncMapper mapper;

    public AuthConsentSyncRepository(AuthConsentSyncMapper mapper) {
        this.mapper = mapper;
    }

    void insertChallenge(ChallengeRow challenge) {
        mapper.insertChallenge(challenge);
    }

    Optional<ChallengeRow> findChallenge(String challengeId) {
        return Optional.ofNullable(mapper.findChallenge(challengeId));
    }

    int markChallengeVerified(String challengeId, Instant verifiedAt) {
        return mapper.markChallengeVerified(challengeId, verifiedAt);
    }

    void markChallengeExpired(String challengeId, String reason) {
        mapper.markChallengeExpired(challengeId, reason);
    }

    Optional<AccountRow> findActiveAccountByPhone(String phoneNumber) {
        return Optional.ofNullable(mapper.findActiveAccountByPhone(phoneNumber));
    }

    Optional<AccountRow> findAccountById(String accountId) {
        return Optional.ofNullable(mapper.findAccountById(accountId));
    }

    AccountRow insertAccount(AccountRow account) {
        mapper.insertAccount(account);
        return account;
    }

    SessionContextRow insertSession(SessionContextRow session) {
        mapper.insertSession(session);
        return session;
    }

    void insertRefreshToken(RefreshTokenRow refreshToken) {
        mapper.insertRefreshToken(refreshToken);
    }

    Optional<RefreshTokenRow> findRefreshToken(String refreshTokenId) {
        return Optional.ofNullable(mapper.findRefreshToken(refreshTokenId));
    }

    Optional<RefreshTokenRow> lockRefreshToken(String refreshTokenId) {
        return Optional.ofNullable(mapper.lockRefreshToken(refreshTokenId));
    }

    int rotateRefreshToken(String refreshTokenId, String replacementTokenId, Instant rotatedAt) {
        return mapper.rotateRefreshToken(refreshTokenId, replacementTokenId, rotatedAt);
    }

    int revokeRefreshToken(String refreshTokenId, Instant revokedAt) {
        return mapper.revokeRefreshToken(refreshTokenId, revokedAt);
    }

    int expireRefreshToken(String refreshTokenId, Instant expiredAt) {
        return mapper.expireRefreshToken(refreshTokenId, expiredAt);
    }

    int revokeSession(String sessionId, Instant revokedAt) {
        return mapper.revokeSession(sessionId, revokedAt);
    }

    Optional<SessionContextRow> findActiveSession(String sessionId) {
        return Optional.ofNullable(mapper.findActiveSession(sessionId));
    }

    Optional<SessionContextRow> findSessionAnyStatus(String sessionId) {
        return Optional.ofNullable(mapper.findSessionAnyStatus(sessionId));
    }

    void updateAccountConsent(String accountId, String consentStatus) {
        mapper.updateAccountConsent(accountId, consentStatus);
    }

    void updateSessionsStatus(String accountId, String newStatus, Instant changedAt) {
        mapper.updateSessionsStatus(accountId, newStatus, changedAt);
    }

    void insertConsentAudit(AuditRow auditRow) {
        mapper.insertConsentAudit(auditRow);
    }

    List<AuditRow> listAuditEntries(String accountId) {
        return mapper.listAuditEntries(accountId);
    }

    boolean insertInteractionEvent(String accountId, String sessionId, SyncEventRecord event, Instant receivedAt) {
        return mapper.insertInteractionEvent(accountId, sessionId, event, receivedAt) > 0;
    }

    List<StoredInteractionEvent> listInteractionEvents(String accountId, String installationId, int limit) {
        return mapper.listInteractionEvents(accountId, installationId, limit);
    }

    int countInteractionEvents(String accountId, String installationId) {
        return mapper.countInteractionEvents(accountId, installationId);
    }

    int countAllInteractionEvents() {
        return mapper.countAllInteractionEvents();
    }

    int deleteInteractionEvents(String accountId) {
        return mapper.deleteInteractionEvents(accountId);
    }

    void tombstoneAccount(String accountId, String tombstonePhone, Instant deletedAt) {
        mapper.tombstoneAccount(accountId, tombstonePhone, deletedAt);
    }

    public record ChallengeRow(
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

    public record AccountRow(
            String accountId,
            String phoneNumber,
            String status,
            String latestConsentStatus,
            Instant createdAt,
            Instant deletedAt
    ) {
    }

    public record SessionContextRow(
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

    public record RefreshTokenRow(
            String refreshTokenId,
            String accountId,
            String sessionId,
            String status,
            Instant issuedAt,
            Instant expiresAt,
            Instant updatedAt,
            Instant rotatedAt,
            Instant revokedAt,
            String replacementTokenId
    ) {
    }

    public record AuditRow(
            String accountId,
            String sessionId,
            String installationId,
            String action,
            String result,
            String reason,
            Instant createdAt
    ) {
    }

    public record StoredInteractionEvent(
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

    public record SyncEventRecord(
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
