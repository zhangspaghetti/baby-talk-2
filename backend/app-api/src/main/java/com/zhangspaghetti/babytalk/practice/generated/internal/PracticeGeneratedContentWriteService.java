package com.zhangspaghetti.babytalk.practice.generated.internal;

import com.zhangspaghetti.babytalk.practice.generated.DraftReservation;
import com.zhangspaghetti.babytalk.practice.generated.GeneratedContentIdConflictException;
import com.zhangspaghetti.babytalk.practice.generated.GenerationStartDecision;
import com.zhangspaghetti.babytalk.practice.generated.GenerationAttemptAuditPort;
import com.zhangspaghetti.babytalk.practice.generated.PracticeGeneratedContentCommands;
import com.zhangspaghetti.babytalk.practice.generated.PracticeGeneratedContentQueryMapper;
import com.zhangspaghetti.babytalk.practice.generated.PracticeGenerationRateLimitExceededException;
import com.zhangspaghetti.babytalk.practice.generated.ReservationPolicy;
import com.zhangspaghetti.babytalk.practice.generated.model.PracticeGeneratedContentEntity;
import java.time.OffsetDateTime;
import java.util.Optional;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
class PracticeGeneratedContentWriteService implements PracticeGeneratedContentCommands {

    private final PracticeGeneratedContentCommandMapper commandMapper;
    private final PracticeGeneratedContentQueryMapper queryMapper;
    private final PracticeGenerationAuditMapper auditMapper;

    PracticeGeneratedContentWriteService(
            PracticeGeneratedContentCommandMapper commandMapper,
            PracticeGeneratedContentQueryMapper queryMapper,
            PracticeGenerationAuditMapper auditMapper
    ) {
        this.commandMapper = commandMapper;
        this.queryMapper = queryMapper;
        this.auditMapper = auditMapper;
    }

    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public DraftReservation reserveDraft(
            PracticeGeneratedContentEntity draft,
            ReservationPolicy policy
    ) {
        commandMapper.lockOwnerRateLimit(ownerLockKey(draft));
        var clientRequestMatch = findByClientRequestId(draft);
        if (clientRequestMatch != null) {
            return new DraftReservation(clientRequestMatch, false);
        }
        var existing = findLive(draft);
        var staleDraft = isStaleDraft(existing, policy.now());
        var dueInstallationActive = isDueInstallationActive(existing, policy.now());
        if (existing != null && !staleDraft && !dueInstallationActive) {
            return new DraftReservation(existing, false);
        }
        var recent = queryMapper.countRecentDraftReservations(
                draft.ownerKey(), draft.ownerKeyVersion(), draft.surface(), draft.mode(), policy.burstFrom());
        if (recent >= policy.burstLimit()) {
            throw new PracticeGenerationRateLimitExceededException("burst", policy.burstLimit());
        }
        if (dueInstallationActive
                && existing.generatedContentId().equals(draft.generatedContentId())) {
            throw new GeneratedContentIdConflictException(
                    draft.generatedContentId(),
                    new IllegalStateException("due installation content requires a replacement id"));
        }
        if (staleDraft) {
            commandMapper.expireLive(
                    existing.generatedContentId(),
                    "draft_expired",
                    true,
                    policy.now(),
                    policy.expiredRetentionExpiresAt());
        } else if (dueInstallationActive) {
            commandMapper.deleteDueInstallationActive(
                    existing.generatedContentId(), draft.ownerKeyVersion(), policy.now());
        }
        var remaining = findLive(draft);
        if (remaining != null) {
            return new DraftReservation(remaining, false);
        }
        try {
            if (commandMapper.insertDraftIgnoringLiveConflict(draft) == 1) {
                return new DraftReservation(
                        queryMapper.findByGeneratedContentId(draft.generatedContentId()), true);
            }
        } catch (DuplicateKeyException exception) {
            throw new GeneratedContentIdConflictException(draft.generatedContentId(), exception);
        }
        var conflicted = findLive(draft);
        if (conflicted != null) {
            return new DraftReservation(conflicted, false);
        }
        throw new IllegalStateException("practice generated content reservation conflict could not be loaded");
    }

    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public GenerationStartDecision startGeneration(
            String generatedContentId,
            OffsetDateTime dailyFrom,
            int dailyLimit,
            OffsetDateTime now
    ) {
        var draft = commandMapper.findLiveDraftForUpdate(generatedContentId);
        if (draft == null) {
            return GenerationStartDecision.NOT_LIVE;
        }
        commandMapper.lockOwnerRateLimit(ownerLockKey(draft));
        draft = commandMapper.findLiveDraftForUpdate(generatedContentId);
        if (draft == null) {
            return GenerationStartDecision.NOT_LIVE;
        }
        var starts = commandMapper.countRecentGenerationStarts(
                draft.ownerKey(), draft.ownerKeyVersion(), draft.surface(), draft.mode(), dailyFrom);
        if (starts >= dailyLimit) {
            return GenerationStartDecision.DAILY_LIMIT_EXCEEDED;
        }
        return commandMapper.markGenerating(generatedContentId, now) == 1
                ? GenerationStartDecision.STARTED
                : GenerationStartDecision.NOT_LIVE;
    }

    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public Optional<PracticeGeneratedContentEntity> activate(PracticeGeneratedContentEntity active) {
        insertApprovedUtterances(active);
        return commandMapper.activateGenerating(active) == 1
                ? Optional.ofNullable(queryMapper.findByGeneratedContentId(active.generatedContentId()))
                : Optional.empty();
    }

