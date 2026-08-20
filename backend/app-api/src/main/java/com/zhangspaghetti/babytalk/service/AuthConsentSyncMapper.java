package com.zhangspaghetti.babytalk.service;

import java.time.Instant;
import java.util.List;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

@Mapper
public interface AuthConsentSyncMapper {

    void insertChallenge(@Param("row") AuthConsentSyncRepository.ChallengeRow row);

    AuthConsentSyncRepository.ChallengeRow findChallenge(@Param("challengeId") String challengeId);

    AuthConsentSyncRepository.ChallengeRow lockChallenge(@Param("challengeId") String challengeId);

    int markChallengeVerified(@Param("challengeId") String challengeId, @Param("verifiedAt") Instant verifiedAt);

    int markChallengeExpired(@Param("challengeId") String challengeId, @Param("reason") String reason);

    void recordChallengeVerificationFailure(@Param("challengeId") String challengeId);

    AuthConsentSyncRepository.AccountRow findActiveAccountByPhoneLookupRef(@Param("phoneLookupRef") String phoneLookupRef);

    AuthConsentSyncRepository.AccountRow findAccountById(@Param("accountId") String accountId);

    void insertAccount(@Param("row") AuthConsentSyncRepository.AccountRow row);

    void insertSession(@Param("row") AuthConsentSyncRepository.SessionContextRow row);

    void insertRefreshToken(@Param("row") AuthConsentSyncRepository.RefreshTokenRow row);

    AuthConsentSyncRepository.RefreshTokenRow findRefreshToken(@Param("refreshTokenId") String refreshTokenId);

    AuthConsentSyncRepository.RefreshTokenRow lockRefreshToken(@Param("refreshTokenId") String refreshTokenId);

    int rotateRefreshToken(
            @Param("refreshTokenId") String refreshTokenId,
            @Param("replacementTokenId") String replacementTokenId,
            @Param("rotatedAt") Instant rotatedAt
    );

    int revokeRefreshToken(@Param("refreshTokenId") String refreshTokenId, @Param("revokedAt") Instant revokedAt);

    int expireRefreshToken(@Param("refreshTokenId") String refreshTokenId, @Param("expiredAt") Instant expiredAt);

    int revokeSession(@Param("sessionId") String sessionId, @Param("revokedAt") Instant revokedAt);

    AuthConsentSyncRepository.SessionContextRow findActiveSession(@Param("sessionId") String sessionId);

    AuthConsentSyncRepository.SessionContextRow findSessionAnyStatus(@Param("sessionId") String sessionId);

    int updateAccountConsent(@Param("accountId") String accountId, @Param("consentStatus") String consentStatus);

    int updateSessionsStatus(
            @Param("accountId") String accountId,
            @Param("newStatus") String newStatus,
            @Param("changedAt") Instant changedAt
    );

    int redactConsentAuditInstallationReferences(@Param("accountId") String accountId);

    void insertConsentAudit(@Param("row") AuthConsentSyncRepository.AuditRow row);

    List<AuthConsentSyncRepository.AuditRow> listAuditEntries(@Param("accountId") String accountId);

    int insertInteractionEvent(
            @Param("accountId") String accountId,
            @Param("sessionId") String sessionId,
            @Param("event") AuthConsentSyncRepository.SyncEventRecord event,
            @Param("receivedAt") Instant receivedAt
    );

    List<AuthConsentSyncRepository.StoredInteractionEvent> listInteractionEvents(
            @Param("accountId") String accountId,
            @Param("limit") int limit
    );

    int countInteractionEvents(
            @Param("accountId") String accountId,
            @Param("installationReference") String installationReference
    );

    int countAllInteractionEvents();

    int deleteInteractionEvents(@Param("accountId") String accountId);

    int tombstoneAccount(
            @Param("accountId") String accountId,
            @Param("tombstonePhone") String tombstonePhone,
            @Param("deletedAt") Instant deletedAt
    );
}
