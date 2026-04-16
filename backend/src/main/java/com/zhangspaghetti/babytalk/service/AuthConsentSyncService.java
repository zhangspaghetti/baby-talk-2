package com.zhangspaghetti.babytalk.service;

import com.zhangspaghetti.babytalk.config.ApiContractProperties;
import com.zhangspaghetti.babytalk.web.ContractException;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.dao.DataAccessException;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthConsentSyncService {

    private static final Set<String> ALLOWED_REACTION_TYPES = Set.of("calm", "engaged", "imitated", "needs_break");

    private final AuthConsentSyncRepository repository;
    private final SmsVerificationProvider smsVerificationProvider;
    private final HouseholdSharedContextProjector householdSharedContextProjector;
    private final ApiContractProperties contractProperties;
    private final Clock clock = Clock.systemUTC();

    public AuthConsentSyncService(
            AuthConsentSyncRepository repository,
            SmsVerificationProvider smsVerificationProvider,
            HouseholdSharedContextProjector householdSharedContextProjector,
            ApiContractProperties contractProperties
    ) {
        this.repository = repository;
        this.smsVerificationProvider = smsVerificationProvider;
        this.householdSharedContextProjector = householdSharedContextProjector;
        this.contractProperties = contractProperties;
    }

    @Transactional
    public ChallengeResponse createChallenge(String phoneNumber) {
        var normalizedPhone = normalizePhone(phoneNumber);
        var now = Instant.now(clock);
        SmsVerificationProvider.SmsChallenge issued;
        try {
            issued = smsVerificationProvider.issueChallenge(normalizedPhone, now);
        } catch (SmsVerificationProvider.ProviderMisconfiguredException exception) {
            throw new ContractException(HttpStatus.SERVICE_UNAVAILABLE, "sms_provider_unconfigured", exception.getMessage());
        } catch (SmsVerificationProvider.RetryableChallengeException exception) {
            throw new ContractException(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "sms_provider_retryable",
                    exception.getMessage(),
                    Map.of("retryable", true)
            );
        }

        var challengeId = "challenge_" + UUID.randomUUID();
        repository.insertChallenge(
                new AuthConsentSyncRepository.ChallengeRow(
                        challengeId,
                        normalizedPhone,
                        issued.verificationCode(),
                        "pending",
                        now,
                        issued.expiresAt(),
                        null,
                        null
                )
        );
        return new ChallengeResponse(challengeId, issued.maskedPhoneNumber(), issued.codeLength(), issued.expiresAt());
    }

    @Transactional
    public SessionResponse verifyChallenge(String challengeId, String verificationCode, String installationId) {
        if (challengeId == null || challengeId.isBlank()) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "challenge_id_required", "challengeId 不能为空。");
        }
        if (verificationCode == null || !verificationCode.matches("\\d{4,8}")) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "invalid_verification_code", "验证码必须是 4-8 位数字。");
        }
        var normalizedInstallationId = normalizeInstallationId(installationId);

        var challenge = repository.findChallenge(challengeId)
                .orElseThrow(() -> new ContractException(HttpStatus.BAD_REQUEST, "challenge_not_found", "challenge 不存在。"));
        if (!"pending".equals(challenge.status())) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "challenge_not_pending", "challenge 已使用或已失效。");
        }
        var now = Instant.now(clock);
        if (challenge.expiresAt().isBefore(now)) {
            repository.markChallengeExpired(challengeId, "expired_before_verify");
            throw new ContractException(HttpStatus.BAD_REQUEST, "challenge_expired", "验证码已过期，请重新获取。", Map.of("retryable", true));
        }
        if (!challenge.verificationCode().equals(verificationCode)) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "verification_code_invalid", "验证码错误。", Map.of("retryable", true));
        }

        repository.markChallengeVerified(challengeId, now);
        var account = repository.findActiveAccountByPhone(challenge.phoneNumber())
                .orElseGet(() -> repository.insertAccount(
                        new AuthConsentSyncRepository.AccountRow(
                                "acct_" + UUID.randomUUID(),
                                challenge.phoneNumber(),
                                "active",
                                "signed_out",
                                now,
                                null
                        )
                ));

        var sessionId = "sess_" + UUID.randomUUID();
        repository.insertSession(
                new AuthConsentSyncRepository.SessionContextRow(
                        sessionId,
                        account.accountId(),
                        normalizedInstallationId,
                        "active",
                        now,
                        null,
                        account.phoneNumber(),
                        account.status(),
                        account.latestConsentStatus(),
                        account.createdAt(),
                        account.deletedAt()
                )
        );
        return new SessionResponse(account.accountId(), sessionId, maskPhone(account.phoneNumber()), now, account.latestConsentStatus());
    }

    @Transactional
    public ConsentResponse acceptConsent(String sessionId, String consentVersion) {
        var session = requireExistingActiveSession(sessionId);
        var now = Instant.now(clock);
        if ("accepted".equals(session.latestConsentStatus())) {
            repository.insertConsentAudit(audit(session, "accept", "duplicate", sanitizeReason(consentVersion), now));
            return new ConsentResponse(false, "duplicate", "accepted", session.accountId(), session.sessionId(), now);
        }
        repository.updateAccountConsent(session.accountId(), "accepted");
        repository.insertConsentAudit(audit(session, "accept", "applied", sanitizeReason(consentVersion), now));
        return new ConsentResponse(true, "applied", "accepted", session.accountId(), session.sessionId(), now);
    }

    @Transactional
    public ConsentResponse revokeConsent(String sessionId, String reason) {
        var session = requireExistingSessionAnyStatus(sessionId);
        if ("deleted".equals(session.accountStatus())) {
            throw new ContractException(HttpStatus.GONE, "account_deleted", "账号已删除。请重新注册。");
        }
        var now = Instant.now(clock);
        if ("revoked".equals(session.latestConsentStatus())) {
            repository.insertConsentAudit(audit(session, "revoke", "duplicate", sanitizeReason(reason), now));
            return new ConsentResponse(false, "duplicate", "revoked", session.accountId(), session.sessionId(), now);
        }
        repository.updateAccountConsent(session.accountId(), "revoked");
        repository.updateSessionsStatus(session.accountId(), "revoked", now);
        repository.insertConsentAudit(audit(session, "revoke", "applied", sanitizeReason(reason), now));
        return new ConsentResponse(true, "applied", "revoked", session.accountId(), session.sessionId(), now);
    }

    @Transactional
    public DeleteResponse deleteAccount(String sessionId, String reason) {
        var session = requireExistingSessionAnyStatus(sessionId);
        var now = Instant.now(clock);
        if ("deleted".equals(session.accountStatus())) {
            repository.insertConsentAudit(audit(session, "delete", "duplicate", sanitizeReason(reason), now));
            return new DeleteResponse(false, "duplicate", session.accountId(), session.sessionId(), 0, now);
        }

        var deletedEvents = repository.deleteInteractionEvents(session.accountId());
        repository.updateSessionsStatus(session.accountId(), "deleted", now);
        repository.tombstoneAccount(session.accountId(), "deleted:" + session.accountId(), now);
        repository.insertConsentAudit(audit(session, "delete", "applied", sanitizeReason(reason), now));
        return new DeleteResponse(true, "applied", session.accountId(), session.sessionId(), deletedEvents, now);
    }

    @Transactional
    public SyncBatchResponse ingestEvents(String sessionId, String installationId, List<SyncEventRequest> events) {
        var session = requireSessionForSync(sessionId);
        var normalizedInstallationId = normalizeInstallationId(installationId);
        if (!normalizedInstallationId.equals(session.installationId())) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "installation_mismatch", "请求 installationId 与当前 session 不一致。");
        }
        if (events == null || events.isEmpty()) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "empty_batch", "同步 batch 不能为空。");
        }
        if (events.size() > contractProperties.syncMaxBatchSize()) {
            throw new ContractException(
                    HttpStatus.BAD_REQUEST,
                    "batch_too_large",
                    "同步 batch 超过上限。",
                    Map.of("maxBatchSize", contractProperties.syncMaxBatchSize())
            );
        }

        var seenEventKeys = new LinkedHashSet<String>();
        var acceptedEventKeys = new ArrayList<String>();
        var duplicateEventKeys = new ArrayList<String>();
        var now = Instant.now(clock);

        for (var event : events) {
            var validated = validateSyncEvent(normalizedInstallationId, event, seenEventKeys);
            try {
                repository.insertInteractionEvent(session.accountId(), session.sessionId(), validated, now);
                acceptedEventKeys.add(validated.eventKey());
            } catch (DuplicateKeyException exception) {
                duplicateEventKeys.add(validated.eventKey());
            } catch (DataAccessException exception) {
                throw new ContractException(
                        HttpStatus.BAD_REQUEST,
                        "sync_batch_rejected",
                        "同步 batch 被拒绝，整批已回滚。",
                        Map.of(
                                "failedEventKey", validated.eventKey(),
                                "reason", simplifyDataAccessMessage(exception)
                        )
                );
            }
        }

        if (!acceptedEventKeys.isEmpty()) {
            try {
                householdSharedContextProjector.refreshForAccount(session.accountId(), now);
            } catch (ContractException | DataAccessException exception) {
                throw syncBatchRejectedForProjection(exception);
            }
        }

        return new SyncBatchResponse(
                session.accountId(),
                session.sessionId(),
                normalizedInstallationId,
                events.size(),
                acceptedEventKeys.size(),
                duplicateEventKeys.size(),
                acceptedEventKeys,
                duplicateEventKeys,
                now
        );
    }

    @Transactional(readOnly = true)
    public BootstrapResponse bootstrap(String sessionId, String installationId) {
        var session = requireSessionForSync(sessionId);
        var normalizedInstallationId = normalizeInstallationId(installationId);
        if (!normalizedInstallationId.equals(session.installationId())) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "installation_mismatch", "请求 installationId 与当前 session 不一致。");
        }
        var events = repository.listInteractionEvents(session.accountId(), normalizedInstallationId, contractProperties.bootstrapMaxEvents())
                .stream()
                .map(row -> new BootstrapEvent(
                        row.eventKey(),
                        row.localEventId(),
                        row.installationId(),
                        row.spaceId(),
                        row.activityId(),
                        row.phraseId(),
                        row.reactionType(),
                        row.clientTimestamp(),
                        row.receivedAt()
                ))
                .toList();
        return new BootstrapResponse(
                session.accountId(),
                session.sessionId(),
                normalizedInstallationId,
                session.latestConsentStatus(),
                events.size(),
                events,
                Instant.now(clock)
        );
    }

    @Transactional(readOnly = true)
    public int countInteractionEvents(String accountId, String installationId) {
        return repository.countInteractionEvents(accountId, installationId);
    }

    @Transactional(readOnly = true)
    public int countAllInteractionEvents() {
        return repository.countAllInteractionEvents();
    }

    @Transactional(readOnly = true)
    public List<AuditEntry> listAuditEntries(String accountId) {
        return repository.listAuditEntries(accountId)
                .stream()
                .map(row -> new AuditEntry(
                        row.accountId(),
                        row.sessionId(),
                        row.installationId(),
                        row.action(),
                        row.result(),
                        row.reason(),
                        row.createdAt()
                ))
                .toList();
    }

    private AuthConsentSyncRepository.SessionContextRow requireExistingActiveSession(String sessionId) {
        var normalizedSessionId = normalizeSessionId(sessionId);
        var session = repository.findActiveSession(normalizedSessionId)
                .orElseThrow(() -> new ContractException(HttpStatus.UNAUTHORIZED, "invalid_session", "session 不存在或已失效。"));
        if ("deleted".equals(session.accountStatus())) {
            throw new ContractException(HttpStatus.GONE, "account_deleted", "账号已删除。请重新注册。");
        }
        return session;
    }

    private AuthConsentSyncRepository.SessionContextRow requireExistingSessionAnyStatus(String sessionId) {
        var normalizedSessionId = normalizeSessionId(sessionId);
        return repository.findSessionAnyStatus(normalizedSessionId)
                .orElseThrow(() -> new ContractException(HttpStatus.UNAUTHORIZED, "invalid_session", "session 不存在。"));
    }

    private AuthConsentSyncRepository.SessionContextRow requireSessionForSync(String sessionId) {
        var session = requireExistingSessionAnyStatus(sessionId);
        if ("deleted".equals(session.accountStatus()) || "deleted".equals(session.sessionStatus())) {
            throw new ContractException(HttpStatus.GONE, "account_deleted", "账号已删除，bootstrap/sync 不再可用。请重新注册。");
        }
        if ("revoked".equals(session.sessionStatus()) || "revoked".equals(session.latestConsentStatus())) {
            throw new ContractException(HttpStatus.CONFLICT, "consent_revoked", "同意已撤回，请重新登录并再次同意后再同步。", Map.of("retryable", true));
        }
        if (!"accepted".equals(session.latestConsentStatus())) {
            throw new ContractException(HttpStatus.CONFLICT, "consent_required", "当前账号尚未完成同意，不能执行 bootstrap/sync。", Map.of("retryable", true));
        }
        if (!"active".equals(session.sessionStatus())) {
            throw new ContractException(HttpStatus.UNAUTHORIZED, "invalid_session", "session 不存在或已失效。");
        }
        return session;
    }

    private AuthConsentSyncRepository.SyncEventRecord validateSyncEvent(
            String requestInstallationId,
            SyncEventRequest event,
            Set<String> seenEventKeys
    ) {
        if (event == null) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "invalid_event", "batch 中存在空事件。");
        }
        var localEventId = requireTrimmed(event.localEventId(), "localEventId");
        var installationId = normalizeInstallationId(event.installationId());
        if (!requestInstallationId.equals(installationId)) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "installation_mismatch", "事件 installationId 与 batch 不一致。");
        }
        var expectedEventKey = installationId + ":" + localEventId;
        var eventKey = requireTrimmed(event.eventKey(), "eventKey");
        if (!expectedEventKey.equals(eventKey)) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "unknown_event_key", "eventKey 与 installationId/localEventId 不一致。", Map.of("eventKey", eventKey));
        }
        if (!seenEventKeys.add(eventKey)) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "duplicate_event_key_in_batch", "同一 batch 内不允许重复 eventKey。", Map.of("eventKey", eventKey));
        }
        var reactionType = requireTrimmed(event.reactionType(), "reactionType").toLowerCase(Locale.ROOT);
        if (!ALLOWED_REACTION_TYPES.contains(reactionType)) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "invalid_reaction_type", "reactionType 非法。");
        }
        return new AuthConsentSyncRepository.SyncEventRecord(
                eventKey,
                localEventId,
                installationId,
                requireTrimmed(event.spaceId(), "spaceId"),
                requireTrimmed(event.activityId(), "activityId"),
                requireTrimmed(event.phraseId(), "phraseId"),
                reactionType,
                requireClientTimestamp(event.clientTimestamp())
        );
    }

    private AuthConsentSyncRepository.AuditRow audit(
            AuthConsentSyncRepository.SessionContextRow session,
            String action,
            String result,
            String reason,
            Instant createdAt
    ) {
        return new AuthConsentSyncRepository.AuditRow(
                session.accountId(),
                session.sessionId(),
                session.installationId(),
                action,
                result,
                reason,
                createdAt
        );
    }

    private ContractException syncBatchRejectedForProjection(Exception exception) {
        var reason = exception instanceof ContractException contractException
                ? simplifyProjectionFailureReason(contractException)
                : simplifyDataAccessMessage((DataAccessException) exception);
        return new ContractException(
                HttpStatus.BAD_REQUEST,
                "sync_batch_rejected",
                "同步 batch 被拒绝，整批已回滚。",
                Map.of(
                        "retryable", true,
                        "reason", reason,
                        "phase", "household_shared_context_projection"
                )
        );
    }

    private String simplifyProjectionFailureReason(ContractException exception) {
        var reason = exception.details().get("reason");
        if (reason instanceof String value && !value.isBlank()) {
            return value;
        }
        var field = exception.details().get("field");
        if (field instanceof String value && !value.isBlank()) {
            return value + "_invalid";
        }
        return exception.code();
    }

    private String simplifyDataAccessMessage(DataAccessException exception) {
        var message = exception.getMostSpecificCause() == null
                ? exception.getMessage()
                : exception.getMostSpecificCause().getMessage();
        if (message == null || message.isBlank()) {
            return "database_write_failed";
        }
        return message.length() > 240 ? message.substring(0, 240) : message;
    }

    private String normalizePhone(String phoneNumber) {
        if (phoneNumber == null) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "invalid_phone_number", "手机号不能为空。");
        }
        var digits = phoneNumber.replaceAll("[^0-9]", "");
        if (!digits.matches("1\\d{10}")) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "invalid_phone_number", "手机号必须是 11 位大陆手机号。");
        }
        return digits;
    }

    private String normalizeInstallationId(String installationId) {
        var normalized = requireTrimmed(installationId, "installationId");
        if (normalized.length() > 128) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "invalid_installation_id", "installationId 过长。");
        }
        return normalized;
    }

    private String normalizeSessionId(String sessionId) {
        var normalized = requireTrimmed(sessionId, "sessionId");
        if (normalized.length() > 128) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "invalid_session_id", "sessionId 过长。");
        }
        return normalized;
    }

    private String requireTrimmed(String value, String fieldName) {
        if (value == null || value.isBlank()) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "missing_" + fieldName, fieldName + " 不能为空。");
        }
        return value.trim();
    }

    private Instant requireClientTimestamp(Instant clientTimestamp) {
        if (clientTimestamp == null) {
            throw new ContractException(HttpStatus.BAD_REQUEST, "missing_client_timestamp", "clientTimestamp 不能为空。");
        }
        return clientTimestamp;
    }

    private String maskPhone(String phoneNumber) {
        return phoneNumber.substring(0, 3) + "****" + phoneNumber.substring(phoneNumber.length() - 4);
    }

    private String sanitizeReason(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        var trimmed = value.trim();
        return trimmed.length() > 240 ? trimmed.substring(0, 240) : trimmed;
    }

    public record ChallengeResponse(
            String challengeId,
            String maskedPhoneNumber,
            int codeLength,
            Instant expiresAt
    ) {
    }

    public record SessionResponse(
            String accountId,
            String sessionId,
            String maskedPhoneNumber,
            Instant createdAt,
            String consentStatus
    ) {
    }

    public record ConsentResponse(
            boolean applied,
            String result,
            String consentStatus,
            String accountId,
            String sessionId,
            Instant updatedAt
    ) {
    }

    public record DeleteResponse(
            boolean applied,
            String result,
            String accountId,
            String sessionId,
            int deletedEventCount,
            Instant updatedAt
    ) {
    }

    public record SyncEventRequest(
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

    public record SyncBatchResponse(
            String accountId,
            String sessionId,
            String installationId,
            int receivedCount,
            int acceptedCount,
            int duplicateCount,
            List<String> acceptedEventKeys,
            List<String> duplicateEventKeys,
            Instant syncedAt
    ) {
    }

    public record BootstrapEvent(
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

    public record BootstrapResponse(
            String accountId,
            String sessionId,
            String installationId,
            String consentStatus,
            int eventCount,
            List<BootstrapEvent> events,
            Instant bootstrapAt
    ) {
    }

    public record AuditEntry(
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