    @Override
    @Transactional
    public Optional<PracticeGeneratedContentEntity> activateWithCompletedAttempt(
            PracticeGeneratedContentEntity active,
            GenerationAttemptAuditPort.AttemptCompleted completedAttempt
    ) {
        if (auditMapper.completeAttempt(
                completedAttempt.attemptId(),
                completedAttempt.outcome(),
                completedAttempt.violationCodes(),
                completedAttempt.completedAt()) != 1) {
            throw new IllegalStateException("generation attempt was not started");
        }
        insertApprovedUtterances(active);
        if (commandMapper.activateGenerating(active) != 1) {
            throw new IllegalStateException("generated content was not generating");
        }
        var activated = queryMapper.findByGeneratedContentId(active.generatedContentId());
        if (activated == null || !"active".equals(activated.status())) {
            throw new IllegalStateException("activated generated content could not be loaded");
        }
        return Optional.of(activated);
    }

    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void reject(
            String generatedContentId,
            String errorCode,
            boolean retryable,
            OffsetDateTime now,
            OffsetDateTime retentionExpiresAt
    ) {
        commandMapper.rejectLive(generatedContentId, errorCode, retryable, now, retentionExpiresAt);
    }

    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void expire(
            String generatedContentId,
            String errorCode,
            boolean retryable,
            OffsetDateTime now,
            OffsetDateTime retentionExpiresAt
    ) {
        commandMapper.expireLive(generatedContentId, errorCode, retryable, now, retentionExpiresAt);
    }

    @Override
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public boolean quarantineUnsupportedActive(
            String generatedContentId,
            OffsetDateTime now,
            OffsetDateTime retentionExpiresAt
    ) {
        return commandMapper.quarantineUnsupportedActive(generatedContentId, now, retentionExpiresAt) == 1;
    }

    @Override
    @Transactional
    public int interruptStaleExecutions(
            OffsetDateTime interruptedAt,
            OffsetDateTime installationRetentionExpiresAt,
            int limit
    ) {
        commandMapper.interruptStartedProviderCalls(interruptedAt, limit);
        commandMapper.interruptStartedOperations(interruptedAt, limit);
        commandMapper.interruptStartedAttempts(interruptedAt, limit);
        return commandMapper.expireInterruptedGeneratedContent(
                interruptedAt, installationRetentionExpiresAt, limit);
    }

    @Override
    @Transactional
    public int deleteExpiredInstallationRows(OffsetDateTime retentionExpiresAtOrBefore, int limit) {
        return commandMapper.deleteExpiredInstallationRows(retentionExpiresAtOrBefore, limit);
    }

    @Override
    @Transactional
    public int deleteAccountOwned(String accountId) {
        return commandMapper.deleteAccountOwned(accountId);
    }

    private PracticeGeneratedContentEntity findLive(PracticeGeneratedContentEntity draft) {
        return queryMapper.findLiveByFingerprint(
                draft.ownerKey(),
                draft.ownerKeyVersion(),
                draft.surface(),
                draft.mode(),
                draft.requestFingerprint(),
                draft.generationProfileVersion(),
                draft.contentRefreshEpoch());
    }

    private PracticeGeneratedContentEntity findByClientRequestId(PracticeGeneratedContentEntity draft) {
        if (draft.clientRequestId() == null) {
            return null;
        }
        return queryMapper.findByClientRequestId(
                draft.ownerScope(),
                draft.ownerKey(),
                draft.ownerKeyVersion(),
                draft.clientRequestId());
    }

    private void insertApprovedUtterances(PracticeGeneratedContentEntity active) {
        var utterances = active.approvedUtterances();
        if (utterances.isEmpty()) {
            return;
        }
        if (commandMapper.insertApprovedUtterances(utterances) != utterances.size()) {
            throw new IllegalStateException("approved generated utterances could not be persisted");
        }
    }

    private String ownerLockKey(PracticeGeneratedContentEntity draft) {
        return draft.ownerKeyVersion() + ":" + draft.ownerKey();
    }

    private boolean isStaleDraft(PracticeGeneratedContentEntity entity, OffsetDateTime now) {
        return entity != null
                && "draft".equals(entity.status())
                && entity.generationExpiresAt() != null
                && !entity.generationExpiresAt().isAfter(now);
    }

    private boolean isDueInstallationActive(PracticeGeneratedContentEntity entity, OffsetDateTime now) {
        return entity != null
                && "installation".equals(entity.ownerScope())
                && "active".equals(entity.status())
                && entity.retentionExpiresAt() != null
                && !entity.retentionExpiresAt().isAfter(now);
    }

}
